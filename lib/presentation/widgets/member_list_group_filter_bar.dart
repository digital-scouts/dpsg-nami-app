import 'package:flutter/material.dart';

class GroupFilterItem {
  final String keyName;
  final String? imageAssetPath;
  final String? semanticLabel;

  const GroupFilterItem({
    required this.keyName,
    this.imageAssetPath,
    this.semanticLabel,
  });
}

class GroupFilterBar extends StatelessWidget {
  final List<GroupFilterItem> items;
  final Set<String> selectedKeys;
  final ValueChanged<Set<String>> onChanged;
  final double itemSize;
  final EdgeInsetsGeometry padding;

  const GroupFilterBar({
    super.key,
    required this.items,
    required this.selectedKeys,
    required this.onChanged,
    this.itemSize = 50.0,
    this.padding = const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: items.map((item) {
            final isActive = selectedKeys.contains(item.keyName);
            final double imageSize = itemSize * 0.6;

            Widget inner = Image.asset(
              item.imageAssetPath ?? 'assets/icons/lilie_schwarz.png',
              semanticLabel: item.semanticLabel ?? '${item.keyName} Filter',
              width: imageSize,
              height: imageSize,
              fit: BoxFit.contain,
            );

            final circle = Container(
              width: itemSize,
              height: itemSize,
              margin: const EdgeInsets.symmetric(horizontal: 4.0),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isActive
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.secondaryContainer,
              ),
              child: Center(child: inner),
            );
            return GestureDetector(
              onTap: () {
                final next = Set<String>.from(selectedKeys);
                if (isActive) {
                  next.remove(item.keyName);
                } else {
                  next.add(item.keyName);
                }
                onChanged(next);
              },
              child: circle,
            );
          }).toList(),
        ),
      ),
    );
  }
}
