import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';

import 'package:http/http.dart';
import 'package:lox/env.dart';
import 'package:lox/interpreter.dart';
import 'package:lox/mark_types.dart';
import 'package:lox/parser.dart';
import 'package:lox/scanner.dart';
import 'package:web/web.dart' as web;

import './codemirror.dart';


void main() {

  CodeMirror.defineSimpleMode('lox', loxMode.jsify());
  final editor = CodeMirror(
    web.document.getElementById('code-input')!,
    codeMirrorOptions.jsify()
  )..setSize('100%', '100%');

  final outputElement = web.document.getElementById('output-area')!;
  web.document.getElementById('run-button')!.onClick.listen((_) {
    outputElement.text = exec(editor.getDoc().getValue());
  });

  <String, String>{
    'sample1-button': aoc2024day1Sample,
    'sample2-button': sample,
    'sample3-button': tagsSample,
  }.forEach((id, code) {
    web.document.getElementById(id)!.onClick.listen((_) {
      editor.getDoc().setValue(code);
    });
  });

  final clearMarks = <void Function()>[];
  Timer? debounce;
  void queueTypecheck() {
    debounce?.cancel();
    debounce = Timer(const Duration(milliseconds: 300), () {
      for (var clear in clearMarks) {
        clear();
      }
      clearMarks.clear();
      final (:errorOutput, marks) = markTypes(editor.getDoc().getValue());
      outputElement.text = errorOutput;
      final doc = editor.getDoc();
      for (final ((:from, :to), :display) in marks) {
        final mark = doc.markText(
          Position(line: from.line, ch: from.offset),
          Position(line: to.line, ch: to.offset),
          MarkTextOptions(
            className: 'cm-tooltip-marker',
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
    fold(List.rest(list), List.first(list), fn);

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
    
let withCoolStatus = \friend -> { ..friend, isCool: friend.name == "bob" };

print "";
print "side effects:";
print "";
let updatedFriends = map(friends, \friend {
    print "side effect!";
    let updated = friend \> withCoolStatus;
    if updated.isCool then print "nice";
    return updated;
});

print updatedFriends;
print map(updatedFriends, \f -> f.isCool ? f.birthYear : 0);

''';

final aoc2024day1Sample = r'''
// advent of code 2024 day 1

let empty = List.empty;
let first = List.first;
let rest = List.rest;

let fold = \list, state, fn ->
    list \> empty ? state : 
    fold(list \> rest, fn(state, list \> first), fn);

let map = \list, fn ->
    fold(list, [], \state, element -> [..state, fn(element)]);

let reduce = \list, fn ->
    fold(list \> rest, list \> first, fn);

let where = \list, fn ->
    fold(list, [], \state, element -> 
        fn(element) ? [..state, element] : state);

let sort = \list {
  if list \> empty then return [];
  let x = list \> first;
  let xs = list \> rest;
  let isBefore = \e -> e < x;
  let isAfter = \e -> e >= x;
  return [
    ..xs \> where(_, isBefore) \> sort,
    x,
    ..xs \> where(_, isAfter) \> sort
  ];
}; 

let zip = \l1, l2, fn -> 
    (l1 \> empty) or 
    (l2 \> empty) ? [] :
    [
        fn(l1 \> first, l2 \> first),
        ..zip(l1 \> rest, l2 \> rest, fn)
    ];


let absDiff = \a, b -> a > b ? a - b : b - a;
let plus = \a, b -> a + b;
let sum = \list -> reduce(list, plus);

let input = [
    [3, 4],
    [4, 3],
    [2, 5],
    [1, 3],
    [3, 9],
    [3, 3]
];

let lists = fold(
    input,
    {l1: [], l2: []},
    \state, pair -> {
        l1: [..state.l1, pair \> first],
        l2: [..state.l2, pair \> rest \> first]
    }
);
print lists;

let diffs = zip(
  lists.l1 \> sort,
  lists.l2 \> sort,
  absDiff
);
print diffs;

let ans = sum(diffs);
print ans;
assert ans == 11;
''';

final tagsSample = r'''
let empty = List.empty;
let first = List.first;
let rest = List.rest;

let fold = \list, state, fn ->
    list \> empty ? state : 
    fold(list \> rest, fn(state, list \> first), fn);

let map = \list, fn ->
    fold(list, [], \state, element -> [..state, fn(element)]);

//////////////////////////////////////////////////////

let colorToStr = \color -> match color {
  .Red -> "r",
  .RedAndYellow -> "r&y",
  .Yellow -> "y",
  .Green -> "g",
};

let na = [.Green, .Yellow, .Red];
let eu = [.Green, .Yellow, .Red, .RedAndYellow];
let current = true ? na : eu;

let colorsToStr = map(_, colorToStr);
print colorsToStr(na);
print colorsToStr(eu);
print colorsToStr(current);

//////////////////////////////////////////////////////

let tab = .Key("\t");
let center = .Mouse({x: 50, y: 50});
let keyOrMouse = false ? tab : center;

let fn = \e -> match e {
    .Key char -> char,
    .Mouse coords -> coords.x > 50 ? "top" : "bottom",
};

print fn(tab);
print fn(center);
print fn(keyOrMouse);
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
  'value': aoc2024day1Sample,
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
    }
  })
);
