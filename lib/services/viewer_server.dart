import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import 'capture_store.dart';

class ViewerServer extends ChangeNotifier {
  ViewerServer(this.store);
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
  String get localUrl => 'ws://127.0.0.1:$port/rnv/network';

  Future<void> start({int port = 38940}) async {
    if (busy || running || _disposed) return;
    if (port < 0 || port > 65535) {
      error = 'Port must be between 1 and 65535.';
      notifyListeners();
      return;
    }
    busy = true;
    error = null;
    notifyListeners();
    try {
      final server = await HttpServer.bind(
        InternetAddress.anyIPv4,
        port,
        shared: false,
      );
      if (_disposed) {
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
      try {
        final interfaces = await NetworkInterface.list(
          type: InternetAddressType.IPv4,
        );
        addresses = {
          '127.0.0.1',
          ...interfaces.expand((i) => i.addresses.map((a) => a.address)),
        }.toList();
      } on SocketException {
        // Loopback still works when interface discovery is unavailable.
      }
    } on SocketException catch (e) {
      error = 'Cannot listen on port $port. ${e.osError?.message ?? e.message}';
    } finally {
      busy = false;
      _notify();
    }
  }

  Future<void> _accept(HttpRequest request) async {
    try {
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
      // Android's OkHttp client rejects Dart's permessage-deflate parameters.
      final socket = await WebSocketTransformer.upgrade(
        request,
        compression: CompressionOptions.compressionOff,
      );
      if (!running || _disposed) {
        await socket.close(WebSocketStatus.goingAway);
        return;
      }
      socket.pingInterval = const Duration(seconds: 20);
      _clients[socket] = null;
      _notify();
      socket.listen(
        (dynamic data) {
          try {
            // SDK sends UTF-8 text. Reject excessive frames before JSON decoding.
            if (data is! String || data.length > 16 * 1024 * 1024) {
              throw const FormatException(
                'Expected a text JSON frame up to 16 MiB.',
              );
            }
            final id = store.ingest(jsonDecode(data));
            _clients[socket] = id;
            _notify();
          } on FormatException catch (e) {
            invalidMessages++;
            lastProtocolError = e.message;
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
      lastProtocolError = 'Connection failed: $e';
      _notify();
    }
  }

  Future<void> stop() async {
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
