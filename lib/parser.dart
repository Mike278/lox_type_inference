import 'package:lox/expr.dart';
import 'package:lox/token.dart';
import 'package:lox/utils.dart';

//
// program        → declaration* EOF ;
// declaration    → letDecl
//                | destructuringDecl
//                | statement
//                ;
// letDecl        → "let" IDENTIFIER "=" expression ";" ;
// destructuringDecl → "let" destructuring "="  expression ";" ;
// destructuring     → "{" destructElement ( "," destructElement )* "}";
// destructElement   → IDENTIFIER (":" ( IDENTIFIER | destructuring ) )?;
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
//                | tagConstructor
//                | tagMatch
//                | import
//                | call
//                ;
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
// import         → "import" STRING
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
  var current = 0;
  Parser(this.tokens);

  Token previous() => tokens[current-1];
  Token peek() => tokens[current];
  bool isAtEnd() => peek().type == .eof;
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
    throwParseError(peek(), message);
  }

  Never throwParseError(Token token, String message) {
    throw (token, message: message);
  }

  void synchronize() {
    advance();

    while (!isAtEnd()) {
      if (previous().type == .semicolon) return;
      switch (peek().type) {
        case .class_:
        case .let:
        case .for_:
        case .if_:
        case .while_:
        case .print:
        case .return_:
          return;
        default:
          advance();
      }
    }
  }

  List<Statement> parse() => [
    for (;!isAtEnd();)
      declaration()
  ];

  // declaration    → letDecl
  //                | destructuringDecl
  //                | statement
  //
  Statement declaration() {
    if (matchFirst(.let)) {
      if (matchFirst(.openBrace)) {
        return destructuringDecl();
      } else {
        return letDeclaration();
      }
    }
    return statement();
  }

  // letDecl        → "let" IDENTIFIER "=" expression ";" ;
  Statement letDeclaration() {
    final name = consume(.identifier, 'Expected variable name.');
    consume(.equal, "Expected '=' before variable declaration.");
    final initializer = expression();
    consume(.semicolon, "Expected ';' after variable declaration.");
    return LetDeclaration(name, initializer);
  }


  // destructuringDecl → "let" destructuring "="  expression ";" ;
  // destructuring     → "{" destructElement ( "," destructElement )* "}";
  // destructElement   → IDENTIFIER (":" ( IDENTIFIER | destructuring ) )?;
  Statement destructuringDecl() {

    DestructuringElement destructElement() {
      final name = consume(.identifier, 'Expected variable name');
      if (matchFirst(.colon)) {
        if (matchFirst(.openBrace)) {
          final elements = <DestructuringElement>[];
          while (!check(.closeBrace) && !isAtEnd()) {
            if (elements.isNotEmpty) consume(.comma, 'Expected comma between record field declarations.');
            if (check(.closeBrace)) break; // trailing comma
            elements.add(destructElement());
          }
          consume(.closeBrace, "Expected '}' after destructuring.");
          return Nested(name, elements);
        } else {
          final redeclaredName = consume(.identifier, 'Expected name of new variable');
          return Redeclare(name, redeclaredName);
        }
      } else {
        return InheritName(name);
      }
    }

    final elements = <DestructuringElement>[];
    while (!check(.closeBrace) && !isAtEnd()) {
      if (elements.isNotEmpty) consume(.comma, 'Expected comma between record field declarations.');
      if (check(.closeBrace)) break; // trailing comma
      elements.add(destructElement());
    }

    consume(.closeBrace, "Expected '}' after destructuring.");

    final equals = consume(.equal, "Expected '=' before variable declaration.");
    final initializer = expression();
    consume(.semicolon, "Expected ';' after variable declaration.");
    return Destructuring(elements, equals, initializer);
  }

  // statement      → printStmt
  //                | ifStmt
  //                | block
  //                | returnStmt
  //                | exprStmt
  Statement statement() {
    if (matchFirst(.assert_)) return assertStatement();
    if (matchFirst(.print)) return printStatement();
    if (matchFirst(.openBrace)) return block();
    if (matchFirst(.if_)) return ifStatement();
    return expressionStatement();
  }

  // block          → "{" declaration* "}" ;
  // Expects open brace is already consumed.
  Block block() {
    final openBrace = previous();
    final statements = [
      for (;!check(.closeBrace) && !isAtEnd();)
        declaration()
    ];
    final closeBrace = consume(.closeBrace, "Expected '}' after block.");
    return Block(openBrace, statements, closeBrace);
  }

  // ifStmt         → "if" expression "then" statement
  //                ( "else" statement )?;
  Statement ifStatement() {
    final keyword = previous();
    final condition = expression();
    consume(.then, "Expected 'then' after if condition.");
    final thenBranch = statement();
    final elseBranch = matchFirst(.else_) ? statement() : null;
    return IfStatement(keyword, condition, thenBranch, elseBranch);
  }

  Statement printStatement() {
    final keyword = previous();
    final value = expression();
    consume(.semicolon, "Expected ';' after value.");
    return PrintStatement(value, keyword);
  }

  Statement assertStatement() {
    var start = current;
    final keyword = previous();
    final value = expression();
    consume(.semicolon, "Expected ';' after value.");
    var end = current;
    final source = tokens.sublist(start, end).map((t) => t.lexeme).join();
    return AssertStatement(keyword, source, value);
  }

  Statement expressionStatement() {
    final value = expression();
    final semicolon = consume(.semicolon, "Expected ';' after value.");
    return ExpressionStatement(value, semicolon);
  }

  // expression     → ternary;
  Expr expression() => return_();

  Expr return_() {
    if (matchFirst(.return_)) {
      final keyword = previous();
      Expr? value;
      try {
        value = expression();
      } on MissingExpression {
        value = null;
      }
      return Return(keyword, value);
    }
    return ternary();
  }

  // ternary        → pipeline "?" expression ":" expression ";";
  Expr ternary() {
    final condition = pipeline();
    if (matchFirst(.question)) {
      final questionMark = previous();
      final ifTrue = expression();
      consume(.colon, "Expected ':' before last ternary expression");
      final ifFalse = expression();
      return Ternary(questionMark, condition, ifTrue, ifFalse);
    }
    return condition;
  }

  // pipeline       → logical_or ( "|>" logical_or )* ;
  Expr pipeline() {
    var expr = or();
    while (matchFirst(.pipeline)) {
      final operator = previous();
      final right = or();
      expr = Binary(expr, operator, right);
    }
    return expr;
  }

  // logical_or     → logical_and ( "or" logical_and)* ;
  Expr or() {
    var expr = and();
    while (matchFirst(.or)) {
      final operator = previous();
      final right = and();
      expr = LogicalOr(expr, operator, right);
    }
    return expr;
  }

  // logical_and    → equality ( "and" equality)* ;
  Expr and() {
    var expr = equality();
    while (matchFirst(.and)) {
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
      .bangEqual,
      .equalEqual,
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
        .greater,
        .greaterEqual,
        .less,
        .lessEqual,
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
      .minus,
      .plus,
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
      .slash,
      .star,
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
    if (matchFirst(.bang)) {
      final operator = previous();
      final right = unary();
      return UnaryBang(operator, right);
    }
    if (matchFirst(.minus)) {
      final operator = previous();
      final right = unary();
      return UnaryMinus(operator, right);
    }
    if (matchFirst(.backslash)) {
      return lambda();
    }
    if (matchFirst(.openBracket)) {
      return listLiteral();
    }
    if (matchFirst(.openBrace)) {
      return recordLiteral();
    }
    if (matchFirst(.dot)) {
      return tagConstructor();
    }
    if (matchFirst(.match)) {
      return tagMatch();
    }
    if (matchFirst(.import)) {
      return import();
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
      if (matchFirst(.openParen)) {
        final before = <Expr>[];
        final after = <Expr>[];
        Token? placeholder;
        if (check(.closeParen)) {
          // 0-arg function
        } else {
          while (true) {
            if (check(.closeParen)) break; // trailing comma
            if (matchFirst(.underscore)) {
              if (placeholder != null) {
                throwParseError(previous(), 'Can only have 1 placeholder arg');
              }
              placeholder = previous();
            } else {
              if (placeholder == null) {
                before.add(expression());
              } else {
                after.add(expression());
              }
            }
            if (!matchFirst(.comma)) {
              break;
            }
          }
        }
        final closingParen = consume(.closeParen, "Expected ')' after arguments");
        if (placeholder != null) {
          expr = Call(expr, ArgsWithPlaceholder(before, placeholder, after), closingParen);
        } else {
          if (after.isNotEmpty) throw 'bug';
          expr = Call(expr, ExpressionArgs(before), closingParen);
        }
      } else if (matchFirst(.dot)) {
        final fieldName = consume(.identifier, "Expected field name");
        expr = RecordGet(expr, fieldName);
      } else {
        break;
      }
    }
    return expr;
  }

  Expr tagConstructor() {
    final tagName = consume(.identifier, "Expected tag name");
    final Expr? payload;
    if (matchFirst(.openParen)) {
      payload = expression();
      consume(.closeParen, "Expected close paren");
    } else {
      payload = null;
    }
    return TagConstructor(tagName, payload);
  }

  Expr tagMatch() {
    final keyword = previous();
    final tag = expression();
    final openBrace = consume(.openBrace, "Expected open brace");
    final cases = <({Token tag, Token? payload, Token arrow, Expr result})>[];
    DefaultMatchCase? defaultCase;
    var first = true;
    do {
      if (!first) consume(.comma, 'Expected comma between match cases.');
      if (check(.closeBrace)) break;
      first = false;
      if (matchFirst(.identifier)) {
        final variable = previous();
        final arrow = consume(.arrow, "Expected arrow");
        final result = expression();
        defaultCase = (variable: variable, arrow: arrow, result: result);
      } else {
        consume(.dot, "Expected dot before tag name");
        final tag = consume(.identifier, "Expected tag name");
        final payload = matchFirst(.identifier, .underscore) ? previous() : null;
        final arrow = consume(.arrow, "Expected arrow");
        final result = expression();
        cases.add((tag: tag, payload: payload, arrow: arrow, result: result));
      }
    } while (!check(.closeBrace) && !isAtEnd());
    final closeBrace = consume(.closeBrace, "Expected close brace");
    return TagMatch(keyword, tag, (openBrace, closeBrace), cases, defaultCase);
  }

  Expr import() {
    final keyword = previous();
    final path = consume(.string, 'Expected path to import from.');
    return Import(keyword: keyword, target: path);
  }

  // record         → "{" recordField ( "," recordField )* "}"
  // recordField    → IDENTIFIER ":" expression
  Expr recordLiteral() {
    final fields = <Token, Expr>{};
    var first = true;
    ({Token dotdot, Expr record})? update;
    while (!check(.closeBrace) && !isAtEnd()) {
      if (!first) consume(.comma, 'Expected comma between record field declarations.');
      if (check(.closeBrace)) break; // trailing comma
      if (matchFirst(.dotdot)) {

        // todo: relax these constraints and transform into multiple record updates?
        if (update != null) throwParseError(previous(), 'Can only update 1 record');
        if (!first) throwParseError(previous(), 'The record being updated must be the first entry.');

        first = false;
        update = (
          dotdot: previous(),
          record: expression(),
        );
      } else {
        first = false;
        final name = consume(.identifier, 'Expected field name.');
        if (fields.containsKey(name)) {
          throwParseError(name, 'Duplicate field name');
        }
        consume(.colon, "Expected ':' between field name and value.");
        final value = expression();
        fields[name] = value;
      }
    }
    final closingBrace = consume(.closeBrace, "Expected '}' after record literal.");
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
    while (!check(.closeBracket) && !isAtEnd()) {
      if (!first) consume(.comma, 'Expected comma between list elements.');
      first = false;
      if (check(.closeBracket)) break; // trailing comma
      if (matchFirst(.dotdot)) {
        final dotdot = previous();
        final expr = expression();
        elements.add(SpreadListElement(dotdot, expr));
      } else {
        final expr = expression();
        elements.add(ExpressionListElement(expr));
      }
    }
    final closingBracket = consume(.closeBracket, "Expected ']' after list literal.");
    return ListLiteral(openBracket, closingBracket, elements);
  }

  // lambda          → "\" parameters? (block | ("->" expression)) ;
  // parameters      → IDENTIFIER ( "," IDENTIFIER )* ;
  Expr lambda() {
    final params = <Token>[];
    if (check(.openBrace) || check(.arrow)) {
      // 0-param function
    } else {
      while (true) {
        if (check(.arrow)) break; // trailing comma
        final param = consume(.identifier, "Expected parameter name");
        params.add(param);
        if (!matchFirst(.comma)) {
          break;
        }
      }
    }

    final LambdaBody body;
    if (matchFirst(.arrow)) {
      final arrow = previous();
      body = ArrowExpression(arrow, expression());
    } else {
      consume(.openBrace, "Expected '{' before body.");
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
    if (matchFirst(.number)) return NumberLiteral(previous());
    if (matchFirst(.string)) return StringLiteral(previous());
    if (matchFirst(.true_)) return TrueLiteral(previous());
    if (matchFirst(.false_)) return FalseLiteral(previous());
    if (matchFirst(.nil)) return NilLiteral(previous());
    if (matchFirst(.identifier)) return Variable(previous());

    if (matchFirst(.openParen)) {
      final expr = expression();
      consume(.closeParen, "Expected ')' after expression.");
      return Grouping(expr);
    }

    throw MissingExpression(peek());
  }

}

class ParserError implements Exception {
  final Token token;
  final String message;
  ParserError(this.token, this.message);
}
class MissingExpression extends ParserError {
  MissingExpression(Token token) : super(token, 'Expected expression.');
}