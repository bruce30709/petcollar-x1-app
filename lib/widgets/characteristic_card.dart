import 'package:flutter/material.dart';

class CharacteristicCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final List<Widget> rows;
  final Widget? footer;

  const CharacteristicCard({
    super.key,
    required this.icon,
    required this.title,
    required this.rows,
    this.footer,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(icon, size: 22),
              const SizedBox(width: 8),
              Text(title, style: Theme.of(context).textTheme.titleMedium),
            ]),
            const SizedBox(height: 12),
            ...rows,
            if (footer != null) ...[const SizedBox(height: 12), footer!],
          ],
        ),
      ),
    );
  }
}
