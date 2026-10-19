import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:rn_network_viewer/services/connection_security.dart';
import 'package:rn_network_viewer/services/capture_store.dart';
import 'package:rn_network_viewer/services/viewer_server.dart';
import 'package:rn_network_viewer/services/viewer_mcp_server.dart';
import 'viewer_server_test.dart' show until;

void main() {
  test(
    'capture default matches the SDK and custom tokens remain separate from MCP',
    () {
      expect(defaultViewerToken, 'rnv_default_pairing_token_for_local_dev_001');
      expect(validAccessToken(defaultViewerToken), isTrue);
      final store = CaptureStore();
      final server = ViewerServer(store);
      final mcp = ViewerMcpServer(store, server);
      final custom = ViewerServer(store, token: 'c' * 43);
      expect(server.accessToken, defaultViewerToken);
      expect(custom.accessToken, 'c' * 43);
      expect(mcp.accessToken, isNot(defaultViewerToken));
      mcp.dispose();
      custom.dispose();
      server.dispose();
      store.dispose();
    },
  );

  test(
    'WSS validates certificate trust and still requires pairing',
    () async {
      final dir = await Directory.systemTemp.createTemp('rnv-tls-test-');
      final store = CaptureStore();
      final server = ViewerServer(store);
      addTearDown(() async {
        await server.stop();
        server.dispose();
        store.dispose();
        await dir.delete(recursive: true);
      });
      final cert = '${dir.path}/cert.pem';
      final key = '${dir.path}/key.pem';
      final config = File('${dir.path}/openssl.cnf');
      await config.writeAsString(
        '[req]\ndistinguished_name=dn\nx509_extensions=ext\nprompt=no\n[dn]\nCN=127.0.0.1\n[ext]\nsubjectAltName=IP:127.0.0.1\nbasicConstraints=critical,CA:TRUE\nkeyUsage=digitalSignature,keyEncipherment,keyCertSign\nextendedKeyUsage=serverAuth\n',
      );
      final generated = await Process.run('openssl', [
        'req',
        '-x509',
        '-newkey',
        'rsa:2048',
        '-sha256',
        '-nodes',
        '-days',
        '1',
        '-keyout',
        key,
        '-out',
        cert,
        '-config',
        config.path,
      ]);
      expect(generated.exitCode, 0, reason: '${generated.stderr}');
      server.tlsContext = SecurityContext()
        ..useCertificateChain(cert)
        ..usePrivateKey(key);
      await server.start(port: 0);
      expect(server.localUrl, startsWith('wss://'));
      expect(server.setupCode, contains(server.localUrl));
      await expectLater(
        WebSocket.connect(server.localUrl, headers: server.connectionHeaders),
        throwsA(isA<HandshakeException>()),
      );
      final client = HttpClient(
        context: SecurityContext()..setTrustedCertificates(cert),
      );
      addTearDown(() => client.close(force: true));
      final socket = await WebSocket.connect(
        server.localUrl,
        headers: server.connectionHeaders,
        customClient: client,
      );
      socket.listen((_) {});
      await socket.close();
    },
    skip: Platform.isWindows
        ? 'Requires openssl available on macOS/Linux CI'
        : false,
  );

  test('tokens and explicit subnets fail closed', () {
    final token = createAccessToken();
    expect(validAccessToken(token), isTrue);
    expect(createAccessToken(), isNot(token));
    expect(matchesBearer('Bearer $token', token), isTrue);
    expect(matchesBearer('Bearer wrong', token), isFalse);
    expect(matchesBearer(null, token), isFalse);
    for (final value in [
      '0.0.0.0/0',
      '192.168.1.0/8',
      '172.0.0.0/8',
      '8.8.8.8/32',
      '::1/128',
      '192.168.1.1',
      '10.0.0.1/33',
    ]) {
      expect(() => LanSubnet(value), throwsFormatException);
    }
    final subnet = LanSubnet('192.168.10.0/24');
    expect(subnet.contains(InternetAddress('192.168.10.12')), isTrue);
    for (final ip in ['192.168.11.12', '8.8.8.8', '127.0.0.1', '::1']) {
      expect(subnet.contains(InternetAddress(ip)), isFalse);
    }
  });

  test('capture rejects unpaired clients, origins and foreign hosts', () async {
    final store = CaptureStore();
    final server = ViewerServer(store);
    final client = HttpClient();
    addTearDown(() async {
      client.close(force: true);
      await server.stop();
      server.dispose();
      store.dispose();
    });
    expect(server.bindAddress, '127.0.0.1');
    await server.start(port: 0);
    for (final scenario in [
      (<String, String>{}, 401),
      ({'Authorization': 'Bearer wrong'}, 401),
      ({...server.connectionHeaders, 'Origin': 'http://localhost'}, 403),
      ({...server.connectionHeaders, 'Host': 'attacker.example'}, 403),
      (server.connectionHeaders, 426),
      ({...server.connectionHeaders, 'Host': '10.0.2.2'}, 426),
    ]) {
      final request = await client.getUrl(
        Uri.parse('http://127.0.0.1:${server.port}/rnv/network'),
      );
      scenario.$1.forEach(request.headers.set);
      final response = await request.close();
      expect(response.statusCode, scenario.$2);
      await response.drain<void>();
    }
    expect(store.sessions, isEmpty);
  });

  test(
    'session switching rejected before ingestion and rotation revokes access',
    () async {
      final store = CaptureStore();
      final server = ViewerServer(store);
      addTearDown(() async {
        await server.stop();
        server.dispose();
        store.dispose();
      });
      await server.start(port: 0);
      final oldHeaders = server.connectionHeaders;
      final socket = await WebSocket.connect(
        server.localUrl,
        headers: oldHeaders,
      );
      final done = socket.drain<void>();
      final fixture =
          jsonDecode(File('test/fixtures/sdk_envelope.json').readAsStringSync())
              as Map;
      socket.add(jsonEncode(fixture));
      await until(() => store.sessions.isNotEmpty);
      fixture['session']['id'] = 'impostor';
      socket.add(jsonEncode(fixture));
      await done.timeout(const Duration(seconds: 5));
      expect(store.sessions.containsKey('impostor'), isFalse);
      final active = await WebSocket.connect(
        server.localUrl,
        headers: oldHeaders,
      );
      final activeDone = active.drain<void>();
      final port = server.port;
      await server.stop();
      await activeDone;
      server.accessToken = createAccessToken();
      await server.start(port: port);
      await expectLater(
        WebSocket.connect(server.localUrl, headers: oldHeaders),
        throwsA(isA<WebSocketException>()),
      );
      final paired = await WebSocket.connect(
        server.localUrl,
        headers: server.connectionHeaders,
      );
      paired.listen((_) {});
      await paired.close();
    },
  );

  test('capture bounds connections, messages and malformed payloads', () async {
    final store = CaptureStore();
    final server = ViewerServer(store);
    final sockets = <WebSocket>[];
    addTearDown(() async {
      for (final s in sockets) {
        await s.close();
      }
      await server.stop();
      server.dispose();
      store.dispose();
    });
    await server.start(port: 0);
    for (var i = 0; i < ViewerServer.maxConnections; i++) {
      final socket = await WebSocket.connect(
        server.localUrl,
        headers: server.connectionHeaders,
      );
      socket.listen((_) {});
      sockets.add(socket);
    }
    await expectLater(
      WebSocket.connect(server.localUrl, headers: server.connectionHeaders),
      throwsA(isA<WebSocketException>()),
    );
    for (final s in sockets) {
      await s.close();
    }
    await until(() => server.connections == 0);
    for (final messages in [
      List.filled(3, 'invalid'),
      ['x' * (ViewerServer.maxMessageBytes + 1)],
      List.filled(
        31,
        jsonEncode({
          'sdk': {'schemaVersion': 1},
          'session': {'id': 'flood'},
          'events': [],
        }),
      ),
    ]) {
      final socket = await WebSocket.connect(
        server.localUrl,
        headers: server.connectionHeaders,
      );
      final done = socket.drain<void>();
      messages.forEach(socket.add);
      await done.timeout(const Duration(seconds: 5));
      expect(socket.closeCode, WebSocketStatus.policyViolation);
    }
  });

  test(
    'LAN binds only an assigned private address and rejects loopback sources',
    () async {
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
      );
      final addresses = interfaces
          .expand((i) => i.addresses)
          .where(privateIPv4);
      if (addresses.isEmpty) {
        markTestSkipped('No private IPv4 interface available on this host');
        return;
      }
      final address = addresses.first;
      final store = CaptureStore();
      final server = ViewerServer(store)
        ..bindAddress = address.address
        ..lanCidr = '${address.address}/32';
      addTearDown(() async {
        await server.stop();
        server.dispose();
        store.dispose();
      });
      await server.start(port: 0);
      expect(server.running, isTrue, reason: server.error);
      final socket = await WebSocket.connect(
        server.localUrl,
        headers: server.connectionHeaders,
      );
      socket.listen((_) {});
      await socket.close();
      final denied = await Socket.connect(
        address,
        server.port,
        sourceAddress: InternetAddress.loopbackIPv4,
      );
      addTearDown(denied.destroy);
      final response = denied
          .cast<List<int>>()
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .first;
      denied.write(
        'GET /rnv/network HTTP/1.1\r\nHost: ${address.address}:${server.port}\r\nAuthorization: Bearer ${server.accessToken}\r\nConnection: close\r\n\r\n',
      );
      expect(
        await response.timeout(const Duration(seconds: 5)),
        contains('403'),
      );
    },
    skip: Platform.isWindows
        ? 'Source-address routing differs on Windows'
        : false,
  );

  test('public bind and invalid LAN configuration never start', () async {
    final store = CaptureStore();
    final server = ViewerServer(store);
    addTearDown(() {
      server.dispose();
      store.dispose();
    });
    for (final host in ['0.0.0.0', '8.8.8.8', '::', '192.168.3.4']) {
      server.bindAddress = host;
      server.lanCidr = '192.168.1.0/24';
      await server.start(port: 0);
      expect(server.running, isFalse);
      expect(server.error, isNotNull);
    }
  });

  test(
    'MCP rejects missing/wrong/capture tokens and rotates separately',
    () async {
      final store = CaptureStore();
      final viewer = ViewerServer(store);
      final mcp = ViewerMcpServer(store, viewer);
      final client = HttpClient();
      addTearDown(() async {
        client.close(force: true);
        await mcp.stop();
        mcp.dispose();
        viewer.dispose();
        store.dispose();
      });
      expect(mcp.running, isFalse);
      await mcp.configure(enabled: true, port: 0);
      final previous = mcp.accessToken;
      for (final token in [null, 'wrong', viewer.accessToken, previous]) {
        final request = await client.postUrl(Uri.parse(mcp.endpoint));
        if (token != null) {
          request.headers.set('Authorization', 'Bearer $token');
        }
        request.headers.contentType = ContentType.json;
        request.headers.set('Accept', 'application/json, text/event-stream');
        request.write('{}');
        final response = await request.close();
        expect(response.statusCode, token == previous ? 400 : 403);
        await response.drain<void>();
      }
      mcp.accessToken = createAccessToken();
      await mcp.configure(enabled: true, port: mcp.port, restart: true);
      final request = await client.getUrl(Uri.parse(mcp.endpoint));
      request.headers.set('Authorization', 'Bearer $previous');
      final response = await request.close();
      expect(response.statusCode, 403);
      await response.drain<void>();
    },
  );
}
