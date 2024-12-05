import 'dart:async';
import 'dart:js_interop';

import 'package:lox/env.dart';
import 'package:lox/expr.dart';
import 'package:lox/hindley_milner_api.dart';
import 'package:lox/hindley_milner_lambda_calculus.dart';
import 'package:lox/interpreter.dart';
import 'package:lox/lox_lambda_calculus.dart';
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
  web.document.getElementById('sample1-button')!.onClick.listen((_) {
    editor.getDoc().setValue(aoc2024day1Sample);
  });
  web.document.getElementById('sample2-button')!.onClick.listen((_) {
    editor.getDoc().setValue(sample);
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
      final (summary, marks) = typecheck(editor.getDoc().getValue());
      outputElement.text = summary;
      final doc = editor.getDoc();
      for (final (:from, :to, options) in marks) {
        final mark = doc.markText(from, to, options);
        clearMarks.add(() => mark.clear());
      }
    });
  }

  editor.on('change', (JSAny? _, JSAny? __) { queueTypecheck(); }.toJS);
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

print "";
print "side effects:";
print "";
let fx = map(friends, \friend {
    print "side effect!";
    if friend.name == "bob" then {
        print "hey bob :)";
        print friend;
    }
    else print friend;
    return friend;
});

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

let sort = \list -> list \> empty ? [] : [
    ..list \> rest \> where (_, \e -> e < (list \> first)) \> sort,
    list \> first,
    ..list \> rest \> where (_, \e -> e >= (list \> first)) \> sort
];

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


(String, List<MarkText>) typecheck(String source) {

  final marks = <MarkText>[];
  final output = [];
  reportError(kind) => (err) => output.add('$kind:\n$err');

  final (tokens, hadError: hadScanError) = scanTokens(source, reportError('scan error'));
  final (statements, hadError: hadParseError) = Parser(tokens, reportError('parse error')).parse();

  if (!hadParseError && !hadScanError) {

    unsupported(token, kind) {
      final msg = 'type checking $kind statements is not supported';
      final (:from, :to) = toCodeMirrorPositions(token);
      marks.add((
        from: from,
        to: to,
        MarkTextOptions(
          className: 'type-error',
          title: msg,
        ),
      ));
    }

    final lets = <LetDeclaration>[];

    for (final statement in statements) {
      switch (statement) {
        case LetDeclaration(:final initializer, :final name):
          lets.add(statement);
          marks.add(runInference(name, lets, initializer));
        case ExpressionStatement(:final expr, :final semicolon):
          lets.add(LetDeclaration(semicolon, expr));
          marks.add(runInference(semicolon, lets, expr));
        case PrintStatement(:final expr, :final keyword):
          lets.add(LetDeclaration(keyword, expr));
          marks.add(runInference(keyword, lets, expr));
        case AssertStatement(:final expr, :final keyword):
          lets.add(LetDeclaration(keyword, expr));
          marks.add(runInference(keyword, lets, expr));
        case ReturnStatement(:final keyword):
          unsupported(keyword, 'return');
        case Block(:final openBrace):
          unsupported(openBrace, 'block');
        case IfStatement(:final keyword):
          unsupported(keyword, 'if');
      }
    }
  }

  return (output.join('\n'), marks);
}

typedef MarkText = (
  MarkTextOptions options, {
  Position from,
  Position to,
});

({Position from, Position to}) toCodeMirrorPositions(Token token) {
  final from = Position(line: token.line-1, ch: token.offset);
  final to = Position(line: token.line-1, ch: token.offset + token.lexeme.length);
  return (from: from, to: to);
}

MarkText runInference(Token token, List<LetDeclaration> lets, Expr loxExpr) {
  final (:from ,:to) = toCodeMirrorPositions(token);

  final context = {...loxStandardLibraryContext};
  final expr = lets.length == 1
      ? toLambdaCalculus(loxExpr)
      : toLet(lets);
  try {
    TypeVariable.counter = 0;
    final (substitution, t) = w(expr, context);
    final type = substitution.appliedTo(t);
    final normalized = normalizeTypeVariableIds(type, displayAlpha);
    return (
      from: from,
      to: to,
      MarkTextOptions(
        className: 'type-info cm-tooltip-marker',
        attributes: {
          'data-tooltip': '${token.lexeme}: $normalized',
        }.jsify(),
      ),
    );
  } catch (e) {
    return (
      from: from,
      to: to,
      MarkTextOptions(
        className: 'type-error cm-tooltip-marker',
        attributes: {
          'data-tooltip': '${token.lexeme}: $e',
        }.jsify(),
      ),
    );
  }
}
