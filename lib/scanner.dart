
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
    tokens.add(Token(type, text, literal, line, offset - (current - start), start));
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
    addToken(.string, stringValue);
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
    addToken(.number, n);
  }

  void identifier() {
    while (current < source.length && source.codeUnitAt(current).isAlphaNumeric) {
      current++;
      offset++;
    }
    final text = source.substring(start, current);
    addToken(keywords[text] ?? .identifier);
  }

  void scanToken() {
    final c = source[current++];
    offset++;
    switch (c) {
      case '_': addToken(.underscore);
      case '(': addToken(.openParen);
      case ')': addToken(.closeParen);
      case '{': addToken(.openBrace);
      case '}': addToken(.closeBrace);
      case '[': addToken(.openBracket);
      case ']': addToken(.closeBracket);
      case r'\': addToken(match('>') ? .pipeline : .backslash);
      case ':': addToken(.colon);
      case ',': addToken(.comma);
      case '.': addToken(match('.') ? .dotdot : .dot);
      case '-': addToken(match('>') ? .arrow : .minus);
      case '+': addToken(.plus);
      case '|': addToken(.pipe);
      case ';': addToken(.semicolon);
      case '*': addToken(.star);
      case '?': addToken(match('?') ? .questionQuestion : .question);
      case '!': addToken(match('=') ? .bangEqual : .bang);
      case '=': addToken(match('=') ? .equalEqual : .equal);
      case '<': addToken(match('=') ? .lessEqual : .less);
      case '>': addToken(match('=') ? .greaterEqual : .greater);
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
          addToken(.slash);
        }
      default: error('Unexpected character $c');
    }
  }

  while (current < source.length) {
    start = current;
    scanToken();
  }

  tokens.add(Token(.eof, '', null, line, 0, current));
  return (tokens, errors: errors);
}

final keywords = <String, TokenType>{
  'match' : .match,
  'as' : .as,
  'assert' : .assert_,
  'and' :    .and,
  'class' :  .class_,
  'else' :   .else_,
  'false' :  .false_,
  'for' :    .for_,
  'if' :     .if_,
  'import' : .import,
  'let' :    .let,
  'nil' :    .nil,
  'or' :     .or,
  'print' :  .print,
  'return' : .return_,
  'super' :  .super_,
  'this' :   .this_,
  'then' :   .then,
  'true' :   .true_,
  'while' :  .while_,
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