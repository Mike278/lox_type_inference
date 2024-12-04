import 'package:lox/hindley_milner_api.dart';

sealed class LambdaCalculusExpression {}

class Lit extends LambdaCalculusExpression {
  final PolyType type;
  Lit(this.type);
  @override String toString() => prettyPrint(this);
}

class Var extends LambdaCalculusExpression {
  final String name;
  Var(this.name);

  @override String toString() => prettyPrint(this);
}

class App extends LambdaCalculusExpression {
  final LambdaCalculusExpression func;
  final LambdaCalculusExpression arg;

  App({required this.func, required this.arg});

  @override String toString() => prettyPrint(this);
}


class Abs extends LambdaCalculusExpression {
  final String param;
  final LambdaCalculusExpression body;
  Abs(this.param, this.body);

  @override String toString() => prettyPrint(this);
}

class Let extends LambdaCalculusExpression {
  final String name;
  final LambdaCalculusExpression assignment;
  final LambdaCalculusExpression body;
  Let(this.name, this.assignment, this.body);

  @override String toString() => prettyPrint(this);
}

class RecordEmpty extends LambdaCalculusExpression {
  @override String toString() => prettyPrint(this);
}
class RecordSelection extends LambdaCalculusExpression {
  final String label;
  final LambdaCalculusExpression record;
  RecordSelection(this.label, this.record);

  @override String toString() => prettyPrint(this);
}
class RecordExtension extends LambdaCalculusExpression {
  final String label;
  final LambdaCalculusExpression newField;
  final LambdaCalculusExpression record;

  RecordExtension(this.label, this.newField, this.record);

  @override String toString() => prettyPrint(this);
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

String prettyPrint(LambdaCalculusExpression expr) => switch (expr) {
  Lit(:final type) =>
      '<$type>',

  Var(:final name) =>
      name,

  App() =>
      prettyPrintApp(expr),

  Abs() =>
      prettyPrintAbs(expr),

  Let(:final name, :final assignment, :final body) =>
      'let $name = ${prettyPrint(assignment)} in ${prettyPrint(body)}',

  RecordEmpty() =>
      '{}',

  RecordSelection(:final record, :final label) =>
      '(${prettyPrint(record)}).$label',

  RecordExtension() =>
      prettyPrintRecord(expr),
};

String prettyPrintApp(App expr) {
  var func = expr.func;
  final args = [expr.arg];
  while (func is App) {
    args.add(func.arg);
    func = func.func;
  }

  switch (func) {
    case Var(:final name) when const {
      '+', '-', '*', '/',
      'or', 'and',
      '>', '>=', '<', '<=',
      '!=', '==',
    }.contains(name):
        final [rhs, lhs] = args;
        return '${prettyPrint(lhs)} $name ${prettyPrint(rhs)}';

    case Var(name: '?'):
      final [elseBranch, thenBranch, condition] = args;
      return '${prettyPrint(condition)} ? ${prettyPrint(thenBranch)} : ${prettyPrint(elseBranch)}';

    default:
      return '${prettyPrint(func)}(${args.reversed.map(prettyPrint).join(', ')})';
  }
}

String prettyPrintAbs(Abs expr) {
  var body = expr.body;
  final params = [expr.param];
  while (body is Abs) {
    params.add(body.param);
    body = body.body;
  }
  return '\\${params.join(', ')} -> ${prettyPrint(body)}';
}

String prettyPrintRecord(RecordExtension expr) {
  final rows = ['${expr.label} = ${prettyPrint(expr.newField)}'];
  var tail = expr.record;
  while (tail is RecordExtension) {
    rows.add('${tail.label} = ${prettyPrint(tail.newField)}');
    tail = tail.record;
  }
  final pairs = rows.reversed.join(', ');
  if (tail is RecordEmpty) {
    return '{$pairs}';
  } else {
    return '{..${prettyPrint(tail)}, $pairs}';
  }
}