import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/config/delivery_config.dart';
import '../../../models/order_model.dart';
import '../../../shared_widgets/qb_ui.dart';
import 'rider_helpers.dart';

final double _perDelivery = DeliveryConfig.defaultPerDeliveryEarning;

/// Shared building blocks for the Delivery Partner app (Quick Basket branding).

const double kRiderGutter = 16;

/// Card with the Quick Basket hairline border.
class RCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color color;
  final Color borderColor;
  final VoidCallback? onTap;
  final double radius;

  const RCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.color = Colors.white,
    this.borderColor = AppColors.border,
    this.onTap,
    this.radius = 18,
  });

  @override
  Widget build(BuildContext context) {
    // A Material surface (not a DecoratedBox) so ListTiles / ink splashes
    // inside the card paint correctly.
    final body = Padding(padding: padding, child: child);
    return Material(
      color: color,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radius),
        side: BorderSide(color: borderColor),
      ),
      child: onTap == null ? body : InkWell(onTap: onTap, child: body),
    );
  }
}

class RSectionTitle extends StatelessWidget {
  final String title;
  final String? action;
  final VoidCallback? onAction;
  const RSectionTitle(this.title, {super.key, this.action, this.onAction});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 20, bottom: 10),
      child: Row(
        children: [
          Expanded(
            child: Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
          ),
          if (action != null)
            GestureDetector(
              onTap: onAction,
              child: Text(action!, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.primary)),
            ),
        ],
      ),
    );
  }
}

class RPrimaryButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final Color color;
  final Color foreground;

  const RPrimaryButton({
    super.key,
    required this.label,
    this.icon,
    this.onPressed,
    this.color = AppColors.primary,
    this.foreground = Colors.white,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: icon != null ? Icon(icon, size: 20) : const SizedBox.shrink(),
        label: Text(label, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: foreground,
          disabledBackgroundColor: AppColors.borderStrong,
          disabledForegroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
    );
  }
}

class ROutlineButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final Color color;

  const ROutlineButton({super.key, required this.label, this.icon, this.onPressed, this.color = AppColors.textPrimary});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: icon != null ? Icon(icon, size: 19) : const SizedBox.shrink(),
        label: Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
        style: OutlinedButton.styleFrom(
          foregroundColor: color,
          side: BorderSide(color: color == AppColors.textPrimary ? AppColors.borderStrong : color.withValues(alpha: 0.5), width: 1.4),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
    );
  }
}

/// Round icon action (call / chat / navigate).
class RRoundAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final Color color;
  final Color background;
  const RRoundAction({
    super.key,
    required this.icon,
    required this.label,
    this.onTap,
    this.color = AppColors.primaryDeep,
    this.background = AppColors.primaryLight,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(14)),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(height: 5),
            Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textBody)),
          ],
        ),
      ),
    );
  }
}

class RInfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color iconColor;
  const RInfoRow({super.key, required this.icon, required this.label, required this.value, this.iconColor = AppColors.textSecondary});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 19, color: iconColor),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 11.5, color: AppColors.textMuted, fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(value, style: const TextStyle(fontSize: 14, color: AppColors.textPrimary, fontWeight: FontWeight.w700)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Status chip styled for rider delivery states.
class RStatusPill extends StatelessWidget {
  final OrderModel order;
  const RStatusPill(this.order, {super.key});

  @override
  Widget build(BuildContext context) {
    final (label, bg, fg) = switch (RiderFormat.stageOf(order)) {
      'assigned' => ('New request', AppColors.accentLight, AppColors.accentInk),
      'accepted' => ('Heading to store', AppColors.infoLight, AppColors.info),
      'reached_store' => ('At store', AppColors.infoLight, AppColors.info),
      'picked_up' => ('Picked up', AppColors.primaryLight, AppColors.primaryDeep),
      'out_for_delivery' => ('On the way', AppColors.secondaryLight, const Color(0xFFB45309)),
      'issue_reported' => ('Issue reported', AppColors.errorLight, AppColors.error),
      'delivered' => ('Delivered', AppColors.primaryLight, AppColors.primaryDeep),
      _ => ('Cancelled', AppColors.errorLight, AppColors.error),
    };
    return QbPill(label: label, background: bg, foreground: fg, dot: true);
  }
}

/// Horizontal delivery progress: Accepted → At store → Picked up → Delivered.
class RDeliveryStepper extends StatelessWidget {
  /// 0 = accepted, 1 = at store, 2 = picked up / on the way, 3 = delivered.
  final int step;
  const RDeliveryStepper({super.key, required this.step});

  static const _labels = ['Accepted', 'At store', 'On the way', 'Delivered'];

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(_labels.length * 2 - 1, (i) {
        if (i.isOdd) {
          final done = (i ~/ 2) < step;
          return Expanded(
            child: Container(
              height: 3,
              margin: const EdgeInsets.only(bottom: 18),
              color: done ? AppColors.primary : AppColors.border,
            ),
          );
        }
        final idx = i ~/ 2;
        final done = idx < step;
        final current = idx == step;
        return SizedBox(
          width: 62,
          child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: done ? AppColors.primary : (current ? Colors.white : AppColors.surfaceMuted),
                border: Border.all(color: done || current ? AppColors.primary : AppColors.borderStrong, width: 2),
              ),
              child: done
                  ? const Icon(Icons.check_rounded, size: 14, color: Colors.white)
                  : current
                      ? Center(child: Container(width: 8, height: 8, decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle)))
                      : null,
            ),
            const SizedBox(height: 4),
            Text(
              _labels[idx],
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 10,
                fontWeight: current ? FontWeight.w800 : FontWeight.w600,
                color: done || current ? AppColors.textPrimary : AppColors.textMuted,
              ),
            ),
          ],
          ),
        );
      }),
    );
  }
}

/// Swipe-to-confirm control used for irreversible delivery steps.
class RSlideToConfirm extends StatefulWidget {
  final String label;
  final VoidCallback onConfirmed;
  final Color color;
  final bool enabled;

  const RSlideToConfirm({
    super.key,
    required this.label,
    required this.onConfirmed,
    this.color = AppColors.primary,
    this.enabled = true,
  });

  @override
  State<RSlideToConfirm> createState() => _RSlideToConfirmState();
}

class _RSlideToConfirmState extends State<RSlideToConfirm> {
  double _dx = 0;
  static const double _thumb = 48;

  @override
  Widget build(BuildContext context) {
    final color = widget.enabled ? widget.color : AppColors.borderStrong;
    return LayoutBuilder(builder: (context, c) {
      final maxDx = c.maxWidth - _thumb - 8;
      return Container(
        height: 56,
        decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(16)),
        child: Stack(
          alignment: Alignment.centerLeft,
          children: [
            Center(
              child: Padding(
                padding: const EdgeInsets.only(left: 40),
                child: Text(
                  widget.label,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: (1 - _dx / (maxDx <= 0 ? 1 : maxDx)).clamp(0.2, 1)),
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                ),
              ),
            ),
            Positioned(
              left: 4 + _dx,
              child: GestureDetector(
                onHorizontalDragUpdate: widget.enabled
                    ? (d) => setState(() => _dx = (_dx + d.delta.dx).clamp(0, maxDx))
                    : null,
                onHorizontalDragEnd: widget.enabled
                    ? (_) {
                        if (_dx > maxDx * 0.8) {
                          setState(() => _dx = maxDx);
                          widget.onConfirmed();
                        }
                        setState(() => _dx = 0);
                      }
                    : null,
                onTap: widget.enabled ? widget.onConfirmed : null, // tap fallback for desktop review
                child: Container(
                  width: _thumb,
                  height: _thumb,
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(13)),
                  child: Icon(Icons.double_arrow_rounded, color: color),
                ),
              ),
            ),
          ],
        ),
      );
    });
  }
}

/// Schematic route illustration (store → customer). Live turn-by-turn
/// navigation opens in Google Maps via [RiderIntents.navigate].
class RRouteMap extends StatelessWidget {
  final double height;
  final bool toStore;
  final double radius;
  final Widget? overlay;
  const RRouteMap({super.key, this.height = 180, this.toStore = false, this.radius = 18, this.overlay});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: SizedBox(
        height: height,
        width: double.infinity,
        child: Stack(
          children: [
            Positioned.fill(child: CustomPaint(painter: _MapPainter(toStore: toStore))),
            if (overlay != null) Positioned.fill(child: overlay!),
          ],
        ),
      ),
    );
  }
}

class _MapPainter extends CustomPainter {
  final bool toStore;
  _MapPainter({required this.toStore});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    canvas.drawRect(Offset.zero & size, Paint()..color = const Color(0xFFEDF1EC));

    // Blocks
    final block = Paint()..color = const Color(0xFFE1E8E0);
    for (double x = 8; x < w; x += 74) {
      for (double y = 8; y < h; y += 58) {
        canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(x, y, 60, 44), const Radius.circular(6)), block);
      }
    }
    // Park + lake
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(w * 0.62, h * 0.08, 70, 46), const Radius.circular(10)),
        Paint()..color = const Color(0xFFCDE8CF));
    canvas.drawOval(Rect.fromLTWH(w * 0.08, h * 0.62, 60, 34), Paint()..color = const Color(0xFFCFE3F1));

    // Main roads
    final road = Paint()
      ..color = Colors.white
      ..strokeWidth = 9
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(0, h * 0.5), Offset(w, h * 0.42), road);
    canvas.drawLine(Offset(w * 0.32, 0), Offset(w * 0.38, h), road);
    canvas.drawLine(Offset(w * 0.75, 0), Offset(w * 0.7, h), road);

    final store = Offset(w * 0.18, h * 0.74);
    final customer = Offset(w * 0.82, h * 0.22);
    final rider = toStore ? Offset(w * 0.5, h * 0.88) : Offset(w * 0.55, h * 0.46);

    // Route
    final route = Path()
      ..moveTo(store.dx, store.dy)
      ..lineTo(w * 0.36, h * 0.74)
      ..lineTo(w * 0.36, h * 0.47)
      ..lineTo(w * 0.72, h * 0.43)
      ..lineTo(w * 0.73, customer.dy)
      ..lineTo(customer.dx, customer.dy);
    final routePaint = Paint()
      ..color = AppColors.primary
      ..strokeWidth = 5
      ..style = PaintingStyle.stroke
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round;
    if (toStore) {
      final p = Path()
        ..moveTo(rider.dx, rider.dy)
        ..lineTo(w * 0.37, h * 0.88)
        ..lineTo(w * 0.36, h * 0.74)
        ..lineTo(store.dx, store.dy);
      canvas.drawPath(p, routePaint..color = AppColors.info);
    } else {
      canvas.drawPath(route, routePaint);
    }

    _pin(canvas, store, AppColors.primaryDark, Icons.storefront_rounded);
    _pin(canvas, customer, const Color(0xFFE65100), Icons.home_rounded);

    // Rider dot
    canvas.drawCircle(rider, 14, Paint()..color = AppColors.accent.withValues(alpha: 0.35));
    canvas.drawCircle(rider, 8, Paint()..color = Colors.white);
    canvas.drawCircle(rider, 6, Paint()..color = AppColors.primaryDark);
  }

  void _pin(Canvas canvas, Offset at, Color color, IconData icon) {
    canvas.drawCircle(at.translate(0, 2), 15, Paint()..color = Colors.black.withValues(alpha: 0.12));
    canvas.drawCircle(at, 15, Paint()..color = color);
    final tp = TextPainter(
      text: TextSpan(
        text: String.fromCharCode(icon.codePoint),
        style: TextStyle(fontSize: 17, fontFamily: icon.fontFamily, package: icon.fontPackage, color: Colors.white),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, at - Offset(tp.width / 2, tp.height / 2));
  }

  @override
  bool shouldRepaint(covariant _MapPainter old) => old.toStore != toStore;
}

/// Small stat tile used on dashboard / earnings.
class RStatTile extends StatelessWidget {
  final String value;
  final String label;
  final IconData icon;
  final Color tint;
  final Color ink;
  final VoidCallback? onTap;

  const RStatTile({
    super.key,
    required this.value,
    required this.label,
    required this.icon,
    this.tint = AppColors.primaryLight,
    this.ink = AppColors.primaryDeep,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return RCard(
      onTap: onTap,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(color: tint, borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, size: 18, color: ink),
          ),
          const SizedBox(height: 10),
          Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: AppColors.textPrimary, letterSpacing: -0.4)),
          const SizedBox(height: 2),
          Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

/// Compact delivery row used in lists.
class RDeliveryTile extends StatelessWidget {
  final OrderModel order;
  final String timeLabel;
  final VoidCallback? onTap;
  const RDeliveryTile(this.order, {super.key, required this.timeLabel, this.onTap});

  @override
  Widget build(BuildContext context) {
    final d = order;
    final earned = d.status == OrderStatus.delivered ? d.tipAmount + _perDelivery : 0.0;
    final count = d.items.fold<int>(0, (s, i) => s + i.quantity);
    return RCard(
      onTap: onTap,
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(color: AppColors.surfaceMuted, borderRadius: BorderRadius.circular(12)),
            child: const Icon(Icons.shopping_bag_outlined, color: AppColors.textBody),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(child: Text(d.orderNumber, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14))),
                    const SizedBox(width: 8),
                    Flexible(child: RStatusPill(d)),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  [RiderFormat.area(d), if (RiderFormat.dropKm(d) != null) RiderFormat.km(RiderFormat.dropKm(d)), if (count > 0) '$count items'].join(' · '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 2),
                Text(timeLabel, style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                earned > 0 ? qbRupees(earned) : '—',
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 15,
                  color: earned > 0 ? AppColors.primaryDeep : AppColors.textMuted,
                ),
              ),
              const SizedBox(height: 2),
              const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted, size: 20),
            ],
          ),
        ],
      ),
    );
  }
}

/// Bottom-docked action area with safe padding.
class RBottomBar extends StatelessWidget {
  final List<Widget> children;
  const RBottomBar({super.key, required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(16, 12, 16, 12 + MediaQuery.paddingOf(context).bottom),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: children),
    );
  }
}

/// On wide screens (tablet / desktop browser) keeps the rider app at phone
/// width, centred, instead of stretching cards edge to edge.
class RiderFrame extends StatelessWidget {
  final Widget child;
  const RiderFrame({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    if (size.width <= 520) return child;
    return ColoredBox(
      color: AppColors.primaryDark,
      child: Center(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(size.height > 760 ? 20 : 0),
          child: SizedBox(
            width: 440,
            height: size.height > 760 ? size.height - 32 : size.height,
            child: MediaQuery(
              data: MediaQuery.of(context).copyWith(size: Size(440, size.height > 760 ? size.height - 32 : size.height)),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}
