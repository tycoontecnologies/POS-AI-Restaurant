from pathlib import Path
import re

emp_path = Path('lib/screens/employee_dashboard_screen.dart')
v6_path = Path('lib/screens/pos_order_screen_v6.dart')
v7_path = Path('lib/screens/pos_order_screen_v7.dart')
dash_path = Path('lib/screens/restaurant_dashboard_screen_v3.dart')

for p in [emp_path, v6_path, v7_path, dash_path]:
    if not p.exists():
        raise SystemExit(f'ERROR: missing {p}')

# ------------------------------------------------------------
# 1) CASHIER DASHBOARD: visible Table Wise / Item Wise selector
# ------------------------------------------------------------
emp = emp_path.read_text()

imports = {
    "import 'package:pos/providers/table_provider.dart';\n": "import 'package:pos/providers/auth_provider.dart';\n",
    "import 'package:shared_preferences/shared_preferences.dart';\n": "import 'package:provider/provider.dart';\n",
}
for imp, anchor in imports.items():
    if imp not in emp:
        if anchor not in emp:
            raise SystemExit(f'ERROR: employee dashboard import anchor missing for {imp.strip()}')
        emp = emp.replace(anchor, anchor + imp, 1)

if "String _cashierOrderMode = 'tableWise';" not in emp:
    anchor = "  bool _uploading = false;\n"
    if anchor not in emp:
        raise SystemExit('ERROR: employee dashboard state anchor missing')
    emp = emp.replace(anchor, anchor + "  String _cashierOrderMode = 'tableWise';\n  bool _cashierModeLoaded = false;\n", 1)

if 'Future<void> _loadCashierOrderMode(UserModel user)' not in emp:
    marker = "  Future<void> _setHidden(UserModel user, String key, bool hidden) async {\n"
    if marker not in emp:
        raise SystemExit('ERROR: employee dashboard method anchor missing')
    helpers = r'''  Future<void> _loadCashierOrderMode(UserModel user) async {
    if (_cashierModeLoaded || user.role != UserRole.cashier) return;
    _cashierModeLoaded = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString('cashier_order_mode_${user.id}');
      if (!mounted) return;
      setState(() {
        _cashierOrderMode = saved == 'itemWise' ? 'itemWise' : 'tableWise';
      });
    } catch (_) {}
  }

  Future<void> _openCashierMode(UserModel user, String mode) async {
    if (user.role != UserRole.cashier) return;
    setState(() => _cashierOrderMode = mode);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('cashier_order_mode_${user.id}', mode);
    } catch (_) {}
    if (!mounted) return;

    if (mode == 'tableWise') {
      context.go(AppRouter.tables);
      return;
    }

    final tables = context.read<TableProvider>();
    if (tables.tables.isEmpty) {
      await tables.loadTables();
    }
    if (!mounted) return;
    if (tables.tables.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No tables are available for order taking.')),
      );
      return;
    }

    // Item Wise opens the menu immediately using the first available table.
    // The POS mode bar lets the cashier switch the serving table without
    // leaving the item screen.
    final table = tables.tables.first;
    context.go('/table-order/${table.id}', extra: table);
  }

'''
    emp = emp.replace(marker, helpers + marker, 1)

# Trigger preference load once the cashier user exists.
if '_loadCashierOrderMode(user);' not in emp:
    anchor = "    if (user == null) return const Center(child: CircularProgressIndicator());\n"
    if anchor not in emp:
        raise SystemExit('ERROR: cashier user anchor missing')
    emp = emp.replace(anchor, anchor + "    if (user.role == UserRole.cashier) {\n      WidgetsBinding.instance.addPostFrameCallback((_) => _loadCashierOrderMode(user));\n    }\n", 1)

# Put selector directly below the Cashier Dashboard heading row.
if 'class _CashierOrderModeSelector extends StatelessWidget' not in emp:
    needle = "                    const SizedBox(height: 16),\n                    if (show('profile')) ...[\n"
    if needle not in emp:
        raise SystemExit('ERROR: cashier dashboard insertion anchor missing')
    insertion = """                    const SizedBox(height: 16),\n                    if (user.role == UserRole.cashier) ...[\n                      _CashierOrderModeSelector(\n                        mode: _cashierOrderMode,\n                        onTableWise: () => _openCashierMode(user, 'tableWise'),\n                        onItemWise: () => _openCashierMode(user, 'itemWise'),\n                      ),\n                      const SizedBox(height: 12),\n                    ],\n                    if (show('profile')) ...[\n"""
    emp = emp.replace(needle, insertion, 1)

    marker = "String _roleName(UserRole role) => role.name\n"
    if marker not in emp:
        raise SystemExit('ERROR: selector class insertion anchor missing')
    selector = r'''class _CashierOrderModeSelector extends StatelessWidget {
  final String mode;
  final VoidCallback onTableWise;
  final VoidCallback onItemWise;

  const _CashierOrderModeSelector({
    required this.mode,
    required this.onTableWise,
    required this.onItemWise,
  });

  @override
  Widget build(BuildContext context) {
    final itemWise = mode == 'itemWise';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.outlineLight),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: AppColors.primarySoft,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.point_of_sale_rounded, color: AppColors.primary),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Order Taking Mode', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900)),
                SizedBox(height: 2),
                Text('Choose how this cashier prefers to start an order.', style: TextStyle(fontSize: 10.5, color: AppColors.grey500)),
              ],
            ),
          ),
          const SizedBox(width: 12),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment<String>(value: 'tableWise', icon: Icon(Icons.table_restaurant_rounded, size: 17), label: Text('Table Wise')),
              ButtonSegment<String>(value: 'itemWise', icon: Icon(Icons.restaurant_menu_rounded, size: 17), label: Text('Item Wise')),
            ],
            selected: <String>{itemWise ? 'itemWise' : 'tableWise'},
            onSelectionChanged: (selection) {
              final value = selection.first;
              if (value == 'itemWise') {
                onItemWise();
              } else {
                onTableWise();
              }
            },
          ),
        ],
      ),
    );
  }
}

'''
    emp = emp.replace(marker, selector + marker, 1)

emp_path.write_text(emp)
print('OK: cashier dashboard now has visible Table Wise / Item Wise selector')
print('OK: Table Wise opens Tables; Item Wise opens menu POS and remembers cashier preference')

# ------------------------------------------------------------
# 2) POS V6: ensure the in-POS mode bar remains present
# ------------------------------------------------------------
v6 = v6_path.read_text()
if 'class _CashierModeBar extends StatelessWidget' not in v6:
    import runpy
    runpy.run_path('tools/add_cashier_table_item_mode_v17.py', run_name='__main__')
    v6 = v6_path.read_text()
if 'Table Wise' not in v6 or 'Item Wise' not in v6:
    raise SystemExit('ERROR: cashier POS mode selector still missing after V17 compatibility pass')
print('OK: existing cashier POS mode bar preserved')

# ------------------------------------------------------------
# 3) WHITE KOT CUBE: remove the actual V7 absolute white overlay
# ------------------------------------------------------------
v7 = v7_path.read_text()
old_overlay = r'''        // Do not show a disabled PRINT BILL action before the order reaches
        // the served/checkout stage. The underlying V6 screen remains intact.
        if (hasItems && !served)
          Positioned(
            right: 14,
            bottom: 8,
            width: 187,
            height: 58,
            child: IgnorePointer(
              child: ColoredBox(color: Colors.white),
            ),
          ),
'''
if old_overlay in v7:
    v7 = v7.replace(old_overlay, '', 1)
    print('OK: removed V7 white absolute overlay that covered KOT/footer')
else:
    # tolerate formatted/local variants, but remove only the specific white IgnorePointer block
    pattern = re.compile(
        r"\s*if \(hasItems && !served\)\s*Positioned\(\s*right:\s*14,\s*bottom:\s*8,\s*width:\s*187,\s*height:\s*58,\s*child:\s*IgnorePointer\(\s*child:\s*ColoredBox\(color:\s*Colors\.white\),\s*\),\s*\),",
        re.S,
    )
    v7, count = pattern.subn('', v7, count=1)
    if count:
        print('OK: removed formatted V7 white KOT/footer overlay')
    else:
        print('INFO: V7 white overlay already absent')
v7_path.write_text(v7)

# ------------------------------------------------------------
# 4) KITCHEN PERFORMANCE: bind readable KOT id to visible labels only
# ------------------------------------------------------------
dash = dash_path.read_text()
ks = dash.find('class _KitchenCard')
ke = dash.find('class _AlertsCard', ks)
if ks < 0 or ke < 0:
    raise SystemExit('ERROR: Kitchen Performance anchors missing')
block = dash[ks:ke]

# Keep raw ids for navigation/data; replace only display labels/variables.
replacements = 0
pairs = [
    (r"Text\(\s*doc\.id\s*,", "Text(_readableKitchenId(doc),"),
    (r"Text\(\s*'\#\$\{doc\.id\}'\s*,", "Text(_readableKitchenId(doc),"),
    (r"Text\(\s*'\$\{doc\.id\}'\s*,", "Text(_readableKitchenId(doc),"),
]
for pattern, repl in pairs:
    block, n = re.subn(pattern, repl, block)
    replacements += n

# Common local variants derive a display variable from doc.id.
for varname in ['displayId', 'receiptId', 'kotId', 'orderLabel', 'receiptLabel']:
    pattern = rf"final\s+{varname}\s*=\s*doc\.id\s*;"
    repl = f"final {varname} = _readableKitchenId(doc);"
    block, n = re.subn(pattern, repl, block)
    replacements += n

# Common visible combined title form: '#$orderId • Table ...'
block, n = re.subn(
    r"'\#\$\{doc\.id\}\s*•",
    "'${_readableKitchenId(doc)} •",
    block,
)
replacements += n

# If helper is still unused, report exact doc.id lines for the next inspection,
# but do not alter navigation/data ids blindly.
if replacements == 0:
    print('INFO: no direct visible doc.id label found; showing KitchenCard doc.id lines:')
    for line in block.splitlines():
        if 'doc.id' in line:
            print('  ', line.strip())
else:
    print(f'OK: Kitchen Performance readable KOT id bound to {replacements} visible label(s)')

dash = dash[:ks] + block + dash[ke:]
dash_path.write_text(dash)

print('ONLY touched employee dashboard, cashier POS V6/V7, and Kitchen Performance display binding')
print('NO auth, billing lifecycle, table lifecycle, inventory, CRM, MPS, PM2, or Nginx changes')
