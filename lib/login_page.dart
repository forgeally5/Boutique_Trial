import 'package:flutter/material.dart';
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
                        Column(
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
                              onTap: () {
                                BoutiqueToast.showSuccess(
                                    context, 'Please contact administrator to reset password.');
                              },
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
  }) {
    return Container(
      color: Colors.white,
      child: TextField(
        controller: controller,
        obscureText: obscureText,
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
