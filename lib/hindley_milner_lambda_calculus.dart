import 'package:lox/hindley_milner_api.dart';
import 'package:lox/utils.dart';

sealed class LambdaCalculusExpression {}

class Lit extends LambdaCalculusExpression {
  final Ty type;
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
class VariantConstructor extends LambdaCalculusExpression {
  final String tag;
  final LambdaCalculusExpression? payload;
  VariantConstructor(this.tag, this.payload);

  @override String toString() => prettyPrint(this);
}
class VariantMatch extends LambdaCalculusExpression {
  final LambdaCalculusExpression variant;
  final List<({String tag, String? payload, LambdaCalculusExpression result})> cases;
  VariantMatch(this.variant, this.cases);

  @override String toString() => prettyPrint(this);
}

final function = ({required Ty from, required Ty to}) => TyFunctionApplication('Function', [from, to]);
final unit = TyFunctionApplication('Unit', []);

typedef AlgorithmWResult = ({
  Ty overallType,
  Map<LambdaCalculusExpression, Ty> subExpressionTypes,
});

AlgorithmWResult algorithmW(LambdaCalculusExpression expr, Context context) {
  final overallType = generalize(-1, _infer(0, expr, context));
  final subExpressions = _log.mapValues(generalize.partial(-1));
  _log.clear();
  return (
    overallType: overallType,
    subExpressionTypes: subExpressions,
  );
}

final _log = <LambdaCalculusExpression, Ty>{};
Ty _output(LambdaCalculusExpression expr, Ty type) {
  _log[expr] = type;
  return type;
}

Ty _infer(int level, LambdaCalculusExpression expr, Context context) {
  switch (expr) {
    case Lit(:final type):
      return _output(expr, instantiate(level, type));
    case Var(:final name):
      final type = context[name];
      if (type == null) throw Exception('Undefined variable $name');
      return _output(expr, instantiate(level, type));
    case Abs(:final param, :final body):
      final paramType = TyVariable.fresh(level);
      final bodyReturnType = _infer(level, body, {...context, param: paramType});
      final funcType = function(from: paramType, to: bodyReturnType);
      return _output(expr, funcType);
    case App(:final func, :final arg):
      final funcType = _infer(level, func, context);
      final argType = _infer(level, arg, context);
      final evaluatesToType = TyVariable.fresh(level);
      unify(
        funcType,
        function(from: argType, to: evaluatesToType),
      );
      return _output(expr, evaluatesToType);
    case Let(:final name, :final assignment, :final body):
      final maybeRecursive = TyVariable.fresh(level+1);
      final assignmentType = _infer(level+1, assignment, {
        ...context,
        // [assignment] might reference [name], so add it to the context with a fresh type variable and let it get resolved normally
        name: maybeRecursive,
      });

      // tie together the self reference (if any)
      unify(maybeRecursive, assignmentType);

      final generalizedAssignmentType = generalize(level, assignmentType);
      final bodyType = _infer(level, body, {
        ...context,
        name: generalizedAssignmentType,
      });
      return _output(expr, bodyType);
    case RecordEmpty():
      return _output(expr, TyRowEmpty());
    case RecordSelection(:final label, :final record):
      final restRowType = TyVariable.fresh(level);
      final fieldType = TyVariable.fresh(level);
      final paramType = TyRowExtend(
        newEntry: (label, fieldType),
        row: restRowType,
      );
      final returnType = fieldType;
      unify(
        paramType,
        _infer(level, record, context),
      );
      return _output(expr, returnType);

    case RecordExtension(:final label, :final newField, :final record):
      final restRowType = TyVariable.fresh(level);
      final param1Type = TyVariable.fresh(level);
      final returnType = TyRowExtend(
        newEntry: (label, param1Type),
        row: restRowType,
      );

      unify(
        param1Type,
        _infer(level, newField, context),
      );

      unify(
        restRowType,
        _infer(level, record, context),
      );

      return _output(expr, returnType);
    case VariantConstructor(:final tag, :final payload):
      final /*inferred as `Object`, expected it to be `Ty`*/ expectedPayloadType = payload == null
          ? unit
          : TyVariable.fresh(level);
      final restRowType = TyVariable.fresh(level);
      final expectedVariantType = TyVariant(TyRowExtend(
        newEntry: (tag, expectedPayloadType),
        row: restRowType,
      ));

      if (payload != null) {
        unify(
          expectedPayloadType,
          _infer(level, payload, context),
        );
      }
      return _output(expr, expectedVariantType);
    case VariantMatch(variant: final matchTarget, :final cases):
      final expectedReturnType = TyVariable.fresh(level);
      Ty casesRow = TyRowEmpty();
      for (final (:tag, :payload, :result) in cases) {
        final Ty payloadType;
        final Context env;
        if (payload == null) {
          payloadType = unit;
          env = context;
        } else {
          payloadType = TyVariable.fresh(level);
          env = {
            ...context,
            payload: payloadType,
          };
        }
        unify(expectedReturnType, _infer(level, result, env));
        casesRow = TyRowExtend(
          newEntry: (tag, payloadType),
          row: casesRow,
        );
      }
      final variantType = _infer(level, matchTarget, context);
      unify(variantType, TyVariant(casesRow));
      return _output(expr, expectedReturnType);
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

  VariantConstructor(:final tag, :final payload) =>
      '.$tag $payload',

  VariantMatch(
    :final variant,
    :final cases,
  ) =>
    'match ${prettyPrint(variant)} { ${[
      for (final (:tag, :payload, :result) in cases)
        payload == null
            ? '.$tag => ${prettyPrint(result)}'
            : '.$tag $payload => ${prettyPrint(result)}'
      ].sorted().join(', ')
    } }',
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