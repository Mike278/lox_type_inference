import 'package:lox/src/expr.dart';
import 'package:lox/src/hindley_milner_api.dart';
import 'package:lox/src/hindley_milner_lambda_calculus.dart';
import 'package:lox/src/parser.dart';
import 'package:lox/src/scanner.dart';
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
    final questionMark = Token(TokenType.QUESTION, '?', null, 1);
    final unused = newUnused(1);
    final arrow = newArrow(1);
    
    final currySource = (String source) {
      final lambda = parseExpression(source) as Lambda;
      final (:arrow, :body) = asArrowExpression(lambda);
      return curry(lambda.params, arrow, body);
    };

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

    expect(
      currySource(r'\x, y, z -> x ? y : z'),
      (id('x'), Lambda([id('y')], ArrowExpression(arrow, Lambda([id('z')], ArrowExpression(arrow, Ternary(questionMark, Variable(id('x')), Variable(id('y')), Variable(id('z')))))))),
    );
  });

  test('lox inference', () {

    expect(inferSource(r'\  -> 1'),        _fn(_var('t0'), num_t));
    expect(inferSource(r'\x -> 1'),        _fn(_var('t0'), num_t));
    expect(inferSource(r'\x -> x'),        _fn(_var('t0'), _var('t0')));

    expect(inferSource(r'\x, y -> 1'),     _fn(_var('t0'), _fn(_var('t1'), num_t)));
    expect(inferSource(r'\x, y -> x'),     _fn(_var('t0'), _fn(_var('t1'), _var('t0'))));
    expect(inferSource(r'\x, y -> y'),     _fn(_var('t0'), _fn(_var('t1'), _var('t1'))));
    expect(inferSource(r'\x, y -> []'),    _fn(_var('t0'), _fn(_var('t1'), _list('t2'))));
    expect(inferSource(r'\x, y -> x(y)'),  _fn(_fn(_var('t1'), _var('t2')), _fn(_var('t1'), _var('t2'))));

    expect(inferSource(r'\x, y, z -> 1'),  _fn(_var('t0'), _fn(_var('t1'), _fn(_var('t2'), num_t))));
    expect(inferSource(r'\x, y, z -> x'),  _fn(_var('t0'), _fn(_var('t1'), _fn(_var('t2'), _var('t0')))));
    expect(inferSource(r'\x, y, z -> y'),  _fn(_var('t0'), _fn(_var('t1'), _fn(_var('t2'), _var('t1')))));
    expect(inferSource(r'\x, y, z -> z'),  _fn(_var('t0'), _fn(_var('t1'), _fn(_var('t2'), _var('t2')))));

    expect(inferSource(r'(\  -> 1)()'),   num_t);
    expect(inferSource(r'(\x -> x)(1)'),  num_t);
    expect(inferSource(r'(\x -> x)(-1)'),  num_t);
    expect(inferSource(r'(\x -> 1)([])'), num_t);
    expect(inferSource(r'(\x -> x)([])'), _list('t1'));
    expect(inferSource(r'(\x -> [])(1)'), _list('t1'));

    expect(inferSource(r'(\x, y -> 1)("ok", false)'), num_t);
    expect(inferSource(r'(\x, y -> x)("ok", false)'), string_t);
    expect(inferSource(r'(\x, y -> y)("ok", false)'), bool_t);

    expect(inferSource(r'\x, y -> x and y'), _fn(bool_t, _fn(bool_t, bool_t)));
    expect(inferSource(r'\x, y -> x or y'),  _fn(bool_t, _fn(bool_t, bool_t)));
    expect(inferSource(r'\x, y -> x + y'),   _fn(num_t, _fn(num_t, num_t)));
    expect(inferSource(r'\x, y -> x - y'),   _fn(num_t, _fn(num_t, num_t)));
    expect(inferSource(r'\x, y -> x * y'),   _fn(num_t, _fn(num_t, num_t)));
    expect(inferSource(r'\x, y -> x / y'),   _fn(num_t, _fn(num_t, num_t)));
    expect(inferSource(r'\x, y -> -x'),      _fn(num_t, _fn(_var('t1'), num_t)));
    expect(inferSource(r'\x, y -> x - -y'),  _fn(num_t, _fn(num_t, num_t)));

    expect(inferSource(r'\c, x, y -> c ? x : y').toString(),  'Function[Bool, Function[t6, Function[t6, t6]]]');
    expect(inferSource(r'\c, x, y -> c ? x : y'),  _fn(bool_t, _fn(_var('t6'), _fn(_var('t6'), _var('t6')))));
  });
}

final _list = (String typeVariableName) => 
  matchesTypeFunctionApplication(name: kList, monoTypes: [_var(typeVariableName)]);

final _var = (String typeVariableName) => matchesTypeVariable(name: typeVariableName);

final _fn = (a, b) => 
  matchesTypeFunctionApplication(
    name: kFunction,
    monoTypes: [a, b],
  );

const numOp = TypeFunctionApplication(
  kFunction, [ num_t, TypeFunctionApplication(kFunction, [ num_t, num_t ])]
);
const boolOp = TypeFunctionApplication(
  kFunction, [ bool_t, TypeFunctionApplication(kFunction, [ bool_t, bool_t ])]
);

const ternary =
  TypeQuantifier(
    'a',
    TypeFunctionApplication(
      kFunction,
      [
        bool_t, // todo works with TypeVariable('a')?
        TypeFunctionApplication(
          kFunction,
          [
            TypeVariable('a'), // todo works with bool_t?..
            TypeFunctionApplication(
              kFunction,
              [
                TypeVariable('a'),
                TypeVariable('a'),
              ],
            ),
          ],
        ),
      ],
    ),
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
  '!': boolOp,
  '?': ternary,
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
  final (tokens, hadError: _) = scanTokens(source, fail);
  final (statements, hadError: _) = Parser(tokens, fail).parse();
  final expr = (statements.single as ExpressionStatement).expr;
  return expr;
}

MonoType infer(Expr expression, Context context) {
  TypeVariable.counter = 0;
  final (type, _) = _infer(expression, context);
  return type;
}

(MonoType, Substitution) _infer(Expr expression, Context context) {
  switch (expression) {

    case Variable(name: Token(lexeme: final name)):
      return _varRule(name, context);

    case Lambda(
      :final params,
      body: ArrowExpression(
        :final arrow,
        :final body,
      ),
    ):
      final (param, curriedBody) = curry(params, arrow, body);
      return _absRule(param.lexeme, curriedBody, context);

    case Call(
      :final callee,
      args: ExpressionArgs(exprs: final args),
      :final closingParen,
    ):
      final (:arg, :func) = curriedCall(callee, args, closingParen);
      return appRule(arg: arg, func: func, context);

    case FalseLiteral() || TrueLiteral(): return (instantiate(bool_t), {});
    case StringLiteral():                 return (instantiate(string_t), {});
    case NumberLiteral():                 return (instantiate(num_t), {});
    case NilLiteral():                    return (instantiate(unit_t), {});
    case ListLiteral(elements: []):       return (instantiate(emptyList), {});

    case Grouping(:final expr):           return _infer(expr, context);

    case LogicalAnd(:final left, :final right, :final keyword):
    case LogicalOr(:final left, :final right, :final keyword):
    case Binary(:final left, :final right, operator: final keyword):
      final (:arg, :func) = curriedCall(Variable(keyword), [left, right], keyword);
      return appRule(arg: arg, func: func, context);

    case UnaryMinus(:final operator, :final expr):
      final (:arg, :func) = curriedCall(Variable(operator), [NumberLiteral(0), expr], operator);
      return appRule(arg: arg, func: func, context);

    case UnaryBang(:final operator, :final expr):
      return appRule(arg: expr, func: Variable(operator), context);

    case Ternary(:final condition, :final ifTrue, :final ifFalse, :final questionMark):
      final (:arg, :func) = curriedCall(Variable(questionMark), [condition, ifTrue, ifFalse], questionMark);
      return appRule(arg: arg, func: func, context);

    case Record():
    case FieldAccess():
    case ListLiteral(elements: [_, ...]):
    case Lambda(body: FunctionBody()):
    case Call(args: ArgsWithPlaceholder()):
      throw 'unsupported $expression';
  }
}

(MonoType, Substitution) _varRule(String name, Context context) {
  final type = context[name];
  if (type == null) throw 'Undefined variable $name';
  return (instantiate(type), {});
}

(MonoType, Substitution) _absRule(String param, Expr body, Context context) {
  final solveFor = TypeVariable.fresh();
  final (retType, retSubstitution) = _infer(body, {
    ...context,
    param: solveFor,
  });
  final exprType = retSubstitution.apply(function_t(solveFor, retType));
  return (exprType, retSubstitution);
}

(MonoType, Substitution) appRule(Context context, {required Expr func, required Expr arg}) {
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
final newNil = (int line) => Token(TokenType.NIL, 'nil', null, line);
final newArrow = (int line) => Token(TokenType.ARROW, '->', null, line);

({Token arrow, Expr body}) asArrowExpression(Lambda lambda) {
  return switch (lambda.body) {
    ArrowExpression(:final arrow, :final body) =>
        (arrow: arrow, body: body),
    FunctionBody(body: Block()) =>
        throw 'only expression bodies for now'
  };
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
(Token, Expr) curry(List<Token> params, Token arrow, Expr body) {

  final newLambda = (List<Token> params, Expr body) =>
      Lambda(params, ArrowExpression(arrow, body));

  return switch (params) {
    [] =>
        (newUnused(arrow.line), body),
    [final x] =>
        (x, body),
    [final x, ...final rest] => () {
        final (y, newBody) = curry(rest, arrow, body);
        return (x, newLambda([y], newBody));
    } (),
  };
}

//
// IN:  f()
// OUT: f(nil)
//
// IN:  f(x)
// OUT: f(x)
//
// IN:  f(x, y)
// OUT: f(x)(y)
//
({Expr func, Expr arg}) curriedCall(Expr callee, List<Expr> args, Token closingParen) {

  final newCall = (List<Expr> args, Expr body) =>
      Call(body, ExpressionArgs(args), closingParen);

  return switch (args) {
    [] =>
        (func: callee, arg: NilLiteral()),
    [final x] =>
        (func: callee, arg: x),
    [final x, ...final rest] => () {
        final (:func, :arg) = curriedCall(callee, rest, closingParen);
        return (arg: arg, func: newCall([x], func));
    } (),
  };
}
