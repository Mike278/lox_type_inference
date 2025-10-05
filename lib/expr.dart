import 'package:equatable/equatable.dart';
import 'package:lox/hindley_milner_lox.dart' show LoxType;
import 'package:lox/token.dart';

// ignore_for_file: must_be_immutable

sealed class Expr with EquatableMixin  {
  LoxType? type;
  @override get props => [type];
}

class Return extends Expr with EquatableMixin {
  final Token keyword;
  final Expr? expr;
  Return(this.keyword, this.expr);
  @override get props => [...super.props, keyword, expr];
}

sealed class Literal extends Expr with EquatableMixin {
  final Token token;
  late final Object? value = token.literal;
  Literal(this.token);
  @override get props => [...super.props, value];
}

class StringLiteral extends Literal {
  StringLiteral(super.token);
  @override String get value => super.value as String;
}
class NumberLiteral extends Literal {
  NumberLiteral(super.token);
  @override num get value => super.value as num;
}
class FalseLiteral extends Literal {
  FalseLiteral(super.token);
  @override bool get value => false;
}
class TrueLiteral extends Literal {
  TrueLiteral(super.token);
  @override bool get value => true;
}
class NilLiteral extends Literal {
  NilLiteral(super.token);
  @override Null get value => null;
}

sealed class Unary extends Expr with EquatableMixin {
  final Token operator;
  final Expr expr;
  Unary(this.operator, this.expr);
  @override get props => [...super.props, operator, expr];
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
  @override get props => [...super.props, left, operator, right];
}

class LogicalAnd extends Expr with EquatableMixin {
  final Expr left;
  final Token keyword;
  final Expr right;
  LogicalAnd(this.left, this.keyword, this.right);
  @override get props => [...super.props, left, keyword, right];
}

class LogicalOr extends Expr with EquatableMixin {
  final Expr left;
  final Token keyword;
  final Expr right;
  LogicalOr(this.left, this.keyword, this.right);
  @override get props => [...super.props, left, keyword, right];
}

sealed class LambdaBody {}
class ArrowExpression with EquatableMixin implements LambdaBody {
  final Token arrow;
  final Expr body;
  ArrowExpression(this.arrow, this.body);
  @override get props => [arrow, body];
}
class FunctionBody with EquatableMixin  implements LambdaBody {
  final Token openBrace;
  final List<Statement> body;
  final Token closeBrace;
  FunctionBody(this.openBrace, this.body, this.closeBrace);
  @override get props => [openBrace, body, closeBrace];
}
class Lambda extends Expr with EquatableMixin {
  final List<Pattern> params;
  final LambdaBody body;
  Lambda(this.params, this.body);
  @override get props => [...super.props, params, body];
}

class Grouping extends Expr with EquatableMixin {
  final Expr expr;
  Grouping(this.expr);
  @override get props => [...super.props, expr];
}

class Variable extends Expr with EquatableMixin {
  final Token name;
  Variable(this.name);
  @override get props => [...super.props, name];
}
class Call extends Expr with EquatableMixin {
  final Expr callee;
  final CallArgs args;
  final Token closingParen;
  Call(this.callee, this.args, this.closingParen);
  @override get props => [...super.props, callee, args, closingParen];
}
sealed class CallArgs {}
class ArgsWithPlaceholder with EquatableMixin implements CallArgs {
  final List<Expr> before;
  final Token placeholder;
  LoxType? placeholderType;
  final List<Expr> after;
  ArgsWithPlaceholder(this.before, this.placeholder, this.after);
  @override get props => [before, placeholder, placeholderType, after];
}
class ExpressionArgs with EquatableMixin implements CallArgs {
  final List<Expr> exprs;
  ExpressionArgs(this.exprs);
  @override get props => [exprs];
}

class IfExpression extends Expr with EquatableMixin {
  final Token ifKeyword;
  final Expr condition;
  final Expr ifTrue;
  final Expr? ifFalse;
  IfExpression(this.ifKeyword, this.condition, this.ifTrue, this.ifFalse);
  @override get props => [...super.props, ifKeyword, condition, ifTrue, ifFalse];
}

class Record extends Expr with EquatableMixin {
  final Token closingBrace;
  final Map<Token, Expr> fields;
  Record(this.closingBrace, this.fields);
  @override get props => [...super.props, closingBrace, fields];
}
class RecordGet extends Expr with EquatableMixin {
  final Expr record;
  final Token name;
  RecordGet(this.record, this.name);
  @override get props => [...super.props, record, name];
}
class RecordUpdate extends Expr with EquatableMixin {
  final Token dotdot;
  final Expr record;
  final Map<Token, Expr> newFields;
  final Token closingBrace;
  RecordUpdate(this.dotdot, this.record, this.newFields, this.closingBrace);
  @override get props => [...super.props, dotdot, record, newFields, closingBrace];
}
class ListLiteral extends Expr with EquatableMixin {
  final Token openBracket;
  final Token closingBracket;
  final List<ListElement> elements;
  ListLiteral(this.openBracket, this.closingBracket, this.elements);
  @override get props => [...super.props, openBracket, closingBracket, elements];
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

class TagConstructor extends Expr with EquatableMixin {
  final Token tag;
  final Expr? payload;
  TagConstructor(this.tag, this.payload);
  @override get props => [...super.props, tag, payload];
}

class TagMatch extends Expr with EquatableMixin {
  final Token keyword;
  final Expr tag;
  final (Token, Token) braces;
  final List<TagMatchCase> cases;
  TagMatch(this.keyword, this.tag, this.braces, this.cases);
  @override get props => [...super.props, keyword, tag, braces, cases];
}

typedef TagMatchCase = ({
  Pattern pattern,
  Token arrow,
  Expr result,
});

class Import extends Expr with EquatableMixin {
  final Token keyword;
  final Token target;
  late final path = ImportPath(target.literal as String);
  Import({required this.keyword, required this.target});
  @override get props => [...super.props, keyword, target];
}
extension type ImportPath(String literal) {}
typedef Exports = Map<Pattern, Expr>;
typedef ResolveImport = Exports Function(ImportPath);

class TagCastOk extends Expr with EquatableMixin {
  final Expr expr;
  final Token operator;
  final Expr? fallback;
  TagCastOk(this.expr, this.operator, this.fallback);
  @override get props => [...super.props, expr, operator, fallback];
}

class BlockExpr extends Expr with EquatableMixin {
  final Token openBrace;
  final List<Statement> statements;
  final Token closeBrace;
  BlockExpr(this.openBrace, this.statements, this.closeBrace) : assert(statements.isNotEmpty);
}

class Print extends Expr {
  final Expr expr;
  final Token keyword;
  Print(this.expr, this.keyword);
}
class Assertion extends Expr {
  final Token keyword;
  final String source;
  final Expr expr;
  Assertion(this.keyword, this.source, this.expr);
}

sealed class Statement {}
class ExpressionStatement extends Statement {
  final Expr expr;
  final Token semicolon;
  ExpressionStatement(this.expr, this.semicolon);
}
class LetDeclaration extends Statement {
  final Token keyword;
  final Pattern pattern;
  final Expr initializer;
  LetDeclaration(this.keyword, this.pattern, this.initializer);
}
class IfStatement extends Statement {
  final Token keyword;
  final Expr condition;
  final List<Statement> thenBranch;
  final List<Statement> elseBranch;
  IfStatement(this.keyword, this.condition, this.thenBranch, this.elseBranch);
}

sealed class Pattern {}

class Identifier extends Pattern with TypeReference {
  final Token name;
  Identifier(this.name);
}

class RecordDestructure extends Pattern {
  final Token openBrace;
  final Token closeBrace;
  final List<RecordDestructuringElement> elements;
  RecordDestructure({
    required this.openBrace,
    required this.elements,
    required this.closeBrace,
  });
}
class RecordDestructuringElement with TypeReference {
  final Token name;
  final Pattern? pattern;
  RecordDestructuringElement(this.name, [this.pattern]);
}

class TagPattern extends Pattern with TypeReference {
  final Token tag;
  final Pattern? payload;
  TagPattern(this.tag, this.payload);
}

mixin TypeReference {
  LoxType? Function()? _type;
  LoxType? get type => _type?.call();
  void copyTypeOf(Expr expr) => _type = () => expr.type;
  set type(LoxType type) => _type = () => type;
}

extension StatementAPI on Statement {
  Iterable<Expr> allExpressions() sync* {
    switch (this) {
      case ExpressionStatement(:final expr):
        yield* expr.subExpressions();
      case LetDeclaration(:final initializer):
        yield* initializer.subExpressions();
      case IfStatement(:final condition, :final thenBranch, :final elseBranch):
        yield* condition.subExpressions();
        for (final branch in thenBranch) yield* branch.allExpressions();
        for (final branch in elseBranch) yield* branch.allExpressions();
    }
  }
  Iterable<Pattern> allPatterns() sync* {
    switch (this) {
      case ExpressionStatement(:final expr):
        yield* expr.allPatterns();
      case LetDeclaration(:final pattern, :final initializer):
        yield* pattern.subPatterns();
        yield* initializer.allPatterns();
      case IfStatement(:final condition, :final thenBranch, :final elseBranch):
        yield* condition.allPatterns();
        for (final branch in thenBranch) yield* branch.allPatterns();
        for (final branch in elseBranch) yield* branch.allPatterns();
    }
  }
}

extension ExprAPI on Expr {
  Iterable<Expr> subExpressions() sync* {
    yield this;
    switch (this) {
      case Return(:final expr):
        if (expr != null) yield* expr.subExpressions();
      case Binary(:final left, :final right):
      case LogicalAnd(:final left, :final right):
      case LogicalOr(:final left, :final right):
        yield* left.subExpressions();
        yield* right.subExpressions();
      case Assertion(:final expr):
      case Print(:final expr):
      case UnaryMinus(:final expr):
      case UnaryBang(:final expr):
      case Grouping(:final expr):
        yield* expr.subExpressions();
      case Lambda(:final body): switch (body) {
        case ArrowExpression(:final body):
          yield* body.subExpressions();
        case FunctionBody(:final body):
          for (final statement in body) {
            yield* statement.allExpressions();
          }
      }
      case Call(:final callee, :final args):
        yield* callee.subExpressions();
        switch (args) {
          case ArgsWithPlaceholder(:final before, :final after):
            for (final expr in before) yield* expr.subExpressions();
            for (final expr in after) yield* expr.subExpressions();
          case ExpressionArgs(:final exprs):
            for (final expr in exprs) yield* expr.subExpressions();
        }
      case IfExpression(:final condition, :final ifTrue, :final ifFalse):
        yield* condition.subExpressions();
        yield* ifTrue.subExpressions();
        if (ifFalse != null) yield* ifFalse.subExpressions();
      case TagConstructor(:final payload):
        if (payload != null)
        yield* payload.subExpressions();
      case Record(:final fields):
        for (final expr in fields.values) yield* expr.subExpressions();
      case RecordGet(:final record):
        yield* record.subExpressions();
      case RecordUpdate(:final record, :final newFields):
        yield* record.subExpressions();
        for (final expr in newFields.values) yield* expr.subExpressions();
      case ListLiteral(:final elements):
        for (final e in elements) {
          switch (e) {
            case ExpressionListElement(:final expr):
            case SpreadListElement(:final expr):
              yield* expr.subExpressions();
          }
        }
      case TagMatch(:final tag, :final cases):
        yield* tag.subExpressions();
        for (final case_ in cases) yield* case_.result.subExpressions();
      case TagCastOk(:final expr, :final fallback):
        yield* expr.subExpressions();
        if (fallback != null) yield* fallback.subExpressions();
      case BlockExpr(:final statements):
        for (final statement in statements)
          yield* statement.allExpressions();
      case Import():
      case Variable():
      case StringLiteral():
      case NumberLiteral():
      case FalseLiteral():
      case TrueLiteral():
      case NilLiteral():
    }
  }
  
  Iterable<Pattern> allPatterns() sync* {
    switch (this) {
      case Return(:final expr):
        if (expr != null) yield* expr.allPatterns();
      case Binary(:final left, :final right):
      case LogicalAnd(:final left, :final right):
      case LogicalOr(:final left, :final right):
        yield* left.allPatterns();
        yield* right.allPatterns();
      case Assertion(:final expr):
      case Print(:final expr):
      case UnaryMinus(:final expr):
      case UnaryBang(:final expr):
      case Grouping(:final expr):
        yield* expr.allPatterns();
      case Lambda(:final params, :final body):
        for (final p in params) yield* p.subPatterns();
        switch (body) {
          case ArrowExpression(:final body):
            yield* body.allPatterns();
          case FunctionBody(:final body):
            for (final statement in body) {
              yield* statement.allPatterns();
            }
        }
      case Call(:final callee, :final args):
        yield* callee.allPatterns();
        switch (args) {
          case ArgsWithPlaceholder(:final before, :final after):
            for (final expr in before) yield* expr.allPatterns();
            for (final expr in after) yield* expr.allPatterns();
          case ExpressionArgs(:final exprs):
            for (final expr in exprs) yield* expr.allPatterns();
        }
      case IfExpression(:final condition, :final ifTrue, :final ifFalse):
        yield* condition.allPatterns();
        yield* ifTrue.allPatterns();
        if (ifFalse != null) yield* ifFalse.allPatterns();
      case TagConstructor(:final payload):
        if (payload != null)
        yield* payload.allPatterns();
      case Record(:final fields):
        for (final expr in fields.values) yield* expr.allPatterns();
      case RecordGet(:final record):
        yield* record.allPatterns();
      case RecordUpdate(:final record, :final newFields):
        yield* record.allPatterns();
        for (final expr in newFields.values) yield* expr.allPatterns();
      case ListLiteral(:final elements):
        for (final e in elements) {
          switch (e) {
            case ExpressionListElement(:final expr):
            case SpreadListElement(:final expr):
              yield* expr.allPatterns();
          }
        }
      case TagMatch(:final tag, :final cases):
        yield* tag.allPatterns();
        for (final TagMatchCase(:pattern, :result) in cases) {
          yield* pattern.subPatterns();
          yield* result.allPatterns();
        }
      case TagCastOk(:final expr, :final fallback):
        yield* expr.allPatterns();
        if (fallback != null) yield* fallback.allPatterns();
      case BlockExpr(:final statements):
        for (final statement in statements)
          yield* statement.allPatterns();
      case Import():
      case Variable():
      case StringLiteral():
      case NumberLiteral():
      case FalseLiteral():
      case TrueLiteral():
      case NilLiteral():
    }
  }
}

extension PatternAPI on Pattern {
  
  Iterable<Pattern> subPatterns() sync* {
    yield this;
    switch (this) {
      case RecordDestructure(:final elements):
        for (final e in elements) 
          if (e.pattern case final pattern?) 
            yield* pattern.subPatterns();
      case TagPattern(:final payload):
        if (payload != null)
          yield* payload.subPatterns();
      case Identifier():
    }
  }
}