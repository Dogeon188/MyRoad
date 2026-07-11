import 'package:flutter/material.dart';

/// An icon + label pair used inside a [StatRow].
class StatItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final double iconSize;
  final Color? color;
  final TextStyle? style;

  const StatItem({
    super.key,
    required this.icon,
    required this.label,
    this.iconSize = 16,
    this.color,
    this.style,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      spacing: 4,
      children: [
        Icon(icon, size: iconSize, color: color),
        Text(label, style: style),
      ],
    );
  }
}

/// A row of [StatItem]s, e.g. "N areas · N spots" on a list card.
class StatRow extends StatelessWidget {
  final List<StatItem> items;

  const StatRow({super.key, required this.items});

  @override
  Widget build(BuildContext context) {
    return Row(spacing: 16, children: items);
  }
}
