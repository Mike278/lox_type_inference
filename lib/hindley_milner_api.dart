
import 'package:equatable/equatable.dart';
import 'package:lox/utils.dart';

/// One of:
///   - [TyFunctionApplication] `(String, List<Ty>)`
///     - String []
///     - List [Int]
///     - Function [Bool, Int]
///   - [TyVariable].[Unresolved] `(int id, int level)`
///     - id=t0, level=1
///     - id=t0, level=null (if quantified)
///     - id=t2, level=1
///     -  see https://okmij.org/ftp/ML/generalization.html
///   - [TyVariable].[Resolved] `(Ty)`
///     - List [String]
///     - Bool
///
///   Extend HM with records and variants, based on https://www.microsoft.com/en-us/research/publication/extensible-records-with-scoped-labels/
///   - [TyRowExtend] `((String, Ty), Ty)`
///     - {..{}, a = 1}
///     - {..r, a = 1}
///     - {..{..r, a = 1}, b = "b"}
///   - [TyRowEmpty]
///     - {}
///   - [TyVariant]
///     - <{..{}, .A(1)}>
///     - <{..{..{}, .A(1)}, .B("b")}>
sealed class Ty {}

// Based on https://okmij.org/ftp/ML/generalization.html
class TyVariable extends Ty with EquatableMixin { // ignore: must_be_immutable
  TyVariableState mutableRef;
  TyVariable(this.mutableRef);

  static int counter = 0;
  static TyVariable freshGeneric() => TyVariable(Unresolved(id: counter++, level: null));
  static TyVariable fresh(int level) => TyVariable(Unresolved(id: counter++, level: level));

  @override String toString() => prettyPrint(this);

  @override get props => [mutableRef];
}

sealed class TyVariableState with EquatableMixin {}
class Unresolved extends TyVariableState with EquatableMixin {
  final int id;
  final int? level;
  late final quantified = level == null;
  Unresolved({required this.id, required this.level});

  @override get props => [id, level];
}
class Resolved extends TyVariableState with EquatableMixin {
  final Ty type;
  Resolved(this.type);
  @override get props => [type];
}

class TyFunctionApplication extends Ty with EquatableMixin {
  final String name;
  final List<Ty> monoTypes;

  TyFunctionApplication(this.name, this.monoTypes);

  @override String toString() => prettyPrint(this);
  @override get props => [name, monoTypes];
}

class TyNever extends Ty with EquatableMixin {
  @override get props => [];
  @override String toString() => prettyPrint(this);
}

class TyRowEmpty extends Ty with EquatableMixin {
  @override get props => [];
  @override String toString() => prettyPrint(this);
}
class TyRowExtend extends Ty with EquatableMixin {
  final String label;
  final Ty type;
  final Ty row;
  TyRowExtend({required (String, Ty) newEntry, required this.row}) :
        label = newEntry.$1,
        type = newEntry.$2;
  @override get props => [label, type, row];
  @override String toString() => prettyPrint(this);
}
class TyVariant extends Ty with EquatableMixin {
  final Ty type;
  TyVariant(this.type);
  @override get props => [type];
  @override String toString() => prettyPrint(this);
}

sealed class TypeCheckException implements Exception {}
class NotARow implements TypeCheckException {
  final Ty actual;
  NotARow(this.actual);
  @override toString() => 'row type expected, got $actual';
}
class RowMissingLabel implements TypeCheckException {
  final String label;
  RowMissingLabel(this.label);
  @override toString() => 'row does not contain label $label';
}
class RecursiveRowTypes implements TypeCheckException {
  final Ty t1;
  final Ty t2;
  RecursiveRowTypes(this.t1, this.t2);
  @override toString() => 'Recursive row types:\n$t1\n$t2';
}
class TypeMismatch implements TypeCheckException {
  final Ty t1;
  final Ty t2;
  TypeMismatch(this.t1, this.t2);
  @override toString() => 'Type mismatch:\n$t1\n$t2';
}
class TypeCardinalityMismatch implements TypeCheckException {
  final TyFunctionApplication t1;
  final TyFunctionApplication t2;
  TypeCardinalityMismatch(this.t1, this.t2);
  @override toString() =>
      'Type cardinality mismatch:\n'
      '$t1 has ${t1.monoTypes.length}\n'
      '$t2 has ${t2.monoTypes.length}';
}
class UndefinedVariable implements TypeCheckException {
  final String name;
  UndefinedVariable(this.name);
  @override toString() => 'Undefined variable `$name`';
}
class TopLevelReturn implements TypeCheckException {
  @override toString() => 'Return statements must be defined inside functions, not at the top level.';
}

Ty rewriteRow(
  Ty row2,
  String label1,
  Ty fieldType1,
) {
  switch (row2) {
    case TyRowExtend(
      label: final label2,
      type: final fieldType2,
      row: final restRow2,
    ):
        if (label1 == label2) {
          unify(fieldType1, fieldType2);
          return restRow2;
        }
        final t = rewriteRow(restRow2, label1, fieldType1);
        return TyRowExtend(newEntry: (label2, fieldType2), row: t);

    case TyVariable(mutableRef: Resolved(type: final row2)):
        return rewriteRow(row2, label1, fieldType1);
    case TyVariable(mutableRef: Unresolved(:final level?)):
        final restRow2 = TyVariable.fresh(level);
        final type2 = TyRowExtend(
          newEntry: (label1, fieldType1),
          row: restRow2,
        );
        row2.mutableRef = Resolved(type2);
        return restRow2;

    case TyFunctionApplication()
      || TyVariant()
      || TyVariable(mutableRef: Unresolved(level: null)):
        throw NotARow(row2);
    case TyRowEmpty():
        throw RowMissingLabel(label1);
    case TyNever():
        throw 'unreachable because we immediately return from `unify` if either type is Never';
  }
}

void unify(Ty t1, Ty t2) {
  if (t1 == t2) return;
  if (t1 is TyNever || t2 is TyNever) return;

  switch ((t1, t2)) {
    case (final t1, TyVariable(mutableRef: Resolved(type: final t2)))
      || (TyVariable(mutableRef: Resolved(type: final t1)), final t2):
      unify(t1, t2);
      return;

    case (final ty, final TyVariable tvar && TyVariable(mutableRef: Unresolved(:final id, :final level?)))
      || (final TyVariable tvar && TyVariable(mutableRef: Unresolved(:final id, :final level?)), final ty):

      void verify(Ty ty) => switch (ty) {
        TyVariable(:final Unresolved mutableRef) when mutableRef.id == id =>
          throw RecursiveRowTypes(t1, t2),

        TyVariable(:final Unresolved mutableRef) when mutableRef.level! > level =>
          ty.mutableRef = Unresolved(id: mutableRef.id, level: level),

        TyVariable(mutableRef: Unresolved()) => null,
        TyVariable(mutableRef: Resolved(:final type)) => verify(type),
        TyFunctionApplication(:final monoTypes) => monoTypes.forEach(verify),
        TyRowExtend(:final type, :final row) => [verify(type), verify(row)],
        TyVariant(:final type) => verify(type),
        TyRowEmpty() => null,
        TyNever() => null,
      };
      verify(ty);
      tvar.mutableRef = Resolved(ty);
      return;

    default:
  }

  if (t1 is TyFunctionApplication &&
      t2 is TyFunctionApplication) {
    if (t1.name != t2.name) {
      throw TypeMismatch(t1, t2);
    }

    if (t1.monoTypes.length != t2.monoTypes.length) {
      throw TypeCardinalityMismatch(t1, t2);
    }

    zip(t1.monoTypes, t2.monoTypes, unify)
      .toList(); // force evaluation because zip is lazy
    return;
  }

  if (t1 is TyRowEmpty &&
      t2 is TyRowEmpty) {
    return;
  }

  if (t1 is TyRowExtend &&
      t2 is TyRowExtend) {
    final TyRowExtend(
      label: label1,
      type: fieldType1,
      row: restRow1,
    ) = t1;

    final wasUnresolved = switch (restRow1) {
      TyVariable(mutableRef: Unresolved()) => true,
      _ => false
    };

    final restRow2 = rewriteRow(t2, label1, fieldType1);

    final isResolved = switch (restRow1) {
      TyVariable(mutableRef: Resolved()) => true,
      _ => false
    };

    if (wasUnresolved && isResolved) throw RecursiveRowTypes(t1, t2);

    unify(restRow1, restRow2);
    return;
  }

  if (t1 is TyVariant &&
      t2 is TyVariant) {
    unify(t1.type, t2.type);
    return;
  }

  throw TypeMismatch(t1, t2);
}

Ty instantiate(int level, Ty type) => _instantiate(level, type, {});

Ty _instantiate(
  int level,
  Ty type,
  Map<int, TyVariable> mappings,
) {
  return switch (type) {
    TyVariable() => switch (type.mutableRef) {
      Unresolved(quantified: true, :final id) =>
        mappings[id] ??= TyVariable.fresh(level),

      Unresolved(quantified: false) =>
        type,

      Resolved(:final type) =>
        _instantiate(level, type, mappings),
    },
    TyFunctionApplication(:final name, :final monoTypes) =>
        TyFunctionApplication(name, [
          for (final ty in monoTypes) _instantiate(level, ty, mappings)
        ]),
    TyRowEmpty() =>
        type,
    TyNever() =>
        type,
    TyRowExtend(:final label, :final type, :final row) =>
        TyRowExtend(
          newEntry: (label, _instantiate(level, type, mappings)),
          row: _instantiate(level, row, mappings),
        ),
    TyVariant(:final type) => TyVariant(_instantiate(level, type, mappings)),
  };
}

Ty generalize(int level, Ty type) => switch (type) {
  TyVariable(mutableRef: Resolved(:final type)) =>
    generalize(level, type),

  TyVariable(mutableRef: Unresolved(:final id, level: final otherLevel?))
    when otherLevel > level =>
        TyVariable(Unresolved(id: id, level: null)),

  TyFunctionApplication() => TyFunctionApplication(
    type.name,
    type.monoTypes.map(generalize.partial(level)).toList(),
  ),

  TyRowExtend() => TyRowExtend(
    newEntry: (type.label, generalize(level, type.type)),
    row: generalize(level, type.row),
  ),

  TyVariant() => TyVariant(generalize(level, type.type)),

  TyRowEmpty() ||
  TyNever() ||
  TyVariable(mutableRef: Unresolved()) =>
    type,
};

typedef DisplayTypeVariable = String Function(({int id, bool quantified}));

String prettyPrint(
  Ty type, [
  DisplayTypeVariable displayTypeVariable = _default,
]) => switch (type) {
  TyVariable(:final mutableRef) =>
    switch (mutableRef) {
      Resolved(:final type) => prettyPrint(type, displayTypeVariable),
      Unresolved(:final id, :final quantified) =>
        displayTypeVariable((id: id, quantified: quantified)),
    },

  TyFunctionApplication(:final name, monoTypes: [])
      => name,

  TyFunctionApplication(name: 'List', monoTypes: [final typeArg])
      => 'List[${prettyPrint(typeArg, displayTypeVariable)}]',

  TyFunctionApplication(name: 'Result', monoTypes: [final typeArg])
      => 'Result[${prettyPrint(typeArg, displayTypeVariable)}]',

  TyFunctionApplication(name: 'Function', monoTypes: [final input, final output])
      => prettyPrintFunction(input, output, displayTypeVariable),

  TyFunctionApplication(:final name)
      => throw 'unknown TypeFunctionApplication $name',

  TyRowExtend(:final label, :final type, :final row)
      => prettyPrintRecord(label, type, row, displayTypeVariable),

  TyNever()
      => 'Never',

  TyRowEmpty()
      => '{}',

  TyVariant(type: TyRowExtend(:final label, :final type, :final row))
      => prettyPrintVariant(label, type, row, displayTypeVariable),

  TyVariant(:final type)
      => prettyPrint(type, displayTypeVariable),
};


String prettyPrintFunction(Ty parameter, Ty body, DisplayTypeVariable displayTypeVariable) {

  final parameters = [parameter];

  // https://github.com/dart-lang/language/issues/2536
  while (true) if (body case TyFunctionApplication(
    name: 'Function',
    monoTypes: [final input, final output],
  )) {
    parameters.add(input);
    body = output;
  } else break;

  final prettyParameters = [
    for (final param in parameters)
      if (param case TyFunctionApplication(name: 'Function'))
        prettyPrint(param, displayTypeVariable).parenthesized
      else
        prettyPrint(param, displayTypeVariable)
  ].join(', ');

  return '$prettyParameters -> ${prettyPrint(body, displayTypeVariable)}';
}


String prettyPrintRecord(String label, Ty type, Ty tail, DisplayTypeVariable displayTypeVariable) {
  final rows = ['$label: ${prettyPrint(type, displayTypeVariable)}'];
  while (tail is TyRowExtend) {
    rows.add('${tail.label}: ${prettyPrint(tail.type, displayTypeVariable)}');
    tail = tail.row;
  }
  final pairs = rows.reversed.join(', ');

  if (tail is TyRowEmpty || tail is TyVariable) {
    return '{$pairs}';
  } else {
    return '{..${prettyPrint(tail, displayTypeVariable)}, $pairs}';
  }
}

String _formatTag(String tag, Ty payload, DisplayTypeVariable displayTypeVariable) => switch (payload) {
  TyFunctionApplication(name: 'Unit') => '.$tag',
  _ => '.$tag(${prettyPrint(payload, displayTypeVariable)})',
};

String prettyPrintVariant(String tag, Ty payload, Ty tail, DisplayTypeVariable displayTypeVariable) {
  final rows = [_formatTag(tag, payload, displayTypeVariable)];
  while (tail is TyRowExtend) {
    rows.add(_formatTag(tail.label, tail.type, displayTypeVariable));
    tail = tail.row;
  }
  final pairs = rows.sorted().join(' | ');
  return pairs;
}

String _default(({int id, bool quantified}) args) =>
  args.quantified
    ? 't${args.id}'
    : '_${args.id}';


Ty normalizeTypeVariableIds(Ty t) {
  final namesSorted = collectTypeVariables({}, t).toList();

  int lookup(int name) =>
    namesSorted.contains(name)
      ? namesSorted.indexOf(name)
      : name;

  return rename(t, lookup);
}

Ty rename(Ty t, int Function(int) replace) =>
  switch (t) {
    TyVariable(:final mutableRef) => TyVariable(switch (mutableRef) {
        Unresolved(:final id, :final level) => Unresolved(id: replace(id), level: level),
        Resolved(:final type) => Resolved(rename(type, replace)),
      }),
    TyFunctionApplication(:final name, :final monoTypes) => TyFunctionApplication(
      name,
      [ for (final t in monoTypes) rename(t, replace) ]
    ),
    TyNever() => t,
    TyRowEmpty() => t,
    TyRowExtend(:final label, :final type, :final row) => TyRowExtend(
      newEntry: (label, rename(type, replace)),
      row: rename(row, replace),
    ),
    TyVariant(:final type) => TyVariant(
      rename(type, replace),
    )
  };

Set<int> collectTypeVariables(Set<int> state, Ty t) => {
  ...state,
  ...switch (t) {
    TyVariable(:final mutableRef) => switch (mutableRef) {
      Unresolved(:final id) => {id},
      Resolved(:final type) => collectTypeVariables(state, type),
    },
    TyFunctionApplication(:final monoTypes) => {
      for (final t in monoTypes)
        ...collectTypeVariables(state, t),
    },
    TyNever() => { },
    TyRowEmpty() => { },
    TyRowExtend(:final type, :final row) => {
      ...collectTypeVariables(state, row),
      ...collectTypeVariables(state, type),
    },
    TyVariant(:final type) => collectTypeVariables(state, type),
  }
};
