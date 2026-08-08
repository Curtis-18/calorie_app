import 'package:flutter/material.dart';
import 'split_text.dart';

class WelcomeOverlay extends StatefulWidget {
  final VoidCallback onFinished;
  const WelcomeOverlay({super.key, required this.onFinished});

  @override
  State<WelcomeOverlay> createState() => _WelcomeOverlayState();
}

class _WelcomeOverlayState extends State<WelcomeOverlay> {
  int _step = 0;

  void _next() async {
    await Future.delayed(const Duration(milliseconds: 600));
    if (!mounted) return;
    if (_step < 2) setState(() => _step++); else widget.onFinished();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_step == 0) SplitText(key: ValueKey(0), text: "Hello, you!", style: Theme.of(context).textTheme.headlineMedium, onComplete: _next),
            if (_step == 1) SplitText(key: ValueKey(1), text: "Welcome to Calorie Tracker", style: Theme.of(context).textTheme.headlineSmall, onComplete: _next),
            if (_step == 2) SplitText(key: ValueKey(2), text: "Let's get you started.", style: Theme.of(context).textTheme.bodyLarge, onComplete: _next),
          ],
        ),
      ),
    );
  }
}
