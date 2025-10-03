import 'dart:math';

import 'package:lox/coordinator.dart';
import 'package:lox/expr.dart';
import 'package:lox/hindley_milner_api.dart';
import 'package:lox/hindley_milner_lox.dart';
import 'package:lox/token.dart';
import 'package:lox/utils.dart';

typedef MarkText = (CodeSpan, {String display, bool isError});
typedef CodeSpan = ({CodePosition from, CodePosition to});
typedef CodePosition = ({int line, int offset, int absoluteOffset});

extension on Token {
  CodeSpan get span => toSpan(this);
}

CodeSpan toSpan(Token token) {
  final length = token.lexeme.length;
  final line = token.line-1;
  final fromOffset = token.offset;
  final toOffset = fromOffset + length;
  final fromAbsolute = token.absoluteOffset;
  final toAbsolute = fromAbsolute + length;
  return (
    from: (line: line, offset: fromOffset, absoluteOffset: fromAbsolute),
    to: (line: line, offset: toOffset, absoluteOffset: toAbsolute),
  );
}

extension CodeSpanAPI on CodeSpan {
  CodeSpan extendedBy(CodeSpan other) => extend(this, other);
  bool contains(int position) =>
    from.absoluteOffset <= position && position <= to.absoluteOffset;
}

CodeSpan extend(CodeSpan a, CodeSpan b) => (
  from: (
    line: min(a.from.line, b.from.line),
    offset: min(a.from.offset, b.from.offset),
    absoluteOffset: min(a.from.absoluteOffset, b.from.absoluteOffset),
  ),
  to: (
    line: max(a.from.line, b.from.line),
    offset: max(a.from.offset, b.from.offset),
    absoluteOffset: max(a.from.absoluteOffset, b.from.absoluteOffset),
  ),
);

(List<MarkText>, {String errorOutput}) markTypes(
  String relativeToDir,
  Source source,
  ReadFile readFile,
) {

  final output = [];
  reportError(kind) => (err) => output.add('$kind:\n$err');

  final sw = Stopwatch()..start();
  justSpentTime(msg) => print('$msg took ${sw.elapsedMilliseconds}ms');

  final (statements, resolveImport) = parseSourceAndResolveImports(relativeToDir, source, readFile);

  final marks = <MarkText>[];
  try {
    TypeInference(resolveImport).inferProgramTypes(statements);
    justSpentTime('type checking');
  } catch (e) {
    if (e case (Expr expr, TypeCheckException typeError)) {
      final span = locationForErrorUnderline(expr);
      if (span != null) {
        marks.add((
          span,
          display: '$typeError',
          isError: true,
        ));
        reportError('typecheck error')(typeError);
      } else {
        reportError('typecheck error caused by $expr')(typeError);
      }
    } else {
      reportError('typecheck error')(e);
    }
  }

  normalizeProgramTypeVariableIds(statements);
  justSpentTime('normalizing type variables');

  final typeOf = (Expr expr) => expr.type;
  final hovers = buildHoverInfo(statements, typeOf);
  justSpentTime('building hovers');
  for (final (token, :display) in hovers) {
    marks.add((
      toSpan(token),
      display: display,
      isError: false,
    ));
  }

  sw.stop();
  return (
    errorOutput: output.join('\n'),
    marks,
  );
}

typedef TypeOf = Ty? Function(Expr);

List<(Token, {String display})> buildHoverInfo(
  List<Statement> program,
  TypeOf typeOf,
) => [
  for (final statement in program)
    for (final (span, display) in displayStatement(statement, typeOf))
      (
        span,
        display: display,
      )
];


List<(Token, String)> displayStatement(
  Statement statement,
  TypeOf typeOf,
) => switch (statement) {

  ExpressionStatement(:final expr) =>
      displayExpression(expr, typeOf),

  AssertStatement(:final keyword, :final expr) ||
  PrintStatement(:final keyword, :final expr) => [
      (keyword, '${keyword.lexeme}: ${displayType(typeOf(expr))}'),
      ...displayExpression(expr, typeOf),
  ],

  LetDeclaration(:final pattern, :final initializer) => [
      ...displayPattern(pattern),
      ...displayExpression(initializer, typeOf),
  ],

  Block(:final statements) => [
      for (final s in statements)
        ...displayStatement(s, typeOf)
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

List<(Token, String)> displayPattern(Pattern pattern) =>
  switch (pattern) {
    Identifier(:final name, :final type) => [
      (name, '${name.lexeme}: ${displayType(type)}'),
    ],
    RecordDestructure(:final elements) => [
      for (final field in elements) ...[
        (field.name, '${field.name.lexeme}: ${displayType(field.type)}'),
        if (field.pattern case final pattern?)
          ...displayPattern(pattern),
      ],
    ],
    TagPattern(:final tag, :final payload, :final type) => [
      (tag, '${tag.lexeme}: ${displayType(type)}'),
      if (payload != null) ...displayPattern(payload),
    ],
  };

List<(Token, String)> displayExpression(
  Expr expr,
  TypeOf typeOf,
) => switch (expr) {

  Return(:final keyword, :final expr) => [
    (keyword, expr == null ? 'nil' : displayType(typeOf(expr))),
    if (expr != null) ...displayExpression(expr, typeOf),
  ],

  Variable(:final name) => [
    (name, '${name.lexeme}: ${displayType(typeOf(expr))}')
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
    (arrow, displayType(typeOf(expr))),
    ...displayExpression(body, typeOf),
    ...params.expand(displayPattern),
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
    (openBrace, displayType(typeOf(expr))),
    (closeBrace, displayType(typeOf(expr))),
    ...params.expand(displayPattern),
    for (final s in statements)
      ...displayStatement(s, typeOf),
  ],


  Call(
    :final callee,
    args: ExpressionArgs(exprs: final args),
    :final closingParen,
  ) => [
    (closingParen, displayType(typeOf(expr))),
    ...displayExpression(callee, typeOf),
    for (final arg in args) ...displayExpression(arg, typeOf),
  ],


  Call(
    :final callee,
    args: ArgsWithPlaceholder(:final before, :final placeholder, :final placeholderType, :final after),
    :final closingParen,
  ) => [
    (closingParen, displayType(typeOf(expr))),
    (placeholder, '${placeholder.lexeme}: ${displayType(placeholderType)}'),
    for (final e in before) ...displayExpression(e, typeOf),
    for (final e in after) ...displayExpression(e, typeOf),
    ...displayExpression(callee, typeOf),
  ],


  ListLiteral(
    :final closingBracket,
    :final elements,
  ) => [
    (closingBracket, '[...]: ${displayType(typeOf(expr))}'),
    for (final e in elements) ...switch (e) {
        ExpressionListElement(:final expr) || SpreadListElement(:final expr) =>
          displayExpression(expr, typeOf)
      }
  ],


  IfExpression(
    :final ifKeyword,
    :final condition,
    :final ifTrue,
    :final ifFalse,
  ) => [
    (ifKeyword, 'if: ${displayType(typeOf(expr))}'),
    ...displayExpression(condition, typeOf),
    ...displayExpression(ifTrue, typeOf),
    ...displayExpression(ifFalse, typeOf),
  ],


  LogicalAnd(:final left, :final keyword, :final right) ||
  LogicalOr(:final left, :final keyword, :final right) ||
  Binary(:final left, operator: final keyword, :final right) => [
    (keyword, '${keyword.lexeme}: ${displayType(typeOf(expr))}'),
    ...displayExpression(left, typeOf),
    ...displayExpression(right, typeOf),
  ],


  Record(:final fields, :final closingBrace) => [
    (closingBrace, '{...}: ${displayType(typeOf(expr))}'),
    for (final (name, field) in fields.pairs()) ...[
      (name, '${name.lexeme}: ${displayType(typeOf(field))}'),
      ...displayExpression(field, typeOf),
    ]
  ],


  RecordGet(:final name, :final record) => [
    (name, '${name.lexeme}: ${displayType(typeOf(expr))}'),
    ...displayExpression(record, typeOf),
  ],


  RecordUpdate(
    :final record,
    :final newFields,
    :final closingBrace,
  ) => [
    (closingBrace, '{...}: ${displayType(typeOf(expr))}'),
    ...displayExpression(record, typeOf),
    for (final (name, field) in newFields.pairs()) ...[
      (name, '${name.lexeme}: ${displayType(typeOf(field))}'),
      ...displayExpression(field, typeOf),
    ]
  ],


  UnaryMinus(:final operator, :final expr) ||
  UnaryBang(:final operator, :final expr) => [
    (operator, '${operator.lexeme}: ${displayType(typeOf(expr))}'),
    ...displayExpression(expr, typeOf),
  ],
  TagConstructor(:final tag, :final payload) => [
    (tag, '${tag.lexeme}: ${displayType(typeOf(expr))}'),
    if (payload != null) ...displayExpression(payload, typeOf)
  ],
  TagMatch(:final tag, :final keyword, :final cases) => [
    (keyword, '${keyword.lexeme}: ${displayType(typeOf(expr))}'),
    ...displayExpression(tag, typeOf),
    for (final TagMatchCase(:pattern, :result) in cases) ...[
      ...displayPattern(pattern),
      ...displayExpression(result, typeOf),
    ],
  ],
  Import(:final keyword, :final target, :final path) => [
    (keyword, '$path: ${displayType(typeOf(expr))}'),
    (target, '$path: ${displayType(typeOf(expr))}'),
  ],
  TagCastOk(expr: final tagExpr, :final fallback) => [
    ...displayExpression(tagExpr, typeOf),
    if (fallback != null) ...displayExpression(fallback, typeOf),
  ],
  BlockExpr(:final openBrace, :final statements, :final closeBrace) => [
    (openBrace, '{ ... }: ${displayType(typeOf(expr))}'),
    (closeBrace, '{ ... }: ${displayType(typeOf(expr))}'),
    for (final statement in statements)
      ...displayStatement(statement, typeOf),
  ],
};

String displayType(Ty? type) =>
  type == null ? '<unknown>' : prettyPrint(type, displayTypeVariable);

String displayTypeVariable(({int id, bool quantified}) args) {
  final name = displayAlpha(args.id);
  return args.quantified ? name : '`$name';
}

String displayAlpha(int i) => String.fromCharCode(97 + i % 26) * (i ~/ 26 + 1);

CodeSpan locationForErrorUnderlineOfPattern(Pattern pattern) => switch (pattern) {
  Identifier(:final name) =>
      name.span,
  RecordDestructure(:final openBrace, :final closeBrace) =>
      openBrace.span.extendedBy(closeBrace.span),
  TagPattern(:final tag) =>
      tag.span,
};


CodeSpan? locationForErrorUnderline(Expr expr) => switch (expr) {

  Return(:final keyword) =>
      keyword.span,

  Variable(:final name) =>
      name.span,


  Literal(:final token) =>
      token.span,


  Grouping(:final expr) =>
      locationForErrorUnderline(expr),


  Lambda(
    :final params,
    body: ArrowExpression(:final arrow),
  ) =>
      params
        .map(locationForErrorUnderlineOfPattern)
        .reduce(extend)
        .extendedBy(arrow.span),


  Lambda(
    :final params,
    body: FunctionBody(body: Block(:final openBrace)),
  ) =>
      params
        .map(locationForErrorUnderlineOfPattern)
        .reduce(extend)
        .extendedBy(openBrace.span),


  Call(:final callee) =>
      locationForErrorUnderline(callee),


  ListLiteral(:final openBracket, :final closingBracket) =>
      openBracket.span.extendedBy(closingBracket.span),


  IfExpression(
    :final ifKeyword,
    :final condition,
    :final ifTrue,
    :final ifFalse,
  ) =>
      [
        ifKeyword.span,
        locationForErrorUnderline(condition),
        locationForErrorUnderline(ifTrue),
        locationForErrorUnderline(ifFalse),
      ].whereNotNull().reduce(extend),


  LogicalAnd(:final left, :final keyword, :final right) ||
  LogicalOr(:final left, :final keyword, :final right) ||
  Binary(:final left, operator: final keyword, :final right) =>
      [
        locationForErrorUnderline(left),
        keyword.span,
        locationForErrorUnderline(right),
      ].whereNotNull().reduce(extend),


  Record(:final closingBrace) =>
      closingBrace.span, // todo


  RecordGet(:final name, :final record) =>
      [
        locationForErrorUnderline(record),
        name.span,
      ].whereNotNull().reduce(extend),


  RecordUpdate(:final closingBrace) =>
      closingBrace.span, // todo


  UnaryMinus(:final operator, :final expr) ||
  UnaryBang(:final operator, :final expr) =>
      [
        operator.span,
        locationForErrorUnderline(expr),
      ].whereNotNull().reduce(extend),


  TagConstructor(:final tag, :final payload) =>
      [
        tag.span,
        if (payload != null) locationForErrorUnderline(payload),
      ].whereNotNull().reduce(extend),


  TagMatch(:final keyword) =>
      keyword.span,

  Import(:final keyword) =>
      keyword.span,

  TagCastOk(:final operator) =>
      operator.span,

  BlockExpr(:final openBrace, :final closeBrace) =>
    openBrace.span.extendedBy(closeBrace.span),
};
