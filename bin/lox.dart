import 'dart:io';

import 'package:lox/src/env.dart';
import 'package:lox/src/interpreter.dart';
import 'package:lox/src/scanner.dart';

void main(List<String> args) {
  if (args.length > 1) {
    print("Usage: jlox [script or directory of scripts]");
    exit(64);
  } else if (args case [final path]) {
    if (path.endsWith('.lox')) {
      runFile(path);
    } else {
      Directory(path)
          .listSync(recursive: true)
          .whereType<File>()
          .map((f) => f.path)
          .forEach(runFile);
    }
  } else {
    runPrompt();
  }
}


RunResult _run(String source, Env env) =>
  run(source, env, print, defaultLoxAssert, (print: print));

void runPrompt() {
  var env = Env.global();
  while (true) {
    print('> ');
    final line = stdin.readLineSync();
    if (line == null) break;
    RunResult($1: env) = _run(line, env);
  }
}

void runFile(String path) {
  final RunResult(
    :hadScanError,
    :hadParseError,
    :hadRuntimeError,
  ) = _run(
    File(path).readAsStringSync(),
    Env.global(),
  );
  if (hadScanError) exit(65);
  if (hadParseError) exit(66);
  if (hadRuntimeError) exit(70);
}
