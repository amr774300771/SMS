import 'package:flutter/material.dart';

const qaidiRadius = 18.0;
const qaidiPagePadding = EdgeInsets.all(18);

class QaidiSectionHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? action;
  const QaidiSectionHeader({super.key, required this.title, this.subtitle, this.action});
  @override
  Widget build(BuildContext context) => Row(children: [
    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
      if (subtitle != null) Text(subtitle!, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 12)),
    ])),
    if (action != null) action!,
  ]);
}

class QaidiStatusPill extends StatelessWidget {
  final String label;
  final Color color;
  final IconData icon;
  const QaidiStatusPill({super.key, required this.label, required this.color, required this.icon});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(color: color.withValues(alpha: .12), borderRadius: BorderRadius.circular(30)),
    child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(icon, size: 15, color: color), const SizedBox(width: 5), Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 12))]),
  );
}

class QaidiMetricTile extends StatelessWidget {
  final String title;
  final String value;
  final String caption;
  final IconData icon;
  final Color color;
  const QaidiMetricTile({super.key, required this.title, required this.value, required this.caption, required this.icon, required this.color});
  @override
  Widget build(BuildContext context) => Card(child: Padding(padding: const EdgeInsets.all(14), child: Row(children: [
    Container(width: 38, height: 38, decoration: BoxDecoration(color: color.withValues(alpha: .12), borderRadius: BorderRadius.circular(12)), child: Icon(icon, color: color, size: 20)),
    const SizedBox(width: 10),
    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 12)), const SizedBox(height: 2), Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900)), Text(caption, style: const TextStyle(fontSize: 11, color: Colors.grey))])),
  ])));
}
