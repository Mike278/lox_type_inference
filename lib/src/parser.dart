import 'package:lox/src/expr.dart';
import 'package:lox/src/lox_base.dart';
import 'package:lox/src/utils.dart';

//
// program        → declaration* EOF ;
// declaration    → varDecl
//                | funDecl
//                | statement
//                ;
// funDecl        → "fun" function ;
// function       → IDENTIFIER "(" parameters? ")" block ;
// parameters     → IDENTIFIER ( "," IDENTIFIER )* ;
// varDecl        → "var" IDENTIFIER ( "=" expression )? ";" ;
// statement      → exprStmt
//                | printStmt
//                | ifStmt
//                | block
//                | returnStmt
//                ;
// block          → "{" declaration* "}" ;
// exprStmt       → expression ";" ;
// printStmt      → "print" expression ";" ;
// ifStmt         → "if" expression "then" statement
//                ( "else" statement )?;
// returnStmt     → "return" expression? ";" ;
// expression     → ternary;
// ternary        → logical_or "?" expression ":" expression ";";
// logical_or     → logical_and ( "or" logical_and)* ;
// logical_and    → equality ( "and" equality)* ;
// equality       → comparison ( ( "!=" | "==" ) comparison )* ;
// comparison     → term ( ( ">" | ">=" | "<" | "<=" ) term )* ;
// term           → factor ( ( "-" | "+" ) factor )* ;
// factor         → unary ( ( "/" | "*" ) unary )* ;
// unary          → ( "!" | "-" ) unary
//                | call ;
// call           → primary ( "(" arguments? ")" )* ;
// arguments      → expression ( "," expression )* ;
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
      declaration()?.run(statements.add);
    }
    return statements;
  }

  // declaration    → varDecl
  //                | funDecl
  //                | statement
  //
  Statement? declaration() {
    if (matchFirst(TokenType.VAR)) return varDeclaration();
    if (matchFirst(TokenType.FUN)) return function();
    return statement();
  }

  // function       → IDENTIFIER "(" parameters? ")" block ;
  // parameters     → IDENTIFIER ( "," IDENTIFIER )* ;
  Statement? function() {
    final name = consume(TokenType.IDENTIFIER, "Expected function name.");
    consume(TokenType.LEFT_PAREN, "Expected '(' after function name.");

    final params = <Token>[];
    if (check(TokenType.RIGHT_PAREN)) {
      // 0-param function
    } else {
      while (true) {
        final param = consume(TokenType.IDENTIFIER, "Expected parameter name");
        params.add(param);
        if (!matchFirst(TokenType.COMMA)) {
          break;
        }
      }
    }
    consume(TokenType.RIGHT_PAREN, "Expected ')' after parameter list.");

    consume(TokenType.LEFT_BRACE, "Expected '{' before body.");
    final body = block();
    return FunctionDeclaration(name, params, body);
  }

  // varDecl        → "var" IDENTIFIER ( "=" expression )? ";" ;
  Statement? varDeclaration() {
    final name = consume(TokenType.IDENTIFIER, 'Expected variable name.');
    Expr? initializer;
    if (matchFirst(TokenType.EQUAL)) {
      initializer = expression();
    }

    consume(TokenType.SEMICOLON, "Expected ';' after variable declaration.");
    return VariableDeclaration(name, initializer);
  }

  // statement      → printStmt
  //                | ifStmt
  //                | block
  //                | returnStmt
  //                | exprStmt
  Statement statement() {
    if (matchFirst(TokenType.PRINT)) return printStatement();
    if (matchFirst(TokenType.LEFT_BRACE)) return Block(block());
    if (matchFirst(TokenType.RETURN)) return returnStatement();
    if (matchFirst(TokenType.IF)) return ifStatement();
    return expressionStatement();
  }

  // block          → "{" declaration* "}" ;
  // Expects open brace is already consumed.
  List<Statement> block() {
    final statements = [
      for (;!check(TokenType.RIGHT_BRACE) && !isAtEnd();)
        if (declaration() case final decl?)
          decl,
    ];
    consume(TokenType.RIGHT_BRACE, "Expected '}' after block.");
    return statements;
  }

  // ifStmt         → "if" expression "then" statement
  //                ( "else" statement )?;
  Statement ifStatement() {
    final keyword = previous();
    final condition = expression();
    consume(TokenType.THEN, "Expected 'then' after if condition.");
    final thenBranch = statement();
    final elseBranch = matchFirst(TokenType.ELSE) ? statement() : null;
    return IfStatement(keyword, condition, thenBranch, elseBranch);
  }

  Statement returnStatement() {
    final keyword = previous();
    final value = check(TokenType.SEMICOLON) ? null : expression();
    consume(TokenType.SEMICOLON, "Expected ';' after value.");
    return ReturnStatement(keyword, value);
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

  // expression     → ternary;
  Expr expression() => ternary();

  // ternary        → logical_or "?" expression ":" expression ";";
  Expr ternary() {
    final condition = or();
    if (matchFirst(TokenType.QUESTION)) {
      final questionMark = previous();
      final ifTrue = expression();
      consume(TokenType.COLON, "Expected ':' before last ternary expression");
      final ifFalse = expression();
      return Ternary(questionMark, condition, ifTrue, ifFalse);
    }
    return condition;
  }

  // logical_or     → logical_and ( "or" logical_and)* ;
  Expr or() {
    var expr = and();
    while (matchFirst(TokenType.OR)) {
      final operator = previous();
      final right = and();
      expr = LogicalOr(expr, operator, right);
    }
    return expr;
  }

  // logical_and    → equality ( "and" equality)* ;
  Expr and() {
    var expr = equality();
    while (matchFirst(TokenType.AND)) {
      final operator = previous();
      final right = equality();
      expr = LogicalAnd(expr, operator, right);
    }
    return expr;
  }


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
  //                | call ;
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

    return call();
  }

  // call           → primary ( "(" arguments? ")" )* ;
  Expr call() {
    final callee = primary();
    var expr = callee;
    while (true) {
      if (matchFirst(TokenType.LEFT_PAREN)) {
        expr = finishCall(expr);
      } else {
        break;
      }
    }
    return expr;
  }

  // arguments      → expression ( "," expression )* ;
  Expr finishCall(Expr callee) {
    final args = <Expr>[];
    if (check(TokenType.RIGHT_PAREN)) {
      // 0-arg function
    } else {
      while (true) {
        args.add(expression());
        if (!matchFirst(TokenType.COMMA)) {
          break;
        }
      }
    }
    final closingParen = consume(TokenType.RIGHT_PAREN, "Expected ')' after arguments");
    return Call(callee, args, closingParen);
  }


  // primary        → NUMBER | STRING
  //                | "true" | "false" | "nil"
  //                | "(" expression ")"
  //                | IDENTIFIER
  //                ;
  Expr primary() {
    if (matchFirst(TokenType.NUMBER)) return NumberLiteral(previous().literal as num);
    if (matchFirst(TokenType.STRING)) return StringLiteral(previous().literal as String);
    if (matchFirst(TokenType.TRUE)) return TrueLiteral();
    if (matchFirst(TokenType.FALSE)) return FalseLiteral();
    if (matchFirst(TokenType.NIL)) return NilLiteral();
    if (matchFirst(TokenType.IDENTIFIER)) return Variable(previous());

    if (matchFirst(TokenType.LEFT_PAREN)) {
      final expr = expression();
      consume(TokenType.RIGHT_PAREN, "Expected ')' after expression.");
      return Grouping(expr);
    }

    throw newParseError(peek(), 'Expected expression.');
  }

}

class ParseError implements Exception {}