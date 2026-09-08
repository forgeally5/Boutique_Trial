import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../auth/viewmodels/auth_viewmodel.dart';

/// Change Password dialog.
///
/// Accessible from the [AdminHomeShell] header settings icon.
///
/// Flow:
///  1. User enters current password (for Firebase re-authentication).
///  2. User enters new password + confirmation.
///  3. [AuthViewModel.changePassword] re-authenticates via Firebase Auth,
///     then calls [User.updatePassword].
///
/// NOTE: The password stored in Firestore [admin_users] is NOT used here.
/// All changes go through Firebase Authentication exclusively.
class ChangePasswordDialog extends StatefulWidget {
  const ChangePasswordDialog({super.key});

  @override
  State<ChangePasswordDialog> createState() => _ChangePasswordDialogState();
}

class _ChangePasswordDialogState extends State<ChangePasswordDialog> {
  final _formKey = GlobalKey<FormState>();
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _obscureCurrent = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;
  bool _isSaving = false;
  String? _errorMessage;
  bool _success = false;

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _handleChangePassword() async {
    setState(() => _errorMessage = null);
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      await context.read<AuthViewModel>().changePassword(
            currentPassword: _currentPasswordController.text,
            newPassword: _newPasswordController.text,
          );
      if (!mounted) return;
      setState(() {
        _isSaving = false;
        _success = true;
      });
      // Auto-close after showing success
      await Future.delayed(const Duration(seconds: 2));
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSaving = false;
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  InputDecoration _inputDecoration({
    required String hint,
    required IconData prefixIcon,
    Widget? suffix,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Colors.black26, fontSize: 13),
      prefixIcon:
          Icon(prefixIcon, color: const Color(0xFF8D6E63), size: 20),
      suffixIcon: suffix,
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      filled: true,
      fillColor: const Color(0xFFFAF7F2),
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
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      backgroundColor: Colors.white,
      child: SizedBox(
        width: 420,
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: _success ? _buildSuccess() : _buildForm(),
        ),
      ),
    );
  }

  // ── Success state ──────────────────────────────────────────────────────────
  Widget _buildSuccess() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.check_circle_outline,
            size: 52, color: Color(0xFF3E2723)),
        const SizedBox(height: 16),
        const Text(
          'Password Changed',
          style: TextStyle(
            fontFamily: 'serif',
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Color(0xFF3E2723),
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Your password has been updated successfully.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 13, color: Color(0xFF8D6E63)),
        ),
      ],
    );
  }

  // ── Form state ─────────────────────────────────────────────────────────────
  Widget _buildForm() {
    return Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ────────────────────────────────────────────────────────
          Row(
            children: [
              const Icon(Icons.lock_reset_outlined,
                  color: Color(0xFF3E2723), size: 22),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Change Password',
                  style: TextStyle(
                    fontFamily: 'serif',
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF3E2723),
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close,
                    color: Color(0xFF8D6E63), size: 20),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          const Divider(color: Color(0xFFE5DDD0), height: 24),

          // ── Error banner ───────────────────────────────────────────────────
          if (_errorMessage != null) ...[
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF0F0),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color: Colors.redAccent.withValues(alpha: 0.4)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline,
                      color: Colors.redAccent, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _errorMessage!,
                      style: const TextStyle(
                          fontSize: 12, color: Colors.redAccent),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          // ── Current Password ───────────────────────────────────────────────
          const Text(
            'Current Password',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Color(0xFF5D4037),
            ),
          ),
          const SizedBox(height: 6),
          TextFormField(
            controller: _currentPasswordController,
            obscureText: _obscureCurrent,
            style: const TextStyle(
                color: Color(0xFF3E2723), fontSize: 13),
            decoration: _inputDecoration(
              hint: 'Enter current password',
              prefixIcon: Icons.lock_outline,
              suffix: _eyeToggle(
                  obscure: _obscureCurrent,
                  onTap: () =>
                      setState(() => _obscureCurrent = !_obscureCurrent)),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Current password is required';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),

          // ── New Password ───────────────────────────────────────────────────
          const Text(
            'New Password',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Color(0xFF5D4037),
            ),
          ),
          const SizedBox(height: 6),
          TextFormField(
            controller: _newPasswordController,
            obscureText: _obscureNew,
            style: const TextStyle(
                color: Color(0xFF3E2723), fontSize: 13),
            decoration: _inputDecoration(
              hint: 'Enter new password',
              prefixIcon: Icons.lock_reset_outlined,
              suffix: _eyeToggle(
                  obscure: _obscureNew,
                  onTap: () =>
                      setState(() => _obscureNew = !_obscureNew)),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'New password is required';
              }
              if (value.length < 6) {
                return 'Password must be at least 6 characters';
              }
              if (value == _currentPasswordController.text) {
                return 'New password must differ from current password';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),

          // ── Confirm New Password ───────────────────────────────────────────
          const Text(
            'Confirm New Password',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Color(0xFF5D4037),
            ),
          ),
          const SizedBox(height: 6),
          TextFormField(
            controller: _confirmPasswordController,
            obscureText: _obscureConfirm,
            style: const TextStyle(
                color: Color(0xFF3E2723), fontSize: 13),
            onFieldSubmitted: (_) =>
                _isSaving ? null : _handleChangePassword(),
            decoration: _inputDecoration(
              hint: 'Confirm new password',
              prefixIcon: Icons.verified_outlined,
              suffix: _eyeToggle(
                  obscure: _obscureConfirm,
                  onTap: () => setState(
                      () => _obscureConfirm = !_obscureConfirm)),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please confirm your new password';
              }
              if (value != _newPasswordController.text) {
                return 'Passwords do not match';
              }
              return null;
            },
          ),
          const SizedBox(height: 28),

          // ── Action buttons ─────────────────────────────────────────────────
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFFE5DDD0)),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed:
                      _isSaving ? null : () => Navigator.of(context).pop(),
                  child: const Text(
                    'Cancel',
                    style: TextStyle(
                        fontSize: 13,
                        color: Color(0xFF8D6E63),
                        fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF3E2723),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    elevation: 2,
                  ),
                  onPressed:
                      _isSaving ? null : _handleChangePassword,
                  child: _isSaving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Text(
                          'Update Password',
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold),
                        ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _eyeToggle({required bool obscure, required VoidCallback onTap}) {
    return IconButton(
      icon: Icon(
        obscure
            ? Icons.visibility_outlined
            : Icons.visibility_off_outlined,
        color: const Color(0xFF8D6E63),
        size: 18,
      ),
      onPressed: onTap,
    );
  }
}
