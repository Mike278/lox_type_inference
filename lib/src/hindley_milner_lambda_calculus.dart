import 'package:lox/src/hindley_milner_api.dart';

// ignore_for_file: non_constant_identifier_names
// ignore_for_file: constant_identifier_names


sealed class LambdaCalculusExpression {}

class Lit extends LambdaCalculusExpression {
  final PolyType type;
  Lit(this.type);
  @override
  String toString() => '<$type>';
}

class Var extends LambdaCalculusExpression {
  final String x;
  Var(this.x);

  @override
  String toString() => x;
}

class App extends LambdaCalculusExpression {
  final LambdaCalculusExpression func;
  final LambdaCalculusExpression arg;

  App({required this.func, required this.arg});

  @override
  String toString() => '($func $arg)';
}


class Abs extends LambdaCalculusExpression {
  final String x;
  final LambdaCalculusExpression e;
  Abs(this.x, this.e);

  @override
  String toString() => 'λ$x -> $e';
}

class Let extends LambdaCalculusExpression {
  final String x;
  final LambdaCalculusExpression e1;
  final LambdaCalculusExpression e2;
  Let(this.x, this.e1, this.e2);

  @override
  String toString() => 'let $x = $e1 in $e2';
}

const kFunction = 'Function';
const kBool = 'Bool';
const kNum = 'Num';
const kString = 'String';
const kList = 'List';
const kUnit = 'Unit';

const bool_t = TypeFunctionApplication(kBool, []);
const num_t = TypeFunctionApplication(kNum, []);
const string_t = TypeFunctionApplication(kString, []);
const unit_t = TypeFunctionApplication(kUnit, []);
final function_t = (MonoType from, MonoType to) => TypeFunctionApplication(kFunction, [from, to]);
final list_t = (MonoType of) => TypeFunctionApplication(kList, [of]);
const emptyList = TypeQuantifier('a', TypeFunctionApplication(kList, [TypeVariable('a')]));

(Substitution, MonoType) w(LambdaCalculusExpression expr, Context context) {
  switch (expr) {
    case Lit(): return ({}, instantiate(expr.type));
    case Var(:final x):
      final type = context[x];
      if (type == null) throw Exception('Undefined variable $x');
      return ({}, instantiate(type));
    case Abs(:final x, :final e):
      final beta = TypeVariable.fresh();
      final (s1, t1) = w(e, {...context, x: beta});
      return (s1, s1.apply(function_t(beta, t1)));
    case App(func:final e1, arg:final e2):
      final (s1, t1) = w(e1, context);
      final (s2, t2) = w(e2, s1.applyContext(context));
      final beta = TypeVariable.fresh();
      final s3 = unify(s2.apply(t1), function_t(t2, beta));
      return (combine([s1, s2, s3]), s3.apply(beta));
    case Let(:final x, :final e1, :final e2):
      final (s1, t1) = w(e1, context);
      final (s2, t2) = w(e2, {...s1.applyContext(context), x: generalize(context, t1)});
      return (combine([s1, s2]), t2);
  }
}
