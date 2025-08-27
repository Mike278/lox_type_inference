
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
