import 'package:lox/expr.dart';
import 'package:lox/scanner.dart';
import 'package:lox/utils.dart';

//
// program        → declaration* EOF ;
// declaration    → letDecl
//                | statement
//                ;
// letDecl        → "let" IDENTIFIER "=" expression ";" ;
// statement      → exprStmt
//                | printStmt
//                | ifStmt
//                | block
//                | returnStmt
//                ;
// block          → "{" declaration* "}" ;
// exprStmt       → expression ";" ;
// printStmt      → "print" expression ";" ;
// assertStmt     → "assert" expression ";" ;
// ifStmt         → "if" expression "then" statement
//                ( "else" statement )?;
// returnStmt     → "return" expression? ";" ;
// expression     → ternary;
// ternary        → pipeline "?" expression ":" expression ";";
// pipeline       → logical_or ( "|>" logical_or )* ;
// logical_or     → logical_and ( "or" logical_and)* ;
// logical_and    → equality ( "and" equality)* ;
// equality       → comparison ( ( "!=" | "==" ) comparison )* ;
// comparison     → term ( ( ">" | ">=" | "<" | "<=" ) term )* ;
// term           → factor ( ( "-" | "+" ) factor )* ;
// factor         → unary ( ( "/" | "*" ) unary )* ;
// unary          → ( "!" | "-" ) unary
//                | lambda
//                | recordLiteral
//                | listLiteral
//                | call ;
// lambda         → "\" parameters? (block | ("->" expression)) ;
// parameters     → IDENTIFIER ( "," IDENTIFIER )* ;
// recordLiteral  → "{" recordField ( "," recordField )* "}"
// recordField    → IDENTIFIER ":" expression
// listLiteral    → "[" listElement ( "," listElement )* "]"
// listElement    → ".." expression
//                | expression
// tagConstructor → "." IDENTIFIER ( "(" expression ")" ) ? ;
// tagMatch       → "match" expression "{" tagMatchCase ("," tagMatchCase )* "}"
// tagMatchCase   → "." IDENTIFIER (IDENTIFIER)? "->" expression
// call           → primary ( "(" arguments? ")" | "." IDENTIFIER )* ;
// arguments      → argument ( "," argument )* ;
// argument       → "_" | expression;
// primary        → NUMBER | STRING
//                | "true" | "false" | "nil"
//                | "(" expression ")"
//                | IDENTIFIER
//                ;
//

class Parser {
  final List<Token> tokens;
  final ErrorReporter _errorReporter;
  var current = 0;
  Parser(this.tokens, this._errorReporter);

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
    if (token.type == TokenType.EOF) {
      _errorReporter(formatError(token.line, token.offset, ' at end', message));
    } else {
      _errorReporter(formatError(token.line, token.offset, " at '${token.lexeme}'", message));
    }
    return ParseError();
  }

  void synchronize() {
    advance();

    while (!isAtEnd()) {
      if (previous().type == TokenType.SEMICOLON) return;
      switch (peek().type) {
        case TokenType.CLASS:
        case TokenType.LET:
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

  (List<Statement>, {bool hadError}) parse() {
    try {
      final statements = [
        for (;!isAtEnd();)
          declaration()
      ];
      return (statements, hadError: false);
    } on ParseError {
      return ([], hadError: true);
    }
  }

  // declaration    → letDecl
  //                | funDecl
  //                | statement
  //
  Statement declaration() {
    if (matchFirst(TokenType.LET)) return letDeclaration();
    return statement();
  }

  // letDecl        → "let" IDENTIFIER "=" expression ";" ;
  Statement letDeclaration() {
    final name = consume(TokenType.IDENTIFIER, 'Expected variable name.');
    consume(TokenType.EQUAL, "Expected '=' before variable declaration.");
    final initializer = expression();
    consume(TokenType.SEMICOLON, "Expected ';' after variable declaration.");
    return LetDeclaration(name, initializer);
  }

  // statement      → printStmt
  //                | ifStmt
  //                | block
  //                | returnStmt
  //                | exprStmt
  Statement statement() {
    if (matchFirst(TokenType.ASSERT)) return assertStatement();
    if (matchFirst(TokenType.PRINT)) return printStatement();
    if (matchFirst(TokenType.OPEN_BRACE)) return block();
    if (matchFirst(TokenType.RETURN)) return returnStatement();
    if (matchFirst(TokenType.IF)) return ifStatement();
    return expressionStatement();
  }

  // block          → "{" declaration* "}" ;
  // Expects open brace is already consumed.
  Block block() {
    final openBrace = previous();
    final statements = [
      for (;!check(TokenType.CLOSE_BRACE) && !isAtEnd();)
        declaration()
    ];
    final closeBrace = consume(TokenType.CLOSE_BRACE, "Expected '}' after block.");
    return Block(openBrace, statements, closeBrace);
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
    final keyword = previous();
    final value = expression();
    consume(TokenType.SEMICOLON, "Expected ';' after value.");
    return PrintStatement(value, keyword);
  }

  Statement assertStatement() {
    var start = current;
    final keyword = previous();
    final value = expression();
    consume(TokenType.SEMICOLON, "Expected ';' after value.");
    var end = current;
    final source = tokens.sublist(start, end).map((t) => t.lexeme).join();
    return AssertStatement(keyword, source, value);
  }

  Statement expressionStatement() {
    final value = expression();
    final semicolon = consume(TokenType.SEMICOLON, "Expected ';' after value.");
    return ExpressionStatement(value, semicolon);
  }

  // expression     → ternary;
  Expr expression() => ternary();

  // ternary        → pipeline "?" expression ":" expression ";";
  Expr ternary() {
    final condition = pipeline();
    if (matchFirst(TokenType.QUESTION)) {
      final questionMark = previous();
      final ifTrue = expression();
      consume(TokenType.COLON, "Expected ':' before last ternary expression");
      final ifFalse = expression();
      return Ternary(questionMark, condition, ifTrue, ifFalse);
    }
    return condition;
  }

  // pipeline       → logical_or ( "|>" logical_or )* ;
  Expr pipeline() {
    var expr = or();
    while (matchFirst(TokenType.PIPELINE)) {
      final operator = previous();
      final right = or();
      expr = Binary(expr, operator, right);
    }
    return expr;
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
  //                | lambda
  //                | recordLiteral
  //                | listLiteral
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
    if (matchFirst(TokenType.BACKSLASH)) {
      return lambda();
    }
    if (matchFirst(TokenType.OPEN_BRACKET)) {
      return listLiteral();
    }
    if (matchFirst(TokenType.OPEN_BRACE)) {
      return recordLiteral();
    }
    if (matchFirst(TokenType.DOT)) {
      return tagConstructor();
    }
    if (matchFirst(TokenType.MATCH)) {
      return tagMatch();
    }

    return call();
  }

  // call           → primary ( "(" arguments? ")" | "." IDENTIFIER )* ;
  // arguments      → argument ( "," argument )* ;
  // argument       → "_" | expression;
  Expr call() {
    final callee = primary();
    var expr = callee;
    while (true) {
      if (matchFirst(TokenType.OPEN_PAREN)) {
        final before = <Expr>[];
        final after = <Expr>[];
        Token? placeholder;
        if (check(TokenType.CLOSE_PAREN)) {
          // 0-arg function
        } else {
          while (true) {
            if (check(TokenType.CLOSE_PAREN)) break; // trailing comma
            if (matchFirst(TokenType.UNDERSCORE)) {
              if (placeholder != null) {
                throw newParseError(previous(), 'Can only have 1 placeholder arg');
              }
              placeholder = previous();
            } else {
              if (placeholder == null) {
                before.add(expression());
              } else {
                after.add(expression());
              }
            }
            if (!matchFirst(TokenType.COMMA)) {
              break;
            }
          }
        }
        final closingParen = consume(TokenType.CLOSE_PAREN, "Expected ')' after arguments");
        if (placeholder != null) {
          expr = Call(expr, ArgsWithPlaceholder(before, placeholder, after), closingParen);
        } else {
          if (after.isNotEmpty) throw 'bug';
          expr = Call(expr, ExpressionArgs(before), closingParen);
        }
      } else if (matchFirst(TokenType.DOT)) {
        final fieldName = consume(TokenType.IDENTIFIER, "Expected field name");
        expr = RecordGet(expr, fieldName);
      } else {
        break;
      }
    }
    return expr;
  }

  Expr tagConstructor() {
    final tagName = consume(TokenType.IDENTIFIER, "Expected tag name");
    final Expr? payload;
    if (matchFirst(TokenType.OPEN_PAREN)) {
      payload = expression();
      consume(TokenType.CLOSE_PAREN, "Expected close paren");
    } else {
      payload = null;
    }
    return TagConstructor(tagName, payload);
  }

  Expr tagMatch() {
    final keyword = previous();
    final tag = expression();
    final openBrace = consume(TokenType.OPEN_BRACE, "Expected open brace");
    final cases = <({Token tag, Token? payload, Token arrow, Expr result})>[];
    DefaultMatchCase? defaultCase;
    var first = true;
    do {
      if (!first) consume(TokenType.COMMA, 'Expected comma between match cases.');
      if (check(TokenType.CLOSE_BRACE)) break;
      first = false;
      if (matchFirst(TokenType.IDENTIFIER)) {
        final variable = previous();
        final arrow = consume(TokenType.ARROW, "Expected arrow");
        final result = expression();
        defaultCase = (variable: variable, arrow: arrow, result: result);
      } else {
        consume(TokenType.DOT, "Expected dot before tag name");
        final tag = consume(TokenType.IDENTIFIER, "Expected tag name");
        final payload = matchFirst(TokenType.IDENTIFIER) ? previous() : null;
        final arrow = consume(TokenType.ARROW, "Expected arrow");
        final result = expression();
        cases.add((tag: tag, payload: payload, arrow: arrow, result: result));
      }
    } while (!check(TokenType.CLOSE_BRACE) && !isAtEnd());
    final closeBrace = consume(TokenType.CLOSE_BRACE, "Expected close brace");
    return TagMatch(keyword, tag, (openBrace, closeBrace), cases, defaultCase);
  }

  // record         → "{" recordField ( "," recordField )* "}"
  // recordField    → IDENTIFIER ":" expression
  Expr recordLiteral() {
    final fields = <Token, Expr>{};
    var first = true;
    ({Token dotdot, Expr record})? update;
    while (!check(TokenType.CLOSE_BRACE) && !isAtEnd()) {
      if (!first) consume(TokenType.COMMA, 'Expected comma between record field declarations.');
      if (check(TokenType.CLOSE_BRACE)) break; // trailing comma
      if (matchFirst(TokenType.DOTDOT)) {

        // todo: relax these constraints and transform into multiple record updates?
        if (update != null) throw newParseError(previous(), 'Can only update 1 record');
        if (!first) throw newParseError(previous(), 'The record being updated must be the first entry.');

        first = false;
        update = (
          dotdot: previous(),
          record: expression(),
        );
      } else {
        first = false;
        final name = consume(TokenType.IDENTIFIER, 'Expected field name.');
        if (fields.containsKey(name)) {
          throw newParseError(name, 'Duplicate field name');
        }
        consume(TokenType.COLON, "Expected ':' between field name and value.");
        final value = expression();
        fields[name] = value;
      }
    }
    final closingBrace = consume(TokenType.CLOSE_BRACE, "Expected '}' after record literal.");
    if (update case (:final dotdot, :final record)?) {
      return RecordUpdate(dotdot, record, fields, closingBrace);
    }
    return Record(closingBrace, fields);
  }

  // listLiteral    → "[" listElement ( "," listElement )* "]"
  // listElement    → ".." expression
  //                | expression
  Expr listLiteral() {
    final openBracket = previous();
    final elements = <ListElement>[];
    var first = true;
    while (!check(TokenType.CLOSE_BRACKET) && !isAtEnd()) {
      if (!first) consume(TokenType.COMMA, 'Expected comma between list elements.');
      first = false;
      if (check(TokenType.CLOSE_BRACKET)) break; // trailing comma
      if (matchFirst(TokenType.DOTDOT)) {
        final dotdot = previous();
        final expr = expression();
        elements.add(SpreadListElement(dotdot, expr));
      } else {
        final expr = expression();
        elements.add(ExpressionListElement(expr));
      }
    }
    final closingBracket = consume(TokenType.CLOSE_BRACKET, "Expected ']' after list literal.");
    return ListLiteral(openBracket, closingBracket, elements);
  }

  // lambda          → "\" parameters? (block | ("->" expression)) ;
  // parameters      → IDENTIFIER ( "," IDENTIFIER )* ;
  Expr lambda() {
    final params = <Token>[];
    if (check(TokenType.OPEN_BRACE) || check(TokenType.ARROW)) {
      // 0-param function
    } else {
      while (true) {
        if (check(TokenType.ARROW)) break; // trailing comma
        final param = consume(TokenType.IDENTIFIER, "Expected parameter name");
        params.add(param);
        if (!matchFirst(TokenType.COMMA)) {
          break;
        }
      }
    }

    final LambdaBody body;
    if (matchFirst(TokenType.ARROW)) {
      final arrow = previous();
      body = ArrowExpression(arrow, expression());
    } else {
      consume(TokenType.OPEN_BRACE, "Expected '{' before body.");
      body = FunctionBody(block());
    }

    return Lambda(params, body);
  }



  // primary        → NUMBER | STRING
  //                | "true" | "false" | "nil"
  //                | "(" expression ")"
  //                | IDENTIFIER
  //                ;
  Expr primary() {
    if (matchFirst(TokenType.NUMBER)) return NumberLiteral(previous());
    if (matchFirst(TokenType.STRING)) return StringLiteral(previous());
    if (matchFirst(TokenType.TRUE)) return TrueLiteral(previous());
    if (matchFirst(TokenType.FALSE)) return FalseLiteral(previous());
    if (matchFirst(TokenType.NIL)) return NilLiteral(previous());
    if (matchFirst(TokenType.IDENTIFIER)) return Variable(previous());

    if (matchFirst(TokenType.OPEN_PAREN)) {
      final expr = expression();
      consume(TokenType.CLOSE_PAREN, "Expected ')' after expression.");
      return Grouping(expr);
    }

    throw newParseError(peek(), 'Expected expression.');
  }

}

class ParseError implements Exception {}