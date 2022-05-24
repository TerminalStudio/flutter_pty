import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_pty/flutter_pty.dart';
import 'package:flutter_test/flutter_test.dart';

String get shell {
  if (Platform.isWindows) {
    return 'cmd.exe';
  }

  if (Platform.isLinux || Platform.isMacOS) {
    return 'bash';
  }

  return 'sh';
}

extension StringToUtf8 on String {
  Uint8List toUtf8() {
    return Uint8List.fromList(
      utf8.encode(this),
    );
  }
}

void main() {
  test('Pty works', () async {
    final pty = Pty.start(shell);
    final input = 'random input'.toUtf8();
    pty.write(input);
    expect(await pty.output.first, input);
  });
}
