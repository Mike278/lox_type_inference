import 'package:lox/src/expr.dart';
import 'package:lox/src/hindley_milner_api.dart' hide contains;
import 'package:lox/src/hindley_milner_lambda_calculus.dart';
import 'package:lox/src/lox_lambda_calculus.dart';
import 'package:lox/src/scanner.dart';
import 'package:lox/src/utils.dart';
import 'package:test/test.dart';

import 'test_utils.dart';

final t0 = var_t('t0');
final t1 = var_t('t1');
final t2 = var_t('t2');

void main() {
  
  final testInferFunction = testInferSource.partial('infer function');
  
  // arity 0
  testInferFunction(r'\  -> 1',  function_t(t0, num_t));

  // arity 1
  testInferFunction(r'\x -> 1',  function_t(t0, num_t));
  testInferFunction(r'\x -> x',  function_t(t0, t0));

  // arity 2
  testInferFunction(r'\x, y -> 1',   function_t(t0, function_t(t1, num_t)));
  testInferFunction(r'\x, y -> x',   function_t(t0, function_t(t1, t0)));
  testInferFunction(r'\x, y -> y',   function_t(t0, function_t(t1, t1)));
  testInferFunction(r'\x, y -> []',  function_t(t0, function_t(t1, list_t(t2))));
  testInferFunction(r'\x, y -> x(y and false)',  function_t(function_t(bool_t, t0), function_t(bool_t, t0)));
  testInferFunction(r'\x, y -> x(y)',            function_t(function_t(t0, t1), function_t(t0, t1)));

  // arity 3
  testInferFunction(r'\x, y, z -> 1',             function_t(t0, function_t(t1, function_t(t2, num_t))));
  testInferFunction(r'\x, y, z -> x',             function_t(t0, function_t(t1, function_t(t2, t0))));
  testInferFunction(r'\x, y, z -> y',             function_t(t0, function_t(t1, function_t(t2, t1))));
  testInferFunction(r'\x, y, z -> z',             function_t(t0, function_t(t1, function_t(t2, t2))));
  testInferFunction(r'\x, y, z -> x or y',        function_t(bool_t, function_t(bool_t, function_t(t0, bool_t))));
  testInferFunction(r'\x, y, z -> z(x or y)',     function_t(bool_t, function_t(bool_t, function_t(function_t(bool_t, t0), t0))));
  testInferFunction(r'\x, y, z -> z(x or y, x)',  function_t(bool_t, function_t(bool_t, function_t(function_t(bool_t, function_t(bool_t, t0)), t0))));

  // unary function body
  testInferFunction(r'\x -> -x',  function_t(num_t, num_t));
  testInferFunction(r'\x -> !x',  function_t(bool_t, bool_t));
  testInferFunction(r'\x, y -> -x',  function_t(num_t, function_t(t0, num_t)));
  testInferFunction(r'\x, y -> !x',  function_t(bool_t, function_t(t0, bool_t)));

  // binary function body
  testInferFunction(r'\x, y -> x and y',  function_t(bool_t, function_t(bool_t, bool_t)));
  testInferFunction(r'\x, y -> x or y',   function_t(bool_t, function_t(bool_t, bool_t)));
  testInferFunction(r'\x, y -> x + y',    function_t(num_t, function_t(num_t, num_t)));
  testInferFunction(r'\x, y -> x - y',    function_t(num_t, function_t(num_t, num_t)));
  testInferFunction(r'\x, y -> x * y',    function_t(num_t, function_t(num_t, num_t)));
  testInferFunction(r'\x, y -> x / y',    function_t(num_t, function_t(num_t, num_t)));
  testInferFunction(r'\x, y -> x - -y',   function_t(num_t, function_t(num_t, num_t)));

  // ternary function body
  testInferFunction(r'\c, x, y -> c ? x : y',            function_t(bool_t, function_t(t0, function_t(t0, t0))));
  testInferFunction(r'\c, x, y -> c ? x : y+1',          function_t(bool_t, function_t(num_t, function_t(num_t, num_t))));
  testInferFunction(r'\c, x, y -> c ? x : -y',           function_t(bool_t, function_t(num_t, function_t(num_t, num_t))));
  testInferFunction(r'\c, x, y -> c ? x : y or false',   function_t(bool_t, function_t(bool_t, function_t(bool_t, bool_t))));
  testInferFunction(r'\c, x, y -> c ? x : !y',           function_t(bool_t, function_t(bool_t, function_t(bool_t, bool_t))));

  // function call in function body
  testInferFunction(r'\x -> x("h", 1)', function_t(function_t(string_t, function_t(num_t, t0)), t0));

  // complex
  testInferFunction(r'\x, y, z -> x(y and false, z + 1)',  function_t(function_t(bool_t, function_t(num_t, t0)), function_t(bool_t, function_t(num_t, t0))));


  final testInferCall = testInferSource.partial('infer call');

  // arity 0
  testInferCall(r'(\  -> 1)()',  num_t);

  // arity 1
  testInferCall(r'(\x -> x)(1)',  num_t);
  testInferCall(r'(\x -> x)(-1)',  num_t);
  testInferCall(r'(\x -> 1)([])',  num_t);
  testInferCall(r'(\x -> x)([])',  list_t(t0));
  testInferCall(r'(\x -> [])(1)',  list_t(t0));

  // arity 2
  testInferCall(r'(\x, y -> 1)("ok", false)',  num_t);
  testInferCall(r'(\x, y -> x)("ok", false)',  string_t);
  testInferCall(r'(\x, y -> y)("ok", false)',  bool_t);

  // placeholder
  testInferCall(r'let f = \x, y -> (x ? 1 : 0) + y; let f1 = f(false, _);',  function_t(num_t, num_t));
  testInferCall(r'let f = \x, y -> (x ? 1 : 0) + y; let f1 = f(false, _); f1(1);',  num_t);
  testInferCall(r'let f = \x, y -> (x ? 1 : 0) + y; let f1 = f(_, 1);',  function_t(bool_t, num_t));
  testInferCall(r'let f = \x, y -> (x ? 1 : 0) + y; let f1 = f(_, 1); f1(false);',  num_t);


  // complex
  testInferCall(r'(\x, y -> x(y and false)) (\b -> 1, false)',  num_t);
  testInferCall(r'(\x, y -> x(y and false)) (\b -> b, false)',  bool_t);
  testInferCall(r'(\x, y -> x(y and false)) (\b -> b, true)',  bool_t);
  testInferCall(r'(\x, y -> x(y and false)) (\b -> 1, true)',  num_t);
  testInferCall(r'(\x, y -> x(y)) (\b -> 1, true)',  num_t);
  testInferCall(r'(\x -> x("h")) (\b -> 1)',  num_t);
  testInferCall(r'(\x -> "h") (\b, c -> 1)',  string_t);
  testInferCall(r'(\x -> x) (\b, c -> 1)',  function_t(t0, function_t(t1, num_t)));
  testInferCall(r'(\x -> x)(\f -> f("h", 1))', function_t(function_t(string_t, function_t(num_t, t0)), t0));
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


  final testInferListLiteral = testInferSource.partial('infer list');

  testInferListLiteral('[1]', list_t(num_t));
  testInferListLiteral('[1, 2]', list_t(num_t));
  testInferListLiteral('[1, 2, 3]', list_t(num_t));
  testInferListLiteral('[1, 2, 3, 4]', list_t(num_t));

  testInferListLiteral('["h"]', list_t(string_t));
  testInferListLiteral('["h", "h"]', list_t(string_t));
  testInferListLiteral('["h", "h", "h"]', list_t(string_t));
  testInferListLiteral('["h", "h", "h", "h"]', list_t(string_t));

  testInferListLiteral('[[]]', list_t(list_t(t0)));
  testInferListLiteral('[[], []]', list_t(list_t(t0)));
  testInferListLiteral('[[], [], []]', list_t(list_t(t0)));
  testInferListLiteral('[[], [], [], []]', list_t(list_t(t0)));

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

  testInferListLiteral(r'\f -> [f()]', function_t(function_t(unit_t, t0), list_t(t0)));
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

  testInferListLiteral(r'\f -> [..f]', function_t(list_t(t0), list_t(t0)));
  testInferListLiteral(r'\f -> [..f, 1]', function_t(list_t(num_t), list_t(num_t)));
  testInferListLiteral(r'\f -> [[..f]]', function_t(list_t(t0), list_t(list_t(t0))));

  testInferListLiteral('[..[]]', list_t(t0));
  testInferListLiteral('[..[], []]', list_t(list_t(t0)));
  testInferListLiteral('[..[], ..[]]', list_t(t0));

  test('let', () {
    expect(inferSource(r'let factorial = \n -> n > 0 ? n * factorial(n - 1) : 1;'), function_t(num_t, num_t));
    expect(inferSource(r'let x = 1;'), num_t);
    expect(inferSource(r'''
    let x = 1;
    let y = "h";
    '''), string_t);
    expect(inferSource(r'''
    let x = \list -> [..list, 1]; 
    let y = x([4]);
    '''), list_t(num_t));

    final f1 = (source: r'\x, y -> List.first(x) + y',       expectedType: function_t(list_t(num_t),  function_t(num_t, num_t)));
    final f2 = (source: r'\x, y -> List.first(x) or y',      expectedType: function_t(list_t(bool_t), function_t(bool_t, bool_t)));
    final f3 = (source: r'\x, y -> (true ? x : y) + 1',      expectedType: function_t(num_t,  function_t(num_t, num_t)));
    final f4 = (source: r'\x, y -> (true ? x : y) or false', expectedType: function_t(bool_t, function_t(bool_t, bool_t)));

    expect(inferSource(f1.source),  f1.expectedType);
    expect(inferSource(f2.source),  f2.expectedType);
    expect(inferSource(f3.source),  f3.expectedType);
    expect(inferSource(f4.source),  f4.expectedType);

    expect(inferSource('let f = ${f1.source};'),  f1.expectedType);
    expect(inferSource('let f = ${f2.source};'),  f2.expectedType);
    expect(inferSource('let f = ${f3.source};'),  f3.expectedType);
    expect(inferSource('let f = ${f4.source};'),  f4.expectedType);
  });

  final fold = r'''
    let fold = \list, state, fn ->
        List.empty(list) 
          ? state 
          : fold(
              List.rest(list),
              fn(state, List.first(list)),
              fn
            );''';

  final map = fold + r'''
    let map = \list, fn ->
        fold(list, [], \state, element -> [..state, fn(element)]);
  ''';

  final reduce = fold + r'''
    let reduce = \list, fn ->
        fold(list, List.first(list), fn);
  ''';


  test('recursive polymorphic functions', () {

    expect(inferSource(fold + r'''
      fold([1,2,3], false, \state, num -> num > 1 ? state : false);
    '''), bool_t);
    expect(inferSource(fold + r'''
      fold([1,2,3], false, \state, num -> num > 1 ? state : false);
      fold(["a", "b", "c"], 0, \state, str -> str == "a" ? state+1 : state);
    '''), num_t);

    expect(inferSource(map), function_t(
      list_t(t1), function_t(
      function_t(t1, t0),
      list_t(t0))
    ));
    expect(inferSource(map + r'''
      map([1,2,3], \x -> x > 1);
    '''), list_t(bool_t));
    expect(inferSource(map + r'''
      map([1,2,3], \x -> x > 1);
      map([false], \x -> x ? 5 : 10);
    '''), list_t(num_t));

    expect(inferSource(reduce + r'''
      reduce([4,5,6], \max, e -> e > max ? e : max);
    '''), num_t);
    expect(inferSource(reduce + r'''
      reduce([4,5,6], \max, e -> e > max ? e : max);
      reduce([true, false, true], \state, b -> state and b);
    '''), bool_t);
    expect(inferSource(reduce + r'''
      let r = reduce; 
      r([4,5,6], \max, e -> e > max ? e : max);
      r([true, false, true], \state, b -> state and b);
    '''), bool_t);

    final employees = r'''
    let employees = [
        {name: "mike", age: 30},
        {name: "jane", age: 60},
        {name: "joe", age: 50}
    ];
    ''';

    expect(inferSource(reduce + employees + r'''
      let employeeWithMaxAge = reduce(
          employees,
          \highest, employee ->
              employee.age > highest.age
                  ? employee
                  : highest
      );
    '''), record_t({'name': string_t, 'age': num_t}));

    expect(inferSource(map + reduce + employees + r'''
      let maxAge = reduce(
          map(employees, \e -> e.age),
          \highest, age -> age > highest ? age : highest
      );
    '''), num_t);
  });

  final testInferRecord = testInferSource.partial('infer record');
  testInferRecord('let y = {};', record_empty_t);
  testInferRecord('let y = {foo: "foo"};', record_t({'foo': string_t}));
  testInferRecord('let y = {foo: "foo"}; let x = y.foo;', string_t);
  testInferRecord(r'let double = \x -> x * 2; let y = {foo: "foo", bar: double(4)};', record_t({'foo': string_t, 'bar': num_t}));
  testInferRecord('let y = {foo: "foo"}; let x = {a: 1, ok: y.foo};', record_t({'a': num_t, 'ok': string_t}));
  testInferRecord(r'let y = \x -> {foo: 1};', function_t(t0, record_t({'foo': num_t})));
  testInferRecord(r'let r = {id: \x -> x}; let a = r.id(1);', num_t);
  testInferRecord(r'let r = {id: \x -> x}; let a = r.id(1); let b = r.id("b");', string_t);
  testInferRecord(r'List.empty([]);', bool_t);
  testInferRecord(r'List.first([1]);', num_t);
  testInferRecord(r'List.first(["b"]);', string_t);
  testInferRecord(r'print List.first([1]); '
                  r'print List.first(["b"]);', string_t);
  testInferRecord(r'let f = List.first; f([1]);', num_t);
  testInferRecord(r'let f = \x -> {a: x}; f(5).a;', num_t);
  testInferRecord(r'let f = \x -> {a: x}; f(5).a; f("hi").a;', string_t);

  test('infer accessing field of record thats passed in as a parameter', () {
    expect(inferSource(r'\someRecord -> someRecord.bar'), function_t(record_extension_t(t0, {'bar': t1}), t1));
    expect(inferSource(r'\someRecord -> someRecord.bar + 1'), function_t(record_extension_t(t0, {'bar': num_t}), num_t));
    expect(inferSource(r'\someRecord, someNum -> someRecord.bar + someNum'), function_t(record_extension_t(t0, {'bar': num_t}), function_t(num_t, num_t)));
    expect(inferSource(r'''
    let getAge = \person -> person.age;
    let bob = {age: 100};
    let age = getAge(bob);
    '''), num_t);
    expect(inferSource(r'''
    let getAge = \person -> person.age;
    let getBirthYear = \currentYear, person -> currentYear - getAge(person);
    '''), function_t(num_t, function_t(record_extension_t(t0, {'age': num_t}), num_t)));
    expect(inferSource(r'''
    let getAge = \person -> person.age;
    let getBirthYear = \currentYear, person -> currentYear - getAge(person);
    let bob = {age: 100};
    let bornIn = getBirthYear(2024, bob);
    '''), num_t);

    expect(inferSource(r'''
    let getAge = \person -> person.age;
    let getBirthYear = \args -> args.currentYear - getAge(args.person);
    let bornIn = getBirthYear({currentYear: 2024, person: {age: 100}});
    '''), num_t);

    expect(inferSource(r'''
    let getAge = \person -> person.age;
    let getBirthYear = \args -> args.currentYear - getAge(args.person);
    let bornIn = getBirthYear({currentYear: 2024, person: {age: 100, someExtraArg: "hi"}});
    '''), num_t);

    expect(inferSource(r'''
    let withRecord = \x -> \f -> f(x);
    print withRecord({a: "one", b: 2});
    '''), function_t(function_t(record_t({'a': string_t, 'b': num_t}), t0), t0));

    expect(inferSource(r'''
    let withRecord = \x -> \f -> f(x);
    print withRecord({a: "one", b: 2});
    print withRecord({a: "one", b: 2, c: 4});
    '''), function_t(function_t(record_t({'a': string_t, 'b': num_t, 'c': num_t}), t0), t0));

    expect(inferSource(r'''
    let withRecord = \x -> \f -> f(x);
    print withRecord({a: "one", b: 2});
    print withRecord({a: "one", b: 2, c: 4});
    print withRecord;
    '''), function_t(t1, function_t(function_t(t1, t0), t0)));

    expect(inferSource(r'''
    let f = \rec -> rec.first + (rec.second ? 1 : 0);
    '''), function_t(record_extension_t(t0, {'second': bool_t, 'first': num_t}), num_t));

    expect(inferSource(r'''
    let f = \rec -> rec.first + (rec.second ? 1 : 0);
    print f({first: 1, second: false});
    '''), num_t);

    expect(inferSource(r'''
    let f = \rec -> rec.first + (rec.second ? 1 : 0);
    print f({second: false, first: 1});
    '''), num_t);
    expect(inferSource(r'''
    let f = \rec -> rec.first + (rec.second ? 1 : 0);
    print f({first: 1, second: false});
    print f({second: false, first: 1});
    '''), num_t);
    expect(inferSource(r'''
    let f = \rec -> rec.first + (rec.second ? 1 : 0);
    print f({first: 1, second: false});
    print f({second: false, first: 1});
    '''), num_t);
  });

  test('"modules"?', () {
    final source = map + r'''
    
    let Shapes = {
      calcArea: \shape -> shape.getArea(),
      
      newSquare: \side -> {
        side: side,
        getArea: \ -> side * side
      },
      
      newRectangle: \w, h -> {
        width: w,
        height: h,
        getArea: \ -> w * h
      },
      
      newTriangle: \base, height -> {
        base: base,
        height: height,
        getArea: \ -> 0.5 * base * height
      },
      
      newCircle: \radius -> {
        radius: radius,
        getArea: \ -> 3.14 * radius * radius
      }
    };
    
    let square = Shapes.newSquare(1);
    let rect = Shapes.newRectangle(2, 4);
    let tri = Shapes.newTriangle(2, 10);
    let circle = Shapes.newCircle(10);
    
    print Shapes.calcArea(square);
    print Shapes.calcArea(rect);
    print Shapes.calcArea(tri);
    print Shapes.calcArea(circle);
    print Shapes.calcArea({getArea: \ -> 42});
    
    map([square], Shapes.calcArea);
    map([square, square], Shapes.calcArea);
    map([square.getArea, rect.getArea, tri.getArea, circle.getArea], \f -> f());
    
    // let areas = map([square, rect, tri, circle], Shapes.calcArea); 
    //                          ^ need variants?
    ''';

    expect(inferSource(source), list_t(num_t));
  });


  test('record update', () {

    expect(inferSource(r'''
      let r1 = {a: "a"};
      let r2 = {..r1, b: false};
    '''), record_t({'a': string_t, 'b': bool_t}));
    expect(inferSource(r'''
      let r1 = {a: "a"};
      let r2 = {..r1, b: false};
      let r3 = {..r1, b: true, c: 1};
    '''), record_t({'a': string_t, 'b': bool_t, 'c': num_t}));
    expect(inferSource(r'''
      let r1 = {a: "a"};
      let r2 = {..r1, b: false};
      let r3 = {..r1, b: true, c: 1};
      let r4 = {..r1};
    '''), record_t({'a': string_t}));
    expect(inferSource(r'''
      let r1 = {};
      let r2 = {..r1};
    '''), record_empty_t);
    expect(inferSource(r'''
    \r -> {..r, one: "one"}
    '''), function_t(t0, record_extension_t(t0, {'one': string_t})));
    expect(inferSource(r'''
    \r -> {..r, one: "one", two: 2}
    '''), function_t(t0, record_extension_t(t0, {'one': string_t, 'two': num_t})));
    expect(inferSource(r'''
    let f = \r -> {..r, one: "one", two: 2};
    f({hello: 1});
    '''), record_t({'hello': num_t, 'one': string_t, 'two': num_t}));
    expect(inferSource(r'''
    let f = \r -> {..r, one: "one", two: 2};
    f({hello: 1});
    f({a: false});
    '''), record_t({'a': bool_t, 'one': string_t, 'two': num_t}));
    expect(inferSource(r'''
    let f = \r -> {..r, one: "one", two: 2};
    f({hello: 1}).one;
    f({a: false}).two;
    '''), num_t);
    expect(inferSource(r'''
    let f = \r -> {..r, one: "one", two: 2};
    f({hello: 1}).hello;
    '''), num_t);
    expect(inferSource(r'''
    let f = \r -> {..r, one: "one", two: 2};
    f({hello: 1}).hello;
    f({a: false}).a;
    '''), bool_t);
    expect(inferSource(r'''
    let f = \r -> {..r, one: "one", two: 2};
    f({one: "hello"}).one;
    '''), string_t);
    expect(inferSource(r'''
    let f = \r -> true ? {..r, x: 2} : {..r, y: 2};
    '''), isException(contains('recursive row type')));

    expect(inferSource(r'''
    let named = \r, name -> {..r, name: name};
    let x = {title: "a", name: "some name"};
    let y = named(x, "updated");
    '''), record_allow_dupe_labels_t(record_empty_t, [('title', string_t), ('name', string_t), ('name', string_t)]));
    expect(inferSource(r'''
    let named = \r, name -> {..r, name: name};
    let x = {title: "a", name: "some name"};
    let y = named(x, "updated");
    print y.name;
    '''), string_t);
    expect(inferSource(r'''
    let named = \r, name -> {..r, name: name};
    let x = {title: "a", name: 42};
    let y = named(x, "updated");
    print y.name;
    '''), string_t);
    expect(inferSource(r'''
    let named = \r, name -> {..r, name: name};
    let x = {title: "a", name: "a"};
    let y = named(x, 42);
    print y.name;
    '''), num_t);
    expect(inferSource(r'''
    let incrX = \r -> {..r, x: r.x+1};
    let point1 = {y: 1, x: 0};
    let point2 = incrX(point1);
    let point3 = incrX(point2);'''), record_allow_dupe_labels_t(record_empty_t, [
      ('y', num_t),
      ('x', num_t),
      ('x', num_t),
      ('x', num_t),
    ]));
    expect(inferSource(r'''
    let takesInt = \x -> x+1;
    let takesList = \x -> [..x];
    let takesBool = \x -> x or false;
    let a = {x: 0};
    let b = {..a, x: []};
    let c = {..a, x: false};
    let d = {..b, x: "abc"};
    takesInt(a.x);
    takesList(b.x);
    takesBool(c.x);
    d.x;
    '''), string_t);
  });
}

String? get mainStackTrace =>
  StackTrace.current
      .toString()
      .split('\n')
      .map(RegExp(r'main \((.+)\)').firstMatch)
      .whereNotNull()
      .single
      .group(1);


void testInferSource(String prefix, String source, expectedType) {
  final line = mainStackTrace;
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

Matcher isException(message) =>
  isA<Exception>().having((e) => e.toString(), 'message', message);

dynamic inferSource(String source) {
  try {
    return _inferSource(source);
  } catch (e) {
    return e;
  }
}

MonoType _inferSource(String source) {
  final LambdaCalculusExpression lc;

  if (!source.contains(';')) {
    final expr = parseExpression(source);
    lc = toLambdaCalculus(expr);
  } else {
    var i = 0;
    final newIdentifier = (String prefix) {
      final id = '$prefix#${i++}';
      return Token(TokenType.IDENTIFIER, id, id, -1, -1);
    };
    LetDeclaration? tryConvert(Statement s) => switch (s) {
      LetDeclaration() => s,
      ExpressionStatement(:final expr) => LetDeclaration(newIdentifier('expr'), expr),
      PrintStatement(:final expr) => LetDeclaration(newIdentifier('print'), expr),
      AssertStatement(:final expr) => LetDeclaration(newIdentifier('assert'), expr),
      ReturnStatement() ||
      Block() ||
      IfStatement() => null,
    };

    final statements = parse(source);
    final lets = [
      for (final s in statements)
        if (tryConvert(s) case final let?)
          let
    ];
    if (lets.isEmpty) fail('source does not contain any supported statements');
    if (lets.length < statements.length) fail('source contains unsupported statements');
    lc = toLet(lets);
  }

  final context = newContext();
  final inferred = infer(lc, context);
  final normalized = normalizeTypeVariableIds(inferred);

  //print('''
  //______________________________
  //source:          $source
  //inferred type:   $normalized
  //''');
  return normalized;
}

MonoType infer(LambdaCalculusExpression expr, Context context) {
  TypeVariable.counter = 0;
  final (substitution, t) = w(expr, context);
  final type = substitution.appliedTo(t);
  return type;
}
