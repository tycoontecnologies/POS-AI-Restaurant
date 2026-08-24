import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:pos/providers/table_order_provider.dart';

const _purple = Color(0xFF6C3BFF);
const _line = Color(0xFFE2E8F0);
const _ink = Color(0xFF0F172A);
const _muted = Color(0xFF64748B);

class KitchenKotScreen extends StatefulWidget {
  const KitchenKotScreen({super.key});

  @override
  State<KitchenKotScreen> createState() => _KitchenKotScreenState();
}

class _KitchenKotScreenState extends State<KitchenKotScreen> {
  String _filter = 'active';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<TableOrderProvider>().loadAllTableOrders();
    });
  }

  String _kotNo(Map<String, dynamic> info) {
    final raw = info['createdAt'];
    DateTime d = DateTime.now();
    if (raw is DateTime) d = raw;
    try {
      if (raw != null && raw.runtimeType.toString().contains('Timestamp')) {
        d = (raw as dynamic).toDate() as DateTime;
      }
    } catch (_) {}
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(d.day)}${two(d.month)}${two(d.year % 100)}${two(d.hour)}${two(d.minute)}${two(d.second)}';
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'making': return const Color(0xFFF59E0B);
      case 'served':
      case 'ready': return const Color(0xFF10B981);
      default: return _purple;
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'making': return 'ORDER IN MAKING';
      case 'served':
      case 'ready': return 'READY TO SERVE';
      default: return 'NEW KOT';
    }
  }

  bool _visible(String status) {
    if (_filter == 'all') return true;
    if (_filter == 'ready') return status == 'served' || status == 'ready';
    if (_filter == 'making') return status == 'making';
    return status != 'served' && status != 'ready';
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TableOrderProvider>();
    final tableIds = provider.getTablesWithOrders();
    final visible = tableIds.where((id) => _visible(provider.getOrderStatus(id))).toList();

    return ColoredBox(
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Kitchen KOT', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: _ink)),
              SizedBox(height: 3),
              Text('Live kitchen queue • Start making • Ready to serve', style: TextStyle(fontSize: 11.5, color: _muted)),
            ])),
            OutlinedButton.icon(
              onPressed: () => provider.loadAllTableOrders(),
              style: OutlinedButton.styleFrom(side: const BorderSide(color: _line), foregroundColor: _purple, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9))),
              icon: const Icon(Icons.refresh_rounded, size: 17),
              label: const Text('Refresh'),
            ),
          ]),
          const SizedBox(height: 16),
          Wrap(spacing: 8, runSpacing: 8, children: [
            _FilterChip(label: 'Active', selected: _filter == 'active', onTap: () => setState(() => _filter = 'active')),
            _FilterChip(label: 'Making', selected: _filter == 'making', onTap: () => setState(() => _filter = 'making')),
            _FilterChip(label: 'Ready', selected: _filter == 'ready', onTap: () => setState(() => _filter = 'ready')),
            _FilterChip(label: 'All', selected: _filter == 'all', onTap: () => setState(() => _filter = 'all')),
          ]),
          const SizedBox(height: 16),
          Expanded(
            child: visible.isEmpty
                ? const Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.soup_kitchen_outlined, size: 44, color: Color(0xFFCBD5E1)),
                    SizedBox(height: 10),
                    Text('No KOTs in this queue', style: TextStyle(fontWeight: FontWeight.w700, color: _muted)),
                  ]))
                : LayoutBuilder(builder: (_, c) {
                    final columns = c.maxWidth >= 1250 ? 4 : c.maxWidth >= 900 ? 3 : c.maxWidth >= 620 ? 2 : 1;
                    final width = (c.maxWidth - ((columns - 1) * 12)) / columns;
                    return SingleChildScrollView(
                      child: Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: visible.map((tableId) {
                          final status = provider.getOrderStatus(tableId);
                          final info = provider.getOrderInfo(tableId);
                          final items = provider.getOrderForTable(tableId);
                          return SizedBox(
                            width: width,
                            child: _KotCard(
                              tableId: tableId,
                              kotNo: _kotNo(info),
                              status: status,
                              label: _statusLabel(status),
                              accent: _statusColor(status),
                              waiter: (info['waiterName'] ?? 'Unassigned').toString(),
                              guests: (info['guestCount'] ?? '—').toString(),
                              items: items.map((e) => '${e.quantity} × ${e.displayName}').toList(),
                              total: items.fold<double>(0, (sum, e) => sum + e.totalPrice),
                              onAction: status == 'making'
                                  ? () => provider.setOrderStatus(tableId, 'served')
                                  : (status == 'served' || status == 'ready')
                                      ? null
                                      : () => provider.setOrderStatus(tableId, 'making'),
                            ),
                          );
                        }).toList(),
                      ),
                    );
                  }),
          ),
        ]),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _FilterChip({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(
            color: selected ? const Color(0xFFF3EFFF) : Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: selected ? _purple : _line),
          ),
          child: Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: selected ? _purple : const Color(0xFF334155))),
        ),
      );
}

class _KotCard extends StatelessWidget {
  final String tableId;
  final String kotNo;
  final String status;
  final String label;
  final Color accent;
  final String waiter;
  final String guests;
  final List<String> items;
  final double total;
  final VoidCallback? onAction;

  const _KotCard({required this.tableId, required this.kotNo, required this.status, required this.label, required this.accent, required this.waiter, required this.guests, required this.items, required this.total, required this.onAction});

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _line),
          boxShadow: const [BoxShadow(color: Color(0x0B000000), blurRadius: 10, offset: Offset(0, 4))],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(color: accent.withValues(alpha: .08), borderRadius: const BorderRadius.vertical(top: Radius.circular(12))),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Container(width: 8, height: 8, decoration: BoxDecoration(shape: BoxShape.circle, color: accent)),
                const SizedBox(width: 7),
                Expanded(child: Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: accent))),
                Text('KOT $kotNo', style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: _muted)),
              ]),
              const SizedBox(height: 9),
              Text('Table $tableId', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: _ink)),
              const SizedBox(height: 2),
              Text('$waiter • $guests guests', style: const TextStyle(fontSize: 9.5, color: _muted)),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.all(13),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('ITEMS', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: _muted, letterSpacing: .8)),
              const SizedBox(height: 8),
              ...items.map((item) => Padding(
                    padding: const EdgeInsets.only(bottom: 7),
                    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Icon(Icons.circle, size: 5, color: _ink),
                      const SizedBox(width: 7),
                      Expanded(child: Text(item, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: _ink))),
                    ]),
                  )),
              const Divider(height: 18),
              Row(children: [
                const Expanded(child: Text('Order total', style: TextStyle(fontSize: 10, color: _muted))),
                Text('Rs ${total.toStringAsFixed(0)}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: _ink)),
              ]),
              const SizedBox(height: 12),
              if (onAction != null)
                SizedBox(
                  width: double.infinity,
                  height: 42,
                  child: FilledButton.icon(
                    onPressed: onAction,
                    style: FilledButton.styleFrom(backgroundColor: accent, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                    icon: Icon(status == 'making' ? Icons.check_circle_outline_rounded : Icons.soup_kitchen_outlined, size: 17),
                    label: Text(status == 'making' ? 'READY TO SERVE' : 'START MAKING', style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w900)),
                  ),
                )
              else
                Container(
                  height: 42,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: const Color(0xFFE8FFF4), borderRadius: BorderRadius.circular(8)),
                  child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 17),
                    SizedBox(width: 7),
                    Text('READY FOR SERVICE', style: TextStyle(color: Color(0xFF047857), fontSize: 10.5, fontWeight: FontWeight.w900)),
                  ]),
                ),
            ]),
          ),
        ]),
      );
}
