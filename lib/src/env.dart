import 'package:lox/lox.dart';
import 'package:lox/src/interpreter.dart';

class Env {
  final _values = <String, Object?>{};

  void operator[]=(Token name, Object? value) {
    _values[name.lexeme] = value;
  }
  Object? operator[](Token name) =>
    _values.containsKey(name.lexeme)
      ? _values[name.lexeme]
      : throw LoxRuntimeException(name, "Undefined variable '${name.lexeme}'.");
}