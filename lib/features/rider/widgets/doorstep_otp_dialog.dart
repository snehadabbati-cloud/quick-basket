import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/config/delivery_config.dart';
import '../../../models/order_model.dart';
import '../../../services/supabase_service.dart';

/// Secure Doorstep OTP Verification Dialog for Delivery Partners.
/// Conforms to Security Requirements:
/// 1. Plain-text OTP is NEVER shown to the rider.
/// 2. Rider must input the OTP given by the customer in person.
/// 3. Validated on backend/Supabase with a 3-attempt lockout limit.
class DoorstepOtpDialog extends StatefulWidget {
  final OrderModel order;
  final String riderId;

  const DoorstepOtpDialog({
    super.key,
    required this.order,
    required this.riderId,
  });

  static Future<bool?> show(
    BuildContext context, {
    required OrderModel order,
    required String riderId,
  }) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => DoorstepOtpDialog(
        order: order,
        riderId: riderId,
      ),
    );
  }

  @override
  State<DoorstepOtpDialog> createState() => _DoorstepOtpDialogState();
}

class _DoorstepOtpDialogState extends State<DoorstepOtpDialog> {
  final _otpController = TextEditingController();
  bool _isSubmitting = false;
  String? _errorMessage;
  int _remainingAttempts = DeliveryConfig.maxOtpAttempts;
  bool _isLocked = false;

  @override
  void initState() {
    super.initState();
    _remainingAttempts = (DeliveryConfig.maxOtpAttempts - widget.order.otpAttempts).clamp(0, DeliveryConfig.maxOtpAttempts);
    if (_remainingAttempts <= 0) {
      _isLocked = true;
      _errorMessage = 'Maximum OTP verification attempts exceeded. Order is locked.';
    }
  }

  @override
  void dispose() {
    _otpController.dispose();
    super.dispose();
  }

  Future<void> _verifyOtp() async {
    final entered = _otpController.text.trim();
    if (entered.length < 4) {
      setState(() => _errorMessage = 'Please enter a valid 4-digit OTP');
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      final res = await SupabaseService().verifyDoorstepOtp(
        orderId: widget.order.id,
        enteredOtp: entered,
        riderId: widget.riderId,
      );

      final success = res['success'] == true;
      final remaining = (res['remaining_attempts'] as num?)?.toInt() ?? (_remainingAttempts - 1);
      final locked = res['locked'] == true;

      if (mounted) {
        if (success) {
          Navigator.of(context).pop(true);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Delivery confirmed! OTP verified successfully.'),
              backgroundColor: Color(0xFF0C8340),
              behavior: SnackBarBehavior.floating,
            ),
          );
        } else {
          setState(() {
            _remainingAttempts = remaining.clamp(0, DeliveryConfig.maxOtpAttempts);
            _isLocked = locked || _remainingAttempts <= 0;
            _errorMessage = res['error'] as String? ??
                (_isLocked
                    ? 'Maximum attempts exceeded. Order is locked. Please contact store support.'
                    : 'Incorrect OTP. $_remainingAttempts attempt(s) remaining.');
            _otpController.clear();
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _errorMessage = 'Verification error: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      backgroundColor: Colors.white,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Icon Header
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: _isLocked ? const Color(0xFFFFEBEE) : const Color(0xFFE8F5E9),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _isLocked ? Icons.lock_outline_rounded : Icons.verified_user_outlined,
                  color: _isLocked ? AppColors.error : const Color(0xFF0C8340),
                  size: 28,
                ),
              ),
              const SizedBox(height: 16),

              // Title
              Text(
                _isLocked ? 'Order Verification Locked' : 'Doorstep OTP Verification',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
              ),
              const SizedBox(height: 6),
              Text(
                widget.order.orderNumber,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 12),

              // Instructions
              Text(
                _isLocked
                    ? '3 incorrect OTP attempts were recorded. Delivery completion is locked for customer security.'
                    : 'Ask the customer for the 4-digit Delivery OTP shown in their Quick Basket app.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: _isLocked ? AppColors.error : AppColors.textSecondary,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 20),

              // OTP Input Field
              if (!_isLocked) ...[
                SizedBox(
                  width: 220,
                  child: TextField(
                    controller: _otpController,
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    maxLength: 6,
                    style: const TextStyle(fontSize: 26, letterSpacing: 8, fontWeight: FontWeight.w900),
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: InputDecoration(
                      hintText: '••••',
                      counterText: '',
                      filled: true,
                      fillColor: const Color(0xFFF8F9FA),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: const BorderSide(color: Color(0xFF0C8340), width: 2),
                      ),
                      contentPadding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onSubmitted: (_) => _isSubmitting ? null : _verifyOtp(),
                  ),
                ),
                const SizedBox(height: 8),

                // Remaining Attempts Counter Badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _remainingAttempts <= 1 ? const Color(0xFFFFEBEE) : const Color(0xFFF1F8E9),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '$_remainingAttempts attempt(s) remaining',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: _remainingAttempts <= 1 ? AppColors.error : const Color(0xFF2E7D32),
                    ),
                  ),
                ),
              ],

              // Error Banner
              if (_errorMessage != null) ...[
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF3E0),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFFFCC80)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.warning_amber_rounded, size: 16, color: Color(0xFFE65100)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFFBF360C)),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 24),

              // Action Buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(false),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: Text(_isLocked ? 'Close' : 'Cancel'),
                    ),
                  ),
                  if (!_isLocked) ...[
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton(
                        onPressed: _isSubmitting ? null : _verifyOtp,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0C8340),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        child: _isSubmitting
                            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Text('Verify & Complete', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
