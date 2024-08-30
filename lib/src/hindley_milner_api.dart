
import 'package:equatable/equatable.dart';
import 'package:lox/src/utils.dart';

//                         <PolyType>
//                        /          \
//                       /           |----------------------------------|
//                  <MonoType>       | TypeQuantifier(String, PolyType) |
//                 /         \       |----------------------------------|
//                /           \      | <a> List [a]                     |
//               /             \     | <a> Function [List [a], a]       |
//              /               \
// |----------------------|   |------------------------------------------------------|
// | TypeVariable(String) |   |TypeFunctionApplication(TypeFunction, List<MonoType>) |
// |----------------------|   |------------------------------------------------------|
// | a                    |   | String []                                            |
// |                      |   | List [Int]                                           |
// |                      |   | Function [Bool, Int]                                 |
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


extension PolyTypeAPI on PolyType {
  Set<String> freeVars() =>
    switch (this) {
      TypeVariable(name:final a) =>
          { a },
    
      TypeFunctionApplication(:final monoTypes) => 
          { for (final type in monoTypes) ...type.freeVars() },
    
      TypeQuantifier(:final a, :final sigma) =>
          sigma.freeVars().difference({ a })
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

  MonoType appliedTo(MonoType mono) =>
    switch (mono) {
      TypeVariable typeVariable => this[typeVariable.name] ?? typeVariable,
      TypeFunctionApplication app => TypeFunctionApplication(
        app.name,
        app.monoTypes.map(appliedTo).toList(),
      )
    };

  Context appliedToContext(Context context) =>
    context.mapValues(_applyPoly);

  PolyType _applyPoly(PolyType poly) =>
    switch (poly) {
      MonoType m => appliedTo(m),
      TypeQuantifier(:final a, :final sigma) => TypeQuantifier(a, _applyPoly(sigma))
    };

}

bool contains(MonoType type, TypeVariable type2) =>
  switch (type) {
    TypeVariable typeVar => typeVar == type2,
    TypeFunctionApplication(:final monoTypes) => monoTypes.any((ty) => contains(ty, type2))
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

  if (t1 is TypeFunctionApplication && t2 is TypeFunctionApplication) {
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

  throw 'Type unification error: $t1 != $t2';
}

MonoType instantiate(
  PolyType type, [
  Map<String, TypeVariable>? mappings,
]) {
  mappings ??= {};
  switch (type) {
    case TypeVariable typeVar:
      return mappings[typeVar.name] ?? typeVar;
    case TypeFunctionApplication app:
      return TypeFunctionApplication(
        app.name,
        app.monoTypes.map((mu) => instantiate(mu, mappings)).toList(),
      );
    case TypeQuantifier quant:
      mappings[quant.a] = TypeVariable.fresh();
      return instantiate(quant.sigma, mappings);
  }
}

PolyType generalize(Context context, MonoType type) {
  final freeVars = type.freeVars().difference(context.freeVars());
  return freeVars.fold(type, (sigma, a) => TypeQuantifier(a, sigma));
}
