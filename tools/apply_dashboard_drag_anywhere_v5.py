from pathlib import Path

p=Path('lib/screens/restaurant_dashboard_screen_v3.dart')
s=p.read_text()
old="""                    final orderedIds = _sectionOrder
                        .where(widgets.containsKey)
                        .toList();
                    return Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: orderedIds.map((id) {
                        final child = widgets[id]!;
                        return DragTarget<String>(
                          onWillAcceptWithDetails: (d) =>
                              d.data != id && _sectionOrder.contains(d.data),
                          onAcceptWithDetails: (d) {
                            final from = _sectionOrder.indexOf(d.data);
                            final to = _sectionOrder.indexOf(id);
                            if (from < 0 || to < 0 || from == to) return;
                            setState(() {
                              final moved = _sectionOrder.removeAt(from);
                              _sectionOrder.insert(to, moved);
                            });
                            _savePrefs();
                          },
                          builder: (_, candidate, __) =>
                              LongPressDraggable<String>(
                                data: id,
                                feedback: Material(
                                  color: Colors.transparent,
                                  child: ConstrainedBox(
                                    constraints: BoxConstraints(
                                      maxWidth: constraints.maxWidth * .75,
                                    ),
                                    child: Opacity(opacity: .90, child: child),
                                  ),
                                ),
                                childWhenDragging: Opacity(
                                  opacity: .28,
                                  child: child,
                                ),
                                child: child,
                              ),
                        );
                      }).toList(),
                    );
"""
new="""                    final orderedIds = _sectionOrder
                        .where(widgets.containsKey)
                        .toList();

                    void moveWidget(String dragged, int insertionIndex) {
                      final from = _sectionOrder.indexOf(dragged);
                      if (from < 0) return;
                      setState(() {
                        final moved = _sectionOrder.removeAt(from);
                        var to = insertionIndex;
                        if (from < to) to--;
                        to = to.clamp(0, _sectionOrder.length);
                        _sectionOrder.insert(to, moved);
                      });
                      _savePrefs();
                    }

                    Widget dropZone(int index) => DragTarget<String>(
                          onWillAcceptWithDetails: (d) =>
                              _sectionOrder.contains(d.data),
                          onAcceptWithDetails: (d) => moveWidget(d.data, index),
                          builder: (_, candidates, __) => AnimatedContainer(
                            duration: const Duration(milliseconds: 120),
                            width: candidates.isEmpty ? 6 : 28,
                            height: 330,
                            decoration: BoxDecoration(
                              color: candidates.isEmpty
                                  ? Colors.transparent
                                  : _purple.withValues(alpha: .12),
                              borderRadius: BorderRadius.circular(12),
                              border: candidates.isEmpty
                                  ? null
                                  : Border.all(color: _purple, width: 2),
                            ),
                          ),
                        );

                    final children = <Widget>[];
                    for (var i = 0; i < orderedIds.length; i++) {
                      final id = orderedIds[i];
                      final child = widgets[id]!;
                      children.add(dropZone(_sectionOrder.indexOf(id)));
                      children.add(
                        DragTarget<String>(
                          onWillAcceptWithDetails: (d) =>
                              d.data != id && _sectionOrder.contains(d.data),
                          onAcceptWithDetails: (d) =>
                              moveWidget(d.data, _sectionOrder.indexOf(id)),
                          builder: (_, candidate, __) =>
                              LongPressDraggable<String>(
                                data: id,
                                feedback: Material(
                                  color: Colors.transparent,
                                  child: ConstrainedBox(
                                    constraints: BoxConstraints(
                                      maxWidth: constraints.maxWidth * .75,
                                    ),
                                    child: Opacity(opacity: .90, child: child),
                                  ),
                                ),
                                childWhenDragging:
                                    Opacity(opacity: .22, child: child),
                                child: MouseRegion(
                                  cursor: SystemMouseCursors.grab,
                                  child: child,
                                ),
                              ),
                        ),
                      );
                    }
                    children.add(dropZone(_sectionOrder.length));
                    return Wrap(
                      spacing: 3,
                      runSpacing: 12,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: children,
                    );
"""
if old not in s:
    raise SystemExit('ERROR: dashboard widget reorder block not found; source not changed')
s=s.replace(old,new,1)
p.write_text(s)
print('OK: dashboard widgets can be dragged/reordered into any position')
print('OK: widget order still persists through existing dashboardPreferences')
print('ONLY restaurant_dashboard_screen_v3.dart changed')
