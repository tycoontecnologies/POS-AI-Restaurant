from pathlib import Path

P = Path('lib/screens/pos_order_screen_v6.dart')
if not P.exists():
    raise SystemExit('ERROR: cashier POS source missing')

s = P.read_text()
orig = s

# 1) SharedPreferences import
imp = "import 'package:shared_preferences/shared_preferences.dart';\n"
if imp not in s:
    anchor = "import 'package:provider/provider.dart';\n"
    if anchor not in s:
        raise SystemExit('ERROR: provider import anchor missing')
    s = s.replace(anchor, anchor + imp, 1)

# 2) Mode enum before screen class
if 'enum _CashierOrderMode' not in s:
    marker = 'class TableOrderScreen extends StatefulWidget {'
    if marker not in s:
        raise SystemExit('ERROR: TableOrderScreen anchor missing')
    enum_block = "enum _CashierOrderMode { tableWise, itemWise }\n\n"
    s = s.replace(marker, enum_block + marker, 1)

# 3) State fields
field_anchor = "  bool _busy = false;\n"
if '_orderMode' not in s:
    if field_anchor not in s:
        raise SystemExit('ERROR: busy field anchor missing')
    s = s.replace(
        field_anchor,
        field_anchor + "  _CashierOrderMode _orderMode = _CashierOrderMode.tableWise;\n  bool _modeLoaded = false;\n",
        1,
    )

# 4) Load preference from didChangeDependencies
if '_loadOrderModePreference();' not in s:
    needle = "    final vendorId = categories.authProvider?.currentUser?.id;\n"
    if needle not in s:
        raise SystemExit('ERROR: didChangeDependencies vendor anchor missing')
    s = s.replace(needle, needle + "    _loadOrderModePreference();\n", 1)

# 5) Add preference helpers before categories method
if 'Future<void> _loadOrderModePreference()' not in s:
    marker = '  List<String> _categories(List<Product> products) {'
    if marker not in s:
        raise SystemExit('ERROR: categories method anchor missing')
    helpers = r'''  Future<void> _loadOrderModePreference() async {
    if (_modeLoaded) return;
    _modeLoaded = true;
    try {
      final user = context.read<AuthProvider>().currentUser;
      if (user == null) return;
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('cashier_order_mode_${user.id}');
      if (!mounted) return;
      setState(() {
        _orderMode = raw == 'itemWise'
            ? _CashierOrderMode.itemWise
            : _CashierOrderMode.tableWise;
      });
    } catch (_) {}
  }

  Future<void> _setOrderMode(_CashierOrderMode mode) async {
    if (_orderMode == mode) return;
    setState(() => _orderMode = mode);
    try {
      final user = context.read<AuthProvider>().currentUser;
      if (user == null) return;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        'cashier_order_mode_${user.id}',
        mode == _CashierOrderMode.itemWise ? 'itemWise' : 'tableWise',
      );
    } catch (_) {}
  }

  void _switchTable(RestaurantTable table) {
    if (table.id == widget.table.id) return;
    context.go('/table-order/${table.id}', extra: table);
  }

'''
    s = s.replace(marker, helpers + marker, 1)

# 6) Add mode bar into menu area below cashier header
if '_CashierModeBar(' not in s:
    needle = '''        _CashierHeader(
          table: widget.table,
          onBack: () => context.go('/tables'),
          onSearch: (v) => setState(() => _search = v),
        ),
'''
    if needle not in s:
        raise SystemExit('ERROR: CashierHeader block anchor missing')
    addition = needle + '''        _CashierModeBar(
          mode: _orderMode,
          currentTable: widget.table,
          tables: context.watch<TableProvider>().tables,
          onModeChanged: _setOrderMode,
          onTableChanged: _switchTable,
        ),
'''
    s = s.replace(needle, addition, 1)

# 7) Add widget before CashierHeader class
if 'class _CashierModeBar extends StatelessWidget' not in s:
    marker = 'class _CashierHeader extends StatelessWidget {'
    if marker not in s:
        raise SystemExit('ERROR: CashierHeader class anchor missing')
    widget = r'''class _CashierModeBar extends StatelessWidget {
  final _CashierOrderMode mode;
  final RestaurantTable currentTable;
  final List<RestaurantTable> tables;
  final ValueChanged<_CashierOrderMode> onModeChanged;
  final ValueChanged<RestaurantTable> onTableChanged;

  const _CashierModeBar({
    required this.mode,
    required this.currentTable,
    required this.tables,
    required this.onModeChanged,
    required this.onTableChanged,
  });

  @override
  Widget build(BuildContext context) {
    final itemWise = mode == _CashierOrderMode.itemWise;
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: const Color(0xFFF3F0FF),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _ModeChoice(
                  icon: Icons.table_restaurant_rounded,
                  label: 'Table Wise',
                  selected: !itemWise,
                  onTap: () => onModeChanged(_CashierOrderMode.tableWise),
                ),
                _ModeChoice(
                  icon: Icons.restaurant_menu_rounded,
                  label: 'Item Wise',
                  selected: itemWise,
                  onTap: () => onModeChanged(_CashierOrderMode.itemWise),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 180),
              child: itemWise
                  ? Row(
                      key: const ValueKey('itemWise'),
                      children: [
                        const Text(
                          'Serving',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppColors.grey500,
                          ),
                        ),
                        const SizedBox(width: 8),
                        DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: currentTable.id,
                            borderRadius: BorderRadius.circular(12),
                            items: tables
                                .map(
                                  (t) => DropdownMenuItem<String>(
                                    value: t.id,
                                    child: Text(
                                      'Table ${t.tableNumber}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                )
                                .toList(),
                            onChanged: (id) {
                              if (id == null) return;
                              for (final table in tables) {
                                if (table.id == id) {
                                  onTableChanged(table);
                                  break;
                                }
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 10),
                        const Text(
                          'Pick items first and switch tables without leaving POS',
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.grey500,
                          ),
                        ),
                      ],
                    )
                  : Row(
                      key: const ValueKey('tableWise'),
                      children: [
                        Icon(
                          Icons.check_circle_outline_rounded,
                          size: 16,
                          color: AppColors.primary,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Table ${currentTable.tableNumber} selected • Traditional table-first ordering',
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.grey500,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ModeChoice extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _ModeChoice({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(9),
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: selected ? AppColors.primary : Colors.transparent,
        borderRadius: BorderRadius.circular(9),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 16,
            color: selected ? Colors.white : AppColors.grey500,
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: selected ? Colors.white : AppColors.grey700,
            ),
          ),
        ],
      ),
    ),
  );
}

'''
    s = s.replace(marker, widget + marker, 1)

if s == orig:
    print('INFO: cashier mode patch already applied')
else:
    P.write_text(s)

print('OK: cashier now supports Table Wise and Item Wise modes')
print('OK: mode preference persists per logged-in cashier')
print('OK: Item Wise mode can switch active table without leaving POS')
print('OK: existing KOT / serve / bill / checkout lifecycle unchanged')
print('ONLY lib/screens/pos_order_screen_v6.dart modified')
