import 'package:lox/src/hindley_milner_api.dart';
import 'package:lox/src/hindley_milner_lambda_calculus.dart';
import 'package:lox/src/lox_lambda_calculus.dart';
import 'package:lox/src/utils.dart';
import 'package:test/test.dart';

import 'test_utils.dart';

void main() {
  for (final (source, expectedType) in {
    // arity 0
    r'\  -> 1': function_t(var_t('t0'), num_t),

    // arity 1
    r'\x -> 1': function_t(var_t('t0'), num_t),
    r'\x -> x': function_t(var_t('t0'), var_t('t0')),

    // arity 2
    r'\x, y -> 1':  function_t(var_t('t0'), function_t(var_t('t1'), num_t)),
    r'\x, y -> x':  function_t(var_t('t0'), function_t(var_t('t1'), var_t('t0'))),
    r'\x, y -> y':  function_t(var_t('t0'), function_t(var_t('t1'), var_t('t1'))),
    r'\x, y -> []': function_t(var_t('t0'), function_t(var_t('t1'), list_t(var_t('t2')))),
    r'\x, y -> x(y and false)': function_t(function_t(bool_t, var_t('t4')), function_t(bool_t, var_t('t4'))),
    r'\x, y -> x(y)':           function_t(function_t(var_t('t1'), var_t('t2')), function_t(var_t('t1'), var_t('t2'))),

    // arity 3
    r'\x, y, z -> 1':            function_t(var_t('t0'), function_t(var_t('t1'), function_t(var_t('t2'), num_t))),
    r'\x, y, z -> x':            function_t(var_t('t0'), function_t(var_t('t1'), function_t(var_t('t2'), var_t('t0')))),
    r'\x, y, z -> y':            function_t(var_t('t0'), function_t(var_t('t1'), function_t(var_t('t2'), var_t('t1')))),
    r'\x, y, z -> z':            function_t(var_t('t0'), function_t(var_t('t1'), function_t(var_t('t2'), var_t('t2')))),
    r'\x, y, z -> x or y':       function_t(bool_t, function_t(bool_t, function_t(var_t('t2'), bool_t))),
    r'\x, y, z -> z(x or y)':    function_t(bool_t, function_t(bool_t, function_t(function_t(bool_t, var_t('t5')), var_t('t5')))),
    r'\x, y, z -> z(x or y, x)': function_t(bool_t, function_t(bool_t, function_t(function_t(bool_t, function_t(bool_t, var_t('t6'))), var_t('t6')))),

    // unary function body
    r'\x -> -x': function_t(num_t, num_t),
    r'\x -> !x': function_t(bool_t, bool_t),
    r'\x, y -> -x': function_t(num_t, function_t(var_t('t1'), num_t)),
    r'\x, y -> !x': function_t(bool_t, function_t(var_t('t1'), bool_t)),

    // binary function body
    r'\x, y -> x and y': function_t(bool_t, function_t(bool_t, bool_t)),
    r'\x, y -> x or y':  function_t(bool_t, function_t(bool_t, bool_t)),
    r'\x, y -> x + y':   function_t(num_t, function_t(num_t, num_t)),
    r'\x, y -> x - y':   function_t(num_t, function_t(num_t, num_t)),
    r'\x, y -> x * y':   function_t(num_t, function_t(num_t, num_t)),
    r'\x, y -> x / y':   function_t(num_t, function_t(num_t, num_t)),
    r'\x, y -> x - -y':  function_t(num_t, function_t(num_t, num_t)),

    // ternary function body
    r'\c, x, y -> c ? x : y':           function_t(bool_t, function_t(var_t('t6'), function_t(var_t('t6'), var_t('t6')))),
    r'\c, x, y -> c ? x : y+1':         function_t(bool_t, function_t(num_t, function_t(num_t, num_t))),
    r'\c, x, y -> c ? x : -y':          function_t(bool_t, function_t(num_t, function_t(num_t, num_t))),
    r'\c, x, y -> c ? x : y or false':  function_t(bool_t, function_t(bool_t, function_t(bool_t, bool_t))),
    r'\c, x, y -> c ? x : !y':          function_t(bool_t, function_t(bool_t, function_t(bool_t, bool_t))),

    // complex
    r'\x, y, z -> x(y and false, z + 1)': function_t(function_t(bool_t, function_t(num_t, var_t('t8'))), function_t(bool_t, function_t(num_t, var_t('t8')))),
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
    r'(\x -> x)([])': list_t(var_t('t1')),
    r'(\x -> [])(1)': list_t(var_t('t1')),

    // arity 2
    r'(\x, y -> 1)("ok", false)': num_t,
    r'(\x, y -> x)("ok", false)': string_t,
    r'(\x, y -> y)("ok", false)': bool_t,

    // complex
    r'(\x, y -> x(y and false)) (\b -> 1, false)': num_t,
    r'(\x, y -> x(y and false)) (\b -> b, false)': bool_t,
    r'(\x, y, z ->       x(y and false, z + 1)) (\a, b -> b, true, 1)': num_t,
  }.pairs()) {
    test('infer call $source', () {
      expect(inferSource(source),  expectedType, reason: source);
    });
  }
}

Map<String, PolyType> newContext() => {
  ...loxStandardLibraryContext,
};

MonoType inferSource(String source) {
  final expr = parseExpression(source);
  final context = newContext();
  final lc = toLambdaCalculus(expr);
  return infer(lc, context);
}

MonoType infer(LambdaCalculusExpression expr, Context context) {
  TypeVariable.counter = 0;
  final (substitution, t) = w(expr, context);
  final type = substitution.apply(t);
  return type;
}
