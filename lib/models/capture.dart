import 'dart:convert';

typedef Json = Map<String, dynamic>;

Json objectOf(dynamic value) => value is Map
    ? value.map((key, value) => MapEntry(key.toString(), value))
    : <String, dynamic>{};

String pretty(dynamic value) {
  if (value is String) {
    try {
      return const JsonEncoder.withIndent('  ').convert(jsonDecode(value));
    } on FormatException {
      return value;
    }
  }
  return const JsonEncoder.withIndent('  ').convert(value);
}

class DeviceSession {
  DeviceSession(this.metadata, this.sdk);
  final Json metadata;
  final Json sdk;
  String get id => metadata['id'] as String;
  String get name => '${metadata['appName'] ?? 'React Native'}';
  String get device => '${metadata['deviceName'] ?? 'Unknown device'}';
  String get platform => '${metadata['platform'] ?? 'unknown'}';
}

class NetworkRecord {
  NetworkRecord(this.sessionId, this.requestId);
  final String sessionId;
  final String requestId;
  Json requestEvent = {};
  Json completionEvent = {};

  String get key => jsonEncode([sessionId, requestId]);
  Json get request => objectOf(requestEvent['request']);
  Json get response => objectOf(completionEvent['response']);
  Json get error => objectOf(completionEvent['error']);
  String get method => '${request['method'] ?? '—'}';
  String get url => '${request['url'] ?? '(request not received)'}';
  String get source =>
      '${requestEvent['source'] ?? completionEvent['source'] ?? ''}';
  int? get status => (response['statusCode'] as num?)?.toInt();
  num? get duration => completionEvent['durationMs'] as num?;
  bool get failed => error.isNotEmpty || (status ?? 0) >= 400;
  bool get pending => completionEvent.isEmpty;
  String get state => error.isNotEmpty
      ? (completionEvent['phase'] == 'abort' ? 'Aborted' : 'Error')
      : status?.toString() ??
            (pending ? 'Pending' : '${completionEvent['phase']}');
  DateTime? get time => DateTime.tryParse(
    '${requestEvent['timestamp'] ?? completionEvent['timestamp']}',
  );
  int get responseBytes => utf8
      .encode('${response['body'] ?? response['bodyPreview'] ?? ''}')
      .length;

  void apply(Json event) {
    if (event['phase'] == 'request') {
      requestEvent = event;
    } else {
      completionEvent = event;
    }
  }

  Json toJson() => {
    'sessionId': sessionId,
    'requestId': requestId,
    'requestEvent': requestEvent,
    'completionEvent': completionEvent,
  };

  String get curl {
    String quote(String value) => "'${value.replaceAll("'", "'\\''")}'";
    final parts = ['curl', '-X', method, quote(url)];
    objectOf(request['headers']).forEach((name, value) {
      parts.addAll(['-H', quote('$name: $value')]);
    });
    if (request['body'] != null) {
      parts.addAll(['--data-raw', quote('${request['body']}')]);
    }
    return parts.join(' ');
  }
}

class ConsoleRecord {
  ConsoleRecord(this.id, this.sessionId, this.event);
  final int id;
  final String sessionId;
  final Json event;
  String get level => '${event['level'] ?? 'log'}';
  String get message => '${event['message'] ?? ''}';
  DateTime? get time => DateTime.tryParse('${event['timestamp']}');
  Json toJson() => {'sessionId': sessionId, 'event': event};
}
