import 'package:lox/coordinator.dart';
import 'package:lox/expr.dart';
import 'package:lox/hindley_milner_api.dart';
import 'package:lox/hindley_milner_lox.dart';
import 'package:test/test.dart';


void main() {

  test('new inference', () {
    final statements = inferSource2(r'''
let id = \x -> x;
let a = id(1);
let b = id("b");
''');
    expect(
      [
        for (final let in statements)
          (let as LetDeclaration).initializer.type.toString(),
      ],
      [
        't0 -> t0',
        'Num',
        'String',
      ]
    );
  });
}


List<Statement> inferSource2(String source, [ReadFile? readFile]) {
  if (!source.contains(';')) source = '$source;';
  readFile ??= (_) => fail('no import resolver');
  final (statements, resolveImport) = parseSourceAndResolveImports(
    '',
    Source(source),
    readFile,
  );
  inferProgramTypes(statements);
  for (final statement in statements) {
    for (final expr in statement.allExpressions()) {
      if (expr.type case final type?) {
        expr.type = LoxType(normalizeTypeVariableIds(type));
      }
    }
  }
  return statements;
}