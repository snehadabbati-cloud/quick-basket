import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/config/delivery_config.dart';
import '../../../core/constants/app_colors.dart';
import '../../../shared_widgets/qb_ui.dart';
import '../controllers/rider_session.dart';
import '../widgets/rider_ui.dart';
import 'rider_otp_screen.dart';
import 'rider_shell.dart';

/// Route helper: every rider page is shown at phone width on wide screens.
Route<T> riderRoute<T>(Widget page) => MaterialPageRoute<T>(builder: (_) => RiderFrame(child: page));

/// 1.1 Rider Login — registered mobile number → Supabase phone OTP.
/// Restores an existing session automatically.
class RiderLoginScreen extends StatefulWidget {
  /// Set false in tests to skip automatic session restore.
  final bool autoRestore;
  const RiderLoginScreen({super.key, this.autoRestore = true});

  @override
  State<RiderLoginScreen> createState() => _RiderLoginScreenState();
}

class _RiderLoginScreenState extends State<RiderLoginScreen> {
  final _ctrl = TextEditingController();
  bool _restoring = true;
  bool _sending = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.autoRestore) {
      _tryRestore();
    } else {
      _restoring = false;
    }
  }

  Future<void> _tryRestore() async {
    final ok = await RiderSession().restore();
    if (!mounted) return;
    if (ok) {
      Navigator.of(context).pushReplacement(riderRoute(const RiderShell()));
    } else {
      setState(() => _restoring = false);
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _sendOtp() async {
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      final req = await RiderSession().requestOtp(_ctrl.text);
      if (!mounted) return;
      setState(() => _sending = false);
      Navigator.of(context).push(riderRoute(RiderOtpScreen(request: req)));
    } on RiderException catch (e) {
      if (!mounted) return;
      setState(() {
        _sending = false;
        _error = e.message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_restoring) {
      return const RiderFrame(
        child: Scaffold(body: Center(child: CircularProgressIndicator(color: AppColors.primary))),
      );
    }
    return RiderFrame(
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.fromLTRB(24, 20, 24, 30),
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            colors: [AppColors.primary, AppColors.primaryDark],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Expanded(child: QbLogo(size: 38, textColor: Colors.white)),
                                TextButton(
                                  onPressed: () => Navigator.of(context).pushReplacementNamed('/'),
                                  child: const Text('Customer app', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            const Padding(
                              padding: EdgeInsets.only(left: 2),
                              child: QbPill(
                                label: 'DELIVERY PARTNER',
                                background: AppColors.accent,
                                foreground: AppColors.primaryDark,
                                fontSize: 10,
                              ),
                            ),
                            const SizedBox(height: 24),
                            Center(
                              child: Container(
                                width: 110,
                                height: 110,
                                decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.12), shape: BoxShape.circle),
                                child: const Icon(Icons.delivery_dining_rounded, size: 66, color: AppColors.accent),
                              ),
                            ),
                            const SizedBox(height: 22),
                            const Text(
                              'Deliver happiness\nin minutes.',
                              style: TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w900, height: 1.15, letterSpacing: -0.5),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Log in with your registered mobile number to start your shift.',
                              style: TextStyle(color: Color(0xFFCFEBD9), fontSize: 13.5, height: 1.4),
                            ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Mobile number', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                            const SizedBox(height: 8),
                            Container(
                              decoration: qbCard(borderColor: _error != null ? AppColors.error : AppColors.borderStrong, radius: 14),
                              padding: const EdgeInsets.symmetric(horizontal: 14),
                              child: Row(
                                children: [
                                  const Text('+91', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                                  Container(width: 1, height: 26, color: AppColors.border, margin: const EdgeInsets.symmetric(horizontal: 12)),
                                  Expanded(
                                    child: TextField(
                                      key: const ValueKey('rider_phone_field'),
                                      controller: _ctrl,
                                      keyboardType: TextInputType.phone,
                                      autofocus: true,
                                      inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(10)],
                                      onSubmitted: (_) => _sendOtp(),
                                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, letterSpacing: 1),
                                      decoration: const InputDecoration(
                                        border: InputBorder.none,
                                        enabledBorder: InputBorder.none,
                                        focusedBorder: InputBorder.none,
                                        filled: false,
                                        hintText: '10-digit number',
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 10),
                            if (_error != null)
                              Text(_error!, style: const TextStyle(fontSize: 12.5, color: AppColors.error, fontWeight: FontWeight.w600))
                            else
                              const Row(
                                children: [
                                  Icon(Icons.verified_user_outlined, size: 15, color: AppColors.primary),
                                  SizedBox(width: 6),
                                  Expanded(
                                    child: Text('Only partners onboarded by Quick Basket can log in.',
                                        style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                                  ),
                                ],
                              ),
                            if (RiderSession.testRidersEnabled) ...[
                              const SizedBox(height: 14),
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(color: AppColors.infoLight, borderRadius: BorderRadius.circular(10)),
                                child: const Text(
                                  'Test mode: built-in test riders (e.g. 98765 43210) skip SMS and use OTP ${DeliveryConfig.debugTestRiderOtp}. '
                                  'Partners added in the Admin Panel receive a real SMS OTP.',
                                  style: TextStyle(fontSize: 11.5, color: AppColors.info, height: 1.35),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
                child: RPrimaryButton(
                  label: _sending ? 'Sending…' : 'Send OTP',
                  icon: Icons.sms_outlined,
                  onPressed: _sending ? null : _sendOtp,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
