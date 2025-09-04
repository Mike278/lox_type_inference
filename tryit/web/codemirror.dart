
@JS()
library;

import 'dart:js_interop';

import 'package:web/web.dart';

@JS('cm.basicSetup')
external JSObject get basicSetup;

@JS('oneDark')
external JSObject get oneDark;

@JS('cmView.hoverTooltip')
external JSObject hoverTooltip(JSFunction callback, [JSObject? options]);

@JS('lint.linter')
external JSObject linter(JSFunction callback, [JSObject? options]);

@JS('lint.lintGutter')
external JSObject lintGutter();

@JS('commands.indentWithTab')
external JSObject get indentWithTab;

@JS('cmView.keymap')
external KeyMap get keymap;

@JS('cm.EditorView')
extension type EditorView._(JSObject o) implements JSObject {
  external EditorView(EditorViewConfig config);
  external EditorState get state;
  external void dispatch(TransactionSpec spec);
  external static ViewUpdateFacet updateListener;

  static JSAny createUpdateListener(void Function(String) onChange) =>
    EditorView.updateListener.of((ViewUpdate update) {
      if (update.docChanged) onChange(update.view.state.doc.value);
    }.toJS);

  void replaceContent(String newContent) {
    dispatch(TransactionSpec(
      changes: ChangeSpec(
        from: 0,
        to: state.doc.value.length,
        insert: newContent,
      ),
    ));
  }
}

extension type ViewUpdateFacet._(JSObject o) implements JSObject {
  external JSAny of(JSAny value);
}

extension type KeyMap._(JSObject o) implements JSObject {
  external JSAny of(JSAny value);
}

extension type ViewUpdate._(JSObject o) implements JSObject {
  external EditorView get view;
  external bool get docChanged;
}

extension type EditorViewConfig._(JSObject o) implements JSObject {
  external factory EditorViewConfig({
    JSArray<JSAny> extensions,
    String doc,
    HTMLElement parent,
  });
}

extension type EditorState._(JSObject o) implements JSObject {
  external Text get doc;
}

extension type Text._(JSObject o) implements JSObject {
  String get value => o.toString();
  external Line lineAt(JSNumber pos);
}

extension type Line._(JSObject o) implements JSObject {
  external int get from;
  external int get to;
  external int get number;
  external String get text;
  external int get length;
}

extension type TransactionSpec._(JSObject o) implements JSObject {
  external factory TransactionSpec({ChangeSpec changes});
}

extension type ChangeSpec._(JSObject o) implements JSObject {
  external factory ChangeSpec({int from, int to, String insert});
}

extension type HoverTooltipOptions._(JSObject o) implements JSObject {
  external factory HoverTooltipOptions({int hoverTime});
}

extension type Tooltip._(JSObject o) implements JSObject {
  external factory Tooltip({
    JSNumber pos,
    JSFunction create,
  });

  static Tooltip create({
    required JSNumber start,
    required HTMLElement Function(EditorView) build,
  }) => Tooltip(
    pos: start,
    create: (JSObject? view) {
      final element = build(view as EditorView);
      return TooltipView(dom: element);
    }.toJS,
  );
}

extension type TooltipView._(JSObject o) {
  external factory TooltipView({
    HTMLElement dom,
  });
}

@JS('RegExp')
extension type JSRegExp._(JSObject _) implements JSObject {
  external JSRegExp(String pattern, [String flags]);
}

extension RegExpToJS on RegExp {
  JSAny get toJS {
    final flags = [
      if (!isCaseSensitive) 'i',
      if (isMultiLine) 'm',
      if (isDotAll) 's',
      if (isUnicode) 'u',
    ].join('');
    return JSRegExp(pattern, flags);
  }
}


@JS('language.StreamLanguage.define')
external Language streamLanguageDefine(StreamParser parser);

extension type StreamParser._(JSObject o) implements JSObject {
  external factory StreamParser({
    String? name,
    JSFunction? startState,
    JSFunction? token,
    JSFunction? blankLine,
    JSFunction? copyState,
    JSFunction? indent,
    JSAny? languageData,
  });

  static StreamParser create({
    required String? name,
    required JSAny Function()? startState,
    required String? Function(StringStream, JSAny) token,
    required void Function(JSAny)? blankLine,
    required JSAny Function(JSAny)? copyState,
    required int Function(JSAny, String, JSObject)? indent,
    required Map<String, JSAny>? languageData,
  }) {
    return StreamParser(
      name: name,
      token: token.toJS,
      blankLine: blankLine?.toJS,
      startState: startState?.toJS,
      copyState: copyState?.toJS,
      indent: indent?.toJS,
      languageData: languageData?.jsify(),
    );
  }
}

extension type StringStream._(JSObject o) implements JSObject {
  external int get pos;
  external int get start;
  external String get string;
  external int get indentUnit;
  external bool eol();
  external bool sol();
  external String? peek();
  external String? next();
  external String? eat(JSAny match);
  external bool eatWhile(JSAny match);
  external bool eatSpace();
  external void skipToEnd();
  external bool? skipTo(String ch);
  external void backUp(int n);
  external int column();
  external int indentation();
  external JSAny? match(JSAny pattern, [bool? consume, bool? caseInsensitive]);
  external String current();
}

extension type Language._(JSObject o) implements JSObject {
  external String get name;
}

extension type Diagnostic._(JSObject o) implements JSObject {
  external factory Diagnostic({
    required int from,
    required int to,
    required String severity, // "error" | "hint" | "info" | "warning"
    String? markClass,
    String? source,
    required String message,
  });
}
