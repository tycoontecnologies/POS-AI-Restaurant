from pathlib import Path
import re

P = Path('lib/screens/restaurant_dashboard_screen_v3.dart')
if not P.exists():
    raise SystemExit('ERROR: dashboard source missing')

s = P.read_text()
orig = s

# ------------------------------------------------------------------
# 1) True content-driven dashboard layout.
#    Wrap lays widgets out in rows, so one tall widget forces every
#    widget in the same row to reserve that height. This is exactly the
#    large blank-space problem visible after minimizing a neighbour.
#    Replace the standard-widget Wrap with responsive vertical columns.
#    Each column now compacts independently like a masonry dashboard.
# ------------------------------------------------------------------
if 'DASHBOARD_MASONRY_V14' not in s:
    start = s.find('                    final orderedIds = _sectionOrder')
    if start < 0:
        raise SystemExit('ERROR: ordered widget section anchor not found')

    end_marker = '                  },\n                ),\n              ],'
    end = s.find(end_marker, start)
    if end < 0:
        raise SystemExit('ERROR: standard dashboard layout end anchor not found')

    block = s[start:end]

    # Find the final `return Wrap(...)` in this widget section, keeping
    # everything before it (widget map + orderedIds) intact.
    return_pos = block.find('                    return Wrap(')
    if return_pos < 0:
        raise SystemExit('ERROR: standard dashboard Wrap not found')

    prefix = block[:return_pos]
    replacement = r'''                    // DASHBOARD_MASONRY_V14
                    // Independent vertical columns remove row-height holes.
                    final columnCount = wide
                        ? 3
                        : medium
                        ? 2
                        : 1;
                    final columns = List.generate(
                      columnCount,
                      (_) => <Widget>[],
                    );

                    for (var i = 0; i < orderedIds.length; i++) {
                      final id = orderedIds[i];
                      final child = widgets[id]!;
                      final tile = DragTarget<String>(
                        onWillAcceptWithDetails: (d) =>
                            d.data != id && _sectionOrder.contains(d.data),
                        onAcceptWithDetails: (d) {
                          final from = _sectionOrder.indexOf(d.data);
                          final to = _sectionOrder.indexOf(id);
                          if (from < 0 || to < 0 || from == to) return;
                          setState(() {
                            final moved = _sectionOrder.removeAt(from);
                            var insertAt = to;
                            if (from < to) insertAt--;
                            insertAt = insertAt.clamp(0, _sectionOrder.length);
                            _sectionOrder.insert(insertAt, moved);
                          });
                          _savePrefs();
                        },
                        builder: (_, candidate, __) => Draggable<String>(
                          data: id,
                          dragAnchorStrategy: pointerDragAnchorStrategy,
                          feedback: Material(
                            color: Colors.transparent,
                            child: ConstrainedBox(
                              constraints: BoxConstraints(
                                maxWidth: constraints.maxWidth / columnCount,
                              ),
                              child: Opacity(opacity: .90, child: child),
                            ),
                          ),
                          childWhenDragging: Opacity(
                            opacity: .22,
                            child: child,
                          ),
                          child: MouseRegion(
                            cursor: SystemMouseCursors.grab,
                            child: child,
                          ),
                        ),
                      );

                      columns[i % columnCount].add(
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: tile,
                        ),
                      );
                    }

                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (var i = 0; i < columnCount; i++) ...[
                          if (i > 0) const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: columns[i],
                            ),
                          ),
                        ],
                      ],
                    );
'''
    block = prefix + replacement
    s = s[:start] + block + s[end:]
    print('OK: standard dashboard switched from row Wrap to compact masonry columns')
else:
    print('OK: masonry dashboard already installed')

# ------------------------------------------------------------------
# 2) Per-widget resize anchor.
#    V13 gave each expanded panel a 230px body. Make that body height
#    user-resizable from a visible bottom-right handle. Minimized panels
#    still collapse to header-only, so resizing never creates a ghost slot.
# ------------------------------------------------------------------
if 'DASHBOARD_RESIZE_V14' not in s:
    # There should be one state field named `minimized` in the reusable panel.
    if 'bool minimized = false;' not in s:
        raise SystemExit('ERROR: reusable panel minimized state not found')
    s = s.replace(
        'bool minimized = false;',
        'bool minimized = false;\n  double _bodyHeight = 230; // DASHBOARD_RESIZE_V14',
        1,
    )

    body_old = '          SizedBox(height: 230, child: widget.child),\n'
    if body_old not in s:
        raise SystemExit('ERROR: V13 panel body anchor not found')

    body_new = r'''          SizedBox(
            height: _bodyHeight,
            child: Stack(
              children: [
                Positioned.fill(child: widget.child),
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Tooltip(
                    message: 'Drag to resize widget',
                    child: MouseRegion(
                      cursor: SystemMouseCursors.resizeUpDown,
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onPanUpdate: (details) {
                          setState(() {
                            _bodyHeight = (_bodyHeight + details.delta.dy)
                                .clamp(140.0, 520.0)
                                .toDouble();
                          });
                        },
                        child: Container(
                          width: 26,
                          height: 26,
                          alignment: Alignment.bottomRight,
                          padding: const EdgeInsets.all(3),
                          child: const Icon(
                            Icons.drag_handle_rounded,
                            size: 16,
                            color: _muted,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
'''
    s = s.replace(body_old, body_new, 1)
    print('OK: every standard widget has a bottom-right drag resize anchor')
else:
    print('OK: resize anchors already installed')

# ------------------------------------------------------------------
# 3) Remove accidental extra vertical spacing directly before/after the
#    standard widget region where prior passes may have accumulated gaps.
# ------------------------------------------------------------------
s = s.replace('                const SizedBox(height: 16),\n                const SizedBox(height: 16),',
              '                const SizedBox(height: 12),')

if s == orig:
    print('INFO: source already matched V14; no textual changes required')
else:
    P.write_text(s)

print('OK: minimized widgets now compact independently inside their column')
print('OK: expanded widgets occupy only their own content height')
print('OK: drag/drop ordering remains connected to _sectionOrder and _savePrefs()')
print('ONLY lib/screens/restaurant_dashboard_screen_v3.dart modified')
