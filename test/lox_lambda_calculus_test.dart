import 'package:lox/hindley_milner_lambda_calculus.dart';
import 'package:lox/lox_lambda_calculus.dart';
import 'package:lox/utils.dart';
import 'package:test/test.dart';

import 'test_utils.dart';

void main() {
  final tests = [
    // arity 0
    (lox: r'\  -> 1',  lc: 'λ_ -> <Num>'),

    // arity 1
    (lox: r'\x -> 1', lc: 'λx -> <Num>'),
    (lox: r'\x -> x', lc: 'λx -> x'),

    // arity 2
    (lox: r'\x, y -> 1'               , lc: 'λx -> λy -> <Num>'),
    (lox: r'\x, y -> x'               , lc: 'λx -> λy -> x'),
    (lox: r'\x, y -> y'               , lc: 'λx -> λy -> y'),
    (lox: r'\x, y -> []'              , lc: 'λx -> λy -> <(∀a. List[a])>'),
    (lox: r'\x, y -> x(y and false)'  , lc: 'λx -> λy -> (x ((and y) <Bool>))'),
    (lox: r'\x, y -> x(y)'            , lc: 'λx -> λy -> (x y)'),

    // arity 3
    (lox: r'\x, y, z -> 1'                    , lc: 'λx -> λy -> λz -> <Num>'),
    (lox: r'\x, y, z -> x'                    , lc: 'λx -> λy -> λz -> x'),
    (lox: r'\x, y, z -> y'                    , lc: 'λx -> λy -> λz -> y'),
    (lox: r'\x, y, z -> z'                    , lc: 'λx -> λy -> λz -> z'),
    (lox: r'\x, y, z -> x or y'               , lc: 'λx -> λy -> λz -> ((or x) y)'),
    (lox: r'\x, y, z -> z(x or y)'            , lc: 'λx -> λy -> λz -> (z ((or x) y))'),
    (lox: r'\x, y, z -> z(x or y, x)'         , lc: 'λx -> λy -> λz -> ((z ((or x) y)) x)'),

    // unary function body
    (lox: r'\x -> -x'                         , lc: 'λx -> ((- <Num>) x)'),
    (lox: r'\x -> !x'                         , lc: 'λx -> (! x)'),
    (lox: r'\x, y -> -x'                      , lc: 'λx -> λy -> ((- <Num>) x)'),
    (lox: r'\x, y -> !x'                      , lc: 'λx -> λy -> (! x)'),
    // binary function body
    (lox: r'\x, y -> x and y'                 , lc: 'λx -> λy -> ((and x) y)'),
    (lox: r'\x, y -> x or y'                  , lc: 'λx -> λy -> ((or x) y)'),
    (lox: r'\x, y -> x + y'                   , lc: 'λx -> λy -> ((+ x) y)'),
    (lox: r'\x, y -> x - y'                   , lc: 'λx -> λy -> ((- x) y)'),
    (lox: r'\x, y -> x * y'                   , lc: 'λx -> λy -> ((* x) y)'),
    (lox: r'\x, y -> x / y'                   , lc: 'λx -> λy -> ((/ x) y)'),
    (lox: r'\x, y -> x - -y'                  , lc: 'λx -> λy -> ((- x) ((- <Num>) y))'),

    // ternary function body
    (lox: r'\c, x, y -> c ? x : y'            , lc: 'λc -> λx -> λy -> (((? c) x) y)'),
    (lox: r'\c, x, y -> c ? x : y+1'          , lc: 'λc -> λx -> λy -> (((? c) x) ((+ y) <Num>))'),
    (lox: r'\c, x, y -> c ? x : -y'           , lc: 'λc -> λx -> λy -> (((? c) x) ((- <Num>) y))'),
    (lox: r'\c, x, y -> c ? x : y or false'   , lc: 'λc -> λx -> λy -> (((? c) x) ((or y) <Bool>))'),
    (lox: r'\c, x, y -> c ? x : !y'           , lc: 'λc -> λx -> λy -> (((? c) x) (! y))'),

    // complex
    (
      lox: r'\x, y, z -> x(y and false, z + 1)',
      lc: 'λx -> λy -> λz -> ((x ((and y) <Bool>)) ((+ z) <Num>))',
    ),
  ];
  for (final (:lox, :lc) in tests) {
    test('toLambdaCalculus function $lox', () {
      final actualLc = toLC(lox);
      expect(actualLc.toString(), lc, reason: lox);
    });
  }

  for (final (source, expectedType) in {

    // arity 0
    r'(\  -> 1)()': '(λ_ -> <Num> <Unit>)',

    // arity 1
    r'(\x -> x)(1)'  : '(λx -> x <Num>)',
    r'(\x -> x)(-1)' : '(λx -> x ((- <Num>) <Num>))',
    r'(\x -> 1)([])' : '(λx -> <Num> <(∀a. List[a])>)',
    r'(\x -> x)([])' : '(λx -> x <(∀a. List[a])>)',
    r'(\x -> [])(1)' : '(λx -> <(∀a. List[a])> <Num>)',

    // arity 2
    r'(\x, y -> 1)("ok", false)': '((λx -> λy -> <Num> <String>) <Bool>)',
    r'(\x, y -> x)("ok", false)': '((λx -> λy -> x <String>) <Bool>)',
    r'(\x, y -> y)("ok", false)': '((λx -> λy -> y <String>) <Bool>)',

    // complex
    r'(\x, y -> x(y and false)) (\b -> 1, false)': () {
        final func = 'λx -> λy -> (x ((and y) <Bool>))';
        final arg1 = 'λb -> <Num>';
        final arg2 = '<Bool>';
        return '(($func $arg1) $arg2)';
    } (),
    r'(\x, y -> x(y and false)) (\b -> b, false)': () {
        final func = 'λx -> λy -> (x ((and y) <Bool>))';
        final arg1 = 'λb -> b';
        final arg2 = '<Bool>';
        return '(($func $arg1) $arg2)';
    } (),
    r'(\x, y, z -> x(y and false, z + 1)) (\a, b -> b, true, 1)': () {
        final func = 'λx -> λy -> λz -> ((x ((and y) <Bool>)) ((+ z) <Num>))';
        final arg1 = 'λa -> λb -> b';
        final arg2 = '<Bool>';
        final arg3 = '<Num>';
        return '((($func $arg1) $arg2) $arg3)';
    } (),


    r'(\x -> x("h")     ) (\b    -> 1)': '(λx -> (x <String>) λb -> <Num>)',
    r'(\x -> "h")         (\b, c -> 1)': '(λx -> <String> λb -> λc -> <Num>)',
    r'(\x -> x("h", "h")) (\b, c -> 1)': '(λx -> ((x <String>) <String>) λb -> λc -> <Num>)',

  }.pairs()) {
    test('toLambdaCalculus call $source', () {
      expect(toLC(source).toString(),  expectedType, reason: source);
    });
  }

  test('transform polymorphic statements', () {
    final source = r'''
      let id = \x -> x;
      let a = id(1);
      let b = id("b");
    ''';
    final program = parse(source);
    final lambdaCalculus = transformStatements(program);
    final type = infer(lambdaCalculus);
    expect(type.toString(), r'String');
  });

  test('transform recursive functions', () {
    final source = r'let factorial = \n -> n > 0 ? n * factorial(n - 1) : 1;';
    final program = parse(source);
    final lambdaCalculus = transformStatements(program);
    final type = infer(lambdaCalculus);
    expect(type.toString(), r'Num -> Num');
  });

  test('transform recursive function calls', () {
    final source = r'let factorial = \n -> n > 0 ? n * factorial(n - 1) : 1; factorial(2);';
    final program = parse(source);
    final lambdaCalculus = transformStatements(program);
    final type = infer(lambdaCalculus);
    expect(type.toString(), r'Num');
  });

  test('if then block', () {
    final source = r'''
    let fn = \x { 
      if true then {
        print 1;
      } 
      return "ok"; 
    };
    ''';
    final program = parse(source);
    final lambdaCalculus = transformStatements(program);
    final type = infer(lambdaCalculus);
    expect(type.toString(), r't0 -> String');
  });

  test('if then', () {
    final source = r'''
    let fn = \x { 
      if true then print 1;
      return "ok"; 
    };
    ''';
    final program = parse(source);
    final lambdaCalculus = transformStatements(program);
    final type = infer(lambdaCalculus);
    expect(type.toString(), r't0 -> String');
  });

  test('if then else', () {
    final source = r'''
    let fn = \x { 
      if true then {
        return "ok"; 
      } else {
        return "ko"; 
      } 
    };
    ''';
    final program = parse(source);
    final lambdaCalculus = transformStatements(program);
    final type = infer(lambdaCalculus);
    expect(type.toString(), r't0 -> String');
  });

  test('nested functions', () {
    final source = r'''
    let fn = \x { 
      let inner = \y {
        print x;
        print y;
        return x + y;
      }; 
      let sum = inner(5);
      print "sum: "; 
      print sum;
      return sum;
    };
    ''';
    final program = parse(source);
    final lambdaCalculus = transformStatements(program);
    final type = infer(lambdaCalculus);
    expect(type.toString(), r'Num -> Num');
    {
      final program = parse('$source let result = fn(6);');
      final lambdaCalculus = transformStatements(program);
      final type = infer(lambdaCalculus);
      expect(type.toString(), r'Num');
    }
  });
}

LambdaCalculusExpression toLC(String source) {
  final expr = parseExpression(source);
  return toLambdaCalculus(expr);
}
