import 'dart:async';
import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../models/order_model.dart';
import '../../../services/supabase_service.dart';
import '../../../shared_widgets/responsive_wrapper.dart';

class OrderTrackingScreen extends StatefulWidget {
  final OrderModel order;

  const OrderTrackingScreen({
    super.key,
    required this.order,
  });

  @override
  State<OrderTrackingScreen> createState() => _OrderTrackingScreenState();
}

class _OrderTrackingScreenState extends State<OrderTrackingScreen> {
  late OrderModel _activeOrder;
  late int _remainingSeconds;
  Timer? _countdownTimer;
  Timer? _crossTabSyncTimer;
  late OrderStatus _currentStatus;

  @override
  void initState() {
    super.initState();
    // Resolve fresh state from SupabaseService
    final fresh = SupabaseService().getOrderById(widget.order.id) ??
        SupabaseService().getOrderById(widget.order.orderNumber);
    _activeOrder = fresh ?? widget.order;
    _currentStatus = _activeOrder.status;

    if (_currentStatus == OrderStatus.delivered) {
      _remainingSeconds = 0;
    } else if (_currentStatus == OrderStatus.outForDelivery) {
      _remainingSeconds = 4 * 60;
    } else if (_currentStatus == OrderStatus.packing || _currentStatus == OrderStatus.confirmed) {
      _remainingSeconds = 7 * 60;
    } else {
      _remainingSeconds = _activeOrder.estimatedDeliveryMinutes * 60;
    }

    // Subscribe to real-time order status notifications from Admin/Store Manager
    SupabaseService().ordersNotifier.addListener(_onOrdersUpdated);

    // Active cross-tab sync ticker (every 800ms checks shared storage with reload() for instant live status propagation)
    _crossTabSyncTimer = Timer.periodic(const Duration(milliseconds: 800), (_) async {
      if (_currentStatus == OrderStatus.delivered) {
        _crossTabSyncTimer?.cancel();
        return;
      }
      final latest = await SupabaseService().getLatestOrderStatus(widget.order.orderNumber) ??
          await SupabaseService().getLatestOrderStatus(widget.order.id);
      if (latest != null && latest != _currentStatus && mounted) {
        setState(() {
          _currentStatus = latest;
          _activeOrder = _activeOrder.copyWith(status: latest);
          if (_currentStatus == OrderStatus.delivered) {
            _remainingSeconds = 0;
            _countdownTimer?.cancel();
            _crossTabSyncTimer?.cancel();
          } else if (_currentStatus == OrderStatus.outForDelivery) {
            if (_remainingSeconds > 300) _remainingSeconds = 240;
          } else if (_currentStatus == OrderStatus.packing) {
            if (_remainingSeconds > 480) _remainingSeconds = 420;
          }
        });
      }
    });

    // Realistic countdown ticker
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remainingSeconds > 0 && _currentStatus != OrderStatus.delivered) {
        if (mounted) {
          setState(() {
            _remainingSeconds--;
          });
        }
      }
    });
  }

  void _onOrdersUpdated() {
    final updated = SupabaseService().getOrderById(widget.order.id) ??
        SupabaseService().getOrderById(widget.order.orderNumber);
    if (updated != null && mounted) {
      setState(() {
        _activeOrder = updated;
        if (_currentStatus != updated.status) {
          _currentStatus = updated.status;
          if (_currentStatus == OrderStatus.delivered) {
            _remainingSeconds = 0;
            _countdownTimer?.cancel();
          } else if (_currentStatus == OrderStatus.outForDelivery) {
            if (_remainingSeconds > 300) _remainingSeconds = 240;
          } else if (_currentStatus == OrderStatus.packing) {
            if (_remainingSeconds > 480) _remainingSeconds = 420;
          }
        }
      });
    }
  }

  @override
  void dispose() {
    _crossTabSyncTimer?.cancel();
    SupabaseService().ordersNotifier.removeListener(_onOrdersUpdated);
    _countdownTimer?.cancel();
    super.dispose();
  }

  String _formatTime(int totalSeconds) {
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          'Order ${_activeOrder.orderNumber}',
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: AppColors.textPrimary),
        ),
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: ResponsiveWrapper(
          maxWidth: 800,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // 1. 12-Minute Countdown Hero Banner (Real-time reactive)
              _buildCountdownHero(),

              const SizedBox(height: 16),

              // 2. Delivery OTP Card (PRD 4.10)
              _buildOtpCard(),

              const SizedBox(height: 16),

              // 3. Status Stepper
              _buildStatusStepper(),

              const SizedBox(height: 16),

              // 4. Delivery Partner Card
              _buildRiderCard(),

              const SizedBox(height: 16),

              // 5. Delivery Address Card
              _buildAddressCard(),

              const SizedBox(height: 16),

              // 6. Item Summary Card
              _buildItemSummaryCard(),

              const SizedBox(height: 24),

              // Back to Home Button
              ElevatedButton.icon(
                onPressed: () => Navigator.pop(context),
                icon: Icon(
                  _currentStatus == OrderStatus.delivered
                      ? Icons.check_circle_outline_rounded
                      : Icons.arrow_back_rounded,
                  size: 18,
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                label: Text(
                  _currentStatus == OrderStatus.delivered
                      ? 'Order Delivered • Back to Orders'
                      : 'Continue Shopping',
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCountdownHero() {
    final isDelivered = _currentStatus == OrderStatus.delivered;
    final isOut = _currentStatus == OrderStatus.outForDelivery;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 350),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDelivered
              ? [const Color(0xFF0C8340), const Color(0xFF045828)]
              : isOut
                  ? [const Color(0xFF0288D1), const Color(0xFF01579B)]
                  : [const Color(0xFF0C8340), const Color(0xFF075E2B)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: (isDelivered ? const Color(0xFF0C8340) : const Color(0xFF0288D1)).withValues(alpha: 0.35),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                isDelivered ? Icons.celebration_rounded : Icons.bolt_rounded,
                color: const Color(0xFFFFD700),
                size: 28,
              ),
              const SizedBox(width: 8),
              Text(
                isDelivered ? 'Order Delivered!' : 'Arriving in ${_formatTime(_remainingSeconds)} mins',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _getStatusMessage(),
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.95),
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.22),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.circle, color: Color(0xFF4ADE80), size: 8),
                SizedBox(width: 6),
                Text(
                  'Live synced with Koramangala Dark Store',
                  style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _getStatusMessage() {
    switch (_currentStatus) {
      case OrderStatus.placed:
        return 'Order received! Sending to nearest dark store...';
      case OrderStatus.confirmed:
        return 'Store manager accepted your order. Packing will begin shortly.';
      case OrderStatus.packing:
        return 'Store picker is packing your fresh items with care';
      case OrderStatus.outForDelivery:
        return 'Delivery partner Ramesh is on the way to your door 🛵';
      case OrderStatus.delivered:
        return 'Order delivered! Enjoy your fresh groceries 🎉';
      case OrderStatus.cancelled:
        return 'Order has been cancelled.';
    }
  }

  Widget _buildOtpCard() {
    final isDelivered = _currentStatus == OrderStatus.delivered;

    if (isDelivered) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: const Color(0xFFE8F5E9),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFA5D6A7), width: 1.2),
        ),
        child: Row(
          children: [
            const Icon(Icons.verified_rounded, color: Color(0xFF0C8340), size: 28),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Delivery Verified & Handed Over',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: Color(0xFF064E26)),
                  ),
                  Text(
                    'Verified via Secure OTP: ${_activeOrder.deliveryOtp}',
                    style: TextStyle(fontSize: 12, color: Colors.green.shade900),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF0C8340),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text('VERIFIED', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 11)),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7ED),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFFD8A8), width: 1.2),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Delivery Verification OTP',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFFC05621),
                ),
              ),
              SizedBox(height: 2),
              Text(
                'Share with rider upon arrival',
                style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
              ),
            ],
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.secondary,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              _activeOrder.deliveryOtp,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 18,
                letterSpacing: 2,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusStepper() {
    final isDelivered = _currentStatus == OrderStatus.delivered;
    final isOut = _currentStatus == OrderStatus.outForDelivery || isDelivered;
    final isPacking = _currentStatus == OrderStatus.confirmed || _currentStatus == OrderStatus.packing || isOut;

    final steps = [
      {'title': 'Order Placed', 'time': 'Just now', 'done': true},
      {
        'title': 'Packing at Dark Store',
        'time': isPacking ? (isOut ? 'Completed' : 'Packing now') : 'Pending',
        'done': isPacking,
      },
      {
        'title': 'Out for Delivery',
        'time': isOut ? (isDelivered ? 'Delivered' : 'On the way') : '7 mins',
        'done': isOut,
      },
      {'title': 'Delivered', 'time': isDelivered ? 'Completed' : '12 mins', 'done': isDelivered},
    ];

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
          const Text(
            'Delivery Status',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: AppColors.textPrimary),
          ),
          const SizedBox(height: 16),
          ...List.generate(steps.length, (index) {
            final s = steps[index];
            final isDone = s['done'] as bool;
            final isLast = index == steps.length - 1;

            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Column(
                  children: [
                    CircleAvatar(
                      radius: 12,
                      backgroundColor: isDone ? AppColors.primary : Colors.grey.shade200,
                      child: Icon(
                        isDone ? Icons.check : Icons.circle,
                        size: isDone ? 14 : 8,
                        color: isDone ? Colors.white : Colors.grey.shade400,
                      ),
                    ),
                    if (!isLast)
                      Container(
                        width: 2,
                        height: 28,
                        color: isDone ? AppColors.primary : Colors.grey.shade200,
                      ),
                  ],
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          s['title'] as String,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: isDone ? FontWeight.w700 : FontWeight.w500,
                            color: isDone ? AppColors.textPrimary : AppColors.textMuted,
                          ),
                        ),
                        Text(
                          s['time'] as String,
                          style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          }),
        ],
      ),
    );
  }

  Widget _buildRiderCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border, width: 0.8),
      ),
      child: Row(
        children: [
          const CircleAvatar(
            radius: 24,
            backgroundColor: AppColors.primaryLight,
            child: Icon(Icons.sports_motorsports_rounded, color: AppColors.primary, size: 28),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Ramesh Kumar',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                ),
                SizedBox(height: 2),
                Row(
                  children: [
                    Icon(Icons.star, color: Colors.amber, size: 14),
                    SizedBox(width: 4),
                    Text(
                      '4.9 (2,400+ deliveries) • Electric EV',
                      style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Calling delivery partner Ramesh Kumar...')),
              );
            },
            style: IconButton.styleFrom(
              backgroundColor: AppColors.primaryLight,
              padding: const EdgeInsets.all(10),
            ),
            icon: const Icon(Icons.call, color: AppColors.primary, size: 20),
          ),
        ],
      ),
    );
  }

  Widget _buildAddressCard() {
    final addr = _activeOrder.address;
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
          const Row(
            children: [
              Icon(Icons.location_on_outlined, size: 18, color: AppColors.primary),
              SizedBox(width: 8),
              Text(
                'Delivery Address',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            addr != null ? '${addr.type} • ${addr.formattedAddress}' : 'Home • Indiranagar, Bengaluru',
            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, height: 1.3),
          ),
          if (_activeOrder.deliveryInstructions != null && _activeOrder.deliveryInstructions!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                'Instructions: ${_activeOrder.deliveryInstructions}',
                style: const TextStyle(fontSize: 11, color: AppColors.textPrimary, fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildItemSummaryCard() {
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Items (${_activeOrder.items.length})',
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  _activeOrder.paymentMethod.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ..._activeOrder.items.map((item) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      '${item.quantity}x ${item.product.name} (${item.variant.unit})',
                      style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                    ),
                  ),
                  Text(
                    '₹${item.totalPrice.toStringAsFixed(0)}',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            );
          }),
          const Divider(height: 16, color: AppColors.border),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Total Paid', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
              Text(
                '₹${_activeOrder.grandTotal.toStringAsFixed(0)}',
                style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: AppColors.primary),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
