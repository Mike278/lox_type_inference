import 'package:lox/src/expr.dart';
import 'package:lox/src/hindley_milner_api.dart';
import 'package:lox/src/hindley_milner_lambda_calculus.dart';
import 'package:lox/src/lox_lambda_calculus.dart';
import 'package:lox/src/utils.dart';
import 'package:test/test.dart';

import 'test_utils.dart';

void main() {
  
  final testInferFunction = testInferSourceExpression.partial('infer function');
  
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
  testInferFunction(r'\x, y -> x(y and false)',  function_t(function_t(bool_t, var_t('t0')), function_t(bool_t, var_t('t0'))));
  testInferFunction(r'\x, y -> x(y)',            function_t(function_t(var_t('t0'), var_t('t1')), function_t(var_t('t0'), var_t('t1'))));

  // arity 3
  testInferFunction(r'\x, y, z -> 1',             function_t(var_t('t0'), function_t(var_t('t1'), function_t(var_t('t2'), num_t))));
  testInferFunction(r'\x, y, z -> x',             function_t(var_t('t0'), function_t(var_t('t1'), function_t(var_t('t2'), var_t('t0')))));
  testInferFunction(r'\x, y, z -> y',             function_t(var_t('t0'), function_t(var_t('t1'), function_t(var_t('t2'), var_t('t1')))));
  testInferFunction(r'\x, y, z -> z',             function_t(var_t('t0'), function_t(var_t('t1'), function_t(var_t('t2'), var_t('t2')))));
  testInferFunction(r'\x, y, z -> x or y',        function_t(bool_t, function_t(bool_t, function_t(var_t('t0'), bool_t))));
  testInferFunction(r'\x, y, z -> z(x or y)',     function_t(bool_t, function_t(bool_t, function_t(function_t(bool_t, var_t('t0')), var_t('t0')))));
  testInferFunction(r'\x, y, z -> z(x or y, x)',  function_t(bool_t, function_t(bool_t, function_t(function_t(bool_t, function_t(bool_t, var_t('t0'))), var_t('t0')))));

  // unary function body
  testInferFunction(r'\x -> -x',  function_t(num_t, num_t));
  testInferFunction(r'\x -> !x',  function_t(bool_t, bool_t));
  testInferFunction(r'\x, y -> -x',  function_t(num_t, function_t(var_t('t0'), num_t)));
  testInferFunction(r'\x, y -> !x',  function_t(bool_t, function_t(var_t('t0'), bool_t)));

  // binary function body
  testInferFunction(r'\x, y -> x and y',  function_t(bool_t, function_t(bool_t, bool_t)));
  testInferFunction(r'\x, y -> x or y',   function_t(bool_t, function_t(bool_t, bool_t)));
  testInferFunction(r'\x, y -> x + y',    function_t(num_t, function_t(num_t, num_t)));
  testInferFunction(r'\x, y -> x - y',    function_t(num_t, function_t(num_t, num_t)));
  testInferFunction(r'\x, y -> x * y',    function_t(num_t, function_t(num_t, num_t)));
  testInferFunction(r'\x, y -> x / y',    function_t(num_t, function_t(num_t, num_t)));
  testInferFunction(r'\x, y -> x - -y',   function_t(num_t, function_t(num_t, num_t)));

  // ternary function body
  testInferFunction(r'\c, x, y -> c ? x : y',            function_t(bool_t, function_t(var_t('t0'), function_t(var_t('t0'), var_t('t0')))));
  testInferFunction(r'\c, x, y -> c ? x : y+1',          function_t(bool_t, function_t(num_t, function_t(num_t, num_t))));
  testInferFunction(r'\c, x, y -> c ? x : -y',           function_t(bool_t, function_t(num_t, function_t(num_t, num_t))));
  testInferFunction(r'\c, x, y -> c ? x : y or false',   function_t(bool_t, function_t(bool_t, function_t(bool_t, bool_t))));
  testInferFunction(r'\c, x, y -> c ? x : !y',           function_t(bool_t, function_t(bool_t, function_t(bool_t, bool_t))));

  // function call in function body
  testInferFunction(r'\x -> x("h", 1)', function_t(function_t(string_t, function_t(num_t, var_t('t0'))), var_t('t0')));

  // complex
  testInferFunction(r'\x, y, z -> x(y and false, z + 1)',  function_t(function_t(bool_t, function_t(num_t, var_t('t0'))), function_t(bool_t, function_t(num_t, var_t('t0')))));


  final testInferCall = testInferSourceExpression.partial('infer call');

  // arity 0
  testInferCall(r'(\  -> 1)()',  num_t);

  // arity 1
  testInferCall(r'(\x -> x)(1)',  num_t);
  testInferCall(r'(\x -> x)(-1)',  num_t);
  testInferCall(r'(\x -> 1)([])',  num_t);
  testInferCall(r'(\x -> x)([])',  list_t(var_t('t0')));
  testInferCall(r'(\x -> [])(1)',  list_t(var_t('t0')));

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
  testInferCall(r'(\x -> x) (\b, c -> 1)',  function_t(var_t('t0'), function_t(var_t('t1'), num_t)));
  testInferCall(r'(\x -> x)(\f -> f("h", 1))', function_t(function_t(string_t, function_t(num_t, var_t('t0'))), var_t('t0')));
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


  final testInferListLiteral = testInferSourceExpression.partial('infer list');

  testInferListLiteral('[1]', list_t(num_t));
  testInferListLiteral('[1, 2]', list_t(num_t));
  testInferListLiteral('[1, 2, 3]', list_t(num_t));
  testInferListLiteral('[1, 2, 3, 4]', list_t(num_t));

  testInferListLiteral('["h"]', list_t(string_t));
  testInferListLiteral('["h", "h"]', list_t(string_t));
  testInferListLiteral('["h", "h", "h"]', list_t(string_t));
  testInferListLiteral('["h", "h", "h", "h"]', list_t(string_t));

  testInferListLiteral('[[]]', list_t(list_t(var_t('t0'))));
  testInferListLiteral('[[], []]', list_t(list_t(var_t('t0'))));
  testInferListLiteral('[[], [], []]', list_t(list_t(var_t('t0'))));
  testInferListLiteral('[[], [], [], []]', list_t(list_t(var_t('t0'))));

  testInferListLiteral('[["h"]]', list_t(list_t(string_t)));
  testInferListLiteral('[["h"], ["h"]]', list_t(list_t(string_t)));
  testInferListLiteral('[["h"], ["h"], ["h"]]', list_t(list_t(string_t)));
  testInferListLiteral('[["h"], ["h"], ["h"], ["h"]]', list_t(list_t(string_t)));

  testInferListLiteral('[[], ["h"]]', list_t(list_t(string_t)));
  testInferListLiteral('[[], ["h"], ["h"]]', list_t(list_t(string_t)));
  testInferListLiteral('[[], ["h"], ["h"], ["h"]]', list_t(list_t(string_t)));
  testInferListLiteral('[[], ["h"], ["h"], ["h"], ["h"]]', list_t(list_t(string_t)));

  testInferListLiteral('[["h"], []]', list_t(list_t(string_t)));
  testInferListLiteral('[["h"], ["h"], []]', list_t(list_t(string_t)));
  testInferListLiteral('[["h"], ["h"], ["h"], []]', list_t(list_t(string_t)));
  testInferListLiteral('[["h"], ["h"], ["h"], ["h"], []]', list_t(list_t(string_t)));

  testInferListLiteral(r'\f -> [f()]', function_t(function_t(unit_t, var_t('t0')), list_t(var_t('t0'))));
  testInferListLiteral(r'\f -> [f() + 1]', function_t(function_t(unit_t, num_t), list_t(num_t)));

  testInferListLiteral('[1, ..[]]', list_t(num_t));
  testInferListLiteral('[1, ..[2]]', list_t(num_t));
  testInferListLiteral('[1, ..[2, 3]]', list_t(num_t));
  testInferListLiteral('[1, ..[2, 3, 4]]', list_t(num_t));
  testInferListLiteral('[1, ..[2, 3, 4], 5]', list_t(num_t));
  testInferListLiteral('[1, ..[2, 3, 4], 5, 6]', list_t(num_t));
  testInferListLiteral('[1, ..[2, 3, 4], 5, 6, ..[]]', list_t(num_t));
  testInferListLiteral('[1, ..[2, 3, 4], 5, 6, ..[7]]', list_t(num_t));
  testInferListLiteral('[1, ..[2, 3, 4], ..[5]]', list_t(num_t));
  testInferListLiteral('[..[1], ..[2, 3, 4], ..[5]]', list_t(num_t));
  testInferListLiteral('[..[[1]], ..[[2], [3, 4]], ..[[5]]]', list_t(list_t(num_t)));
  testInferListLiteral('[..[..[1]], ..[..[2], ..[3, 4]], ..[..[5]], 6]', list_t(num_t));

  testInferListLiteral(r'\f -> [..f]', function_t(list_t(var_t('t0')), list_t(var_t('t0'))));
  testInferListLiteral(r'\f -> [..f, 1]', function_t(list_t(num_t), list_t(num_t)));
  testInferListLiteral(r'\f -> [[..f]]', function_t(list_t(var_t('t0')), list_t(list_t(var_t('t0')))));

  testInferListLiteral('[..[]]', list_t(var_t('t0')));
  testInferListLiteral('[..[], []]', list_t(list_t(var_t('t0'))));
  testInferListLiteral('[..[], ..[]]', list_t(var_t('t0')));

  test('let', () {
    expect(inferLetStatementsFromSource(r'let f = \x -> x > 3 ? f(x - 1) : x;'), function_t(num_t, num_t));
    expect(inferLetStatementsFromSource(r'let x = 1;'), num_t);
    expect(inferLetStatementsFromSource(r'''
    let x = 1;
    let y = "h";
    '''), string_t);
    expect(inferLetStatementsFromSource(r'''
    let x = \list -> [..list, 1]; 
    let y = x([4]);
    '''), list_t(num_t));
  });

}

void testInferSourceExpression(String prefix, String source, expectedType) {
  final line = StackTrace.current
      .toString()
      .split('\n')
      .map(RegExp(r'main \((.+)\)').firstMatch)
      .whereNotNull()
      .single
      .group(1);
  test('$prefix $source', () {
    expect(
      inferExpressionFromSource(source),
      expectedType,
      reason: line == null ? null : 'test case: $line',
    );
  });
}

Map<String, PolyType> newContext() => {
  ...loxStandardLibraryContext,
};

MonoType inferLetStatementsFromSource(String source) {
  final statements = parse(source);
  final lets = [for (final s in statements) if (s is LetDeclaration) s];
  if (lets.isEmpty) fail('source does not contain any let statements');
  if (lets.length < statements.length) fail('source contains non-let statements');
  final lc = toLet(lets);
  final context = newContext();
  final inferred = infer(lc, context);
  return normalizeTypeVariableIds(inferred);
}

MonoType inferExpressionFromSource(String source) {
  final expr = parseExpression(source);
  final context = newContext();
  final lc = toLambdaCalculus(expr);
  final inferred = infer(lc, context);
  return normalizeTypeVariableIds(inferred);
}

MonoType infer(LambdaCalculusExpression expr, Context context) {
  TypeVariable.counter = 0;
  final (substitution, t) = w(expr, context);
  final type = substitution.apply(t);
  return type;
}

MonoType normalizeTypeVariableIds(MonoType t) {
  final namesSorted =
    collectTypeVariables({}, t)
      .map(
        (name) => switch (extractTypeVariableId(name)) {
          null => null,
          final id => (name, id),
        },
      )
      .whereNotNull()
      .toList()
      .sorted((a, b) => a.$2.compareTo(b.$2))
      .map((x) => x.$1)
      .toList();

  String lookup(String name) =>
    namesSorted.contains(name)
      ? 't${namesSorted.indexOf(name)}'
      : name;

  return rename(t, lookup);
}

MonoType rename(MonoType t, String Function(String) lookup) => switch (t) {
  TypeVariable(:final name) => TypeVariable(lookup(name)),
  TypeFunctionApplication(:final name, :final monoTypes) => TypeFunctionApplication(
    lookup(name),
    [ for (final t in monoTypes) rename(t, lookup) ]
  ),
};

Set<String> collectTypeVariables(Set<String> state, MonoType t) => {
  ...state,
  ...switch (t) {
    TypeVariable(:final name) => {name},
    TypeFunctionApplication(:final name, :final monoTypes) => {
      name,
      for (final t in monoTypes)
        ...collectTypeVariables(state, t),
    },
  }
};

int? extractTypeVariableId(String s) =>
  s.startsWith('t') ? int.parse(s.substring(1)) : null;
