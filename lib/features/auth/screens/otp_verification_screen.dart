import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/constants/app_colors.dart';
import '../../../services/supabase_service.dart';
import '../widgets/auth_shell.dart';
import 'profile_setup_screen.dart';

/// Customer OTP Verification Screen conforming to PRD Section 4.1
class OtpVerificationScreen extends StatefulWidget {
  final String phoneNumber;
  final String displayPhone;

  const OtpVerificationScreen({
    super.key,
    required this.phoneNumber,
    required this.displayPhone,
  });

  @override
  State<OtpVerificationScreen> createState() => _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends State<OtpVerificationScreen> {
  final List<TextEditingController> _otpControllers = List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());

  int _resendCountdown = 30;
  Timer? _timer;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _startCountdown();
    for (final f in _focusNodes) {
      f.addListener(() {
        if (mounted) setState(() {});
      });
    }
  }

  void _startCountdown() {
    setState(() => _resendCountdown = 30);
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_resendCountdown > 0) {
        setState(() => _resendCountdown--);
      } else {
        timer.cancel();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    for (var c in _otpControllers) {
      c.dispose();
    }
    for (var f in _focusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  String get _enteredOtp => _otpControllers.map((c) => c.text.trim()).join();

  Future<void> _handleVerifyOtp() async {
    final otp = _enteredOtp;
    if (otp.length != 6) {
      setState(() => _errorMessage = 'Please enter all 6 digits of the OTP');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await SupabaseService().verifyOtp(
        phoneNumber: widget.phoneNumber,
        token: otp,
      );

      final user = response?.user ?? SupabaseService().currentUser;

      if (!mounted) return;
      setState(() => _isLoading = false);

      if (user != null) {
        // Check if user has an existing profile in the 'profiles' table
        final profile = await SupabaseService().getProfile(user.id);

        if (!mounted) return;

        if (profile == null ||
            profile['full_name'] == null ||
            (profile['full_name'] as String).trim().isEmpty ||
            profile['full_name'] == 'Quick Basket Customer') {
          // New user or default placeholder -> Profile Setup
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => ProfileSetupScreen(
                userId: user.id,
                phoneNumber: widget.phoneNumber,
              ),
            ),
          );
        } else {
          // Profile exists -> Return to Home
          Navigator.of(context).popUntil((route) => route.isFirst);
        }
      } else {
        // In offline/dev fallback
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'Invalid or expired OTP. Please try again.';
      });
    }
  }

  Future<void> _handleResendOtp() async {
    if (_resendCountdown > 0) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await SupabaseService().sendOtp(phoneNumber: widget.phoneNumber);
      if (!mounted) return;
      setState(() => _isLoading = false);
      _startCountdown();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('A new OTP has been sent!'), behavior: SnackBarBehavior.floating),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'Failed to resend OTP. Please wait and try again.';
      });
    }
  }

  Widget _digitBox(int index) {
    final filled = _otpControllers[index].text.isNotEmpty;
    return SizedBox(
      height: 56,
      child: TextField(
        controller: _otpControllers[index],
        focusNode: _focusNodes[index],
        keyboardType: TextInputType.number,
        textAlign: TextAlign.center,
        maxLength: 1,
        autofocus: index == 0,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
        decoration: InputDecoration(
          counterText: '',
          filled: true,
          fillColor: filled ? AppColors.primaryTint : Colors.white,
          contentPadding: EdgeInsets.zero,
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: filled ? AppColors.primary : AppColors.borderStrong, width: 1.5),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.textPrimary, width: 1.5),
          ),
        ),
        onChanged: (val) {
          setState(() {});
          if (val.isNotEmpty && index < 5) {
            _focusNodes[index + 1].requestFocus();
          } else if (val.isEmpty && index > 0) {
            _focusNodes[index - 1].requestFocus();
          }
          if (_enteredOtp.length == 6) {
            _handleVerifyOtp();
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final anyFocused = _focusNodes.any((f) => f.hasFocus);
    return AuthShell(
      onBack: () => Navigator.pop(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Enter verification code', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, letterSpacing: -0.4)),
          const SizedBox(height: 6),
          Text.rich(
            TextSpan(children: [
              const TextSpan(text: 'Sent to '),
              TextSpan(text: widget.displayPhone, style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
            ]),
            style: const TextStyle(fontSize: 14, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 22),
          Row(
            children: [
              for (var i = 0; i < 6; i++) ...[
                if (i > 0) const SizedBox(width: 8),
                Expanded(
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: anyFocused && _focusNodes[i].hasFocus
                          ? const [BoxShadow(color: AppColors.primaryLight, spreadRadius: 4)]
                          : null,
                    ),
                    child: _digitBox(i),
                  ),
                ),
              ],
            ],
          ),
          if (_errorMessage != null) ...[
            const SizedBox(height: 12),
            AuthError(_errorMessage!),
          ],
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _resendCountdown > 0
                    ? Text.rich(
                        TextSpan(children: [
                          const TextSpan(text: 'Didn’t get it? Resend in '),
                          TextSpan(
                            text: '0:${_resendCountdown.toString().padLeft(2, '0')}',
                            style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                          ),
                        ]),
                        style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                      )
                    : TextButton(
                        onPressed: _isLoading ? null : _handleResendOtp,
                        style: TextButton.styleFrom(padding: EdgeInsets.zero, alignment: Alignment.centerLeft),
                        child: const Text('Resend OTP', style: TextStyle(fontWeight: FontWeight.w800)),
                      ),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Change number', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: _isLoading ? null : _handleVerifyOtp,
            style: ElevatedButton.styleFrom(
              minimumSize: const Size.fromHeight(54),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
            ),
            child: _isLoading
                ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Text('Verify & continue'),
          ),
        ],
      ),
    );
  }
}
