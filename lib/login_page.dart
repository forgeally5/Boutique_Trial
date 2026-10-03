import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'auth/viewmodels/auth_viewmodel.dart';
import 'services/api_service.dart';
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
  
  static const Color inkColor = Color(0xFF262220);
  static const Color inkSoftColor = Color(0xFF8A8078);
  static const Color lineColor = Color(0xFFD8CFC0);
  static const Color ivoryColor = Color(0xFFF7F3EA);
  static const Color placeholderColor = Color(0xFFBDB2A2);

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      BoutiqueToast.showError(context, 'Please enter email and password.');
      return;
    }

    final authVM = context.read<AuthViewModel>();
    await authVM.login(email, password);

    if (!mounted) return;
    final status = authVM.status;
    if (status == AuthStatus.unauthorized) {
      BoutiqueToast.showError(context, authVM.errorMessage ?? 'Unauthorized access.');
    } else if (status == AuthStatus.error) {
      BoutiqueToast.showError(context, authVM.errorMessage ?? 'Invalid credentials.');
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
                      'Enter your registered email address. We will send a secure temporary password to your inbox.',
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

                                try {
                                  final msg = await ApiService().forgotPassword(email);
                                  setDialogState(() {
                                    isSubmitting = false;
                                    isSuccess = true;
                                    statusMessage = msg;
                                  });
                                } catch (e) {
                                  setDialogState(() {
                                    isSubmitting = false;
                                    isSuccess = false;
                                    statusMessage = e.toString().replaceAll('Exception: ', '');
                                  });
                                }
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
                                  'SEND TEMPORARY PASSWORD',
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
                          hintText: 'you@boutique.com',
                          onSubmitted: _handleLogin,
                        ),
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
                          hintText: '••••••••',
                          obscureText: true,
                          onSubmitted: _handleLogin,
                        ),
                        const SizedBox(height: 24),
                        Material(
                          color: inkColor,
                          child: InkWell(
                            onTap: isLoading ? null : _handleLogin,
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
                                      'SIGN IN',
                                      style: GoogleFonts.workSans(
                                        fontSize: 13.5,
                                        letterSpacing: 0.06 * 13.5,
                                        fontWeight: FontWeight.w500,
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
    bool obscureText = false,
    VoidCallback? onSubmitted,
  }) {
    return Container(
      color: Colors.white,
      child: TextField(
        controller: controller,
        obscureText: obscureText,
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
