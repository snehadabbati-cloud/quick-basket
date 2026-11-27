import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/utils/image_upload_helper.dart';
import '../../../models/delivery_partner_model.dart';
import '../../../services/supabase_service.dart';
import 'rider_session.dart';

/// Editable rider profile fields (personal + payout).
class RiderProfileData {
  final String email;
  final String address;
  final String emergencyName;
  final String emergencyPhone;
  final String bankHolder;
  final String bankAccount;
  final String bankIfsc;
  final String upiId;

  const RiderProfileData({
    this.email = '',
    this.address = '',
    this.emergencyName = '',
    this.emergencyPhone = '',
    this.bankHolder = '',
    this.bankAccount = '',
    this.bankIfsc = '',
    this.upiId = '',
  });

  bool get hasBank => bankAccount.isNotEmpty && bankIfsc.isNotEmpty;
  String get maskedAccount => bankAccount.length <= 4 ? bankAccount : '••••${bankAccount.substring(bankAccount.length - 4)}';

  RiderProfileData copyWith({
    String? email,
    String? address,
    String? emergencyName,
    String? emergencyPhone,
    String? bankHolder,
    String? bankAccount,
    String? bankIfsc,
    String? upiId,
  }) =>
      RiderProfileData(
        email: email ?? this.email,
        address: address ?? this.address,
        emergencyName: emergencyName ?? this.emergencyName,
        emergencyPhone: emergencyPhone ?? this.emergencyPhone,
        bankHolder: bankHolder ?? this.bankHolder,
        bankAccount: bankAccount ?? this.bankAccount,
        bankIfsc: bankIfsc ?? this.bankIfsc,
        upiId: upiId ?? this.upiId,
      );

  Map<String, dynamic> toRow() => {
        'email': email,
        'address': address,
        'emergency_contact_name': emergencyName,
        'emergency_contact_phone': emergencyPhone,
        'bank_account_holder': bankHolder,
        'bank_account_number': bankAccount,
        'bank_ifsc': bankIfsc,
        'upi_id': upiId,
      };

  factory RiderProfileData.fromRow(Map<String, dynamic> m) => RiderProfileData(
        email: m['email'] as String? ?? '',
        address: m['address'] as String? ?? '',
        emergencyName: m['emergency_contact_name'] as String? ?? '',
        emergencyPhone: m['emergency_contact_phone'] as String? ?? '',
        bankHolder: m['bank_account_holder'] as String? ?? '',
        bankAccount: m['bank_account_number'] as String? ?? '',
        bankIfsc: m['bank_ifsc'] as String? ?? '',
        upiId: m['upi_id'] as String? ?? '',
      );
}

class RiderDocument {
  final String type;
  final String status; // 'missing' | 'pending' | 'verified' | 'rejected'
  final DateTime? uploadedAt;
  final String? note;
  const RiderDocument(this.type, this.status, {this.uploadedAt, this.note});
}

/// Where rider profile data lives:
/// - Signed-in partners (real Supabase phone OTP session): `rider_profiles`,
///   `rider_documents` and the private `rider-documents` bucket, all owner-only
///   (see migration 20261123000000_rider_profiles_and_documents.sql).
/// - Debug-build test riders (no auth session): local device storage, profile
///   only — never document uploads.
class RiderProfileRepository {
  RiderProfileRepository._();
  static final RiderProfileRepository instance = RiderProfileRepository._();
  factory RiderProfileRepository() => instance;

  static const migrationName = '20261123000000_rider_profiles_and_documents.sql';
  static const documentTypes = [
    ('aadhaar', 'Aadhaar card'),
    ('pan', 'PAN card'),
    ('driving_licence', 'Driving licence'),
    ('vehicle_rc', 'Vehicle RC'),
    ('vehicle_insurance', 'Vehicle insurance'),
  ];

  SupabaseService get _svc => SupabaseService();
  User? get _user => _svc.isInitialized ? _svc.currentUser : null;

  bool get usesCloud => _user != null;
  bool canUseLocal(DeliveryPartnerModel r) => RiderSession.testRidersEnabled && RiderSession.isTestRider(r);
  bool canUploadDocuments(DeliveryPartnerModel r) => usesCloud;

  RiderException _friendly(Object e) {
    final msg = e.toString();
    if (e is PostgrestException && (e.code == '42P01' || e.code == 'PGRST205' || e.code == 'PGRST202') ||
        msg.contains('does not exist') ||
        msg.contains('Could not find the table') ||
        msg.contains('Bucket not found')) {
      return const RiderException('Profile storage isn\'t set up on the server yet. Ask your admin to run the database migration $migrationName.');
    }
    return RiderException('Couldn\'t reach the server: ${msg.replaceFirst('Exception: ', '')}');
  }

  RiderException get _signInNeeded =>
      const RiderException('Sign in with your registered partner number to manage this.');

  Future<RiderProfileData> load(DeliveryPartnerModel r) async {
    final user = _user;
    if (user != null) {
      try {
        final row = await _svc.client.from('rider_profiles').select().eq('user_id', user.id).maybeSingle();
        return row == null ? const RiderProfileData() : RiderProfileData.fromRow(row);
      } catch (e) {
        throw _friendly(e);
      }
    }
    if (canUseLocal(r)) {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('qb_rider_profile_${r.id}');
      return raw == null ? const RiderProfileData() : RiderProfileData.fromRow(jsonDecode(raw) as Map<String, dynamic>);
    }
    throw _signInNeeded;
  }

  Future<void> save(DeliveryPartnerModel r, RiderProfileData data) async {
    final user = _user;
    if (user != null) {
      try {
        await _svc.client.from('rider_profiles').upsert({
          'user_id': user.id,
          'rider_ref': r.id,
          'phone': r.phone,
          ...data.toRow(),
          'updated_at': DateTime.now().toIso8601String(),
        }, onConflict: 'user_id');
        return;
      } catch (e) {
        throw _friendly(e);
      }
    }
    if (canUseLocal(r)) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('qb_rider_profile_${r.id}', jsonEncode(data.toRow()));
      return;
    }
    throw _signInNeeded;
  }

  Future<Map<String, RiderDocument>> documents(DeliveryPartnerModel r) async {
    final result = {for (final (t, _) in documentTypes) t: RiderDocument(t, 'missing')};
    final user = _user;
    if (user == null) return result;
    try {
      final rows = await _svc.client.from('rider_documents').select().eq('user_id', user.id) as List<dynamic>;
      for (final row in rows) {
        final m = row as Map<String, dynamic>;
        final type = m['doc_type'] as String;
        result[type] = RiderDocument(
          type,
          m['status'] as String? ?? 'pending',
          uploadedAt: DateTime.tryParse(m['uploaded_at'] as String? ?? ''),
          note: m['review_note'] as String?,
        );
      }
      return result;
    } catch (e) {
      throw _friendly(e);
    }
  }

  /// Picks an image and uploads it for review. Returns false if cancelled.
  Future<bool> uploadDocument(DeliveryPartnerModel r, String docType) async {
    final user = _user;
    if (user == null) throw _signInNeeded;
    final picked = await ImageUploadHelper.pickImage();
    if (picked == null) return false;
    final ext = picked.fileName.contains('.') ? picked.fileName.split('.').last.toLowerCase() : 'jpg';
    final path = '${user.id}/$docType-${DateTime.now().millisecondsSinceEpoch}.$ext';
    try {
      await _svc.client.storage.from('rider-documents').uploadBinary(path, picked.bytes);
      await _svc.client.from('rider_documents').upsert({
        'user_id': user.id,
        'doc_type': docType,
        'storage_path': path,
        'status': 'pending',
        'uploaded_at': DateTime.now().toIso8601String(),
      }, onConflict: 'user_id,doc_type');
      return true;
    } catch (e) {
      throw _friendly(e);
    }
  }
}
