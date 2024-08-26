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
  final String name;
  Var(this.name);

  @override
  String toString() => name;
}

class App extends LambdaCalculusExpression {
  final LambdaCalculusExpression func;
  final LambdaCalculusExpression arg;

  App({required this.func, required this.arg});

  @override
  String toString() => '($func $arg)';
}


class Abs extends LambdaCalculusExpression {
  final String param;
  final LambdaCalculusExpression body;
  Abs(this.param, this.body);

  @override
  String toString() => 'λ$param -> $body';
}

class Let extends LambdaCalculusExpression {
  final String name;
  final LambdaCalculusExpression assignment;
  final LambdaCalculusExpression body;
  Let(this.name, this.assignment, this.body);

  @override
  String toString() => 'let $name = $assignment in $body';
}

const bool_t = TypeFunctionApplication('Bool', []);
const num_t = TypeFunctionApplication('Num', []);
const string_t = TypeFunctionApplication('String', []);
const unit_t = TypeFunctionApplication('Unit', []);
final list_t = (MonoType of) => TypeFunctionApplication('List', [of]);
final function_t = (MonoType from, MonoType to) => TypeFunctionApplication('Function', [from, to]);
final var_t = TypeVariable.new;
final forall = TypeQuantifier.new;
final unary_bool_t = function_t(bool_t, bool_t);
final binary_num_t = function_t(num_t, function_t(num_t, num_t));
final binary_bool_t = function_t(bool_t, function_t(bool_t, bool_t));
final ternary_t = forall('a', function_t(bool_t, function_t(var_t('a'), function_t(var_t('a'), var_t('a')))));
final emptyList_t = forall('a', list_t(var_t('a')));

(Substitution, MonoType) w(LambdaCalculusExpression expr, Context context) {
  switch (expr) {
    case Lit(): return ({}, instantiate(expr.type));
    case Var(:final name):
      final type = context[name];
      if (type == null) throw Exception('Undefined variable $name');
      return ({}, instantiate(type));
    case Abs(:final param, :final body):
      final beta = TypeVariable.fresh();
      final (s1, t1) = w(body, {...context, param: beta});
      return (s1, s1.apply(function_t(beta, t1)));
    case App(:final func, :final arg):
      final (s1, t1) = w(func, context);
      final (s2, t2) = w(arg, s1.applyContext(context));
      final beta = TypeVariable.fresh();
      final s3 = unify(s2.apply(t1), function_t(t2, beta));
      return (combine([s1, s2, s3]), s3.apply(beta));
    case Let(:final name, :final assignment, :final body):
      final (s1, t1) = w(assignment, context);
      final (s2, t2) = w(body, {...s1.applyContext(context), name: generalize(context, t1)});
      return (combine([s1, s2]), t2);
  }
}
