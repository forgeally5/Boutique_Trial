import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
import 'utils/file_downloader.dart';
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
  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
  const TrilokAdminApp({super.key});

  @override
  Widget build(BuildContext context) {
    return FocusTraversalGroup(
      policy: WidgetOrderTraversalPolicy(),
      child: MaterialApp(
        navigatorKey: navigatorKey,
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
        builder: (context, child) {
          return SessionTimeoutWatcher(
            timeout: const Duration(minutes: 15),
            child: child ?? const SizedBox.shrink(),
          );
        },
        home: const AuthGate(),
      ),
    );
  }
}

// ─── Inactivity / Auto-Logout Watcher (15 minutes idle timeout) ───────────────

class SessionTimeoutWatcher extends StatefulWidget {
  final Widget child;
  final Duration timeout;

  const SessionTimeoutWatcher({
    super.key,
    required this.child,
    this.timeout = const Duration(minutes: 15),
  });

  @override
  State<SessionTimeoutWatcher> createState() => _SessionTimeoutWatcherState();
}

class _SessionTimeoutWatcherState extends State<SessionTimeoutWatcher> {
  Timer? _timer;
  DateTime _lastActivity = DateTime.now();

  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_handleKeyEvent);
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_handleKeyEvent);
    _timer?.cancel();
    super.dispose();
  }

  bool _handleKeyEvent(KeyEvent event) {
    _recordActivity();
    return false; // Do not consume the key event
  }

  void _recordActivity() {
    final now = DateTime.now();
    // Throttle activity recording to at most once per second
    if (now.difference(_lastActivity).inSeconds >= 1) {
      _lastActivity = now;
      _startTimer();
    }
  }

  void _startTimer() {
    _timer?.cancel();
    final authVM = context.read<AuthViewModel>();
    if (!authVM.isAuthenticated) {
      _timer = null;
      return;
    }
    _timer = Timer(widget.timeout, _handleTimeout);
  }

  Future<void> _handleTimeout() async {
    final authVM = context.read<AuthViewModel>();
    if (!authVM.isAuthenticated || !mounted) return;

    debugPrint('[AutoLogout] 15 minutes of inactivity detected. Logging out user...');

    // Pop any open modal dialogs so they don't block the login screen
    TrilokAdminApp.navigatorKey.currentState?.popUntil((route) => route.isFirst);

    // Save active tab as Billing for next login
    LocalDbService().saveActiveTab(2);

    await authVM.logout();

    final currentCtx = TrilokAdminApp.navigatorKey.currentContext;
    if (currentCtx != null && currentCtx.mounted) {
      BoutiqueToast.showWarning(
        currentCtx,
        'Logged out automatically due to 15 minutes of inactivity.',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isAuthenticated = context.select<AuthViewModel, bool>((vm) => vm.isAuthenticated);
    if (!isAuthenticated) {
      _timer?.cancel();
      _timer = null;
    } else if (_timer == null || !_timer!.isActive) {
      _lastActivity = DateTime.now();
      _startTimer();
    }

    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) => _recordActivity(),
      onPointerMove: (_) => _recordActivity(),
      onPointerHover: (_) => _recordActivity(),
      onPointerSignal: (_) => _recordActivity(),
      child: widget.child,
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
  final GlobalKey<ReportsViewState> _reportsKey = GlobalKey<ReportsViewState>();
  final GlobalKey<BillingViewState> _billingKey = GlobalKey<BillingViewState>();
  int _reportsSubTab = 0;
  int _activeTabIndex = 2; // Default to Billing / POS on login
  String _selectedBillingSection = 'A Sales Entry';
  final TextEditingController _globalSearchCtrl = TextEditingController();
  final FocusScopeNode _mainContentFocusScopeNode = FocusScopeNode(debugLabel: 'MainContentFocusScope');

  void _switchTab(int index) {
    if (index == _activeTabIndex) return;
    LocalDbService().saveActiveTab(index);
    setState(() {
      _activeTabIndex = index;
    });
  }

  void _focusMainContent() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _mainContentFocusScopeNode.requestFocus();
      final firstNode = _mainContentFocusScopeNode.traversalChildren.firstOrNull;
      if (firstNode != null) {
        firstNode.requestFocus();
      } else {
        _mainContentFocusScopeNode.nextFocus();
      }
    });
  }

  void _switchAndFocus(int targetTab) {
    final authUser = context.read<AuthViewModel>().appUser;
    final perms = authUser?.permissions ?? PermissionsModel.adminPreset();
    final canViewSettings = authUser?.role.toLowerCase() == 'admin' || perms.manageUsers;
    bool allowed = false;
    if (targetTab == 1 && perms.viewInventory) allowed = true;
    if (targetTab == 2 && perms.salesEntry) allowed = true;
    if (targetTab == 3 && perms.viewReports) allowed = true;
    if (targetTab == 4 && perms.manageUsers) allowed = true;
    if (targetTab == 5 && canViewSettings) allowed = true;

    if (allowed) {
      _switchTab(targetTab);
      _focusMainContent();
    }
  }

  void _navigateToReportTab(int subTab) {
    final authUser = context.read<AuthViewModel>().appUser;
    final perms = authUser?.permissions ?? PermissionsModel.adminPreset();
    if (!perms.viewReports) return;

    if (_activeTabIndex != 3) {
      _switchTab(3);
    }
    setState(() {
      _reportsSubTab = subTab;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _reportsKey.currentState?.selectTab(subTab);
      _focusMainContent();
    });
  }

  void _navigateToBillingTab(int subTab) {
    final authUser = context.read<AuthViewModel>().appUser;
    final perms = authUser?.permissions ?? PermissionsModel.adminPreset();
    if (!perms.salesEntry && !perms.viewReports) return;

    if (_activeTabIndex != 2) {
      _switchTab(2);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _billingKey.currentState?.selectTab(subTab);
      _focusMainContent();
    });
  }

  bool _handleGlobalKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent) return false;

    final isAlt = HardwareKeyboard.instance.isAltPressed;
    final isCtrl = HardwareKeyboard.instance.isControlPressed;
    final isMeta = HardwareKeyboard.instance.isMetaPressed;
    final isShift = HardwareKeyboard.instance.isShiftPressed;
    final isCtrlOrMeta = isCtrl || isMeta;

    // Logout shortcuts: Alt+L, Alt+Q, Ctrl+Shift+L, Ctrl+Shift+Q, Meta+Shift+L, Meta+Shift+Q
    if ((isAlt && (event.logicalKey == LogicalKeyboardKey.keyL || event.logicalKey == LogicalKeyboardKey.keyQ)) ||
        (isCtrlOrMeta && isShift && (event.logicalKey == LogicalKeyboardKey.keyL || event.logicalKey == LogicalKeyboardKey.keyQ))) {
      _handleLogout();
      return true;
    }

    // Reports sub-tab shortcuts: Alt + 1..4 OR Ctrl + Shift + 1..4 (Works from any page!)
    if ((isAlt && !isCtrlOrMeta) || (isCtrlOrMeta && isShift)) {
      if (event.logicalKey == LogicalKeyboardKey.digit1 || event.logicalKey == LogicalKeyboardKey.numpad1) {
        _navigateToReportTab(0);
        return true;
      }
      if (event.logicalKey == LogicalKeyboardKey.digit2 || event.logicalKey == LogicalKeyboardKey.numpad2) {
        _navigateToReportTab(1);
        return true;
      }
      if (event.logicalKey == LogicalKeyboardKey.digit3 || event.logicalKey == LogicalKeyboardKey.numpad3) {
        _navigateToReportTab(2);
        return true;
      }
      if (event.logicalKey == LogicalKeyboardKey.digit4 || event.logicalKey == LogicalKeyboardKey.numpad4) {
        _navigateToReportTab(3);
        return true;
      }

      // Billing sub-tab shortcuts: Alt + B, Alt + H, Alt + C (Works from any page!)
      if (event.logicalKey == LogicalKeyboardKey.keyB) {
        _navigateToBillingTab(0);
        return true;
      }
      if (event.logicalKey == LogicalKeyboardKey.keyH) {
        _navigateToBillingTab(1);
        return true;
      }
      if (event.logicalKey == LogicalKeyboardKey.keyC) {
        _navigateToBillingTab(2);
        return true;
      }
    }

    // Main navigation tabs: Ctrl+1..5 / Meta+1..5 (without Shift)
    if (isCtrlOrMeta && !isShift && !isAlt) {
      if (event.logicalKey == LogicalKeyboardKey.digit1 || event.logicalKey == LogicalKeyboardKey.numpad1) {
        _switchAndFocus(1);
        return true;
      }
      if (event.logicalKey == LogicalKeyboardKey.digit2 || event.logicalKey == LogicalKeyboardKey.numpad2) {
        _switchAndFocus(2);
        return true;
      }
      if (event.logicalKey == LogicalKeyboardKey.digit3 || event.logicalKey == LogicalKeyboardKey.numpad3) {
        _switchAndFocus(3);
        return true;
      }
      if (event.logicalKey == LogicalKeyboardKey.digit4 || event.logicalKey == LogicalKeyboardKey.numpad4) {
        _switchAndFocus(4);
        return true;
      }
      if (event.logicalKey == LogicalKeyboardKey.digit5 || event.logicalKey == LogicalKeyboardKey.numpad5) {
        _switchAndFocus(5);
        return true;
      }
    }

    return false;
  }

  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_handleGlobalKeyEvent);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final perms = context.read<AuthViewModel>().appUser?.permissions ?? PermissionsModel.adminPreset();
      if (mounted) {
        setState(() {
          // Whenever user logs in, prioritize Billing / POS (tab 2)
          if (perms.salesEntry) {
            _activeTabIndex = 2;
          } else if (perms.viewInventory) {
            _activeTabIndex = 1;
          } else if (perms.viewReports) {
            _activeTabIndex = 3;
          } else if (perms.manageUsers) {
            _activeTabIndex = 4;
          } else {
            _activeTabIndex = 5;
          }
          _selectedBillingSection = 'A Sales Entry';
          LocalDbService().saveActiveTab(_activeTabIndex);
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
    HardwareKeyboard.instance.removeHandler(_handleGlobalKeyEvent);
    _mainContentFocusScopeNode.dispose();
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
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
                  ],
                ),
              ),
              Tooltip(
                message: 'Refresh data from server (F5)',
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.refresh_rounded, size: 16, color: BoutiqueColors.accent),
                  label: const Text(
                    'Refresh',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: BoutiqueColors.accent,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    backgroundColor: BoutiqueColors.bgCard,
                    side: const BorderSide(color: BoutiqueColors.accentLightBorder),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  ),
                  onPressed: reloadWebPage,
                ),
              ),
            ],
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
                title: 'Logout Admin (Alt+L)',
                subtitle: 'Sign out of current session (Alt+L / Ctrl+Shift+L)',
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
    bool? confirmed;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return CallbackShortcuts(
          bindings: {
            const SingleActivator(LogicalKeyboardKey.escape): () {
              Navigator.of(ctx).pop();
            },
            const SingleActivator(LogicalKeyboardKey.enter): () {
              confirmed = true;
              Navigator.of(ctx).pop();
            },
            const SingleActivator(LogicalKeyboardKey.numpadEnter): () {
              confirmed = true;
              Navigator.of(ctx).pop();
            },
          },
          child: Focus(
            autofocus: true,
            child: AlertDialog(
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
                  onPressed: () {
                    confirmed = false;
                    Navigator.of(ctx).pop();
                  },
                  child: const Text('Cancel', style: TextStyle(color: BoutiqueColors.textSecondary)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: BoutiqueColors.destructive,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () {
                    confirmed = true;
                    Navigator.of(ctx).pop();
                  },
                  child: const Text('Logout'),
                ),
              ],
            ),
          ),
        );
      },
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

    return CallbackShortcuts(
      bindings: {
        // Ctrl + 1..5 & Numpad 1..5 for Windows / Linux
        const SingleActivator(LogicalKeyboardKey.digit1, control: true): () => _switchAndFocus(1),
        const SingleActivator(LogicalKeyboardKey.digit2, control: true): () => _switchAndFocus(2),
        const SingleActivator(LogicalKeyboardKey.digit3, control: true): () => _switchAndFocus(3),
        const SingleActivator(LogicalKeyboardKey.digit4, control: true): () => _switchAndFocus(4),
        const SingleActivator(LogicalKeyboardKey.digit5, control: true): () => _switchAndFocus(5),
        const SingleActivator(LogicalKeyboardKey.numpad1, control: true): () => _switchAndFocus(1),
        const SingleActivator(LogicalKeyboardKey.numpad2, control: true): () => _switchAndFocus(2),
        const SingleActivator(LogicalKeyboardKey.numpad3, control: true): () => _switchAndFocus(3),
        const SingleActivator(LogicalKeyboardKey.numpad4, control: true): () => _switchAndFocus(4),
        const SingleActivator(LogicalKeyboardKey.numpad5, control: true): () => _switchAndFocus(5),
        // Meta (Command) + 1..5 for macOS
        const SingleActivator(LogicalKeyboardKey.digit1, meta: true): () => _switchAndFocus(1),
        const SingleActivator(LogicalKeyboardKey.digit2, meta: true): () => _switchAndFocus(2),
        const SingleActivator(LogicalKeyboardKey.digit3, meta: true): () => _switchAndFocus(3),
        const SingleActivator(LogicalKeyboardKey.digit4, meta: true): () => _switchAndFocus(4),
        const SingleActivator(LogicalKeyboardKey.digit5, meta: true): () => _switchAndFocus(5),
        // Alt + 1..4 (Reports: Issue, Stock, Sales, Inward)
        const SingleActivator(LogicalKeyboardKey.digit1, alt: true): () => _navigateToReportTab(0),
        const SingleActivator(LogicalKeyboardKey.digit2, alt: true): () => _navigateToReportTab(1),
        const SingleActivator(LogicalKeyboardKey.digit3, alt: true): () => _navigateToReportTab(2),
        const SingleActivator(LogicalKeyboardKey.digit4, alt: true): () => _navigateToReportTab(3),
        const SingleActivator(LogicalKeyboardKey.numpad1, alt: true): () => _navigateToReportTab(0),
        const SingleActivator(LogicalKeyboardKey.numpad2, alt: true): () => _navigateToReportTab(1),
        const SingleActivator(LogicalKeyboardKey.numpad3, alt: true): () => _navigateToReportTab(2),
        const SingleActivator(LogicalKeyboardKey.numpad4, alt: true): () => _navigateToReportTab(3),
        // Ctrl + Shift + 1..4 (Reports: Issue, Stock, Sales, Inward)
        const SingleActivator(LogicalKeyboardKey.digit1, control: true, shift: true): () => _navigateToReportTab(0),
        const SingleActivator(LogicalKeyboardKey.digit2, control: true, shift: true): () => _navigateToReportTab(1),
        const SingleActivator(LogicalKeyboardKey.digit3, control: true, shift: true): () => _navigateToReportTab(2),
        const SingleActivator(LogicalKeyboardKey.digit4, control: true, shift: true): () => _navigateToReportTab(3),
        // Alt + B, H, C (Billing: Create Bill, Bill History, Customer Ledger)
        const SingleActivator(LogicalKeyboardKey.keyB, alt: true): () => _navigateToBillingTab(0),
        const SingleActivator(LogicalKeyboardKey.keyH, alt: true): () => _navigateToBillingTab(1),
        const SingleActivator(LogicalKeyboardKey.keyC, alt: true): () => _navigateToBillingTab(2),
        const SingleActivator(LogicalKeyboardKey.keyB, control: true, shift: true): () => _navigateToBillingTab(0),
        const SingleActivator(LogicalKeyboardKey.keyH, control: true, shift: true): () => _navigateToBillingTab(1),
        const SingleActivator(LogicalKeyboardKey.keyC, control: true, shift: true): () => _navigateToBillingTab(2),
        // Logout shortcuts
        const SingleActivator(LogicalKeyboardKey.keyL, control: true, shift: true): _handleLogout,
        const SingleActivator(LogicalKeyboardKey.keyL, alt: true): _handleLogout,
        const SingleActivator(LogicalKeyboardKey.keyQ, control: true, shift: true): _handleLogout,
        const SingleActivator(LogicalKeyboardKey.keyQ, alt: true): _handleLogout,
        const SingleActivator(LogicalKeyboardKey.keyL, meta: true, shift: true): _handleLogout,
        const SingleActivator(LogicalKeyboardKey.keyQ, meta: true, shift: true): _handleLogout,
      },
      child: FocusScope(
        autofocus: true,
        child: Scaffold(
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
                        if (canViewInventory) _buildNavItem(1, Icons.inventory_2_outlined, 'Inventory', shortcut: 'Ctrl+1'),
                        if (canViewBilling) _buildNavItem(2, Icons.point_of_sale_rounded, 'Billing / POS', shortcut: 'Ctrl+2'),
                        if (canViewReports) _buildNavItem(3, Icons.analytics_outlined, 'Reports', shortcut: 'Ctrl+3'),
                        if (canManageUsers) _buildNavItem(4, Icons.manage_accounts_outlined, 'Users', shortcut: 'Ctrl+4'),
                        if (canViewSettings) _buildNavItem(5, Icons.settings_outlined, 'Settings', shortcut: 'Ctrl+5'),
                        const SizedBox(height: 12),
                        const Divider(height: 1, color: BoutiqueColors.borderLight),
                        const SizedBox(height: 12),
                        _buildLogoutNavItem(shortcut: 'Alt+L'),
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
                          icon: const Icon(Icons.refresh_rounded, size: 16, color: BoutiqueColors.accent),
                          onPressed: reloadWebPage,
                          tooltip: 'Speed Refresh (F5)',
                        ),
                        IconButton(
                          icon: const Icon(Icons.logout_rounded, size: 16, color: BoutiqueColors.destructive),
                          onPressed: _handleLogout,
                          tooltip: 'Logout (Alt+L)',
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
                          onSelected: (idx) {
                            if (idx == 99) {
                              _handleLogout();
                            } else {
                              _switchTab(idx);
                            }
                          },
                          itemBuilder: (ctx) => [
                            if (canViewInventory) const PopupMenuItem(value: 1, child: Text('Inventory (Ctrl+1)')),
                            if (canViewBilling) const PopupMenuItem(value: 2, child: Text('Billing / POS (Ctrl+2)')),
                            if (canViewReports) const PopupMenuItem(value: 3, child: Text('Reports (Ctrl+3)')),
                            if (canManageUsers) const PopupMenuItem(value: 4, child: Text('Users (Ctrl+4)')),
                            if (canViewSettings) const PopupMenuItem(value: 5, child: Text('Settings (Ctrl+5)')),
                            const PopupMenuDivider(),
                            const PopupMenuItem(
                              value: 99,
                              child: Row(
                                children: [
                                  Icon(Icons.logout_rounded, size: 18, color: BoutiqueColors.destructive),
                                  SizedBox(width: 8),
                                  Text('Logout (Alt+L)', style: TextStyle(color: BoutiqueColors.destructive)),
                                ],
                              ),
                            ),
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
                        IconButton(
                          icon: const Icon(Icons.refresh_rounded, color: BoutiqueColors.accent),
                          onPressed: reloadWebPage,
                          tooltip: 'Speed Refresh',
                        ),
                        ConnectionStatusBadge(state: _state),
                      ],
                    ),
                  ),

                // Page Body — IndexedStack keeps all views alive for instant tab switching
                Expanded(
                  child: FocusScope(
                    node: _mainContentFocusScopeNode,
                    child: ChangeNotifierProvider<AdminState>.value(
                      value: _state,
                      child: IndexedStack(
                        index: _stackIndex,
                        children: [
                          // Index 0: Inventory
                          ExcludeFocus(
                            excluding: _stackIndex != 0,
                            child: InventoryView(state: _state, globalSearchCtrl: _globalSearchCtrl),
                          ),
                          // Index 1: Billing
                          ExcludeFocus(
                            excluding: _stackIndex != 1,
                            child: BillingView(
                              key: _billingKey,
                              state: _state,
                              initialSection: _selectedBillingSection,
                              onSectionChanged: (sec) {
                                setState(() => _selectedBillingSection = sec);
                              },
                            ),
                          ),
                          // Index 2: Reports
                          ExcludeFocus(
                            excluding: _stackIndex != 2,
                            child: ReportsView(
                              key: _reportsKey,
                              isActive: _stackIndex == 2,
                              targetSubTab: _reportsSubTab,
                              onSubTabChanged: (tab) {
                                _reportsSubTab = tab;
                              },
                            ),
                          ),
                          // Index 3: Users
                          ExcludeFocus(
                            excluding: _stackIndex != 3,
                            child: const UserManagementScreen(),
                          ),
                          // Index 4: Settings
                          ExcludeFocus(
                            excluding: _stackIndex != 4,
                            child: _buildSettingsView(),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
    ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, String label, {String? shortcut}) {
    return _SidebarNavItem(
      index: index,
      icon: icon,
      label: label,
      shortcut: shortcut,
      isSelected: _activeTabIndex == index,
      onTap: () {
        _switchTab(index);
        _focusMainContent();
      },
      onEnterOrRight: () {
        _switchTab(index);
        _focusMainContent();
      },
    );
  }

  Widget _buildLogoutNavItem({String? shortcut}) {
    return _SidebarNavItem(
      index: -1,
      icon: Icons.logout_rounded,
      label: 'Logout',
      shortcut: shortcut ?? 'Alt+L',
      isSelected: false,
      isDestructive: true,
      onTap: _handleLogout,
      onEnterOrRight: _handleLogout,
    );
  }
}

class _SidebarNavItem extends StatefulWidget {
  final int index;
  final IconData icon;
  final String label;
  final String? shortcut;
  final bool isSelected;
  final bool isDestructive;
  final VoidCallback onTap;
  final VoidCallback onEnterOrRight;

  const _SidebarNavItem({
    required this.index,
    required this.icon,
    required this.label,
    this.shortcut,
    required this.isSelected,
    this.isDestructive = false,
    required this.onTap,
    required this.onEnterOrRight,
  });

  @override
  State<_SidebarNavItem> createState() => _SidebarNavItemState();
}

class _SidebarNavItemState extends State<_SidebarNavItem> {
  bool _isHovered = false;
  bool _isFocused = false;

  @override
  Widget build(BuildContext context) {
    final showHighlight = widget.isSelected || _isHovered || _isFocused;
    final primaryColor = widget.isDestructive ? BoutiqueColors.destructive : BoutiqueColors.accent;
    final primaryBg = widget.isDestructive ? BoutiqueColors.destructiveBg : BoutiqueColors.accentSoft;

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      child: Focus(
        onFocusChange: (v) => setState(() => _isFocused = v),
        onKeyEvent: (node, event) {
          if (event is KeyDownEvent) {
            if (event.logicalKey == LogicalKeyboardKey.enter ||
                event.logicalKey == LogicalKeyboardKey.numpadEnter ||
                event.logicalKey == LogicalKeyboardKey.space ||
                event.logicalKey == LogicalKeyboardKey.arrowRight) {
              widget.onEnterOrRight();
              return KeyEventResult.handled;
            } else if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
              node.nextFocus();
              return KeyEventResult.handled;
            } else if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
              node.previousFocus();
              return KeyEventResult.handled;
            }
          }
          return KeyEventResult.ignored;
        },
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          onEnter: (_) => setState(() => _isHovered = true),
          onExit: (_) => setState(() => _isHovered = false),
          child: GestureDetector(
            onTap: widget.onTap,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: widget.isSelected
                    ? primaryBg
                    : (_isFocused || _isHovered
                        ? primaryBg.withValues(alpha: 0.5)
                        : Colors.transparent),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: widget.isSelected
                      ? (_isFocused ? primaryColor : BoutiqueColors.accentLightBorder)
                      : (_isFocused
                          ? primaryColor
                          : (_isHovered
                              ? (widget.isDestructive
                                  ? BoutiqueColors.destructive.withValues(alpha: 0.3)
                                  : BoutiqueColors.accentLightBorder)
                              : Colors.transparent)),
                  width: _isFocused ? 1.5 : 1,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    widget.icon,
                    size: 20,
                    color: showHighlight ? primaryColor : (widget.isDestructive ? BoutiqueColors.destructive.withValues(alpha: 0.8) : BoutiqueColors.textSecondary),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Row(
                      children: [
                        Flexible(
                          child: Text(
                            widget.label,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: widget.isSelected || _isFocused ? FontWeight.bold : FontWeight.w500,
                              color: showHighlight ? primaryColor : (widget.isDestructive ? BoutiqueColors.destructive : BoutiqueColors.textPrimary),
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (widget.shortcut != null) ...[
                          const SizedBox(width: 6),
                          Text(
                            '(${widget.shortcut})',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: showHighlight
                                  ? primaryColor.withValues(alpha: 0.8)
                                  : (widget.isDestructive
                                      ? BoutiqueColors.destructive.withValues(alpha: 0.7)
                                      : BoutiqueColors.textSecondary.withValues(alpha: 0.7)),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
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
