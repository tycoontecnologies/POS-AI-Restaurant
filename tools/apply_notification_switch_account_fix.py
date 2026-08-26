from pathlib import Path

p = Path('lib/components/layout/main_shell_v7.dart')
s = p.read_text()


def once(old: str, new: str, label: str):
    global s
    count = s.count(old)
    if count != 1:
        raise SystemExit(f'ERROR: {label}: expected 1 match, found {count}')
    s = s.replace(old, new, 1)
    print(f'OK: {label}')

# 1) Live notification toasts are for every authorized user, not admin only.
once(
"""              if (user.isAdmin)
                Positioned(
                  top: 12,
                  right: 12,
                  child: _UnreadNotificationRail(user: user),
                ),""",
"""              Positioned(
                top: 12,
                right: 12,
                child: _UnreadNotificationRail(user: user),
              ),""",
'notification rail for all roles',
)

# 2) Add Switch Account to profile menu. It deliberately performs a real sign-out
#    so the next account receives a fresh Firebase/auth/role session.
once(
"""            onSelected: (value) {
              if (value == 'profile') onProfile();
              if (value == 'settings') onSettings();
              if (value == 'logout') onLogout();
            },
            itemBuilder: (_) => const [""",
"""            onSelected: (value) {
              if (value == 'profile') onProfile();
              if (value == 'settings') onSettings();
              if (value == 'switch_account') onLogout();
              if (value == 'logout') onLogout();
            },
            itemBuilder: (_) => const [""",
'profile menu selection',
)

once(
"""              PopupMenuDivider(),
              PopupMenuItem(
                value: 'logout',
                child: ListTile(
                  dense: true,
                  leading: Icon(Icons.logout_rounded),
                  title: Text('Logout'),
                ),
              ),""",
"""              PopupMenuDivider(),
              PopupMenuItem(
                value: 'switch_account',
                child: ListTile(
                  dense: true,
                  leading: Icon(Icons.switch_account_outlined),
                  title: Text('Switch Account'),
                  subtitle: Text('Sign in as another user'),
                ),
              ),
              PopupMenuItem(
                value: 'logout',
                child: ListTile(
                  dense: true,
                  leading: Icon(Icons.logout_rounded),
                  title: Text('Logout'),
                ),
              ),""",
'switch account menu item',
)

# 3) Fix notification audience rules:
#    - support NotificationService.targetAuthUid (single-user notifications)
#    - keep role-targeted notifications role-aware
#    - notifications with no target are restaurant-wide broadcasts, not admin-only
old_visible = """bool _visibleFor(UserModel user, Map<String, dynamic> data) {
  final roles = List<String>.from(data['targetRoles'] ?? const <String>[]);
  final users = List<String>.from(data['targetUserIds'] ?? const <String>[]);
  if (users.isNotEmpty &&
      !users.contains(user.authUid) &&
      !users.contains(user.id))
    return false;
  if (roles.isNotEmpty &&
      !roles.contains(user.role.name) &&
      !(user.isAdmin && roles.contains('admin')))
    return false;
  if (users.isEmpty && roles.isEmpty) return user.isAdmin;
  return true;
}"""

new_visible = """bool _visibleFor(UserModel user, Map<String, dynamic> data) {
  final roles = List<String>.from(data['targetRoles'] ?? const <String>[]);
  final users = List<String>.from(data['targetUserIds'] ?? const <String>[]);
  final directUser = (data['targetAuthUid'] ?? '').toString().trim();

  if (directUser.isNotEmpty &&
      directUser != user.authUid &&
      directUser != user.id) {
    return false;
  }

  if (users.isNotEmpty &&
      !users.contains(user.authUid) &&
      !users.contains(user.id)) {
    return false;
  }

  if (roles.isNotEmpty &&
      !roles.contains(user.role.name) &&
      !(user.isAdmin && roles.contains('admin'))) {
    return false;
  }

  // No target means a restaurant-wide operational notification.
  // Every signed-in restaurant user may see it; read/clear state remains per-user.
  if (directUser.isEmpty && users.isEmpty && roles.isEmpty) return true;
  return true;
}"""

once(old_visible, new_visible, 'notification audience rules')

p.write_text(s)
print('OK: main_shell_v7.dart written')
