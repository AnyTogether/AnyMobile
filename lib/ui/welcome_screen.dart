import 'package:flutter/material.dart';

/// The first start: what the app is, and the one button that begins the setup.
class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key, required this.onStart});

  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF07080B),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.sports_esports_rounded,
                  color: Colors.white,
                  size: 52,
                ),
                const SizedBox(height: 18),
                const Text(
                  'Telefonun DualSense olsun',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.w300,
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  "Mac'te AnyPS5 ile açtığın oyunları bu telefonla oyna.",
                  style: TextStyle(color: Colors.white60, fontSize: 15),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 26),
                const Wrap(
                  spacing: 28,
                  runSpacing: 12,
                  alignment: WrapAlignment.center,
                  children: [
                    _Step(number: 1, text: "Mac'te AnyPS5'i aç"),
                    _Step(number: 2, text: "Aynı Wi-Fi'a bağlan"),
                    _Step(number: 3, text: "Mac'te izin ver"),
                  ],
                ),
                const SizedBox(height: 30),
                FilledButton(
                  onPressed: onStart,
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 44,
                      vertical: 16,
                    ),
                    textStyle: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  child: const Text('Başla'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Step extends StatelessWidget {
  const _Step({required this.number, required this.text});

  final int number;
  final String text;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 26,
        height: 26,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: const Color(0x55FFFFFF)),
        ),
        child: Text(
          '$number',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      const SizedBox(width: 10),
      Text(text, style: const TextStyle(color: Colors.white, fontSize: 15)),
    ],
  );
}
