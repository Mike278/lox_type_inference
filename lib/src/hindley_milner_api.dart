
import 'package:equatable/equatable.dart';
import 'package:lox/src/utils.dart';

//                                     <PolyType>
//                                    /          \
//  |----------------------------------|          \
//  | TypeQuantifier(String, PolyType) |       <MonoType>_____.|----------------------|
//  |----------------------------------|            |          | TypeVariable(String) |
//  | <a> List [a]                     |            |          |----------------------|
//  | <a> Function [List [a], a]       |            |          | a                    |
//  |----------------------------------|            |          |----------------------|
//                                                  |
//                                                  |_________.|------------------------------------------------------|
//                                                  |          |TypeFunctionApplication(TypeFunction, List<MonoType>) |
//                                                  |          |------------------------------------------------------|
//                                                  |          | String []                                            |
//                                                  |          | List [Int]                                           |
//                                                  |          | Function [Bool, Int]                                 |
//                                                  |          |------------------------------------------------------|
//                                                  |
//                                                  |~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
//                                                  |
//                                                  | Extend HM with records, based on https://www.microsoft.com/en-us/research/publication/extensible-records-with-scoped-labels/
//                                                  |
//                                                  |---------.|-------------------------------------------|
//                                                  |          | TypeRowExtend((String, MonoType), MonoType) |
//                                                  |          |-------------------------------------------|
//                                                  |          | {..{}, a = 1}                             |
//                                                  |          | {..r, a = 1}                              |
//                                                  |          | {..{..r, a = 1}, b = "b"}                 |
//                                                  |          |-------------------------------------------|
//                                                  |
//                                                  |---------.|----------------|
//                                                  |          | TypeRowEmpty() |
//                                                  |          |----------------|
//                                                  |          | {}             |
//                                                  |          |----------------|
//


sealed class PolyType {
  const PolyType();
}

class TypeQuantifier extends PolyType with EquatableMixin {
  final String a;
  final PolyType sigma;

  const TypeQuantifier(this.a, this.sigma);

  @override
  String toString() => '(∀$a. $sigma)';

  @override get props => [a, sigma];
}

sealed class MonoType extends PolyType {
  const MonoType();
}

class TypeVariable extends MonoType with EquatableMixin {
  final String name;
  const TypeVariable(this.name);

  static int counter = 0;
  TypeVariable.fresh() : name = "t${counter++}";

  @override
  String toString() => name;

  @override get props => [name];
}

class TypeFunctionApplication extends MonoType with EquatableMixin {
  final String name;
  final List<MonoType> monoTypes;

  const TypeFunctionApplication(this.name, this.monoTypes);

  @override
  String toString() => "$name${monoTypes.isEmpty ? '' : '[${monoTypes.join(', ')}]'}";

  @override get props => [name, monoTypes];
}

class TypeRowEmpty extends MonoType with EquatableMixin {
  @override get props => [];
  @override String toString() => '{}';
}
class TypeRowExtend extends MonoType with EquatableMixin {
  final String label;
  final MonoType type;
  final MonoType row;
  TypeRowExtend({required (String, MonoType) newEntry, required this.row}) :
        label = newEntry.$1,
        type = newEntry.$2;
  @override get props => [label, type, row];
  @override String toString() => '{ ..$row, $label = $type }';
}

(Substitution, MonoType) rewriteRow(
  MonoType row2,
  String label1,
  MonoType fieldType1,
) {
  switch (row2) {
    case TypeRowExtend(
      label: final label2,
      type: final fieldType2,
      row: final restRow2,
    ):
        if (label1 == label2) {
          return (unify(fieldType1, fieldType2), restRow2);
        }
        final (s, t) = rewriteRow(restRow2, label1, fieldType1);
        return (s, TypeRowExtend(newEntry: (label2, fieldType2), row: t));

    case TypeVariable(:final name):
        final restRow2 = TypeVariable.fresh();
        final type2 = TypeRowExtend(
          newEntry: (label1, fieldType1),
          row: restRow2,
        );
        return ({name: type2}, restRow2);

    case TypeFunctionApplication():
        throw Exception('row type expected, got $row2');
    case TypeRowEmpty():
        throw Exception('row does not contain label $label1');
  }
}

extension PolyTypeAPI on PolyType {
  Set<String> freeVars() =>
    switch (this) {
      TypeVariable(name:final a) =>
          { a },
    
      TypeFunctionApplication(:final monoTypes) => 
          { for (final type in monoTypes) ...type.freeVars() },
    
      TypeQuantifier(:final a, :final sigma) =>
          sigma.freeVars().difference({ a }),

      TypeRowEmpty() => {},

      TypeRowExtend(:final type, :final row) => {
        ...type.freeVars(),
        ...row.freeVars(),
      },
    };

}

typedef Context = Map<String, PolyType>;
typedef Substitution = Map<String, MonoType>;
Substitution combine(List<Substitution> ss) => ss.reduce((a, b) => {
  ...a,
  for (final (k, v) in b.pairs())
    k: a.appliedTo(v)
});

extension ContextAPI on Context {
  Set<String> freeVars() => { for (final type in values) ...type.freeVars() };
}

extension SubstitutionAPI on Substitution {

  MonoType appliedTo(MonoType mono) => switch (mono) {
      TypeVariable(:final name) => this[name] ?? mono,
      TypeFunctionApplication(:final name, :final monoTypes) =>
        TypeFunctionApplication(
          name,
          monoTypes.map(appliedTo).toList(),
        ),
      TypeRowEmpty() => mono,
      TypeRowExtend(:final label, :final type, :final row) => TypeRowExtend(
        newEntry: (label, appliedTo(type)),
        row: appliedTo(row),
      ),
  };

  Context appliedToContext(Context context) =>
    context.mapValues(_applyPoly);

  PolyType _applyPoly(PolyType poly) =>
    switch (poly) {
      MonoType m => appliedTo(m),
      TypeQuantifier(:final a, :final sigma) => TypeQuantifier(a, _applyPoly(sigma))
    };

}

bool contains(MonoType type1, TypeVariable type2) =>
  switch (type1) {
    TypeVariable() => type1 == type2,
    TypeFunctionApplication(:final monoTypes) => monoTypes.any((ty) => contains(ty, type2)),
    TypeRowEmpty() => false,
    TypeRowExtend(:final type, :final row) =>
        contains(type, type2) ||
        contains(row, type2),
  };

Substitution unify(MonoType t1, MonoType t2) {
  if (t1 == t2) return {};

  if (t1 is TypeVariable) {
    if (contains(t2, t1)) throw 'Type unification error: $t2 contains $t1';
    return {t1.name: t2};
  }

  if (t2 is TypeVariable) {
    return unify(t2, t1);
  }

  if (t1 is TypeFunctionApplication &&
      t2 is TypeFunctionApplication) {
    if (t1.name != t2.name) {
      throw 'Type unification error: ${t1.name} != ${t2.name}';
    }

    if (t1.monoTypes.length != t2.monoTypes.length) {
      throw 'Type unification error: $t1 has ${t1.monoTypes.length}, $t2 has ${t2.monoTypes.length}';
    }

    Substitution substitution = {};

    for (final (a, b) in zip(t1.monoTypes, t2.monoTypes, makePair)) {
      final a1 = substitution.appliedTo(a);
      final b1 = substitution.appliedTo(b);
      final unified = unify(a1, b1);
      substitution = combine([substitution, unified]);
    }

    return substitution;
  }

  if (t1 is TypeRowEmpty &&
      t2 is TypeRowEmpty) {
    return {};
  }

  if (t1 is TypeRowExtend &&
      t2 is TypeRowExtend) {
    final TypeRowExtend(
      label: label1,
      type: fieldType1,
      row: restRow1,
    ) = t1;
    final (rowSubstitution, restRow2) = rewriteRow(t2, label1, fieldType1);

    // from `uni-row` rule: tail(r) !∈ dom(θ`)
    final tailVar = findTailTypeVariableName(restRow1);
    if (tailVar != null && rowSubstitution.containsKey(tailVar)) {
      throw Exception('recursive row type');
    }

    final unifiedSubstitution = unify(rowSubstitution.appliedTo(restRow1), restRow2);
    return combine([rowSubstitution, unifiedSubstitution]);
  }

  throw 'Type unification error: $t1 != $t2';
}


String? findTailTypeVariableName(MonoType row) => switch (row) {
  TypeVariable(:final name) => name,
  TypeRowEmpty() => null,
  TypeRowExtend(:final row) => findTailTypeVariableName(row),
  TypeFunctionApplication() => throw '$row is not a row type',
};

MonoType instantiate(
  PolyType type, [
  Map<String, TypeVariable>? mappings,
]) {
  mappings ??= {};
  return switch (type) {
    TypeQuantifier(:final a, :final sigma) =>
        instantiate(sigma, mappings..[a] = TypeVariable.fresh()),
    MonoType type => switch (type) {
        TypeVariable(:final name) =>
            mappings[name] ?? type,
        TypeFunctionApplication(:final name, :final monoTypes) =>
            TypeFunctionApplication(name, [for (final ty in monoTypes) instantiate(ty, mappings)]),
        TypeRowEmpty() =>
            type,
        TypeRowExtend(:final label, :final type, :final row) =>
            TypeRowExtend(
              newEntry: (label, instantiate(type, mappings)),
              row: instantiate(row, mappings),
            ),
    }
  };
}

PolyType generalize(Context context, MonoType type) {
  final freeVars = type.freeVars().difference(context.freeVars());
  return freeVars.fold(type, (sigma, a) => TypeQuantifier(a, sigma));
}
