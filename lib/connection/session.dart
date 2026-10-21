import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../protocol/messages.dart';
import '../protocol/packets.dart';

enum ConnectionStatus { searching, connecting, pairing, connected, rejected }

/// The phone's link to the launcher: the WebSocket control channel (hello, pairing, welcome),
/// the UDP pad sender and the latency measured from the game's answers.
class Session extends ChangeNotifier {
  Session({required this.preferences, required this.deviceName});

  final SharedPreferences preferences;
  final String deviceName;

  static const sendInterval = Duration(milliseconds: 8);
  static const reportInterval = Duration(seconds: 2);
  static const retryInterval = Duration(seconds: 1);
  static final _clock = Stopwatch()..start();

  ConnectionStatus status = ConnectionStatus.searching;
  String? code;
  String? macName;
  String? rejectedReason;
  double? latencyMs;

  /// The game's latest answer: vibration, light bar and trigger fallbacks.
  Output? output;

  InternetAddress? _host;
  int? _port;
  WebSocket? _socket;
  RawDatagramSocket? _udp;
  int? _udpPort;
  BigInt? _session;
  Timer? _sender;
  Timer? _reporter;
  Timer? _retry;
  bool _closed = false;
  int _sequence = 0;
  PadState _state = PadState();
  int _handlingMicros = 0;

  String get _deviceID {
    final stored = preferences.getString('deviceID');
    if (stored != null) return stored;
    final random = Random.secure();
    final id = List.generate(
      16,
      (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
    preferences.setString('deviceID', id);
    return id;
  }

  /// Connects to the launcher at [host]:[port] and keeps reconnecting until [close].
  Future<void> connect(InternetAddress host, int port) async {
    _host = host;
    _port = port;
    _closed = false;
    await _open();
  }

  Future<void> _open() async {
    if (_closed || _host == null) return;
    _setStatus(ConnectionStatus.connecting);
    try {
      final socket = await WebSocket.connect(
        Uri(scheme: 'ws', host: _host!.address, port: _port).toString(),
      ).timeout(const Duration(seconds: 3));
      _socket = socket;
      socket.listen(
        _received,
        onDone: _lost,
        onError: (_) => _lost(),
        cancelOnError: true,
      );
      socket.add(
        Hello(
          deviceID: _deviceID,
          deviceName: deviceName,
          key: preferences.getString('key'),
        ).toJson(),
      );
    } on Object {
      _scheduleRetry();
    }
  }

  void _received(dynamic data) {
    if (data is! String) return;
    switch (Message.fromJson(data)) {
      case Pairing(:final code):
        this.code = code;
        _setStatus(ConnectionStatus.pairing);
      case Welcome(:final session, :final udpPort, :final macName, :final key):
        preferences.setString('key', key);
        this.macName = macName;
        _session = session;
        _udpPort = udpPort;
        code = null;
        _startPad();
        _setStatus(ConnectionStatus.connected);
      case Rejected(:final reason):
        rejectedReason = reason;
        _setStatus(ConnectionStatus.rejected);
      default:
        break;
    }
  }

  Future<void> _startPad() async {
    if (_udp == null) {
      final udp = await RawDatagramSocket.bind(
        _host!.type == InternetAddressType.IPv6
            ? InternetAddress.anyIPv6
            : InternetAddress.anyIPv4,
        0,
      );
      _udp = udp;
      udp.listen((event) {
        if (event != RawSocketEvent.read) return;
        final datagram = udp.receive();
        final answer = datagram == null ? null : decodeOutput(datagram.data);
        if (answer != null) _answered(answer);
      });
    }
    _sender?.cancel();
    _sender = Timer.periodic(sendInterval, (_) => _send());
    _reporter?.cancel();
    _reporter = Timer.periodic(reportInterval, (_) {
      if (latencyMs != null) _socket?.add(Latency(latencyMs!).toJson());
    });
    _send();
  }

  /// The new pad state, sent at once; the moment it arrives is when the touch was received.
  void update(PadState state) {
    final touched = _clock.elapsedMicroseconds;
    _state = state.copy();
    _send();
    _handlingMicros = _clock.elapsedMicroseconds - touched;
  }

  void _send() {
    final udp = _udp;
    final session = _session;
    if (udp == null ||
        session == null ||
        _udpPort == null ||
        status != ConnectionStatus.connected && _sender == null) {
      return;
    }
    _sequence = (_sequence + 1) & 0xFFFFFFFF;
    udp.send(
      encodeInput(
        sequence: _sequence,
        sentMicros: _clock.elapsedMicroseconds,
        session: session,
        state: _state,
      ),
      _host!,
      _udpPort!,
    );
  }

  /// One-way latency from an answer: half the round trip without the time the input waited in
  /// the game's socket, plus that wait, plus the time from the touch to the send.
  void _answered(Output answer) {
    output = answer;
    final roundTrip = _clock.elapsedMicroseconds - answer.sentMicros;
    if (roundTrip < 0 || roundTrip > 2000000) return;
    final oneWay =
        (roundTrip - answer.waitMicros) / 2 +
        answer.waitMicros +
        _handlingMicros;
    final sample = oneWay / 1000;
    latencyMs = latencyMs == null ? sample : latencyMs! * 0.8 + sample * 0.2;
    notifyListeners();
  }

  void _lost() {
    _socket = null;
    _stopPad();
    if (_closed || status == ConnectionStatus.rejected) return;
    _scheduleRetry();
  }

  void _scheduleRetry() {
    _setStatus(ConnectionStatus.connecting);
    _retry?.cancel();
    _retry = Timer(retryInterval, _open);
  }

  void _stopPad() {
    _sender?.cancel();
    _sender = null;
    _reporter?.cancel();
    _reporter = null;
    _session = null;
    latencyMs = null;
  }

  void _setStatus(ConnectionStatus next) {
    status = next;
    notifyListeners();
  }

  /// Ends the session for good.
  Future<void> close() async {
    _closed = true;
    _retry?.cancel();
    _stopPad();
    _udp?.close();
    _udp = null;
    await _socket?.close();
    _socket = null;
  }
}
