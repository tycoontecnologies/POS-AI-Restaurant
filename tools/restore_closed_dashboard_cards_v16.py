from pathlib import Path

P = Path('lib/screens/restaurant_dashboard_screen_v3.dart')
if not P.exists():
    raise SystemExit('ERROR: dashboard source missing')

s = P.read_text()

start = s.find('  Future<void> _customize() async {')
end = s.find('  bool _sameDay(', start)
if start < 0 or end < 0:
    raise SystemExit('ERROR: dashboard customize function anchors not found')

new_func = r'''  Future<void> _customize() async {
    final user = context.read<AuthProvider>().currentUser;
    if (user == null || !user.canAddWidgets) return;

    const allKpis = <String, String>{
      'sales': 'Total Sales',
      'orders': 'Orders',
      'avg': 'Average Bill',
      'kitchenTime': 'Kitchen Time',
      'tables': 'Active Tables',
      'pra': 'PRA Finalized',
    };

    final selectedSections = Set<String>.from(_visible);
    final selectedKpis = Set<String>.from(_kpiOrder);

    final result = await showDialog<Map<String, Set<String>>>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (_, setModal) => AlertDialog(
          backgroundColor: Colors.white,
          title: const Text('Customize Dashboard'),
          content: SizedBox(
            width: 520,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 560),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Top Cards',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        color: _muted,
                      ),
                    ),
                    const SizedBox(height: 6),
                    ...allKpis.entries.map(
                      (entry) => CheckboxListTile(
                        dense: true,
                        value: selectedKpis.contains(entry.key),
                        title: Text(
                          entry.value,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        onChanged: (value) => setModal(() {
                          if (value == true) {
                            selectedKpis.add(entry.key);
                          } else {
                            selectedKpis.remove(entry.key);
                          }
                        }),
                      ),
                    ),
                    const Divider(height: 22),
                    const Text(
                      'Dashboard Widgets',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        color: _muted,
                      ),
                    ),
                    const SizedBox(height: 6),
                    ..._allSections.entries.map(
                      (entry) => CheckboxListTile(
                        dense: true,
                        value: selectedSections.contains(entry.key),
                        title: Text(
                          entry.value,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        onChanged: (value) => setModal(() {
                          if (value == true) {
                            selectedSections.add(entry.key);
                          } else {
                            selectedSections.remove(entry.key);
                          }
                        }),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => setModal(() {
                selectedSections
                  ..clear()
                  ..addAll(_allSections.keys);
                selectedKpis
                  ..clear()
                  ..addAll(allKpis.keys);
              }),
              child: const Text('Show all'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(
                dialogContext,
                <String, Set<String>>{
                  'sections': Set<String>.from(selectedSections),
                  'kpis': Set<String>.from(selectedKpis),
                },
              ),
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );

    if (!mounted) return;

    if (result != null) {
      const canonicalKpis = <String>[
        'sales',
        'orders',
        'avg',
        'kitchenTime',
        'tables',
        'pra',
      ];
      final wantedKpis = result['kpis'] ?? <String>{};

      setState(() {
        _visible = result['sections'] ?? _allSections.keys.toSet();

        // Keep the user's existing KPI order for cards that are still visible,
        // then append any restored cards in canonical order.
        _kpiOrder = [
          ..._kpiOrder.where(wantedKpis.contains),
          ...canonicalKpis.where(
            (id) => wantedKpis.contains(id) && !_kpiOrder.contains(id),
          ),
        ];
      });

      await _savePrefs();
    }

    if (mounted &&
        GoRouterState.of(context).uri.queryParameters.containsKey('customize')) {
      context.go(AppRouter.dashboard);
    }
  }

'''

s = s[:start] + new_func + s[end:]
P.write_text(s)

print('OK: Widgets customizer now lists all six top KPI cards')
print('OK: closed KPI cards can be restored individually')
print('OK: closed standard dashboard widgets can still be restored')
print('OK: Show all restores every dashboard card and widget')
print('OK: restored KPI cards preserve existing order and append cleanly')
print('ONLY lib/screens/restaurant_dashboard_screen_v3.dart modified')
