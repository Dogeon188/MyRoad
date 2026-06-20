import 'package:flutter/material.dart';

class SpotBlock extends StatelessWidget {
  final String name;
  final String type;
  final String? subtitle;
  final VoidCallback? onTap;

  const SpotBlock({
    super.key,
    required this.name,
    required this.type,
    this.subtitle,
    this.onTap,
  });

  Color get _color => switch (type) {
    'restaurant' => Colors.orange,
    'hotel' => Colors.purple,
    'custom' => Colors.grey,
    _ => Colors.blue,
  };

  IconData get _icon => switch (type) {
    'restaurant' => Icons.restaurant,
    'hotel' => Icons.hotel,
    'custom' => Icons.star_outline,
    _ => Icons.place,
  };

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 3),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: _color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: _color.withValues(alpha: 0.4)),
        ),
        child: Row(
          children: [
            Icon(_icon, color: _color, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: TextStyle(fontWeight: FontWeight.w600, color: _color)),
                  if (subtitle != null)
                    Text(subtitle!, style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
