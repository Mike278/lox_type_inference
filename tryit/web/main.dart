import 'dart:js_interop';

import 'package:web/web.dart' as web;
import 'package:lox/src/scanner.dart';
import 'package:lox/src/parser.dart';
import 'package:lox/src/interpreter.dart';
import 'package:lox/src/env.dart';
import './codemirror.dart';


void main() {

  CodeMirror.defineSimpleMode('lox', loxMode.jsify());
  final editor = CodeMirror(
    web.document.getElementById('code-input')!,
    codeMirrorOptions.jsify()
  )..setSize('100%', '100%');

  final outputElement = web.document.getElementById('output-area')!;
  web.document.getElementById('run-button')!.onClick.listen((_) {
    outputElement.text = exec(editor.getDoc().getValue().trim());
  });
}

final sample = r'''
print "all friends:";

let friends = [
    {name: "alice", birthYear: 1996},
    {name: "bob", birthYear: 1984},
    {name: "charlie", birthYear: 1990},
    {name: "devin", birthYear: 1995}
];
print friends;
print "";



print "age of oldest friend (as of 2024):";

let ageOf = \friend, now -> 
    now.currentYear - friend.birthYear;

// have to define a bit of a standard library ourselves :)

let fold = \list, state, fn ->
    List.empty(list)
        ? state
        : fold(
            List.rest(list),
            fn(state, List.first(list)),
            fn
        );

let map = \list, fn ->
    fold(list, [], \state, element -> [..state, fn(element)]);
    
let reduce = \list, fn ->
    fold(list, List.first(list), fn);

let max = \x, y -> x > y ? x : y;

print friends
    \> map(_, ageOf(_, {currentYear: 2024}))
    \> reduce(_, max);
print "";


    
print "friends who probably grunt when they stand up:";

let where = \list, fn ->
    fold(list, [], \state, element -> 
        fn(element) ? [..state, element] : state);
    
let kneesProbablyHurt = \friend ->
     ageOf(friend, {currentYear: 2024}) >= 30;
     
print friends
    \> where(_, kneesProbablyHurt)
    \> map(_, \friend -> friend.name);
    
''';

String exec(String source) {

  final output = [];
  printMessage(msg) => output.add(msg);
  reportError(kind) => (err) => output.add('$kind:\n$err');
  runAssert(keyword, source, value) {
    try { defaultLoxAssert(keyword, source, value); }
    catch (e) { output.add(e); }
  }

  final (tokens, hadError: hadScanError) = scanTokens(source, reportError('scan error'));
  final (statements, hadError: hadParseError) = Parser(tokens, reportError('parse error')).parse();

  if (!hadParseError && !hadScanError) {
    LoxRuntime(
      reportError('runtime error'),
      runAssert,
      (print: printMessage),
    ).interpret(
      statements,
      Env.global(),
    );
  }

  return output.join('\n');
}


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
    {'token': "keyword",                    'regex': r'(?:let|print)\b'},
    {'token': "attribute",                  'regex': r'List'},
    {'token': "bracket",                    'regex': r'[{}\[\]()]'},
    {'token': "atom",                       'regex': r'true|false|nil'},
    {'token': "punctuation",                'regex': r'[,;]'},
    {'token': "number",                     'regex': r'\d'},
    {'token': "comment",                    'regex': r'\/\/.*'},
    {'token': "comment", 'next': "comment", 'regex': r'\/\*'},
    {'regex': r'[\{\[\(]',                  'indent': true},
    {'regex': r'[\}\]\)]',                  'dedent': true},
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
};