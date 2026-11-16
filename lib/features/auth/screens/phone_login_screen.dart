import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/constants/app_colors.dart';
import '../../../services/supabase_service.dart';
import '../widgets/auth_shell.dart';
import 'otp_verification_screen.dart';

/// Customer Phone Authentication Screen conforming to PRD Section 4.1
class PhoneLoginScreen extends StatefulWidget {
  const PhoneLoginScreen({super.key});

  @override
  State<PhoneLoginScreen> createState() => _PhoneLoginScreenState();
}

class _PhoneLoginScreenState extends State<PhoneLoginScreen> {
  final TextEditingController _phoneController = TextEditingController();
  final String _countryCode = '+91'; // India default as per PRD 4.1
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _handleGetOtp() async {
    final rawPhone = _phoneController.text.trim();
    if (rawPhone.isEmpty || rawPhone.length != 10 || !RegExp(r'^[0-9]+$').hasMatch(rawPhone)) {
      setState(() {
        _errorMessage = 'Please enter a valid 10-digit mobile number';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final fullPhoneNumber = '$_countryCode$rawPhone';

    try {
      await SupabaseService().sendOtp(phoneNumber: fullPhoneNumber);
      if (!mounted) return;

      setState(() => _isLoading = false);

      // Navigate to OTP verification screen
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => OtpVerificationScreen(
            phoneNumber: fullPhoneNumber,
            displayPhone: '$_countryCode $rawPhone',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthShell(
      onBack: Navigator.canPop(context) ? () => Navigator.pop(context) : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Login with Mobile Number',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, letterSpacing: -0.4),
          ),
          const SizedBox(height: 6),
          const Text(
            'We’ll send a 6-digit OTP to verify your number',
            style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 20),
          const Text('Mobile number', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textBody)),
          const SizedBox(height: 8),
          TextField(
            controller: _phoneController,
            keyboardType: TextInputType.phone,
            autofocus: true,
            maxLength: 10,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            onSubmitted: (_) => _handleGetOtp(),
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600, letterSpacing: 0.8),
            decoration: InputDecoration(
              counterText: '',
              hintText: '98765 43210',
              prefixIcon: Padding(
                padding: const EdgeInsets.only(left: 14, right: 10),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(_countryCode, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                    const SizedBox(width: 10),
                    Container(width: 1, height: 24, color: const Color(0xFFE2E8E4)),
                  ],
                ),
              ),
              contentPadding: const EdgeInsets.symmetric(vertical: 18),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: AppColors.borderStrong, width: 1.5),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
              ),
            ),
          ),
          if (_errorMessage != null) ...[
            const SizedBox(height: 12),
            AuthError(_errorMessage!),
          ],
          const SizedBox(height: 18),
          ElevatedButton(
            onPressed: _isLoading ? null : _handleGetOtp,
            style: ElevatedButton.styleFrom(
              minimumSize: const Size.fromHeight(54),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
            ),
            child: _isLoading
                ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Text('Continue'),
          ),
          const SizedBox(height: 14),
          const Text.rich(
            TextSpan(children: [
              TextSpan(text: 'By continuing, you agree to our '),
              TextSpan(text: 'Terms of Service', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700)),
              TextSpan(text: ' & '),
              TextSpan(text: 'Privacy Policy', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700)),
            ]),
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary, height: 1.5),
          ),
        ],
      ),
    );
  }
}
