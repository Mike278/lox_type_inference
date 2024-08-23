import 'package:lox/src/hindley_milner_api.dart';

// ignore_for_file: non_constant_identifier_names
// ignore_for_file: constant_identifier_names


sealed class Expression {}

class VariableExpression extends Expression {
  final String x;
  VariableExpression(this.x);

  @override
  String toString() => x;
}

class ApplicationExpression extends Expression {
  final Expression e1;
  final Expression e2;
  ApplicationExpression(this.e1, this.e2);

  @override
  String toString() => '$e1 $e2';
}

class AbstractionExpression extends Expression {
  final String x;
  final Expression e;
  AbstractionExpression(this.x, this.e);

  @override
  String toString() => '\\$x -> $e';
}

class LetExpression extends Expression {
  final String x;
  final Expression e1;
  final Expression e2;
  LetExpression(this.x, this.e1, this.e2);

  @override
  String toString() => 'let $x = $e1 in $e2';
}

const kFunction = '->';
const kBool = 'Bool';
const kNum = 'Num';
const kString = 'String';
const kList = 'List';

const bool_t = TypeFunctionApplication(kBool, []);
const num_t = TypeFunctionApplication(kNum, []);
const string_t = TypeFunctionApplication(kString, []);
final function_t = (MonoType from, MonoType to) => TypeFunctionApplication(kFunction, [from, to]);
final list_t = (MonoType of) => TypeFunctionApplication(kList, [of]);

(Substitution, MonoType) w(Expression expr, Context context) {
  switch (expr) {
    case VariableExpression(:final x):
      final type = context[x];
      if (type == null) throw Exception('Undefined variable $x');
      return ({}, instantiate(type));
    case AbstractionExpression(:final x, :final e):
      final beta = TypeVariable.fresh();
      final (s1, t1) = w(e, {...context, x: beta});
      return (s1, s1.apply(function_t(beta, t1)));
    case ApplicationExpression(:final e1, :final e2):
      final (s1, t1) = w(e1, context);
      final (s2, t2) = w(e2, s1.applyContext(context));
      final beta = TypeVariable.fresh();
      final s3 = unify(s2.apply(t1), function_t(t2, beta));
      return (combine([s1, s2, s3]), s3.apply(beta));
    case LetExpression(:final x, :final e1, :final e2):
      final (s1, t1) = w(e1, context);
      final (s2, t2) = w(e2, {...s1.applyContext(context), x: generalize(context, t1)});
      return (combine([s1, s2]), t2);
  }
}