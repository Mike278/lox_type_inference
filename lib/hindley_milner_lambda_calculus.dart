import 'package:lox/hindley_milner_api.dart';

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

class RecordEmpty extends LambdaCalculusExpression {}
class RecordSelection extends LambdaCalculusExpression {
  final String label;
  final LambdaCalculusExpression record;
  RecordSelection(this.label, this.record);

  @override String toString() => '$record.$label';
}
class RecordExtension extends LambdaCalculusExpression {
  final String label;
  final LambdaCalculusExpression newField;
  final LambdaCalculusExpression record;

  RecordExtension(this.label, this.newField, this.record);

  @override String toString() => ' { ..$record, $label = $newField }';
}


final function = ({required MonoType from, required MonoType to}) => TypeFunctionApplication('Function', [from, to]);

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
      final funcType = bodySubstitution.appliedTo(function(from: paramType, to: bodyReturnType));
      return (bodySubstitution, funcType);
    case App(:final func, :final arg):
      final (funcSubstitution, funcType) = w(func, context);
      final (argSubstitution, argType) = w(arg, funcSubstitution.appliedToContext(context));
      final evaluatesToType = TypeVariable.fresh();
      final unifiedSubstitution = unify(
        argSubstitution.appliedTo(funcType),
        function(from: argType, to: evaluatesToType),
      );
      final overallType = unifiedSubstitution.appliedTo(evaluatesToType);
      final substitutionsCombined = combine([funcSubstitution, argSubstitution, unifiedSubstitution]);
      return (substitutionsCombined, overallType);
    case Let(:final name, :final assignment, :final body):
      final maybeRecursive = TypeVariable.fresh();
      final (assignmentSub, assignmentType) = w(assignment, {
        ...context,
        // [assignment] might reference [name], so add it to the context with a fresh type variable and let it get resolved normally
        name: maybeRecursive,
      });
      final finalAssignmentSub = combine([
        assignmentSub,
        // tie together the self reference (if any)
        unify(assignmentSub.appliedTo(maybeRecursive), assignmentType),
      ]);

      final contextWithAssignment = finalAssignmentSub.appliedToContext(context);
      final generalizedAssignmentType = generalize(contextWithAssignment, finalAssignmentSub.appliedTo(assignmentType));
      final (bodySub, bodyType) = w(body, {
        ...contextWithAssignment,
        name: generalizedAssignmentType,
      });
      final combined = combine([finalAssignmentSub, bodySub]);
      return (combined, bodyType);
    case RecordEmpty():
      return ({}, instantiate(TypeRowEmpty()));
    case RecordSelection(:final label, :final record):
      final (recordSubstitution, recordType) = w(record, context);
      final restRowType = TypeVariable.fresh();
      final fieldType = TypeVariable.fresh();
      final paramType = recordSubstitution.appliedTo(TypeRowExtend(
          newEntry: (label, fieldType),
          row: restRowType,
      ));
      final unifiedSubstitution = unify(
        paramType,
        recordType,
      );
      final allSubstitutions = combine([recordSubstitution, unifiedSubstitution]);
      final returnType = unifiedSubstitution.appliedTo(fieldType);
      return (allSubstitutions, returnType);

    case RecordExtension(:final label, :final newField, :final record):
      final (fieldSubstitution, fieldType) = w(newField, context);
      final (recordSubstitution, recordType) = w(record, fieldSubstitution.appliedToContext(context));

      final restRowType = TypeVariable.fresh();
      final param1Type = TypeVariable.fresh();
      final returnType = recordSubstitution.appliedTo(TypeRowExtend(
        newEntry: (label, param1Type),
        row: restRowType,
      ));

      final sub1 = unify(
        param1Type,
        fieldType,
      );
      final sub2 = unify(
        restRowType,
        recordType,
      );

      final substitutionsCombined = combine([
        sub2,
        sub1,
        recordSubstitution,
        fieldSubstitution,
      ]);

      final overallType = substitutionsCombined.appliedTo(returnType);
      return (substitutionsCombined, overallType);
  }
}
