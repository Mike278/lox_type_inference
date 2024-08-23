import 'package:equatable/equatable.dart';
import 'package:lox/src/scanner.dart';

sealed class Expr {}

sealed class Literal extends Expr with EquatableMixin {
  final Object? value;
  Literal(this.value);
  @override get props => [value];
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

sealed class Unary extends Expr with EquatableMixin {
  final Token operator;
  final Expr expr;
  Unary(this.operator, this.expr);
  @override get props => [operator, expr];
}
class UnaryMinus extends Unary {
  UnaryMinus(super.operator, super.expr);
}
class UnaryBang extends Unary {
  UnaryBang(super.operator, super.expr);
}

class Binary extends Expr with EquatableMixin {
  final Expr left;
  final Token operator;
  final Expr right;
  Binary(this.left, this.operator, this.right);
  @override get props => [left, operator, right];
}

class LogicalAnd extends Expr with EquatableMixin {
  final Expr left;
  final Token keyword;
  final Expr right;
  LogicalAnd(this.left, this.keyword, this.right);
  @override get props => [left, keyword, right];
}

class LogicalOr extends Expr with EquatableMixin {
  final Expr left;
  final Token keyword;
  final Expr right;
  LogicalOr(this.left, this.keyword, this.right);
  @override get props => [left, keyword, right];
}

sealed class LambdaBody {}
class ArrowExpression with EquatableMixin implements LambdaBody {
  final Token arrow;
  final Expr body;
  ArrowExpression(this.arrow, this.body);
  @override get props => [arrow, body];
}
class FunctionBody with EquatableMixin  implements LambdaBody {
  final Block body;
  FunctionBody(this.body);
  @override get props => [body];
}
class Lambda extends Expr with EquatableMixin {
  final List<Token> params;
  final LambdaBody body;
  Lambda(this.params, this.body);
  @override get props => [params, body];
}

class Grouping extends Expr with EquatableMixin {
  final Expr expr;
  Grouping(this.expr);
  @override get props => [expr];
}

class Variable extends Expr with EquatableMixin {
  final Token name;
  Variable(this.name);
  @override get props => [name];
}
class Call extends Expr with EquatableMixin {
  final Expr callee;
  final CallArgs args;
  final Token closingParen;
  Call(this.callee, this.args, this.closingParen);
  @override get props => [callee, args, closingParen];
}
sealed class CallArgs {}
class ArgsWithPlaceholder with EquatableMixin implements CallArgs {
  final List<Expr> before;
  final Token placeholder;
  final List<Expr> after;
  ArgsWithPlaceholder(this.before, this.placeholder, this.after);
  @override get props => [before, placeholder, after];
}
class ExpressionArgs with EquatableMixin implements CallArgs {
  final List<Expr> exprs;
  ExpressionArgs(this.exprs);
  @override get props => [exprs];
}

class Ternary extends Expr with EquatableMixin {
  final Token questionMark;
  final Expr condition;
  final Expr ifTrue;
  final Expr ifFalse;
  Ternary(this.questionMark, this.condition, this.ifTrue, this.ifFalse);
  @override get props => [questionMark, condition, ifTrue, ifFalse];
}

class Record extends Expr with EquatableMixin {
  final Token closingBrace;
  final Map<Token, Expr> fields;
  Record(this.closingBrace, this.fields);
  @override get props => [closingBrace, fields];
}
class FieldAccess extends Expr with EquatableMixin {
  final Expr record;
  final Token name;
  FieldAccess(this.record, this.name);
  @override get props => [record, name];
}
class ListLiteral extends Expr with EquatableMixin {
  final Token closingBracket;
  final List<ListElement> elements;
  ListLiteral(this.closingBracket, this.elements);
  @override get props => [closingBracket, elements];
}
sealed class ListElement {}
class ExpressionListElement with EquatableMixin implements ListElement {
  final Expr expr;
  ExpressionListElement(this.expr);
  @override get props => [expr];
}
class SpreadListElement with EquatableMixin implements ListElement {
  final Token dotdot;
  final Expr expr;
  SpreadListElement(this.dotdot, this.expr);
  @override get props => [dotdot, expr];
}


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
  final Token openBrace;
  final List<Statement> statements;
  final Token closeBrace;
  Block(this.openBrace, this.statements, this.closeBrace);
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