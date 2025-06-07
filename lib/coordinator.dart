import 'package:lox/interpreter.dart';
import 'package:lox/parser.dart';
import 'package:lox/scanner.dart';

import 'package:lox/expr.dart';
import 'package:path/path.dart';

extension type Source(String literal) {}

typedef ReadFile = Source Function(String);

Env runFile(
  String path,
  Env env,
  LoxAssertion runAssert,
  RuntimeIO io,
  ReadFile readFile,
) {
  return run(
    dirname(path),
    readFile(path),
    env,
    runAssert,
    io,
    readFile,
  );
}

Env run(
  String relativeToDir,
  Source source,
  Env env,
  LoxAssertion runAssert,
  RuntimeIO io,
  ReadFile readFile,
) {
  final (statements, resolveImport) = parseSourceAndResolveImports(
    relativeToDir,
    source,
    readFile,
  );
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
  if (errors.isNotEmpty) throw errors;
  return Parser(tokens).parse();
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
    final source = readFile(join(relativeToDir, path.literal));
    final statements = parse(source);
    final declarationsToExport = {
      for (final statement in statements)
        if (statement case LetDeclaration(:final name, :final initializer))
          name: initializer,
    };
    result[path] = declarationsToExport;
    final relativeToImportDir = dirname(join(relativeToDir, path.literal));
    toVisit.addAll(findImports(statements).map((import) => (relativeToImportDir, import)));
  }
  return result;
}
