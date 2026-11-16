import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../shared_widgets/qb_ui.dart';

/// Rider tip selector + bill breakdown (PRD 4.8).
///
/// Renders two cards on mobile. With [embedded] = true (desktop summary
/// column) it renders the same content without card chrome.
class BillDetailsCard extends StatelessWidget {
  final double itemTotal;
  final double itemMrpTotal;
  final double deliveryFee;
  final double packagingFee;
  final double couponDiscount;
  final double tipAmount;
  final double grandTotal;
  final ValueChanged<double> onTipSelected;
  final bool embedded;
  final bool showTip;

  const BillDetailsCard({
    super.key,
    required this.itemTotal,
    required this.itemMrpTotal,
    required this.deliveryFee,
    this.packagingFee = 5.0,
    this.couponDiscount = 0.0,
    this.tipAmount = 0.0,
    required this.grandTotal,
    required this.onTipSelected,
    this.embedded = false,
    this.showTip = true,
  });

  static const List<double> tipOptions = [10, 20, 30, 50];

  double get totalSavings =>
      (itemMrpTotal - itemTotal) + couponDiscount + (deliveryFee == 0 && itemTotal >= 199 ? 25 : 0);

  @override
  Widget build(BuildContext context) {
    final tip = _buildTipSection();
    final bill = _buildBillSection();

    if (embedded) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (showTip) ...[tip, const SizedBox(height: 16)],
          Container(
            padding: const EdgeInsets.only(top: 14),
            decoration: const BoxDecoration(border: Border(top: BorderSide(color: AppColors.divider))),
            child: bill,
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (showTip) ...[
          Container(padding: const EdgeInsets.all(14), decoration: qbCard(), child: tip),
          const SizedBox(height: 12),
        ],
        Container(padding: const EdgeInsets.all(14), decoration: qbCard(), child: bill),
      ],
    );
  }

  Widget _buildTipSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Tip your delivery partner',
          style: TextStyle(fontSize: embedded ? 13 : 14, fontWeight: FontWeight.w800),
        ),
        if (!embedded) ...[
          const SizedBox(height: 2),
          const Text('100% of the tip goes to them', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
        ],
        const SizedBox(height: 10),
        Row(
          children: [
            for (var i = 0; i < tipOptions.length; i++) ...[
              if (i > 0) const SizedBox(width: 8),
              Expanded(child: _tipChip(tipOptions[i])),
            ],
          ],
        ),
      ],
    );
  }

  Widget _tipChip(double amount) {
    final selected = tipAmount == amount;
    return Material(
      color: selected ? AppColors.primary : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: selected ? AppColors.primary : AppColors.borderStrong, width: 1.5),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => onTipSelected(selected ? 0 : amount),
        child: SizedBox(
          height: 40,
          child: Center(
            child: Text(
              '₹${amount.toStringAsFixed(0)}',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: selected ? Colors.white : AppColors.textPrimary,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBillSection() {
    final hasMrpSaving = itemMrpTotal > itemTotal;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!embedded) ...[
          const Text('Bill details', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
          const SizedBox(height: 10),
        ],
        _row(
          'Item total',
          Text.rich(TextSpan(children: [
            if (hasMrpSaving)
              TextSpan(
                text: '₹${itemMrpTotal.toStringAsFixed(0)} ',
                style: const TextStyle(color: AppColors.textMuted, decoration: TextDecoration.lineThrough),
              ),
            TextSpan(text: '₹${itemTotal.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.w800)),
          ])),
        ),
        _row(
          'Delivery fee',
          deliveryFee == 0
              ? const Text.rich(TextSpan(children: [
                  TextSpan(
                    text: '₹25 ',
                    style: TextStyle(color: AppColors.textMuted, decoration: TextDecoration.lineThrough),
                  ),
                  TextSpan(text: 'FREE', style: TextStyle(fontWeight: FontWeight.w800, color: AppColors.primaryDeep)),
                ]))
              : Text('₹${deliveryFee.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.w800)),
        ),
        _row('Packaging fee', Text('₹${packagingFee.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.w800))),
        _row('Delivery partner tip', Text('₹${tipAmount.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.w800))),
        if (couponDiscount > 0)
          _row(
            'Coupon discount',
            Text('−₹${couponDiscount.toStringAsFixed(0)}',
                style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.primaryDeep)),
          ),
        const Padding(padding: EdgeInsets.symmetric(vertical: 6), child: Divider(height: 1)),
        Row(
          children: [
            Expanded(
              child: Text('To pay', style: TextStyle(fontSize: embedded ? 17 : 15, fontWeight: FontWeight.w800)),
            ),
            Text(
              '₹${grandTotal.toStringAsFixed(0)}',
              style: TextStyle(fontSize: embedded ? 17 : 15, fontWeight: FontWeight.w800),
            ),
          ],
        ),
        if (totalSavings > 0) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(color: AppColors.primaryLight, borderRadius: BorderRadius.circular(10)),
            child: Text(
              'You are saving ₹${totalSavings.toStringAsFixed(0)} on this order',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.primaryDeep),
            ),
          ),
        ],
      ],
    );
  }

  Widget _row(String label, Widget value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: DefaultTextStyle.merge(
        style: const TextStyle(fontSize: 13),
        child: Row(
          children: [
            Expanded(child: Text(label, style: const TextStyle(color: AppColors.textBody))),
            value,
          ],
        ),
      ),
    );
  }
}
