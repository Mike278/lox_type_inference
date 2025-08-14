import 'package:lox/coordinator.dart' show Source;
import 'package:lox/mark_types.dart';
import 'package:test/test.dart';

void main() {

  test('normalizeProgramTypeVariableIds', () {
    expect(
      _markTypes(r'''
      let fn1 = \data { let x = data.x; let y = data.y; };
      let fn2 = \data { let x = data.x; let y = data.y; };
      ''').map((x) => x.display),
      [
        'fn1: {y: b, x: c} -> Unit',
        '{y: b, x: c} -> Unit',
        '{y: b, x: c} -> Unit',
        'data: {y: b, x: c}',
        'x: c',
        'x: c',
        'data: {y: b, x: c}',
        'y: b',
        'y: b',
        'data: {y: b, x: c}',
        'fn2: {y: b, x: c} -> Unit',
        '{y: b, x: c} -> Unit',
        '{y: b, x: c} -> Unit',
        'data: {y: b, x: c}',
        'x: c',
        'x: c',
        'data: {y: b, x: c}',
        'y: b',
        'y: b',
        'data: {y: b, x: c}',
      ],
    );
    expect(
      _markTypes(r'''
      let fn1 = \data { let {x, y} = data; };
      let fn2 = \data { let {x, y} = data; };
      ''').map((x) => x.display),
      [
        'fn1: {y: b, x: c} -> Unit',
        '{y: b, x: c} -> Unit',
        '{y: b, x: c} -> Unit',
        'data: {y: b, x: c}',
        'x: c',
        'y: b',
        'data: {y: b, x: c}',
        'fn2: {y: b, x: c} -> Unit',
        '{y: b, x: c} -> Unit',
        '{y: b, x: c} -> Unit',
        'data: {y: b, x: c}',
        'x: c',
        'y: b',
        'data: {y: b, x: c}',
      ],
    );
  });
}


List<MarkText> _markTypes(String source, [Map<String, String> files = const {}]) {
  final (marks, :errorOutput) = markTypes(
    '',
    Source.memory(source),
    (path) => files[path]!
  );
  if (errorOutput.isNotEmpty) throw errorOutput;
  return marks;
}
