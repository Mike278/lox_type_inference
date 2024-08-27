import 'package:lox/src/hindley_milner_api.dart';
import 'package:lox/src/hindley_milner_lambda_calculus.dart';
import 'package:lox/src/lox_lambda_calculus.dart';
import 'package:lox/src/utils.dart';
import 'package:test/test.dart';

import 'test_utils.dart';

void main() {
  
  final testInferFunction = testInferSource.partial('infer function');
  
  // arity 0
  testInferFunction(r'\  -> 1',  function_t(var_t('t0'), num_t));

  // arity 1
  testInferFunction(r'\x -> 1',  function_t(var_t('t0'), num_t));
  testInferFunction(r'\x -> x',  function_t(var_t('t0'), var_t('t0')));

  // arity 2
  testInferFunction(r'\x, y -> 1',   function_t(var_t('t0'), function_t(var_t('t1'), num_t)));
  testInferFunction(r'\x, y -> x',   function_t(var_t('t0'), function_t(var_t('t1'), var_t('t0'))));
  testInferFunction(r'\x, y -> y',   function_t(var_t('t0'), function_t(var_t('t1'), var_t('t1'))));
  testInferFunction(r'\x, y -> []',  function_t(var_t('t0'), function_t(var_t('t1'), list_t(var_t('t2')))));
  testInferFunction(r'\x, y -> x(y and false)',  function_t(function_t(bool_t, var_t('t4')), function_t(bool_t, var_t('t4'))));
  testInferFunction(r'\x, y -> x(y)',            function_t(function_t(var_t('t1'), var_t('t2')), function_t(var_t('t1'), var_t('t2'))));

  // arity 3
  testInferFunction(r'\x, y, z -> 1',             function_t(var_t('t0'), function_t(var_t('t1'), function_t(var_t('t2'), num_t))));
  testInferFunction(r'\x, y, z -> x',             function_t(var_t('t0'), function_t(var_t('t1'), function_t(var_t('t2'), var_t('t0')))));
  testInferFunction(r'\x, y, z -> y',             function_t(var_t('t0'), function_t(var_t('t1'), function_t(var_t('t2'), var_t('t1')))));
  testInferFunction(r'\x, y, z -> z',             function_t(var_t('t0'), function_t(var_t('t1'), function_t(var_t('t2'), var_t('t2')))));
  testInferFunction(r'\x, y, z -> x or y',        function_t(bool_t, function_t(bool_t, function_t(var_t('t2'), bool_t))));
  testInferFunction(r'\x, y, z -> z(x or y)',     function_t(bool_t, function_t(bool_t, function_t(function_t(bool_t, var_t('t5')), var_t('t5')))));
  testInferFunction(r'\x, y, z -> z(x or y, x)',  function_t(bool_t, function_t(bool_t, function_t(function_t(bool_t, function_t(bool_t, var_t('t6'))), var_t('t6')))));

  // unary function body
  testInferFunction(r'\x -> -x',  function_t(num_t, num_t));
  testInferFunction(r'\x -> !x',  function_t(bool_t, bool_t));
  testInferFunction(r'\x, y -> -x',  function_t(num_t, function_t(var_t('t1'), num_t)));
  testInferFunction(r'\x, y -> !x',  function_t(bool_t, function_t(var_t('t1'), bool_t)));

  // binary function body
  testInferFunction(r'\x, y -> x and y',  function_t(bool_t, function_t(bool_t, bool_t)));
  testInferFunction(r'\x, y -> x or y',   function_t(bool_t, function_t(bool_t, bool_t)));
  testInferFunction(r'\x, y -> x + y',    function_t(num_t, function_t(num_t, num_t)));
  testInferFunction(r'\x, y -> x - y',    function_t(num_t, function_t(num_t, num_t)));
  testInferFunction(r'\x, y -> x * y',    function_t(num_t, function_t(num_t, num_t)));
  testInferFunction(r'\x, y -> x / y',    function_t(num_t, function_t(num_t, num_t)));
  testInferFunction(r'\x, y -> x - -y',   function_t(num_t, function_t(num_t, num_t)));

  // ternary function body
  testInferFunction(r'\c, x, y -> c ? x : y',            function_t(bool_t, function_t(var_t('t6'), function_t(var_t('t6'), var_t('t6')))));
  testInferFunction(r'\c, x, y -> c ? x : y+1',          function_t(bool_t, function_t(num_t, function_t(num_t, num_t))));
  testInferFunction(r'\c, x, y -> c ? x : -y',           function_t(bool_t, function_t(num_t, function_t(num_t, num_t))));
  testInferFunction(r'\c, x, y -> c ? x : y or false',   function_t(bool_t, function_t(bool_t, function_t(bool_t, bool_t))));
  testInferFunction(r'\c, x, y -> c ? x : !y',           function_t(bool_t, function_t(bool_t, function_t(bool_t, bool_t))));

  // function call in function body
  testInferFunction(r'\x -> x("h", 1)', function_t(function_t(string_t, function_t(num_t, var_t('t2'))), var_t('t2')));

  // complex
  testInferFunction(r'\x, y, z -> x(y and false, z + 1)',  function_t(function_t(bool_t, function_t(num_t, var_t('t8'))), function_t(bool_t, function_t(num_t, var_t('t8')))));


  final testInferCall = testInferSource.partial('infer call');

  // arity 0
  testInferCall(r'(\  -> 1)()',  num_t);

  // arity 1
  testInferCall(r'(\x -> x)(1)',  num_t);
  testInferCall(r'(\x -> x)(-1)',  num_t);
  testInferCall(r'(\x -> 1)([])',  num_t);
  testInferCall(r'(\x -> x)([])',  list_t(var_t('t1')));
  testInferCall(r'(\x -> [])(1)',  list_t(var_t('t1')));

  // arity 2
  testInferCall(r'(\x, y -> 1)("ok", false)',  num_t);
  testInferCall(r'(\x, y -> x)("ok", false)',  string_t);
  testInferCall(r'(\x, y -> y)("ok", false)',  bool_t);

  // complex
  testInferCall(r'(\x, y -> x(y and false)) (\b -> 1, false)',  num_t);
  testInferCall(r'(\x, y -> x(y and false)) (\b -> b, false)',  bool_t);
  testInferCall(r'(\x, y -> x(y and false)) (\b -> b, true)',  bool_t);
  testInferCall(r'(\x, y -> x(y and false)) (\b -> 1, true)',  num_t);
  testInferCall(r'(\x, y -> x(y)) (\b -> 1, true)',  num_t);
  testInferCall(r'(\x -> x("h")) (\b -> 1)',  num_t);
  testInferCall(r'(\x -> "h") (\b, c -> 1)',  string_t);
  testInferCall(r'(\x -> x) (\b, c -> 1)',  function_t(var_t('t1'), function_t(var_t('t2'), num_t)));
  testInferCall(r'(\x -> x)(\f -> f("h", 1))', function_t(function_t(string_t, function_t(num_t, var_t('t3'))), var_t('t3')));
  testInferCall(r'(\x, y, z -> x(y and false, z + 1)) (\a, b -> b, true, 1)',  num_t);
  testInferCall(r'(\x -> \y -> \z -> x(y and false)(z + 1)) (\a -> \b -> b)(true)(1)',  num_t);
  testInferCall(r'(\x -> x(1, 1)) (\a, b -> "h")',  string_t);

  test('manual', () {
    // (x 1)
    final x1 = App(func: Var('x'), arg: Lit(num_t));
    // ((x 1) 1)
    final x11 = App(func: x1, arg: Lit(num_t));
    // \x -> ((x 1) 1)
    final abs = Abs('x', x11);
    // \a -> \b -> "h"
    final arg = Abs('a', Abs('b', Lit(string_t)));
    // (\x -> ((x 1) 1))(\a -> \b -> "h")
    final expr = App(func: abs, arg: arg);
    final result = infer(expr, newContext());
    expect(result, string_t);
  });
}

void testInferSource(String prefix, String source, expectedType) {
  final [_, _, frame, ...] = StackTrace.current.toString().split('\n');
  final line = RegExp(r'main \((.+)\)').firstMatch(frame)?.group(1);
  test('$prefix $source', () {
    expect(
      inferSource(source),
      expectedType,
      reason: line == null ? null : 'test case: $line',
    );
  });
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
