
@JS()
library;

import 'dart:js_interop';

import 'package:web/web.dart';

extension type CodeMirror._(JSObject _) implements JSObject {
  external static void defineSimpleMode(String mode, JSAny? options);
  external factory CodeMirror(Element element, JSAny? codeMirrorOptions);
  external Doc getDoc();
  external void setSize(String x, String y);
}


extension type Doc._(JSObject _) implements JSObject {
  external void setValue(String value);
  external String getValue();
}
