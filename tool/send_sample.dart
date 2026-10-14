import 'dart:convert';
import 'dart:io';

/// Explicit sample sender; no sample data is injected by the production app.
/// Run from the project root: dart run tool/send_sample.dart [port] [holdSeconds]
Future<void> main(List<String> arguments) async {
  final port = arguments.isEmpty ? 38940 : int.parse(arguments[0]);
  final hold = arguments.length < 2 ? 30 : int.parse(arguments[1]);
  final socket = await WebSocket.connect('ws://127.0.0.1:$port/rnv/network');
  final fixture =
      jsonDecode(await File('test/fixtures/sdk_envelope.json').readAsString())
          as Map<String, dynamic>;
  socket.add(jsonEncode(fixture));
  final android = jsonDecode(jsonEncode(fixture)) as Map<String, dynamic>;
  android['session'].addAll({
    'id': 'android-sample',
    'platform': 'android',
    'appName': 'Example Android',
    'deviceName': 'Pixel Emulator',
    'systemName': 'Android',
    'systemVersion': '15',
    'isSimulator': true,
  });
  android['sdk']['name'] = 'rnv_network_sdk_android';
  for (final event in android['events']) {
    event['platform'] = 'android';
  }
  final second = await WebSocket.connect('ws://127.0.0.1:$port/rnv/network');
  second.add(jsonEncode(android));
  stdout.writeln(
    'Sent sample iOS + Android sessions to port $port. Holding connections for $hold seconds.',
  );
  await Future<void>.delayed(Duration(seconds: hold));
  await socket.close();
  await second.close();
}
