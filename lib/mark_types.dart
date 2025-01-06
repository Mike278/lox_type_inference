import 'package:lox/expr.dart';
import 'package:lox/hindley_milner_api.dart';
import 'package:lox/lox_lambda_calculus.dart';
import 'package:lox/parser.dart';
import 'package:lox/scanner.dart';
import 'package:lox/utils.dart';

typedef MarkText = (CodeSpan, {String display});
typedef CodeSpan = ({CodePosition from, CodePosition to});
typedef CodePosition = ({int line, int offset});

extension on Token {
  CodeSpan get span {
    final from = (line: line-1, offset: offset);
    final to = (line: line-1, offset: offset + lexeme.length);
    return (from: from, to: to);
  }
}

(List<MarkText>, {String errorOutput}) markTypes(String source) {

  final output = [];
  reportError(kind) => (err) => output.add('$kind:\n$err');

  final (tokens, hadError: hadScanError) = scanTokens(source, reportError('scan error'));
  final (statements, hadError: hadParseError) = Parser(tokens, reportError('parse error')).parse();

  if (hadParseError || hadScanError) return (errorOutput: output.join('\n'), []);

  final marks = <MarkText>[];
  try {
    final lookup = runInference(statements);
    final typeOf = (Expr expr) {
      final type = lookup[expr];
      return type;
    };
    final hovers = buildHoverInfo(statements, typeOf);
    for (final (span, :display) in hovers) {
      marks.add((
        span,
        display: display,
      ));
    }

  } catch (e) {
    reportError('typecheck error')(e);
  }

  return (
    errorOutput: output.join('\n'),
    marks,
  );
}

typedef TypeOf = Ty? Function(Expr);

List<(CodeSpan, {String display})> buildHoverInfo(
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
