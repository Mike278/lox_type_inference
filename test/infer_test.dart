import 'package:lox/expr.dart';
import 'package:lox/hindley_milner_api.dart' hide contains;
import 'package:lox/hindley_milner_lambda_calculus.dart';
import 'package:lox/lox_lambda_calculus.dart';
import 'package:lox/scanner.dart';
import 'package:lox/utils.dart';
import 'package:test/test.dart';

import 'test_utils.dart';

void main() {
  
  final testInferFunction = testInferSource.partial('infer function');
  
  // arity 0
  testInferFunction(r'\  -> 1',  't0 -> Num');

  // arity 1
  testInferFunction(r'\x -> 1',  't0 -> Num');
  testInferFunction(r'\x -> x',  't0 -> t0');

  // arity 2
  testInferFunction(r'\x, y -> 1',   't0, t1 -> Num');
  testInferFunction(r'\x, y -> x',   't0, t1 -> t0');
  testInferFunction(r'\x, y -> y',   't0, t1 -> t1');
  testInferFunction(r'\x, y -> []',  't0, t1 -> List[t2]');
  testInferFunction(r'\x, y -> x(y and false)',  '(Bool -> t0), Bool -> t0');
  testInferFunction(r'\x, y -> x(y)',            '(t0 -> t1), t0 -> t1');

  // arity 3
  testInferFunction(r'\x, y, z -> 1',             't0, t1, t2 -> Num');
  testInferFunction(r'\x, y, z -> x',             't0, t1, t2 -> t0');
  testInferFunction(r'\x, y, z -> y',             't0, t1, t2 -> t1');
  testInferFunction(r'\x, y, z -> z',             't0, t1, t2 -> t2');
  testInferFunction(r'\x, y, z -> x or y',        'Bool, Bool, t0 -> Bool');
  testInferFunction(r'\x, y, z -> z(x or y)',     'Bool, Bool, (Bool -> t0) -> t0');
  testInferFunction(r'\x, y, z -> z(x or y, x)',  'Bool, Bool, (Bool, Bool -> t0) -> t0');

  // unary function body
  testInferFunction(r'\x -> -x',  'Num -> Num');
  testInferFunction(r'\x -> !x',  'Bool -> Bool');
  testInferFunction(r'\x, y -> -x',  'Num, t0 -> Num');
  testInferFunction(r'\x, y -> !x',  'Bool, t0 -> Bool');

  // binary function body
  testInferFunction(r'\x, y -> x and y',  'Bool, Bool -> Bool');
  testInferFunction(r'\x, y -> x or y',   'Bool, Bool -> Bool');
  testInferFunction(r'\x, y -> x + y',    'Num, Num -> Num');
  testInferFunction(r'\x, y -> x - y',    'Num, Num -> Num');
  testInferFunction(r'\x, y -> x * y',    'Num, Num -> Num');
  testInferFunction(r'\x, y -> x / y',    'Num, Num -> Num');
  testInferFunction(r'\x, y -> x - -y',   'Num, Num -> Num');

  // ternary function body
  testInferFunction(r'\c, x, y -> c ? x : y',            'Bool, t0, t0 -> t0');
  testInferFunction(r'\c, x, y -> c ? x : y+1',          'Bool, Num, Num -> Num');
  testInferFunction(r'\c, x, y -> c ? x : -y',           'Bool, Num, Num -> Num');
  testInferFunction(r'\c, x, y -> c ? x : y or false',   'Bool, Bool, Bool -> Bool');
  testInferFunction(r'\c, x, y -> c ? x : !y',           'Bool, Bool, Bool -> Bool');

  // function call in function body
  testInferFunction(r'\x -> x("h", 1)', '(String, Num -> t0) -> t0');

  // complex
  testInferFunction(r'\x, y, z -> x(y and false, z + 1)',  '(Bool, Num -> t0), Bool, Num -> t0');


  final testInferCall = testInferSource.partial('infer call');

  // arity 0
  testInferCall(r'(\  -> 1)()', 'Num');

  // arity 1
  testInferCall(r'(\x -> x)(1)', 'Num');
  testInferCall(r'(\x -> x)(-1)', 'Num');
  testInferCall(r'(\x -> 1)([])', 'Num');
  testInferCall(r'(\x -> x)([])',  'List[t0]');
  testInferCall(r'(\x -> [])(1)',  'List[t0]');

  // arity 2
  testInferCall(r'(\x, y -> 1)("ok", false)', 'Num');
  testInferCall(r'(\x, y -> x)("ok", false)',  'String');
  testInferCall(r'(\x, y -> y)("ok", false)',  'Bool');

  // placeholder
  testInferCall(r'let f = \x, y -> (x ? 1 : 0) + y; let f1 = f(false, _);', 'Num -> Num');
  testInferCall(r'let f = \x, y -> (x ? 1 : 0) + y; let f1 = f(false, _); f1(1);', 'Num');
  testInferCall(r'let f = \x, y -> (x ? 1 : 0) + y; let f1 = f(_, 1);', 'Bool -> Num');
  testInferCall(r'let f = \x, y -> (x ? 1 : 0) + y; let f1 = f(_, 1); f1(false);', 'Num');


  // complex
  testInferCall(r'(\x, y -> x(y and false)) (\b -> 1, false)', 'Num');
  testInferCall(r'(\x, y -> x(y and false)) (\b -> b, false)',  'Bool');
  testInferCall(r'(\x, y -> x(y and false)) (\b -> b, true)',  'Bool');
  testInferCall(r'(\x, y -> x(y and false)) (\b -> 1, true)', 'Num');
  testInferCall(r'(\x, y -> x(y)) (\b -> 1, true)', 'Num');
  testInferCall(r'(\x -> x("h")) (\b -> 1)', 'Num');
  testInferCall(r'(\x -> "h") (\b, c -> 1)',  'String');
  testInferCall(r'(\x -> x) (\b, c -> 1)',  't0, t1 -> Num');
  testInferCall(r'(\x -> x)(\f -> f("h", 1))', '(String, Num -> t0) -> t0');
  testInferCall(r'(\x, y, z -> x(y and false, z + 1)) (\a, b -> b, true, 1)', 'Num');
  testInferCall(r'(\x -> \y -> \z -> x(y and false)(z + 1)) (\a -> \b -> b)(true)(1)', 'Num');
  testInferCall(r'(\x -> x(1, 1)) (\a, b -> "h")',  'String');

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
    final result = infer(expr, newContext()).toString();
    expect(result, 'String');
  });


  final testInferListLiteral = testInferSource.partial('infer list');

  testInferListLiteral('[1]'                , 'List[Num]');
  testInferListLiteral('[1, 2]'             , 'List[Num]');
  testInferListLiteral('[1, 2, 3]'          , 'List[Num]');
  testInferListLiteral('[1, 2, 3, 4]'       , 'List[Num]');

  testInferListLiteral('["h"]'               , 'List[String]');
  testInferListLiteral('["h", "h"]'          , 'List[String]');
  testInferListLiteral('["h", "h", "h"]'     , 'List[String]');
  testInferListLiteral('["h", "h", "h", "h"]', 'List[String]');

  testInferListLiteral('[[]]'             , 'List[List[t0]]');
  testInferListLiteral('[[], []]'         , 'List[List[t0]]');
  testInferListLiteral('[[], [], []]'     , 'List[List[t0]]');
  testInferListLiteral('[[], [], [], []]' , 'List[List[t0]]');

  testInferListLiteral('[["h"]]'                         , 'List[List[String]]');
  testInferListLiteral('[["h"], ["h"]]'                  , 'List[List[String]]');
  testInferListLiteral('[["h"], ["h"], ["h"]]'           , 'List[List[String]]');
  testInferListLiteral('[["h"], ["h"], ["h"], ["h"]]'    , 'List[List[String]]');

  testInferListLiteral('[[], ["h"]]'                     , 'List[List[String]]');
  testInferListLiteral('[[], ["h"], ["h"]]'              , 'List[List[String]]');
  testInferListLiteral('[[], ["h"], ["h"], ["h"]]'       , 'List[List[String]]');
  testInferListLiteral('[[], ["h"], ["h"], ["h"], ["h"]]', 'List[List[String]]');

  testInferListLiteral('[["h"], []]'                     , 'List[List[String]]');
  testInferListLiteral('[["h"], ["h"], []]'              , 'List[List[String]]');
  testInferListLiteral('[["h"], ["h"], ["h"], []]'       , 'List[List[String]]');
  testInferListLiteral('[["h"], ["h"], ["h"], ["h"], []]', 'List[List[String]]');

  testInferListLiteral(r'\f -> [f()]', '(Unit -> t0) -> List[t0]');
  testInferListLiteral(r'\f -> [f() + 1]', '(Unit -> Num) -> List[Num]');

  testInferListLiteral('[1, ..[]]',                                      'List[Num]');
  testInferListLiteral('[1, ..[2]]',                                     'List[Num]');
  testInferListLiteral('[1, ..[2, 3]]',                                  'List[Num]');
  testInferListLiteral('[1, ..[2, 3, 4]]',                               'List[Num]');
  testInferListLiteral('[1, ..[2, 3, 4], 5]',                            'List[Num]');
  testInferListLiteral('[1, ..[2, 3, 4], 5, 6]',                         'List[Num]');
  testInferListLiteral('[1, ..[2, 3, 4], 5, 6, ..[]]',                   'List[Num]');
  testInferListLiteral('[1, ..[2, 3, 4], 5, 6, ..[7]]',                  'List[Num]');
  testInferListLiteral('[1, ..[2, 3, 4], ..[5]]',                        'List[Num]');
  testInferListLiteral('[..[1], ..[2, 3, 4], ..[5]]',                    'List[Num]');
  testInferListLiteral('[..[[1]], ..[[2], [3, 4]], ..[[5]]]',            'List[List[Num]]');
  testInferListLiteral('[..[..[1]], ..[..[2], ..[3, 4]], ..[..[5]], 6]', 'List[Num]');

  testInferListLiteral(r'\f -> [..f]', 'List[t0] -> List[t0]');
  testInferListLiteral(r'\f -> [..f, 1]', 'List[Num] -> List[Num]');
  testInferListLiteral(r'\f -> [[..f]]', 'List[t0] -> List[List[t0]]');

  testInferListLiteral('[..[]]', 'List[t0]');
  testInferListLiteral('[..[], []]', 'List[List[t0]]');
  testInferListLiteral('[..[], ..[]]', 'List[t0]');

  test('let', () {
    expect(inferSource(r'let factorial = \n -> n > 0 ? n * factorial(n - 1) : 1;'), 'Num -> Num');
    expect(inferSource(r'let x = 1;'), 'Num');
    expect(inferSource(r'''
    let x = 1;
    let y = "h";
    '''), 'String');
    expect(inferSource(r'''
    let x = \list -> [..list, 1]; 
    let y = x([4]);
    '''), 'List[Num]');

    final f1 = (source: r'\x, y -> List.first(x) + y',       expectedType: 'List[Num], Num -> Num');
    final f2 = (source: r'\x, y -> List.first(x) or y',      expectedType: 'List[Bool], Bool -> Bool');
    final f3 = (source: r'\x, y -> (true ? x : y) + 1',      expectedType: 'Num, Num -> Num');
    final f4 = (source: r'\x, y -> (true ? x : y) or false', expectedType: 'Bool, Bool -> Bool');

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

    expect(
      inferSource(fold),
      'List[t1], t0, (t0, t1 -> t0) -> t0',
    );
    expect(
      inferSource(fold + r' fold([1,2,3], false, \state, element -> "wat");'),
      'Type unification error: Bool != String',
    );

    expect(inferSource(fold + r'''
      fold([1,2,3], false, \state, num -> num > 1 ? state : false);
    '''), 'Bool');
    expect(inferSource(fold + r'''
      fold([1,2,3], false, \state, num -> num > 1 ? state : false);
      fold(["a", "b", "c"], 0, \state, str -> str == "a" ? state+1 : state);
    '''), 'Num');

    expect(inferSource(map), 'List[t1], (t1 -> t0) -> List[t0]');
    expect(inferSource(map + r'''
      map([1,2,3], \x -> x > 1);
    '''), 'List[Bool]');
    expect(inferSource(map + r'''
      map([1,2,3], \x -> x > 1);
      map([false], \x -> x ? 5 : 10);
    '''), 'List[Num]');

    expect(inferSource(reduce + r'''
      reduce([4,5,6], \max, e -> e > max ? e : max);
    '''), 'Num');
    expect(inferSource(reduce + r'''
      reduce([4,5,6], \max, e -> e > max ? e : max);
      reduce([true, false, true], \state, b -> state and b);
    '''), 'Bool');
    expect(inferSource(reduce + r'''
      let r = reduce; 
      r([4,5,6], \max, e -> e > max ? e : max);
      r([true, false, true], \state, b -> state and b);
    '''), 'Bool');

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
    '''), '{name = String, age = Num}');

    expect(inferSource(map + reduce + employees + r'''
      let maxAge = reduce(
          map(employees, \e -> e.age),
          \highest, age -> age > highest ? age : highest
      );
    '''), 'Num');
  });

  final testInferRecord = testInferSource.partial('infer record');
  testInferRecord('let y = {};', '{}');
  testInferRecord('let y = {foo: "foo"};', '{foo = String}');
  testInferRecord('let y = {foo: "foo"}; let x = y.foo;', 'String');
  testInferRecord(r'let double = \x -> x * 2; let y = {foo: "foo", bar: double(4)};', '{foo = String, bar = Num}');
  testInferRecord('let y = {foo: "foo"}; let x = {a: 1, ok: y.foo};', '{a = Num, ok = String}');
  testInferRecord(r'let y = \x -> {foo: 1};', 't0 -> {foo = Num}');
  testInferRecord(r'let r = {id: \x -> x}; let a = r.id(1);', 'Num');
  testInferRecord(r'let r = {id: \x -> x}; let a = r.id(1); let b = r.id("b");', 'String');
  testInferRecord(r'List.empty([]);', 'Bool');
  testInferRecord(r'List.first([1]);', 'Num');
  testInferRecord(r'List.first(["b"]);', 'String');
  testInferRecord(r'print List.first([1]); '
                  r'print List.first(["b"]);', 'String');
  testInferRecord(r'let f = List.first; f([1]);', 'Num');
  testInferRecord(r'let f = \x -> {a: x}; f(5).a;', 'Num');
  testInferRecord(r'let f = \x -> {a: x}; f(5).a; f("hi").a;', 'String');

  test('infer accessing field of record thats passed in as a parameter', () {
    expect(inferSource(r'\someRecord -> someRecord.bar'), '{..t0, bar = t1} -> t1');
    expect(inferSource(r'\someRecord -> someRecord.bar + 1'), '{..t0, bar = Num} -> Num');
    expect(inferSource(r'\someRecord, someNum -> someRecord.bar + someNum'), '{..t0, bar = Num}, Num -> Num');
    expect(inferSource(r'''
    let getAge = \person -> person.age;
    let bob = {age: 100};
    let age = getAge(bob);
    '''), 'Num');
    expect(inferSource(r'''
    let getAge = \person -> person.age;
    let getBirthYear = \currentYear, person -> currentYear - getAge(person);
    '''), 'Num, {..t0, age = Num} -> Num');
    expect(inferSource(r'''
    let getAge = \person -> person.age;
    let getBirthYear = \currentYear, person -> currentYear - getAge(person);
    let bob = {age: 100};
    let bornIn = getBirthYear(2024, bob);
    '''), 'Num');

    expect(inferSource(r'''
    let getAge = \person -> person.age;
    let getBirthYear = \args -> args.currentYear - getAge(args.person);
    let bornIn = getBirthYear({currentYear: 2024, person: {age: 100}});
    '''), 'Num');

    expect(inferSource(r'''
    let getAge = \person -> person.age;
    let getBirthYear = \args -> args.currentYear - getAge(args.person);
    let bornIn = getBirthYear({currentYear: 2024, person: {age: 100, someExtraArg: "hi"}});
    '''), 'Num');

    expect(inferSource(r'''
    let withRecord = \x -> \f -> f(x);
    print withRecord({a: "one", b: 2});
    '''), '({a = String, b = Num} -> t0) -> t0');

    expect(inferSource(r'''
    let withRecord = \x -> \f -> f(x);
    print withRecord({a: "one", b: 2});
    print withRecord({a: "one", b: 2, c: 4});
    '''), '({a = String, b = Num, c = Num} -> t0) -> t0');

    expect(inferSource(r'''
    let withRecord = \x -> \f -> f(x);
    print withRecord({a: "one", b: 2});
    print withRecord({a: "one", b: 2, c: 4});
    print withRecord;
    '''), 't1, (t1 -> t0) -> t0');

    expect(inferSource(r'''
    let f = \rec -> rec.first + (rec.second ? 1 : 0);
    '''), '{..t0, second = Bool, first = Num} -> Num');

    expect(inferSource(r'''
    let f = \rec -> rec.first + (rec.second ? 1 : 0);
    print f({first: 1, second: false});
    '''), 'Num');

    expect(inferSource(r'''
    let f = \rec -> rec.first + (rec.second ? 1 : 0);
    print f({second: false, first: 1});
    '''), 'Num');
    expect(inferSource(r'''
    let f = \rec -> rec.first + (rec.second ? 1 : 0);
    print f({first: 1, second: false});
    print f({second: false, first: 1});
    '''), 'Num');
    expect(inferSource(r'''
    let f = \rec -> rec.first + (rec.second ? 1 : 0);
    print f({first: 1, second: false});
    print f({second: false, first: 1});
    '''), 'Num');
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

    expect(inferSource(source), 'List[Num]');
  });


  test('record update', () {

    expect(inferSource(r'''
      let r1 = {a: "a"};
      let r2 = {..r1, b: false};
    '''), '{a = String, b = Bool}');
    expect(inferSource(r'''
      let r1 = {a: "a"};
      let r2 = {..r1, b: false};
      let r3 = {..r1, b: true, c: 1};
    '''), '{a = String, b = Bool, c = Num}');
    expect(inferSource(r'''
      let r1 = {a: "a"};
      let r2 = {..r1, b: false};
      let r3 = {..r1, b: true, c: 1};
      let r4 = {..r1};
    '''), '{a = String}');
    expect(inferSource(r'''
      let r1 = {};
      let r2 = {..r1};
    '''), '{}');
    expect(inferSource(r'''
    \r -> {..r, one: "one"}
    '''), 't0 -> {..t0, one = String}');
    expect(inferSource(r'''
    \r -> {..r, one: "one", two: 2}
    '''), 't0 -> {..t0, one = String, two = Num}');
    expect(inferSource(r'''
    let f = \r -> {..r, one: "one", two: 2};
    f({hello: 1});
    '''), '{hello = Num, one = String, two = Num}');
    expect(inferSource(r'''
    let f = \r -> {..r, one: "one", two: 2};
    f({hello: 1});
    f({a: false});
    '''), '{a = Bool, one = String, two = Num}');
    expect(inferSource(r'''
    let f = \r -> {..r, one: "one", two: 2};
    f({hello: 1}).one;
    f({a: false}).two;
    '''), 'Num');
    expect(inferSource(r'''
    let f = \r -> {..r, one: "one", two: 2};
    f({hello: 1}).hello;
    '''), 'Num');
    expect(inferSource(r'''
    let f = \r -> {..r, one: "one", two: 2};
    f({hello: 1}).hello;
    f({a: false}).a;
    '''), 'Bool');
    expect(inferSource(r'''
    let f = \r -> {..r, one: "one", two: 2};
    f({one: "hello"}).one;
    '''), 'String');
    expect(inferSource(r'''
    let f = \r -> true ? {..r, x: 2} : {..r, y: 2};
    '''), isException(contains('recursive row type')));

    expect(inferSource(r'''
    let named = \r, name -> {..r, name: name};
    let x = {title: "a", name: "some name"};
    let y = named(x, "updated");
    '''), '{title = String, name = String, name = String}');
    expect(inferSource(r'''
    let named = \r, name -> {..r, name: name};
    let x = {title: "a", name: "some name"};
    let y = named(x, "updated");
    print y.name;
    '''), 'String');
    expect(inferSource(r'''
    let named = \r, name -> {..r, name: name};
    let x = {title: "a", name: 42};
    let y = named(x, "updated");
    print y.name;
    '''), 'String');
    expect(inferSource(r'''
    let named = \r, name -> {..r, name: name};
    let x = {title: "a", name: "a"};
    let y = named(x, 42);
    print y.name;
    '''), 'Num');
    expect(inferSource(r'''
    let incrX = \r -> {..r, x: r.x+1};
    let point1 = {y: 1, x: 0};
    let point2 = incrX(point1);
    let point3 = incrX(point2);'''),
        '{y = Num, x = Num, x = Num, x = Num}'
    );
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
    '''), 'String');
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
    return _inferSource(source).toString();
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
