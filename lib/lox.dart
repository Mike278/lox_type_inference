import 'dart:io';

import 'package:lox/src/env.dart';
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

void runPrompt() {
  var env = Env.global();
  while (true) {
    print('> ');
    final line = stdin.readLineSync();
    if (line == null) break;
    env = run(line, env);
    hadError = false;
  }
}

void runFile(String path) {
  run(File(path).readAsStringSync(), Env.global());
  if (hadError) exit(65);
  if (hadRuntimeError) exit(70);
}
