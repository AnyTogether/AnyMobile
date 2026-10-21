import 'dart:convert';

/// A message on the launcher's control channel: one JSON object per WebSocket text frame.
sealed class Message {
  const Message();

  String toJson();

  static Message? fromJson(String text) {
    try {
      final json = jsonDecode(text);
      if (json is! Map<String, dynamic>) return null;
      return switch (json['type']) {
        'hello' => Hello(
          deviceID: json['deviceID'] as String,
          deviceName: json['deviceName'] as String,
          key: json['key'] as String?,
        ),
        'pairing' => Pairing(json['code'] as String),
        'welcome' => Welcome(
          session: BigInt.parse(json['session'] as String),
          udpPort: json['udpPort'] as int,
          macName: json['macName'] as String,
          key: json['key'] as String,
        ),
        'rejected' => Rejected(json['reason'] as String),
        'latency' => Latency((json['milliseconds'] as num).toDouble()),
        _ => null,
      };
    } on Object {
      return null;
    }
  }
}

class Hello extends Message {
  const Hello({
    required this.deviceID,
    required this.deviceName,
    required this.key,
  });

  final String deviceID;
  final String deviceName;
  final String? key;

  @override
  String toJson() => jsonEncode({
    'type': 'hello',
    'protocol': 1,
    'deviceID': deviceID,
    'deviceName': deviceName,
    'key': key,
  });
}

class Pairing extends Message {
  const Pairing(this.code);

  final String code;

  @override
  String toJson() => jsonEncode({'type': 'pairing', 'code': code});
}

class Welcome extends Message {
  const Welcome({
    required this.session,
    required this.udpPort,
    required this.macName,
    required this.key,
  });

  final BigInt session;
  final int udpPort;
  final String macName;
  final String key;

  @override
  String toJson() => jsonEncode({
    'type': 'welcome',
    'session': session.toString(),
    'udpPort': udpPort,
    'macName': macName,
    'key': key,
  });
}

class Rejected extends Message {
  const Rejected(this.reason);

  final String reason;

  @override
  String toJson() => jsonEncode({'type': 'rejected', 'reason': reason});
}

class Latency extends Message {
  const Latency(this.milliseconds);

  final double milliseconds;

  @override
  String toJson() =>
      jsonEncode({'type': 'latency', 'milliseconds': milliseconds});
}
