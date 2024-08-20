import 'dart:collection';

import 'package:lox/lox.dart';
import 'package:lox/src/interpreter.dart';

final LoxFunction clock = (
  arity: 0,
  impl: (args) => DateTime.now().millisecondsSinceEpoch / 1000,
);
final LoxFunction first = (
  arity: 1,
  impl: (args) => switch (args.single as List) {
    [final x, ...] => x,
    [] => throw LoxRuntimeException(null, 'List is empty'),
  },
);
final LoxFunction rest = (
  arity: 1,
  impl: (args) => switch (args.single as List) {
    [final _, ...final rest] => rest,
    [] => [],
  },
);
final LoxFunction empty = (
  arity: 1,
  impl: (args) => (args.single as List).isEmpty,
);

final globals = UnmodifiableMapView({
  'clock': clock,
  'List': {
    'first': first,
    'rest': rest,
    'empty': empty,
  },
});

class Env {
  final UnmodifiableMapView<String, Object?> _values;
  final Env? _enclosing;
  Env.global() : _values = globals, _enclosing = null;
  Env(this._enclosing, [Map<String, Object?>? values]) : _values = UnmodifiableMapView({...?values});

  Env defining(Token name, Object? value) {
    final key = name.lexeme;
    if (_values.containsKey(key)) {
      throw LoxRuntimeException(name, "The name '${name.lexeme}' is already defined.");
    }
    return Env(_enclosing, {
      ..._values,
      key: value,
    });
  }

  Object? operator[](Token name) {
    final key = name.lexeme;
    if (_values.containsKey(key)) {
      return _values[key];
    }
    if (_enclosing case final env?) {
      return env[name];
    }
    return throw LoxRuntimeException(name, "Undefined variable '${name.lexeme}'.");
  }
}