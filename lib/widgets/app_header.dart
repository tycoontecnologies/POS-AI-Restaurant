import 'package:flutter/material.dart';

class AppHeader extends StatelessWidget {
  const AppHeader({
    super.key,
    required this.selectedIndex,
    required this.onTap,
  });

  final int selectedIndex;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final items = [
      _HeaderItem(icon: Icons.category, label: 'Categories'),
      _HeaderItem(icon: Icons.inventory_2, label: 'Products'),
      _HeaderItem(icon: Icons.group, label: 'Staff'),
      _HeaderItem(icon: Icons.access_time, label: 'Attendance'),
      _HeaderItem(icon: Icons.local_shipping, label: 'Suppliers'),
      _HeaderItem(icon: Icons.shopping_cart, label: 'Purchases'),
      _HeaderItem(icon: Icons.point_of_sale, label: 'Sales'),
      _HeaderItem(icon: Icons.archive_outlined, label: 'Drafts'),
      _HeaderItem(icon: Icons.storefront_outlined, label: 'Store Out'),
      _HeaderItem(icon: Icons.settings, label: 'Settings'),
    ];

    return Material(
      color: Theme.of(context).colorScheme.primary,
      child: SafeArea(
        bottom: false,
        child: Container(
          height: 64,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isCompact = constraints.maxWidth < 600;
              return Row(
                children: [
                  IconButton(
                    onPressed: null,
                    icon: const Icon(Icons.point_of_sale, color: Colors.white),
                  ),
                  Text(
                    'POS',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          for (int i = 0; i < items.length; i++)
                            _HeaderButton(
                              item: items[i],
                              selected: selectedIndex == i,
                              onTap: () => onTap(i),
                              compact: isCompact,
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _HeaderItem {
  const _HeaderItem({required this.icon, required this.label});
  final IconData icon;
  final String label;
}

class _HeaderButton extends StatelessWidget {
  const _HeaderButton({
    required this.item,
    required this.selected,
    required this.onTap,
    required this.compact,
  });

  final _HeaderItem item;
  final bool selected;
  final VoidCallback onTap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final color = selected ? Colors.white : Colors.white70;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: TextButton.icon(
        onPressed: onTap,
        style: TextButton.styleFrom(
          foregroundColor: color,
          backgroundColor: selected
              ? Colors.white.withOpacity(0.12)
              : Colors.transparent,
        ),
        icon: Icon(item.icon, color: color),
        label: Text(
          compact ? '' : item.label,
          style: TextStyle(color: color),
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
}
