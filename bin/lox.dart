import 'dart:io';

import 'package:lox/coordinator.dart';
import 'package:lox/interpreter.dart';

void main(List<String> args) {
  if (args.length > 1) {
    print("Usage: jlox [script or directory of scripts]");
    exit(64);
  } else if (args case [final path]) {
    if (path.endsWith('.lox')) {
      _runFile(path);
    } else {
      Directory(path)
          .listSync(recursive: true)
          .whereType<File>()
          .map((f) => f.path)
          .forEach(_runFile);
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
        (path) => Source(File(path).readAsStringSync()),
      );
    } catch (e, s) {
      print(e);
      print(s);
    }
  }
}

void _runFile(String path) {
  runFile(
    path,
    Env.global(),
    defaultLoxAssert,
    _io,
    (path) => Source(File(path).readAsStringSync())
  );
}
