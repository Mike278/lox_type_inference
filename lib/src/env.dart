import 'package:lox/lox.dart';
import 'package:lox/src/interpreter.dart';

class Env {
  final _values = <String, Object?>{};
  final Env? _enclosing;
  Env.global() : _enclosing = null;
  Env(this._enclosing);

  void operator[]=(Token name, Object? value) {
    final key = name.lexeme;
    final values = _values;
    if (values.containsKey(key)) {
      throw LoxRuntimeException(name, "The name '${name.lexeme}' is already defined.");
    }
    values[key] = value;
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