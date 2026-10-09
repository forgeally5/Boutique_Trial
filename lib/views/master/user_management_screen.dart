import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../auth/models/app_user_model.dart';
import '../../auth/viewmodels/auth_viewmodel.dart';
import '../../services/user_management_service.dart';
import 'user_edit_dialog.dart';
import '../../utils/file_downloader.dart';

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
          Tooltip(
            message: 'Refresh data from server',
            child: IconButton(
              icon: const Icon(Icons.refresh_rounded),
              onPressed: reloadWebPage,
            ),
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
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
                ),
                const SizedBox(width: 16),
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
          ),
          Expanded(
            child: _buildUserList(),
          ),
        ],
      ),
    );
  }

  Widget _buildUserList() {
    final currentLoggedUser = context.watch<AuthViewModel>().appUser;
    final isCurrentRootAdmin = currentLoggedUser?.email.toLowerCase() == 'admin@ritumita.com';

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

        // Hide primary root admin from non-root users
        if (!isCurrentRootAdmin) {
          users = users.where((u) => u.email.toLowerCase() != 'admin@ritumita.com').toList();
        }

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
            final isThisUserRootAdmin = user.email.toLowerCase() == 'admin@ritumita.com';

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
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Tooltip(
                      message: isThisUserRootAdmin ? 'Root Admin cannot be deactivated' : 'Active Status',
                      child: Switch(
                        value: user.isActive,
                        onChanged: isThisUserRootAdmin ? null : (val) {
                          _userService.toggleUserStatus(user.uid, val);
                        },
                      ),
                    ),
                    if (!isThisUserRootAdmin || isCurrentRootAdmin)
                      IconButton(
                        icon: const Icon(Icons.edit),
                        tooltip: 'Edit User',
                        onPressed: () {
                          showDialog(
                            context: context,
                            builder: (context) => UserEditDialog(existingUser: user),
                          );
                        },
                      ),
                    if (!isThisUserRootAdmin)
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        tooltip: 'Delete User',
                        onPressed: () {
                          _showDeleteConfirmation(user);
                        },
                      ),
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
        color: _getRoleColor(role).withValues(alpha: 0.2),
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
