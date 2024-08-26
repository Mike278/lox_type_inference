import 'package:lox/src/expr.dart';
import 'package:lox/src/hindley_milner_api.dart';
import 'package:lox/src/hindley_milner_lambda_calculus.dart';
import 'package:lox/src/lox_lambda_calculus.dart';
import 'package:lox/src/parser.dart';
import 'package:lox/src/scanner.dart';
import 'package:lox/src/utils.dart';
import 'package:test/test.dart';

import 'test_matchers.dart';

void main() {
  for (final (source, expectedType) in {
    // arity 0
    r'\  -> 1': _fn(_var('t0'), num_t),

    // arity 1
    r'\x -> 1': _fn(_var('t0'), num_t),
    r'\x -> x': _fn(_var('t0'), _var('t0')),

    // arity 2
    r'\x, y -> 1':  _fn(_var('t0'), _fn(_var('t1'), num_t)),
    r'\x, y -> x':  _fn(_var('t0'), _fn(_var('t1'), _var('t0'))),
    r'\x, y -> y':  _fn(_var('t0'), _fn(_var('t1'), _var('t1'))),
    r'\x, y -> []': _fn(_var('t0'), _fn(_var('t1'), _list('t2'))),
    r'\x, y -> x(y and false)': _fn(_fn(bool_t, _var('t4')), _fn(bool_t, _var('t4'))),
    r'\x, y -> x(y)':           _fn(_fn(_var('t1'), _var('t2')), _fn(_var('t1'), _var('t2'))),

    // arity 3
    r'\x, y, z -> 1':            _fn(_var('t0'), _fn(_var('t1'), _fn(_var('t2'), num_t))),
    r'\x, y, z -> x':            _fn(_var('t0'), _fn(_var('t1'), _fn(_var('t2'), _var('t0')))),
    r'\x, y, z -> y':            _fn(_var('t0'), _fn(_var('t1'), _fn(_var('t2'), _var('t1')))),
    r'\x, y, z -> z':            _fn(_var('t0'), _fn(_var('t1'), _fn(_var('t2'), _var('t2')))),
    r'\x, y, z -> x or y':       _fn(bool_t, _fn(bool_t, _fn(_var('t2'), bool_t))),
    r'\x, y, z -> z(x or y)':    _fn(bool_t, _fn(bool_t, _fn(_fn(bool_t, _var('t5')), _var('t5')))),
    r'\x, y, z -> z(x or y, x)': _fn(bool_t, _fn(bool_t, _fn(_fn(bool_t, _fn(bool_t, _var('t6'))), _var('t6')))),

    // unary function body
    r'\x -> -x': _fn(num_t, num_t),
    r'\x -> !x': _fn(bool_t, bool_t),
    r'\x, y -> -x': _fn(num_t, _fn(_var('t1'), num_t)),
    r'\x, y -> !x': _fn(bool_t, _fn(_var('t1'), bool_t)),

    // binary function body
    r'\x, y -> x and y': _fn(bool_t, _fn(bool_t, bool_t)),
    r'\x, y -> x or y':  _fn(bool_t, _fn(bool_t, bool_t)),
    r'\x, y -> x + y':   _fn(num_t, _fn(num_t, num_t)),
    r'\x, y -> x - y':   _fn(num_t, _fn(num_t, num_t)),
    r'\x, y -> x * y':   _fn(num_t, _fn(num_t, num_t)),
    r'\x, y -> x / y':   _fn(num_t, _fn(num_t, num_t)),
    r'\x, y -> x - -y':  _fn(num_t, _fn(num_t, num_t)),

    // ternary function body
    r'\c, x, y -> c ? x : y':           _fn(bool_t, _fn(_var('t6'), _fn(_var('t6'), _var('t6')))),
    r'\c, x, y -> c ? x : y+1':         _fn(bool_t, _fn(num_t, _fn(num_t, num_t))),
    r'\c, x, y -> c ? x : -y':          _fn(bool_t, _fn(num_t, _fn(num_t, num_t))),
    r'\c, x, y -> c ? x : y or false':  _fn(bool_t, _fn(bool_t, _fn(bool_t, bool_t))),
    r'\c, x, y -> c ? x : !y':          _fn(bool_t, _fn(bool_t, _fn(bool_t, bool_t))),

    // complex
    r'\x, y, z -> x(y and false, z + 1)': _fn(_fn(bool_t, _fn(num_t, _var('t8'))), _fn(bool_t, _fn(num_t, _var('t8')))),
  }.pairs()) {
    test('infer function $source', () {
      expect(inferSource(source),  expectedType, reason: source);
    });
  }

  for (final (source, expectedType) in {

    // arity 0
    r'(\  -> 1)()': num_t,

    // arity 1
    r'(\x -> x)(1)': num_t,
    r'(\x -> x)(-1)': num_t,
    r'(\x -> 1)([])': num_t,
    r'(\x -> x)([])': _list('t1'),
    r'(\x -> [])(1)': _list('t1'),

    // arity 2
    r'(\x, y -> 1)("ok", false)': num_t,
    r'(\x, y -> x)("ok", false)': string_t,
    r'(\x, y -> y)("ok", false)': bool_t,

    // complex
    r'(\x, y -> x(y and false)) (\b -> 1, false)': num_t,
    r'(\x, y -> x(y and false)) (\b -> b, false)': bool_t,
    r'(\x, y, z -> x(y and false, z + 1)) (\a, b -> b, true, 1)': num_t,
  }.pairs()) {
    test('infer call $source', () {
      expect(inferSource(source),  expectedType, reason: source);
    });
  }
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
const negate = TypeFunctionApplication(kFunction, [ bool_t, bool_t]);

const ternary =
  TypeQuantifier(
    'a',
    TypeFunctionApplication(
      kFunction,
      [
        bool_t,
        TypeFunctionApplication(
          kFunction,
          [
            TypeVariable('a'),
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
  '!': negate,
  '?': ternary,
  '[]': emptyList,
  'nil': unit_t,
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
  final expr = toLambdaCalculus(expression);
  final (substitution, t) = w(expr, context);
  final type = substitution.apply(t);
  return type;
}
