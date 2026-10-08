import 'dart:async';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:provider/provider.dart';
import 'auth/viewmodels/auth_viewmodel.dart';
import 'utils/boutique_theme.dart';
import 'package:google_fonts/google_fonts.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _emailFocusNode = FocusNode();
  final _passwordFocusNode = FocusNode();

  bool _showPasswordField = false;
  bool _obscurePassword = true;
  String? _errorMessage;

  int _failedAttempts = 0;
  DateTime? _lockoutEndTime;
  Timer? _lockoutCountdownTimer;
  String _lockoutCountdownStr = '';
  
  static const Color inkColor = Color(0xFF262220);
  static const Color inkSoftColor = Color(0xFF8A8078);
  static const Color lineColor = Color(0xFFD8CFC0);
  static const Color ivoryColor = Color(0xFFF7F3EA);
  static const Color placeholderColor = Color(0xFFBDB2A2);

  @override
  void initState() {
    super.initState();
    _checkLockoutStatus();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _emailFocusNode.dispose();
    _passwordFocusNode.dispose();
    _lockoutCountdownTimer?.cancel();
    super.dispose();
  }

  Future<void> _checkLockoutStatus() async {
    try {
      if (!Hive.isBoxOpen('user_session_box')) {
        await Hive.openBox('user_session_box');
      }
      final box = Hive.box('user_session_box');
      final lockoutMillis = box.get('login_lockout_until') as int?;
      final storedAttempts = box.get('login_failed_attempts') as int? ?? 0;
      _failedAttempts = storedAttempts;

      if (lockoutMillis != null) {
        final lockoutEnd = DateTime.fromMillisecondsSinceEpoch(lockoutMillis);
        if (lockoutEnd.isAfter(DateTime.now())) {
          _lockoutEndTime = lockoutEnd;
          _startLockoutCountdown();
        } else {
          await box.delete('login_lockout_until');
          await box.put('login_failed_attempts', 0);
          _failedAttempts = 0;
        }
      }
    } catch (e) {
      debugPrint('Lockout status check: $e');
    }
  }

  void _startLockoutCountdown() {
    _lockoutCountdownTimer?.cancel();
    _updateLockoutMessage();
    _lockoutCountdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      if (_lockoutEndTime == null || DateTime.now().isAfter(_lockoutEndTime!)) {
        _lockoutCountdownTimer?.cancel();
        _lockoutCountdownTimer = null;
        setState(() {
          _lockoutEndTime = null;
          _failedAttempts = 0;
          _errorMessage = null;
          _lockoutCountdownStr = '';
        });
        try {
          if (Hive.isBoxOpen('user_session_box')) {
            final box = Hive.box('user_session_box');
            box.delete('login_lockout_until');
            box.put('login_failed_attempts', 0);
          }
        } catch (_) {}
      } else {
        _updateLockoutMessage();
      }
    });
  }

  void _updateLockoutMessage() {
    if (_lockoutEndTime == null) return;
    final remaining = _lockoutEndTime!.difference(DateTime.now());
    if (remaining.isNegative) return;
    final mins = remaining.inMinutes;
    final secs = (remaining.inSeconds % 60).toString().padLeft(2, '0');
    final formattedTime = mins > 0 ? '$mins min $secs sec' : '$secs sec';
    final shortTime = mins > 0 ? '${mins}m ${secs}s' : '${secs}s';
    
    setState(() {
      _lockoutCountdownStr = shortTime;
      _errorMessage = 'Too many failed login attempts. Please try again after $formattedTime.';
    });
  }

  void _recordFailedAttempt({bool forceLockout = false, int lockoutMinutes = 15}) {
    _failedAttempts++;
    final remaining = 5 - _failedAttempts;

    if (forceLockout || _failedAttempts >= 5) {
      final lockEnd = DateTime.now().add(Duration(minutes: lockoutMinutes));
      _lockoutEndTime = lockEnd;
      _startLockoutCountdown();
    } else {
      if (remaining <= 2) {
        _errorMessage = 'Your email or password is incorrect. ($remaining attempt${remaining == 1 ? '' : 's'} remaining before 15-min lockout)';
      } else {
        _errorMessage = 'Your email or password is incorrect.';
      }
      if (mounted) {
        BoutiqueToast.showError(context, _errorMessage!);
      }
    }
    setState(() {});

    // Save to Hive asynchronously without blocking UI
    try {
      if (Hive.isBoxOpen('user_session_box')) {
        final box = Hive.box('user_session_box');
        box.put('login_failed_attempts', _failedAttempts);
        if (_lockoutEndTime != null) {
          box.put('login_lockout_until', _lockoutEndTime!.millisecondsSinceEpoch);
        }
      }
    } catch (e) {
      debugPrint('Failed attempt recording to Hive: $e');
    }
  }

  Future<void> _clearFailedAttempts() async {
    _failedAttempts = 0;
    _lockoutEndTime = null;
    _lockoutCountdownTimer?.cancel();
    setState(() {
      _errorMessage = null;
      _lockoutCountdownStr = '';
    });
    try {
      if (Hive.isBoxOpen('user_session_box')) {
        final box = Hive.box('user_session_box');
        await box.delete('login_lockout_until');
        await box.put('login_failed_attempts', 0);
      }
    } catch (_) {}
  }

  void _handleEmailSubmit() {
    if (_lockoutEndTime != null && DateTime.now().isBefore(_lockoutEndTime!)) {
      _updateLockoutMessage();
      BoutiqueToast.showError(context, _errorMessage ?? 'Account is temporarily locked.');
      return;
    }

    final email = _emailController.text.trim();
    if (email.isEmpty) {
      setState(() {
        _errorMessage = 'Please enter your email address.';
      });
      BoutiqueToast.showError(context, 'Please enter your email address.');
      _emailFocusNode.requestFocus();
      return;
    }

    setState(() {
      _showPasswordField = true;
      _errorMessage = null;
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _passwordFocusNode.requestFocus();
    });
  }

  Future<void> _handleLogin() async {
    if (_lockoutEndTime != null && DateTime.now().isBefore(_lockoutEndTime!)) {
      _updateLockoutMessage();
      BoutiqueToast.showError(context, _errorMessage ?? 'Account is temporarily locked.');
      return;
    }

    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (email.isEmpty) {
      setState(() {
        _showPasswordField = false;
        _errorMessage = 'Please enter your email address.';
      });
      BoutiqueToast.showError(context, 'Please enter your email address.');
      _emailFocusNode.requestFocus();
      return;
    }

    if (password.isEmpty) {
      setState(() {
        _errorMessage = 'Please enter your password.';
      });
      BoutiqueToast.showError(context, 'Please enter your password.');
      _passwordFocusNode.requestFocus();
      return;
    }

    setState(() {
      _errorMessage = null;
    });

    try {
      final authVM = context.read<AuthViewModel>();
      await authVM.login(email, password);

      if (!mounted) return;
      final status = authVM.status;
      if (status == AuthStatus.authenticated) {
        await _clearFailedAttempts();
      } else if (status == AuthStatus.unauthorized) {
        final msg = authVM.errorMessage ?? 'Your account has been deactivated.';
        setState(() {
          _errorMessage = msg;
        });
        BoutiqueToast.showError(context, msg);
      } else {
        final serverMsg = authVM.errorMessage ?? '';
        if (serverMsg.toLowerCase().contains('too many failed') || serverMsg.toLowerCase().contains('locked')) {
          _recordFailedAttempt(forceLockout: true, lockoutMinutes: 15);
          if (mounted && _errorMessage != null) {
            BoutiqueToast.showError(context, _errorMessage!);
          }
        } else {
          _recordFailedAttempt();
        }
      }
    } catch (e) {
      if (!mounted) return;
      _recordFailedAttempt();
    }
  }

  Future<void> _showForgotPasswordDialog() async {
    final forgotEmailCtrl = TextEditingController(text: _emailController.text.trim());
    bool isSubmitting = false;
    String? statusMessage;
    bool isSuccess = false;

    await showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Dialog(
              backgroundColor: ivoryColor,
              shape: RoundedRectangleBorder(
                side: const BorderSide(color: inkColor, width: 1),
                borderRadius: BorderRadius.circular(0),
              ),
              child: Container(
                width: 420,
                padding: const EdgeInsets.all(28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'RESET PASSWORD',
                          style: GoogleFonts.cormorantGaramond(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.2,
                            color: inkColor,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, size: 20, color: inkColor),
                          onPressed: () => Navigator.pop(dialogContext),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Please contact your Store Administrator (admin@ritumita.com) to reset your login password.',
                      style: GoogleFonts.workSans(
                        fontSize: 13,
                        color: inkSoftColor,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border.all(color: lineColor),
                      ),
                      child: TextField(
                        controller: forgotEmailCtrl,
                        keyboardType: TextInputType.emailAddress,
                        style: GoogleFonts.workSans(fontSize: 14, color: inkColor),
                        decoration: InputDecoration(
                          hintText: 'admin@ritumita.com',
                          hintStyle: GoogleFonts.workSans(color: placeholderColor, fontSize: 13),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          border: InputBorder.none,
                          prefixIcon: const Icon(Icons.email_outlined, size: 18, color: inkSoftColor),
                        ),
                      ),
                    ),
                    if (statusMessage != null) ...[
                      const SizedBox(height: 14),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isSuccess ? const Color(0xFFE8F5E9) : const Color(0xFFFFEBEE),
                          border: Border.all(
                            color: isSuccess ? const Color(0xFF4CAF50) : const Color(0xFFE57373),
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              isSuccess ? Icons.check_circle_outline : Icons.error_outline,
                              size: 18,
                              color: isSuccess ? const Color(0xFF2E7D32) : const Color(0xFFC62828),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                statusMessage!,
                                style: GoogleFonts.workSans(
                                  fontSize: 12,
                                  color: isSuccess ? const Color(0xFF1B5E20) : const Color(0xFFB71C1C),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),
                    Material(
                      color: inkColor,
                      child: InkWell(
                        onTap: isSubmitting
                            ? null
                            : () async {
                                final email = forgotEmailCtrl.text.trim();
                                if (email.isEmpty || !email.contains('@')) {
                                  setDialogState(() {
                                    statusMessage = 'Please enter a valid email address.';
                                    isSuccess = false;
                                  });
                                  return;
                                }

                                setDialogState(() {
                                  isSubmitting = true;
                                  statusMessage = null;
                                });

                                await Future.delayed(const Duration(milliseconds: 300));
                                setDialogState(() {
                                  isSubmitting = false;
                                  isSuccess = true;
                                  statusMessage = 'Password reset request recorded. Please contact Store Administrator (admin@ritumita.com) to complete your password reset.';
                                });
                              },
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          alignment: Alignment.center,
                          child: isSubmitting
                              ? const SizedBox(
                                  height: 18,
                                  width: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: ivoryColor,
                                  ),
                                )
                              : Text(
                                  'CONTACT ADMINISTRATOR',
                                  style: GoogleFonts.workSans(
                                    fontSize: 12.5,
                                    letterSpacing: 1.0,
                                    fontWeight: FontWeight.w600,
                                    color: ivoryColor,
                                  ),
                                ),
                        ),
                      ),
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

  @override
  Widget build(BuildContext context) {
    final authVM = context.watch<AuthViewModel>();
    final isLoading = authVM.isLoading;

    final isLocked = _lockoutEndTime != null && DateTime.now().isBefore(_lockoutEndTime!);
    final effectiveError = _errorMessage ??
        ((authVM.status == AuthStatus.error || authVM.status == AuthStatus.unauthorized)
            ? (authVM.errorMessage?.isNotEmpty == true
                ? authVM.errorMessage!
                : 'Your email or password is incorrect.')
            : null);

    return Scaffold(
      backgroundColor: ivoryColor,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Stack(
                children: [
                  Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      border: Border.all(color: inkColor, width: 1),
                    ),
                    padding: const EdgeInsets.fromLTRB(40, 48, 40, 40),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Center(
                          child: Image.asset(
                            'assets/logo.png',
                            height: 75,
                            fit: BoxFit.contain,
                            errorBuilder: (_, _, _) => Column(
                              children: [
                                Text(
                                  'RituMita',
                                  style: GoogleFonts.cormorantGaramond(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 34,
                                    letterSpacing: 0.03 * 34,
                                    color: inkColor,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'BOUTIQUE PORTAL',
                                  style: GoogleFonts.workSans(
                                    fontSize: 11.5,
                                    letterSpacing: 0.12 * 11.5,
                                    color: inkSoftColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 38),
                        Text(
                          'Email address',
                          style: GoogleFonts.workSans(
                            fontSize: 12.5,
                            letterSpacing: 0.04 * 12.5,
                            color: inkSoftColor,
                          ),
                        ),
                        const SizedBox(height: 8),
                        _buildTextField(
                          controller: _emailController,
                          focusNode: _emailFocusNode,
                          hintText: 'you@boutique.com',
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: _showPasswordField ? TextInputAction.next : TextInputAction.done,
                          onChanged: (_) {
                            if (_errorMessage != null && !isLocked) {
                              setState(() => _errorMessage = null);
                            }
                          },
                          onSubmitted: () {
                            if (!_showPasswordField) {
                              _handleEmailSubmit();
                            } else {
                              _passwordFocusNode.requestFocus();
                            }
                          },
                        ),
                        AnimatedSize(
                          duration: const Duration(milliseconds: 250),
                          curve: Curves.easeInOut,
                          child: _showPasswordField
                              ? Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    const SizedBox(height: 22),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      crossAxisAlignment: CrossAxisAlignment.baseline,
                                      textBaseline: TextBaseline.alphabetic,
                                      children: [
                                        Text(
                                          'Password',
                                          style: GoogleFonts.workSans(
                                            fontSize: 12.5,
                                            letterSpacing: 0.04 * 12.5,
                                            color: inkSoftColor,
                                          ),
                                        ),
                                        GestureDetector(
                                          onTap: _showForgotPasswordDialog,
                                          child: Container(
                                            decoration: const BoxDecoration(
                                              border: Border(bottom: BorderSide(color: lineColor)),
                                            ),
                                            child: Text(
                                              'Forgot?',
                                              style: GoogleFonts.workSans(
                                                fontSize: 12,
                                                color: inkSoftColor,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    _buildTextField(
                                      controller: _passwordController,
                                      focusNode: _passwordFocusNode,
                                      hintText: '••••••••',
                                      obscureText: _obscurePassword,
                                      textInputAction: TextInputAction.done,
                                      suffixIcon: IconButton(
                                        splashRadius: 18,
                                        icon: Icon(
                                          _obscurePassword
                                              ? Icons.visibility_off_outlined
                                              : Icons.visibility_outlined,
                                          size: 18,
                                          color: inkSoftColor,
                                        ),
                                        tooltip: _obscurePassword ? 'Show password' : 'Hide password',
                                        onPressed: () {
                                          setState(() {
                                            _obscurePassword = !_obscurePassword;
                                          });
                                        },
                                      ),
                                      onChanged: (_) {
                                        if (_errorMessage != null && !isLocked) {
                                          setState(() => _errorMessage = null);
                                        }
                                      },
                                      onSubmitted: _handleLogin,
                                    ),
                                  ],
                                )
                              : const SizedBox.shrink(),
                        ),
                        if (effectiveError != null) ...[
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            decoration: BoxDecoration(
                              color: isLocked ? const Color(0xFFFFF3E0) : const Color(0xFFFFEBEE),
                              border: Border.all(
                                color: isLocked ? const Color(0xFFFFB74D) : const Color(0xFFE57373),
                              ),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(
                                  isLocked ? Icons.lock_clock_outlined : Icons.error_outline,
                                  size: 19,
                                  color: isLocked ? const Color(0xFFE65100) : const Color(0xFFC62828),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    effectiveError,
                                    style: GoogleFonts.workSans(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w500,
                                      height: 1.35,
                                      color: isLocked ? const Color(0xFFBF360C) : const Color(0xFFB71C1C),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        const SizedBox(height: 24),
                        Material(
                          color: isLocked ? inkSoftColor.withValues(alpha: 0.5) : inkColor,
                          child: InkWell(
                            onTap: (isLoading || isLocked)
                                ? null
                                : (_showPasswordField ? _handleLogin : _handleEmailSubmit),
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              alignment: Alignment.center,
                              child: isLoading
                                  ? const SizedBox(
                                      height: 20,
                                      width: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: ivoryColor,
                                      ),
                                    )
                                  : Text(
                                      isLocked
                                          ? 'LOCKED ($_lockoutCountdownStr)'
                                          : (_showPasswordField ? 'SIGN IN' : 'CONTINUE'),
                                      style: GoogleFonts.workSans(
                                        fontSize: 13.5,
                                        letterSpacing: 0.06 * 13.5,
                                        fontWeight: FontWeight.w600,
                                        color: ivoryColor,
                                      ),
                                    ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 26),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'New here? ',
                              style: GoogleFonts.workSans(
                                fontSize: 12.5,
                                color: inkSoftColor,
                              ),
                            ),
                            GestureDetector(
                              onTap: () {},
                              child: Container(
                                decoration: const BoxDecoration(
                                  border: Border(bottom: BorderSide(color: inkColor)),
                                ),
                                child: Text(
                                  'Request an account',
                                  style: GoogleFonts.workSans(
                                    fontSize: 12.5,
                                    color: inkColor,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Positioned(
                    top: -1,
                    left: -1,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        border: Border(
                          top: BorderSide(color: inkColor, width: 1),
                          left: BorderSide(color: inkColor, width: 1),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: -1,
                    right: -1,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        border: Border(
                          bottom: BorderSide(color: inkColor, width: 1),
                          right: BorderSide(color: inkColor, width: 1),
                        ),
                      ),
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

  Widget _buildTextField({
    required TextEditingController controller,
    required String hintText,
    FocusNode? focusNode,
    bool obscureText = false,
    Widget? suffixIcon,
    TextInputAction? textInputAction,
    TextInputType? keyboardType,
    ValueChanged<String>? onChanged,
    VoidCallback? onSubmitted,
  }) {
    return Container(
      color: Colors.white,
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        obscureText: obscureText,
        keyboardType: keyboardType,
        textInputAction: textInputAction,
        onChanged: onChanged,
        onSubmitted: (_) => onSubmitted?.call(),
        style: GoogleFonts.workSans(
          fontSize: 15,
          color: inkColor,
        ),
        cursorColor: inkColor,
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: GoogleFonts.workSans(color: placeholderColor),
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          suffixIcon: suffixIcon,
          enabledBorder: const OutlineInputBorder(
            borderSide: BorderSide(color: lineColor),
            borderRadius: BorderRadius.zero,
          ),
          focusedBorder: const OutlineInputBorder(
            borderSide: BorderSide(color: inkColor),
            borderRadius: BorderRadius.zero,
          ),
          isDense: true,
        ),
      ),
    );
  }
}
