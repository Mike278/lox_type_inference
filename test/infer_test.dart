import 'package:lox/coordinator.dart';
import 'package:lox/expr.dart';
import 'package:lox/hindley_milner_api.dart';
import 'package:lox/hindley_milner_lox.dart';
import 'package:lox/mark_types.dart';
import 'package:lox/utils.dart';
import 'package:test/test.dart';
import 'package:test_api/src/backend/invoker.dart'; // ignore: depend_on_referenced_packages

import 'test_utils.dart';

void main() {

  final testInferFunction = testInferSource.partial('infer function');

  // arity 0
  testInferFunction(r'\  -> 1',  't0 -> Num');

  // arity 1
  testInferFunction(r'\x -> 1',  't0 -> Num');
  testInferFunction(r'\_ -> 1',  't0 -> Num');
  testInferFunction(r'\x -> x',  't0 -> t0');

  // arity 2
  testInferFunction(r'\x, y -> 1',   't0, t1 -> Num');
  testInferFunction(r'\_, _ -> 1',   't0, t1 -> Num');
  testInferFunction(r'\x, y -> x',   't0, t1 -> t0');
  testInferFunction(r'\x, y -> y',   't0, t1 -> t1');
  testInferFunction(r'\x, y -> []',  't0, t1 -> List[t2]');
  testInferFunction(r'\x, y -> x(y and false)',  '(Bool -> t0), Bool -> t0');
  testInferFunction(r'\x, y -> x(y)',            '(t0 -> t1), t0 -> t1');

  // arity 3
  testInferFunction(r'\x, y, z -> 1',             't0, t1, t2 -> Num');
  testInferFunction(r'\_, _, _ -> 1',             't0, t1, t2 -> Num');
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
    expect(_inferSource(r'let factorial = \n -> n > 0 ? n * factorial(n - 1) : 1;'), 'Num -> Num');
    expect(_inferSource(r'let x = 1;'), 'Num');
    expect(_inferSource(r'''
    let x = 1;
    let y = "h";
    '''), 'String');
    expect(_inferSource(r'''
    let x = \list -> [..list, 1]; 
    let y = x([4]);
    '''), 'List[Num]');

    final f1 = (source: r'\x, y -> List.first(x) + y',       expectedType: 'List[Num], Num -> Num');
    final f2 = (source: r'\x, y -> List.first(x) or y',      expectedType: 'List[Bool], Bool -> Bool');
    final f3 = (source: r'\x, y -> (true ? x : y) + 1',      expectedType: 'Num, Num -> Num');
    final f4 = (source: r'\x, y -> (true ? x : y) or false', expectedType: 'Bool, Bool -> Bool');

    expect(_inferSource(f1.source),  f1.expectedType);
    expect(_inferSource(f2.source),  f2.expectedType);
    expect(_inferSource(f3.source),  f3.expectedType);
    expect(_inferSource(f4.source),  f4.expectedType);

    expect(_inferSource('let f = ${f1.source};'),  f1.expectedType);
    expect(_inferSource('let f = ${f2.source};'),  f2.expectedType);
    expect(_inferSource('let f = ${f3.source};'),  f3.expectedType);
    expect(_inferSource('let f = ${f4.source};'),  f4.expectedType);
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

  final where = fold + r'''
  let where = \list, fn ->
      fold(list, [], \state, element -> 
          fn(element) ? [..state, element] : state);
  ''';


  test('recursive polymorphic functions', () {

    expect(
      _inferSource(r'''
let make_counter = \i, fn {
  let count = \ {
    fn(i + 1);
    return make_counter(i+1, fn);
  };

  return count;
};

make_counter(0, \value { print value*value; })
()
()
()
()
()
()
;
      '''),
      'idk but it shouldnt throw',
      skip: true, // todo
    );
    expect(
      _inferSource(fold),
      'List[t0], t1, (t1, t0 -> t1) -> t1',
    );
    expect(
      _inferSource(fold + r' fold([1,2,3], false, \state, element -> "wat");'),
      isTypeMismatch(
        lhs: 'Bool',
        rhs: 'String',
      ),
    );

    expect(_inferSource(fold + r'''
      fold([1,2,3], false, \state, num -> num > 1 ? state : false);
    '''), 'Bool');
    expect(_inferSource(fold + r'''
      fold([1,2,3], false, \state, num -> num > 1 ? state : false);
      fold(["a", "b", "c"], 0, \state, str -> str == "a" ? state+1 : state);
    '''), 'Num');

    expect(_inferSource(map), 'List[t0], (t0 -> t1) -> List[t1]');
    expect(_inferSource(map + r'''
      map([1,2,3], \x -> x > 1);
    '''), 'List[Bool]');
    expect(_inferSource(map + r'''
      map([1,2,3], \x -> x > 1);
      map([false], \x -> x ? 5 : 10);
    '''), 'List[Num]');

    expect(_inferSource(reduce + r'''
      reduce([4,5,6], \max, e -> e > max ? e : max);
    '''), 'Num');
    expect(_inferSource(reduce + r'''
      reduce([4,5,6], \max, e -> e > max ? e : max);
      reduce([true, false, true], \state, b -> state and b);
    '''), 'Bool');
    expect(_inferSource(reduce + r'''
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

    expect(_inferSource(reduce + employees + r'''
      let employee_with_max_age = reduce(
          employees,
          \highest, employee ->
              employee.age > highest.age
                  ? employee
                  : highest
      );
    '''), '{name: String, age: Num}');

    expect(_inferSource(map + reduce + employees + r'''
      let max_age = reduce(
          map(employees, \e -> e.age),
          \highest, age -> age > highest ? age : highest
      );
    '''), 'Num');

    expect(_inferSource(where + r'''
    let sort = \list {
      if List.empty(list) then return [];
      let first = List.first(list);
      let rest = List.rest(list);
      return [
        ..rest \> where (_, \e -> e < first) \> sort,
        first,
        ..rest \> where (_, \e -> e >= first) \> sort
      ];
    };
    '''), 'List[Num] -> List[Num]');
  });

  final testInferRecord = testInferSource.partial('infer record');
  testInferRecord('let y = {};', '{}');
  testInferRecord('let y = {foo: "foo"};', '{foo: String}');
  testInferRecord('let y = {foo: "foo"}; let x = y.foo;', 'String');
  testInferRecord(r'let double = \x -> x * 2; let y = {foo: "foo", bar: double(4)};', '{foo: String, bar: Num}');
  testInferRecord('let y = {foo: "foo"}; let x = {a: 1, ok: y.foo};', '{a: Num, ok: String}');
  testInferRecord(r'let y = \x -> {foo: 1};', 't0 -> {foo: Num}');
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
    expect(_inferSource(r'\some_record -> some_record.bar'), '{bar: t1} -> t1');
    expect(_inferSource(r'\some_record -> some_record.bar + 1'), '{bar: Num} -> Num');
    expect(_inferSource(r'\some_record, some_num -> some_record.bar + some_num'), '{bar: Num}, Num -> Num');
    expect(_inferSource(r'''
    let get_age = \person -> person.age;
    let bob = {age: 100};
    let age = get_age(bob);
    '''), 'Num');
    expect(_inferSource(r'''
    let get_age = \person -> person.age;
    let get_birth_year = \current_year, person -> current_year - get_age(person);
    '''), 'Num, {age: Num} -> Num');
    expect(_inferSource(r'''
    let get_age = \person -> person.age;
    let get_birth_year = \current_year, person -> current_year - get_age(person);
    let bob = {age: 100};
    let born_in = get_birth_year(2024, bob);
    '''), 'Num');

    expect(_inferSource(r'''
    let get_age = \person -> person.age;
    let get_birth_year = \args -> args.current_year - get_age(args.person);
    let born_in = get_birth_year({current_year: 2024, person: {age: 100}});
    '''), 'Num');

    expect(_inferSource(r'''
    let get_age = \person -> person.age;
    let get_birth_year = \args -> args.current_year - get_age(args.person);
    let born_in = get_birth_year({current_year: 2024, person: {age: 100, some_extra_arg: "hi"}});
    '''), 'Num');

    expect(_inferSource(r'''
    let with_record = \x -> \f -> f(x);
    print with_record({a: "one", b: 2});
    '''), '({a: String, b: Num} -> t0) -> t0');

    expect(_inferSource(r'''
    let with_record = \x -> \f -> f(x);
    print with_record({a: "one", b: 2});
    print with_record({a: "one", b: 2, c: 4});
    '''), '({a: String, b: Num, c: Num} -> t0) -> t0');

    expect(_inferSource(r'''
    let with_record = \x -> \f -> f(x);
    print with_record({a: "one", b: 2});
    print with_record({a: "one", b: 2, c: 4});
    print with_record;
    '''), 't0, (t0 -> t1) -> t1');

    expect(_inferSource(r'let f = \rec -> rec.first + (rec.second ? 1 : 0);'), '{second: Bool, first: Num} -> Num');

    expect(_inferSource(r'''
    let f = \rec -> rec.first + (rec.second ? 1 : 0);
    print f({first: 1, second: false});
    '''), 'Num');

    expect(_inferSource(r'''
    let f = \rec -> rec.first + (rec.second ? 1 : 0);
    print f({second: false, first: 1});
    '''), 'Num');
    expect(_inferSource(r'''
    let f = \rec -> rec.first + (rec.second ? 1 : 0);
    print f({first: 1, second: false});
    print f({second: false, first: 1});
    '''), 'Num');
    expect(_inferSource(r'''
    let f = \rec -> rec.first + (rec.second ? 1 : 0);
    print f({first: 1, second: false});
    print f({second: false, first: 1});
    '''), 'Num');
  });

  test('"modules"?', () {
    final source = map + r'''
    
    let Shapes = {
      calc_area: \shape -> shape.get_area(),
      
      new_square: \side -> {
        side: side,
        get_area: \ -> side * side
      },
      
      new_rectangle: \w, h -> {
        width: w,
        height: h,
        get_area: \ -> w * h
      },
      
      new_triangle: \base, height -> {
        base: base,
        height: height,
        get_area: \ -> 0.5 * base * height
      },
      
      new_circle: \radius -> {
        radius: radius,
        get_area: \ -> 3.14 * radius * radius
      }
    };
    
    let square = Shapes.new_square(1);
    let rect = Shapes.new_rectangle(2, 4);
    let tri = Shapes.new_triangle(2, 10);
    let circle = Shapes.new_circle(10);
    
    print Shapes.calc_area(square);
    print Shapes.calc_area(rect);
    print Shapes.calc_area(tri);
    print Shapes.calc_area(circle);
    print Shapes.calc_area({get_area: \ -> 42});
    
    map([square], Shapes.calc_area);
    map([square, square], Shapes.calc_area);
    map([square.get_area, rect.get_area, tri.get_area, circle.get_area], \f -> f());
    
    // let areas = map([square, rect, tri, circle], Shapes.calc_area); 
    //                          ^ need variants?
    ''';

    expect(_inferSource(source), 'List[Num]');
  });


  test('record update', () {

    expect(_inferSource(r'''
      let r1 = {a: "a"};
      let r2 = {..r1, b: false};
    '''), '{a: String, b: Bool}');
    expect(_inferSource(r'''
      let r1 = {a: "a"};
      let r2 = {..r1, b: false};
      let r3 = {..r1, b: true, c: 1};
    '''), '{a: String, b: Bool, c: Num}');
    expect(_inferSource(r'''
      let r1 = {a: "a"};
      let r2 = {..r1, b: false};
      let r3 = {..r1, b: true, c: 1};
      let r4 = {..r1};
    '''), '{a: String}');
    expect(_inferSource(r'''
      let r1 = {};
      let r2 = {..r1};
    '''), '{}');
    expect(_inferSource(r'\r -> {..r, one: "one"}'), 't0 -> {one: String}');
    expect(_inferSource(r'\r -> {..r, one: "one", two: 2}'), 't0 -> {one: String, two: Num}');
    expect(_inferSource(r'''
    let f = \r -> {..r, one: "one", two: 2};
    f({hello: 1});
    '''), '{hello: Num, one: String, two: Num}');
    expect(_inferSource(r'''
    let f = \r -> {..r, one: "one", two: 2};
    f({hello: 1});
    f({a: false});
    '''), '{a: Bool, one: String, two: Num}');
    expect(_inferSource(r'''
    let f = \r -> {..r, one: "one", two: 2};
    f({hello: 1}).one;
    f({a: false}).two;
    '''), 'Num');
    expect(_inferSource(r'''
    let f = \r -> {..r, one: "one", two: 2};
    f({hello: 1}).hello;
    '''), 'Num');
    expect(_inferSource(r'''
    let f = \r -> {..r, one: "one", two: 2};
    f({hello: 1}).hello;
    f({a: false}).a;
    '''), 'Bool');
    expect(_inferSource(r'''
    let f = \r -> {..r, one: "one", two: 2};
    f({one: "hello"}).one;
    '''), 'String');
    expect(_inferSource(r'let f = \r -> true ? {..r, x: 2} : {..r, y: 2};'), isA<RecursiveRowTypes>());

    expect(_inferSource(r'''
    let named = \r, name -> {..r, name: name};
    let x = {title: "a", name: "some name"};
    let y = named(x, "updated");
    '''), '{title: String, name: String, name: String}');
    expect(_inferSource(r'''
    let named = \r, name -> {..r, name: name};
    let x = {title: "a", name: "some name"};
    let y = named(x, "updated");
    print y.name;
    '''), 'String');
    expect(_inferSource(r'''
    let named = \r, name -> {..r, name: name};
    let x = {title: "a", name: 42};
    let y = named(x, "updated");
    print y.name;
    '''), 'String');
    expect(_inferSource(r'''
    let named = \r, name -> {..r, name: name};
    let x = {title: "a", name: "a"};
    let y = named(x, 42);
    print y.name;
    '''), 'Num');
    expect(_inferSource(r'''
    let incr_x = \r -> {..r, x: r.x+1};
    let point1 = {y: 1, x: 0};
    let point2 = incr_x(point1);
    let point3 = incr_x(point2);'''),
        '{y: Num, x: Num, x: Num, x: Num}',
    );
    expect(_inferSource(r'''
    let takes_int = \x -> x+1;
    let takes_list = \x -> [..x];
    let takes_bool = \x -> x or false;
    let a = {x: 0};
    let b = {..a, x: []};
    let c = {..a, x: false};
    let d = {..b, x: "abc"};
    takes_int(a.x);
    takes_list(b.x);
    takes_bool(c.x);
    d.x;
    '''), 'String');
  });

  group('statements', () {

    test(r'let fn = \ {};', () => expectedType('t0 -> Unit'));
    test(r'let fn = \x {};', () => expectedType('t0 -> Unit'));
    test(r'let fn = \x { return x; };', () => expectedType('t0 -> t0'));
    test(r'let fn = \x { return [x]; };', () => expectedType('t0 -> List[t0]'));
    test(r'let fn = \x { return "a"; };', () => expectedType('t0 -> String'));
    test(r'let fn = \x { return ["a"]; };', () => expectedType('t0 -> List[String]'));
    test(r'let fn = \x { return [x, "a"]; };', () => expectedType('String -> List[String]'));

    test(r'let fn = \ { print 1; };', () => expectedType('t0 -> Unit'));
    test(r'let fn = \x { print 1; };', () => expectedType('t0 -> Unit'));
    test(r'let fn = \x { print 1; return x; };', () => expectedType('t0 -> t0'));
    test(r'let fn = \x { print 1; return [x]; };', () => expectedType('t0 -> List[t0]'));
    test(r'let fn = \x { print 1; return "a"; };', () => expectedType('t0 -> String'));
    test(r'let fn = \x { print 1; return ["a"]; };', () => expectedType('t0 -> List[String]'));
    test(r'let fn = \x { print 1; return [x, "a"]; };', () => expectedType('String -> List[String]'));

    test(r'let fn = \ { let a = 1; };', () => expectedType('t0 -> Unit'));
    test(r'let fn = \x { let a = 1; };', () => expectedType('t0 -> Unit'));
    test(r'let fn = \x { let a = 1; return x; };', () => expectedType('t0 -> t0'));
    test(r'let fn = \x { let a = 1; return [x]; };', () => expectedType('t0 -> List[t0]'));
    test(r'let fn = \x { let a = 1; return "a"; };', () => expectedType('t0 -> String'));
    test(r'let fn = \x { let a = 1; return ["a"]; };', () => expectedType('t0 -> List[String]'));
    test(r'let fn = \x { let a = 1; return [x, "a"]; };', () => expectedType('String -> List[String]'));

    test(r'let fn = \ {};                    fn();',  () => expectedType('Unit'));
    test(r'let fn = \x {};                   fn(1);', () => expectedType('Unit'));
    test(r'let fn = \x { return x; };        fn(1);', () => expectedType('Num'));
    test(r'let fn = \x { return [x]; };      fn(1);', () => expectedType('List[Num]'));
    test(r'let fn = \x { return "a"; };      fn(1);', () => expectedType('String'));
    test(r'let fn = \x { return ["a"]; };    fn(1);', () => expectedType('List[String]'));
    test(r'let fn = \x { return [x, "a"]; }; fn("1");', () => expectedType('List[String]'));

    test(r'let fn = \  { print 1; };                  fn();',  () => expectedType('Unit'));
    test(r'let fn = \x { print 1; };                  fn(1);', () => expectedType('Unit'));
    test(r'let fn = \x { print 1; return x; };        fn(1);', () => expectedType('Num'));
    test(r'let fn = \x { print 1; return [x]; };      fn(1);', () => expectedType('List[Num]'));
    test(r'let fn = \x { print 1; return "a"; };      fn(1);', () => expectedType('String'));
    test(r'let fn = \x { print 1; return ["a"]; };    fn(1);', () => expectedType('List[String]'));
    test(r'let fn = \x { print 1; return [x, "a"]; }; fn("1");', () => expectedType('List[String]'));

    test(r'let fn = \  { let a = 1; };                  fn();',  () => expectedType('Unit'));
    test(r'let fn = \x { let a = 1; };                  fn(1);', () => expectedType('Unit'));
    test(r'let fn = \x { let a = 1; return x; };        fn(1);', () => expectedType('Num'));
    test(r'let fn = \x { let a = 1; return [x]; };      fn(1);', () => expectedType('List[Num]'));
    test(r'let fn = \x { let a = 1; return "a"; };      fn(1);', () => expectedType('String'));
    test(r'let fn = \x { let a = 1; return ["a"]; };    fn(1);', () => expectedType('List[String]'));
    test(r'let fn = \x { let a = 1; return [x, "a"]; }; fn("1");', () => expectedType('List[String]'));


    test(r'let fn = \x { if true then { print 1;      } return "ok"; };', () => expectedType('t0 -> String'));
    test(r'let fn = \x { if true then { return "yep"; } return "ok"; };', () => expectedType('t0 -> String'));
    test(r'let fn = \x { if true then { print 1; return "yep"; } return "ok"; };', () => expectedType('t0 -> String'));
    test(r'let fn = \x { if true then  print 1;         return "ok"; };', () => expectedType('t0 -> String'));
    test(r'let fn = \x { if true then  return "yep";    return "ok"; };', () => expectedType('t0 -> String'));
    test(r'let fn = \x { if true then  return "yep";    print 1; return "ok"; };', () => expectedType('t0 -> String'));

    test(r'let fn = \x { if true then { print 1;      } else { print 2;     } return "ok"; };', () => expectedType('t0 -> String'));
    test(r'let fn = \x { if true then { print 1;      } else { print "2";   } return "ok"; };', () => expectedType('t0 -> String'));
    test(r'let fn = \x { if true then { return "yep"; } else { return "ok"; }              };', () => expectedType('t0 -> String'));
    test(r'let fn = \x { if true then { print 1; return "yep"; } else { return "ok"; }     };', () => expectedType('t0 -> String'));
    test(r'let fn = \x { if true then { print 1; return "yep"; } else { print 1; return "ok"; }     };', () => expectedType('t0 -> String'));
    test(r'let fn = \x { if true then { return "yep"; } else { print 1; return "ok"; }     };', () => expectedType('t0 -> String'));

    test(r'let fn = \x { if true then  print 1;       else  print 2;      return "ok"; };', () => expectedType('t0 -> String'));
    test(r'let fn = \x { if true then  print 1;       else  print "2";    return "ok"; };', () => expectedType('t0 -> String'));
    test(r'let fn = \x { if true then  return "yep";  else  return "ok";               };', () => expectedType('t0 -> String'));


    test(r'let fn = \x { if true then { print 1;      } return "ok"; }; fn(1);', () => expectedType('String'));
    test(r'let fn = \x { if true then { return "yep"; } return "ok"; }; fn(1);', () => expectedType('String'));
    test(r'let fn = \x { if true then { print 1;      } else { print 2;     } return "ok"; }; fn(1);', () => expectedType('String'));
    test(r'let fn = \x { if true then { print 1;      } else { print "2";   } return "ok"; }; fn(1);', () => expectedType('String'));
    test(r'let fn = \x { if true then { return "yep"; } else { return "ok"; }              }; fn(1);', () => expectedType('String'));

    test(r'let fn = \x { if true then print 1;       return "ok"; }; fn(1);', () => expectedType('String'));
    test(r'let fn = \x { if true then return "yep";  return "ok"; }; fn(1);', () => expectedType('String'));
    test(r'let fn = \x { if true then print 1;       else  print 2;      return "ok"; }; fn(1);', () => expectedType('String'));
    test(r'let fn = \x { if true then print 1;       else  print "2";    return "ok"; }; fn(1);', () => expectedType('String'));
    test(r'let fn = \x { if true then return "yep";  else  return "ok";               }; fn(1);', () => expectedType('String'));


    test(r'''
    let fn = \x {
      if x then {
        print "here1";
        return true;
      }
      print "here2";
      return false;
    };
    
    let r1 = fn(true);
    let r2 = fn(false);
    print r1;
    print r2;
    ''', () => expectedType('Bool'));

    test(r'''
    let fn = \x {
      if x then {
        print "here1";
      }
      print "here2";
      return false;
    };
    
    let r1 = fn(true);
    let r2 = fn(false);
    print r1;
    print r2;
    ''', () => expectedType('Bool'));

    test(r'''
    let fn = \x {
      {
        print "here1";
      }
      print "here2";
      return false;
    };
    
    let r1 = fn(true);
    let r2 = fn(false);
    print r1;
    print r2;
    ''', () => expectedType('Bool'));

    test('use return', () {
      final source  = r'''
      let id = \x { return x; };
      id(1) + 1;
      ''';
      expect(_inferSource(source), 'Num');
    });

  });

  group('variants', () {
    test('construct', () {
      expect(_inferSource(r'let x = .Green;'), '.Green');
      expect(_inferSource(r'let x = .Green(1);'), '.Green(Num)');
      expect(_inferSource(r'''
      let x = .Green;
      let y = .Red;
      let z = true ? x : y;
      '''), '.Green | .Red');
      expect(_inferSource(r'''
      \x {
        if x == .Green then return 1;
        if x == .Red then return 2;
        return 3;
      };
      '''), '.Green | .Red -> Num');
    });

    test('match', () {
      expect(_inferSource(r'''
      \z -> match z {
         .Green -> 1,
         .Red -> 2,
      };
      '''), '.Green | .Red -> Num');
      expect(_inferSource(r'''
      \z -> match z {
         .Green g -> 1 + g,
         .Red r -> 2 + r,
      };
      '''), '.Green(Num) | .Red(Num) -> Num');
      expect(_inferSource(r'''
      \z -> match z {
         .Green g -> 1 + g,
         .Red _ -> 2,
      };
      '''), '.Green(Num) | .Red(t0) -> Num');
      expect(_inferSource(r'''
      let fn = \z -> match z {
         .Green -> 1,
         .Red -> 2,
      };
      fn(.Green);
      '''), 'Num');
      expect(_inferSource(r'''
      let fn = \z -> match z {
         .Green g -> 1 + g,
         .Red r -> 2 + r,
      };
      fn(.Green(1));
      '''), 'Num');
      expect(_inferSource(r'''
      let fn = \z -> match z {
         .Green g -> 1 + g,
         .Red r -> 2 + r,
      };
      fn(.Yellow(1));
      '''), isTypeError);
      expect(_inferSource(r'''
      \z -> match z {
         .Green -> 1,
         .Red -> false,
      };
      '''), isTypeError);
    });

    test('match returning payload', () {
      expect(_inferSource(r'''match .A(1) { .A a -> a };'''), ('Num'));
      expect(_inferSource(r'''match .A([]) { .A a -> a };'''), ('List[t0]'));
      expect(_inferSource(r'''\x -> match .A(x) { .A a -> a };'''), ('t0 -> t0'));
      expect(_inferSource(r'''match true ? .A(1) : .B(2) { .A a -> a, .B b -> b };'''), 'Num');
      expect(_inferSource(r'''match true ? .A(1) : .B(2) { .A a -> a, .B b -> "no" };'''), isTypeError);
      expect(_inferSource(r'''match true ? .A(1) : .B("no") { .A a -> a, .B b -> b };'''), isTypeError);
    });

    test('match returning tags', () {
      expect(_inferSource(r'''
      \z -> match z {
         .InGreen -> .OutGreen,
         .InRed -> .OutRed,
      };
      '''), '.InGreen | .InRed -> .OutGreen | .OutRed');
    });

    test('open vs closed', () {
      expect(_inferSource(r'''
      let fn = \z -> match z {
         .InGreen -> .OutGreen,
         .InRed -> .OutRed,
      };
      match fn(.InGreen) {
        .OutGreen -> 1,
        .OutRed -> 2,
      };
      '''), 'Num');
      expect(_inferSource(r'''
      let fn = \z -> match z {
         .InGreen -> .OutGreen,
         .InRed -> .OutRed,
      };
      match fn(.InGreen) {
        .OutGreen -> 1,
        .OutRed -> 2,
        .SomeExtraTag -> 3,
      };
      '''), 'Num');
      expect(_inferSource(r'''
      let fn = \z -> match z {
         .InGreen -> .OutGreen,
         .InRed -> .OutRed,
      };
      match fn(.InGreen) {
        .OutGreen -> 1
      };
      '''), isTypeError);
    });

    group('default case', () {
      test('case1', () {
        expect(_inferSource(r'''
        let f = \v -> match v {
           .A -> .Ok(1),
           .B -> .Ok(2),
           other -> .Other(other),
        };
        '''), '.A | .B -> .Ok(Num) | .Other(t0)');
      });
      test('case2', () {
        expect(_inferSource(r'''
        let f = \v -> match v {
           .A -> .Ok(1),
           .B -> .Ok(2),
           other -> .Other(other),
        };
        let input = [.A, .B, .C, .D] \> List.first;
        let result = f(input);
        '''), '.Ok(Num) | .Other(.C | .D)');
      });
      test('case3', () {
        expect(_inferSource(r'''
        let f = \v -> match v {
           .A -> .Ok(1),
           .B -> .Ok(2),
           other -> .Other(other),
        };
        let input = [.A, .B, .C, .D] \> List.first;
        match f(input) {
          .Ok x -> "a or b",
          .Other o -> match o {
            .C -> "c",
            .D -> "d",
          },
        };
        '''), 'String');
      });
      test('case4', () {
        expect(_inferSource(r'''
        let f = \v -> match v {
           .A -> .Ok(1),
           .B -> .Ok(2),
           other -> .Other(other),
        };
        let input = [.A, .B, .C, .D] \> List.first;
        match f(input) {
          .Ok x -> "a or b",
          .Other o -> match o {
            .C -> "c",
       //     .D -> "d",
          },
        };
        '''), isTypeError);
      });
      test('case5', () {
        expect(_inferSource(r'''
        let f1 = \v -> match v {
           .A -> .Ok(1),
           .B -> .Ok(2),
           other -> .Other(other),
        };
        let f2 = \v -> match v {
           .C -> .Ok(3),
           .D -> .Ok(4),
        };
        let input = [.A, .B, .C, .D] \> List.first;
        match f1(input) {
          .Ok x -> .Ok(x),
          .Other o -> f2(o),
        };
        '''), '.Ok(Num)');
      });
      test('case6', () {
        expect(_inferSource(r'''
        let f1 = \v -> match v {
           .A -> .Ok(1),
           .B -> .Ok(2),
           other -> .Other(other),
        };
        let f2 = \v -> match v {
           .C -> .Ok(3),
      //     .D -> .Ok(4),
        };
        let input = [.A, .B, .C, .D] \> List.first;
        match f1(input) {
          .Ok x -> .Ok(x),
          .Other o -> f2(o),
        };
        '''), isTypeError);
      });
    });
  });

  test('imports', () {
    expect(
      _inferSource(
        'let foo = import "foo.lox";',
        {'foo.lox': 'let x = 1;'}
      ),
      '{x: Num}',
    );
    expect(
      _inferSource(
        'let y = (import "foo.lox").x;',
        {'foo.lox': 'let x = 1;'}
      ),
      'Num',
    );

    expect(
      _inferSource(
        r'''
        let module = import "some_module.lox";
        print module.x(1);
        ''',
        {'some_module.lox': r'let x = \a -> [a];'}
      ),
      'List[Num]',
    );
    expect(
      _inferSource(r'''
        let module = import "some_module.lox";
        print module.x;
        ''',
        {'some_module.lox': r' let a = 1; let x = a;'}
      ),
      'Num',
    );
  });

  test('destructuring', () {
    expect(
      _markTypes(r'''
      let fn1 = \data { let {x, y} = data; };
      let fn2 = \data { let {x, y} = data; };
      ''').map((x) => x.display),
      [
        'fn1: {y: a, x: b} -> Unit',
        '{y: a, x: b} -> Unit',
        '{y: a, x: b} -> Unit',
        'data: {y: a, x: b}',
        'x: b',
        'y: a',
        'data: {y: a, x: b}',
        'fn2: {y: a, x: b} -> Unit',
        '{y: a, x: b} -> Unit',
        '{y: a, x: b} -> Unit',
        'data: {y: a, x: b}',
        'x: b',
        'y: a',
        'data: {y: a, x: b}'
      ],
    );
    expect(
      _inferSource('let {a} = {a: 1}; a;'),
      'Num',
    );
    expect(
      _inferSource('let {a: b} = {a: 1}; b;'),
      'Num',
    );
    expect(
      _inferSource('let {a: x} = {a: {b: 1}}; x;'),
      '{b: Num}',
    );
    expect(
      _inferSource('let {a: {b}} = {a: {b: 1}}; b;'),
      'Num',
    );
    expect(
      _inferSource('let {a: {b: x}} = {a: {b: 1}}; x;'),
      'Num',
    );
    expect(
      _inferSource(
        '''
        let {x, y} = import "foo.lox"; 
        x + y;
        ''',
        {'foo.lox': 'let x = 1; let y = 2;'}
      ),
      'Num',
    );
  });

  test('return expression', () {

    expect(
      _inferSource(r'''
let unlucky = \ -> true;
let online = \ -> true;
let is_auth_expired = \ -> true;

let connect = \ {
    if unlucky() then return .BadLuck;
    if !online() then return .Offline;
    return .Connection({
        some_connection_details: 123,
        download: \ -> {this_is_wrong: "yep"},
    });
}
;

let download = \connection {
    if is_auth_expired() then return .AuthExpired;
    if unlucky() then return .DownloadInterrupted;
    let result = connection.download();
    return .TheData(result);
};

let connect_and_connect = \ {
    let connection = match connect() {
        .Connection c -> c,
        .Offline -> return .TheData("some default data"),
        other -> return other,
    };

    return download(connection);
};
      '''),
      isTypeMismatch(
        lhs: 'String',
        rhs: '{this_is_wrong: String}'
      ),
    );

    expect(
      _inferSource(r'''
        let f = \x {
          let remaining = match x {
            .Green -> return false,
            .Red -> 2,
          };
          let ok = remaining + 0 == 2;
          return ok;
        };
      '''),
      '.Green | .Red -> Bool',
    );

    expect(
      _inferSource(r'''
        let get = \ -> List.first([
          .Ok(1),
          .OOM,
          .BadLuck({attempts_left: 3}),
        ]);
        let f = \x {
          let value = match x {
            .Ok value -> value,
            err -> return err,
          };
          
          return .Ok(value + 0 == 2);
        };
        
        let data = get();
        let result = f(data);
      '''),
      '.BadLuck({attempts_left: Num}) | .OOM | .Ok(Bool)',
    );

    expect(
      _inferSource(r'''
        let f = \x {
          let a = x 
            ? return {early: "yes"} 
            : "hi";
          return {early: List.first([a, "wat"])};  
        };
      '''),
      'Bool -> {early: String}',
    );

    expect(
      _inferSource(r'''
        let f = \x {
          let f_ = \y {
            let a = y ? return [1] : 2;
            return [a];
          };
          let result = f_(x > 1);
          return {lets_see: result};
        };
      '''),
      'Num -> {lets_see: List[Num]}',
    );

  });

  test('parameter patterns', () {

    if (inferSource(r'''
      \data {
        let i = data.some_int + 1;
        let b = data.some_bool or false;
      };
    ''') case [
      ExpressionStatement(
        expr: Lambda(
          params: [Identifier dataParam],
          body: FunctionBody(body: Block(statements: [
            LetDeclaration(initializer: Binary(left: RecordGet(:final record))),
            ...
          ])),
        ),
      ),
    ]) {
      expect(
        dataParam.type.toString(),
        record.type.toString(),
      );
    } else {
      fail('bug in test');
    }
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
      _inferSource(source),
      expectedType,
      reason: line == null ? null : 'test case: $line',
    );
  });
}


final isTypeError = isA<TypeCheckException>();

dynamic _inferSource(String source, [Map<String, String> files = const {}]) {
  try {
    if (!source.contains(';')) source = '$source;';
    final statements = inferSource(source, (path) => files[path]!);
    return statements.typeOfLastStatement.toString();
  } on (Expr, TypeCheckException) catch (e) {
    return e.$2;
  } catch (e, s) {
    print(s);
    return e;
  }
}

dynamic _markTypes(String source, [Map<String, String> files = const {}]) {
  try {
    if (!source.contains(';')) source = '$source;';
    final (marks, :errorOutput) = markTypes('', Source.memory(source), (path) => files[path]!);
    if (errorOutput.isNotEmpty) throw errorOutput;
    return marks;
  } on (Expr, TypeCheckException) catch (e) {
    return e.$2;
  } catch (e, s) {
    print(s);
    return e;
  }
}

extension on List<Statement> {
  LoxType? get typeOfLastStatement => switch (lastOrNull) {
    null => null,
    ExpressionStatement(:final expr)
    || PrintStatement(:final expr)
    || AssertStatement(:final expr)
      => expr.type,

    LetDeclaration(:final initializer)
      => initializer.type,

    Block(:final statements)
      => statements.typeOfLastStatement,

    IfStatement()
      => fail('doesnt make sense'),
  };
}

void expectedType(String expected) {
  final liveTest = Invoker.current!.liveTest;
  final source = liveTest.test.name.toString().replaceAll(liveTest.groups.last.name, '');
  expect(_inferSource(source).toString(), expected);
}

const _sentinel = Object();
Matcher isTypeMismatch({
  Object lhs = _sentinel,
  Object rhs = _sentinel,
}) =>
    isA<TypeMismatch>()
        .having((e) => e.t1.toString(), 'lhs', lhs)
        .having((e) => e.t2.toString(), 'rhs', rhs);
