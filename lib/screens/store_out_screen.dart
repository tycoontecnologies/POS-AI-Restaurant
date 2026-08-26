import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import 'package:pos/models/store_out.dart';
import 'package:pos/providers/store_out_provider.dart';
import 'package:pos/screens/add_edit_store_out_screen.dart';

const _ink = Color(0xFF101828);
const _muted = Color(0xFF667085);
const _line = Color(0xFFE4E7EC);
const _soft = Color(0xFFF8FAFC);
const _purple = Color(0xFF6C4CF1);
const _green = Color(0xFF12B76A);
const _orange = Color(0xFFF79009);
const _red = Color(0xFFD92D20);

class StoreOutScreen extends StatefulWidget {
  const StoreOutScreen({super.key});

  @override
  State<StoreOutScreen> createState() => _StoreOutScreenState();
}

class _StoreOutScreenState extends State<StoreOutScreen> {
  final TextEditingController _search = TextEditingController();
  String _view = 'list';

  @override
  void initState() {
    super.initState();
    _search.addListener(() {
      context.read<StoreOutProvider>().setSearchQuery(_search.text);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<StoreOutProvider>().loadStoreOuts();
    });
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _add() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AddEditStoreOutScreen()),
    );
    if (result == true && mounted) {
      await context.read<StoreOutProvider>().loadStoreOuts();
    }
  }

  Future<void> _edit(StoreOut item) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => AddEditStoreOutScreen(storeOut: item)),
    );
    if (result == true && mounted) {
      await context.read<StoreOutProvider>().loadStoreOuts();
    }
  }

  Future<void> _delete(StoreOut item) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Delete movement?'),
        content: Text(
          'Remove ${item.reason.isEmpty ? 'this store movement' : item.reason}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: _red),
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok == true && mounted) {
      await context.read<StoreOutProvider>().deleteStoreOut(item.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<StoreOutProvider>();
    final items = provider.storeOuts;
    final totalUnits = items.fold<int>(0, (sum, e) => sum + e.items);
    final totalValue = items.fold<double>(0, (sum, e) => sum + e.totalValue);
    final now = DateTime.now();
    final todayCount = items
        .where(
          (e) =>
              e.date.year == now.year &&
              e.date.month == now.month &&
              e.date.day == now.day,
        )
        .length;
    final kitchenCount = items
        .where((e) => e.reason.toLowerCase().contains('kitchen'))
        .length;

    return ColoredBox(
      color: _soft,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Store Overview',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: _ink,
                        ),
                      ),
                      SizedBox(height: 3),
                      Text(
                        'Outgoing stock, kitchen movement and internal usage',
                        style: TextStyle(fontSize: 11, color: _muted),
                      ),
                    ],
                  ),
                ),
                FilledButton.icon(
                  onPressed: _add,
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Record Outgoing'),
                  style: FilledButton.styleFrom(
                    backgroundColor: _purple,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 16,
                    ),
                    textStyle: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            LayoutBuilder(
              builder: (_, c) {
                final cols = c.maxWidth >= 950
                    ? 4
                    : c.maxWidth >= 600
                    ? 2
                    : 1;
                final width = (c.maxWidth - ((cols - 1) * 10)) / cols;
                final cards = [
                  _SummaryCard(
                    'Movements',
                    '${items.length}',
                    Icons.swap_horiz_rounded,
                    _purple,
                  ),
                  _SummaryCard(
                    'Units Out',
                    '$totalUnits',
                    Icons.inventory_2_outlined,
                    const Color(0xFF2E90FA),
                  ),
                  _SummaryCard(
                    'Value Out',
                    'Rs ${NumberFormat('#,##0').format(totalValue.round())}',
                    Icons.payments_outlined,
                    _green,
                  ),
                  _SummaryCard(
                    'Today / Kitchen',
                    '$todayCount / $kitchenCount',
                    Icons.soup_kitchen_outlined,
                    _orange,
                  ),
                ];
                return Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: cards
                      .map((e) => SizedBox(width: width, child: e))
                      .toList(),
                );
              },
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _line),
              ),
              child: LayoutBuilder(
                builder: (_, c) {
                  final compact = c.maxWidth < 760;
                  final search = TextField(
                    controller: _search,
                    decoration: InputDecoration(
                      hintText: 'Search movements, reasons or staff…',
                      prefixIcon: const Icon(Icons.search_rounded),
                      filled: true,
                      fillColor: _soft,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(9),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(vertical: 9),
                    ),
                  );
                  final views = Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      _ViewButton(
                        label: 'Cards',
                        icon: Icons.grid_view_rounded,
                        selected: _view == 'cards',
                        onTap: () => setState(() => _view = 'cards'),
                      ),
                      _ViewButton(
                        label: 'Compact',
                        icon: Icons.view_list_rounded,
                        selected: _view == 'list',
                        onTap: () => setState(() => _view = 'list'),
                      ),
                      _ViewButton(
                        label: 'Table',
                        icon: Icons.table_rows_rounded,
                        selected: _view == 'table',
                        onTap: () => setState(() => _view = 'table'),
                      ),
                    ],
                  );
                  if (compact) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [search, const SizedBox(height: 8), views],
                    );
                  }
                  return Row(
                    children: [
                      Expanded(child: search),
                      const SizedBox(width: 10),
                      views,
                    ],
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
            if (provider.error != null)
              Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF3F2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, color: _red),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        provider.error!,
                        style: const TextStyle(color: _red),
                      ),
                    ),
                    IconButton(
                      onPressed: provider.clearError,
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
              ),
            Expanded(
              child: provider.isLoading && items.isEmpty
                  ? const Center(child: CircularProgressIndicator())
                  : items.isEmpty
                  ? _EmptyState(onAdd: _add)
                  : _view == 'cards'
                  ? _CardGrid(items: items, onEdit: _edit, onDelete: _delete)
                  : _view == 'list'
                  ? _CompactList(items: items, onEdit: _edit, onDelete: _delete)
                  : _TableView(items: items, onEdit: _edit, onDelete: _delete),
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  const _SummaryCard(this.label, this.value, this.icon, this.color);

  @override
  Widget build(BuildContext context) => Container(
    height: 68,
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: _line),
    ),
    child: Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: color.withValues(alpha: .10),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 10,
                  color: _muted,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: _ink,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _ViewButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  const _ViewButton({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => OutlinedButton.icon(
    onPressed: onTap,
    icon: Icon(icon, size: 17),
    label: Text(label),
    style: OutlinedButton.styleFrom(
      foregroundColor: selected ? _purple : _muted,
      backgroundColor: selected ? const Color(0xFFF4F3FF) : Colors.white,
      side: BorderSide(color: selected ? _purple : _line),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
      textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800),
    ),
  );
}

class _CardGrid extends StatelessWidget {
  final List<StoreOut> items;
  final ValueChanged<StoreOut> onEdit;
  final ValueChanged<StoreOut> onDelete;
  const _CardGrid({
    required this.items,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (_, c) {
      final cols = c.maxWidth >= 1100
          ? 3
          : c.maxWidth >= 700
          ? 2
          : 1;
      final width = (c.maxWidth - ((cols - 1) * 10)) / cols;
      return SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 16),
        child: Wrap(
          spacing: 10,
          runSpacing: 10,
          children: items
              .map(
                (item) => SizedBox(
                  width: width,
                  child: _MovementCard(
                    item: item,
                    onEdit: onEdit,
                    onDelete: onDelete,
                  ),
                ),
              )
              .toList(),
        ),
      );
    },
  );
}

class _MovementCard extends StatelessWidget {
  final StoreOut item;
  final ValueChanged<StoreOut> onEdit;
  final ValueChanged<StoreOut> onDelete;
  const _MovementCard({
    required this.item,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final products = item.products
        .take(3)
        .map((e) => '${e.product.name} × ${e.quantity}')
        .join(' • ');
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFFAEB),
                  borderRadius: BorderRadius.circular(7),
                ),
                child: Text(
                  item.reason.isEmpty ? 'Movement' : item.reason,
                  style: const TextStyle(
                    fontSize: 9,
                    color: _orange,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const Spacer(),
              PopupMenuButton<String>(
                onSelected: (v) => v == 'edit' ? onEdit(item) : onDelete(item),
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'edit', child: Text('Edit')),
                  PopupMenuItem(value: 'delete', child: Text('Delete')),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            products.isEmpty ? 'No products' : products,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w800,
              color: _ink,
            ),
          ),
          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _Meta(Icons.inventory_2_outlined, '${item.items} units'),
              ),
              Expanded(
                child: _Meta(
                  Icons.payments_outlined,
                  'Rs ${NumberFormat('#,##0').format(item.totalValue.round())}',
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _Meta(
                  Icons.person_outline,
                  item.handledBy.isEmpty ? 'Unassigned' : item.handledBy,
                ),
              ),
              _Meta(
                Icons.calendar_today_outlined,
                DateFormat('d MMM yyyy').format(item.date),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CompactList extends StatelessWidget {
  final List<StoreOut> items;
  final ValueChanged<StoreOut> onEdit;
  final ValueChanged<StoreOut> onDelete;
  const _CompactList({
    required this.items,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) => ListView.separated(
    padding: const EdgeInsets.only(bottom: 16),
    itemCount: items.length,
    separatorBuilder: (_, __) => const SizedBox(height: 8),
    itemBuilder: (_, i) {
      final item = items[i];
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: _line),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: const Color(0xFFF4F3FF),
                borderRadius: BorderRadius.circular(9),
              ),
              child: const Icon(Icons.output_rounded, color: _purple, size: 18),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.reason,
                    style: const TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  Text(
                    item.products
                        .map((e) => '${e.product.name} (${e.quantity})')
                        .take(2)
                        .join(', '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 9, color: _muted),
                  ),
                ],
              ),
            ),
            Expanded(
              child: _Meta(Icons.inventory_2_outlined, '${item.items} units'),
            ),
            Expanded(child: _Meta(Icons.person_outline, item.handledBy)),
            Expanded(
              child: _Meta(
                Icons.calendar_today_outlined,
                DateFormat('d MMM yyyy').format(item.date),
              ),
            ),
            IconButton(
              onPressed: () => onEdit(item),
              icon: const Icon(Icons.edit_outlined, size: 18, color: _purple),
            ),
            IconButton(
              onPressed: () => onDelete(item),
              icon: const Icon(
                Icons.delete_outline_rounded,
                size: 18,
                color: _red,
              ),
            ),
          ],
        ),
      );
    },
  );
}

class _TableView extends StatelessWidget {
  final List<StoreOut> items;
  final ValueChanged<StoreOut> onEdit;
  final ValueChanged<StoreOut> onDelete;
  const _TableView({
    required this.items,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: _line),
    ),
    child: Scrollbar(
      thumbVisibility: true,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SingleChildScrollView(
          child: DataTable(
            columns: const [
              DataColumn(label: Text('Reason')),
              DataColumn(label: Text('Products')),
              DataColumn(label: Text('Units')),
              DataColumn(label: Text('Date')),
              DataColumn(label: Text('Handled By')),
              DataColumn(label: Text('Actions')),
            ],
            rows: items
                .map(
                  (item) => DataRow(
                    cells: [
                      DataCell(Text(item.reason)),
                      DataCell(
                        SizedBox(
                          width: 300,
                          child: Text(
                            item.products
                                .map((e) => '${e.product.name} (${e.quantity})')
                                .join(', '),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                      DataCell(Text('${item.items}')),
                      DataCell(
                        Text(DateFormat('d MMM yyyy').format(item.date)),
                      ),
                      DataCell(Text(item.handledBy)),
                      DataCell(
                        Row(
                          children: [
                            IconButton(
                              onPressed: () => onEdit(item),
                              icon: const Icon(
                                Icons.edit_outlined,
                                color: _purple,
                              ),
                            ),
                            IconButton(
                              onPressed: () => onDelete(item),
                              icon: const Icon(
                                Icons.delete_outline_rounded,
                                color: _red,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                )
                .toList(),
          ),
        ),
      ),
    ),
  );
}

class _Meta extends StatelessWidget {
  final IconData icon;
  final String text;
  const _Meta(this.icon, this.text);

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 14, color: _muted),
      const SizedBox(width: 5),
      Flexible(
        child: Text(
          text,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 9.5, color: _muted),
        ),
      ),
    ],
  );
}

class _EmptyState extends StatelessWidget {
  final VoidCallback onAdd;
  const _EmptyState({required this.onAdd});

  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.inventory_2_outlined, size: 42, color: _muted),
        const SizedBox(height: 10),
        const Text(
          'No store movements found',
          style: TextStyle(fontWeight: FontWeight.w800, color: _ink),
        ),
        const SizedBox(height: 10),
        FilledButton.icon(
          onPressed: onAdd,
          icon: const Icon(Icons.add_rounded),
          label: const Text('Record Outgoing'),
        ),
      ],
    ),
  );
}
