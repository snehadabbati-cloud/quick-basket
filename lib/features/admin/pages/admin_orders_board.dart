import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../models/order_model.dart';
import '../../../shared_widgets/qb_ui.dart';
import '../widgets/admin_orders_logic.dart';
import '../widgets/admin_ui.dart';

/// Live order board: four fulfilment stages with clear action feedback.
class AdminOrdersBoard extends StatefulWidget {
  final List<OrderModel> orders;
  final bool isLoading;
  final String search;
  final String Function(OrderModel) customerName;
  final AdminOrderAction? lastAction;
  final Future<void> Function(OrderModel) onAdvance;
  final Future<void> Function(OrderModel) onReject;
  final VoidCallback onUndo;
  final VoidCallback onDismiss;
  final ValueChanged<OrderModel> onOpenDetails;
  final VoidCallback onClearSearch;

  const AdminOrdersBoard({
    super.key,
    required this.orders,
    required this.isLoading,
    required this.search,
    required this.customerName,
    required this.lastAction,
    required this.onAdvance,
    required this.onReject,
    required this.onUndo,
    required this.onDismiss,
    required this.onOpenDetails,
    required this.onClearSearch,
  });

  @override
  State<AdminOrdersBoard> createState() => _AdminOrdersBoardState();
}

class _AdminOrdersBoardState extends State<AdminOrdersBoard> {
  String _payment = 'all';
  bool _newestFirst = false;
  bool _arrivalDismissed = false;
  final Set<String> _busy = {};

  static const _stageColors = {
    OrderStatus.placed: AppColors.accent,
    OrderStatus.confirmed: AppColors.purple,
    OrderStatus.packing: AppColors.indigo,
    OrderStatus.outForDelivery: AppColors.primary,
  };

  static const _hints = {
    OrderStatus.placed: 'Accept within 2 minutes',
    OrderStatus.confirmed: 'Ready to pick from shelves',
    OrderStatus.packing: 'Hand over once bagged',
    OrderStatus.outForDelivery: 'Verify the customer OTP at the door',
  };

  static const _emptyText = {
    OrderStatus.placed: 'No new orders waiting',
    OrderStatus.confirmed: 'Nothing waiting to be picked',
    OrderStatus.packing: 'Packing floor is clear',
    OrderStatus.outForDelivery: 'No riders on the road',
  };

  List<OrderModel> get _visible {
    var list = widget.orders.toList();
    if (_payment != 'all') list = list.where((o) => o.paymentMethod == _payment).toList();
    final q = widget.search.trim().toLowerCase();
    if (q.isNotEmpty) {
      list = list.where((o) {
        return o.orderNumber.toLowerCase().contains(q) ||
            widget.customerName(o).toLowerCase().contains(q) ||
            o.userId.toLowerCase().contains(q) ||
            (o.address?.formattedAddress.toLowerCase().contains(q) ?? false) ||
            o.items.any((i) => i.product.name.toLowerCase().contains(q));
      }).toList();
    }
    list.sort((a, b) => _newestFirst ? b.createdAt.compareTo(a.createdAt) : a.createdAt.compareTo(b.createdAt));
    return list;
  }

  Future<void> _run(OrderModel o, Future<void> Function(OrderModel) action) async {
    setState(() => _busy.add(o.id));
    try {
      await action(o);
    } finally {
      if (mounted) setState(() => _busy.remove(o.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final orders = _visible;
    final active = orders.where((o) => OrderFlow.isActive(o.status)).length;
    final now = DateTime.now();
    bool today(OrderModel o) => o.createdAt.year == now.year && o.createdAt.month == now.month && o.createdAt.day == now.day;
    var done = orders.where((o) => !OrderFlow.isActive(o.status) && today(o)).toList();
    final doneLabel = done.isEmpty ? 'Recently completed' : 'Completed today';
    if (done.isEmpty) done = orders.where((o) => !OrderFlow.isActive(o.status)).take(8).toList();

    return ListView(
      padding: EdgeInsets.fromLTRB(Responsive.isMobile(context) ? 16 : 32, 24, Responsive.isMobile(context) ? 16 : 32, 40),
      children: [
        AdminPageHeader(
          title: 'Live Orders',
          subtitle: '$active active orders · ${orders.where((o) => !OrderFlow.isActive(o.status) && today(o)).length} completed today',
          actions: [
            _dropdown<String>(
              value: _payment,
              icon: Icons.tune_rounded,
              items: const [('all', 'All payments'), ('upi', 'UPI / Card'), ('cod', 'Cash on delivery')],
              onChanged: (v) => setState(() => _payment = v),
            ),
            _dropdown<bool>(
              value: _newestFirst,
              icon: Icons.swap_vert_rounded,
              items: const [(false, 'Oldest first'), (true, 'Newest first')],
              onChanged: (v) => setState(() => _newestFirst = v),
            ),
          ],
        ),
        const SizedBox(height: 18),
        if (widget.search.isNotEmpty) ...[
          Row(
            children: [
              QbPill(
                label: 'Results for “${widget.search}”',
                icon: Icons.search_rounded,
                background: AppColors.surfaceMuted,
                foreground: AppColors.textBody,
                fontSize: 12,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              ),
              const SizedBox(width: 8),
              TextButton(onPressed: widget.onClearSearch, child: const Text('Clear search')),
            ],
          ),
          const SizedBox(height: 14),
        ],
        _feedbackBar(),
        if (widget.isLoading && widget.orders.isEmpty)
          const Padding(
            padding: EdgeInsets.all(80),
            child: Center(child: CircularProgressIndicator(color: AppColors.primary)),
          )
        else
          LayoutBuilder(
            builder: (context, constraints) {
              final cols = constraints.maxWidth >= 1000 ? 4 : (constraints.maxWidth >= 540 ? 2 : 1);
              final w = (constraints.maxWidth - (cols - 1) * 14) / cols;
              return Wrap(
                spacing: 14,
                runSpacing: 14,
                children: [
                  for (var i = 0; i < OrderFlow.activeStages.length; i++)
                    SizedBox(width: w, child: _column(i, orders.where((o) => o.status == OrderFlow.activeStages[i]).toList())),
                ],
              );
            },
          ),
        const SizedBox(height: 18),
        AdminPanel(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 10,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(doneLabel, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
                  const Text('Delivered and rejected orders leave the board and appear here',
                      style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                ],
              ),
              const SizedBox(height: 12),
              if (done.isEmpty)
                const Text('Nothing completed yet', style: TextStyle(color: AppColors.textSecondary, fontSize: 13))
              else
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: done.map((o) {
                    final ok = o.status == OrderStatus.delivered;
                    final ink = ok ? AppColors.primaryDeep : AppColors.error;
                    return Material(
                      color: ok ? const Color(0xFFF3FAF5) : const Color(0xFFFFF5F4),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: ok ? const Color(0xFFCFE3D6) : AppColors.errorBorder),
                      ),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () => widget.onOpenDetails(o),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(ok ? Icons.check_rounded : Icons.close_rounded, size: 16, color: ink),
                              const SizedBox(width: 8),
                              Text(o.orderNumber, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
                              const SizedBox(width: 8),
                              Text(widget.customerName(o), style: const TextStyle(fontSize: 13, color: AppColors.textBody)),
                              const SizedBox(width: 8),
                              Text(qbRupees(o.grandTotal), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
                              const SizedBox(width: 8),
                              Text(ok ? 'DELIVERED' : 'REJECTED',
                                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: ink)),
                            ],
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _dropdown<T>({
    required T value,
    required IconData icon,
    required List<(T, String)> items,
    required ValueChanged<T> onChanged,
  }) {
    return Container(
      height: 42,
      padding: const EdgeInsets.only(left: 12, right: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: AppColors.textBody),
          const SizedBox(width: 6),
          DropdownButtonHideUnderline(
            child: DropdownButton<T>(
              value: value,
              borderRadius: BorderRadius.circular(12),
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
              items: items.map((i) => DropdownMenuItem<T>(value: i.$1, child: Text(i.$2))).toList(),
              onChanged: (v) {
                if (v != null) onChanged(v);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _feedbackBar() {
    final action = widget.lastAction;
    String title;
    String sub;
    Color bg, border, tile, ink;
    IconData icon;
    bool canUndo;
    VoidCallback onDismiss;

    if (action != null) {
      canUndo = true;
      onDismiss = widget.onDismiss;
      if (action.rejected) {
        title = 'Order ${action.orderNumber} rejected';
        sub = '${action.customer} will be notified and any payment refunded.';
        bg = const Color(0xFFFFF5F4);
        border = AppColors.errorBorder;
        tile = AppColors.error;
        ink = AppColors.error;
        icon = Icons.close_rounded;
      } else {
        title = 'Order ${action.orderNumber} ${OrderFlow.verb(action.from)}';
        final stepIndex = OrderFlow.activeStages.indexOf(action.to);
        sub = stepIndex >= 0
            ? '${action.customer} · Now in ${OrderFlow.stageTitle(action.to)} (step ${stepIndex + 1} of 4).'
            : '${action.customer} · Moved to Completed today.';
        bg = const Color(0xFFF3FAF5);
        border = const Color(0xFFCFE3D6);
        tile = AppColors.primary;
        ink = AppColors.primaryDeep;
        icon = Icons.check_rounded;
      }
    } else {
      final newest = widget.orders.where((o) => o.status == OrderStatus.placed).toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      if (newest.isEmpty || _arrivalDismissed) return const SizedBox.shrink();
      final o = newest.first;
      final count = o.items.fold<int>(0, (s, i) => s + i.quantity);
      title = 'New order ${o.orderNumber} ${qbAge(o.createdAt) == 'now' ? 'just arrived' : 'arrived ${qbAge(o.createdAt)} ago'}';
      sub = '${widget.customerName(o)} · $count items · ${qbRupees(o.grandTotal)} · ${o.paymentMethod == 'cod' ? 'Cash on delivery' : 'UPI / Card'}';
      bg = const Color(0xFFFFFBEB);
      border = AppColors.accentBorder;
      tile = const Color(0xFFB07A00);
      ink = AppColors.accentInk;
      icon = Icons.notifications_active_outlined;
      canUndo = false;
      onDismiss = () => setState(() => _arrivalDismissed = true);
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Semantics(
        liveRegion: true,
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 10, 12),
          decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(14), border: Border.all(color: border)),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(color: tile, borderRadius: BorderRadius.circular(10)),
                child: Icon(icon, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: ink)),
                    const SizedBox(height: 2),
                    Text(sub, style: const TextStyle(fontSize: 13, color: AppColors.textBody)),
                  ],
                ),
              ),
              if (canUndo)
                OutlinedButton.icon(
                  onPressed: widget.onUndo,
                  icon: const Icon(Icons.undo_rounded, size: 16),
                  label: const Text('Undo'),
                  style: OutlinedButton.styleFrom(
                    backgroundColor: Colors.white,
                    side: BorderSide(color: border),
                    minimumSize: const Size(0, 38),
                    textStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                  ),
                ),
              IconButton(tooltip: 'Dismiss', onPressed: onDismiss, icon: const Icon(Icons.close_rounded, size: 20)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _column(int index, List<OrderModel> cards) {
    final stage = OrderFlow.activeStages[index];
    final accent = _stageColors[stage]!;
    return Container(
      decoration: qbCard(),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: accent, width: 4), bottom: const BorderSide(color: AppColors.divider)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text('STEP ${index + 1}',
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.textSecondary)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(OrderFlow.stageTitle(stage), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
                    ),
                    Container(
                      constraints: const BoxConstraints(minWidth: 26),
                      height: 24,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: index == 0 && cards.isNotEmpty ? AppColors.accent : AppColors.surfaceMuted,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text('${cards.length}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(_hints[stage]!, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
              ],
            ),
          ),
          Container(
            constraints: const BoxConstraints(minHeight: 420),
            color: const Color(0xFFFAFBFA),
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (cards.isEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 12),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.borderStrong, width: 1.5),
                    ),
                    child: Column(
                      children: [
                        const Icon(Icons.check_rounded, color: AppColors.textSecondary),
                        const SizedBox(height: 6),
                        const Text('All clear', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textSecondary)),
                        const SizedBox(height: 2),
                        Text(_emptyText[stage]!, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                      ],
                    ),
                  ),
                for (final o in cards) ...[_card(o, index, accent), const SizedBox(height: 10)],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _card(OrderModel o, int stageIndex, Color accent) {
    final action = widget.lastAction;
    final justMoved = action != null && !action.rejected && action.orderId == o.id && action.to == o.status;
    final count = o.items.fold<int>(0, (s, i) => s + i.quantity);
    final busy = _busy.contains(o.id);
    final isCod = o.paymentMethod == 'cod';

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: justMoved ? const Color(0xFFF3FAF5) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: justMoved ? AppColors.primary : AppColors.border, width: justMoved ? 2 : 1),
        boxShadow: [
          BoxShadow(
            color: justMoved ? AppColors.primary.withValues(alpha: 0.15) : const Color(0xFF102818).withValues(alpha: 0.05),
            blurRadius: justMoved ? 20 : 2,
            offset: Offset(0, justMoved ? 8 : 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (justMoved) ...[
            Align(
              alignment: Alignment.centerLeft,
              child: QbPill(
                label: 'Just ${OrderFlow.verb(action.from)}',
                icon: Icons.check_rounded,
                background: AppColors.primary,
                foreground: Colors.white,
              ),
            ),
            const SizedBox(height: 10),
          ],
          Row(
            children: [
              Expanded(child: Text(o.orderNumber, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800))),
              QbPill(
                label: qbAge(o.createdAt),
                icon: Icons.schedule_rounded,
                background: stageIndex == 0 ? AppColors.accentLight : AppColors.surfaceMuted,
                foreground: stageIndex == 0 ? AppColors.accentInk : AppColors.textBody,
                fontSize: 12,
              ),
              const SizedBox(width: 2),
              IconButton(
                tooltip: 'Pick list & details',
                visualDensity: VisualDensity.compact,
                onPressed: () => widget.onOpenDetails(o),
                icon: const Icon(Icons.checklist_rounded, size: 20, color: AppColors.textBody),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Semantics(
            label: 'Progress: step ${stageIndex + 1} of 4',
            child: Row(
              children: [
                for (var k = 0; k < 4; k++) ...[
                  if (k > 0) const SizedBox(width: 4),
                  Expanded(
                    child: Container(
                      height: 5,
                      decoration: BoxDecoration(
                        color: k <= stageIndex ? accent : AppColors.border,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text(widget.customerName(o), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
          const SizedBox(height: 3),
          Text(
            o.address?.formattedAddress ?? 'Address not provided',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
          ),
          if (cleanOrderNote(o.deliveryInstructions).isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              'Note: ${cleanOrderNote(o.deliveryInstructions)}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.accentInk),
            ),
          ],
          const SizedBox(height: 10),
          Row(
            children: [
              Text('$count items', style: const TextStyle(fontSize: 13, color: AppColors.textBody)),
              const Spacer(),
              QbPill(
                label: isCod ? 'COD' : 'UPI',
                background: isCod ? AppColors.accentLight : AppColors.infoLight,
                foreground: isCod ? AppColors.accentInk : const Color(0xFF34479A),
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              ),
              const SizedBox(width: 8),
              Text(qbRupees(o.grandTotal), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
            ],
          ),
          const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Divider(height: 1)),
          Row(
            children: [
              if (stageIndex == 0) ...[
                OutlinedButton(
                  onPressed: busy ? null : () => _run(o, widget.onReject),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.error,
                    side: const BorderSide(color: AppColors.errorBorder),
                    minimumSize: const Size(0, 42),
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    textStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                  ),
                  child: const Text('Reject'),
                ),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: ElevatedButton(
                  onPressed: busy ? null : () => _run(o, widget.onAdvance),
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(0, 42),
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    textStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                  ),
                  child: busy
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Flexible(child: Text(OrderFlow.actionLabel(o.status), overflow: TextOverflow.ellipsis)),
                            const SizedBox(width: 6),
                            const Icon(Icons.arrow_forward_rounded, size: 16),
                          ],
                        ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text.rich(
            TextSpan(children: [
              const TextSpan(text: 'Moves to '),
              TextSpan(
                text: stageIndex < 3 ? OrderFlow.stageTitle(OrderFlow.activeStages[stageIndex + 1]) : 'Completed today',
                style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.textBody),
              ),
            ]),
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}
