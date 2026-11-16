import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../services/supabase_service.dart';
import '../widgets/auth_shell.dart';

/// Customer Profile Creation Screen conforming to PRD Section 4.1
class ProfileSetupScreen extends StatefulWidget {
  final String userId;
  final String phoneNumber;

  const ProfileSetupScreen({
    super.key,
    required this.userId,
    required this.phoneNumber,
  });

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _handleSaveProfile() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() => _errorMessage = 'Please enter your full name');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await SupabaseService().saveProfile(
        userId: widget.userId,
        fullName: name,
        phoneNumber: widget.phoneNumber,
        email: _emailController.text.trim(),
      );

      if (!mounted) return;
      setState(() => _isLoading = false);

      // Return to home screen
      Navigator.of(context).popUntil((route) => route.isFirst);
    } catch (e) {
      if (!mounted) return;
      debugPrint('[ProfileSetupScreen] Error: $e');
      setState(() {
        _isLoading = false;
        _errorMessage = e.toString().contains('policy') || e.toString().contains('security')
            ? 'Database permission error: Please run the RLS policy update in Supabase SQL editor.'
            : 'Failed to save profile: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthShell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Complete your profile', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, letterSpacing: -0.4)),
          const SizedBox(height: 6),
          Text.rich(
            TextSpan(children: [
              const TextSpan(text: 'Verified '),
              TextSpan(text: widget.phoneNumber, style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
              const TextSpan(text: ' · tell us what to call you'),
            ]),
            style: const TextStyle(fontSize: 14, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _nameController,
            autofocus: true,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(labelText: 'Full Name', hintText: 'e.g. Ananya Rao'),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            onSubmitted: (_) => _handleSaveProfile(),
            decoration: const InputDecoration(labelText: 'Email Address (Optional)', hintText: 'you@example.com'),
          ),
          if (_errorMessage != null) ...[
            const SizedBox(height: 12),
            AuthError(_errorMessage!),
          ],
          const SizedBox(height: 18),
          ElevatedButton(
            onPressed: _isLoading ? null : _handleSaveProfile,
            style: ElevatedButton.styleFrom(
              minimumSize: const Size.fromHeight(54),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
            ),
            child: _isLoading
                ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Text('Save & start shopping'),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: _isLoading ? null : () => Navigator.of(context).popUntil((route) => route.isFirst),
            child: const Text('Skip for now'),
          ),
        ],
      ),
    );
  }
}
