import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';

import 'package:collection/collection.dart';
import 'package:http/http.dart';
import 'package:lox/coordinator.dart';
import 'package:lox/interpreter.dart';
import 'package:lox/mark_types.dart';
import 'package:lox/parser.dart';
import 'package:lox/scanner.dart';
import 'package:path/path.dart';
import 'package:web/web.dart' as web;

import './codemirror.dart';
import './code_samples.dart';



final documentsState = {
  for (final (name, sample) in samples)
    name: sample,
};

void main() {

  final outputElement = web.document.getElementById('output')!;
  final editorDiv = web.document.getElementById('editor') as web.HTMLElement;
  final runButton = web.document.getElementById('run-button')!;
  final examplesMenu = web.document.getElementById('examples-menu')!;
  web.EventStreamProviders.beforeUnloadEvent.forTarget(web.window).listen((event) {
    event.preventDefault();
  });

  var selectedExample = samples.first.$1;
  void updateSelectedExample(EditorView editor, SampleName newSample) {
    documentsState[selectedExample] = SampleContent(editor.state.doc.value);
    selectedExample = newSample;
    editor.replaceContent(documentsState[newSample]!);
  }

  final marksByLine = <int, List<MarkText>>{};
  Timer? debounce;
  void queueTypecheck(String code) {
    debounce?.cancel();
    debounce = .new(.new(milliseconds: 300), () {
      marksByLine.clear();
      outputElement.textContent = '';
      try {
        final (:errorOutput, marks) = markTypes('', .memory(code), webImportFile(selectedExample));
        outputElement.textContent = errorOutput;
        for (final mark in marks) {
          final (pos, display:_, isError: _) = mark;
          final line = pos.from.line+1;
          (marksByLine[line] ??= []).add(mark);
        }
        for (final list in marksByLine.values) {
          list.sort((a, b) => -a.$1.from.absoluteOffset.compareTo(b.$1.from.absoluteOffset));
        }
      } on ParserError catch (e) {
        outputElement.textContent = '(line ${e.token.line}:${e.token.offset}) ${e.message}';
        marksByLine[e.token.line] = [(
          toSpan(e.token),
          display: e.message,
          isError: true,
        )];
      }
    });
  }

  final editor = EditorView(.new(
    parent: editorDiv,
    doc: documentsState[selectedExample]!,
    extensions: [
      lox,
      basicSetup,
      oneDark,
      hoverTooltip(
        hoverTooltipCallback(marksByLine),
        HoverTooltipOptions(hoverTime: 50),
      ),
      linter(linterCallback(marksByLine)),
      lintGutter(),
      EditorView.createUpdateListener((code) {
        queueTypecheck(code);
        _maybeLog(code);
      }),
      keymap.of([indentWithTab].toJS),
    ].toJS
  ));

  runButton.onClick.listen((_) {
    outputElement.textContent = exec(
      selectedExample,
      .memory(editor.state.doc.value),
    );
  });

  queueTypecheck(editor.state.doc.value);

  populateExamplesMenu(examplesMenu, (sample) => updateSelectedExample(editor, sample));
}

JSFunction hoverTooltipCallback(Map<int, List<MarkText>> marksByLine) =>
  (JSObject view, JSNumber pos, JSNumber side) {
    view as EditorView;
    final dartPos = (pos.dartify() as num).toInt();
    final line = view.state.doc.lineAt(pos);
    final marks = marksByLine[line.number] ?? [];
    if (marks.isEmpty) return null;
    final mark = marks.firstWhereOrNull((mark) => !mark.isError && mark.$1.contains(dartPos));
    if (mark == null) return null;
    return Tooltip.create(
      start: pos,
      build: (editor) {
        final element = web.document.createElement("div");
        element.className = "cm-tooltip-content type-hint-tooltip";
        final typeElement = web.document.createElement("div");
        typeElement.className = "cm-tooltip-type";
        typeElement.textContent = mark.display;
        element.appendChild(typeElement);
        final tooltip = element as web.HTMLElement;
        return tooltip;
      },
    );
  }.toJS;

JSFunction linterCallback(Map<int, List<MarkText>> marksByLine) =>
  (JSAny _) {
    return [
      for (final (span, :display, :isError) in marksByLine.values.expand((i) => i))
        if (isError)
          Diagnostic(
            from: span.from.absoluteOffset,
            to: span.to.absoluteOffset,
            severity: 'error',
            message: display,
          )
    ].toJS;
  }.toJS;


void populateExamplesMenu(web.Element menuElement, void Function(SampleName) onSelected) {
  final list = web.document.createElement('ul');
  final title = web.document.createElement('h3');
  title.textContent = 'Examples';
  menuElement.append(title);

  for (final name in documentsState.keys) {
    final item = web.document.createElement('li');
    item.textContent = name;
    item.onClick.listen((_) {
      menuElement.querySelector('.active')?.classList.remove('active');
      item.classList.add('active');
      onSelected(name);
    });
    list.append(item);
  }

  // Set the first item as active by default
  (list.firstChild as web.HTMLLIElement?)?.classList.add('active');

  menuElement.append(list);
}

String exec(SampleName sample, Source source) {

  final output = [];
  printMessage(msg) => output.add(msg);
  runAssert(keyword, source, value) {
    try { defaultLoxAssert(keyword, source, value); }
    catch (e) { output.add(e); }
  }

  try {
    run(
      '',
      source,
      .global(),
      runAssert,
      (print: printMessage),
      webImportFile(sample),
      checkTypes: false,
    );
  } catch (e) {
    output.add(e);
  }

  return output.join('\n');
}

ReadFile webImportFile(SampleName relativeTo) =>
  (path) {
    final fileName = basename(path);
    final key = documentsState.keys.singleWhere(
      // assume unique base names to keep this simple
      (sample) => basename(sample) == fileName
    );
    return documentsState[key] ?? (throw 'failed to import $path relative to $relativeTo');
  };



Timer? debounce;
Future<void> _maybeLog(String source) async {
  if (source.isEmpty) return;
  debounce?.cancel();
  debounce = .new(.new(seconds: 2), () => _log(source));
}

final start = DateTime.now().toUtc().toIso8601String();
final _url = Uri.parse('https://firestore.googleapis.com/v1/projects/loxtypeinference/databases/(default)/documents/tryit');
Future<void> _log(String source) => post(
  _url,
  headers: const {'Content-Type': 'application/json'},
  body: jsonEncode({
    "fields": {
      "source": {
        "stringValue": source
      },
      "ts": {
        "timestampValue": DateTime.now().toUtc().toIso8601String(),
      },
      "start": {
        "timestampValue": start,
      },
    }
  })
);


final lox = streamLanguageDefine(StreamParser.create(
  name: 'Lox',
  startState: () => {}.jsify()!,
  copyState: (state) => {...state.dartify() as Map}.jsify()!,
  token: (stream, state) {
    return _nextToken(stream, state);
  },
  blankLine: null,
  indent: null,
  languageData: null,
));


final _red = 'variable';
final _orange = 'atom';
// final _yellow = 'number';
final _blue = 'operator';
final _green = 'string';
// final _pink = 'keyword';
final _white = 'error';
final _grey = 'comment';

String? _nextToken(StringStream stream, JSAny state) {
  // Handle whitespace
  if (stream.eatSpace()) {
    return null;
  }

  final ch = stream.next();
  if (ch == null) return null;

  // Comments
  if (ch == '/' && stream.eat('/'.toJS) != null) {
    stream.skipToEnd();
    return _grey;
  }

  // Strings
  if (ch == '"') {
    var escaped = false;
    String? next;
    while ((next = stream.next()) != null) {
      if (next == '"' && !escaped) {
        break;
      }
      escaped = !escaped && next == "\\";
    }

    return "string";
  }

  // Numbers
  if (RegExp(r'\d').hasMatch(ch)) {
    stream.match(RegExp(r'^\d*(?:\.\d*)?(?:[eE][+\-]?\d+)?').toJS);
    return _green;
  }

  // Operators
  if ('\\+-*/=!<>?:'.contains(ch)) return _orange;
  if (ch == '=' && stream.eat('='.toJS) != null) return _orange;
  if (ch == '!' && stream.eat('='.toJS) != null) return _orange;
  if (ch == '<' && stream.eat('='.toJS) != null) return _orange;
  if (ch == '>' && stream.eat('='.toJS) != null) return _orange;
  if (ch == '.' && stream.eat('.'.toJS) != null) return _orange;
  if (ch == '|' && stream.eat('>'.toJS) != null) return _orange;
  if (ch == '-' && stream.eat('>'.toJS) != null) return _orange;

  // Variants (starting with .)
  if (ch == '.' && RegExp(r'[A-Z]').hasMatch(stream.peek() ?? '-')) {
    stream.match(RegExp(r'^[A-Za-z_][A-Za-z0-9_]*').toJS);
    return _white;
  }

  // Identifiers and keywords
  if (RegExp(r'[a-zA-Z_]').hasMatch(ch)) {
    stream.match(RegExp(r'^[a-zA-Z0-9_]*').toJS);
    final word = stream.current();

    if (keywords.keys.contains(word)) {
      return _red;
    }

    return null;
  }

  if ('[]{}()'.contains(ch)) {
    return _blue;
  }

  // Punctuation
  if (ch == ';' || ch == ',' || ch == ':') {
    return _grey;
  }

  return null;
}
