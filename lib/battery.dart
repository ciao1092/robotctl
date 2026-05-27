import 'package:flutter/material.dart';

class BatteryIcon extends StatelessWidget {
  final double level; // 0.0 to 100.0
  final double width;
  final double height;

  const BatteryIcon({
    super.key,
    required this.level,
    this.width = 40,
    this.height = 20,
  });

  @override
  Widget build(BuildContext context) {
    final clampedLevel = level.clamp(0.0, 100.0);

    Color getColor() {
      if (clampedLevel < 20) return Colors.red;
      if (clampedLevel < 50) return Colors.orange;
      return Colors.green;
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: width,
          height: height,
          padding: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.black, width: 2),
            borderRadius: BorderRadius.circular(4),
          ),
          child: FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: clampedLevel / 100,
            child: Container(
              color: getColor(),
            ),
          ),
        ),
        Container(
          width: 3,
          height: height * 0.6,
          margin: const EdgeInsets.only(left: 2),
          decoration: BoxDecoration(
            color: Colors.black,
            borderRadius: BorderRadius.circular(1),
          ),
        ),
      ],
    );
  }
}