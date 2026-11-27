import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/config/delivery_config.dart';
import '../../../core/constants/app_colors.dart';
import '../../../models/order_model.dart';
import '../../../services/supabase_service.dart';

/// Formatting, distance and device-intent helpers for the rider app.
class RiderFormat {
  RiderFormat._();

  /// Rider-facing stage for an order.
  static String stageOf(OrderModel o) {
    if (o.status == OrderStatus.delivered) return 'delivered';
    if (o.status == OrderStatus.cancelled) return 'cancelled';
    return o.deliveryStage ?? 'assigned';
  }

  /// Progress step for the delivery stepper (0 accepted … 3 delivered).
  static int stepOf(OrderModel o) {
    switch (stageOf(o)) {
      case 'accepted':
        return 0;
      case 'reached_store':
        return 1;
      case 'picked_up':
      case 'out_for_delivery':
      case 'issue_reported':
        return 2;
      case 'delivered':
        return 3;
      default:
        return 0;
    }
  }

  static String shortAddress(OrderModel o) {
    final a = o.address;
    if (a == null) return 'Address shared by store';
    return [a.flatHouseNumber, a.areaStreet].where((s) => s.trim().isNotEmpty).join(', ');
  }

  static String fullAddress(OrderModel o) {
    final a = o.address;
    if (a == null) return 'Address shared by store';
    return [a.flatHouseNumber, a.areaStreet, '${a.city} ${a.pincode}'].where((s) => s.trim().isNotEmpty).join(', ');
  }

  static String area(OrderModel o) {
    final a = o.address;
    if (a == null) return DeliveryConfig.defaultStorePincode;
    final parts = a.areaStreet.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
    return parts.isNotEmpty ? parts.last : a.pincode;
  }

  /// Straight-line distance store → customer (km), when the address has coordinates.
  static double? dropKm(OrderModel o) {
    final lat = o.address?.latitude, lng = o.address?.longitude;
    if (lat == null || lng == null) return null;
    return _haversine(DeliveryConfig.defaultStoreLatitude, DeliveryConfig.defaultStoreLongitude, lat, lng);
  }

  /// Rough ride time for a city two-wheeler (~20 km/h + 2 min handover).
  static int? etaMinutes(OrderModel o) {
    final km = dropKm(o);
    if (km == null) return null;
    return (km / 20 * 60).ceil() + 2;
  }

  static String km(double? v) => v == null ? '— km' : '${v.toStringAsFixed(1)} km';

  static double _haversine(double lat1, double lon1, double lat2, double lon2) {
    const r = 6371.0;
    double rad(double d) => d * math.pi / 180;
    final dLat = rad(lat2 - lat1), dLon = rad(lon2 - lon1);
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(rad(lat1)) * math.cos(rad(lat2)) * math.sin(dLon / 2) * math.sin(dLon / 2);
    return r * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  }

  static String duration(Duration d) {
    final h = d.inHours, m = d.inMinutes % 60;
    return h > 0 ? '${h}h ${m}m' : '${m}m';
  }

  static String pct(double? v) => v == null ? '—' : '${(v * 100).round()}%';
}

/// Customer contact for an order. Orders don't store the customer's name or
/// phone, so this reads the customer's profile when available.
class CustomerContact {
  final String name;
  final String? phone;
  const CustomerContact(this.name, this.phone);

  static final Map<String, CustomerContact> _cache = {};

  static CustomerContact fallback(OrderModel o) =>
      CustomerContact('Customer · ${o.address?.type ?? 'Home'}', null);

  static Future<CustomerContact> load(OrderModel o) async {
    final cached = _cache[o.userId];
    if (cached != null) return cached;
    var contact = fallback(o);
    try {
      final profile = await SupabaseService().getProfile(o.userId);
      final name = (profile?['full_name'] as String?)?.trim();
      final phone = (profile?['phone_number'] as String?)?.trim();
      if ((name != null && name.isNotEmpty) || (phone != null && phone.isNotEmpty)) {
        contact = CustomerContact(name?.isNotEmpty == true ? name! : contact.name, phone?.isNotEmpty == true ? phone : null);
      }
    } catch (_) {}
    _cache[o.userId] = contact;
    return contact;
  }
}

/// Phone / maps intents.
class RiderIntents {
  RiderIntents._();

  static Future<void> call(BuildContext context, String? phone, {String? unavailableMessage}) async {
    if (phone == null || phone.trim().isEmpty) {
      riderToast(context, unavailableMessage ?? 'Phone number not available.');
      return;
    }
    final uri = Uri(scheme: 'tel', path: phone.replaceAll(RegExp(r'[^\d+]'), ''));
    final ok = await _launch(uri);
    if (!ok && context.mounted) riderToast(context, 'Couldn\'t start a call to $phone');
  }

  static Future<void> sms(BuildContext context, String? phone) async {
    if (phone == null || phone.trim().isEmpty) {
      riderToast(context, 'Customer phone not available — contact the store.');
      return;
    }
    final ok = await _launch(Uri(scheme: 'sms', path: phone.replaceAll(RegExp(r'[^\d+]'), '')));
    if (!ok && context.mounted) riderToast(context, 'Couldn\'t open messages');
  }

  static Future<void> callStore(BuildContext context) => call(
        context,
        DeliveryConfig.storeSupportPhone,
        unavailableMessage: 'Store support number isn\'t configured. Ask your store manager.',
      );

  /// Opens Google Maps turn-by-turn navigation to the customer or the store.
  static Future<void> navigate(BuildContext context, {OrderModel? to, bool toStore = false}) async {
    String destination;
    if (toStore || to == null) {
      destination = '${DeliveryConfig.defaultStoreLatitude},${DeliveryConfig.defaultStoreLongitude}';
    } else if (to.address?.latitude != null && to.address?.longitude != null) {
      destination = '${to.address!.latitude},${to.address!.longitude}';
    } else {
      destination = RiderFormat.fullAddress(to);
    }
    final uri = Uri.https('www.google.com', '/maps/dir/', {
      'api': '1',
      'destination': destination,
      'travelmode': 'two-wheeler',
    });
    final ok = await _launch(uri);
    if (!ok && context.mounted) riderToast(context, 'Couldn\'t open Google Maps');
  }

  static Future<bool> _launch(Uri uri) async {
    try {
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      return false;
    }
  }
}

void riderToast(BuildContext context, String message, {bool error = false}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Text(message),
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 3),
      backgroundColor: error ? AppColors.error : AppColors.textPrimary,
    ));
}
