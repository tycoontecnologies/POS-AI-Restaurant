from pathlib import Path

p = Path('lib/components/layout/main_shell_v7.dart')
s = p.read_text()

old = """            onSelected: (value) {
              if (value == 'profile') onProfile();
              if (value == 'settings') onSettings();
              if (value == 'switch_account') onLogout();
              if (value == 'logout') onLogout();
            },"""
new = """            onSelected: (value) {
              if (value == 'profile') onProfile();
              if (value == 'settings') onSettings();
              if (value == 'security') onAccountSecurity();
              if (value == 'switch') onSwitchAccount();
              if (value == 'logout') onLogout();
            },"""
if old not in s:
    raise SystemExit('ERROR: profile menu handler anchor not found')
s = s.replace(old, new, 1)

duplicate = """              PopupMenuDivider(),
              PopupMenuItem(
                value: 'switch_account',
                child: ListTile(
                  dense: true,
                  leading: Icon(Icons.switch_account_outlined),
                  title: Text('Switch Account'),
                  subtitle: Text('Sign in as another user'),
                ),
              ),
"""
if duplicate not in s:
    raise SystemExit('ERROR: duplicate Switch Account menu anchor not found')
s = s.replace(duplicate, "              PopupMenuDivider(),\n", 1)

p.write_text(s)
print('OK: Account & Security is wired to its dialog')
print('OK: Switch Account is wired to account switcher')
print('OK: duplicate logout-style Switch Account removed')
