import 'dart:io';

import 'package:collection/collection.dart';
import 'package:path/path.dart';

void main() async {
  final keep = {
    'foo/relative.lox': false,
    'foo/up.lox': false,
    'util/functions.lox': true,
    'util/lists.lox': true,
    'util/numeric.lox': true,
    'advent_of_code_2021_day_2.lox': true,
    'advent_of_code_2024_day_1.lox': true,
    'advent_of_code_2024_day_2.lox': true,
    'basic_test.lox': false,
    'if.lox': false,
    'imports.lox': false,
    'lambdas.lox': false,
    'lists.lox': false,
    'make_counter.lox': false,
    'patterns.lox': true,
    'records.lox': false,
    'return_expr.lox': true,
    'scoping.lox': false,
    'tags.lox': true,
    'tag_pattern_err_let.lox': false,
    'tag_pattern_err_let_no_payload.lox': false,
    'tag_pattern_err_param.lox': false,
    'tag_pattern_err_param_no_payload.lox': false,
  };
  final sampleFiles = Directory('../examples')
      .list(recursive: true)
      .where((e) => e is File)
      .map((e) => (split(e.path).skip(2).join('/'), e as File));
  final samples = {
      await for (final (name, file) in sampleFiles)
        name: ? switch (keep[name]) {
          null => throw 'new example $name needs classifying',
          true =>  await file.readAsString(),
          false => null,
        },
    };
    final sorted = samples.keys.sorted(
      (a, b) => -a.contains('/').toString().compareTo(b.contains('/').toString())
    );

    File('web/code_samples.dart').writeAsString(
      """
final samples = {
  ${sorted.map((sampleName) => "'$sampleName': r'''${samples[sampleName]!}'''").join(',\n')}
};
""",
    );
}

