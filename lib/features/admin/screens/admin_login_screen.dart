import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../services/supabase_service.dart';
import '../../../shared_widgets/qb_ui.dart';
import 'admin_dashboard_screen.dart';

/// Store Manager Staff Authentication Screen conforming to PRD Section 5.1 & 6.
/// Enforces Role-Based Access Control (RBAC) via Supabase Auth & user_roles.
class AdminLoginScreen extends StatefulWidget {
  const AdminLoginScreen({super.key});

  @override
  State<AdminLoginScreen> createState() => _AdminLoginScreenState();
}

class _AdminLoginScreenState extends State<AdminLoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _keepSignedIn = true;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleStaffLogin({String? prefillEmail, String? prefillPass}) async {
    final email = prefillEmail ?? _emailController.text.trim();
    final password = prefillPass ?? _passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      setState(() => _errorMessage = 'Please enter both staff email and password.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final managerData = await SupabaseService().signInStaff(
        email: email,
        password: password,
      );

      if (mounted) {
        setState(() => _isLoading = false);
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => AdminDashboardScreen(managerData: managerData),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = e.toString().replaceAll('Exception: ', '');
        });
      }
    }
  }

  void _goBack() {
    if (Navigator.canPop(context)) {
      Navigator.pop(context);
    } else {
      Navigator.pushReplacementNamed(context, '/');
    }
  }

  @override
  Widget build(BuildContext context) {
    final wide = Responsive.width(context) >= 900;
    final form = _buildForm();

    if (wide) {
      return Scaffold(
        backgroundColor: Colors.white,
        body: Row(
          children: [
            const Expanded(child: _BrandPanel()),
            Expanded(
              child: Stack(
                children: [
                  Center(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(48),
                      child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 400), child: form),
                    ),
                  ),
                  Positioned(
                    top: 20,
                    left: 20,
                    child: TextButton.icon(
                      onPressed: _goBack,
                      icon: const Icon(Icons.chevron_left_rounded),
                      label: const Text('Back to store'),
                      style: TextButton.styleFrom(foregroundColor: AppColors.textBody),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: ListView(
          children: [
            Stack(
              children: [
                const SizedBox(height: 330, child: _BrandPanel(compact: true)),
                Positioned(
                  top: 8,
                  left: 8,
                  child: IconButton(
                    tooltip: 'Back',
                    onPressed: _goBack,
                    icon: const Icon(Icons.chevron_left_rounded, color: Colors.white, size: 30),
                  ),
                ),
              ],
            ),
            Padding(padding: const EdgeInsets.fromLTRB(24, 28, 24, 32), child: form),
          ],
        ),
      ),
    );
  }

  Widget _buildForm() {
    return AutofillGroup(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Sign in', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, letterSpacing: -0.5)),
          const SizedBox(height: 6),
          const Text('Restricted to authorized Store Managers', style: TextStyle(fontSize: 14, color: AppColors.textSecondary)),
          const SizedBox(height: 22),
          const Text('Work email', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textBody)),
          const SizedBox(height: 8),
          TextField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            autofillHints: const [AutofillHints.email],
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              hintText: 'manager@quickbasket.com',
              contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 16),
            ),
          ),
          const SizedBox(height: 16),
          const Text('Password', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textBody)),
          const SizedBox(height: 8),
          TextField(
            controller: _passwordController,
            obscureText: _obscurePassword,
            autofillHints: const [AutofillHints.password],
            onSubmitted: (_) => _handleStaffLogin(),
            decoration: InputDecoration(
              hintText: '••••••••',
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
              suffixIcon: IconButton(
                tooltip: _obscurePassword ? 'Show password' : 'Hide password',
                onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                icon: Icon(_obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined, size: 20),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Checkbox(
                value: _keepSignedIn,
                activeColor: AppColors.primary,
                onChanged: (v) => setState(() => _keepSignedIn = v ?? true),
              ),
              const Expanded(
                child: Text('Keep me signed in on this device', style: TextStyle(fontSize: 14, color: AppColors.textBody)),
              ),
              TextButton(
                onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Ask your store administrator to reset your password')),
                ),
                child: const Text('Forgot?'),
              ),
            ],
          ),
          if (_errorMessage != null) ...[
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.errorLight,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.errorBorder),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline_rounded, color: AppColors.error, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(_errorMessage!,
                        style: const TextStyle(color: AppColors.error, fontSize: 13, fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 14),
          ElevatedButton(
            onPressed: _isLoading ? null : () => _handleStaffLogin(),
            style: ElevatedButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
              textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
            ),
            child: _isLoading
                ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Text('Sign in to dashboard'),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: _isLoading
                ? null
                : () {
                    _emailController.text = 'manager@quickbasket.com';
                    _passwordController.text = 'admin123';
                    _handleStaffLogin(prefillEmail: 'manager@quickbasket.com', prefillPass: 'admin123');
                  },
            icon: const Icon(Icons.bolt_rounded, size: 18),
            label: const Text('Use demo manager account'),
            style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(color: AppColors.adminBackground, borderRadius: BorderRadius.circular(12)),
            child: const Row(
              children: [
                Icon(Icons.verified_user_outlined, color: AppColors.primary, size: 18),
                SizedBox(width: 10),
                Expanded(
                  child: Text('Secured with Supabase Auth · role-based access',
                      style: TextStyle(fontSize: 12, color: AppColors.textBody)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BrandPanel extends StatelessWidget {
  final bool compact;
  const _BrandPanel({this.compact = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.primary,
      child: Stack(
        clipBehavior: Clip.hardEdge,
        children: [
          Positioned(
            right: -200,
            top: -160,
            child: Container(width: 520, height: 520, decoration: const BoxDecoration(color: Color(0xFF0A7438), shape: BoxShape.circle)),
          ),
          Positioned(
            left: -120,
            bottom: -120,
            child: Container(width: 300, height: 300, decoration: const BoxDecoration(color: Color(0xFF0A7438), shape: BoxShape.circle)),
          ),
          Padding(
            padding: EdgeInsets.all(compact ? 28 : 48),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: compact ? MainAxisAlignment.end : MainAxisAlignment.spaceBetween,
              children: [
                if (!compact) const QbLogo(size: 48, textColor: Colors.white),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(color: AppColors.accent, borderRadius: BorderRadius.circular(6)),
                      child: const Text('STORE STAFF PORTAL',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 0.7)),
                    ),
                    const SizedBox(height: 14),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 460),
                      child: Text(
                        'Run your dark store from one screen.',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: compact ? 28 : 40,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -1,
                          height: 1.1,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 460),
                      child: Text(
                        'Accept orders, pack faster, keep shelves stocked and see how the day is going — live.',
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.92), fontSize: compact ? 14 : 16, height: 1.55),
                      ),
                    ),
                  ],
                ),
                if (!compact)
                  const Wrap(
                    spacing: 24,
                    runSpacing: 8,
                    children: [
                      _Feature('Live order board'),
                      _Feature('Inventory alerts'),
                      _Feature('Catalog control'),
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Feature extends StatelessWidget {
  final String label;
  const _Feature(this.label);

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.check_rounded, color: Colors.white, size: 18),
        const SizedBox(width: 8),
        Text(label, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
      ],
    );
  }
}
