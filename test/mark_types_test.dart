import 'package:lox/coordinator.dart' show Source;
import 'package:lox/mark_types.dart';
import 'package:test/test.dart';

void main() {

  group('normalizeProgramTypeVariableIds', () {
    test('1', () {
      expect(
        _markTypes(r'''
        let id1 = \w, x {
          let id2 = \y, z {};
        };
        ''').map((x) => x.display),
        [
          'id1: a, b -> Unit',
          'a, b -> Unit',
          'a, b -> Unit',
          'w: a',
          'x: b',
          'id2: c, d -> Unit',
          'c, d -> Unit',
          'c, d -> Unit',
          'y: c',
          'z: d',
        ],
      );
    });
    test('2', () {
      expect(
        _markTypes(r'''
        let id1 = \w, x {};
        let id2 = \y, z {};
        ''').map((x) => x.display),
        [
          'id1: a, b -> Unit',
          'a, b -> Unit',
          'a, b -> Unit',
          'w: a',
          'x: b',
          'id2: a, b -> Unit',
          'a, b -> Unit',
          'a, b -> Unit',
          'y: a',
          'z: b',
        ],
      );
    });
    test('3', () {
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
    });

    test('4', () {
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

    test('5', () {
      expect(
        _markTypes(r'''
        let foo = import "foo.lox";
        let fooId1 = foo.id1;
        let fooId2 = foo.id2;
        ''', {'foo.lox': r'let id1 = \x -> x; let id2 = \y -> y;'}
        ).map((x) => x.display),
        [
            'foo: {id1: a -> a, id2: b -> b}',
            'foo.lox: {id1: a -> a, id2: b -> b}',
            'foo.lox: {id1: a -> a, id2: b -> b}',
            'fooId1: a -> a',
            'id1: a -> a',
            'foo: {id1: a -> a, id2: b -> b}',
            'fooId2: a -> a',
            'id2: a -> a',
            'foo: {id1: b -> b, id2: a -> a}',
        ],
      );
    });
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
