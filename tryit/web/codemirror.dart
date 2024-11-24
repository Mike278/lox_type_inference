
@JS()
library;

import 'dart:js_interop';

import 'package:web/web.dart';

extension type CodeMirror._(JSObject _) implements JSObject {
  external static void defineSimpleMode(String mode, JSAny? options);
  external factory CodeMirror(Element element, JSAny? codeMirrorOptions);
  external Doc getDoc();
  external void setSize(String x, String y);
  external void on(String event, JSFunction callback);
}


extension type Doc._(JSObject _) implements JSObject {
  external void setValue(String value);
  external String getValue();
  external TextMarker markText(Position from, Position to, MarkTextOptions options);
}


@anonymous
extension type Position._(JSObject _) implements JSObject {
  external int line;
  external int ch;

  external factory Position({required int line, required int ch});
}

extension type TextMarker._(JSObject _) implements JSObject {
  external void clear();
}

@anonymous
extension type MarkTextOptions._(JSObject _) implements JSObject {
  external String className;
  external String? title;
  external JSAny? attributes;

  external factory MarkTextOptions({
    required String className,
    String? title,
    JSAny? attributes,
  });
}
