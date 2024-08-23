
import 'package:lox/src/hindley_milner_api.dart';
import 'package:test/test.dart';

const _sentinel = Object();

extension TypeMatcherUtils<T> on TypeMatcher<T> {
  TypeMatcher<T> maybeHaving(
    Object? Function(T) feature,
    String description,
    Object? matcher,
  ) => identical(matcher, _sentinel) ? this : having(feature, description, matcher);
}



Matcher matchesTypeFunctionApplication({
  Object? name = _sentinel,
  Object? monoTypes = _sentinel,
}) => isA<TypeFunctionApplication>()
    .maybeHaving((x) => x.name, 'name', name)
    .maybeHaving((x) => x.monoTypes, 'monoTypes', monoTypes)
;


Matcher matchesTypeVariable({
  Object? name = _sentinel,
}) => isA<TypeVariable>()
    .maybeHaving((x) => x.name, 'name', name)
;
