import 'package:flutter/material.dart';
import '../../auth/models/app_user_model.dart';
import '../../services/user_management_service.dart';

class UserEditDialog extends StatefulWidget {
  final AppUserModel? existingUser; // If null, we are creating a new user

  const UserEditDialog({super.key, this.existingUser});

  @override
  State<UserEditDialog> createState() => _UserEditDialogState();
}

class _UserEditDialogState extends State<UserEditDialog> {
  final _formKey = GlobalKey<FormState>();
  final UserManagementService _userService = UserManagementService();

  late TextEditingController _nameController;
  late TextEditingController _emailController;
  late TextEditingController _discountController;

  String _selectedRole = 'Salesman';
  bool _isActive = true;
  late PermissionsModel _permissions;

  final List<String> _roles = ['Admin', 'Salesman'];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.existingUser?.displayName ?? '');
    _emailController = TextEditingController(text: widget.existingUser?.email ?? '');
    _discountController = TextEditingController(
      text: widget.existingUser?.maxDiscountPercent.toString() ?? '0.0',
    );
    _selectedRole = widget.existingUser?.role ?? 'Salesman';
    _isActive = widget.existingUser?.isActive ?? true;
    _permissions = widget.existingUser?.permissions ?? PermissionsModel.salesmanPreset();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _discountController.dispose();
    super.dispose();
  }

  void _onRoleChanged(String? newRole) {
    if (newRole == null) return;
    setState(() {
      _selectedRole = newRole;
      // Auto-apply preset based on role
      if (newRole.toLowerCase() == 'admin') {
        _permissions = PermissionsModel.adminPreset();
      } else {
        _permissions = PermissionsModel.salesmanPreset();
      }
    });
  }

  Future<void> _saveUser() async {
    if (!_formKey.currentState!.validate()) return;

    final user = AppUserModel(
      uid: widget.existingUser?.uid ?? 'temp_${DateTime.now().millisecondsSinceEpoch}', // Real app uses Firebase Auth UID
      email: _emailController.text.trim(),
      displayName: _nameController.text.trim(),
      role: _selectedRole,
      isActive: _isActive,
      maxDiscountPercent: double.tryParse(_discountController.text) ?? 0.0,
      permissions: _permissions,
      createdAt: widget.existingUser?.createdAt,
    );

    if (widget.existingUser == null) {
      await _userService.createUser(user);
      // Increment quota if needed
      await _userService.incrementActiveUsersCount(_selectedRole, 1);
    } else {
      await _userService.updateUser(user);
    }

    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        width: 800,
        height: 600,
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Text(widget.existingUser == null ? 'Create New User' : 'Edit User', 
                 style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            const Divider(),
            Expanded(
              child: Form(
                key: _formKey,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Left Column: Basic Details
                    Expanded(
                      flex: 1,
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Basic Details', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _nameController,
                              decoration: const InputDecoration(labelText: 'Full Display Name', border: OutlineInputBorder()),
                              validator: (v) => v!.isEmpty ? 'Required' : null,
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _emailController,
                              decoration: const InputDecoration(labelText: 'Login ID (Email)', border: OutlineInputBorder()),
                              enabled: widget.existingUser == null, // Disable email edit for existing users
                              validator: (v) => v!.isEmpty ? 'Required' : null,
                            ),
                            const SizedBox(height: 16),
                            DropdownButtonFormField<String>(
                              value: _selectedRole,
                              decoration: const InputDecoration(labelText: 'Role', border: OutlineInputBorder()),
                              items: _roles.map((r) => DropdownMenuItem(value: r, child: Text(r))).toList(),
                              onChanged: _onRoleChanged,
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _discountController,
                              decoration: const InputDecoration(labelText: 'Max Discount Allowed (%)', border: OutlineInputBorder()),
                              keyboardType: TextInputType.number,
                              validator: (v) => v!.isEmpty ? 'Required' : null,
                            ),
                            const SizedBox(height: 16),
                            SwitchListTile(
                              title: const Text('Account Active'),
                              value: _isActive,
                              onChanged: (val) => setState(() => _isActive = val),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const VerticalDivider(width: 32),
                    // Right Column: Permissions
                    Expanded(
                      flex: 2,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Granular Permissions', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          const Text('Adjusting these will override the role preset.', style: TextStyle(color: Colors.grey, fontSize: 12)),
                          const SizedBox(height: 8),
                          Expanded(
                            child: ListView(
                              children: [
                                _buildPermissionSection('Inventory Management', [
                                  _buildCheckbox('View Inventory', _permissions.viewInventory, (v) => _permissions = PermissionsModel.fromMap({..._permissions.toMap(), 'viewInventory': v})),
                                  _buildCheckbox('Add New Tags', _permissions.addTags, (v) => _permissions = PermissionsModel.fromMap({..._permissions.toMap(), 'addTags': v})),
                                  _buildCheckbox('Edit Tags', _permissions.editTags, (v) => _permissions = PermissionsModel.fromMap({..._permissions.toMap(), 'editTags': v})),
                                  _buildCheckbox('Delete Tags', _permissions.deleteTags, (v) => _permissions = PermissionsModel.fromMap({..._permissions.toMap(), 'deleteTags': v})),
                                ]),
                                _buildPermissionSection('Transactions & Billing', [
                                  _buildCheckbox('Sales Entry', _permissions.salesEntry, (v) => _permissions = PermissionsModel.fromMap({..._permissions.toMap(), 'salesEntry': v})),
                                  _buildCheckbox('Purchase Entry', _permissions.purchaseEntry, (v) => _permissions = PermissionsModel.fromMap({..._permissions.toMap(), 'purchaseEntry': v})),
                                  _buildCheckbox('Edit Transactions', _permissions.editTransactions, (v) => _permissions = PermissionsModel.fromMap({..._permissions.toMap(), 'editTransactions': v})),
                                  _buildCheckbox('Delete Transactions', _permissions.deleteTransactions, (v) => _permissions = PermissionsModel.fromMap({..._permissions.toMap(), 'deleteTransactions': v})),
                                ]),
                                _buildPermissionSection('Master Data & Admin', [
                                  _buildCheckbox('Manage Master Data (Items/Tax)', _permissions.manageItems, (v) => _permissions = PermissionsModel.fromMap({..._permissions.toMap(), 'manageItems': v, 'manageTax': v})),
                                  _buildCheckbox('Manage Rates', _permissions.manageRates, (v) => _permissions = PermissionsModel.fromMap({..._permissions.toMap(), 'manageRates': v})),
                                  _buildCheckbox('Manage Users', _permissions.manageUsers, (v) => _permissions = PermissionsModel.fromMap({..._permissions.toMap(), 'manageUsers': v})),
                                  _buildCheckbox('View Reports & Audit', _permissions.viewReports, (v) => _permissions = PermissionsModel.fromMap({..._permissions.toMap(), 'viewReports': v, 'viewAuditLog': v})),
                                ]),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const Divider(),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                const SizedBox(width: 16),
                ElevatedButton(
                  onPressed: _saveUser,
                  child: const Text('Save User'),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }

  Widget _buildPermissionSection(String title, List<Widget> children) {
    return ExpansionTile(
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
      initiallyExpanded: true,
      children: children,
    );
  }

  Widget _buildCheckbox(String label, bool value, Function(bool) onChanged) {
    return CheckboxListTile(
      title: Text(label, style: const TextStyle(fontSize: 14)),
      value: value,
      dense: true,
      controlAffinity: ListTileControlAffinity.leading,
      onChanged: (val) {
        if (val != null) {
          setState(() {
            onChanged(val);
          });
        }
      },
    );
  }
}
