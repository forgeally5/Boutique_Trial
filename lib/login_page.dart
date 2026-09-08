import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'auth/viewmodels/auth_viewmodel.dart';
import 'utils/boutique_theme.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> with SingleTickerProviderStateMixin {
  final _emailController = TextEditingController(text: 'trial@forgeally.com');
  final _passwordController = TextEditingController(text: 'admin12345');
  bool _isPasswordVisible = false;
  bool _rememberMe = true;

  late AnimationController _animController;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 750),
    );

    _fadeAnim = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOut,
    );

    _slideAnim = Tween<Offset>(
      begin: const Offset(0.04, 0),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutCubic,
    ));

    _animController.forward();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _animController.dispose();
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
    final size = MediaQuery.of(context).size;
    final isDesktop = size.width >= 900;

    return Scaffold(
      backgroundColor: BoutiqueColors.bgMain,
      body: SafeArea(
        child: isDesktop
            ? Row(
                children: [
                  // Left Branded Panel (Boutique Aesthetic)
                  Expanded(
                    flex: 5,
                    child: _buildBrandedPanel(),
                  ),
                  // Right Form Panel
                  Expanded(
                    flex: 6,
                    child: Center(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(40),
                        child: FadeTransition(
                          opacity: _fadeAnim,
                          child: SlideTransition(
                            position: _slideAnim,
                            child: Container(
                              constraints: const BoxConstraints(maxWidth: 440),
                              child: _buildLoginForm(isLoading),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              )
            : Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: FadeTransition(
                    opacity: _fadeAnim,
                    child: SlideTransition(
                      position: _slideAnim,
                      child: Container(
                        constraints: const BoxConstraints(maxWidth: 420),
                        decoration: BoutiqueDecoration.card(hasShadow: true, borderRadius: 16),
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  width: 36,
                                  height: 36,
                                  decoration: const BoxDecoration(
                                    color: BoutiqueColors.accent,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Center(
                                    child: Text(
                                      'F',
                                      style: TextStyle(
                                        fontFamily: 'serif',
                                        color: Colors.white,
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                const Text(
                                  'ForgeAlly',
                                  style: TextStyle(
                                    fontFamily: 'serif',
                                    fontSize: 26,
                                    fontWeight: FontWeight.bold,
                                    color: BoutiqueColors.textPrimary,
                                    letterSpacing: 1.2,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            const Text(
                              'BOUTIQUE MANAGEMENT SYSTEM',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 2.0,
                                color: BoutiqueColors.accent,
                              ),
                            ),
                            const SizedBox(height: 32),
                            _buildLoginForm(isLoading),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildBrandedPanel() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF5E1729), // Rich Deep Burgundy
            Color(0xFF8B263E), // Rose Burgundy Accent
            Color(0xFF3B0B19), // Dark Rose Shadow
          ],
        ),
      ),
      child: Stack(
        children: [
          // Elegant decorative subtle patterns
          Positioned(
            right: -80,
            top: -80,
            child: Container(
              width: 360,
              height: 360,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white.withOpacity(0.06), width: 40),
              ),
            ),
          ),
          Positioned(
            left: -100,
            bottom: -100,
            child: Container(
              width: 450,
              height: 450,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: BoutiqueColors.gold.withOpacity(0.12), width: 1.5),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 56, vertical: 64),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Header Logo
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        border: Border.all(color: BoutiqueColors.gold.withOpacity(0.6), width: 1.5),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        'FORGEALLY',
                        style: TextStyle(
                          fontFamily: 'serif',
                          color: BoutiqueColors.gold,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 3.0,
                        ),
                      ),
                    ),
                  ],
                ),
                // Center Tagline & Headline
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                      decoration: BoxDecoration(
                        color: BoutiqueColors.gold.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text(
                        '✨ HIGH-END RETAIL & BILLING',
                        style: TextStyle(
                          color: BoutiqueColors.gold,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Curate, Manage & Grow Your Boutique Enterprise.',
                      style: TextStyle(
                        fontFamily: 'serif',
                        fontSize: 38,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Seamless inventory management, point-of-sale invoicing, and real-time analytics designed specifically for fashion boutiques.',
                      style: TextStyle(
                        fontFamily: 'sans-serif',
                        fontSize: 15,
                        color: Colors.white.withOpacity(0.8),
                        height: 1.6,
                      ),
                    ),
                  ],
                ),
                // Footer details
                Row(
                  children: [
                    Icon(Icons.shield_outlined, color: Colors.white.withOpacity(0.6), size: 16),
                    const SizedBox(width: 8),
                    Text(
                      'Secure Cloud Sync & Local Storage Active',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white.withOpacity(0.6),
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoginForm(bool isLoading) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text(
          'Welcome Back',
          style: TextStyle(
            fontFamily: 'serif',
            fontSize: 30,
            fontWeight: FontWeight.bold,
            color: BoutiqueColors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Please sign in to access your boutique portal.',
          style: TextStyle(
            fontSize: 14,
            color: BoutiqueColors.textSecondary,
          ),
        ),
        const SizedBox(height: 36),

        // Email Field
        const Text(
          'Email Address',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: BoutiqueColors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _emailController,
          keyboardType: TextInputType.emailAddress,
          style: const TextStyle(fontSize: 14, color: BoutiqueColors.textPrimary),
          decoration: BoutiqueInputDecoration.field(
            hintText: 'admin@boutique.com',
            prefixIcon: const Icon(Icons.mail_outline_rounded, color: BoutiqueColors.textSecondary, size: 20),
          ),
        ),
        const SizedBox(height: 20),

        // Password Field
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Password',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: BoutiqueColors.textPrimary,
              ),
            ),
            GestureDetector(
              onTap: () {
                BoutiqueToast.showSuccess(context, 'Please contact administrator to reset password.');
              },
              child: const Text(
                'Forgot password?',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: BoutiqueColors.accent,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _passwordController,
          obscureText: !_isPasswordVisible,
          style: const TextStyle(fontSize: 14, color: BoutiqueColors.textPrimary),
          decoration: BoutiqueInputDecoration.field(
            hintText: '••••••••',
            prefixIcon: const Icon(Icons.lock_outline_rounded, color: BoutiqueColors.textSecondary, size: 20),
            suffixIcon: IconButton(
              icon: Icon(
                _isPasswordVisible ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                color: BoutiqueColors.textSecondary,
                size: 20,
              ),
              onPressed: () {
                setState(() {
                  _isPasswordVisible = !_isPasswordVisible;
                });
              },
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Remember Me Checkbox
        Row(
          children: [
            SizedBox(
              height: 24,
              width: 24,
              child: Checkbox(
                value: _rememberMe,
                activeColor: BoutiqueColors.accent,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                onChanged: (val) {
                  setState(() {
                    _rememberMe = val ?? true;
                  });
                },
              ),
            ),
            const SizedBox(width: 10),
            const Text(
              'Keep me signed in on this device',
              style: TextStyle(fontSize: 13, color: BoutiqueColors.textSecondary),
            ),
          ],
        ),
        const SizedBox(height: 32),

        // Sign In Button
        ElevatedButton(
          onPressed: isLoading ? null : _handleLogin,
          style: ElevatedButton.styleFrom(
            backgroundColor: BoutiqueColors.accent,
            foregroundColor: Colors.white,
            disabledBackgroundColor: BoutiqueColors.accent.withOpacity(0.6),
            padding: const EdgeInsets.symmetric(vertical: 18),
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          child: isLoading
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'SIGN IN TO PORTAL',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.0,
                      ),
                    ),
                    SizedBox(width: 8),
                    Icon(Icons.arrow_forward_rounded, size: 18),
                  ],
                ),
        ),
      ],
    );
  }
}
