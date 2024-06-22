import 'package:lox/src/expr.dart';
import 'package:lox/src/lox_base.dart';
import 'package:lox/src/utils.dart';

//
// expression     → equality ;
// equality       → comparison ( ( "!=" | "==" ) comparison )* ;
// comparison     → term ( ( ">" | ">=" | "<" | "<=" ) term )* ;
// term           → factor ( ( "-" | "+" ) factor )* ;
// factor         → unary ( ( "/" | "*" ) unary )* ;
// unary          → ( "!" | "-" ) unary
//                | primary ;
// primary        → NUMBER | STRING | "true" | "false" | "nil"
//                | "(" expression ")" ;
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
  bool matchAny(
    TokenType type1, [
    TokenType? type2,
    TokenType? type3,
    TokenType? type4,
  ]) {
    for (final type in [type1, type2, type3, type4].whereNotNull()) {
      if (check(type)) {
        advance();
        return true;
      }
    }
    return false;
  }

  Expr parse() {
    todo;
  }

  Expr expression() => equality();

  Expr equality() {
    var expr = comparison();
    while (matchAny(TokenType.BANG_EQUAL, TokenType.EQUAL_EQUAL)) {
      final operator = previous();
      final right = comparison();
      expr = Binary(expr, operator, right);
    }
    return expr;
  }

}
