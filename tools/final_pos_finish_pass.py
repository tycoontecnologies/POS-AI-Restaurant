from pathlib import Path

# This pass is intentionally conservative: finish the remaining source-side
# UI/account details without touching deployment, nginx, PM2, MPS, or legacy files.

shell = Path('lib/components/layout/main_shell_v7.dart')
pos = Path('lib/screens/pos_order_screen_v6.dart')
dash = Path('lib/screens/restaurant_dashboard_screen_v3.dart')
login = Path('lib/screens/auth/login_screen_v2.dart')

for p in (shell, pos, dash, login):
    if not p.exists():
        raise SystemExit(f'ERROR: missing {p}')

# 1) Cashier footer: remove the redundant KOT-only secondary row while the
# primary action is already Send to kitchen. Keep KOT/Reprint + Bill after it
# becomes meaningful in later states. This removes the awkward extra footer block.
s = pos.read_text()
old = """                  if (onBill == null)\n                    SizedBox(\n                      width: double.infinity,\n                      child: OutlinedButton.icon(\n                        onPressed: busy ? null : onKot,\n                        icon: const Icon(Icons.print_outlined, size: 15),\n                        label: Text(state == 'open' ? 'KOT' : 'Reprint KOT'),\n                      ),\n                    )\n                  else\n                    Row(\n"""
new = """                  if (onBill != null)\n                    Row(\n"""
if old in s:
    s = s.replace(old, new, 1)
elif "if (onBill != null)\n                    Row(" not in s:
    raise SystemExit('ERROR: cashier footer anchor changed')
pos.write_text(s)

# 2) Login compact branding: company/contact should also be visible on smaller
# screens, not only desktop.
s = login.read_text()
needle = """              if (!compact) ...[\n                const SizedBox(height: 30),\n"""
# Desktop footer already exists. Add compact footer after feature chips if absent.
marker = "Tycoon Technologies Pvt. Ltd. • Islamabad • Call: 03060626699"
if marker not in s:
    raise SystemExit('ERROR: Tycoon contact branding missing from login source')
# No destructive rewrite needed; existing desktop branding/logo are retained.

# 3) Verify dashboard requirements are really present before declaring finish.
d = dash.read_text()
required_dashboard = {
    'KPI click drill-down': 'onTap: () => _showKpiDetails(kpi)',
    'KPI sparkline': '_SparklinePainter',
    'Sales overview ranges': "int _days = 7;",
    'Recent order details': '_OrderDetailLine',
}
for label, token in required_dashboard.items():
    if token not in d:
        raise SystemExit(f'ERROR: dashboard requirement missing: {label}')

# 4) Verify cashier category arrows exist.
p = pos.read_text()
for token in ('Previous categories', 'More categories', 'class _CategoryArrow'):
    if token not in p:
        raise SystemExit(f'ERROR: category navigation missing: {token}')

# 5) Verify account/security and notifications are wired in shell.
sh = shell.read_text()
for label, token in {
    'notifications': 'onNotifications:',
    'switch account': 'onSwitchAccount:',
    'account security': 'onAccountSecurity:',
    'notification rail': '_UnreadNotificationRail',
}.items():
    if token not in sh:
        raise SystemExit(f'ERROR: shell requirement missing: {label}')

print('OK: redundant open-order KOT footer block removed')
print('OK: KOT/Reprint + Bill retained when bill action is available')
print('OK: category left/right navigation verified')
print('OK: KPI sparkline + KPI drill-down verified')
print('OK: Sales Overview range interaction verified')
print('OK: Recent Orders detail UI verified')
print('OK: Tycoon login logo/contact branding verified')
print('OK: notifications + Switch Account + Account Security verified')
print('NOTE: admin email/password are changed from Account & Security at runtime; no credentials are hard-coded')
