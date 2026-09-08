import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../viewmodels/auth_viewmodel.dart';

/// Forgot Password screen.
/// Sends a Firebase password-reset email to the entered address.
class ForgotPasswordView extends StatefulWidget {
  const ForgotPasswordView({super.key});

  @override
  State<ForgotPasswordView> createState() => _ForgotPasswordViewState();
}

class _ForgotPasswordViewState extends State<ForgotPasswordView>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();

  bool _isSending = false;
  bool _emailSent = false;
  String? _errorMessage;

  late AnimationController _animController;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnim =
        CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(
        CurvedAnimation(parent: _animController, curve: Curves.easeOut));
    _animController.forward();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _animController.dispose();
    super.dispose();
  }

  Future<void> _handleSendReset() async {
    setState(() => _errorMessage = null);
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSending = true);

    try {
      await context
          .read<AuthViewModel>()
          .sendPasswordReset(_emailController.text.trim());

      if (!mounted) return;
      setState(() {
        _isSending = false;
        _emailSent = true;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSending = false;
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  InputDecoration _inputDecoration({
    required String hint,
    required IconData prefixIcon,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Colors.black26, fontSize: 13),
      prefixIcon:
          Icon(prefixIcon, color: const Color(0xFF8D6E63), size: 20),
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      filled: true,
      fillColor: Colors.white,
      focusedBorder: OutlineInputBorder(
        borderSide:
            const BorderSide(color: Color(0xFF3E2723), width: 1.5),
        borderRadius: BorderRadius.circular(8),
      ),
      enabledBorder: OutlineInputBorder(
        borderSide: const BorderSide(color: Color(0xFFE5DDD0)),
        borderRadius: BorderRadius.circular(8),
      ),
      errorBorder: OutlineInputBorder(
        borderSide: const BorderSide(color: Colors.redAccent),
        borderRadius: BorderRadius.circular(8),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderSide:
            const BorderSide(color: Colors.redAccent, width: 1.5),
        borderRadius: BorderRadius.circular(8),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5EFE6),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: FadeTransition(
            opacity: _fadeAnim,
            child: SlideTransition(
              position: _slideAnim,
              child: Container(
                width: 440,
                padding: const EdgeInsets.symmetric(
                  horizontal: 40,
                  vertical: 44,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: const Color(0xFFE5DDD0), width: 1),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x1A3E2723),
                      blurRadius: 30,
                      offset: Offset(0, 10),
                    ),
                  ],
                ),
                child: _emailSent
                    ? _buildSuccessState()
                    : _buildFormState(),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Success state ──────────────────────────────────────────────────────────
  Widget _buildSuccessState() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.mark_email_read_outlined,
            size: 52, color: Color(0xFF3E2723)),
        const SizedBox(height: 20),
        const Text(
          'Reset Email Sent',
          style: TextStyle(
            fontFamily: 'serif',
            fontSize: 22,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.5,
            color: Color(0xFF3E2723),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'A password reset link has been sent to\n${_emailController.text.trim()}',
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 13,
            color: Color(0xFF8D6E63),
            height: 1.6,
          ),
        ),
        const SizedBox(height: 32),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: OutlinedButton(
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Color(0xFF3E2723)),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.of(context).pop(),
            child: const Text(
              'Back to Login',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Color(0xFF3E2723),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ── Form state ─────────────────────────────────────────────────────────────
  Widget _buildFormState() {
    return Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Image.asset('assets/logo.png', height: 34),
              const SizedBox(width: 10),
              const Text(
                'TRILOK',
                style: TextStyle(
                  fontFamily: 'serif',
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 3.5,
                  color: Color(0xFF3E2723),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'FORGOT PASSWORD',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              letterSpacing: 2.0,
              color: Color(0xFF8D6E63),
            ),
          ),
          const SizedBox(height: 28),

          // ── Description ──────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFFAF7F2),
              borderRadius: BorderRadius.circular(8),
              border:
                  Border.all(color: const Color(0xFFE5DDD0), width: 1),
            ),
            child: const Row(
              children: [
                Icon(Icons.info_outline,
                    size: 16, color: Color(0xFF8D6E63)),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Enter your registered email address. We will send you a link to reset your password.',
                    style: TextStyle(
                        fontSize: 12,
                        color: Color(0xFF8D6E63),
                        height: 1.5),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),

          // ── Error banner ─────────────────────────────────────────────────
          if (_errorMessage != null) ...[
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF0F0),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color: Colors.redAccent.withValues(alpha: 0.4)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline,
                      color: Colors.redAccent, size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _errorMessage!,
                      style: const TextStyle(
                          fontSize: 13, color: Colors.redAccent),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],

          // ── Email field ──────────────────────────────────────────────────
          const Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Email Address',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0xFF5D4037),
              ),
            ),
          ),
          const SizedBox(height: 6),
          TextFormField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            style: const TextStyle(
                color: Color(0xFF3E2723), fontSize: 14),
            decoration: _inputDecoration(
              hint: 'Enter your registered email',
              prefixIcon: Icons.email_outlined,
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Email address is required';
              }
              if (!RegExp(r'^[^@]+@[^@]+\.[^@]+')
                  .hasMatch(value.trim())) {
                return 'Please enter a valid email address';
              }
              return null;
            },
          ),
          const SizedBox(height: 28),

          // ── Send Reset Email button ──────────────────────────────────────
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF3E2723),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
                elevation: 2,
              ),
              onPressed: _isSending ? null : _handleSendReset,
              child: _isSending
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                          strokeWidth: 2.5, color: Colors.white),
                    )
                  : const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.send_outlined, size: 18),
                        SizedBox(width: 10),
                        Text(
                          'Send Reset Email',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
          const SizedBox(height: 20),

          // ── Back link ────────────────────────────────────────────────────
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text(
              '← Back to Login',
              style: TextStyle(
                fontSize: 13,
                color: Color(0xFF8D6E63),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
