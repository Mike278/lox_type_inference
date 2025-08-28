import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';

import 'package:collection/collection.dart';
import 'package:http/http.dart';
import 'package:lox/coordinator.dart';
import 'package:lox/interpreter.dart';
import 'package:lox/mark_types.dart';
import 'package:path/path.dart';
import 'package:web/web.dart' as web;

import './codemirror.dart';
import './code_samples.dart';


void main() {

  final outputElement = web.document.getElementById('output')!;
  final editorDiv = web.document.getElementById('editor') as web.HTMLElement;
  final runButton = web.document.getElementById('run-button')!;
  final examplesMenu = web.document.getElementById('examples-menu')!;

  var selectedExample = samples.first;
  void updateSelectedExample(Sample newSample) {
    selectedExample = newSample;
  }

  final marksByLine = <int, List<MarkText>>{};
  Timer? debounce;
  void queueTypecheck(String code) {
    debounce?.cancel();
    debounce = .new(.new(milliseconds: 300), () {
      marksByLine.clear();
      final (:errorOutput, marks) = markTypes('', .memory(code), webImportFile(selectedExample.name));
      outputElement.text = errorOutput;
      for (final mark in marks) {
        final (pos, display:_, style: _) = mark;
        final line = pos.from.line+1;
        (marksByLine[line] ??= []).add(mark);
      }
      for (final list in marksByLine.values) {
        list.sort((a, b) => -a.$1.from.absoluteOffset.compareTo(b.$1.from.absoluteOffset));
      }
    });
  }

  final editor = EditorView(.new(
    parent: editorDiv,
    doc: selectedExample.content,
    extensions: [
      basicSetup,
      oneDark,
      hoverTooltip(
        hoverTooltipCallback(marksByLine),
        HoverTooltipOptions(hoverTime: 1),
      ),
      EditorView.createUpdateListener((code) {
        queueTypecheck(code);
        _maybeLog(code);
      })
    ].toJS
  ));

  runButton.onClick.listen((_) {
    outputElement.text = exec(
      selectedExample.name,
      .memory(editor.state.doc.value),
    );
  });

  queueTypecheck(editor.state.doc.value);

  populateExamplesMenu(editor, examplesMenu, updateSelectedExample);
}

JSFunction hoverTooltipCallback(Map<int, List<MarkText>> marksByLine) =>
  (JSObject view, JSNumber pos, JSNumber side) {
    view as EditorView;
    final dartPos = (pos.dartify() as num).toInt();
    final line = view.state.doc.lineAt(pos);
    final marks = marksByLine[line.number] ?? [];
    if (marks.isEmpty) return null;
    final mark = marks.firstWhereOrNull((mark) => mark.$1.contains(dartPos));
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


void populateExamplesMenu(EditorView editor, web.Element menuElement, void Function(Sample) onSelected) {
  final list = web.document.createElement('ul');
  final title = web.document.createElement('h3');
  title.textContent = 'Examples';
  menuElement.append(title);

  for (final sample in samples) {
    final (name, code) = sample;
    final item = web.document.createElement('li');
    item.textContent = name;
    item.onClick.listen((_) {
      editor.replaceContent(code);
      menuElement.querySelector('.active')?.classList.remove('active');
      item.classList.add('active');
      onSelected(sample);
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

final _samplesByName = {
  for (final (name, sample) in samples)
    name: sample,
};

ReadFile webImportFile(SampleName relativeTo) =>
  (path) {
    final dir = dirname(relativeTo);
    final collapsed = path.replaceAll('../', '');
    final resolved = dir == '.'
        ? collapsed
        : '$dir/$collapsed';
    return _samplesByName[resolved] ?? (throw 'failed to import $path relative to $relativeTo ($resolved)');
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
