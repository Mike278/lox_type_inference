import 'package:lox/src/lox_base.dart';

sealed class Expr {}

sealed class Literal extends Expr {
  final Object? value;
  Literal(this.value);
}

class StringLiteral extends Literal {
  StringLiteral(String super.value);
}
class NumberLiteral extends Literal {
  NumberLiteral(num super.value);
}
class FalseLiteral extends Literal {
  FalseLiteral() : super(false);
}
class TrueLiteral extends Literal {
  TrueLiteral() : super(true);
}
class NilLiteral extends Literal {
  NilLiteral() : super(null);
}

sealed class Unary extends Expr {
  final Token operator;
  final Expr expr;
  Unary(this.operator, this.expr);
}
class UnaryMinus extends Unary {
  UnaryMinus(super.operator, super.expr);
}
class UnaryBang extends Unary {
  UnaryBang(super.operator, super.expr);
}

class Binary extends Expr {
  final Expr left;
  final Token operator;
  final Expr right;
  Binary(this.left, this.operator, this.right);
}

class LogicalAnd extends Expr {
  final Expr left;
  final Token keyword;
  final Expr right;
  LogicalAnd(this.left, this.keyword, this.right);
}

class LogicalOr extends Expr {
  final Expr left;
  final Token keyword;
  final Expr right;
  LogicalOr(this.left, this.keyword, this.right);
}

class Grouping extends Expr {
  final Expr expr;
  Grouping(this.expr);
}

class Variable extends Expr {
  final Token name;
  Variable(this.name);
}
class Call extends Expr {
  final Expr callee;
  final List<Expr> args;
  final Token closingParen;
  Call(this.callee, this.args, this.closingParen);
}
class Ternary extends Expr {
  final Token questionMark;
  final Expr condition;
  final Expr ifTrue;
  final Expr ifFalse;
  Ternary(this.questionMark, this.condition, this.ifTrue, this.ifFalse);
}

class Record extends Expr {
  final Token closingBrace;
  final Map<Token, Expr> fields;
  Record(this.closingBrace, this.fields);
}
class FieldAccess extends Expr {
  final Expr record;
  final Token name;
  FieldAccess(this.record, this.name);
}


String parens(String label, Iterable<Expr> exprs) =>
    '($label ${exprs.map(display).join(' ')})';

String display(Expr expr) => switch (expr) {
  Literal(:final value)                                    => value?.toString() ?? 'nil',
  Unary(:final operator, :final expr)                      => parens(operator.lexeme, [expr]),
  Binary(:final operator, :final left, :final right)       => parens(operator.lexeme, [left, right]),
  Grouping(:final expr)                                    => parens('group', [expr]),
  Variable(:final name)                                    => 'let ${name.lexeme}',
  Call(:final callee, :final args)                         => parens('call', [callee, ...args]),
  LogicalAnd(:final left, :final keyword, :final right) ||
  LogicalOr(:final left, :final keyword, :final right)     => parens(keyword.lexeme, [left, right]),
  Ternary(:final condition, :final ifTrue, :final ifFalse) => parens('?:', [condition, ifTrue, ifFalse]),
  Record(:final fields)                                    => parens('rec', fields.values),
  FieldAccess(:final record, :final name)                  => parens('${name.lexeme}.', [record]),
};



sealed class Statement {}
class ExpressionStatement extends Statement {
  final Expr expr;
  ExpressionStatement(this.expr);
}
class PrintStatement extends Statement {
  final Expr expr;
  PrintStatement(this.expr);
}
class LetDeclaration extends Statement {
  final Token name;
  final Expr initializer;
  LetDeclaration(this.name, this.initializer);
}
class Block extends Statement {
  final List<Statement> statements;
  Block(this.statements);
}
class FunctionDeclaration extends Statement {
  final Token name;
  final List<Token> params;
  final List<Statement> body;
  FunctionDeclaration(this.name, this.params, this.body);
}
class ReturnStatement extends Statement {
  final Token keyword;
  final Expr? expr;
  ReturnStatement(this.keyword, this.expr);
}
class IfStatement extends Statement {
  final Token keyword;
  final Expr condition;
  final Statement thenBranch;
  final Statement? elseBranch;
  IfStatement(this.keyword, this.condition, this.thenBranch, this.elseBranch);
}