import 'package:flutter/cupertino.dart';

class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? color;

  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? CupertinoColors.secondarySystemGroupedBackground,
        borderRadius: BorderRadius.circular(16),
      ),
      child: child,
    );
  }
}
