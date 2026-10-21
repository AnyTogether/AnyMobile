import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import 'connection/discovery.dart';
import 'connection/session.dart';
import 'ui/connect_screen.dart';
import 'ui/pad_screen.dart';

/// The control port the launcher listens on when it can; a typed address uses it.
const launcherPort = 47700;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  final preferences = await SharedPreferences.getInstance();
  runApp(RemoteApp(preferences: preferences));
}

class RemoteApp extends StatefulWidget {
  const RemoteApp({super.key, required this.preferences});

  final SharedPreferences preferences;

  @override
  State<RemoteApp> createState() => _RemoteAppState();
}

class _RemoteAppState extends State<RemoteApp> {
  late final Session _session = Session(
    preferences: widget.preferences,
    deviceName: Platform.isIOS ? 'iPhone' : 'Android',
  );
  StreamSubscription<(InternetAddress, int, String)>? _discovery;
  Timer? _manualTimer;
  bool _manual = false;
  bool _connecting = false;

  @override
  void initState() {
    super.initState();
    _session.addListener(_changed);
    _discovery = discover().listen(
      (found) => _connect(found.$1, found.$2),
      onError: (_) => setState(() => _manual = true),
    );
    _manualTimer = Timer(
      const Duration(seconds: 5),
      () => setState(() => _manual = true),
    );
  }

  void _connect(InternetAddress address, int port) {
    if (_connecting) return;
    _connecting = true;
    _manualTimer?.cancel();
    _session.connect(address, port);
  }

  void _changed() {
    WakelockPlus.toggle(enable: _session.status == ConnectionStatus.connected);
    setState(() {});
  }

  @override
  void dispose() {
    _discovery?.cancel();
    _manualTimer?.cancel();
    _session.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final connected = _session.status == ConnectionStatus.connected;
    return MaterialApp(
      title: 'AnyPS5 Remote',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(useMaterial3: true),
      home: connected
          ? PadScreen(
              onState: _session.update,
              status: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const StatusDot(color: Color(0xFF4CD964)),
                  const SizedBox(width: 8),
                  Text(
                    [
                      _session.macName ?? 'Mac',
                      if (_session.latencyMs != null)
                        '${_session.latencyMs!.round()} ms',
                    ].join(' · '),
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            )
          : ConnectScreen(
              session: _session,
              showManual: _manual,
              onAddress: (address) {
                _connecting = false;
                _connect(address, launcherPort);
              },
            ),
    );
  }
}
