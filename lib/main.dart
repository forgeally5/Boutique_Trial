import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'auth/viewmodels/auth_viewmodel.dart';
import 'firebase_options.dart';
import 'state/admin_state.dart';
import 'services/sync_service.dart';
import 'services/local_db_service.dart';
import 'views/inventory_view.dart';
import 'views/billing_view.dart';
import 'views/rates_view.dart';
import 'login_page.dart';
import 'views/master_view.dart';
import 'views/master/report_shared.dart';
import 'views/change_password_dialog.dart';
import 'views/add_master_view.dart';
import 'views/portal_orders_view.dart';
import 'views/home_view.dart';
import 'views/widgets/connection_status_badge.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  await LocalDbService().init();
  SyncService().initialize();

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
    return MaterialApp(
      title: 'ForgeAlly-trial',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        fontFamily: 'sans-serif',
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF000000),
          surface: const Color(0xFFFFFFFF),
        ),
      ),
      home: const AuthGate(),
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
      backgroundColor: const Color(0xFFF5EFE6),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const Text(
                  'ForgeAlly-trial',
                  style: TextStyle(
                    fontFamily: 'serif',
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 3.5,
                    color: Color(0xFF000000),
                  ),
                ),
              ],
            ),
            SizedBox(height: 8),
            Text(
              'BOUTIQUE MANAGEMENT',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                letterSpacing: 2.0,
                color: Color(0xFF8D6E63),
              ),
            ),
            SizedBox(height: 36),
            SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: Color(0xFF000000),
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
  int _activeTabIndex = 5;
  int? _hoveredTabIndex;
  String _selectedBillingSection = 'A Sales Entry';
  String _selectedReportTitle = 'A Daily Activity Report';
  bool _isTransitioning = false;

  Future<void> _switchTab(int index) async {
    if (index == _activeTabIndex) return;
    setState(() => _isTransitioning = true);
    await Future.delayed(const Duration(milliseconds: 350));
    if (!mounted) return;
    setState(() {
      _activeTabIndex = index;
      _isTransitioning = false;
    });
  }

  final List<String> _tabs = [
    'INVENTORY',
    'BILLING',
  ];

  @override
  void initState() {
    super.initState();
    _state.addListener(() {
      if (mounted) {
        if (_state.requestedTabIndex != null) {
          final target = _state.requestedTabIndex!;
          _state.requestedTabIndex = null;
          _switchTab(target);
          return;
        }
        debugPrint('main.dart listener: pendingEstimationTags = ${_state.pendingEstimationTags}');
        if (_state.pendingEstimationTags.isNotEmpty) {
          if (_activeTabIndex != 1 || _selectedBillingSection != 'A Sales Entry') {
            debugPrint('main.dart: Switching tab to TRANSACTION / A Sales Entry...');
            _selectedBillingSection = 'A Sales Entry';
            _switchTab(1);
          } else {
            debugPrint('main.dart: Already on Sales Entry tab.');
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
    super.dispose();
  }



  Widget _buildBody() {
    switch (_activeTabIndex) {
      case 0:
        return InventoryView(state: _state);
      case 1:
        return BillingView(
          state: _state,
          initialSection: _selectedBillingSection,
          onSectionChanged: (sec) {
            setState(() => _selectedBillingSection = sec);
          },
        );
      default:
        return InventoryView(state: _state);
    }
  }

  // ── Logout ─────────────────────────────────────────────────────────────────

  Future<void> _handleLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        backgroundColor: Colors.white,
        title: const Text(
          'Confirm Logout',
          style: TextStyle(
            fontFamily: 'serif',
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Color(0xFF000000),
          ),
        ),
        content: const Text(
          'Are you sure you want to log out of the admin panel?',
          style: TextStyle(fontSize: 13, color: Colors.black54),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Colors.black54),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF000000),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
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

  // ── Change Password dialog ─────────────────────────────────────────────────

  void _openChangePassword() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => ChangeNotifierProvider.value(
        value: context.read<AuthViewModel>(),
        child: const ChangePasswordDialog(),
      ),
    );
  }

  void _openDropdownOptionsMaster() {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (_) => AddMasterDialog(adminState: _state),
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        backgroundColor: const Color(0xFFFCFAF5),
        body: Column(
        children: [
          // ── Top Navigation Bar ─────────────────────────────────────────────
          Container(
            height: 80,
            padding: const EdgeInsets.symmetric(horizontal: 40),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(
                bottom: BorderSide(color: Color(0xFFE5DDD0), width: 1),
              ),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Brand
                Align(
                  alignment: Alignment.centerLeft,
                  child: InkWell(
                    onTap: () {
                      setState(() {
                        _activeTabIndex = 5;
                      });
                    },
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          const Text(
                            'ForgeAlly-trial',
                            style: TextStyle(
                              fontFamily: 'serif',
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 2.0,
                              color: Color(0xFF000000),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // Nav tabs — centered
                Align(
                  alignment: Alignment.center,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(_tabs.length, (index) {
                        final isSelected = index == _activeTabIndex;
                        final isHovered = index == _hoveredTabIndex;

                        // Removed dropdown menus to simplify UI

                        return InkWell(
                          onTap: () => _switchTab(index),
                          onHover: (hovered) {
                            setState(() {
                              _hoveredTabIndex = hovered ? index : null;
                            });
                          },
                          hoverColor: Colors.transparent,
                          splashColor: Colors.transparent,
                          highlightColor: Colors.transparent,
                          child: Container(
                            height: 80,
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            child: Stack(
                              clipBehavior: Clip.none,
                              alignment: Alignment.center,
                              children: [
                                Text(
                                  _tabs[index],
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w400,
                                    letterSpacing: 0.8,
                                    color: isSelected ? const Color(0xFF2D2B3D) : const Color(0xFF8D6E63),
                                  ),
                                ),
                                Positioned(
                                  bottom: 24,
                                  left: 0,
                                  right: 0,
                                  child: Center(
                                    child: AnimatedContainer(
                                      duration: const Duration(milliseconds: 220),
                                      curve: Curves.easeInOut,
                                      height: 1.5,
                                      width: (isSelected || isHovered)
                                          ? [70.0, 55.0][index]
                                          : 0,
                                      decoration: BoxDecoration(
                                        color: (isSelected || isHovered)
                                            ? const Color(0xFF2D2B3D)
                                            : Colors.transparent,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }),
                    ),
                  ),
                ),

                // Settings & Action Menu
                Align(
                  alignment: Alignment.centerRight,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ConnectionStatusBadge(state: _state),
                      const SizedBox(width: 12),
                      Theme(
                        data: Theme.of(context).copyWith(
                          cardColor: const Color(0xFFFFFFFF),
                        ),
                        child: PopupMenuButton<String>(
                          icon: const Icon(
                            Icons.settings_outlined,
                            color: Color(0xFF8D6E63),
                            size: 20,
                          ),
                          tooltip: 'Settings',
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: const BorderSide(color: Color(0xFFE5DDD0)),
                      ),
                      onSelected: (value) {
                        if (value == 'change_password') {
                          _openChangePassword();
                        } else if (value == 'logout') {
                          _handleLogout();
                        } else if (value == 'dropdown_master') {
                          _openDropdownOptionsMaster();
                        }
                      },
                      itemBuilder: (BuildContext context) => [
                        const PopupMenuItem<String>(
                          value: 'change_password',
                          child: Row(
                            children: [
                              Icon(Icons.lock_outline,
                                  color: Color(0xFF8D6E63), size: 18),
                              SizedBox(width: 8),
                              Text('Change Password',
                                  style: TextStyle(
                                      color: Color(0xFF000000), fontSize: 13)),
                            ],
                          ),
                        ),
                        const PopupMenuItem<String>(
                          value: 'dropdown_master',
                          child: Row(
                            children: [
                              Icon(Icons.list_alt_rounded,
                                  color: Color(0xFF8D6E63), size: 18),
                              SizedBox(width: 8),
                              Text('Add Master',
                                  style: TextStyle(
                                      color: Color(0xFF000000), fontSize: 13)),
                            ],
                          ),
                        ),
                        const PopupMenuItem<String>(
                          value: 'logout',
                          child: Row(
                            children: [
                              Icon(Icons.logout_rounded,
                                  color: Colors.redAccent, size: 18),
                              SizedBox(width: 8),
                              Text('Logout',
                                  style: TextStyle(
                                      color: Colors.redAccent,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
              ],
            ),
          ),

          // ── Page body ──────────────────────────────────────────────────────
          Expanded(
            child: Stack(
              children: [
                // Content fades in/out on tab switch
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  switchInCurve: Curves.easeOut,
                  switchOutCurve: Curves.easeIn,
                  transitionBuilder: (child, animation) => FadeTransition(
                    opacity: animation,
                    child: child,
                  ),
                  child: KeyedSubtree(
                    key: ValueKey(_activeTabIndex),
                    child: _buildBody(),
                  ),
                ),

                // Blurred overlay + centered dot spinner during transition
                if (_isTransitioning)
                  Positioned.fill(
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 4, sigmaY: 4),
                      child: const ColoredBox(
                        color: Colors.transparent,
                        child: _DotSpinner(),
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
}

// ── Dot Circle Spinner ─────────────────────────────────────────────────────────

class _DotSpinner extends StatefulWidget {
  const _DotSpinner();

  @override
  State<_DotSpinner> createState() => _DotSpinnerState();
}

class _DotSpinnerState extends State<_DotSpinner>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
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
          size: const Size(52, 52),
          painter: _DotSpinnerPainter(_ctrl.value),
        ),
      ),
    );
  }
}

class _DotSpinnerPainter extends CustomPainter {
  final double progress;
  static const int _n = 14;

  const _DotSpinnerPainter(this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 5;

    for (int i = 0; i < _n; i++) {
      // t: 1.0 = head (brightest), 0.0 = tail (invisible)
      final t = (i + 1) / _n;
      final angle =
          (2 * math.pi * i / _n) - (2 * math.pi * progress);
      final pos = Offset(
        center.dx + radius * math.cos(angle),
        center.dy + radius * math.sin(angle),
      );

      final dotRadius = 1.4 + t * 2.2;
      final opacity = t * t; // quadratic fade for a nice tail

      // Warm glow for the brighter dots
      if (t > 0.55) {
        final glowPaint = Paint()
          ..color = const Color(0xFFCA6F1E).withAlpha((opacity * 60).round())
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5);
        canvas.drawCircle(pos, dotRadius + 2.5, glowPaint);
      }

      // Core dot: fades from transparent to deep warm brown
      final dotPaint = Paint()
        ..color = Color.lerp(
          const Color(0xFFD4A574).withAlpha(0),
          const Color(0xFF000000),
          opacity,
        )!;
      canvas.drawCircle(pos, dotRadius, dotPaint);
    }
  }

  @override
  bool shouldRepaint(_DotSpinnerPainter old) => old.progress != progress;
}



