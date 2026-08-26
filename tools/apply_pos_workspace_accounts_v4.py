from pathlib import Path
import re

POS = Path('lib/screens/pos_order_screen_v6.dart')
DASH = Path('lib/screens/restaurant_dashboard_screen_v3.dart')
SHELL = Path('lib/components/layout/main_shell_v7.dart')
LOGIN = Path('lib/screens/auth/login_screen_v2.dart')
AUTHS = Path('lib/services/auth_service.dart')
AUTHP = Path('lib/providers/auth_provider.dart')

pos = POS.read_text()
dash = DASH.read_text()
shell = SHELL.read_text()
login = LOGIN.read_text()
auths = AUTHS.read_text()
authp = AUTHP.read_text()


def replace_class(text, start_name, next_name, replacement):
    pattern = re.compile(rf"class {re.escape(start_name)}\b.*?(?=\nclass {re.escape(next_name)}\b)", re.S)
    out, n = pattern.subn(replacement.rstrip() + "\n", text, count=1)
    if n != 1:
        raise SystemExit(f'ERROR: could not replace class {start_name}')
    return out


def matching_paren(text, start):
    depth = 0
    quote = None
    esc = False
    for i in range(start, len(text)):
        ch = text[i]
        if quote:
            if esc:
                esc = False
            elif ch == '\\':
                esc = True
            elif ch == quote:
                quote = None
            continue
        if ch in "'\"":
            quote = ch
            continue
        if ch == '(':
            depth += 1
        elif ch == ')':
            depth -= 1
            if depth == 0:
                return i
    raise SystemExit('ERROR: unmatched parenthesis')

# ---------- CASHIER CATEGORY BAR ----------
if 'class _CategoryStrip extends StatefulWidget' not in pos:
    category = '''class _CategoryStrip extends StatefulWidget {
  final List<String> categories;
  final String selected;
  final ValueChanged<String> onSelect;
  const _CategoryStrip({required this.categories, required this.selected, required this.onSelect});

  @override
  State<_CategoryStrip> createState() => _CategoryStripState();
}

class _CategoryStripState extends State<_CategoryStrip> {
  final ScrollController _scroll = ScrollController();

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _move(double delta) {
    if (!_scroll.hasClients) return;
    final target = (_scroll.offset + delta).clamp(0.0, _scroll.position.maxScrollExtent);
    _scroll.animateTo(target, duration: const Duration(milliseconds: 220), curve: Curves.easeOutCubic);
  }

  @override
  Widget build(BuildContext context) => Container(
    height: 58,
    color: Colors.white,
    child: Row(children: [
      const SizedBox(width: 8),
      _CategoryArrow(icon: Icons.chevron_left_rounded, tooltip: 'Previous categories', onTap: () => _move(-320)),
      const SizedBox(width: 4),
      Expanded(child: ListView.separated(
        controller: _scroll,
        padding: const EdgeInsets.fromLTRB(4, 8, 4, 10),
        scrollDirection: Axis.horizontal,
        itemCount: widget.categories.length,
        separatorBuilder: (_, __) => const SizedBox(width: 7),
        itemBuilder: (_, i) {
          final item = widget.categories[i];
          final active = item == widget.selected;
          return ChoiceChip(
            label: Text(item), selected: active, showCheckmark: false,
            onSelected: (_) => widget.onSelect(item),
            selectedColor: AppColors.primary, backgroundColor: const Color(0xFFF7F7F8),
            side: BorderSide(color: active ? AppColors.primary : AppColors.outlineLight),
            labelStyle: TextStyle(color: active ? Colors.white : AppColors.grey700, fontWeight: FontWeight.w700, fontSize: 11),
          );
        },
      )),
      const SizedBox(width: 4),
      _CategoryArrow(icon: Icons.chevron_right_rounded, tooltip: 'More categories', onTap: () => _move(320)),
      const SizedBox(width: 8),
    ]),
  );
}

class _CategoryArrow extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  const _CategoryArrow({required this.icon, required this.tooltip, required this.onTap});
  @override
  Widget build(BuildContext context) => Tooltip(
    message: tooltip,
    child: Material(
      color: const Color(0xFFF7F7F8), borderRadius: BorderRadius.circular(9),
      child: InkWell(
        onTap: onTap, borderRadius: BorderRadius.circular(9),
        child: SizedBox(width: 34, height: 34, child: Icon(icon, size: 20, color: AppColors.grey700)),
      ),
    ),
  );
}
'''
    pos = replace_class(pos, '_CategoryStrip', '_MenuTile', category)
    print('OK: category bar arrows')
else:
    print('SKIP: category bar already patched')

# ---------- REMOVE GHOST BILL HALF-BUTTON ----------
if 'if (onBill == null)' not in pos:
    bill_idx = pos.find("label: const Text('Bill')")
    if bill_idx < 0:
        raise SystemExit('ERROR: Bill button label not found')
    row_start = pos.rfind('Row(', 0, bill_idx)
    if row_start < 0:
        raise SystemExit('ERROR: KOT/Bill row start not found')
    row_end = matching_paren(pos, row_start)
    end = row_end + 1
    while end < len(pos) and pos[end] in ' \t\r\n':
        end += 1
    if end < len(pos) and pos[end] == ',':
        end += 1
    replacement = "if (onBill == null)\n              SizedBox(\n                width: double.infinity,\n                child: OutlinedButton.icon(\n                  onPressed: busy ? null : onKot,\n                  icon: const Icon(Icons.print_outlined, size: 15),\n                  label: Text(state == 'open' ? 'KOT' : 'Reprint KOT'),\n                ),\n              )\n            else\n              Row(children: [\n                Expanded(child: OutlinedButton.icon(onPressed: busy ? null : onKot, icon: const Icon(Icons.print_outlined, size: 15), label: Text(state == 'open' ? 'KOT' : 'Reprint KOT'))),\n                const SizedBox(width: 8),\n                Expanded(child: OutlinedButton.icon(onPressed: busy ? null : onBill, icon: const Icon(Icons.receipt_long_outlined, size: 15), label: const Text('Bill'))),\n              ]),"
    pos = pos[:row_start] + replacement + pos[end:]
    print('OK: removed ghost Bill block')
else:
    print('SKIP: ghost Bill block already fixed')

# ---------- INTERACTIVE SALES CHART ----------
if 'class _SalesOverviewCard extends StatefulWidget' not in dash:
    chart = '''class _SalesOverviewCard extends StatefulWidget {
  final List<Sale> sales;
  const _SalesOverviewCard({required this.sales});
  @override
  State<_SalesOverviewCard> createState() => _SalesOverviewCardState();
}

class _SalesOverviewCardState extends State<_SalesOverviewCard> {
  int _days = 7;
  int? _selectedIndex;

  List<DateTime> _dates() {
    final now = DateTime.now();
    return List.generate(_days, (i) => DateTime(now.year, now.month, now.day).subtract(Duration(days: _days - 1 - i)));
  }

  @override
  Widget build(BuildContext context) {
    final dates = _dates();
    final values = dates.map((day) => widget.sales.where((s) => _sameDayStatic(s.createdAt, day)).fold<double>(0, (a, b) => a + b.total)).toList();
    final total = values.fold<double>(0, (a, b) => a + b);
    final orderCount = widget.sales.where((s) => dates.any((d) => _sameDayStatic(s.createdAt, d))).length;
    final selected = _selectedIndex != null && _selectedIndex! < values.length ? _selectedIndex! : values.length - 1;

    return _Panel(
      title: 'Sales Overview',
      trailing: Wrap(spacing: 4, children: [7, 30, 90].map((days) => ChoiceChip(
        label: Text(days == 7 ? '7D' : days == 30 ? '30D' : '90D'),
        selected: _days == days, showCheckmark: false, visualDensity: VisualDensity.compact,
        onSelected: (_) => setState(() { _days = days; _selectedIndex = null; }),
      )).toList()),
      child: Column(children: [
        Expanded(child: LayoutBuilder(builder: (_, c) => GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (d) {
            if (values.isEmpty || c.maxWidth <= 0) return;
            final x = d.localPosition.dx.clamp(0.0, c.maxWidth);
            final index = ((x / c.maxWidth) * (values.length - 1)).round().clamp(0, values.length - 1);
            setState(() => _selectedIndex = index);
          },
          child: Stack(children: [
            Positioned.fill(child: Padding(padding: const EdgeInsets.fromLTRB(6, 10, 6, 0), child: CustomPaint(painter: _LineChartPainter(values)))),
            if (values.isNotEmpty) Positioned(left: 10, top: 8, child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(9), border: Border.all(color: _line), boxShadow: const [BoxShadow(color: Color(0x0D101828), blurRadius: 8)]),
              child: Text('${DateFormat('dd MMM').format(dates[selected])}  •  Rs ${NumberFormat('#,##0').format(values[selected].round())}', style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.w800)),
            )),
          ]),
        ))),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(DateFormat('dd MMM').format(dates.first), style: const TextStyle(fontSize: 8.5, color: _muted)),
          const Text('Click chart to inspect a day', style: TextStyle(fontSize: 8.5, color: _muted)),
          Text(DateFormat('dd MMM').format(dates.last), style: const TextStyle(fontSize: 8.5, color: _muted)),
        ]),
        const SizedBox(height: 10),
        Container(padding: const EdgeInsets.symmetric(vertical: 10), decoration: BoxDecoration(color: _soft, borderRadius: BorderRadius.circular(10)), child: Row(children: [
          Expanded(child: _MiniStat('$_days-Day Sales', 'Rs ${NumberFormat('#,##0').format(total.round())}')),
          Expanded(child: _MiniStat('Orders', '$orderCount')),
          Expanded(child: _MiniStat('Daily Avg', 'Rs ${NumberFormat('#,##0').format((total / _days).round())}')),
        ])),
      ]),
    );
  }
}
'''
    dash = replace_class(dash, '_SalesOverviewCard', '_RecentOrdersCard', chart)
    print('OK: interactive sales chart')
else:
    print('SKIP: interactive sales chart already present')

# ---------- CLICKABLE RECENT ORDERS ----------
recent_start = dash.find('class _RecentOrdersCard')
recent_end = dash.find('\nclass ', recent_start + 10)
if recent_start >= 0:
    block = dash[recent_start:recent_end if recent_end > 0 else len(dash)]
    if 'onTap: () => context.go(AppRouter.sales)' not in block:
        block2, n = re.subn(r'return ListTile\(\s*', "return ListTile(\n            onTap: () => context.go(AppRouter.sales),\n            ", block, count=1)
        if n != 1:
            raise SystemExit('ERROR: Recent Orders ListTile not found')
        dash = dash[:recent_start] + block2 + dash[recent_end if recent_end > 0 else len(dash):]
        print('OK: recent orders clickable')
    else:
        print('SKIP: recent orders already clickable')

# ---------- KPI TREND LINES ----------
# Average bill trend
if '_averageBillTrend(sales)' not in dash:
    marker = "'Average Bill',"
    idx = dash.find(marker)
    if idx >= 0:
        empty = dash.find('const <double>[]', idx)
        if empty >= 0:
            dash = dash[:empty] + '_averageBillTrend(sales)' + dash[empty + len('const <double>[]'):]
            print('OK: average bill card trend')
# PRA trend
if '_praTrend(sales)' not in dash:
    marker = "'PRA Finalized',"
    idx = dash.find(marker)
    if idx >= 0:
        empty = dash.find('const <double>[]', idx)
        if empty >= 0:
            dash = dash[:empty] + '_praTrend(sales)' + dash[empty + len('const <double>[]'):]
            print('OK: PRA card trend')

if 'List<double> _averageBillTrend' not in dash:
    anchor = '  String _money(double value)'
    helper = '''  List<double> _averageBillTrend(List<Sale> sales) {
    final now = DateTime.now();
    return List.generate(7, (i) {
      final day = DateTime(now.year, now.month, now.day).subtract(Duration(days: 6 - i));
      final daySales = sales.where((s) => _sameDay(s.createdAt, day)).toList();
      if (daySales.isEmpty) return 0.0;
      return daySales.fold<double>(0, (a, b) => a + b.total) / daySales.length;
    });
  }

  List<double> _praTrend(List<Sale> sales) {
    final now = DateTime.now();
    return List.generate(7, (i) {
      final day = DateTime(now.year, now.month, now.day).subtract(Duration(days: 6 - i));
      final daySales = sales.where((s) => _sameDay(s.createdAt, day)).toList();
      if (daySales.isEmpty) return 0.0;
      final done = daySales.where((s) => (s.praInvoiceNo ?? '').isNotEmpty).length;
      return done / daySales.length * 100;
    });
  }

'''
    if anchor not in dash:
        raise SystemExit('ERROR: dashboard helper anchor missing')
    dash = dash.replace(anchor, helper + anchor, 1)

# ---------- AUTH SERVICE: OWN EMAIL/PASSWORD CHANGE ----------
if 'Future<void> updateCredentials' not in auths:
    anchor = '  Future<void> updateProfile('
    method = '''  Future<void> updateCredentials({
    required String currentPassword,
    required String newEmail,
    required String newPassword,
  }) async {
    final user = _auth.currentUser;
    if (user == null || user.email == null) {
      throw FirebaseAuthException(code: 'not-signed-in', message: 'No signed-in account.');
    }
    final credential = EmailAuthProvider.credential(email: user.email!, password: currentPassword);
    await user.reauthenticateWithCredential(credential);
    final email = newEmail.trim();
    if (email.isNotEmpty && email != user.email) {
      await user.updateEmail(email);
      await _firestore.collection('vendors').doc(user.uid).set({'email': email}, SetOptions(merge: true));
    }
    if (newPassword.isNotEmpty) {
      if (newPassword.length < 6) {
        throw FirebaseAuthException(code: 'weak-password', message: 'Password must be at least 6 characters.');
      }
      await user.updatePassword(newPassword);
    }
  }

'''
    if anchor not in auths:
        raise SystemExit('ERROR: auth service profile anchor missing')
    auths = auths.replace(anchor, method + anchor, 1)
    print('OK: credential update service')

# ---------- AUTH PROVIDER: REMEMBER ACCOUNT IDENTITIES, FAST SWITCH ----------
if "package:shared_preferences/shared_preferences.dart" not in authp:
    authp = authp.replace("import 'package:flutter/foundation.dart';", "import 'package:flutter/foundation.dart';\nimport 'package:shared_preferences/shared_preferences.dart';", 1)

if '_rememberedAccounts' not in authp:
    authp = authp.replace('  String? _error;\n', "  String? _error;\n  List<String> _rememberedAccounts = <String>[];\n", 1)
    authp = authp.replace('  bool get isAuthenticated => _currentUser != null;\n', "  bool get isAuthenticated => _currentUser != null;\n  List<String> get rememberedAccounts => List.unmodifiable(_rememberedAccounts);\n", 1)

if 'Future<void> _loadRememberedAccounts' not in authp:
    anchor = '  Future<void> initialize() async {'
    helpers = '''  Future<void> _loadRememberedAccounts() async {
    final prefs = await SharedPreferences.getInstance();
    _rememberedAccounts = prefs.getStringList('remembered_pos_accounts') ?? <String>[];
  }

  Future<void> _rememberAccount(String email) async {
    final clean = email.trim().toLowerCase();
    if (clean.isEmpty) return;
    _rememberedAccounts.removeWhere((e) => e.toLowerCase() == clean);
    _rememberedAccounts.insert(0, clean);
    if (_rememberedAccounts.length > 10) _rememberedAccounts = _rememberedAccounts.take(10).toList();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('remembered_pos_accounts', _rememberedAccounts);
  }

'''
    authp = authp.replace(anchor, helpers + anchor, 1)
    authp = authp.replace('    _isLoading = true;\n    notifyListeners();\n    try {\n      _currentUser = await _authService.getCurrentUserData();', '    _isLoading = true;\n    notifyListeners();\n    try {\n      await _loadRememberedAccounts();\n      _currentUser = await _authService.getCurrentUserData();', 1)

if 'await _rememberAccount(email);' not in authp:
    sign_marker = '      if (_currentUser == null) return false;\n'
    authp = authp.replace(sign_marker, sign_marker + '      await _rememberAccount(email);\n', 1)

if 'Future<bool> switchAccount' not in authp:
    anchor = '  Future<void> signOut() async {'
    methods = '''  Future<bool> switchAccount({required String email, required String password}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    final previous = _currentUser;
    try {
      if (previous != null) {
        try { await _auditService.endSession(previous); } catch (_) {}
      }
      await _authService.signOut();
      final next = await _authService.signIn(email: email, password: password);
      if (next == null || !next.isActive) {
        _currentUser = null;
        _error = 'Unable to switch to this account.';
        return false;
      }
      _currentUser = next;
      await _rememberAccount(email);
      await _auditService.startSession(next);
      return true;
    } catch (e) {
      _currentUser = null;
      _error = e.toString();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> updateCredentials({required String currentPassword, required String newEmail, required String newPassword}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      if (_currentUser == null) return false;
      await _authService.updateCredentials(currentPassword: currentPassword, newEmail: newEmail, newPassword: newPassword);
      final email = newEmail.trim().isEmpty ? _currentUser!.email : newEmail.trim();
      _currentUser = _copyCurrent(email: email);
      await _rememberAccount(email);
      return true;
    } catch (e) {
      _error = e.toString();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

'''
    if anchor not in authp:
        raise SystemExit('ERROR: auth provider signOut anchor missing')
    authp = authp.replace(anchor, methods + anchor, 1)

if 'String? email,' not in authp[authp.find('UserModel _copyCurrent'):authp.find('void clearError')]:
    authp = authp.replace('  UserModel _copyCurrent({\n    String? name,', '  UserModel _copyCurrent({\n    String? email,\n    String? name,', 1)
    authp = authp.replace('      email: u.email,', '      email: email ?? u.email,', 1)

# ---------- MAIN SHELL: ACCOUNT SECURITY + FAST SWITCH DIALOG ----------
if '_showSwitchAccountDialog' not in shell:
    anchor = '  Future<void> _showNotificationHistory(UserModel user) async {'
    methods = '''  Future<void> _showSwitchAccountDialog(UserModel user) async {
    final auth = context.read<AuthProvider>();
    final accounts = <String>{user.email, ...auth.rememberedAccounts}.where((e) => e.trim().isNotEmpty).toList();
    String selected = accounts.first;
    final password = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (_, setModal) => AlertDialog(
          title: const Text('Switch Account'),
          content: SizedBox(
            width: 420,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              DropdownButtonFormField<String>(
                value: selected,
                items: accounts.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                onChanged: (v) => setModal(() => selected = v ?? selected),
                decoration: const InputDecoration(labelText: 'Remembered account'),
              ),
              const SizedBox(height: 14),
              TextField(controller: password, obscureText: true, decoration: const InputDecoration(labelText: 'Password', helperText: 'Passwords are never stored by Tycoon POS.')),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Switch')),
          ],
        ),
      ),
    );
    if (ok != true || !mounted) { password.dispose(); return; }
    final success = await auth.switchAccount(email: selected, password: password.text);
    password.dispose();
    if (!mounted) return;
    if (success) {
      context.go(AppRouter.dashboard);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(auth.error ?? 'Unable to switch account')));
    }
  }

  Future<void> _showAccountSecurityDialog(UserModel user) async {
    final auth = context.read<AuthProvider>();
    final currentPassword = TextEditingController();
    final newEmail = TextEditingController(text: user.email);
    final newPassword = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Account & Security'),
        content: SizedBox(width: 430, child: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: newEmail, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'Email / username')),
          const SizedBox(height: 12),
          TextField(controller: currentPassword, obscureText: true, decoration: const InputDecoration(labelText: 'Current password')),
          const SizedBox(height: 12),
          TextField(controller: newPassword, obscureText: true, decoration: const InputDecoration(labelText: 'New password', helperText: 'Leave blank to keep the current password.')),
        ])),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Save')),
        ],
      ),
    );
    if (ok != true || !mounted) { currentPassword.dispose(); newEmail.dispose(); newPassword.dispose(); return; }
    final success = await auth.updateCredentials(currentPassword: currentPassword.text, newEmail: newEmail.text, newPassword: newPassword.text);
    currentPassword.dispose(); newEmail.dispose(); newPassword.dispose();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(success ? 'Account credentials updated.' : (auth.error ?? 'Unable to update credentials'))));
  }

'''
    if anchor not in shell:
        raise SystemExit('ERROR: shell notification anchor missing')
    shell = shell.replace(anchor, methods + anchor, 1)

# topbar callbacks
if 'onSwitchAccount:' not in shell:
    shell = shell.replace('          onProfile: () => context.go(AppRouter.profileSettings),\n          onLogout: _logout,', '          onProfile: () => context.go(AppRouter.profileSettings),\n          onSwitchAccount: () => _showSwitchAccountDialog(user),\n          onAccountSecurity: () => _showAccountSecurityDialog(user),\n          onLogout: _logout,', 1)
    shell = shell.replace('  final VoidCallback onProfile;\n  final VoidCallback onLogout;', '  final VoidCallback onProfile;\n  final VoidCallback onSwitchAccount;\n  final VoidCallback onAccountSecurity;\n  final VoidCallback onLogout;', 1)
    shell = shell.replace('    required this.onProfile,\n    required this.onLogout,', '    required this.onProfile,\n    required this.onSwitchAccount,\n    required this.onAccountSecurity,\n    required this.onLogout,', 1)

if "value == 'switch'" not in shell:
    shell = shell.replace("              if (value == 'settings') onSettings();\n              if (value == 'logout') onLogout();", "              if (value == 'settings') onSettings();\n              if (value == 'security') onAccountSecurity();\n              if (value == 'switch') onSwitchAccount();\n              if (value == 'logout') onLogout();", 1)
    menu_anchor = '''              PopupMenuItem(
                value: 'settings',
                child: ListTile(
                  dense: true,
                  leading: Icon(Icons.settings_outlined),
                  title: Text('Settings'),
                ),
              ),'''
    menu_extra = menu_anchor + '''
              PopupMenuItem(
                value: 'security',
                child: ListTile(dense: true, leading: Icon(Icons.lock_outline_rounded), title: Text('Account & Security')),
              ),
              PopupMenuItem(
                value: 'switch',
                child: ListTile(dense: true, leading: Icon(Icons.switch_account_outlined), title: Text('Switch Account')),
              ),'''
    if menu_anchor not in shell:
        raise SystemExit('ERROR: profile menu anchor missing')
    shell = shell.replace(menu_anchor, menu_extra, 1)

# notifications rail to all roles
shell = shell.replace('              if (user.isAdmin)\n                Positioned(', '              Positioned(', 1)

# ---------- BRANDING ----------
login = login.replace('Tycoon Technologies (Pvt.) Ltd.  •  Software for Every Business.', 'Tycoon Technologies Pvt. Ltd. • Islamabad • Call: 03060626699')
if 'Call: 03060626699' not in shell:
    footer = "iconsOnly ? 'T' : 'Tycoon POS'"
    if footer in shell:
        shell = shell.replace(footer, "iconsOnly ? 'T' : 'Tycoon Technologies Pvt. Ltd. • Islamabad • 03060626699'", 1)

POS.write_text(pos)
DASH.write_text(dash)
SHELL.write_text(shell)
LOGIN.write_text(login)
AUTHS.write_text(auths)
AUTHP.write_text(authp)
print('OK: V4 workspace/accounts patch written')
