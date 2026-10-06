import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'auth/viewmodels/auth_viewmodel.dart';
import 'auth/models/app_user_model.dart';
import 'state/admin_state.dart';
import 'services/local_db_service.dart';
import 'views/inventory_view.dart';
import 'views/billing_view.dart';
import 'views/reports_view.dart';
import 'login_page.dart';
import 'views/widgets/connection_status_badge.dart';
import 'utils/boutique_theme.dart';
import 'views/master/user_management_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await LocalDbService().init();

  runApp(
    ChangeNotifierProvider<AuthViewModel>(
      create: (_) => AuthViewModel(),
      child: const TrilokAdminApp(),
    ),
  );
}

// ─── Root App ──────────────────────────────────────────────────────────────────

class TrilokAdminApp extends StatelessWidget {
  const TrilokAdminApp({super.key});

  @override
  Widget build(BuildContext context) {
    return FocusTraversalGroup(
      policy: WidgetOrderTraversalPolicy(),
      child: MaterialApp(
        title: 'RituMita Boutique',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          fontFamily: 'sans-serif',
          scaffoldBackgroundColor: BoutiqueColors.bgMain,
          colorScheme: ColorScheme.fromSeed(
            seedColor: BoutiqueColors.accent,
            primary: BoutiqueColors.accent,
            surface: BoutiqueColors.bgCard,
          ),
        ),
        home: const AuthGate(),
      ),
    );
  }
}

// ─── Auth Gate ─────────────────────────────────────────────────────────────────

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final authVM = context.watch<AuthViewModel>();

    switch (authVM.status) {
      case AuthStatus.initial:
      case AuthStatus.loading:
        return const _SplashScreen();

      case AuthStatus.authenticated:
        return const AdminHomeShell();

      case AuthStatus.unauthenticated:
      case AuthStatus.unauthorized:
      case AuthStatus.error:
        return const LoginPage();
    }
  }
}

// ─── Splash Screen ─────────────────────────────────────────────────────────────

class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: BoutiqueColors.bgMain,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(
              'assets/logo.png',
              height: 70,
              fit: BoxFit.contain,
              errorBuilder: (_, _, _) => const Text(
                'RituMita Boutique',
                style: TextStyle(
                  fontFamily: 'serif',
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2.0,
                  color: BoutiqueColors.textPrimary,
                ),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'HIGH-END RETAIL & BILLING',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 2.5,
                color: BoutiqueColors.accent,
              ),
            ),
            const SizedBox(height: 36),
            const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: BoutiqueColors.accent,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Admin Home Shell ──────────────────────────────────────────────────────────

class AdminHomeShell extends StatefulWidget {
  const AdminHomeShell({super.key});

  @override
  State<AdminHomeShell> createState() => _AdminHomeShellState();
}

class _AdminHomeShellState extends State<AdminHomeShell> {
  final AdminState _state = AdminState();
  int _activeTabIndex = 0; // 0 = uninitialized
  String _selectedBillingSection = 'A Sales Entry';
  final TextEditingController _globalSearchCtrl = TextEditingController();

  void _switchTab(int index) {
    if (index == _activeTabIndex) return;
    LocalDbService().saveActiveTab(index);
    setState(() {
      _activeTabIndex = index;
    });
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final perms = context.read<AuthViewModel>().appUser?.permissions ?? PermissionsModel.adminPreset();
      if (mounted && _activeTabIndex == 0) {
        setState(() {
          final savedTab = LocalDbService().getActiveTab();
          if (savedTab != null) {
            _activeTabIndex = savedTab;
          } else if (perms.viewInventory) {
            _activeTabIndex = 1;
          } else if (perms.salesEntry) {
            _activeTabIndex = 2;
          } else if (perms.viewReports) {
            _activeTabIndex = 3;
          } else if (perms.manageUsers) {
            _activeTabIndex = 4;
          } else {
            _activeTabIndex = 5;
          }
        });
      }
    });

    _state.addListener(() {
      if (mounted) {
        if (_state.requestedTabIndex != null) {
          final target = _state.requestedTabIndex!;
          _state.requestedTabIndex = null;
          _switchTab(target);
          return;
        }
        if (_state.pendingEstimationTags.isNotEmpty) {
          if (_activeTabIndex != 2 || _selectedBillingSection != 'A Sales Entry') {
            _selectedBillingSection = 'A Sales Entry';
            _switchTab(2);
          } else {
            setState(() {});
          }
        } else {
          setState(() {});
        }
      }
    });
  }

  @override
  void dispose() {
    _state.dispose();
    _globalSearchCtrl.dispose();
    super.dispose();
  }

  // Tab index → IndexedStack position mapping
  // 1=Inventory, 2=Billing, 3=Reports, 4=Users, 5=Settings
  static const _tabToStackIndex = {1: 0, 2: 1, 3: 2, 4: 3, 5: 4};
  int get _stackIndex => _tabToStackIndex[_activeTabIndex] ?? 0;

  Widget _buildSettingsView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Boutique Settings',
            style: TextStyle(
              fontFamily: 'serif',
              fontSize: 26,
              fontWeight: FontWeight.bold,
              color: BoutiqueColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Manage session and system settings.',
            style: TextStyle(fontSize: 14, color: BoutiqueColors.textSecondary),
          ),
          const SizedBox(height: 32),
          Wrap(
            spacing: 20,
            runSpacing: 20,
            children: [
              _buildSettingsCard(
                icon: Icons.lock_reset_rounded,
                title: 'Change Password',
                subtitle: 'Update your admin login password',
                onTap: _openChangePassword,
              ),
              _buildSettingsCard(
                icon: Icons.logout_rounded,
                title: 'Logout Admin',
                subtitle: 'Sign out of current boutique session',
                isDestructive: true,
                onTap: _handleLogout,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 320,
        padding: const EdgeInsets.all(24),
        decoration: BoutiqueDecoration.card(
          borderColor: isDestructive ? BoutiqueColors.destructive.withValues(alpha: 0.3) : BoutiqueColors.border,
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDestructive ? BoutiqueColors.destructiveBg : BoutiqueColors.accentSoft,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                icon,
                color: isDestructive ? BoutiqueColors.destructive : BoutiqueColors.accent,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: isDestructive ? BoutiqueColors.destructive : BoutiqueColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(fontSize: 12, color: BoutiqueColors.textSecondary),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Logout ─────────────────────────────────────────────────────────────────

  Future<void> _handleLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        backgroundColor: BoutiqueColors.bgCard,
        title: const Text(
          'Confirm Logout',
          style: TextStyle(
            fontFamily: 'serif',
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: BoutiqueColors.textPrimary,
          ),
        ),
        content: const Text(
          'Are you sure you want to log out of the admin panel?',
          style: TextStyle(fontSize: 14, color: BoutiqueColors.textSecondary),
        ),
        actions: [
          OutlinedButton(
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: BoutiqueColors.border),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel', style: TextStyle(color: BoutiqueColors.textSecondary)),
          ),
          ElevatedButton(
            autofocus: true,
            style: ElevatedButton.styleFrom(
              backgroundColor: BoutiqueColors.destructive,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Logout'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await context.read<AuthViewModel>().logout();
    }
  }

  void _openChangePassword() {
    final currentCtrl = TextEditingController();
    final newCtrl = TextEditingController();
    final confirmCtrl = TextEditingController();
    String? errorMsg;
    bool isLoading = false;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              backgroundColor: BoutiqueColors.bgCard,
              title: const Text(
                'Change Password',
                style: TextStyle(
                  fontFamily: 'serif',
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: BoutiqueColors.textPrimary,
                ),
              ),
              content: SizedBox(
                width: 340,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (errorMsg != null)
                      Container(
                        padding: const EdgeInsets.all(10),
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFEBEE),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          errorMsg!,
                          style: const TextStyle(color: BoutiqueColors.destructive, fontSize: 13),
                        ),
                      ),
                    TextField(
                      controller: currentCtrl,
                      obscureText: true,
                      decoration: BoutiqueInputDecoration.field(hintText: 'Current Password'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: newCtrl,
                      obscureText: true,
                      decoration: BoutiqueInputDecoration.field(hintText: 'New Password'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: confirmCtrl,
                      obscureText: true,
                      decoration: BoutiqueInputDecoration.field(hintText: 'Confirm New Password'),
                    ),
                  ],
                ),
              ),
              actions: [
                OutlinedButton(
                  onPressed: isLoading ? null : () => Navigator.pop(ctx),
                  child: const Text('Cancel', style: TextStyle(color: BoutiqueColors.textSecondary)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: BoutiqueColors.accent),
                  onPressed: isLoading
                      ? null
                      : () async {
                          final curr = currentCtrl.text.trim();
                          final newP = newCtrl.text.trim();
                          final confP = confirmCtrl.text.trim();
                          if (curr.isEmpty || newP.isEmpty || confP.isEmpty) {
                            setDialogState(() => errorMsg = 'Please fill in all fields.');
                            return;
                          }
                          if (newP.length < 6) {
                            setDialogState(() => errorMsg = 'New password must be at least 6 characters.');
                            return;
                          }
                          if (newP != confP) {
                            setDialogState(() => errorMsg = 'New passwords do not match.');
                            return;
                          }

                          setDialogState(() {
                            isLoading = true;
                            errorMsg = null;
                          });

                          try {
                            await context.read<AuthViewModel>().changePassword(
                                  currentPassword: curr,
                                  newPassword: newP,
                                );
                            if (ctx.mounted) {
                              Navigator.pop(ctx);
                              BoutiqueToast.showSuccess(context, 'Password updated successfully!');
                            }
                          } catch (e) {
                            setDialogState(() {
                              isLoading = false;
                              errorMsg = e.toString().replaceAll('Exception: ', '');
                            });
                          }
                        },
                  child: isLoading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('Update Password', style: TextStyle(color: Colors.white)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width >= 900;
    final authUser = context.watch<AuthViewModel>().appUser;
    final userEmail = authUser?.email ?? 'admin@ritumita.com';
    final perms = authUser?.permissions ?? PermissionsModel.adminPreset();
    
    final canViewInventory = perms.viewInventory;
    final canViewBilling = perms.salesEntry; // Billing access
    final canViewReports = perms.viewReports;
    final canManageUsers = perms.manageUsers;
    final canViewSettings = authUser?.role.toLowerCase() == 'admin' || perms.manageUsers;

    // Track allowed tabs dynamically based on user permissions
    final allowedTabs = <int>[];
    if (canViewInventory) allowedTabs.add(1);
    if (canViewBilling) allowedTabs.add(2);
    if (canViewReports) allowedTabs.add(3);
    if (canManageUsers) allowedTabs.add(4);
    if (canViewSettings) allowedTabs.add(5);

    // If no tabs are allowed at all:
    if (allowedTabs.isEmpty) {
      return Scaffold(
        backgroundColor: BoutiqueColors.bgMain,
        body: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 420),
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: BoutiqueColors.bgCard,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: BoutiqueColors.border),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.lock_person_outlined, size: 56, color: BoutiqueColors.accent),
                const SizedBox(height: 16),
                const Text('Access Restricted', style: TextStyle(fontFamily: 'serif', fontSize: 20, fontWeight: FontWeight.bold, color: BoutiqueColors.textPrimary)),
                const SizedBox(height: 8),
                const Text(
                  'No module permissions have been assigned to your account yet. Please ask your administrator to grant permissions.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: BoutiqueColors.textSecondary, fontSize: 13),
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: _handleLogout,
                  icon: const Icon(Icons.logout, size: 16),
                  label: const Text('Log Out'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: BoutiqueColors.accent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Auto-switch to first allowed tab if current active tab is forbidden
    if (!allowedTabs.contains(_activeTabIndex)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !allowedTabs.contains(_activeTabIndex)) {
          setState(() {
            _activeTabIndex = allowedTabs.first;
          });
        }
      });
    }

    // Guard to wait for init logic to assign active tab
    if (_activeTabIndex == 0) return const Scaffold(backgroundColor: BoutiqueColors.bgMain);

    return Scaffold(
      backgroundColor: BoutiqueColors.bgMain,
      body: Row(
        children: [
          // ── Persistent Left Sidebar (Desktop / Tablet) ──────────────────────
          if (isDesktop)
            Container(
              width: 240,
              decoration: const BoxDecoration(
                color: BoutiqueColors.bgCard,
                border: Border(right: BorderSide(color: BoutiqueColors.border, width: 1)),
              ),
              child: Column(
                children: [
                  // Logo Header
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
                    child: Row(
                      children: [
                        Flexible(
                          child: Image.asset(
                            'assets/logo.png',
                            height: 48,
                            fit: BoxFit.contain,
                            alignment: Alignment.centerLeft,
                            errorBuilder: (_, _, _) => const Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'RituMita Boutique',
                                  style: TextStyle(
                                    fontFamily: 'serif',
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: BoutiqueColors.textPrimary,
                                    letterSpacing: 0.5,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  'BOUTIQUE RETAIL',
                                  style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 1.5,
                                    color: BoutiqueColors.accent,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1, color: BoutiqueColors.borderLight),
                  const SizedBox(height: 16),

                  // Nav Items
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      children: [
                        if (canViewInventory) _buildNavItem(1, Icons.inventory_2_outlined, 'Inventory'),
                        if (canViewBilling) _buildNavItem(2, Icons.point_of_sale_rounded, 'Billing / POS'),
                        if (canViewReports) _buildNavItem(3, Icons.analytics_outlined, 'Reports'),
                        if (canManageUsers) _buildNavItem(4, Icons.manage_accounts_outlined, 'Users'),
                        if (canViewSettings) _buildNavItem(5, Icons.settings_outlined, 'Settings'),
                      ],
                    ),
                  ),

                  // Bottom Profile Banner in Sidebar
                  Container(
                    margin: const EdgeInsets.all(14),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: BoutiqueColors.bgSecondary,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: BoutiqueColors.borderLight),
                    ),
                    child: Row(
                      children: [
                        const CircleAvatar(
                          radius: 16,
                          backgroundColor: BoutiqueColors.accent,
                          child: Icon(Icons.person, color: Colors.white, size: 18),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                authUser?.email != null ? (authUser!.role.toUpperCase()) : 'Boutique Admin',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: BoutiqueColors.textPrimary,
                                ),
                              ),
                              Text(
                                userEmail,
                                style: const TextStyle(fontSize: 10, color: BoutiqueColors.textSecondary),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.logout_rounded, size: 16, color: BoutiqueColors.textSecondary),
                          onPressed: _handleLogout,
                          tooltip: 'Logout',
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

          // ── Main Content Area (Header + Body) ──────────────────────────────
          Expanded(
            child: Column(
              children: [
                // Top Header Bar (Mobile only)
                if (!isDesktop)
                  Container(
                    height: 56,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: const BoxDecoration(
                      color: BoutiqueColors.bgCard,
                      border: Border(bottom: BorderSide(color: BoutiqueColors.border, width: 1)),
                    ),
                    child: Row(
                      children: [
                        PopupMenuButton<int>(
                          icon: const Icon(Icons.menu_rounded, color: BoutiqueColors.textPrimary),
                          onSelected: (idx) => _switchTab(idx),
                          itemBuilder: (ctx) => [
                            if (canViewInventory) const PopupMenuItem(value: 1, child: Text('Inventory')),
                            if (canViewBilling) const PopupMenuItem(value: 2, child: Text('Billing / POS')),
                            if (canViewReports) const PopupMenuItem(value: 3, child: Text('Reports')),
                            if (canManageUsers) const PopupMenuItem(value: 4, child: Text('Users')),
                            if (canViewSettings) const PopupMenuItem(value: 5, child: Text('Settings')),
                          ],
                        ),
                        const SizedBox(width: 8),
                        Image.asset(
                          'assets/logo.png',
                          height: 32,
                          fit: BoxFit.contain,
                          errorBuilder: (_, _, _) => const Text(
                            'RituMita Boutique',
                            style: TextStyle(
                              fontFamily: 'serif',
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: BoutiqueColors.textPrimary,
                            ),
                          ),
                        ),
                        const Spacer(),
                        ConnectionStatusBadge(state: _state),
                      ],
                    ),
                  ),

                // Page Body — IndexedStack keeps all views alive for instant tab switching
                Expanded(
                  child: ChangeNotifierProvider<AdminState>.value(
                    value: _state,
                    child: IndexedStack(
                      index: _stackIndex,
                    children: [
                      // Index 0: Inventory
                      InventoryView(state: _state, globalSearchCtrl: _globalSearchCtrl),
                      // Index 1: Billing
                      BillingView(
                        state: _state,
                        initialSection: _selectedBillingSection,
                        onSectionChanged: (sec) {
                          setState(() => _selectedBillingSection = sec);
                        },
                      ),
                      // Index 2: Reports
                      const ReportsView(),
                      // Index 3: Users
                      const UserManagementScreen(),
                      // Index 4: Settings
                      _buildSettingsView(),
                    ],
                  ),
                ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, String label) {
    final isSelected = _activeTabIndex == index;
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      child: InkWell(
        onTap: () => _switchTab(index),
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? BoutiqueColors.accentSoft : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            border: isSelected ? Border.all(color: BoutiqueColors.accentLightBorder, width: 1) : null,
          ),
          child: Row(
            children: [
              Icon(
                icon,
                size: 20,
                color: isSelected ? BoutiqueColors.accent : BoutiqueColors.textSecondary,
              ),
              const SizedBox(width: 14),
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  color: isSelected ? BoutiqueColors.accent : BoutiqueColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Dot Circle Spinner ─────────────────────────────────────────────────────────

class _DotSpinner extends StatefulWidget {
  const _DotSpinner();

  @override
  State<_DotSpinner> createState() => _DotSpinnerState();
}

class _DotSpinnerState extends State<_DotSpinner> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (context, child) => CustomPaint(
          size: const Size(48, 48),
          painter: _DotSpinnerPainter(_ctrl.value),
        ),
      ),
    );
  }
}

class _DotSpinnerPainter extends CustomPainter {
  final double progress;
  static const int _n = 12;

  const _DotSpinnerPainter(this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 4;

    for (int i = 0; i < _n; i++) {
      final t = (i + 1) / _n;
      final angle = (2 * math.pi * i / _n) - (2 * math.pi * progress);
      final pos = Offset(
        center.dx + radius * math.cos(angle),
        center.dy + radius * math.sin(angle),
      );

      final dotRadius = 1.5 + t * 2.0;
      final opacity = t * t;

      final dotPaint = Paint()
        ..color = BoutiqueColors.accent.withValues(alpha: opacity.clamp(0.0, 1.0));
      canvas.drawCircle(pos, dotRadius, dotPaint);
    }
  }

  @override
  bool shouldRepaint(_DotSpinnerPainter old) => old.progress != progress;
}
