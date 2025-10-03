
extension ListUtils<T> on List<T> {
  List<T> sorted([int Function(T, T)? compare]) => this..sort(compare);
}


extension IterableExtensions<T> on Iterable<T> {
  Iterable<U> zipWith<U, V>(Iterable<V> other, U Function(T, V) f) =>
      zip(this, other, f);
  Iterable<T> skipLast() => take(length - 1);
}

extension NullableTypeIterableExtensions<T extends Object> on Iterable<T?> {
  Iterable<T> whereNotNull() => [for (final i in this) if (i != null) i];
}


/// Generates a lazy Iterable by calling [combine] on each element of [left] and [right] at equal indexes.
/// Iteration stops at the end of the shorter iterable.
/// Optionally supply [padLeft] and/or [padRight] to produce values
/// for the shorter iterable such that the longer iterable is exhausted.
///
/// Example:
///     print(zip(
///       ['Alice', 'Bob'],
///       ['Smith', 'Vance', 'Hall'],
///       (first, last) => '$first $last',
///       padLeft: (last) => 'a member of the $last family',
///     ));
///     // Alice Smith, Bob Vance, a member of the Hall family
///
/// Example:
///     final naturalNumbers = () sync* { int i = 1; while (true) yield i++; }();
///     print(zip(
///       ['one', 'two', 'three'],
///       naturalNumbers,
///       (word, digit) => '$word ($digit)',
///     ));
///     // one (1), two (2), three (3)
Iterable<TOutput> zip<TLeft, TRight, TOutput>(
  Iterable<TLeft> left,
  Iterable<TRight> right,
  TOutput Function(TLeft, TRight) combine, {
  TOutput Function(TRight)? padLeft,
  TOutput Function(TLeft)? padRight,
}) sync* {
  final l = left.iterator, r = right.iterator;
  bool hasLeft, hasRight;
  while ((hasLeft = l.moveNext()) | (hasRight = r.moveNext())) {
    if (hasLeft && hasRight) {
      yield combine(l.current, r.current);
    } else if (hasLeft) {
      if (padRight == null) return;
      final leftValue = l.current;
      yield padRight(leftValue);
    } else if (hasRight) {
      if (padLeft == null) return;
      final rightValue = r.current;
      yield padLeft(rightValue);
    }
  }
}


extension MapExtensions<K, V> on Map<K, V> {
  T fold<T>(T initial, T Function(T, K, V) combine) {
    forEach((k, v) => initial = combine(initial, k, v));
    return initial;
  }

  List<T> toList<T>(T Function(K, V) mapper) =>
    fold([], (list, key, value) => list..add(mapper(key, value)));

  List<(K, V)> pairs() => toList(makePair);

  Map<K, V2> mapValues<V2>(V2 Function(V) f) => {
    for (final MapEntry(:key, :value) in entries)
      key: f(value)
  };
}


extension Functions1<T, A> on T Function(A) {
  T Function() partial(A a) => () => this(a);
}

extension Functions2<T, A, B> on T Function(A, B) {
  T Function(B) partial(A a) => (b) => this(a, b);
}

extension Functions3<T, A, B, C> on T Function(A, B, C) {
  T Function(B, C) partial(A a) => (b, c) => this(a, b, c);
}

(A, B) makePair<A, B>(A a, B b) => (a, b);

extension StringUtils on String {
  String get parenthesized => '($this)';
}
