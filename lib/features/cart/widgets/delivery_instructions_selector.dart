import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../shared_widgets/qb_ui.dart';

/// Delivery instructions picker (PRD 4.8).
///
/// Mobile: a card with four square toggle tiles. Desktop ([chips] = true):
/// a wrap of pill toggles without the surrounding card.
class DeliveryInstructionsSelector extends StatelessWidget {
  final Set<String> selectedInstructions;
  final ValueChanged<String> onToggle;
  final bool chips;

  const DeliveryInstructionsSelector({
    super.key,
    required this.selectedInstructions,
    required this.onToggle,
    this.chips = false,
  });

  static const List<Map<String, dynamic>> options = [
    {'title': 'Leave at door', 'icon': Icons.door_front_door_outlined},
    {'title': 'Avoid calling', 'icon': Icons.phone_disabled_outlined},
    {'title': "Don't ring bell", 'icon': Icons.notifications_off_outlined},
    {'title': 'Pet at home', 'icon': Icons.pets_outlined},
  ];

  @override
  Widget build(BuildContext context) {
    if (chips) {
      return Wrap(
        spacing: 10,
        runSpacing: 10,
        children: options.map((opt) {
          final title = opt['title'] as String;
          final on = selectedInstructions.contains(title);
          return Material(
            color: on ? AppColors.primaryTint : Colors.white,
            shape: StadiumBorder(side: BorderSide(color: on ? AppColors.primary : AppColors.border, width: 1.5)),
            child: InkWell(
              customBorder: const StadiumBorder(),
              onTap: () => onToggle(title),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(opt['icon'] as IconData, size: 17, color: on ? AppColors.primaryDeep : AppColors.textBody),
                    const SizedBox(width: 8),
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: on ? AppColors.primaryDeep : AppColors.textBody,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      );
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: qbCard(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Delivery instructions', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
          const SizedBox(height: 10),
          Row(
            children: [
              for (var i = 0; i < options.length; i++) ...[
                if (i > 0) const SizedBox(width: 8),
                Expanded(child: _tile(options[i])),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _tile(Map<String, dynamic> opt) {
    final title = opt['title'] as String;
    final on = selectedInstructions.contains(title);
    final color = on ? AppColors.primaryDeep : AppColors.textBody;
    return Material(
      color: on ? AppColors.primaryTint : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: on ? AppColors.primary : const Color(0xFFE2E8E4), width: 1.5),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => onToggle(title),
        child: Container(
          constraints: const BoxConstraints(minHeight: 84),
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(opt['icon'] as IconData, size: 20, color: color),
              const SizedBox(height: 6),
              Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, height: 1.25, color: color),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
