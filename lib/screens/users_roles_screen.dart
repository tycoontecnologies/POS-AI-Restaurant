import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:pos/firebase_options.dart';
import 'package:pos/models/user.dart';
import 'package:pos/providers/auth_provider.dart';
import 'package:pos/utils/app_colors.dart';

class UsersRolesScreen extends StatefulWidget {
  const UsersRolesScreen({super.key});

  @override
  State<UsersRolesScreen> createState() => _UsersRolesScreenState();
}

class _UsersRolesScreenState extends State<UsersRolesScreen> {
  bool _creating = false;

  static const Map<UserRole, _RolePreset> presets = {
    UserRole.admin: _RolePreset('Restaurant Admin', 'Administration', Icons.admin_panel_settings_outlined, ['dashboard.view', 'tables.manage', 'orders.manage', 'billing.manage', 'inventory.manage', 'customers.manage', 'purchases.manage', 'suppliers.manage', 'recipes.manage', 'reports.view', 'users.manage', 'settings.manage']),
    UserRole.manager: _RolePreset('Manager', 'Management', Icons.manage_accounts_outlined, ['dashboard.view', 'tables.manage', 'orders.manage', 'billing.manage', 'inventory.view', 'customers.view', 'reports.view']),
    UserRole.cashier: _RolePreset('Cashier / POS Operator', 'Cash Counter', Icons.point_of_sale_outlined, ['tables.view', 'tables.open', 'orders.create', 'orders.edit', 'kot.send', 'billing.create', 'payments.receive', 'receipts.print', 'sales.own_shift']),
    UserRole.waiter: _RolePreset('Waiter / Server', 'Service', Icons.room_service_outlined, ['tables.view', 'tables.open', 'orders.create', 'orders.edit', 'kot.send', 'bill.request']),
    UserRole.kitchen: _RolePreset('Kitchen / KDS', 'Kitchen', Icons.soup_kitchen_outlined, ['kot.view', 'kot.accept', 'kot.making', 'kot.ready']),
    UserRole.operations: _RolePreset('Operations', 'Operations', Icons.settings_suggest_outlined, ['tables.view', 'orders.view', 'inventory.manage', 'purchases.manage', 'suppliers.manage', 'recipes.manage']),
    UserRole.accounts: _RolePreset('Accounts', 'Accounts', Icons.account_balance_wallet_outlined, ['sales.view', 'purchases.view', 'expenses.manage', 'supplier_ledger.view', 'returns.manage', 'reports.financial']),
    UserRole.inventory: _RolePreset('Inventory / Store Keeper', 'Store', Icons.inventory_2_outlined, ['inventory.manage', 'stock.receive', 'stock.adjust', 'wastage.manage', 'suppliers.view']),
    UserRole.delivery: _RolePreset('Delivery / Dispatcher', 'Delivery', Icons.delivery_dining_outlined, ['delivery.orders', 'customers.delivery', 'delivery.assign', 'delivery.status']),
    UserRole.reception: _RolePreset('Reception / Host', 'Front Desk', Icons.event_seat_outlined, ['tables.view', 'reservations.manage', 'waitlist.manage']),
    UserRole.auditor: _RolePreset('Owner / Auditor', 'Audit', Icons.visibility_outlined, ['dashboard.view', 'sales.view', 'inventory.view', 'accounts.view', 'reports.view', 'audit.view']),
  };

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.currentUser;
    if (user == null) return const Center(child: CircularProgressIndicator());
    if (!user.isAdmin) return const Center(child: Text('Only administrators can manage users and roles.'));

    return Container(
      color: AppColors.backgroundLight,
      padding: const EdgeInsets.all(24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Users & Roles', style: TextStyle(fontSize: 25, fontWeight: FontWeight.w800, color: AppColors.grey900)),
            SizedBox(height: 4),
            Text('Create department logins and control what each team can access.', style: TextStyle(color: AppColors.grey500, fontSize: 12.5)),
          ])),
          FilledButton.icon(onPressed: _creating ? null : () => _showCreateUser(user), icon: const Icon(Icons.person_add_alt_1_rounded), label: const Text('Create Account')),
        ]),
        const SizedBox(height: 20),
        Expanded(child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(flex: 7, child: _accountsPanel(user)),
          const SizedBox(width: 16),
          Expanded(flex: 4, child: _rolesPanel()),
        ])),
      ]),
    );
  }

  Widget _accountsPanel(UserModel owner) {
    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.outlineLight)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Padding(padding: EdgeInsets.fromLTRB(18, 17, 18, 12), child: Text('Restaurant Accounts', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.grey900))),
        const Divider(height: 1),
        Expanded(child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance.collection('vendors').where('ownerId', isEqualTo: owner.id).snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
            final docs = (snapshot.data?.docs ?? []).where((d) => d.id != owner.authUid).toList();
            if (docs.isEmpty) return const _EmptyAccounts();
            docs.sort((a, b) => (a.data()['name'] ?? '').toString().compareTo((b.data()['name'] ?? '').toString()));
            return ListView.separated(
              padding: const EdgeInsets.all(12), itemCount: docs.length, separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (_, i) {
                final doc = docs[i]; final data = doc.data(); final role = _parseRole((data['role'] ?? 'user').toString()); final preset = presets[role]; final active = data['isActive'] != false;
                final photoUrl = data['photoUrl']?.toString();
                return Container(
                  padding: const EdgeInsets.all(13),
                  decoration: BoxDecoration(color: AppColors.grey50, borderRadius: BorderRadius.circular(11), border: Border.all(color: AppColors.outlineLight)),
                  child: Row(children: [
                    CircleAvatar(
                      radius: 19,
                      backgroundColor: AppColors.primarySoft,
                      backgroundImage: photoUrl != null && photoUrl.isNotEmpty ? NetworkImage(photoUrl) : null,
                      child: photoUrl == null || photoUrl.isEmpty ? Icon(preset?.icon ?? Icons.person_outline, color: AppColors.primary, size: 19) : null,
                    ),
                    const SizedBox(width: 11),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text((data['name'] ?? 'User').toString(), style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 3),
                      Text('${preset?.label ?? role.name}  •  ${data['email'] ?? ''}', style: const TextStyle(fontSize: 10.5, color: AppColors.grey500)),
                    ])),
                    Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5), decoration: BoxDecoration(color: active ? AppColors.successSoft : AppColors.errorSoft, borderRadius: BorderRadius.circular(20)), child: Text(active ? 'ACTIVE' : 'DISABLED', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: active ? AppColors.successDark : AppColors.errorDark))),
                    const SizedBox(width: 7),
                    PopupMenuButton<String>(
                      tooltip: 'Account actions',
                      onSelected: (value) async {
                        if (value == 'toggle') await doc.reference.update({'isActive': !active, 'updatedAt': FieldValue.serverTimestamp()});
                        if (value == 'reset') { final accountEmail = (data['email'] ?? '').toString(); if (accountEmail.isNotEmpty) { await FirebaseAuth.instance.sendPasswordResetEmail(email: accountEmail); if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Password reset email sent.'))); } }
                        if (value == 'photo_on' || value == 'photo_off') {
                          final allowed = value == 'photo_on';
                          await doc.reference.update({'canChangePhoto': allowed, 'updatedAt': FieldValue.serverTimestamp()});
                          final staffId = (data['staffId'] ?? doc.id).toString();
                          await FirebaseFirestore.instance.collection('vendors').doc(owner.id).collection('staff').doc(staffId).set({'canChangePhoto': allowed}, SetOptions(merge: true));
                        }
                        if (value == 'commission_on' || value == 'commission_off') {
                          final visible = value == 'commission_on';
                          await doc.reference.update({'showCommissionToStaff': visible, 'updatedAt': FieldValue.serverTimestamp()});
                          final staffId = (data['staffId'] ?? doc.id).toString();
                          await FirebaseFirestore.instance.collection('vendors').doc(owner.id).collection('staff').doc(staffId).set({'showCommissionToStaff': visible}, SetOptions(merge: true));
                        }
                      },
                      itemBuilder: (_) => [
                        PopupMenuItem(value: 'toggle', child: Text(active ? 'Disable account' : 'Enable account')),
                        const PopupMenuItem(value: 'reset', child: Text('Send password reset')),
                        PopupMenuItem(value: data['canChangePhoto'] == true ? 'photo_off' : 'photo_on', child: Text(data['canChangePhoto'] == true ? 'Block profile photo changes' : 'Allow profile photo changes')),
                        PopupMenuItem(value: data['showCommissionToStaff'] == true ? 'commission_off' : 'commission_on', child: Text(data['showCommissionToStaff'] == true ? 'Hide commission from user' : 'Show commission to user')),
                      ],
                    ),
                  ]),
                );
              },
            );
          },
        )),
      ]),
    );
  }

  Widget _rolesPanel() {
    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.outlineLight)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Padding(padding: EdgeInsets.fromLTRB(18, 17, 18, 12), child: Text('Standard Roles', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.grey900))),
        const Divider(height: 1),
        Expanded(child: ListView(padding: const EdgeInsets.all(12), children: presets.entries.map((entry) {
          final p = entry.value;
          return Padding(padding: const EdgeInsets.only(bottom: 7), child: ExpansionTile(
            tilePadding: const EdgeInsets.symmetric(horizontal: 10), childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 10), leading: Icon(p.icon, size: 19, color: AppColors.primary),
            title: Text(p.label, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700)), subtitle: Text(p.department, style: const TextStyle(fontSize: 9.5, color: AppColors.grey500)),
            children: [Align(alignment: Alignment.centerLeft, child: Wrap(spacing: 5, runSpacing: 5, children: p.permissions.map((x) => Chip(label: Text(x, style: const TextStyle(fontSize: 8.5)), visualDensity: VisualDensity.compact)).toList()))],
          ));
        }).toList())),
      ]),
    );
  }

  Future<void> _showCreateUser(UserModel owner) async {
    final name = TextEditingController(); final email = TextEditingController(); final password = TextEditingController(); final phone = TextEditingController();
    UserRole selectedRole = UserRole.cashier; bool obscure = true;
    final created = await showDialog<bool>(context: context, builder: (dialogContext) => StatefulBuilder(builder: (_, setDialogState) {
      final p = presets[selectedRole]!;
      return AlertDialog(
        title: const Text('Create Department Account'),
        content: SizedBox(width: 520, child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          DropdownButtonFormField<UserRole>(value: selectedRole, decoration: const InputDecoration(labelText: 'Role / Department', border: OutlineInputBorder()), items: presets.entries.map((e) => DropdownMenuItem(value: e.key, child: Text(e.value.label))).toList(), onChanged: (v) => setDialogState(() => selectedRole = v ?? selectedRole)),
          const SizedBox(height: 10), Text('Department: ${p.department}', style: const TextStyle(fontSize: 11, color: AppColors.grey500)), const SizedBox(height: 14),
          TextField(controller: name, decoration: const InputDecoration(labelText: 'Full name', border: OutlineInputBorder())), const SizedBox(height: 12),
          TextField(controller: email, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'Login email', border: OutlineInputBorder())), const SizedBox(height: 12),
          TextField(controller: phone, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Phone (optional)', border: OutlineInputBorder())), const SizedBox(height: 12),
          TextField(controller: password, obscureText: obscure, decoration: InputDecoration(labelText: 'Temporary password', border: const OutlineInputBorder(), suffixIcon: IconButton(onPressed: () => setDialogState(() => obscure = !obscure), icon: Icon(obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined)))),
          const SizedBox(height: 12), Container(padding: const EdgeInsets.all(11), decoration: BoxDecoration(color: AppColors.primarySoft, borderRadius: BorderRadius.circular(10)), child: Text('This account will use ${owner.restaurantName} data and the ${p.label} permission preset. A linked staff performance profile will also be created.', style: const TextStyle(fontSize: 10.5, color: AppColors.grey700))),
        ]))),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
          FilledButton(onPressed: () { if (name.text.trim().isEmpty || !email.text.contains('@') || password.text.length < 6) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter a name, valid email and password of at least 6 characters.'))); return; } Navigator.pop(dialogContext, true); }, child: const Text('Create Account')),
        ],
      );
    }));
    if (created != true) return;
    setState(() => _creating = true);
    try {
      final p = presets[selectedRole]!;
      await _createFirebaseDepartmentUser(owner: owner, name: name.text.trim(), email: email.text.trim().toLowerCase(), password: password.text, phone: phone.text.trim(), role: selectedRole, preset: p);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${p.label} account created successfully.'), backgroundColor: AppColors.success));
    } on FirebaseAuthException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message ?? e.code), backgroundColor: AppColors.error));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Unable to create account: $e'), backgroundColor: AppColors.error));
    } finally { if (mounted) setState(() => _creating = false); }
  }

  Future<void> _createFirebaseDepartmentUser({required UserModel owner, required String name, required String email, required String password, required String phone, required UserRole role, required _RolePreset preset}) async {
    final appName = 'department-${DateTime.now().microsecondsSinceEpoch}';
    final secondaryApp = await Firebase.initializeApp(name: appName, options: DefaultFirebaseOptions.currentPlatform);
    try {
      final secondaryAuth = FirebaseAuth.instanceFor(app: secondaryApp);
      final credential = await secondaryAuth.createUserWithEmailAndPassword(email: email, password: password);
      final uid = credential.user!.uid; final now = DateTime.now();
      final accountRef = FirebaseFirestore.instance.collection('vendors').doc(uid);
      final staffRef = FirebaseFirestore.instance.collection('vendors').doc(owner.id).collection('staff').doc(uid);
      final batch = FirebaseFirestore.instance.batch();
      batch.set(accountRef, {
        'ownerId': owner.id, 'restaurantId': owner.id, 'branchId': owner.branchId, 'branchName': owner.branchName,
        'staffId': uid, 'email': email, 'name': name, 'phoneNo': phone, 'role': role.name, 'department': preset.department, 'permissions': preset.permissions,
        'createdAt': Timestamp.fromDate(now), 'isActive': true, 'trialEndsAt': Timestamp.fromDate(owner.trialEndsAt), 'subscriptionType': owner.subscriptionType.name,
        'subscriptionEndsAt': owner.subscriptionEndsAt == null ? null : Timestamp.fromDate(owner.subscriptionEndsAt!), 'hasActiveSubscription': owner.hasActiveSubscription,
        'location': owner.location, 'restaurantName': owner.restaurantName, 'restaurantLogoUrl': owner.restaurantLogoUrl, 'createdBy': owner.authUid,
        'photoUrl': null, 'canChangePhoto': false, 'showCommissionToStaff': false,
      });
      batch.set(staffRef, {
        'id': uid,
        'authUid': uid,
        'name': name,
        'role': preset.label,
        'dailyWage': 0.0,
        'phone': phone,
        'address': '',
        'active': true,
        'joinDate': now.toIso8601String(),
        'searchKeywords': [name.toLowerCase(), preset.label.toLowerCase(), phone.toLowerCase()].where((x) => x.isNotEmpty).toList(),
        'photoUrl': null,
        'canChangePhoto': false,
        'commissionRate': 0.0,
        'showCommissionToStaff': false,
        'tipsEarned': 0.0,
        'commissionEarned': 0.0,
        'serviceChargesEarned': 0.0,
        'pointsEarned': 0,
        'averageRating': 0.0,
        'reviewCount': 0,
        'leakageTotal': 0.0,
        'deductionsTotal': 0.0,
        'branchId': owner.branchId,
        'branchName': owner.branchName,
      });
      await batch.commit();
      await secondaryAuth.signOut();
    } finally { await secondaryApp.delete(); }
  }

  UserRole _parseRole(String value) { for (final role in UserRole.values) { if (role.name == value) return role; } return UserRole.user; }
}

class _RolePreset {
  final String label; final String department; final IconData icon; final List<String> permissions;
  const _RolePreset(this.label, this.department, this.icon, this.permissions);
}

class _EmptyAccounts extends StatelessWidget {
  const _EmptyAccounts();
  @override
  Widget build(BuildContext context) => const Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
    Icon(Icons.manage_accounts_outlined, size: 42, color: AppColors.grey300), SizedBox(height: 10),
    Text('No department accounts yet', style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.grey700)), SizedBox(height: 4),
    Text('Create a cashier, kitchen, accounts or other login.', style: TextStyle(fontSize: 10.5, color: AppColors.grey500)),
  ]));
}
