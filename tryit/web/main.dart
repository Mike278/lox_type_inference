import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';

import 'package:http/http.dart';
import 'package:lox/coordinator.dart';
import 'package:lox/interpreter.dart';
import 'package:lox/mark_types.dart';
import 'package:web/web.dart' as web;

import './codemirror.dart';
import './sample.dart';


void main() {

  CodeMirror.defineSimpleMode('lox', loxMode.jsify());
  final editor = CodeMirror(
    web.document.getElementById('code-input')!,
    codeMirrorOptions.jsify()
  )..setSize('100%', '100%');
  getSource() => Source(editor.getDoc().getValue());

  final outputElement = web.document.getElementById('output-area')!;
  web.document.getElementById('run-button')!.onClick.listen((_) {
    outputElement.text = exec(getSource());
  });

  editor.getDoc().setValue(sample);

  final clearMarks = <void Function()>[];
  Timer? debounce;
  void queueTypecheck() {
    debounce?.cancel();
    debounce = Timer(const Duration(milliseconds: 300), () {
      for (var clear in clearMarks) {
        clear();
      }
      clearMarks.clear();
      final (:errorOutput, marks) = markTypes('', getSource(), webImportFile);
      outputElement.text = errorOutput;
      final doc = editor.getDoc();
      for (final ((:from, :to), :display, :style) in marks) {
        final mark = doc.markText(
          Position(line: from.line, ch: from.offset),
          Position(line: to.line, ch: to.offset),
          MarkTextOptions(
            className: 'cm-tooltip-marker ${style ?? ''}',
            attributes: {'data-tooltip': display}.jsify(),
          ),
        );
        clearMarks.add(() => mark.clear());
      }
    });
  }

  editor.on('change', (JSAny? _, JSAny? __) {
    queueTypecheck();
    _maybeLog(editor.getDoc().getValue());
  }.toJS);
  queueTypecheck();
}

String exec(Source source) {

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
      Env.global(),
      runAssert,
      (print: printMessage),
      webImportFile,
      checkTypes: false,
    );
  } catch (e) {
    output.add(e);
  }

  return output.join('\n');
}

final webImportFile = (_) => throw 'file imports arent supported on web';


// keyword
// atom
// number
// def
// variable
// punctuation
// property
// operator
// variable-2
// variable-3
// s-default
// type
// comment
// string
// string-2
// meta
// qualifier
// builtin
// bracket
// tag
// attribute
// hr
// link

final loxMode = {
  'start': [
    {'token': "property",                   'regex': r'([a-zA-Z_]\w*)(?=\s*:)'},
    {'token': "string",                     'regex': r'"(?:[^\\]|\\.)*?(?:"|$)'},
    {'token': ["keyword", null, "def"],     'regex': r'(let)(\s+)([a-z$][\w$]*)'},
    {'token': "keyword",                    'regex': r'(?:let|print|if|then|else|return)\b'},
    {'token': "attribute",                  'regex': r'List'},
    {'token': "bracket",                    'regex': r'[\{\[\(]', },
    {'token': "bracket",                    'regex': r'[\}\]\)]', },
    {'token': "atom",                       'regex': r'true|false|nil'},
    {'token': "punctuation",                'regex': r'[,;]'},
    {'token': "number",                     'regex': r'\d'},
    {'token': "comment",                    'regex': r'\/\/.*'},
    {'token': "comment", 'next': "comment", 'regex': r'\/\*'},
    {'token': "operator",                   'regex': r'->'},
    {'token': "operator",                   'regex': r'->|\\>|\?|:|\.\.'},
    {'token': "variable-3",                 'regex': r'[a-z$][\w$]*'},
  ],
  'comment': [
    {'token': "comment", 'next': "start",   'regex': r'.*?\*\/'},
    {'token': "comment",                    'regex': r'.*'},
  ],
};

final codeMirrorOptions = {
  'value': sample,
  'mode': 'lox',
  'lineNumbers': true,
  'theme': 'ambiance',
  'indentUnit': 4,
  'highlightSelectionMatches': true,
  'matchBrackets': true,
  'autoCloseBrackets': true,
  'autoCloseTags': {
    'whenOpening': true,
    'whenClosing': true,
  },
};

Timer? debounce;
Future<void> _maybeLog(String source) async {
  if (source.isEmpty) return;
  debounce?.cancel();
  debounce = Timer(const Duration(seconds: 2), () => _log(source));
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
