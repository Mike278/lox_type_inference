import 'package:lox/src/expr.dart';
import 'package:lox/src/lox_base.dart';
import 'package:lox/src/utils.dart';

//
// program        → declaration* EOF ;
// declaration    → varDecl
//                | statement ;
// varDecl        → "var" IDENTIFIER ( "=" expression )? ";" ;
// statement      → exprStmt
//                | printStmt ;
// exprStmt       → expression ";" ;
// printStmt      → "print" expression ";" ;
// expression     → equality ;
// equality       → comparison ( ( "!=" | "==" ) comparison )* ;
// comparison     → term ( ( ">" | ">=" | "<" | "<=" ) term )* ;
// term           → factor ( ( "-" | "+" ) factor )* ;
// factor         → unary ( ( "/" | "*" ) unary )* ;
// unary          → ( "!" | "-" ) unary
//                | primary ;
// primary        → NUMBER | STRING
//                | "true" | "false" | "nil"
//                | "(" expression ")"
//                | IDENTIFIER
//                ;
//

class Parser {
  final List<Token> tokens;
  var current = 0;
  Parser(this.tokens);

  Token previous() => tokens[current-1];
  Token peek() => tokens[current];
  bool isAtEnd() => peek().type == TokenType.EOF;
  bool check(TokenType type) => !isAtEnd() && peek().type == type;
  Token advance() {
    if (!isAtEnd()) current++;
    return previous();
  }
  bool matchFirst(
    TokenType type1, [
    TokenType? type2,
    TokenType? type3,
    TokenType? type4,
    TokenType? type5,
  ]) {
    for (final type in [type1, type2, type3, type4, type5].whereNotNull()) {
      if (check(type)) {
        advance();
        return true;
      }
    }
    return false;
  }

  Token consume(TokenType type, String message) {
    if (check(type)) return advance();
    throw newParseError(peek(), message);
  }

  ParseError newParseError(Token token, String message) {
    errorForToken(token, message);
    return ParseError();
  }

  void synchronize() {
    advance();

    while (!isAtEnd()) {
      if (previous().type == TokenType.SEMICOLON) return;
      switch (peek().type) {
        case TokenType.CLASS:
        case TokenType.FUN:
        case TokenType.VAR:
        case TokenType.FOR:
        case TokenType.IF:
        case TokenType.WHILE:
        case TokenType.PRINT:
        case TokenType.RETURN:
          return;
        default:
          advance();
      }
    }
  }

  List<Statement> parse() {
    final statements = <Statement>[];
    while (!isAtEnd()) {
      statements.add(statement());
    }
    return statements;
  }

  // statement      → exprStmt
  //                | printStmt ;
  Statement statement() {
    if (matchFirst(TokenType.PRINT)) return printStatement();
    return expressionStatement();
  }

  Statement printStatement() {
    final value = expression();
    consume(TokenType.SEMICOLON, "Expected ';' after value.");
    return PrintStatement(value);
  }

  Statement expressionStatement() {
    final value = expression();
    consume(TokenType.SEMICOLON, "Expected ';' after value.");
    return ExpressionStatement(value);
  }

  // expression     → equality ;
  Expr expression() => equality();

  // equality       → comparison ( ( "!=" | "==" ) comparison )* ;
  Expr equality() {
    var expr = comparison();
    while (matchFirst(
      TokenType.BANG_EQUAL,
      TokenType.EQUAL_EQUAL,
    )) {
      final operator = previous();
      final right = comparison();
      expr = Binary(expr, operator, right);
    }
    return expr;
  }

  // comparison     → term ( ( ">" | ">=" | "<" | "<=" ) term )* ;
  Expr comparison() {
    var expr = term();
    while (matchFirst(
        TokenType.GREATER,
        TokenType.GREATER_EQUAL,
        TokenType.LESS,
        TokenType.LESS_EQUAL,
    )) {
      final operator = previous();
      final right = term();
      expr = Binary(expr, operator, right);
    }
    return expr;
  }

  // term           → factor ( ( "-" | "+" ) factor )* ;
  Expr term() {
    var expr = factor();
    while (matchFirst(
      TokenType.MINUS,
      TokenType.PLUS,
    )) {
      final operator = previous();
      final right = factor();
      expr = Binary(expr, operator, right);
    }
    return expr;
  }

  // factor         → unary ( ( "/" | "*" ) unary )* ;
  Expr factor() {
    var expr = unary();
    while (matchFirst(
      TokenType.SLASH,
      TokenType.STAR,
    )) {
      final operator = previous();
      final right = unary();
      expr = Binary(expr, operator, right);
    }
    return expr;
  }

  // unary          → ( "!" | "-" ) unary
  //                | primary ;
  Expr unary() {
    if (matchFirst(TokenType.BANG)) {
      final operator = previous();
      final right = unary();
      return UnaryBang(operator, right);
    }
    if (matchFirst(TokenType.MINUS)) {
      final operator = previous();
      final right = unary();
      return UnaryMinus(operator, right);
    }

    return primary();
  }

  // primary        → NUMBER | STRING | "true" | "false" | "nil"
  //                | "(" expression ")" ;
  Expr primary() {
    if (matchFirst(TokenType.NUMBER)) return NumberLiteral(previous().literal as num);
    if (matchFirst(TokenType.STRING)) return StringLiteral(previous().literal as String);
    if (matchFirst(TokenType.TRUE)) return TrueLiteral();
    if (matchFirst(TokenType.FALSE)) return FalseLiteral();
    if (matchFirst(TokenType.NIL)) return NilLiteral();

    if (matchFirst(TokenType.LEFT_PAREN)) {
      final expr = expression();
      consume(TokenType.RIGHT_PAREN, "Expected ')' after expression.");
      return Grouping(expr);
    }

    throw newParseError(peek(), 'Expected expression.');
  }

}

class ParseError implements Exception {}