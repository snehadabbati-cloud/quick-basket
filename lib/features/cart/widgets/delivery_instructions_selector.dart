import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';

class DeliveryInstructionsSelector extends StatelessWidget {
  final Set<String> selectedInstructions;
  final ValueChanged<String> onToggle;

  const DeliveryInstructionsSelector({
    super.key,
    required this.selectedInstructions,
    required this.onToggle,
  });

  static const List<Map<String, dynamic>> _options = [
    {
      'title': 'Leave at door',
      'icon': Icons.meeting_room_outlined,
    },
    {
      'title': 'Avoid calling',
      'icon': Icons.phone_disabled_outlined,
    },
    {
      'title': "Don't ring bell",
      'icon': Icons.notifications_off_outlined,
    },
    {
      'title': 'Pet at home',
      'icon': Icons.pets_outlined,
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border, width: 0.8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.directions_bike_rounded, size: 18, color: AppColors.primary),
              SizedBox(width: 8),
              Text(
                'Delivery Instructions',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 72,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _options.length,
              separatorBuilder: (context, index) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final opt = _options[index];
                final title = opt['title'] as String;
                final icon = opt['icon'] as IconData;
                final isSelected = selectedInstructions.contains(title);

                return InkWell(
                  onTap: () => onToggle(title),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    width: 104,
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    decoration: BoxDecoration(
                      color: isSelected ? AppColors.primaryLight : Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected ? AppColors.primary : AppColors.border,
                        width: isSelected ? 1.5 : 0.8,
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          icon,
                          size: 20,
                          color: isSelected ? AppColors.primary : AppColors.textSecondary,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          title,
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                            color: isSelected ? AppColors.primary : AppColors.textSecondary,
                            height: 1.1,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
