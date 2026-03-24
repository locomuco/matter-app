import 'package:flutter/material.dart';

class OnlineBadge extends StatelessWidget {
  final bool isOnline;
  const OnlineBadge({super.key, required this.isOnline});

  @override
  Widget build(BuildContext context) {
    final color = isOnline
        ? const Color(0xFF34A853) // Google green
        : Colors.grey;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(
          isOnline ? 'Online' : 'Offline',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: color,
          ),
        ),
      ],
    );
  }
}
