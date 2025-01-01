
import 'package:equatable/equatable.dart';
import 'package:lox/interpreter.dart';
import 'package:lox/parser.dart';

import '../env.dart';
// ignore_for_file: constant_identifier_names

typedef ErrorReporter = void Function(String);

typedef RunResult = (Env, {bool hadScanError, bool hadParseError, bool hadRuntimeError});

RunResult run(
  String source,
  Env env,
  ErrorReporter errorReporter,
  LoxAssertion runAssert,
  RuntimeIO io,
) {
  final (tokens, hadError: hadScanError) = scanTokens(source, errorReporter);

  final parser = Parser(tokens, errorReporter);
  final (statements, hadError: hadParseError) = parser.parse();

  if (hadParseError || hadScanError) {
    return (
      env,
      hadParseError: hadParseError,
      hadScanError: hadScanError,
      hadRuntimeError: false,
    );
  }

  final (
    newEnv,
    :hadRuntimeError,
  ) = LoxRuntime(errorReporter, runAssert, io).interpret(
    statements,
    env,
  );

  return (
    newEnv,
    hadParseError: false,
    hadScanError: false,
    hadRuntimeError: hadRuntimeError,
  );
}

String formatError(int line, int offset, String atToken, String message) {
  return "[line $line:$offset] Error$atToken: $message";
}

(List<Token>, {bool hadError}) scanTokens(
  String source,
  ErrorReporter errorReporter,
) {

  final tokens = <Token>[];

  int start = 0;
  int current = 0;
  int line = 1;
  int offset = 0;

  var hadError = false;
  void error(String message) {
    hadError = true;
    errorReporter(formatError(line, offset, '', message));
  }

  void addToken(TokenType type, [Object? literal]) {
    final text = source.substring(start, current);
    tokens.add(Token(type, text, literal, line, offset - (current - start)));
  }

  bool match(String expected) {
    if (current >= source.length) return false;
    if (source[current] != expected) return false;
    current++;
    offset++;
    return true;
  }

  void string() {
    while (current < source.length && source[current] != '"') {
      if (source[current] == '\n') {
        line++;
        offset = 0;
      }
      current++;
      offset++;
    }

    if (current >= source.length) {
      error("Unterminated string.");
      return;
    }

    // The closing ".
    current++;
    offset++;

    // Trim the surrounding quotes.
    final stringValue = source.substring(start + 1, current - 1);
    addToken(TokenType.STRING, stringValue);
  }

  void consumeDigits() {
    while (current < source.length && source.codeUnitAt(current).isDigit) {
      current++;
      offset++;
    }
  }

  void number() {
    consumeDigits();
    if (current+1 < source.length && source[current] == '.' && source.codeUnitAt(current+1).isDigit) {
      current++;
      offset++;
      consumeDigits();
    }
    final n = num.parse(source.substring(start, current));
    addToken(TokenType.NUMBER, n);
  }

  void identifier() {
    while (current < source.length && source.codeUnitAt(current).isAlphaNumeric) {
      current++;
      offset++;
    }
    final text = source.substring(start, current);
    addToken(keywords[text] ?? TokenType.IDENTIFIER);
  }

  void scanToken() {
    final c = source[current++];
    offset++;
    switch (c) {
      case '_': addToken(TokenType.UNDERSCORE);
      case '(': addToken(TokenType.OPEN_PAREN);
      case ')': addToken(TokenType.CLOSE_PAREN);
      case '{': addToken(TokenType.OPEN_BRACE);
      case '}': addToken(TokenType.CLOSE_BRACE);
      case '[': addToken(TokenType.OPEN_BRACKET);
      case ']': addToken(TokenType.CLOSE_BRACKET);
      case r'\': addToken(match('>') ? TokenType.PIPELINE : TokenType.BACKSLASH);
      case ':': addToken(TokenType.COLON);
      case ',': addToken(TokenType.COMMA);
      case '.': addToken(match('.') ? TokenType.DOTDOT : TokenType.DOT);
      case '-': addToken(match('>') ? TokenType.ARROW : TokenType.MINUS);
      case '+': addToken(TokenType.PLUS);
      case '|': addToken(TokenType.PIPE);
      case ';': addToken(TokenType.SEMICOLON);
      case '*': addToken(TokenType.STAR);
      case '?': addToken(TokenType.QUESTION);
      case '!': addToken(match('=') ? TokenType.BANG_EQUAL : TokenType.BANG);
      case '=': addToken(match('=') ? TokenType.EQUAL_EQUAL : TokenType.EQUAL);
      case '<': addToken(match('=') ? TokenType.LESS_EQUAL : TokenType.LESS);
      case '>': addToken(match('=') ? TokenType.GREATER_EQUAL : TokenType.GREATER);
      case '"': string();
      case '\n': line++; offset = 0;
      case ' ' || '\r' || '\t': break;
      case String(codeUnits: [Char(isDigit: true)]): number();
      case String(codeUnits: [Char(isAlpha: true)]): identifier();
      case '/':
        if (match('/')) {
          while (current < source.length && source[current] != '\n') {
            current++;
            offset++;
          }
        } else {
          addToken(TokenType.SLASH);
        }
      default: error('Unexpected character $c');
    }
  }

  while (current < source.length) {
    start = current;
    scanToken();
  }

  tokens.add(Token(TokenType.EOF, '', null, line, 0));
  return (tokens, hadError: hadError);
}

final keywords = {
  'match' : TokenType.MATCH,
  'assert' : TokenType.ASSERT,
  'and' :    TokenType.AND,
  'class' :  TokenType.CLASS,
  'else' :   TokenType.ELSE,
  'false' :  TokenType.FALSE,
  'for' :    TokenType.FOR,
  'if' :     TokenType.IF,
  'let' :    TokenType.LET,
  'nil' :    TokenType.NIL,
  'or' :     TokenType.OR,
  'print' :  TokenType.PRINT,
  'return' : TokenType.RETURN,
  'super' :  TokenType.SUPER,
  'this' :   TokenType.THIS,
  'then' :   TokenType.THEN,
  'true' :   TokenType.TRUE,
  'while' :  TokenType.WHILE,
};

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
  ASSERT, AND, CLASS, ELSE, FALSE, FOR, IF, MATCH, NIL, OR,
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
  String toString() => [type.name, lexeme, if (literal != null) literal, '(ln$line:${offset})'].join(' ');

  @override get props => [type, lexeme, literal, line, offset];
}

const zero = 48;
const nine = 57;
const A = 65;
const Z = 90;
const a = 97;
const z = 122;
const underscore = 95;

typedef Char = int;
extension on Char {
  bool get isDigit => switch (this) {
    >= zero && <= nine => true,
    _ => false,
  };
  bool get isAlpha => switch (this) {
    == underscore => true,
    >= A && <= Z => true,
    >= a && <= z => true,
    _ => false,
  };

  bool get isAlphaNumeric => isAlpha || isDigit;
}