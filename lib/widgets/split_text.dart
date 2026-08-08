import 'package:flutter/material.dart';

class SplitText extends StatefulWidget {
  final String text;
  final TextStyle? style;
  final TextAlign textAlign;
  final int delay; // milliseconds between characters
  final double duration; // seconds for each character's animation
  final Offset fromOffset;
  final Curve curve;
  final VoidCallback? onComplete;

  const SplitText({
    super.key,
    required this.text,
    this.style,
    this.textAlign = TextAlign.center,
    this.delay = 50,
    this.duration = 1.25,
    this.fromOffset = const Offset(0, 40),
    this.curve = Curves.easeOutQuart,
    this.onComplete,
  });

  @override
  State<SplitText> createState() => _SplitTextState();
}

class _SplitTextState extends State<SplitText> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final List<Animation<double>> _animations = [];
  late List<String> _chars;

  @override
  void initState() {
    super.initState();
    _chars = widget.text.split('');
    
    final staggerTotal = (widget.delay * _chars.length) / 1000.0;
    final totalDuration = Duration(milliseconds: ((widget.duration + staggerTotal) * 1000).toInt());

    _controller = AnimationController(vsync: this, duration: totalDuration);

    for (int i = 0; i < _chars.length; i++) {
      final double start = (i * widget.delay / 1000.0) / (widget.duration + staggerTotal);
      final double end = start + (widget.duration / (widget.duration + staggerTotal));
      _animations.add(CurvedAnimation(
        parent: _controller,
        curve: Interval(start.clamp(0.0, 1.0), end.clamp(0.0, 1.0), curve: widget.curve),
      ));
    }

    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) widget.onComplete?.call();
    });
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.center,
      children: List.generate(_chars.length, (i) {
        return AnimatedBuilder(
          animation: _animations[i],
          builder: (context, child) {
            return Opacity(
              opacity: _animations[i].value,
              child: Transform.translate(
                offset: widget.fromOffset * (1 - _animations[i].value),
                child: Text(_chars[i] == ' ' ? '\u00A0' : _chars[i], style: widget.style),
              ),
            );
          },
        );
      }),
    );
  }
}
