import 'dart:async';
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

class OutputCollector {
  final Pty pty;

  OutputCollector(this.pty) {
    subscription = pty.output
        .cast<List<int>>()
        .transform(const Utf8Decoder())
        .listen(buffer.write);
  }

  final StringBuffer buffer = StringBuffer();

  late StreamSubscription subscription;

  String get output => buffer.toString();

  late final done = subscription.asFuture();
}

void main() {
  test('Pty works', () async {
    final pty = Pty.start(shell);
    pty.write('random input'.toUtf8());

    expect(await pty.output.first, isNotEmpty);

    pty.kill();
  });

  test('Pty.kill works', () async {
    final pty = Pty.start(shell);
    pty.write('random input'.toUtf8());

    pty.kill();
    expect(await pty.exitCode, isNotNull);
  });

  test('Pty.start can set working directory', () async {
    final tempDir = await Directory.systemTemp.createTemp('flutter_pty_test');

    final pty = Pty.start(shell, workingDirectory: tempDir.path);

    if (Platform.isWindows) {
      pty.write('cd\n'.toUtf8());
    } else {
      pty.write('pwd\n'.toUtf8());
    }

    pty.write('exit\n'.toUtf8());

    final collector = OutputCollector(pty);
    await collector.done;

    expect(collector.output, contains(tempDir.path));
  });

  test('Pty.start can set environment variables', () async {
    final pty = Pty.start(shell, environment: {'TEST_ENV': 'test'});
    pty.write('echo \$TEST_ENV\n'.toUtf8());
    pty.write('exit\n'.toUtf8());

    final collector = OutputCollector(pty);
    await collector.done;

    expect(collector.output, contains('test'));
  });

  test('Pty.start can set ack read mode', () async {
    final pty = Pty.start(shell, ackRead: true);

    final collector = OutputCollector(pty);
    await Future.delayed(const Duration(milliseconds: 100));

    pty.write('echo some text\n'.toUtf8());
    await Future.delayed(const Duration(milliseconds: 100));
    expect(collector.output.contains('some text'), isFalse);

    pty.ackRead();
    await Future.delayed(const Duration(milliseconds: 100));
    expect(collector.output.contains('some text'), isTrue);

    pty.kill();
  });
}
