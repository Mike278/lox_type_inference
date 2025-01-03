
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
sealed class Ty with EquatableMixin {}

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
        throw Exception('row type expected, got $row2');
    case TyRowEmpty():
        throw Exception('row does not contain label $label1');
  }
}

typedef Context = Map<String, Ty>;

void _verifyNoSelfReferenceAndAdjustLevels(int id, int level, Ty ty) {
  void verify(Ty ty) => switch (ty) {
    TyVariable(:final Unresolved mutableRef) when mutableRef.id == id =>
        throw 'recursive types',

    TyVariable(:final Unresolved mutableRef) when mutableRef.level! > level =>
        ty.mutableRef = Unresolved(id: mutableRef.id, level: level),

    TyVariable(mutableRef: Unresolved()) => null,
    TyVariable(mutableRef: Resolved(:final type)) => verify(type),
    TyFunctionApplication(:final monoTypes) => monoTypes.forEach(verify),
    TyRowExtend(:final type, :final row) => [verify(type), verify(row)],
    TyVariant(:final type) => verify(type),
    TyRowEmpty() => null,
  };
  verify(ty);
}

void unify(Ty t1, Ty t2) {
  if (t1 == t2) return;

  switch ((t1, t2)) {
    case (final t1, TyVariable(mutableRef: Resolved(type: final t2)))
      || (TyVariable(mutableRef: Resolved(type: final t1)), final t2):
      unify(t1, t2);
      return;

    case (final ty, final TyVariable tvar && TyVariable(mutableRef: Unresolved(:final id, :final level?)))
      || (final TyVariable tvar && TyVariable(mutableRef: Unresolved(:final id, :final level?)), final ty):
      _verifyNoSelfReferenceAndAdjustLevels(id, level, ty);
      tvar.mutableRef = Resolved(ty);
      return;

    default:
  }

  if (t1 is TyFunctionApplication &&
      t2 is TyFunctionApplication) {
    if (t1.name != t2.name) {
      throw 'Type unification error:\n$t1\n$t2';
    }

    if (t1.monoTypes.length != t2.monoTypes.length) {
      throw 'Type unification error: $t1 has ${t1.monoTypes.length}, $t2 has ${t2.monoTypes.length}';
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

    if (wasUnresolved && isResolved) throw 'recursive row type';

    unify(restRow1, restRow2);
    return;
  }

  if (t1 is TyVariant &&
      t2 is TyVariant) {
    unify(t1.type, t2.type);
    return;
  }

  throw 'Type unification error: $t1 != $t2';
}

Ty instantiate(
  int level,
  Ty type, [
  Map<int, TyVariable>? mappings,
]) {
  mappings ??= {};
  return switch (type) {
    TyVariable() => switch (type.mutableRef) {
      Unresolved(quantified: true, :final id) =>
        mappings[id] ??= TyVariable.fresh(level),

      Unresolved(quantified: false) =>
        type,

      Resolved(:final type) =>
        instantiate(level, type),
    },
    TyFunctionApplication(:final name, :final monoTypes) =>
        TyFunctionApplication(name, [
          for (final ty in monoTypes) instantiate(level, ty, mappings)
        ]),
    TyRowEmpty() =>
        type,
    TyRowExtend(:final label, :final type, :final row) =>
        TyRowExtend(
          newEntry: (label, instantiate(level, type, mappings)),
          row: instantiate(level, row, mappings),
        ),
    TyVariant(:final type) => TyVariant(instantiate(level, type)),
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
  TyVariable(mutableRef: Unresolved()) =>
    type,
};


String prettyPrint(Ty type) => switch (type) {
  TyVariable(:final mutableRef) =>
    switch (mutableRef) {
      Resolved(:final type) => prettyPrint(type),
      Unresolved(:final id, quantified: false) => '_$id',
      Unresolved(:final id, quantified: true) => 't$id',
    },

  TyFunctionApplication(:final name, monoTypes: [])
      => name,

  TyFunctionApplication(name: 'List', monoTypes: [final typeArg])
      => 'List[$typeArg]',

  TyFunctionApplication(name: 'Result', monoTypes: [final typeArg])
      => 'Result[$typeArg]',

  TyFunctionApplication(name: 'Function', monoTypes: [final input, final output])
      => prettyPrintFunction(input, output),

  TyFunctionApplication(:final name)
      => throw 'unknown TypeFunctionApplication $name',

  TyRowExtend(:final label, :final type, :final row)
      => prettyPrintRecord(label, type, row),

  TyRowEmpty()
      => '{}',

  TyVariant(type: TyRowExtend(:final label, :final type, :final row))
      => prettyPrintVariant(label, type, row),

  TyVariant(:final type)
      => prettyPrint(type),
};


String prettyPrintFunction(Ty parameter, Ty body) {

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
        prettyPrint(param).parenthesized
      else
        prettyPrint(param)
  ].join(', ');

  return '$prettyParameters -> ${prettyPrint(body)}';
}


String prettyPrintRecord(String label, Ty type, Ty tail) {
  final rows = ['$label = ${prettyPrint(type)}'];
  while (tail is TyRowExtend) {
    rows.add('${tail.label} = ${prettyPrint(tail.type)}');
    tail = tail.row;
  }
  final pairs = rows.reversed.join(', ');

  if (tail is TyRowEmpty) {
    return '{$pairs}';
  } else {
    return '{..${prettyPrint(tail)}, $pairs}';
  }
}

String _formatTag(String tag, Ty payload) => switch (payload) {
  TyFunctionApplication(name: 'Unit') => '.$tag',
  _ => '.$tag(${prettyPrint(payload)})',
};

String prettyPrintVariant(String tag, Ty payload, Ty tail) {
  final rows = [_formatTag(tag, payload)];
  while (tail is TyRowExtend) {
    rows.add(_formatTag(tail.label, tail.type));
    tail = tail.row;
  }
  final pairs = rows.sorted().join(' | ');
  return pairs;
}
