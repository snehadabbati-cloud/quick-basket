import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/constants/app_colors.dart';
import '../controllers/rider_session.dart';
import '../widgets/rider_helpers.dart';
import '../widgets/rider_ui.dart';
import 'rider_login_screen.dart';
import 'rider_shell.dart';

/// 1.2 OTP Verification for riders.
class RiderOtpScreen extends StatefulWidget {
  final RiderOtpRequest request;
  const RiderOtpScreen({super.key, required this.request});

  @override
  State<RiderOtpScreen> createState() => _RiderOtpScreenState();
}

class _RiderOtpScreenState extends State<RiderOtpScreen> {
  final _ctrl = TextEditingController();
  final _focus = FocusNode();
  Timer? _timer;
  int _resendIn = 30;
  bool _verifying = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _startTimer();
    _ctrl.addListener(() => setState(() {}));
  }

  void _startTimer() {
    _timer?.cancel();
    _resendIn = 30;
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      setState(() => _resendIn > 0 ? _resendIn-- : t.cancel());
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _ctrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    setState(() {
      _verifying = true;
      _error = null;
    });
    try {
      await RiderSession().verifyOtp(_ctrl.text);
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(riderRoute(const RiderShell()), (r) => false);
    } on RiderException catch (e) {
      if (!mounted) return;
      setState(() {
        _verifying = false;
        _error = e.message;
      });
    }
  }

  Future<void> _resend() async {
    try {
      await RiderSession().requestOtp(widget.request.phoneE164);
      if (!mounted) return;
      _startTimer();
      riderToast(context, widget.request.usesTestCode ? 'Test rider: use the debug OTP' : 'OTP sent again');
    } on RiderException catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final code = _ctrl.text;
    final phone = widget.request.phoneE164;
    final display = '${phone.substring(0, 3)} ${phone.substring(3, 8)} ${phone.substring(8)}';
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(backgroundColor: Colors.white),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: AppColors.primaryLight, borderRadius: BorderRadius.circular(16)),
                child: const Icon(Icons.mark_email_read_outlined, color: AppColors.primaryDeep, size: 28),
              ),
              const SizedBox(height: 18),
              Text('Hi ${widget.request.rider.name.split(' ').first}, verify your number',
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: -0.4)),
              const SizedBox(height: 6),
              Text.rich(
                TextSpan(
                  text: 'Enter the 6-digit code sent to ',
                  children: [TextSpan(text: display, style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.textPrimary))],
                ),
                style: const TextStyle(fontSize: 14, color: AppColors.textSecondary, height: 1.4),
              ),
              const SizedBox(height: 24),
              // Boxes are a view over one hidden text field (keyboard + paste friendly).
              GestureDetector(
                onTap: () => _focus.requestFocus(),
                child: Stack(
                  children: [
                    Opacity(
                      opacity: 0,
                      child: SizedBox(
                        height: 54,
                        child: TextField(
                          key: const ValueKey('rider_otp_field'),
                          controller: _ctrl,
                          focusNode: _focus,
                          autofocus: true,
                          keyboardType: TextInputType.number,
                          inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(6)],
                          onSubmitted: (_) => code.length == 6 ? _verify() : null,
                        ),
                      ),
                    ),
                    IgnorePointer(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: List.generate(6, (i) {
                          final filled = i < code.length;
                          final focused = i == code.length;
                          return Container(
                            width: 44,
                            height: 54,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: filled ? AppColors.primaryTint : Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: _error != null
                                    ? AppColors.error
                                    : focused
                                        ? AppColors.primary
                                        : (filled ? AppColors.primary.withValues(alpha: 0.4) : AppColors.borderStrong),
                                width: focused ? 2 : 1.3,
                              ),
                            ),
                            child: Text(filled ? code[i] : '', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
                          );
                        }),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              if (_error != null)
                Text(_error!, style: const TextStyle(color: AppColors.error, fontWeight: FontWeight.w700, fontSize: 12.5)),
              const SizedBox(height: 6),
              Row(
                children: [
                  const Text('Didn\'t get it? ', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                  if (_resendIn > 0)
                    Text('Resend in 0:${_resendIn.toString().padLeft(2, '0')}',
                        style: const TextStyle(color: AppColors.textMuted, fontWeight: FontWeight.w700, fontSize: 13))
                  else
                    GestureDetector(
                      onTap: _resend,
                      child: const Text('Resend OTP', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w800, fontSize: 13)),
                    ),
                ],
              ),
              const Spacer(),
              RPrimaryButton(
                label: _verifying ? 'Verifying…' : 'Verify & Start Shift',
                icon: Icons.login_rounded,
                onPressed: code.length == 6 && !_verifying ? _verify : null,
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}
