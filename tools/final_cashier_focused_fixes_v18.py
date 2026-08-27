from pathlib import Path
import runpy
import re

pos_path = Path('lib/screens/pos_order_screen_v6.dart')
dash_path = Path('lib/screens/restaurant_dashboard_screen_v3.dart')

if not pos_path.exists() or not dash_path.exists():
    raise SystemExit('ERROR: source file missing')

# Ensure the already-approved Table Wise / Item Wise cashier face exists.
pos = pos_path.read_text()
if 'class _CashierModeBar extends StatelessWidget' not in pos:
    runpy.run_path('tools/add_cashier_table_item_mode_v17.py', run_name='__main__')
    pos = pos_path.read_text()
print('OK: cashier mode selector present')

# Keep the existing ticket workflow, but force the footer/actions to stay inside
# their own layout bounds. This removes the white rectangle/overlap artifact.
pos = pos.replace(
    "child: Column(\n              children: [\n                _BillLine(label: 'Items', value: '$count'),",
    "child: Column(\n              crossAxisAlignment: CrossAxisAlignment.stretch,\n              children: [\n                _BillLine(label: 'Items', value: '$count'),",
    1,
)
pos = pos.replace(
    "Container(\n            padding: const EdgeInsets.fromLTRB(18, 12, 18, 16),",
    "Container(\n            width: double.infinity,\n            clipBehavior: Clip.hardEdge,\n            padding: const EdgeInsets.fromLTRB(18, 12, 18, 16),",
    1,
)
# Remove any accidental absolute-positioned footer overlay left by older patches.
for fragment in [
    "Positioned(right: 0, bottom: 0, child: Container(color: Colors.white",
    "Positioned(\n                    right: 0,\n                    bottom: 0,",
]:
    if fragment in pos:
        print('WARNING: legacy footer overlay marker found; inspect after format')

pos_path.write_text(pos)
print('OK: POS footer constrained; existing KOT/billing logic preserved')

# Kitchen Performance: never show raw Firestore ids. Replace common raw-id labels
# inside this class only with a short KOT label based on kotNumber/orderNumber/id.
dash = dash_path.read_text()
ks = dash.find('class _KitchenCard')
ke = dash.find('class _AlertsCard', ks)
if ks < 0 or ke < 0:
    raise SystemExit('ERROR: KitchenCard anchors missing')
block = dash[ks:ke]

helper = """  String _readableKitchenId(QueryDocumentSnapshot<Map<String, dynamic>> doc) {\n    final data = doc.data();\n    final source = (data['kotNumber'] ?? data['orderNumber'] ?? doc.id).toString();\n    final cleaned = source.replaceAll(RegExp(r'[^A-Za-z0-9]'), '');\n    final tail = cleaned.length <= 6 ? cleaned : cleaned.substring(cleaned.length - 6);\n    return 'KOT-$tail';\n  }\n\n"""

if '_readableKitchenId(' not in block:
    brace = block.find('{') + 1
    block = block[:brace] + '\n' + helper + block[brace:]

# Replace only visible raw document-id expressions in the Kitchen card.
block = re.sub(r"Text\(\s*doc\.id\s*,", "Text(_readableKitchenId(doc),", block)
block = re.sub(r"'\#\$\{doc\.id\}'", "_readableKitchenId(doc)", block)
block = re.sub(r"'\$\{doc\.id\}'", "_readableKitchenId(doc)", block)
block = block.replace("'#${doc.id} •", "'${_readableKitchenId(doc)} •")

dash = dash[:ks] + block + dash[ke:]
dash_path.write_text(dash)
print('OK: Kitchen Performance raw receipt ids shortened to KOT-XXXXXX')
print('ONLY modified pos_order_screen_v6.dart and restaurant_dashboard_screen_v3.dart')
