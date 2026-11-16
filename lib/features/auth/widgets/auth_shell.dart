import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../shared_widgets/qb_ui.dart';

/// Shared layout for the customer sign-in flow.
///
/// Phones: green brand hero on top with a rounded white sheet holding the
/// form. Wide screens: brand panel on the left, form on the right.
class AuthShell extends StatelessWidget {
  final Widget child;
  final VoidCallback? onBack;

  const AuthShell({super.key, required this.child, this.onBack});

  @override
  Widget build(BuildContext context) {
    final wide = Responsive.width(context) >= Responsive.desktop;

    final footer = const Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.verified_user_outlined, size: 16, color: AppColors.primary),
        SizedBox(width: 8),
        Flexible(
          child: Text(
            'Secure login · No password needed',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
        ),
      ],
    );

    if (wide) {
      return Scaffold(
        backgroundColor: Colors.white,
        body: Row(
          children: [
            const Expanded(child: _BrandHero(large: true)),
            Expanded(
              child: Stack(
                children: [
                  Center(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(48),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 420),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [child, const SizedBox(height: 28), footer],
                        ),
                      ),
                    ),
                  ),
                  if (onBack != null)
                    Positioned(
                      top: 20,
                      left: 20,
                      child: IconButton.outlined(
                        tooltip: 'Back',
                        onPressed: onBack,
                        icon: const Icon(Icons.chevron_left_rounded),
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
      backgroundColor: AppColors.primary,
      body: SafeArea(
        bottom: false,
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: IntrinsicHeight(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Stack(
                      children: [
                        const SizedBox(height: 340, child: _BrandHero()),
                        if (onBack != null)
                          Positioned(
                            top: 8,
                            left: 8,
                            child: IconButton(
                              tooltip: 'Back',
                              onPressed: onBack,
                              icon: const Icon(Icons.chevron_left_rounded, color: Colors.white, size: 30),
                            ),
                          ),
                      ],
                    ),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.fromLTRB(22, 28, 22, 24),
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                        ),
                        child: Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 460),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [child, const Spacer(), const SizedBox(height: 24), footer],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BrandHero extends StatelessWidget {
  final bool large;
  const _BrandHero({this.large = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.primary,
      child: Stack(
        clipBehavior: Clip.hardEdge,
        children: [
          Positioned(
            top: -140,
            right: -150,
            child: Container(width: 360, height: 360, decoration: const BoxDecoration(color: Color(0xFF0A7438), shape: BoxShape.circle)),
          ),
          Positioned(
            bottom: -110,
            left: -80,
            child: Container(width: 220, height: 220, decoration: const BoxDecoration(color: Color(0xFF0A7438), shape: BoxShape.circle)),
          ),
          Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: large ? 96 : 84,
                    height: large ? 96 : 84,
                    decoration: BoxDecoration(
                      color: AppColors.accent,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 30, offset: Offset(0, 14))],
                    ),
                    child: Icon(Icons.shopping_basket_outlined, size: large ? 52 : 46, color: AppColors.primaryDark),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'quick basket',
                    style: TextStyle(color: Colors.white, fontSize: large ? 38 : 30, fontWeight: FontWeight.w800, letterSpacing: -1),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Groceries & essentials in 10–15 minutes',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: large ? 16 : 14),
                  ),
                  const SizedBox(height: 18),
                  const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _HeroChip(Icons.bolt_rounded, '12-min delivery', AppColors.accent),
                      SizedBox(width: 8),
                      _HeroChip(Icons.eco_outlined, 'Farm fresh', Colors.white),
                    ],
                  ),
                ],
              ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color iconColor;
  const _HeroChip(this.icon, this.label, this.iconColor);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(999)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: iconColor),
          const SizedBox(width: 5),
          Text(label, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

/// Inline error banner for auth forms.
class AuthError extends StatelessWidget {
  final String message;
  const AuthError(this.message, {super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
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
          Expanded(child: Text(message, style: const TextStyle(color: AppColors.error, fontSize: 13, fontWeight: FontWeight.w600))),
        ],
      ),
    );
  }
}
