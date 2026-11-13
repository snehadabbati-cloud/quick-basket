import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';

class BillDetailsCard extends StatelessWidget {
  final double itemTotal;
  final double itemMrpTotal;
  final double deliveryFee;
  final double packagingFee;
  final double couponDiscount;
  final double tipAmount;
  final double grandTotal;
  final ValueChanged<double> onTipSelected;

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
  });

  @override
  Widget build(BuildContext context) {
    final totalSavings = (itemMrpTotal - itemTotal) + couponDiscount + (deliveryFee == 0 && itemTotal >= 199 ? 25 : 0);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border, width: 0.8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          const Row(
            children: [
              Icon(Icons.receipt_outlined, size: 20, color: AppColors.primary),
              SizedBox(width: 8),
              Text(
                'Bill Details',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Items Total
          _buildRow(
            label: 'Items Total',
            value: '₹${itemTotal.toStringAsFixed(0)}',
            strikeValue: itemMrpTotal > itemTotal ? '₹${itemMrpTotal.toStringAsFixed(0)}' : null,
          ),
          const SizedBox(height: 10),

          // Delivery Fee
          _buildRow(
            label: 'Delivery Fee',
            value: deliveryFee == 0 ? 'FREE' : '₹${deliveryFee.toStringAsFixed(0)}',
            valueColor: deliveryFee == 0 ? AppColors.primary : AppColors.textPrimary,
            strikeValue: deliveryFee == 0 ? '₹25' : null,
          ),
          const SizedBox(height: 10),

          // Packaging Charge
          _buildRow(
            label: 'Handling & Packaging',
            value: '₹${packagingFee.toStringAsFixed(0)}',
          ),

          // Coupon Discount
          if (couponDiscount > 0) ...[
            const SizedBox(height: 10),
            _buildRow(
              label: 'Coupon Discount',
              value: '- ₹${couponDiscount.toStringAsFixed(0)}',
              valueColor: AppColors.primary,
            ),
          ],

          // Tip Delivery Partner
          const SizedBox(height: 14),
          const Text(
            'Tip your delivery partner',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _buildTipChip(0, 'None'),
              const SizedBox(width: 8),
              _buildTipChip(10, '₹10'),
              const SizedBox(width: 8),
              _buildTipChip(20, '₹20'),
              const SizedBox(width: 8),
              _buildTipChip(30, '₹30'),
            ],
          ),

          const SizedBox(height: 14),
          const Divider(height: 1, color: AppColors.border),
          const SizedBox(height: 12),

          // Grand Total
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'To Pay',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              Text(
                '₹${grandTotal.toStringAsFixed(0)}',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),

          // Total Savings Highlight
          if (totalSavings > 0) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
              decoration: BoxDecoration(
                color: AppColors.primaryLight,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  const Icon(Icons.savings_outlined, color: AppColors.primary, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'You are saving ₹${totalSavings.toStringAsFixed(0)} on this order!',
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTipChip(double amount, String label) {
    final isSelected = tipAmount == amount;
    return Expanded(
      child: InkWell(
        onTap: () => onTipSelected(amount),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primary : Colors.grey.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected ? AppColors.primary : AppColors.border,
              width: 1,
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: isSelected ? Colors.white : AppColors.textPrimary,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRow({
    required String label,
    required String value,
    String? strikeValue,
    Color valueColor = AppColors.textPrimary,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w500,
          ),
        ),
        Row(
          children: [
            if (strikeValue != null) ...[
              Text(
                strikeValue,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textMuted,
                  decoration: TextDecoration.lineThrough,
                ),
              ),
              const SizedBox(width: 6),
            ],
            Text(
              value,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: valueColor,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
