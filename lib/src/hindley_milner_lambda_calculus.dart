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
final emptyList_t = forall('a', list_t(var_t('a')));

(Substitution, MonoType) w(LambdaCalculusExpression expr, Context context) {
  switch (expr) {
    case Lit(:final type):
      return ({}, instantiate(type));
    case Var(:final name):
      final type = context[name];
      if (type == null) throw Exception('Undefined variable $name');
      return ({}, instantiate(type));
    case Abs(:final param, :final body):
      final paramType = TypeVariable.fresh();
      final (bodySubstitution, bodyReturnType) = w(body, {
        ...context,
        param: paramType,
      });
      final funcType = bodySubstitution.appliedTo(function_t(paramType, bodyReturnType));
      return (bodySubstitution, funcType);
    case App(:final func, :final arg):
      final (funcSubstitution, funcType) = w(func, context);
      final (argSubstitution, argType) = w(arg, funcSubstitution.appliedToContext(context));
      final evaluatesToType = TypeVariable.fresh();
      final unifiedSubstitution = unify(
        argSubstitution.appliedTo(funcType),
        function_t(argType, evaluatesToType),
      );
      final overallType = unifiedSubstitution.appliedTo(evaluatesToType);
      final substitutionsCombined = combine([unifiedSubstitution, argSubstitution, funcSubstitution]);
      return (substitutionsCombined, overallType);
    case Let(:final name, :final assignment, :final body):
      final (s1, t1) = w(assignment, {
        ...context,
        // [assignment] might reference [name], so add it to the context with a fresh type variable and let it get resolved normally
        name: generalize(context, TypeVariable.fresh()),
      });
      final (s2, t2) = w(body, {
        ...s1.appliedToContext(context),
        name: generalize(context, t1),
      });
      return (combine([s1, s2]), t2);
  }
}
