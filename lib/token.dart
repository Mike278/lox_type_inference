
import 'package:equatable/equatable.dart';

// ignore_for_file: constant_identifier_names
enum TokenType {
  // Single-character tokens.
  OPEN_PAREN, CLOSE_PAREN, OPEN_BRACE, CLOSE_BRACE, OPEN_BRACKET, CLOSE_BRACKET,
  BACKSLASH, COLON, COMMA, DOT, MINUS, PIPE, PLUS, QUESTION, SEMICOLON, SLASH, STAR, UNDERSCORE,

  // One or two character tokens.
  ARROW, BANG, BANG_EQUAL, DOTDOT,
  EQUAL, EQUAL_EQUAL,
  GREATER, GREATER_EQUAL,
  LESS, LESS_EQUAL,
  PIPELINE,

  // Literals.
  IDENTIFIER, STRING, NUMBER,

  // Keywords.
  ASSERT, AND, CLASS, ELSE, FALSE, FOR, IF, IMPORT, MATCH, NIL, OR,
  PRINT, RETURN, SUPER, THEN, THIS, TRUE, LET, WHILE,

  EOF;
}

class Token with EquatableMixin {
  final TokenType type;
  final String lexeme;
  final Object? literal;
  final int line;
  final int offset;

  Token(this.type, this.lexeme, this.literal, this.line, this.offset);

  @override
  String toString() => [type.name, lexeme, if (literal != null) literal, '(ln$line:$offset)'].join(' ');

  @override get props => [type, lexeme, literal, line, offset];
}