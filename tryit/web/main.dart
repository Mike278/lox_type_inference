import 'dart:async';
import 'dart:js_interop';

import 'package:lox/env.dart';
import 'package:lox/expr.dart';
import 'package:lox/hindley_milner_api.dart';
import 'package:lox/interpreter.dart';
import 'package:lox/lox_lambda_calculus.dart';
import 'package:lox/parser.dart';
import 'package:lox/scanner.dart';
import 'package:lox/utils.dart';
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
      for (final ((:from, :to), options) in marks) {
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


typedef CodeSpan = ({Position from, Position to});
typedef MarkText = (CodeSpan, MarkTextOptions);

(String, List<MarkText>) typecheck(String source) {

  final output = [];
  reportError(kind) => (err) => output.add('$kind:\n$err');

  final (tokens, hadError: hadScanError) = scanTokens(source, reportError('scan error'));
  final (statements, hadError: hadParseError) = Parser(tokens, reportError('parse error')).parse();

  if (hadParseError || hadScanError) return (output.join('\n'), []);

  final marks = <MarkText>[];
  try {
    final lookup = runInference(statements);
    final typeOf = (Expr expr) {
      final type = lookup[expr];
      return type;
    };
    final hovers = buildHoverInfo(statements, typeOf);
    for (final (span, :display, :style) in hovers) {
      marks.add((
        span,
        MarkTextOptions(
          className: '${style ?? ''} cm-tooltip-marker',
          attributes: {'data-tooltip': display}.jsify(),
        )
      ));
    }

  } catch (e) {
    reportError('typecheck error')(e);
  }

  return (
    output.join('\n'),
    marks,
  );
}

extension on Token {
  CodeSpan get span {
    final from = Position(line: line-1, ch: offset);
    final to = Position(line: line-1, ch: offset + lexeme.length);
    return (from: from, to: to);
  }
}

typedef TypeOf = Ty? Function(Expr);

List<(CodeSpan, {String display, String? style})> buildHoverInfo(
  List<Statement> program,
  TypeOf typeOf,
) => [
  for (final statement in program)
    for (final (span, display) in displayStatement(statement, typeOf))
      (
        span,
        display: display,
        style: null //'type-info',
      )
];


List<(CodeSpan, String)> displayStatement(
  Statement statement,
  TypeOf typeOf,
) => switch (statement) {

  ExpressionStatement(:final expr) =>
      displayExpression(expr, typeOf),

  AssertStatement(:final keyword, :final expr) ||
  PrintStatement(:final keyword, :final expr) => [
      (keyword.span, '${keyword.lexeme}: ${displayType(typeOf(expr))}'),
      ...displayExpression(expr, typeOf),
  ],

  LetDeclaration(:final name, :final initializer) => [
      (name.span, '${name.lexeme}: ${typeOf(initializer)}'),
      ...displayExpression(initializer, typeOf),
  ],

  Block(:final statements) => [
      for (final s in statements)
        ...displayStatement(s, typeOf)
  ],

  ReturnStatement(:final keyword, expr: null) => [
      (keyword.span, '${keyword.lexeme}: nil')
  ],

  ReturnStatement(:final keyword, :final expr?) => [
      (keyword.span, '${keyword.lexeme}: ${displayType(typeOf(expr))}'),
      ...displayExpression(expr, typeOf),
  ],

  IfStatement(
    :final condition,
    :final thenBranch,
    :final elseBranch,
  ) => [
      ...displayExpression(condition, typeOf),
      ...displayStatement(thenBranch, typeOf),
      if (elseBranch != null) ...displayStatement(elseBranch, typeOf),
  ],
};

List<(CodeSpan, String)> displayExpression(
  Expr expr,
  TypeOf typeOf,
) => switch (expr) {


  Variable(:final name) => [
    (name.span, '${name.lexeme}: ${displayType(typeOf(expr))}')
  ],


  StringLiteral() ||
  NumberLiteral() ||
  FalseLiteral() ||
  TrueLiteral() ||
  NilLiteral() => [],


  Grouping(:final expr) => displayExpression(expr, typeOf),

  Lambda(
    :final params,
    body: ArrowExpression(
      :final body,
      :final arrow,
    ),
  ) => [
    (arrow.span, displayType(typeOf(expr))),
    ...displayExpression(body, typeOf),
    ...zip(
      params,
      _uncurry(typeOf(expr) as TyFunctionApplication),
      (param, type) => (param.span, '${param.lexeme}: $type'),
    ),
  ],


  Lambda(
    :final params,
    body: FunctionBody(
      body: Block(
        :final statements,
        :final openBrace,
        :final closeBrace,
      )
    )
  ) =>[
    (openBrace.span, displayType(typeOf(expr))),
    (closeBrace.span, displayType(typeOf(expr))),
    ...zip(
      params,
      _uncurry(typeOf(expr) as TyFunctionApplication),
      (param, type) => (param.span, '${param.lexeme}: $type'),
    ),
    for (final s in statements)
      ...displayStatement(s, typeOf),
  ],


  Call(
    :final callee,
    args: ExpressionArgs(exprs: final args),
    :final closingParen,
  ) => [
    (closingParen.span, displayType(typeOf(expr))),
    ...displayExpression(callee, typeOf),
    for (final arg in args) ...displayExpression(arg, typeOf),
  ],


  Call(
    :final callee,
    args: ArgsWithPlaceholder(:final before, :final placeholder, :final after),
    :final closingParen,
  ) => [
    (closingParen.span, displayType(typeOf(expr))),
    (placeholder.span, '${placeholder.lexeme}: TODO'),
    for (final e in before) ...displayExpression(e, typeOf),
    for (final e in after) ...displayExpression(e, typeOf),
    ...displayExpression(callee, typeOf),
  ],


  ListLiteral(
    :final closingBracket,
    :final elements,
  ) => [
    (closingBracket.span, '[...]: ${displayType(typeOf(expr))}'),
    for (final e in elements) ...switch (e) {
        ExpressionListElement(:final expr) || SpreadListElement(:final expr) =>
          displayExpression(expr, typeOf)
      }
  ],


  Ternary(
    :final questionMark,
    :final condition,
    :final ifTrue,
    :final ifFalse,
  ) => [
    (questionMark.span, '?: ${displayType(typeOf(expr))}'),
    ...displayExpression(condition, typeOf),
    ...displayExpression(ifTrue, typeOf),
    ...displayExpression(ifFalse, typeOf),
  ],


  LogicalAnd(:final left, :final keyword, :final right) ||
  LogicalOr(:final left, :final keyword, :final right) ||
  Binary(:final left, operator: final keyword, :final right) => [
    (keyword.span, '${keyword.lexeme}: ${displayType(typeOf(expr))}'),
    ...displayExpression(left, typeOf),
    ...displayExpression(right, typeOf),
  ],


  Record(:final fields, :final closingBrace) => [
    (closingBrace.span, '{...}: ${displayType(typeOf(expr))}'),
    for (final (name, field) in fields.pairs()) ...[
      (name.span, '${name.lexeme}: ${displayType(typeOf(field))}'),
      ...displayExpression(field, typeOf),
    ]
  ],


  RecordGet(:final name, :final record) => [
    (name.span, '${name.lexeme}: ${displayType(typeOf(expr))}'),
    ...displayExpression(record, typeOf),
  ],


  RecordUpdate(
    :final record,
    :final newFields,
    :final closingBrace,
  ) => [
    (closingBrace.span, '{...}: ${displayType(typeOf(expr))}'),
    ...displayExpression(record, typeOf),
    for (final (name, field) in newFields.pairs()) ...[
      (name.span, '${name.lexeme}: ${displayType(typeOf(field))}'),
      ...displayExpression(field, typeOf),
    ]
  ],


  UnaryMinus(:final operator, :final expr) ||
  UnaryBang(:final operator, :final expr) => [
    (operator.span, '${operator.lexeme}: ${displayType(typeOf(expr))}'),
    ...displayExpression(expr, typeOf),
  ],
  TagConstructor(:final tag, :final payload) => [
    (tag.span, '${tag.lexeme}: ${displayType(typeOf(expr))}'),
    if (payload != null) ...displayExpression(payload, typeOf)
  ],
  TagMatch(:final tag, :final keyword, :final cases) => [
    (keyword.span, '${keyword.lexeme}: ${displayType(typeOf(expr))}'),
    ...displayExpression(tag, typeOf),
    for (final TagMatchCase(:result) in cases)
      ...displayExpression(result, typeOf)
  ],
};

String displayType(Ty? type) =>
  type == null ? '<unknown>' : '$type';

Iterable<Ty> _uncurry(TyFunctionApplication fn) sync* {
  assert(fn.name == 'Function');
  var [parameter, body] = fn.monoTypes;
  yield parameter;

  while (true) if (body case TyFunctionApplication(
    name: 'Function',
    monoTypes: [final input, final output],
  )) {
    yield input;
    body = output;
  } else return;
}
