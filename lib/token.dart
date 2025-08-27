
import 'package:equatable/equatable.dart';

enum TokenType {
  // Single-character tokens.
  openParen, closeParen, openBrace, closeBrace, openBracket, closeBracket,
  backslash, colon, comma, dot, minus, pipe, plus, question, semicolon, slash, star, underscore,

  // one or two character tokens.
  arrow, bang, bangEqual, dotdot,
  equal, equalEqual,
  greater, greaterEqual,
  less, lessEqual,
  pipeline,

  // literals.
  identifier, string, number,

  // keywords.
  assert_, and, class_, else_, false_, for_, if_, import, match, nil, or,
  print, return_, super_, then, this_, true_, let, while_,

  eof;
}

class Token with EquatableMixin {
  final TokenType type;
  final String lexeme;
  final Object? literal;
  final int line;
  final int offset;
  final int absoluteOffset;

  Token(this.type, this.lexeme, this.literal, this.line, this.offset, this.absoluteOffset);
  Token replaceLexeme(String replacement) => Token(
    type,
    replacement,
    literal,
    line,
    offset,
    absoluteOffset,
  );

  @override
  String toString([String? path]) => [type.name, lexeme, if (literal != null) literal, '(${path??'ln'}$line:$offset)'].join(' ');

  @override get props => [type, lexeme, literal, line, offset];
}