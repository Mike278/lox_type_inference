
import 'package:lox/token.dart';


typedef ScanError = ({int line, int offset, String message});

(List<Token>, {List<ScanError> errors}) scanTokens(String source) {

  final tokens = <Token>[];

  int start = 0;
  int current = 0;
  int line = 1;
  int offset = 0;

  final errors = <({int line, int offset, String message})>[];
  void error(String message) {
    errors.add((line: line, offset: offset, message: message));
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
  return (tokens, errors: errors);
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
  'import' : TokenType.IMPORT,
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