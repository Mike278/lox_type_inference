import 'dart:io';
// ignore_for_file: constant_identifier_names

void main(List<String> args) {
  if (args.length > 1) {
    print("Usage: jlox [script]");
    exit(64);
  } else if (args.length == 1) {
    runFile(args[0]);
  } else {
    runPrompt();
  }
}

void runPrompt() {
  while (true) {
    print('> ');
    final line = stdin.readLineSync();
    if (line == null) break;
    run(line);
    hadError = false;
  }
}

void runFile(String path) {
  run(File(path).readAsStringSync());
  if (hadError) exit(65);
}

void run(String source) {
  final tokens = scanTokens(source);

  for (final token in tokens) {
    print(token);
  }
}


var hadError = false;
void error(int line, String message) {
  report(line, "", message);
}

void report(int line, String where, String message) {
  print("[line $line] Error$where: $message");
  hadError = true;
}

List<Token> scanTokens(String source) {
  final tokens = <Token>[];
  int start = 0, current = 0, line = 1;

  String advance() => source[current++];

  while (current < source.length) {
    
  }
  return tokens;
}

enum TokenType {
  // Single-character tokens.
  LEFT_PAREN, RIGHT_PAREN, LEFT_BRACE, RIGHT_BRACE,
  COMMA, DOT, MINUS, PLUS, SEMICOLON, SLASH, STAR,

  // One or two character tokens.
  BANG, BANG_EQUAL,
  EQUAL, EQUAL_EQUAL,
  GREATER, GREATER_EQUAL,
  LESS, LESS_EQUAL,

  // Literals.
  IDENTIFIER, STRING, NUMBER,

  // Keywords.
  AND, CLASS, ELSE, FALSE, FUN, FOR, IF, NIL, OR,
  PRINT, RETURN, SUPER, THIS, TRUE, VAR, WHILE,

  EOF;
}

class Token {
  final TokenType type;
  final String lexeme;
  final Object? literal;
  final int line;

  Token(this.type, this.lexeme, this.literal, this.line);

  @override
  String toString() => '$type $lexeme $literal';
}
