import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import 'connection/discovery.dart';
import 'connection/session.dart';
import 'ui/pad_screen.dart';
import 'ui/setup_screen.dart';
import 'ui/welcome_screen.dart';

/// The control port the launcher listens on when it can; a typed address uses it.
const launcherPort = 47700;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    final preferences = await SharedPreferences.getInstance();
    runApp(RemoteApp(preferences: preferences));
  } catch (error) {
    // Anything that fails before the first frame is shown, never a black screen.
    runApp(StartupError(error: error));
  }
}

/// The reason the app could not start, readable on the phone.
class StartupError extends StatelessWidget {
  const StartupError({super.key, required this.error});

  final Object error;

  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    home: Scaffold(
      backgroundColor: const Color(0xFF07080B),
      body: Padding(
        padding: const EdgeInsets.all(32),
        child: Center(
          child: Text(
            'AnyPS5 Remote açılamadı:\n\n$error',
            style: const TextStyle(color: Colors.white70, fontSize: 14),
          ),
        ),
      ),
    ),
  );
}

class RemoteApp extends StatefulWidget {
  const RemoteApp({super.key, required this.preferences});

  final SharedPreferences preferences;

  @override
  State<RemoteApp> createState() => _RemoteAppState();
}

class _RemoteAppState extends State<RemoteApp> {
  static const readyPause = Duration(milliseconds: 900);

  late final Session _session = Session(
    preferences: widget.preferences,
    deviceName: Platform.isIOS ? 'iPhone' : 'Android',
  );
  StreamSubscription<(InternetAddress, int, String)>? _discovery;
  Timer? _manualTimer;
  Timer? _readyTimer;
  bool _manual = false;
  bool _wasConnected = false;
  bool _padShown = false;
  String? _foundMac;
  late bool _welcomed = widget.preferences.getBool('welcomed') ?? false;

  @override
  void initState() {
    super.initState();
    _session.addListener(_changed);
    if (_welcomed) _search();
  }

  /// Looks for the launcher; the address field shows if nothing turns up within a few seconds.
  void _search() {
    _discovery ??= discover().listen((found) {
      setState(() => _foundMac = found.$3);
      _connect(found.$1, found.$2);
    }, onError: (_) => setState(() => _manual = true));
    _manualTimer ??= Timer(
      const Duration(seconds: 6),
      () => setState(() => _manual = true),
    );
  }

  /// A launcher found or typed in becomes the target unless one is already connected, so a
  /// launcher that comes back on another port or address is followed.
  void _connect(InternetAddress address, int port) {
    if (_session.status == ConnectionStatus.connected) return;
    _manualTimer?.cancel();
    _session.connect(address, port);
  }

  void _changed() {
    final connected = _session.status == ConnectionStatus.connected;
    if (connected != _wasConnected) {
      _wasConnected = connected;
      WakelockPlus.toggle(enable: connected);
      _readyTimer?.cancel();
      if (connected) {
        // "Hazır" shows for a moment, then the pad takes over.
        _readyTimer = Timer(readyPause, () => setState(() => _padShown = true));
      } else {
        _padShown = false;
      }
    }
    setState(() {});
  }

  void _start() {
    widget.preferences.setBool('welcomed', true);
    setState(() => _welcomed = true);
    _search();
  }

  @override
  void dispose() {
    _discovery?.cancel();
    _manualTimer?.cancel();
    _readyTimer?.cancel();
    _session.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Widget home;
    if (!_welcomed) {
      home = WelcomeScreen(onStart: _start);
    } else if (_padShown && _session.status == ConnectionStatus.connected) {
      home = PadScreen(
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
      );
    } else {
      home = SetupScreen(
        session: _session,
        foundMac: _foundMac,
        showManual: _manual,
        onAddress: (address) => _connect(address, launcherPort),
        onRetry: _session.retry,
      );
    }
    return MaterialApp(
      title: 'AnyPS5 Remote',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(useMaterial3: true),
      home: AnimatedSwitcher(
        duration: const Duration(milliseconds: 280),
        child: KeyedSubtree(key: ValueKey(home.runtimeType), child: home),
      ),
    );
  }
}
