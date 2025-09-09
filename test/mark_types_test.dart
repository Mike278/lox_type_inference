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

    test('6', () {
      expect(
        _markTypes(r'''
        let x = [
          .a(.one),
          .a(.two),
          .b(.one),
          .b(.two),
        ] \> List.first;
        
        let y = match x {
          .a(.one) -> 1,
          .a(.two) -> 1,
          .b(.one) -> 1,
          .b(.two) -> 1,
        };
        ''').map((x) => x.display).where((x) => x.startsWith('x:')),
        [
          'x: .a(.one | .two) | .b(.one | .two)',
          'x: .a(.one | .two) | .b(.one | .two)',
        ],
      );
    }, skip: 'Type checking nested tag patterns is not supported yet');

    test('7', () {
      expect(
        _markError(r'''
        let x = [
          .a(.one),
          .a(.two),
        ] \> List.first;
        
        let y = match x {
          .a(.one) -> 1,
        };
        ''').map((x) => 'line ${x.$1.from.line}: ${x.display}'),
        [
          contains('line 5: Type mismatch')
        ],
      );
    }, skip: 'Type checking nested tag patterns is not supported yet');

    test('8', () {
      expect(
        _markError(r'''
        let x = [
          .a(.one),
          .a(.two),
        ] \> List.first;
        
        let y = match x {
          .a(.one) -> 1,
          .a(.two) -> 1,
        };
        ''').map((x) => x.display).where((x) => x.startsWith('x:')),
        [
          'x: .a(.one | .two)',
          'x: .a(.one | .two)',
        ],
      );
    }, skip: 'Type checking nested tag patterns is not supported yet');

    test('9', () {
      expect(
        _markTypes(r'''
        let x = [
          .a(.one),
          .a(.two),
          .b(.one),
          .b(.two),
        ] \> List.first;
        
        let y = match x {
          .a(a) -> match a {
            .one -> 1,
            .two -> 1,
          },
          .b(b) -> match b {
            .one -> 1,
            .two -> 1,
          },
        };
        ''').map((x) => x.display).where((x) => x.startsWith(RegExp('[xyab]'))),
        [
            'x: .a(.one | .two) | .b(.one | .two)',
            'y: Num',
            'x: .a(.one | .two) | .b(.one | .two)',
            'a: .one | .two',
            'a: .one | .two',
            'b: .one | .two',
            'b: .one | .two',
        ],
      );
    });

    test('10', () {
      expect(
        _markTypes(r'''
        let x = [
          .a(.one),
          .a(.two),
        ] \> List.first;
        
        let y = match x {
          .a(a) -> match a {
            .one -> 1,
            .two -> 1,
          },
        };
        ''').map((x) => x.display).where((x) => x.startsWith(RegExp('[xya]'))),
        [
            'x: .a(.one | .two)',
            'y: Num',
            'x: .a(.one | .two)',
            'a: .one | .two',
            'a: .one | .two'
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


List<MarkText> _markError(String source, [Map<String, String> files = const {}]) {
  final (marks, :errorOutput) = markTypes(
    '',
    Source.memory(source),
    (path) => files[path]!
  );
  expect(errorOutput, isNotEmpty, reason: 'marks were:\n${marks.join('\n')}');
  return marks;
}
