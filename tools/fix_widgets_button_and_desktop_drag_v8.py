from pathlib import Path

shell = Path('lib/components/layout/main_shell_v7.dart')
dash = Path('lib/screens/restaurant_dashboard_screen_v3.dart')

s = shell.read_text()
old = "onAddWidget: () => context.go('${AppRouter.dashboard}?customize=1'),"
new = "onAddWidget: () {\n            if (route == AppRouter.dashboard) {\n              context.go('${AppRouter.dashboard}?customize=1');\n            } else {\n              ScaffoldMessenger.of(context).showSnackBar(\n                const SnackBar(\n                  content: Text('Widgets can only be customized from Dashboard.'),\n                ),\n              );\n            }\n          },"
if old not in s:
    raise SystemExit('ERROR: widgets action anchor not found in main_shell_v7.dart')
s = s.replace(old, new, 1)
shell.write_text(s)

s = dash.read_text()
old = """                              LongPressDraggable<String>(
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
"""
new = """                              Draggable<String>(
                                data: id,
                                dragAnchorStrategy: pointerDragAnchorStrategy,
                                feedback: Material(
                                  color: Colors.transparent,
                                  child: ConstrainedBox(
                                    constraints: BoxConstraints(
                                      maxWidth: constraints.maxWidth * .75,
                                    ),
                                    child: Opacity(opacity: .94, child: child),
                                  ),
                                ),
                                childWhenDragging:
                                    Opacity(opacity: .22, child: child),
                                child: MouseRegion(
                                  cursor: SystemMouseCursors.grab,
                                  child: child,
                                ),
                              ),
"""
if old not in s:
    raise SystemExit('ERROR: desktop draggable anchor not found in dashboard')
s = s.replace(old, new, 1)
dash.write_text(s)

print('OK: Widgets button no longer navigates away from Tables/other modules')
print('OK: Dashboard widgets now use immediate desktop Draggable instead of LongPressDraggable')
print('ONLY main_shell_v7.dart and restaurant_dashboard_screen_v3.dart changed')
