import 'package:lox/expr.dart';
import 'package:lox/hindley_milner_lox.dart';
import 'package:lox/interpreter.dart';
import 'package:lox/parser.dart';
import 'package:lox/scanner.dart';
import 'package:path/path.dart';

extension type Source._(({String? path, String literal}) _) {
  factory Source.memory(String literal) {
    return Source._((path: null, literal: literal));
  }

  factory Source(String literal, {required String path}) {
    return Source._((path: path, literal: literal));
  }

  String? get path => _.path;
  String get literal => _.literal;
}

typedef ReadFile = String Function(String);

Env runFile(
  String path,
  Env env,
  LoxAssertion runAssert,
  RuntimeIO io,
  ReadFile readFile, {
  required bool checkTypes,
}) {
  return run(
    dirname(path),
    Source(readFile(path), path: path),
    env,
    runAssert,
    io,
    readFile,
    checkTypes: checkTypes,
  );
}

Env run(
  String relativeToDir,
  Source source,
  Env env,
  LoxAssertion runAssert,
  RuntimeIO io,
  ReadFile readFile, {
  required bool checkTypes,
}) {
  final (statements, resolveImport) = parseSourceAndResolveImports(
    relativeToDir,
    source,
    readFile,
  );
  if (checkTypes) {
    TypeInference(resolveImport).inferProgramTypes(statements);
  }
  return LoxRuntime(runAssert, io, resolveImport).interpret(
    statements,
    env,
  );
}

(List<Statement>, ResolveImport) parseSourceAndResolveImports(
  String relativeToDir,
  Source source,
  ReadFile readFile,
) {
  final statements = parse(source);
  final resolved = findAndResolveImports(relativeToDir, statements, readFile);
  final ResolveImport resolveImport = (path) =>
      resolved[path] ?? (throw '$path was not resolved');
  return (statements, resolveImport);
}

List<Statement> parse(Source source) {
  final (tokens, :errors) = scanTokens(source.literal);
  if (errors.isNotEmpty) throw [
    for (final (:line, :offset, :message) in errors)
      (path: source.path, line: line, offset: offset, message: message),
  ].join('\n');
  try {
    final statements = Parser(tokens).parse();
    return _Resolver(statements).sort();
  } on ParserError catch (e, s) {
    if (source.path case final path?) {
      Error.throwWithStackTrace(e.toString(path), s);
    } else {
      rethrow;
    }
  }
}

Map<ImportPath, Exports> findAndResolveImports(
  String relativeToDir,
  List<Statement> statements,
  ReadFile readFile,
) {
  final importStatements = findImports(statements);
  return resolveImportsRecursive(relativeToDir, importStatements, readFile);
}

Iterable<Import> findImports(List<Statement> statements) sync* {
  for (final statement in statements) {
    yield* statement.allExpressions().whereType<Import>();
  }
}

Map<ImportPath, Exports> resolveImportsRecursive(
  final String relativeToDir,
  Iterable<Import> imports,
  ReadFile readFile,
) {
  final result = <ImportPath, Exports>{};
  final toVisit = [...imports.map((import) => (relativeToDir, import))];
  while (toVisit.isNotEmpty) {
    final (relativeToDir, import) = toVisit.removeAt(0);
    final path = import.path;
    if (result.containsKey(path)) continue;
    final pathString = join(relativeToDir, path.literal);
    final source = Source(readFile(pathString), path: pathString);
    final statements = parse(source);
    final declarationsToExport = {
      for (final statement in statements)
        if (statement case LetDeclaration(:final pattern, :final initializer))
          pattern: initializer,
    };
    result[path] = declarationsToExport;
    final relativeToImportDir = dirname(join(relativeToDir, path.literal));
    toVisit.addAll(findImports(statements).map((import) => (relativeToImportDir, import)));
  }
  return result;
}


class _Resolver {
  final List<Statement> statements;
  _Resolver(this.statements);
  
  late Statement current;
  final adjacency = <({Statement parent, Statement child})>[];
  
  List<Statement> sort() {
    adjacency.clear();
    var env = Env.empty();

    for (final s in statements) {
      current = s;
      switch (s) {
        case ExpressionStatement(:final expr):
           checkExpr(env, expr);
        case LetDeclaration(:final pattern, :final initializer, :final keyword):
          env = env.definingAll(_destructure(pattern), keyword);
          checkExpr(env, initializer);
      }
    }

    final parentsByChildren = <Statement, List<Statement>>{};
    for (final (:parent, :child) in adjacency) {
      parentsByChildren.update(
        child,
        (parents) => parents..add(parent),
        ifAbsent: () => [parent],
      );
    }

    final sorted = <Statement>{};
    getParents(Statement s) => parentsByChildren[s] ?? [];
    addParents(Statement s) {
      for (final p in getParents(s)) {
        addParents(p);
        sorted.add(p);
      }
    }

    for (final s in statements) {
      for (final p in getParents(s)) {
        addParents(p);
        sorted.add(p);
      }
      sorted.add(s);
    }

    return sorted.toList();
  }
  
  void checkExpr(Env env, Expr expr) {
    if (expr case Lambda(:final params)) {
      env = Env(env, { for (final p in params) ..._destructure(p) });
    }

    for (final variable in expr.subExpressions().whereType<Variable>()) {
      try {
        final _ = env[variable.name];
      } on UndefinedVariable {
        for (final s in statements) {
          if (s case LetDeclaration(pattern: Identifier(:final name)) when name.lexeme == variable.name.lexeme) {
            adjacency.add((parent: s, child: current));
            break;
          }
        }
      }
    }
  }

  Map<String, Object?> _destructure(Pattern pattern) => {
    ...switch (pattern) {
      TagPattern() => {},
      Identifier(:final name) => { name.lexeme: null },
      RecordDestructure(:final elements) => {
        for (final e in elements)
          ...switch (e.pattern) {
            TagPattern()                    => {},
            null                            => { e.name.lexeme : null },
            Identifier(name: final newName) => { newName.lexeme : null },
            RecordDestructure nested        => _destructure(nested),
          },
      },
    }
  };
}
