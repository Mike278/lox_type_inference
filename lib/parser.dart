import 'package:lox/expr.dart';
import 'package:lox/token.dart';
import 'package:lox/utils.dart';

//
// program               → declaration* EOF ;
// declaration           → letDecl | statement ;
// letDecl               → "let" pattern "=" expression ";" ;
// pattern               → recordPattern
//                       | literalPattern
//                       | identifierPattern
//                       ;
// recordPattern         → "{" recordPatternElement ( "," recordPatternElement )* "}";
// recordPatternElement  → pattern (":" pattern )?;
// literalPattern        → NUMBER | STRING | "true" | "false" | "nil"
// identifierPattern     → IDENTIFIER
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
// ternary        → logical_or "?" expression ":" expression ";";
// logical_or     → logical_and ( "or" logical_and)* ;
// logical_and    → equality ( "and" equality)* ;
// equality       → comparison ( ( "!=" | "==" ) comparison )* ;
// comparison     → term ( ( ">" | ">=" | "<" | "<=" ) term )* ;
// term           → factor ( ( "-" | "+" ) factor )* ;
// factor         → pipeline ( ( "/" | "*" ) pipeline )* ;
// pipeline       → unary ( "|>" unary )* ;
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
// parameters     → pattern ( "," pattern )* ;
// recordLiteral  → "{" recordField ( "," recordField )* "}"
// recordField    → (IDENTIFIER ":")? expression
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
  var _discardCount = 0;
  Parser(this.tokens);

  Token previous() => tokens[current-1];
  Token peek() => tokens[current];
  Iterable<Token> peekN(int n) => tokens.skip(current).take(n);
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
    throw ParserError(token, message);
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
  //                | statement
  //
  Statement declaration() {
    if (matchFirst(.let)) {
      return letDeclaration();
    }
    return statement();
  }

  // letDecl       → "let" pattern "=" expression ";" ;
  Statement letDeclaration() {
    final keyword = previous();
    final pat = pattern();
    consume(.equal, "Expected '=' before variable declaration.");
    final initializer = expression();
    consume(.semicolon, "Expected ';' after variable declaration.");
    return LetDeclaration(keyword, pat, initializer);
  }

  // statement      → printStmt
  //                | ifStmt
  //                | block
  //                | returnStmt
  //                | exprStmt
  Statement statement() {
    if (matchFirst(.if_)) return ifStatement();
    return expressionStatement();
  }

  // ifStmt         → "if" expression "then" statement
  //                ( "else" statement )?;
  Statement ifStatement() {
    final keyword = previous();
    final condition = expression();
    consume(.then, "Expected 'then' after if condition.");

    final List<Statement> thenBranch;
    final List<Statement> elseBranch;

    if (matchFirst(.openBrace)) {
      thenBranch = [ for (;!check(.closeBrace) && !isAtEnd();) declaration() ];
      consume(.closeBrace, "Expected '}'");
    } else {
      thenBranch = [ statement() ];
    }

    if (matchFirst(.else_)) {
      if (matchFirst(.openBrace)) {
        elseBranch = [ for (;!check(.closeBrace) && !isAtEnd();) declaration() ];
        consume(.closeBrace, "Expected '}'");
      } else {
        elseBranch = [ statement() ];
      }
    } else {
      elseBranch = [];
    }

    return IfStatement(keyword, condition, thenBranch, elseBranch);
  }

  Expr printExpr() {
    final keyword = previous();
    final value = expression();
    return Print(value, keyword);
  }

  Expr assertExpr() {
    var start = current;
    final keyword = previous();
    final value = expression();
    var end = current;
    final source = tokens.sublist(start, end).map((t) => t.lexeme).join();
    return Assertion(keyword, source, value);
  }

  Statement expressionStatement() {
    final value = expression();
    final semicolon = consume(.semicolon, "Expected ';' after value.");
    return ExpressionStatement(value, semicolon);
  }

  Pattern pattern() {
    if (matchFirst(.openBrace)) {
      return recordPattern();
    }
    else if (matchFirst(.dot)) {
      return tagPattern();
    } else {
      // if (matchFirst(.number, .string, .true_, .false_, .nil)) {
      //   return LiteralPattern(previous());
      // }
      if (matchFirst(.underscore)) {
        final discard = previous();
        final newName = '${discard.lexeme}${_discardCount++}';
        return Identifier(discard.replaceLexeme(newName));
      }
      final name = consume(.identifier, 'Expected variable name');
      return Identifier(name);
    }
  }

  Pattern recordPattern() {
    final openBrace = previous();
    final elements = <RecordDestructuringElement>[];
    var first = true;
    while (!check(.closeBrace) && !isAtEnd()) {
      if (first) {
        first = false;
      } else {
        consume(.comma, 'Expected comma between record field declarations.');
        if (check(.closeBrace)) break; // trailing comma
      }
      final fieldName = consume(.identifier, 'Expected variable name');
      if (matchFirst(.colon)) {
        elements.add(RecordDestructuringElement(fieldName, pattern()));
      } else {
        elements.add(RecordDestructuringElement(fieldName));
      }
    }
    final closeBrace = consume(.closeBrace, "Expected '}' after destructuring.");
    return RecordDestructure(
      openBrace: openBrace,
      elements: elements,
      closeBrace: closeBrace,
    );
  }

  Pattern tagPattern() {
    final tagName = consume(.identifier, "Expected tag name");
    final Pattern? payload;
    if (matchFirst(.openParen)) {
      payload = pattern();
      consume(.closeParen, "Expected close paren");
    } else {
      payload = null;
    }
    return TagPattern(tagName, payload);
  }

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
    return postfix();
  }

  Expr postfix() {
    final expr = or();
    if (matchFirst(.questionQuestion)) {
      final qq = previous();
      final fallback = expression();
      return TagCastOk(expr, qq, fallback);
    } else if (matchFirst(.bang)) {
      final bang = previous();
      final cast = TagCastOk(expr, bang, null);
      return chain(cast);
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

  // factor         → pipeline ( ( "/" | "*" ) pipeline )* ;
  Expr factor() {
    var expr = pipeline();
    while (matchFirst(
      .slash,
      .star,
    )) {
      final operator = previous();
      final right = pipeline();
      expr = Binary(expr, operator, right);
    }
    return expr;
  }

  // pipeline       → unary ( "|>" unary )* ;
  Expr pipeline() {
    var expr = unary();
    while (matchFirst(.pipeline)) {
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

      // Need to disambiguate between the opening brace of a record literal:
      //     { a: a + 1 }
      //     { a: 1 }
      //     { a: b }
      //     { a: a }
      //     { a }
      //     { }
      //     { ..a, b: 2}
      // or the opening brace of a block expression:
      //     { let a = 1; a + 1; }
      //     { a + 1; }
      //     { print 1; a; }
      //     { a; }
      //
      // Try to detect a record since records have a more constrained syntax.
      // If it's not a record then assume it's a block.
      final next2 = peekN(2).map((t) => t.type).toList();
      final isBeginningOfRecord = switch (next2) {
        [.identifier, .colon] => true,
        [.identifier, .comma] => true,
        [.identifier, .closeBrace] => true,
        [.closeBrace, _] => true,
        [.dotdot, _]=> true,
        _ => false,
      };
      if (isBeginningOfRecord) {
        return recordLiteral();
      } else {
        return blockExpression();
      }
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
    if (matchFirst(.assert_)) {
      return assertExpr();
    }
    if (matchFirst(.print)) {
      return printExpr();
    }

    if (matchFirst(.if_)) {
      final keyword = previous();
      final condition = expression();
      consume(.then, 'Expected "then"');
      final ifTrue = expression();
      consume(.else_, 'Expected "else"');
      final ifFalse = expression();
      return IfExpression(keyword, condition, ifTrue, ifFalse);
    }

    return call();
  }

  // call           → primary ( "(" arguments? ")" | "." IDENTIFIER )* ;
  // arguments      → argument ( "," argument )* ;
  // argument       → "_" | expression;
  Expr call() {
    final callee = primary();
    return chain(callee);
  }

  Expr chain(Expr expr) {
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
    final cases = <TagMatchCase>[];
    var first = true;
    do {
      if (!first) consume(.comma, 'Expected comma between match cases.');
      if (check(.closeBrace)) break;
      first = false;
      final pat = pattern();
      final arrow = consume(.arrow, "Expected arrow");
      final result = expression();
      cases.add((pattern: pat, arrow: arrow, result: result));
    } while (!check(.closeBrace) && !isAtEnd());
    final closeBrace = consume(.closeBrace, "Expected close brace");
    return TagMatch(keyword, tag, (openBrace, closeBrace), cases);
  }

  Expr import() {
    final keyword = previous();
    final path = consume(.string, 'Expected path to import from.');
    return Import(keyword: keyword, target: path);
  }

  // record         → "{" recordField ( "," recordField )* "}"
  // recordField    → (IDENTIFIER ":")? expression
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
        final value = matchFirst(.colon)
          ? expression()    // { foo: foo + 1 }
          : Variable(name); // { foo }
        fields[name] = value;
      }
    }
    final closingBrace = consume(.closeBrace, "Expected '}' after record literal.");
    if (update case (:final dotdot, :final record)?) {
      return RecordUpdate(dotdot, record, fields, closingBrace);
    }
    return Record(closingBrace, fields);
  }

  BlockExpr blockExpression() {
    final openBrace = previous();
    final statements = [
      for (;!check(.closeBrace) && !isAtEnd();)
        declaration()
    ];
    final closeBrace = consume(.closeBrace, "Expected '}' after block.");
    if (statements.isEmpty) {
      throwParseError(previous(), 'Block expressions must have at least 1 statement.');
    }
    return BlockExpr(openBrace, statements, closeBrace);
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
  // parameters      → pattern ( "," pattern )* ;
  Expr lambda() {
    final params = <Pattern>[];
    final hasArgs = () {
      if (check(.arrow)) return false;
      if (check(.openBrace)) {
        // Ambiguity:
        // This is either the opening brace of a 0-param block function:
        //     \ { a; };
        // Or the opening brace of a record pattern in the first parameter position:
        //     \{ a }, b -> a + b;
        // Need 2 tokens of lookahead to determine if its a record pattern.
        final lookahead = peekN(3).map((t) => t.type).toList();
        final isBeginningOfBlockBody = switch (lookahead) {
          [.openBrace, .identifier, .colon] => false,
          [.openBrace, .identifier, .comma] => false,
          [.openBrace, .identifier, .closeBrace] => false,
          _ => true,
        };
        return !isBeginningOfBlockBody;
      }
      return true;
    } ();
    if (hasArgs) {
      while (true) {
        if (check(.arrow)) break; // trailing comma
        params.add(pattern());
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
      final openBrace = consume(.openBrace, "Expected '{' before body.");
      final statements = [
        for (;!check(.closeBrace) && !isAtEnd();)
          declaration()
      ];
      final closeBrace = consume(.closeBrace, "Expected '}' after block.");
      body = FunctionBody(openBrace, statements, closeBrace);
    }

    return Lambda(params, body);
  }



  // primary        → NUMBER | STRING
  //                | "true" | "false" | "nil"
  //                | "(" expression ")"
  //                | IDENTIFIER
  //                ;
  Expr primary() {
    final expr = p();
    if (matchFirst(.bang)) {
      return TagCastOk(expr, previous(), null);
    }
    return expr;
  }

  Expr p() {
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
  @override
  String toString([String? path]) => 'At ${token.toString(path)}\n$message';
}
class MissingExpression extends ParserError {
  MissingExpression(Token token) : super(token, 'Expected expression.');
}