import 'package:lox/src/expr.dart';
import 'package:lox/src/hindley_milner_api.dart';
import 'package:lox/src/hindley_milner_lambda_calculus.dart';
import 'package:lox/src/parser.dart';
import 'package:lox/src/scanner.dart';
import 'package:lox/src/utils.dart';
import 'package:test/test.dart';

import 'test_matchers.dart';

void main() {
  test('inference', () {
    // let f = \y -> y in f x
    final context = {'x': num_t};
    final expr = LetExpression(
      'f',
      AbstractionExpression('y', VariableExpression('y')),
      ApplicationExpression(
        VariableExpression('f'),
        VariableExpression('x'),
      ),
    );

    final (substitution, t) = w(expr, context);
    final result = substitution.apply(t);
    expect(result, num_t);
  });

  test('curry', () {

    final id = (String named, [int line = 1]) => Token(TokenType.IDENTIFIER, named, null, line);
    final plus = Token(TokenType.PLUS, '+', null, 1);
    final unused = newUnused(1);
    final arrow = newArrow(1);
    
    final currySource = (String source) => curry(parseExpression(source) as Lambda);

    expect(
      currySource(r'\ -> x'),
      (unused, Variable(id('x'))),
    );

    expect(
      currySource(r'\x -> x'),
      (id('x'), Variable(id('x'))),
    );

    expect(
      currySource(r'\x, y -> x + y'),
      (id('x'), Lambda([id('y')], ArrowExpression(arrow, Binary(Variable(id('x')), plus, Variable(id('y')))))),
    );

    expect(
      currySource(r'\x, y, z -> x + y + z'),
      (id('x'), Lambda([id('y')], ArrowExpression(arrow, Lambda([id('z')], ArrowExpression(arrow, Binary(Binary(Variable(id('x')), plus, Variable(id('y'))), plus, Variable(id('z')))))))),
    );

    expect(
      currySource(r'\x -> \x -> x'),
      (id('x'), Lambda([id('x')], ArrowExpression(arrow, Variable(id('x'))))),
    );
  });

  test('lox inference', () {
    expect(inferSource(r'(\x -> x)(1)'), num_t);
    expect(inferSource(r'(\x -> 1)([])'), num_t);
    expect(inferSource(r'(\x -> x)([])'), matchesTypeFunctionApplication(name: kList, monoTypes: hasLength(1)));
    expect(inferSource(r'(\x -> [])(1)'), matchesTypeFunctionApplication(name: kList, monoTypes: hasLength(1)));
  });
}

const numOp = TypeFunctionApplication(
  kFunction, [ num_t, TypeFunctionApplication(kFunction, [ num_t, num_t ])]
);
const boolOp = TypeFunctionApplication(
  kFunction, [ bool_t, TypeFunctionApplication(kFunction, [ bool_t, bool_t ])]
);

const emptyList = TypeQuantifier('a', TypeFunctionApplication(kList, [TypeVariable('a')]));
const listFirst = TypeQuantifier('a', TypeFunctionApplication(kFunction, [ TypeFunctionApplication(kList, [TypeVariable('a')]), TypeVariable('a')]));
const listRest = TypeQuantifier('a', TypeFunctionApplication(kFunction, [ TypeFunctionApplication(kList, [TypeVariable('a')]), TypeFunctionApplication(kList, [TypeVariable('a')])]));
const listEmpty = TypeQuantifier('a', TypeFunctionApplication(kFunction, [ TypeFunctionApplication(kList, [TypeVariable('a')]), bool_t]));

const Context loxStandardLibraryContext = {
  '+': numOp,
  '-': numOp,
  '*': numOp,
  '/': numOp,
  'or': boolOp,
  'and': boolOp,
  '[]': emptyList,
  'List.first': listFirst,
  'List.rest': listRest,
  'List.empty': listEmpty,
};

MonoType inferSource(String source) {
  final expr = parseExpression(source);
  final context = <String, PolyType>{
    ...loxStandardLibraryContext,
  };
  return infer(expr, context);
}

Expr parseExpression(String source) {
  if (!source.endsWith(';')) source = '$source;';
  final statements = source
      .run(scanTokens)
      .run(Parser.new)
      .parse();
  final expr = (statements.single as ExpressionStatement).expr;
  return expr;
}

MonoType infer(Expr expression, Context context) {
  final (type, _) = _infer(expression, context);
  return type;
}

(MonoType, Substitution) _infer(Expr expression, Context context) {
  switch (expression) {
    case Variable(name: Token(lexeme: final name)):
      return varRule(name, context);
    case Lambda():
      final (param, body) = curry(expression);
      return absRule(param.lexeme, body, context);
    case Call(callee: final func, :final args):
      final arg = (args as ExpressionArgs).exprs.single; // TODO: desugar to nested single-arg calls
      return appRule(arg, func, context);
    case FalseLiteral() || TrueLiteral():
      return (instantiate(bool_t), {});
    case StringLiteral():
      return (instantiate(string_t), {});
    case NumberLiteral():
      return (instantiate(num_t), {});
    case ListLiteral(elements: []):
      return (instantiate(emptyList), {});
    case Grouping(:final expr):
      return _infer(expr, context);
    case Binary():
    case ListLiteral():
    case LogicalAnd():
    case LogicalOr():
    case Ternary():
    case Record():
    case FieldAccess():
    case NilLiteral():
    case UnaryMinus():
    case UnaryBang():
      throw 'unsupported $expression';
  }
}

(MonoType, Substitution) varRule(String name, Context context) {
  final type = context[name];
  if (type == null) throw 'Undefined variable $name';
  return (instantiate(type), {});
}

(MonoType, Substitution) absRule(String param, Expr body, Context context) {
  final solveFor = TypeVariable.fresh();
  final (retType, retSubstitution) = _infer(body, {
    ...context,
    param: solveFor,
  });
  final exprType = retSubstitution.apply(function_t(solveFor, retType));
  return (exprType, retSubstitution);
}

(MonoType, Substitution) appRule(Expr arg, Expr func, Context context) {
  final (funcType, funcSubstitution) = _infer(func, context);
  final (argType, argSubstitution) = _infer(arg, funcSubstitution.applyContext(context));
  final solveFor = TypeVariable.fresh();
  final unifiedSubstitution = unify(
    argSubstitution.apply(funcType),
    function_t(argType, solveFor),
  );
  final exprType = unifiedSubstitution.apply(solveFor);
  return (exprType, combine([funcSubstitution, argSubstitution, unifiedSubstitution]));
}


final newUnused = (int line) => Token(TokenType.UNDERSCORE, '_', null, line);
final newArrow = (int line) => Token(TokenType.ARROW, '->', null, line);

(Token, Expr) curry(Lambda lambda) {
  final Lambda(:params, :body) = lambda;
  final (fnStart, fnBody) =  switch (body) {
    ArrowExpression(:final arrow, :final body) =>
        (arrow, body),
    FunctionBody(body: Block(:final openBrace, :final statements)) =>
        throw 'only expression bodies for now'
  };
  return _curry(params, fnStart, fnBody);
}

//
// IN:  \ -> 2
// OUT: \_ -> 2
//
// IN:  \x -> x * 2
// OUT: \x -> x * 2
//
// IN:  \x, y -> x + y * 2
// OUT: \x -> \y -> x + y * 2
//
(Token, Expr) _curry(List<Token> params, Token arrow, Expr body) {

  final newLambda = (List<Token> params, Expr body) =>
      Lambda(params, ArrowExpression(arrow, body));

  return switch (params) {
    [] =>
        (newUnused(arrow.line), body),
    [final x] =>
        (x, body),
    [final x, final y] =>
        (x, newLambda([y], body)),
    [final x, final y, ...final rest] => () {
        final (param, newBody) = _curry(rest, arrow, body);
        return (x, newLambda([y], newLambda([param], newBody)));
    } (),
  };
}
