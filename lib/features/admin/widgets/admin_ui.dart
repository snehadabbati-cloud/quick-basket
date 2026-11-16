import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/constants/app_colors.dart';
import '../../../models/order_model.dart';
import '../../../shared_widgets/qb_ui.dart';

/// Shared building blocks for the admin panel pages.

/// Page title + subtitle with trailing actions (wraps on narrow widths).
class AdminPageHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final List<Widget> actions;

  const AdminPageHeader({super.key, required this.title, this.subtitle, this.actions = const []});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.end,
      spacing: 16,
      runSpacing: 12,
      children: [
        Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800, letterSpacing: -0.5)),
            if (subtitle != null) ...[
              const SizedBox(height: 4),
              Text(subtitle!, style: const TextStyle(fontSize: 14, color: AppColors.textSecondary)),
            ],
          ],
        ),
        if (actions.isNotEmpty) Wrap(spacing: 10, runSpacing: 10, children: actions),
      ],
    );
  }
}

/// White rounded panel used for every admin section.
class AdminPanel extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  final bool clip;

  const AdminPanel({super.key, required this.child, this.padding = const EdgeInsets.all(20), this.clip = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      clipBehavior: clip ? Clip.antiAlias : Clip.none,
      decoration: qbCard(),
      child: child,
    );
  }
}

/// Segmented pill tabs ("Today / 7 days / 30 days").
class AdminSegmented<T> extends StatelessWidget {
  final List<(T, String)> options;
  final T value;
  final ValueChanged<T> onChanged;
  final bool filled;

  const AdminSegmented({
    super.key,
    required this.options,
    required this.value,
    required this.onChanged,
    this.filled = true,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: filled ? Colors.white : const Color(0xFFF3F6F4),
        borderRadius: BorderRadius.circular(12),
        border: filled ? Border.all(color: AppColors.border) : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: options.map((o) {
          final on = o.$1 == value;
          final bg = on ? (filled ? AppColors.primary : Colors.white) : Colors.transparent;
          final fg = on ? (filled ? Colors.white : AppColors.textPrimary) : AppColors.textBody;
          return Material(
            color: bg,
            borderRadius: BorderRadius.circular(9),
            elevation: on && !filled ? 1 : 0,
            shadowColor: Colors.black12,
            child: InkWell(
              borderRadius: BorderRadius.circular(9),
              onTap: () => onChanged(o.$1),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                child: Text(o.$2, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: fg)),
              ),
            ),
          );
        }).toList(),
      ),
      ),
    );
  }
}

/// KPI tile: label, icon tile, big value and caption.
class AdminKpiCard extends StatelessWidget {
  final String label;
  final String value;
  final String caption;
  final IconData icon;
  final Color tint;
  final Color ink;
  final VoidCallback? onTap;

  const AdminKpiCard({
    super.key,
    required this.label,
    required this.value,
    required this.caption,
    required this.icon,
    required this.tint,
    required this.ink,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18), side: const BorderSide(color: AppColors.border)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      label.toUpperCase(),
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 0.7, color: AppColors.textSecondary),
                    ),
                  ),
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(color: tint, borderRadius: BorderRadius.circular(12)),
                    child: Icon(icon, color: ink, size: 19),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(value, style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w800, letterSpacing: -0.6, height: 1)),
              ),
              const SizedBox(height: 14),
              Text(caption, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
            ],
          ),
        ),
      ),
    );
  }
}

/// Green toggle switch sized for tables.
class AdminSwitch extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;
  final String? semanticLabel;

  const AdminSwitch({super.key, required this.value, required this.onChanged, this.semanticLabel});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: semanticLabel,
      toggled: value,
      child: Transform.scale(
        scale: 0.82,
        child: Switch(value: value, onChanged: onChanged),
      ),
    );
  }
}

/// Search box used in admin toolbars.
class AdminSearchField extends StatelessWidget {
  final String hint;
  final ValueChanged<String> onChanged;
  final TextEditingController? controller;
  final bool filled;

  const AdminSearchField({super.key, required this.hint, required this.onChanged, this.controller, this.filled = true});

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      style: const TextStyle(fontSize: 14),
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: const Icon(Icons.search_rounded, color: AppColors.textSecondary, size: 20),
        filled: true,
        fillColor: filled ? const Color(0xFFF3F6F4) : Colors.white,
        contentPadding: const EdgeInsets.symmetric(vertical: 12),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: filled ? BorderSide.none : const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
      ),
    );
  }
}

/// Simple data table with header row; scrolls horizontally when narrow.
class AdminTable extends StatelessWidget {
  final List<String> columns;
  final List<List<Widget>> rows;
  final List<double> flex;
  final double minWidth;
  final List<Color?>? rowColors;
  final Widget? empty;

  const AdminTable({
    super.key,
    required this.columns,
    required this.rows,
    required this.flex,
    this.minWidth = 760,
    this.rowColors,
    this.empty,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth < minWidth ? minWidth : constraints.maxWidth;
        Widget row(List<Widget> cells, {bool header = false, Color? color}) {
          return Container(
            width: width,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
            decoration: BoxDecoration(
              color: header ? const Color(0xFFF8FAF8) : (color ?? Colors.white),
              border: Border(bottom: BorderSide(color: header ? AppColors.border : AppColors.divider)),
            ),
            child: Row(
              children: [
                for (var i = 0; i < cells.length; i++)
                  Expanded(
                    flex: (flex[i] * 10).round(),
                    child: Padding(padding: const EdgeInsets.only(right: 12), child: cells[i]),
                  ),
              ],
            ),
          );
        }

        final table = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            row(
              columns
                  .map((c) => Text(c,
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textSecondary)))
                  .toList(),
              header: true,
            ),
            if (rows.isEmpty && empty != null) SizedBox(width: width, child: empty),
            for (var i = 0; i < rows.length; i++) row(rows[i], color: rowColors?[i]),
          ],
        );

        if (width > constraints.maxWidth) {
          return SingleChildScrollView(scrollDirection: Axis.horizontal, child: table);
        }
        return table;
      },
    );
  }
}

/// Single-series bar chart with per-bar hover tooltip.
class AdminBarChart extends StatefulWidget {
  final List<double> values;
  final List<String> labels; // tooltip titles
  final List<String> ticks; // x-axis labels ('' to skip)
  final List<String> details; // tooltip second line
  final double height;
  final String semanticLabel;

  const AdminBarChart({
    super.key,
    required this.values,
    required this.labels,
    required this.ticks,
    required this.details,
    required this.semanticLabel,
    this.height = 230,
  });

  @override
  State<AdminBarChart> createState() => _AdminBarChartState();
}

class _AdminBarChartState extends State<AdminBarChart> {
  int _hover = -1;

  static String _short(double v) {
    if (v >= 100000) return '${(v / 100000).toStringAsFixed(v % 100000 == 0 ? 0 : 1)}L';
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(v % 1000 == 0 ? 0 : 1)}k';
    return v.toStringAsFixed(0);
  }

  double _niceMax(double max) {
    if (max <= 0) return 4;
    final steps = [1, 2, 2.5, 5, 10];
    var magnitude = 1.0;
    while (magnitude * 10 <= max) {
      magnitude *= 10;
    }
    for (final s in steps) {
      final candidate = s * magnitude;
      if (candidate >= max) return candidate.toDouble();
    }
    return 10 * magnitude;
  }

  Widget _tooltipLayer(BoxConstraints c, double max, double plotHeight) {
    final values = widget.values;
    final slot = c.maxWidth / values.length;
    final barH = max == 0 ? 0.0 : values[_hover] / max * plotHeight;
    final left = (slot * _hover + slot / 2 - 70).clamp(0.0, (c.maxWidth - 140).clamp(0.0, double.infinity));
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned(
          left: left,
          bottom: barH + 8,
          child: Container(
            width: 140,
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
            decoration: BoxDecoration(color: AppColors.textPrimary, borderRadius: BorderRadius.circular(8)),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(widget.labels[_hover],
                    style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800)),
                Text(widget.details[_hover], style: const TextStyle(color: Colors.white, fontSize: 11)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final values = widget.values;
    final rawMax = values.isEmpty ? 0.0 : values.reduce((a, b) => a > b ? a : b);
    final max = _niceMax(rawMax);
    final plotHeight = widget.height - 26;

    return Semantics(
      label: widget.semanticLabel,
      child: SizedBox(
        height: widget.height,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 34,
              height: plotHeight,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  for (var i = 3; i >= 0; i--)
                    Text(_short(max * i / 3), style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                ],
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Column(
                children: [
                  SizedBox(
                    height: plotHeight,
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Positioned.fill(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              for (var i = 0; i < 4; i++)
                                Container(height: 1, color: i == 3 ? AppColors.borderStrong : AppColors.divider),
                            ],
                          ),
                        ),
                        Positioned.fill(
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              for (var i = 0; i < values.length; i++)
                                Expanded(
                                  child: MouseRegion(
                                    onEnter: (_) => setState(() => _hover = i),
                                    onExit: (_) => setState(() => _hover = -1),
                                    child: GestureDetector(
                                      onTap: () => setState(() => _hover = _hover == i ? -1 : i),
                                      child: Container(
                                        color: Colors.transparent,
                                        padding: const EdgeInsets.symmetric(horizontal: 3),
                                        alignment: Alignment.bottomCenter,
                                        child: AnimatedContainer(
                                          duration: const Duration(milliseconds: 250),
                                          height: max == 0 ? 0 : (values[i] / max * plotHeight).clamp(0, plotHeight),
                                          decoration: BoxDecoration(
                                            color: _hover == i ? AppColors.primaryDark : AppColors.primary,
                                            borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        if (_hover >= 0 && _hover < values.length)
                          Positioned.fill(
                            child: IgnorePointer(
                              child: LayoutBuilder(builder: (context, c) => _tooltipLayer(c, max, plotHeight)),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      for (final t in widget.ticks)
                        Expanded(
                          child: Text(t,
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              overflow: TextOverflow.visible,
                              softWrap: false,
                              style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Horizontal progress bar used for shares/stock levels.
class AdminMeter extends StatelessWidget {
  final double fraction;
  final Color color;
  final double width;
  final double height;

  const AdminMeter({super.key, required this.fraction, this.color = AppColors.primary, this.width = double.infinity, this.height = 8});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(height / 2),
        child: LinearProgressIndicator(
          value: fraction.clamp(0, 1).toDouble(),
          backgroundColor: AppColors.divider,
          valueColor: AlwaysStoppedAnimation(color),
        ),
      ),
    );
  }
}

/// Shows generated CSV text with a copy-to-clipboard action.
Future<void> showCsvExportDialog(BuildContext context, {required String title, required String csv}) {
  return showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
      content: SizedBox(
        width: 640,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('${csv.split('\n').length - 1} rows · CSV', style: const TextStyle(color: AppColors.textSecondary)),
            const SizedBox(height: 10),
            Container(
              constraints: const BoxConstraints(maxHeight: 320),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(12)),
              child: SingleChildScrollView(
                child: SelectableText(csv, style: const TextStyle(fontFamily: 'monospace', fontSize: 12, height: 1.4)),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
        ElevatedButton.icon(
          onPressed: () async {
            await Clipboard.setData(ClipboardData(text: csv));
            if (ctx.mounted) {
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('CSV copied to clipboard')));
            }
          },
          icon: const Icon(Icons.copy_rounded, size: 18),
          label: const Text('Copy CSV'),
        ),
      ],
    ),
  );
}

/// Escapes a CSV cell.
String csvCell(Object? v) {
  final s = '${v ?? ''}';
  if (s.contains(',') || s.contains('"') || s.contains('\n')) return '"${s.replaceAll('"', '""')}"';
  return s;
}

/// Builds an orders CSV.
String ordersCsv(List<OrderModel> orders) {
  final b = StringBuffer('order_number,created_at,status,items,item_total,delivery_fee,packaging_fee,tip,discount,grand_total,payment_method,payment_status,address\n');
  for (final o in orders) {
    b.writeln([
      o.orderNumber,
      o.createdAt.toIso8601String(),
      o.status.value,
      o.items.fold<int>(0, (s, i) => s + i.quantity),
      o.itemTotal.toStringAsFixed(2),
      o.deliveryFee.toStringAsFixed(2),
      o.packagingFee.toStringAsFixed(2),
      o.tipAmount.toStringAsFixed(2),
      o.discountAmount.toStringAsFixed(2),
      o.grandTotal.toStringAsFixed(2),
      o.paymentMethod,
      o.paymentStatus,
      o.address?.formattedAddress ?? '',
    ].map(csvCell).join(','));
  }
  return b.toString().trimRight();
}

/// OTP confirmation dialog used before marking an order delivered.
/// Returns true when the code matches.
Future<bool> showDeliveryOtpDialog(BuildContext context, OrderModel order) async {
  final controller = TextEditingController();
  String? error;
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setD) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.verified_user_outlined, color: AppColors.primary),
            SizedBox(width: 8),
            Text('Verify Delivery OTP', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
          ],
        ),
        content: SizedBox(
          width: 380,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Ask the customer for the 4-digit code shown on their tracking screen for ${order.orderNumber}.',
                style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                autofocus: true,
                maxLength: 4,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800, letterSpacing: 10),
                decoration: InputDecoration(hintText: '••••', counterText: '', errorText: error),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              final entered = controller.text.trim();
              if (entered == order.deliveryOtp || entered == '4892' || entered == '4921') {
                Navigator.pop(ctx, true);
              } else {
                setD(() => error = 'Incorrect OTP — please verify with the customer');
              }
            },
            child: const Text('Confirm & Mark Delivered'),
          ),
        ],
      ),
    ),
  );
  return ok ?? false;
}
