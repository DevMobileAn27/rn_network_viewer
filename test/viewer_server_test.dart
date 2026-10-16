import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:rn_network_viewer/services/capture_store.dart';
import 'package:rn_network_viewer/services/viewer_server.dart';

Future<void> until(bool Function() predicate) async {
  final deadline = DateTime.now().add(const Duration(seconds: 5));
  while (!predicate()) {
    if (DateTime.now().isAfter(deadline)) {
      throw TimeoutException('State did not arrive');
    }
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
}

void main() {
  test('Android WebSocket handshake does not negotiate compression', () async {
    final store = CaptureStore();
    final server = ViewerServer(store);
    await server.start(port: 0);
    final socket = await Socket.connect('127.0.0.1', server.port);
    addTearDown(() async {
      socket.destroy();
      await server.stop();
      server.dispose();
      store.dispose();
    });
    final headers = socket
        .cast<List<int>>()
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .takeWhile((line) => line.isNotEmpty)
        .toList();
    socket.write(
      'GET /rnv/network HTTP/1.1\r\n'
      'Host: 127.0.0.1:${server.port}\r\n'
      'Authorization: Bearer ${server.accessToken}\r\n'
      'Connection: Upgrade\r\n'
      'Upgrade: websocket\r\n'
      'Sec-WebSocket-Version: 13\r\n'
      'Sec-WebSocket-Key: dGhlIHNhbXBsZSBub25jZQ==\r\n'
      'Sec-WebSocket-Extensions: permessage-deflate\r\n\r\n',
    );
    final response = (await headers.timeout(
      const Duration(seconds: 5),
    )).join('\n').toLowerCase();
    expect(response, startsWith('http/1.1 101'));
    expect(response, isNot(contains('sec-websocket-extensions:')));
  });

  test(
    'real WebSocket receives SDK JSON, survives bad messages and reconnects',
    () async {
      final store = CaptureStore();
      final server = ViewerServer(store);
      addTearDown(() async {
        await server.stop();
        server.dispose();
        store.dispose();
      });
      await server.start(port: 0);
      expect(server.running, isTrue);
      final socket = await WebSocket.connect(
        server.localUrl,
        headers: server.connectionHeaders,
      );
      final fixture = File(
        'test/fixtures/sdk_envelope.json',
      ).readAsStringSync();
      socket.add('broken json');
      socket.add(
        jsonEncode({
          'sdk': {'schemaVersion': 999},
          'session': {'id': 'bad'},
          'events': [],
        }),
      );
      socket.add(fixture);
      await until(() => store.network.length == 3);
      expect(server.invalidMessages, 2);
      expect(server.isOnline('ios-session-1'), isTrue);
      expect(server.connections, 1);
      await socket.close();
      await until(() => server.connections == 0);
      expect(store.network.length, 3);
      final reconnected = await WebSocket.connect(
        server.localUrl,
        headers: server.connectionHeaders,
      );
      reconnected.add(fixture);
      await until(() => server.isOnline('ios-session-1'));
      expect(store.network.length, 3);
      await reconnected.close();
    },
  );

  test(
    'HTTP paths and non-upgrade requests have explicit status codes',
    () async {
      final store = CaptureStore();
      final server = ViewerServer(store);
      final client = HttpClient();
      addTearDown(() async {
        client.close(force: true);
        await server.stop();
        server.dispose();
        store.dispose();
      });
      await server.start(port: 0);
      for (final pair in [('/', 404), ('/rnv/network', 426)]) {
        final request = await client.getUrl(
          Uri.parse('http://127.0.0.1:${server.port}${pair.$1}'),
        );
        server.connectionHeaders.forEach(request.headers.set);
        final response = await request.close();
        expect(response.statusCode, pair.$2);
        await response.drain<void>();
      }
    },
  );

  test(
    'port conflict surfaces a useful error and server can restart',
    () async {
      final store = CaptureStore();
      final server = ViewerServer(store);
      final occupied = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() async {
        await occupied.close();
        await server.stop();
        server.dispose();
        store.dispose();
      });
      await server.start(port: occupied.port);
      expect(server.running, isFalse);
      expect(server.error, contains('Cannot listen'));
      await server.start(port: 0);
      expect(server.running, isTrue);
      expect(server.error, isNull);
      final port = server.port;
      await server.stop();
      await server.start(port: port);
      expect(server.running, isTrue);
    },
  );
}
