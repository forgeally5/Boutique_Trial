import 'package:flutter/material.dart';
import '../../auth/models/app_user_model.dart';
import '../../auth/models/system_quota_model.dart';
import '../../services/user_management_service.dart';
import 'user_edit_dialog.dart';

class UserManagementScreen extends StatefulWidget {
  const UserManagementScreen({super.key});

  @override
  State<UserManagementScreen> createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends State<UserManagementScreen> {
  final UserManagementService _userService = UserManagementService();
  String _searchQuery = '';
  String _roleFilter = 'All'; // 'All', 'Admin', 'Salesman'

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('User Management'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Add New User',
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => const UserEditDialog(),
              );
            },
          ),
        ],
      ),
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Sidebar / Left Panel for Quotas & Filters
          Expanded(
            flex: 2,
            child: _buildLeftPanel(),
          ),
          const VerticalDivider(width: 1),
          // Main Content / User List
          Expanded(
            flex: 5,
            child: _buildUserList(),
          ),
        ],
      ),
    );
  }

  Widget _buildLeftPanel() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Quotas & Limits', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          StreamBuilder<SystemQuotaModel>(
            stream: _userService.streamQuotas(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              final quota = snapshot.data ?? const SystemQuotaModel(
                maxSalesmen: 0, currentSalesmen: 0,
              );
              return Column(
                children: [
                  _buildQuotaProgress('Salesmen', quota.currentSalesmen, quota.maxSalesmen, Colors.amber),
                ],
              );
            }
          ),
          const SizedBox(height: 32),
          const Text('Filters', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          TextField(
            decoration: const InputDecoration(
              labelText: 'Search Users',
              prefixIcon: Icon(Icons.search),
              border: OutlineInputBorder(),
            ),
            onChanged: (val) {
              setState(() {
                _searchQuery = val.toLowerCase();
              });
            },
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            children: ['All', 'Admin', 'Salesman'].map((role) {
              return ChoiceChip(
                label: Text(role),
                selected: _roleFilter == role,
                onSelected: (selected) {
                  if (selected) {
                    setState(() {
                      _roleFilter = role;
                    });
                  }
                },
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildQuotaProgress(String title, int current, int max, Color color) {
    double progress = max == 0 ? 0 : current / max;
    bool isFull = current >= max;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
            Text('$current / $max ${isFull ? '(LIMIT REACHED)' : ''}', 
                 style: TextStyle(color: isFull ? Colors.red : null, fontWeight: isFull ? FontWeight.bold : FontWeight.normal)),
          ],
        ),
        const SizedBox(height: 4),
        LinearProgressIndicator(
          value: progress,
          color: isFull ? Colors.red : color,
          backgroundColor: Colors.grey[300],
        ),
      ],
    );
  }

  Widget _buildUserList() {
    return StreamBuilder<List<AppUserModel>>(
      stream: _userService.streamUsers(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        var users = snapshot.data ?? [];

        // Apply filters
        if (_roleFilter != 'All') {
          users = users.where((u) => u.role.toLowerCase() == _roleFilter.toLowerCase()).toList();
        }
        if (_searchQuery.isNotEmpty) {
          users = users.where((u) => 
            u.displayName.toLowerCase().contains(_searchQuery) || 
            u.email.toLowerCase().contains(_searchQuery)
          ).toList();
        }

        if (users.isEmpty) {
          return const Center(child: Text('No users found.'));
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: users.length,
          itemBuilder: (context, index) {
            final user = users[index];
            return Card(
              elevation: 2,
              margin: const EdgeInsets.only(bottom: 12),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: _getRoleColor(user.role),
                  child: Text(user.displayName.isNotEmpty ? user.displayName[0].toUpperCase() : 'U'),
                ),
                title: Row(
                  children: [
                    Text(user.displayName, style: const TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(width: 8),
                    _buildRoleBadge(user.role),
                    if (!user.isActive) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(color: Colors.red[100], borderRadius: BorderRadius.circular(4)),
                        child: const Text('DEACTIVATED', style: TextStyle(fontSize: 10, color: Colors.red, fontWeight: FontWeight.bold)),
                      ),
                    ]
                  ],
                ),
                subtitle: Text(user.email),
                trailing: PopupMenuButton<String>(
                  onSelected: (val) {
                    if (val == 'edit') {
                      showDialog(
                        context: context,
                        builder: (context) => UserEditDialog(existingUser: user),
                      );
                    } else if (val == 'toggle') {
                      _userService.toggleUserStatus(user.uid, !user.isActive);
                    } else if (val == 'delete') {
                      _showDeleteConfirmation(user);
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(value: 'edit', child: Text('Edit Permissions')),
                    PopupMenuItem(value: 'toggle', child: Text(user.isActive ? 'Deactivate Account' : 'Activate Account')),
                    const PopupMenuItem(value: 'delete', child: Text('Delete User', style: TextStyle(color: Colors.red))),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Color _getRoleColor(String role) {
    switch (role.toLowerCase()) {
      case 'admin': return Colors.purple;
      case 'manager': return Colors.blue;
      case 'salesman': return Colors.amber;
      default: return Colors.grey;
    }
  }

  Widget _buildRoleBadge(String role) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: _getRoleColor(role).withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _getRoleColor(role)),
      ),
      child: Text(
        role.toUpperCase(),
        style: TextStyle(fontSize: 10, color: _getRoleColor(role), fontWeight: FontWeight.bold),
      ),
    );
  }

  void _showDeleteConfirmation(AppUserModel user) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete User?'),
        content: Text('Are you sure you want to completely remove ${user.displayName}? This action cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              _userService.deleteUser(user.uid);
              Navigator.pop(ctx);
            },
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
