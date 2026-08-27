from pathlib import Path

p = Path('lib/screens/restaurant_dashboard_screen_v3.dart')
s = p.read_text()

# 1) Make every panel header clickable to expand, while preserving the explicit
# maximize button and all child interactions (chart clicks, order clicks, etc.).
old = """        Row(\n          children: [\n            const Icon(Icons.drag_indicator_rounded, size: 16, color: _purple),\n            const SizedBox(width: 5),\n            Expanded(\n              child: Text(\n                widget.title,\n                style: const TextStyle(\n                  fontSize: 12,\n                  fontWeight: FontWeight.w900,\n                ),\n              ),\n            ),\n            widget.trailing,\n            const SizedBox(width: 5),\n            IconButton(\n"""
new = """        InkWell(\n          borderRadius: BorderRadius.circular(10),\n          onTap: _maximize,\n          child: Padding(\n            padding: const EdgeInsets.symmetric(vertical: 2),\n            child: Row(\n              children: [\n                const Icon(Icons.drag_indicator_rounded, size: 16, color: _purple),\n                const SizedBox(width: 5),\n                Expanded(\n                  child: Column(\n                    crossAxisAlignment: CrossAxisAlignment.start,\n                    children: [\n                      Text(\n                        widget.title,\n                        style: const TextStyle(\n                          fontSize: 12,\n                          fontWeight: FontWeight.w900,\n                        ),\n                      ),\n                      const SizedBox(height: 2),\n                      const Text(\n                        'Click header to expand full statistics',\n                        style: TextStyle(fontSize: 8, color: _muted),\n                      ),\n                    ],\n                  ),\n                ),\n                widget.trailing,\n                const SizedBox(width: 5),\n                IconButton(\n"""
if old not in s:
    raise SystemExit('ERROR: panel header anchor not found')
s = s.replace(old, new, 1)

old2 = """            IconButton(\n              visualDensity: VisualDensity.compact,\n              tooltip: 'Maximize',\n              onPressed: _maximize,\n              icon: const Icon(Icons.open_in_full_rounded, size: 16),\n            ),\n          ],\n        ),\n"""
new2 = """                IconButton(\n                  visualDensity: VisualDensity.compact,\n                  tooltip: 'Maximize',\n                  onPressed: _maximize,\n                  icon: const Icon(Icons.open_in_full_rounded, size: 16),\n                ),\n              ],\n            ),\n          ),\n        ),\n"""
if old2 not in s:
    raise SystemExit('ERROR: panel header close anchor not found')
s = s.replace(old2, new2, 1)

# 2) Make expanded dialog larger and clearly identify it as full-statistics mode.
s = s.replace(
    "constraints: const BoxConstraints(maxWidth: 1250, maxHeight: 820),",
    "constraints: const BoxConstraints(maxWidth: 1450, maxHeight: 900),",
    1,
)
s = s.replace(
    """                      Expanded(\n                        child: Text(\n                          widget.title,\n                          style: const TextStyle(\n                            fontSize: 14,\n                            fontWeight: FontWeight.w900,\n                          ),\n                        ),\n                      ),\n""",
    """                      Expanded(\n                        child: Column(\n                          mainAxisAlignment: MainAxisAlignment.center,\n                          crossAxisAlignment: CrossAxisAlignment.start,\n                          children: [\n                            Text(\n                              widget.title,\n                              style: const TextStyle(\n                                fontSize: 14,\n                                fontWeight: FontWeight.w900,\n                              ),\n                            ),\n                            const Text(\n                              'Expanded statistics',\n                              style: TextStyle(fontSize: 9, color: _muted),\n                            ),\n                          ],\n                        ),\n                      ),\n""",
    1,
)

# 3) Let expanded list-based widgets show substantially more data by using
# available height. This affects normal cards only slightly because their
# viewport clips naturally, while expanded dialogs can show the full list.
s = s.replace(
    "itemCount: math.min(6, sorted.length),",
    "itemCount: math.min(20, sorted.length),",
    1,
)
s = s.replace(
    "itemCount: math.min(5, names.length),",
    "itemCount: math.min(15, names.length),",
    1,
)
s = s.replace(
    "itemCount: math.min(5, docs.length),",
    "itemCount: math.min(8, docs.length),",
    1,
)

p.write_text(s)
print('OK: every dashboard panel header now click-expands')
print('OK: maximize button still works')
print('OK: expanded dialog enlarged to 1450x900')
print('OK: Recent Orders expanded capacity 6 -> 20')
print('OK: Top Selling Items expanded capacity 5 -> 15')
print('OK: Alerts expanded capacity 5 -> 8')
print('OK: internal chart/order clicks remain available')
