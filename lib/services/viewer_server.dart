import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import 'capture_store.dart';
import 'connection_security.dart';

class ViewerServer extends ChangeNotifier {
  ViewerServer(this.store, {String? token})
    : accessToken = token ?? defaultViewerToken;
  String accessToken;
  bool redactSensitiveData = true;
  bool get limitCapture => store.limitCapture;
  set limitCapture(bool value) {
    store.limitCapture = value;
    _notify();
  }

  SecurityContext? tlsContext;
  String bindAddress = '127.0.0.1';
  String lanCidr = '';
  LanSubnet? _subnet;
  int _generation = 0;
  int _upgrading = 0;
  static const maxConnections = 8;
  static const maxMessageBytes = 1024 * 1024;
  static const maxMessagesPerSecond = 30;
  static const maxBytesPerSecond = 4 * 1024 * 1024;
  bool get lanEnabled => bindAddress != '127.0.0.1';
  Map<String, String> get connectionHeaders => {
    'Authorization': 'Bearer $accessToken',
  };
  String get setupCode =>
      "if (__DEV__) {\n  const {bootRNNetworkDebugger} = require('@quocandev27/rn_network_debugger');\n  bootRNNetworkDebugger({\n    VIEWER_URL: '$localUrl',\n    VIEWER_TOKEN: '$accessToken',\n    REDACT_SENSITIVE_DATA: $redactSensitiveData,\n    LIMIT_CAPTURE: $limitCapture,\n  });\n}";
  final CaptureStore store;
  HttpServer? _server;
  final _clients = <WebSocket, String?>{};
  bool _disposed = false;
  bool busy = false;
  int port = 38940;
  String? error;
  String? lastProtocolError;
  int invalidMessages = 0;
  List<String> addresses = ['127.0.0.1'];
  bool get running => _server != null;
  int get connections => _clients.length;
  bool isOnline(String sessionId) => _clients.values.contains(sessionId);
  String get scheme => tlsContext == null ? 'ws' : 'wss';
  String get localUrl => '$scheme://$bindAddress:$port/rnv/network';

  Future<void> start({int port = 38940}) async {
    if (busy || running || _disposed) return;
    if (port < 0 || port > 65535) {
      error = 'Port must be between 1 and 65535.';
      notifyListeners();
      return;
    }
    final generation = ++_generation;
    busy = true;
    error = null;
    notifyListeners();
    try {
      if (!validAccessToken(accessToken)) {
        throw const FormatException('Invalid pairing token.');
      }
      final host = InternetAddress.tryParse(bindAddress);
      _subnet = lanEnabled ? LanSubnet(lanCidr) : null;
      if (host == null || (lanEnabled && !_subnet!.contains(host))) {
        throw const FormatException(
          'LAN address must belong to the selected private subnet.',
        );
      }
      if (lanEnabled) {
        final interfaces = await NetworkInterface.list(
          type: InternetAddressType.IPv4,
        );
        if (!interfaces.any(
          (i) => i.addresses.any((a) => a.address == bindAddress),
        )) {
          throw const FormatException(
            'Select an IPv4 address assigned to this computer.',
          );
        }
      }
      final server = tlsContext == null
          ? await HttpServer.bind(host, port, shared: false)
          : await HttpServer.bindSecure(host, port, tlsContext!, shared: false);
      if (_disposed || generation != _generation) {
        await server.close(force: true);
        return;
      }
      _server = server;
      this.port = server.port;
      server.listen(
        (request) => unawaited(_accept(request)),
        onError: (Object e) {
          error = '$e';
          _notify();
        },
      );
      addresses = [bindAddress];
    } on SocketException catch (e) {
      error = 'Cannot listen on port $port. ${e.osError?.message ?? e.message}';
    } on FormatException catch (e) {
      error = e.message;
    } finally {
      busy = false;
      _notify();
    }
  }

  Future<void> _accept(HttpRequest request) async {
    var reserved = false;
    final generation = _generation;
    try {
      final remote = request.connectionInfo?.remoteAddress;
      final host = request.headers.host;
      if (remote == null ||
          (lanEnabled ? !_subnet!.contains(remote) : !remote.isLoopback) ||
          ![
            bindAddress,
            if (!lanEnabled) ...['localhost', '10.0.2.2'],
          ].contains(host) ||
          request.headers.value('origin') != null) {
        request.response.statusCode = HttpStatus.forbidden;
        await request.response.close();
        return;
      }
      if (!matchesBearer(request.headers.value('authorization'), accessToken)) {
        request.response.statusCode = HttpStatus.unauthorized;
        request.response.headers.set('www-authenticate', 'Bearer');
        await request.response.close();
        return;
      }
      if (request.uri.path != '/rnv/network') {
        request.response.statusCode = HttpStatus.notFound;
        await request.response.close();
        return;
      }
      if (!WebSocketTransformer.isUpgradeRequest(request)) {
        request.response.statusCode = HttpStatus.upgradeRequired;
        request.response.write('Connect the React Native SDK using WebSocket.');
        await request.response.close();
        return;
      }
      if (_clients.length + _upgrading >= maxConnections) {
        request.response.statusCode = HttpStatus.serviceUnavailable;
        await request.response.close();
        return;
      }
      _upgrading++;
      reserved = true;
      // Android's OkHttp client rejects Dart's permessage-deflate parameters.
      final socket = await WebSocketTransformer.upgrade(
        request,
        compression: CompressionOptions.compressionOff,
      );
      if (!running || _disposed || generation != _generation) {
        await socket.close(WebSocketStatus.goingAway);
        return;
      }
      socket.pingInterval = const Duration(seconds: 20);
      _clients[socket] = null;
      _notify();
      var window = DateTime.now();
      var messages = 0;
      var bytes = 0;
      var rejected = 0;
      var closing = false;
      socket.listen(
        (dynamic data) {
          if (closing) return;
          try {
            final now = DateTime.now();
            if (now.difference(window) >= const Duration(seconds: 1)) {
              window = now;
              messages = 0;
              bytes = 0;
            }
            messages++;
            final size = data is String
                ? utf8.encode(data).length
                : maxMessageBytes + 1;
            bytes += size;
            if (limitCapture &&
                (messages > maxMessagesPerSecond ||
                    bytes > maxBytesPerSecond ||
                    size > maxMessageBytes)) {
              closing = true;
              unawaited(
                socket.close(
                  WebSocketStatus.policyViolation,
                  'Capture limit exceeded',
                ),
              );
              return;
            }
            // Reject oversized assembled messages before JSON decoding.
            if (data is! String ||
                (limitCapture && data.length > maxMessageBytes)) {
              throw const FormatException(
                'Expected a text JSON frame up to 1 MiB.',
              );
            }
            final payload = jsonDecode(data);
            if (payload is! Map ||
                payload['events'] is! List ||
                (limitCapture && (payload['events'] as List).length > 100)) {
              throw const FormatException(
                'Expected up to 100 events per envelope.',
              );
            }
            if (limitCapture) _validateStructure(payload);
            final session = payload['session'];
            final incomingId = session is Map ? session['id'] : null;
            if (_clients[socket] != null && _clients[socket] != incomingId) {
              closing = true;
              unawaited(socket.close(WebSocketStatus.policyViolation));
              return;
            }
            _clients[socket] = store.ingest(payload);
            _notify();
          } on FormatException catch (e) {
            invalidMessages++;
            lastProtocolError = e.message;
            if (++rejected >= 3) {
              closing = true;
              unawaited(
                socket.close(
                  WebSocketStatus.policyViolation,
                  'Invalid capture payload',
                ),
              );
            }
            _notify();
          }
        },
        onDone: () {
          _clients.remove(socket);
          _notify();
        },
        onError: (Object e) {
          _clients.remove(socket);
          _notify();
        },
        cancelOnError: true,
      );
    } catch (e) {
      try {
        request.response.statusCode = HttpStatus.badRequest;
        await request.response.close();
      } catch (_) {
        // The response may already have upgraded to WebSocket.
      }
      lastProtocolError = 'Connection rejected.';
      _notify();
    } finally {
      if (reserved) _upgrading--;
    }
  }

  void _validateStructure(Map payload) {
    final metadata = payload['session'];
    if (metadata is! Map ||
        metadata['id'] is! String ||
        (metadata['id'] as String).length > 128 ||
        utf8.encode(jsonEncode(metadata)).length > 16384 ||
        utf8.encode(jsonEncode(payload['sdk'])).length > 4096) {
      throw const FormatException('Invalid or oversized session metadata.');
    }
    final pending = <(dynamic, int)>[(payload, 0)];
    var nodes = 0;
    while (pending.isNotEmpty) {
      final (value, depth) = pending.removeLast();
      if (++nodes > 20000 || depth > 32) {
        throw const FormatException('Capture structure limit exceeded.');
      }
      if (value is Map) {
        pending.addAll(value.values.map((v) => (v, depth + 1)));
      } else if (value is List) {
        pending.addAll(value.map((v) => (v, depth + 1)));
      }
    }
  }

  Future<void> stop() async {
    _generation++;
    final server = _server;
    _server = null;
    final clients = _clients.keys.toList();
    _clients.clear();
    await Future.wait(clients.map((s) => s.close(WebSocketStatus.goingAway)));
    await server?.close(force: true);
    _notify();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    unawaited(stop());
    super.dispose();
  }
}
