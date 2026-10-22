import 'dart:io';

import 'package:flutter/material.dart';

import '../connection/session.dart';

/// Before the pad: looking for the Mac, connecting, showing the pairing code, or why the Mac
/// said no. After a few seconds without a launcher found, an address can be typed instead.
class ConnectScreen extends StatefulWidget {
  const ConnectScreen({
    super.key,
    required this.session,
    required this.onAddress,
    required this.showManual,
    required this.onRetry,
  });

  final Session session;
  final void Function(InternetAddress address) onAddress;
  final bool showManual;
  final VoidCallback onRetry;

  @override
  State<ConnectScreen> createState() => _ConnectScreenState();
}

class _ConnectScreenState extends State<ConnectScreen> {
  final _address = TextEditingController();

  @override
  void dispose() {
    _address.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final session = widget.session;
    final (color, title) = switch (session.status) {
      ConnectionStatus.searching => (
        const Color(0xFFFFC857),
        "Mac'teki AnyPS5 aranıyor",
      ),
      ConnectionStatus.connecting => (const Color(0xFFFFC857), 'Bağlanıyor'),
      ConnectionStatus.pairing => (const Color(0xFFFFC857), "Mac'te izin ver"),
      ConnectionStatus.connected => (const Color(0xFF4CD964), 'Bağlandı'),
      ConnectionStatus.rejected => (
        const Color(0xFFFF6B5E),
        session.rejectedReason == 'busy'
            ? 'Başka bir telefon bağlı'
            : 'Mac bağlantıyı reddetti',
      ),
    };
    return Scaffold(
      backgroundColor: const Color(0xFF07080B),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              StatusDot(color: color, size: 14),
              const SizedBox(height: 16),
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.w300,
                ),
              ),
              if (session.status == ConnectionStatus.pairing &&
                  session.code != null) ...[
                const SizedBox(height: 20),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final digit in session.code!.split(''))
                      Container(
                        margin: const EdgeInsets.symmetric(horizontal: 6),
                        width: 54,
                        height: 70,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: const Color(0x1AFFFFFF),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0x24FFFFFF)),
                        ),
                        child: Text(
                          digit,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 40,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                const Text(
                  "Mac'te aynı kod görünüyor.",
                  style: TextStyle(color: Colors.white60, fontSize: 14),
                ),
              ],
              if (session.status == ConnectionStatus.rejected) ...[
                const SizedBox(height: 24),
                OutlinedButton(
                  onPressed: widget.onRetry,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Color(0x55FFFFFF)),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 28,
                      vertical: 14,
                    ),
                  ),
                  child: const Text('Tekrar dene'),
                ),
              ],
              if ((widget.showManual ||
                      session.status == ConnectionStatus.rejected) &&
                  session.status != ConnectionStatus.pairing) ...[
                const SizedBox(height: 28),
                SizedBox(
                  width: 260,
                  child: TextField(
                    controller: _address,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      hintText: "Mac'in adresi (192.168.1.20)",
                      hintStyle: TextStyle(color: Colors.white38),
                      enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: Color(0x33FFFFFF)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.white),
                      ),
                    ),
                    onSubmitted: _submit,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _submit(String text) {
    final address = InternetAddress.tryParse(text.trim());
    if (address != null) widget.onAddress(address);
  }
}

/// The connection's colour: green connected, amber on the way, red refused.
class StatusDot extends StatelessWidget {
  const StatusDot({super.key, required this.color, this.size = 8});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      color: color,
      shape: BoxShape.circle,
      boxShadow: [
        BoxShadow(color: color.withValues(alpha: 0.7), blurRadius: size),
      ],
    ),
  );
}
