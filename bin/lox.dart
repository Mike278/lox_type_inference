import 'dart:io';

import 'package:lox/coordinator.dart';
import 'package:lox/expr.dart';
import 'package:lox/hindley_milner_api.dart';
import 'package:lox/interpreter.dart';
import 'package:lox/mark_types.dart';

void main(List<String> args) {
  if (args.length > 1) {
    print("Usage: jlox [script or directory of scripts]");
    exit(64);
  } else if (args case [final path]) {
    try {
      if (path.endsWith('.lox')) {
        _runFile(path);
      } else {
        Directory(path)
            .listSync(recursive: true)
            .whereType<File>()
            .map((f) => f.path)
            .forEach(_runFile);
      }
    } on (Expr, TypeCheckException) catch (e, s) {
      final (expr, err) = e;
      final span = locationForErrorUnderline(expr);
      Error.throwWithStackTrace('$err\n$expr $span', s);
    }
  } else {
    _runPrompt();
  }
}

final _io = (print: print);

void _runPrompt() {
  var env = Env.global();
  while (true) {
    print('> ');
    final line = stdin.readLineSync();
    if (line == null) break;
    try {
      env = run(
        Directory.current.path,
        Source(line),
        env,
        defaultLoxAssert,
        _io,
        dartIOReadFile,
        checkTypes: true,
      );
    } catch (e, s) {
      print(e);
      print(s);
    }
  }
}

void _runFile(String path) {
  runFile(
    checkTypes: true,
    path,
    Env.global(),
    defaultLoxAssert,
    _io,
    dartIOReadFile,
  );
}

final ReadFile dartIOReadFile =
  (path) => Source(File(path).readAsStringSync());