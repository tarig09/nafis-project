import 'package:flutter/material.dart';
import '../core/theme.dart';

class NafisLogo extends StatelessWidget {
  final double size;
  const NafisLogo({super.key, this.size = 28});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('نافس',
            style: TextStyle(
                fontSize: size,
                fontWeight: FontWeight.w800,
                color: AppColors.indigo,
                height: 1.1)),
        Text('in sudan',
            style: TextStyle(
                fontSize: size * 0.34, color: Colors.black54, letterSpacing: 1)),
      ],
    );
  }
}
