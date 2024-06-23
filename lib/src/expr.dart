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

class Grouping extends Expr {
  final Expr expr;
  Grouping(this.expr);
}

class Variable extends Expr {
  final Token name;
  Variable(this.name);
}

String parens(String label, Iterable<Expr> exprs) =>
    '($label ${exprs.map(display).join(' ')})';

String display(Expr expr) => switch (expr) {
  Literal(:final value)                              => value?.toString() ?? 'nil',
  Unary(:final operator, :final expr)                => parens(operator.lexeme, [expr]),
  Binary(:final operator, :final left, :final right) => parens(operator.lexeme, [left, right]),
  Grouping(:final expr)                              => parens('group', [expr]),
  Variable(:final name)                              => 'var ${name.lexeme}',
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
class VariableDeclaration extends Statement {
  final Token name;
  final Expr? initializer;
  VariableDeclaration(this.name, this.initializer);
}