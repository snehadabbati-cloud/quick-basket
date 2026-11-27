import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/config/delivery_config.dart';
import '../../../core/constants/app_colors.dart';
import '../../../models/delivery_partner_model.dart';
import '../../../shared_widgets/qb_ui.dart';
import '../controllers/rider_profile_repository.dart';
import '../controllers/rider_session.dart';
import '../widgets/rider_helpers.dart';
import '../widgets/rider_ui.dart';
import 'rider_login_screen.dart';

void _go(BuildContext context, Widget w) => Navigator.of(context).push(riderRoute(w));

String _initials(String name) =>
    name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).take(2).map((p) => p[0].toUpperCase()).join();

/// 6.1 Rider Profile (tab).
class RiderProfileTab extends StatelessWidget {
  const RiderProfileTab({super.key});

  @override
  Widget build(BuildContext context) {
    final session = RiderSession();
    return ListenableBuilder(
      listenable: session,
      builder: (context, _) {
        final r = session.rider;
        if (r == null) return const SizedBox.shrink();
        final months = DateTime.now().difference(r.createdAt).inDays ~/ 30;
        return Scaffold(
          backgroundColor: AppColors.background,
          body: ListView(
            padding: EdgeInsets.zero,
            children: [
              Container(
                padding: EdgeInsets.fromLTRB(20, MediaQuery.paddingOf(context).top + 20, 20, 22),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(colors: [AppColors.primary, AppColors.primaryDark], begin: Alignment.topLeft, end: Alignment.bottomRight),
                  borderRadius: BorderRadius.vertical(bottom: Radius.circular(26)),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 34,
                          backgroundColor: AppColors.accent,
                          child: Text(_initials(r.name), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: AppColors.primaryDark)),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(r.name, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900)),
                              const SizedBox(height: 2),
                              Text('${r.phone} · ${DeliveryConfig.defaultStoreName}',
                                  maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Color(0xFFCFEBD9), fontSize: 12)),
                              const SizedBox(height: 6),
                              const QbPill(label: 'Registered partner', background: AppColors.accent, foreground: AppColors.primaryDark, icon: Icons.shield_outlined),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(16)),
                      child: Row(
                        children: [
                          _stat(r.rating.toStringAsFixed(1), 'Rating', icon: Icons.star_rounded),
                          _divider(),
                          _stat('${r.totalDeliveries}', 'Deliveries'),
                          _divider(),
                          _stat(months >= 12 ? '${(months / 12).toStringAsFixed(1)} yrs' : (months < 1 ? 'New' : '$months mo'), 'With us'),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(kRiderGutter),
                child: Column(
                  children: [
                    _group([
                      _MenuTile(Icons.person_outline_rounded, 'Personal information', 'Name, phone, email, address', () => _go(context, const RiderPersonalInfoScreen())),
                      _MenuTile(Icons.two_wheeler_rounded, 'Vehicle details', '${r.vehicleNumber} · ${_vehicleLabel(r.vehicleType)}', () => _go(context, const RiderVehicleScreen())),
                      _MenuTile(Icons.folder_open_rounded, 'Documents', 'ID, licence, RC & insurance', () => _go(context, const RiderDocumentsScreen())),
                      _MenuTile(Icons.account_balance_outlined, 'Bank details', 'Where your payouts go', () => _go(context, const RiderBankScreen())),
                    ]),
                    const SizedBox(height: 12),
                    _group([
                      _MenuTile(Icons.support_agent_rounded, 'Help & support', 'FAQs, store support, emergency', () => _go(context, const RiderSupportScreen())),
                    ]),
                    const SizedBox(height: 12),
                    _group([
                      _MenuTile(Icons.logout_rounded, 'Log out', '', () => _confirmLogout(context), danger: true),
                    ]),
                    const SizedBox(height: 16),
                    const Text('Quick Basket Partner', style: TextStyle(fontSize: 11.5, color: AppColors.textMuted)),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  static Widget _stat(String v, String l, {IconData? icon}) => Expanded(
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (icon != null) ...[Icon(icon, color: AppColors.accent, size: 17), const SizedBox(width: 3)],
                Text(v, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16)),
              ],
            ),
            Text(l, style: const TextStyle(color: Color(0xFFCFEBD9), fontSize: 11.5)),
          ],
        ),
      );

  static Widget _divider() => Container(width: 1, height: 28, color: Colors.white24);

  static Widget _group(List<Widget> tiles) => RCard(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Column(
          children: [
            for (int i = 0; i < tiles.length; i++) ...[
              tiles[i],
              if (i != tiles.length - 1) const Divider(height: 1, indent: 56),
            ],
          ],
        ),
      );

  /// 6.7 Logout with confirmation.
  static Future<void> _confirmLogout(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        icon: const Icon(Icons.logout_rounded, color: AppColors.error, size: 32),
        title: const Text('Log out?', style: TextStyle(fontWeight: FontWeight.w900)),
        content: const Text('You will go offline and stop receiving delivery requests.', textAlign: TextAlign.center),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Log out'),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    final err = await RiderSession().logout();
    if (err != null && context.mounted) riderToast(context, err, error: true);
    // On success the shell sees the session end and returns to the login screen.
  }
}

String _vehicleLabel(String t) => switch (t.toLowerCase()) {
      'ev' => 'Electric scooter',
      'scooter' => 'Scooter',
      'bike' => 'Bike',
      _ => t,
    };

class _MenuTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool danger;
  const _MenuTile(this.icon, this.title, this.subtitle, this.onTap, {this.danger = false});

  @override
  Widget build(BuildContext context) {
    final color = danger ? AppColors.error : AppColors.textPrimary;
    return ListTile(
      onTap: onTap,
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: danger ? AppColors.errorLight : AppColors.primaryTint, borderRadius: BorderRadius.circular(10)),
        child: Icon(icon, size: 20, color: danger ? AppColors.error : AppColors.primaryDeep),
      ),
      title: Text(title, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5, color: color)),
      subtitle: subtitle.isEmpty ? null : Text(subtitle, style: const TextStyle(fontSize: 12)),
      trailing: danger ? null : const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
    );
  }
}

Widget _sectionCard(String title, List<Widget> rows) => RCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15)),
          const SizedBox(height: 4),
          ...rows,
        ],
      ),
    );

class _Notice extends StatelessWidget {
  final String text;
  final bool error;
  const _Notice(this.text, {this.error = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: error ? AppColors.errorLight : AppColors.infoLight, borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: [
          Icon(error ? Icons.error_outline_rounded : Icons.lock_outline_rounded, color: error ? AppColors.error : AppColors.info, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text, style: TextStyle(fontSize: 12.5, color: error ? AppColors.error : AppColors.info, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}

/// Loads & saves [RiderProfileData] with loading / error handling.
abstract class _ProfileFormState<T extends StatefulWidget> extends State<T> {
  final repo = RiderProfileRepository();
  RiderProfileData? data;
  String? loadError;
  bool saving = false;
  final formKey = GlobalKey<FormState>();

  DeliveryPartnerModel get rider => RiderSession().rider!;

  void fill(RiderProfileData d);
  RiderProfileData collect(RiderProfileData base);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final d = await repo.load(rider);
      if (!mounted) return;
      fill(d);
      setState(() => data = d);
    } on RiderException catch (e) {
      if (mounted) setState(() => loadError = e.message);
    }
  }

  Future<void> save() async {
    if (!(formKey.currentState?.validate() ?? false)) return;
    setState(() => saving = true);
    try {
      final next = collect(data ?? const RiderProfileData());
      await repo.save(rider, next);
      if (!mounted) return;
      setState(() => data = next);
      riderToast(context, 'Saved');
      Navigator.of(context).maybePop();
    } on RiderException catch (e) {
      if (mounted) riderToast(context, e.message, error: true);
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  Widget body(BuildContext context);

  Widget scaffold(String title) => Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(title: Text(title)),
        body: loadError != null
            ? Padding(padding: const EdgeInsets.all(kRiderGutter), child: _Notice(loadError!, error: true))
            : data == null
                ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                : Form(key: formKey, child: body(context)),
        bottomNavigationBar: data == null
            ? null
            : RBottomBar(children: [
                RPrimaryButton(label: saving ? 'Saving…' : 'Save changes', icon: Icons.check_rounded, onPressed: saving ? null : save),
              ]),
      );
}

InputDecoration _dec(String label, {String? hint}) => InputDecoration(labelText: label, hintText: hint);

/// 6.2 Personal Information.
class RiderPersonalInfoScreen extends StatefulWidget {
  const RiderPersonalInfoScreen({super.key});

  @override
  State<RiderPersonalInfoScreen> createState() => _RiderPersonalInfoScreenState();
}

class _RiderPersonalInfoScreenState extends _ProfileFormState<RiderPersonalInfoScreen> {
  final _email = TextEditingController();
  final _address = TextEditingController();
  final _eName = TextEditingController();
  final _ePhone = TextEditingController();

  @override
  void dispose() {
    for (final c in [_email, _address, _eName, _ePhone]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  void fill(RiderProfileData d) {
    _email.text = d.email;
    _address.text = d.address;
    _eName.text = d.emergencyName;
    _ePhone.text = d.emergencyPhone;
  }

  @override
  RiderProfileData collect(RiderProfileData base) => base.copyWith(
        email: _email.text.trim(),
        address: _address.text.trim(),
        emergencyName: _eName.text.trim(),
        emergencyPhone: _ePhone.text.trim(),
      );

  @override
  Widget build(BuildContext context) => scaffold('Personal information');

  @override
  Widget body(BuildContext context) => ListView(
        padding: const EdgeInsets.all(kRiderGutter),
        children: [
          _sectionCard('Registered details', [
            RInfoRow(icon: Icons.badge_outlined, label: 'Full name', value: rider.name),
            RInfoRow(icon: Icons.phone_outlined, label: 'Mobile (login)', value: rider.phone),
          ]),
          const SizedBox(height: 8),
          const Text('Name and login number are managed by your store admin.',
              style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
          const SizedBox(height: 16),
          TextFormField(
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            decoration: _dec('Email (optional)'),
            validator: (v) => (v ?? '').trim().isEmpty || RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(v!.trim()) ? null : 'Enter a valid email',
          ),
          const SizedBox(height: 12),
          TextFormField(controller: _address, maxLines: 2, decoration: _dec('Current address')),
          const SizedBox(height: 20),
          const Text('Emergency contact', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15)),
          const SizedBox(height: 10),
          TextFormField(controller: _eName, decoration: _dec('Name & relation', hint: 'e.g. Lakshmi (Spouse)')),
          const SizedBox(height: 12),
          TextFormField(
            controller: _ePhone,
            keyboardType: TextInputType.phone,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(10)],
            decoration: _dec('Phone'),
            validator: (v) => (v ?? '').isEmpty || v!.length == 10 ? null : 'Enter a 10-digit number',
          ),
        ],
      );
}

/// 6.3 Vehicle Details (managed by the store admin).
class RiderVehicleScreen extends StatelessWidget {
  const RiderVehicleScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final r = RiderSession().rider!;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Vehicle details')),
      body: ListView(
        padding: const EdgeInsets.all(kRiderGutter),
        children: [
          RCard(
            color: AppColors.primaryDark,
            borderColor: AppColors.primaryDark,
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: AppColors.accent, borderRadius: BorderRadius.circular(14)),
                  child: Icon(r.vehicleType == 'ev' ? Icons.electric_moped_rounded : Icons.two_wheeler_rounded, size: 34, color: AppColors.primaryDark),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(r.vehicleNumber, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900, letterSpacing: 1)),
                      Text(_vehicleLabel(r.vehicleType), style: const TextStyle(color: Color(0xFFCFEBD9))),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _sectionCard('Registration', [
            RInfoRow(icon: Icons.category_outlined, label: 'Vehicle type', value: _vehicleLabel(r.vehicleType)),
            RInfoRow(icon: Icons.confirmation_number_outlined, label: 'Registration number', value: r.vehicleNumber),
          ]),
          const SizedBox(height: 12),
          const _Notice('Vehicle changes are made by your store admin. Upload the new RC and insurance under Documents, then contact the store.'),
          const SizedBox(height: 16),
          ROutlineButton(label: 'Contact store', icon: Icons.support_agent_rounded, onPressed: () => RiderIntents.callStore(context)),
        ],
      ),
    );
  }
}

/// 6.4 Uploaded Documents.
class RiderDocumentsScreen extends StatefulWidget {
  const RiderDocumentsScreen({super.key});

  @override
  State<RiderDocumentsScreen> createState() => _RiderDocumentsScreenState();
}

class _RiderDocumentsScreenState extends State<RiderDocumentsScreen> {
  final _repo = RiderProfileRepository();
  Map<String, RiderDocument>? _docs;
  String? _error;
  String? _uploading;

  DeliveryPartnerModel get _rider => RiderSession().rider!;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final d = await _repo.documents(_rider);
      if (mounted) setState(() => _docs = d);
    } on RiderException catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  Future<void> _upload(String type) async {
    setState(() => _uploading = type);
    try {
      final ok = await _repo.uploadDocument(_rider, type);
      if (ok && mounted) riderToast(context, 'Uploaded — the admin will review it');
      await _load();
    } on RiderException catch (e) {
      if (mounted) riderToast(context, e.message, error: true);
    } finally {
      if (mounted) setState(() => _uploading = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final canUpload = _repo.canUploadDocuments(_rider);
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Documents')),
      body: ListView(
        padding: const EdgeInsets.all(kRiderGutter),
        children: [
          if (!canUpload) ...[
            const _Notice('Document upload needs a signed-in partner account (real SMS OTP login). Test riders can\'t upload documents.'),
            const SizedBox(height: 12),
          ],
          if (_error != null) ...[
            _Notice(_error!, error: true),
            const SizedBox(height: 12),
          ],
          for (final (type, title) in RiderProfileRepository.documentTypes)
            Builder(builder: (context) {
              final doc = _docs?[type] ?? RiderDocument(type, 'missing');
              final (label, bg, fg) = switch (doc.status) {
                'verified' => ('Verified', AppColors.primaryLight, AppColors.primaryDeep),
                'pending' => ('In review', AppColors.accentLight, AppColors.accentInk),
                'rejected' => ('Re-upload', AppColors.errorLight, AppColors.error),
                _ => ('Upload', AppColors.errorLight, AppColors.error),
              };
              final busy = _uploading == type;
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: RCard(
                  padding: const EdgeInsets.all(14),
                  onTap: canUpload && doc.status != 'verified' && _uploading == null ? () => _upload(type) : null,
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(9),
                        decoration: BoxDecoration(color: AppColors.surfaceMuted, borderRadius: BorderRadius.circular(12)),
                        child: const Icon(Icons.description_outlined, color: AppColors.textBody),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
                            Text(
                              doc.note ?? (doc.uploadedAt != null ? 'Uploaded ${qbFriendlyDate(doc.uploadedAt!)}' : 'Not uploaded'),
                              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                      ),
                      busy
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                          : QbPill(label: label, background: bg, foreground: fg, icon: doc.status == 'missing' || doc.status == 'rejected' ? Icons.upload_rounded : null),
                    ],
                  ),
                ),
              );
            }),
          const SizedBox(height: 6),
          const Text('Documents are stored privately and reviewed by the Quick Basket admin.',
              textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
        ],
      ),
    );
  }
}

/// 6.5 Bank Details.
class RiderBankScreen extends StatefulWidget {
  const RiderBankScreen({super.key});

  @override
  State<RiderBankScreen> createState() => _RiderBankScreenState();
}

class _RiderBankScreenState extends _ProfileFormState<RiderBankScreen> {
  final _holder = TextEditingController();
  final _account = TextEditingController();
  final _confirm = TextEditingController();
  final _ifsc = TextEditingController();
  final _upi = TextEditingController();
  bool _editing = false;

  @override
  void dispose() {
    for (final c in [_holder, _account, _confirm, _ifsc, _upi]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  void fill(RiderProfileData d) {
    _holder.text = d.bankHolder.isEmpty ? rider.name : d.bankHolder;
    _ifsc.text = d.bankIfsc;
    _upi.text = d.upiId;
    _editing = !d.hasBank;
  }

  @override
  RiderProfileData collect(RiderProfileData base) => base.copyWith(
        bankHolder: _holder.text.trim(),
        bankAccount: _editing ? _account.text.trim() : base.bankAccount,
        bankIfsc: _ifsc.text.trim().toUpperCase(),
        upiId: _upi.text.trim(),
      );

  @override
  Widget build(BuildContext context) => scaffold('Bank details');

  @override
  Widget body(BuildContext context) {
    final d = data!;
    return ListView(
      padding: const EdgeInsets.all(kRiderGutter),
      children: [
        if (d.hasBank && !_editing) ...[
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFF1F3A8A), Color(0xFF0F1E4A)]),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.account_balance_rounded, color: Colors.white),
                    const SizedBox(width: 8),
                    Text(d.bankIfsc.length >= 4 ? d.bankIfsc.substring(0, 4) : 'Bank',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16)),
                    const Spacer(),
                    const QbPill(label: 'Payout account', background: AppColors.accent, foreground: AppColors.primaryDark),
                  ],
                ),
                const SizedBox(height: 26),
                Text(d.maskedAccount, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800, letterSpacing: 1.5)),
                const SizedBox(height: 14),
                Text(d.bankHolder.toUpperCase(), style: const TextStyle(color: Color(0xFFC7D2FE), fontWeight: FontWeight.w800, letterSpacing: 1)),
              ],
            ),
          ),
          const SizedBox(height: 12),
          ROutlineButton(label: 'Change bank account', icon: Icons.edit_outlined, onPressed: () => setState(() => _editing = true)),
          const SizedBox(height: 16),
        ],
        TextFormField(
          controller: _holder,
          decoration: _dec('Account holder name'),
          validator: (v) => (v ?? '').trim().length < 3 ? 'Enter the name on the account' : null,
        ),
        if (_editing) ...[
          const SizedBox(height: 12),
          TextFormField(
            controller: _account,
            keyboardType: TextInputType.number,
            obscureText: true,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(18)],
            decoration: _dec('Account number'),
            validator: (v) => (v ?? '').length < 9 ? 'Enter a valid account number (9–18 digits)' : null,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _confirm,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(18)],
            decoration: _dec('Re-enter account number'),
            validator: (v) => v != _account.text ? 'Account numbers don\'t match' : null,
          ),
        ],
        const SizedBox(height: 12),
        TextFormField(
          controller: _ifsc,
          textCapitalization: TextCapitalization.characters,
          inputFormatters: [LengthLimitingTextInputFormatter(11)],
          decoration: _dec('IFSC', hint: 'e.g. HDFC0001234'),
          validator: (v) => RegExp(r'^[A-Z]{4}0[A-Z0-9]{6}$').hasMatch((v ?? '').trim().toUpperCase()) ? null : 'Enter a valid 11-character IFSC',
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _upi,
          decoration: _dec('UPI ID (optional)', hint: 'name@bank'),
          validator: (v) => (v ?? '').trim().isEmpty || RegExp(r'^[\w.\-]{2,}@[a-zA-Z]{2,}$').hasMatch(v!.trim()) ? null : 'Enter a valid UPI ID',
        ),
        const SizedBox(height: 16),
        _Notice(repo.usesCloud
            ? 'Stored securely — only you and Quick Basket admins can see it.'
            : 'Test rider: saved on this device only.'),
      ],
    );
  }
}

/// 6.6 Support / Help.
class RiderSupportScreen extends StatelessWidget {
  const RiderSupportScreen({super.key});

  static final _faqs = [
    ('How are my earnings calculated?',
        '${qbRupees(DeliveryConfig.defaultPerDeliveryEarning)} per completed delivery plus 100% of customer tips. See the Earnings tab for daily, weekly and monthly totals.'),
    ('Customer is not sharing the OTP',
        'Ask the customer to open the order in their Quick Basket app. You have ${DeliveryConfig.maxOtpAttempts} attempts. If it still fails, use "Issue" — never hand over an order without OTP.'),
    ('What do I do with COD cash?', 'Hand all cash-on-delivery cash to the store manager at the end of your shift. Earnings → COD collected shows today\'s total.'),
    ('Can I go offline during a delivery?', 'No. Complete the delivery or report an issue first.'),
    ('What happens if I don\'t respond to a request?',
        'Requests auto-decline after ${DeliveryConfig.requestResponseWindow.inSeconds} seconds and go to another partner. Declines lower your acceptance rate.'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Help & support')),
      body: ListView(
        padding: const EdgeInsets.all(kRiderGutter),
        children: [
          RCard(
            color: AppColors.errorLight,
            borderColor: AppColors.errorBorder,
            onTap: () => RiderIntents.call(context, '112'),
            child: const Row(
              children: [
                Icon(Icons.sos_rounded, color: AppColors.error, size: 30),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Emergency / accident', style: TextStyle(fontWeight: FontWeight.w900, color: AppColors.error)),
                      Text('Call 112 (national emergency number)', style: TextStyle(fontSize: 12, color: AppColors.error)),
                    ],
                  ),
                ),
                Icon(Icons.call_rounded, color: AppColors.error),
              ],
            ),
          ),
          const SizedBox(height: 12),
          RCard(
            onTap: () => RiderIntents.callStore(context),
            child: Row(
              children: [
                const Icon(Icons.storefront_rounded, color: AppColors.primaryDeep),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Call store support', style: TextStyle(fontWeight: FontWeight.w800)),
                      Text(DeliveryConfig.storeSupportPhone.isEmpty ? DeliveryConfig.defaultStoreName : DeliveryConfig.storeSupportPhone,
                          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                    ],
                  ),
                ),
                const Icon(Icons.call_rounded, color: AppColors.primaryDeep),
              ],
            ),
          ),
          const RSectionTitle('FAQs'),
          RCard(
            padding: EdgeInsets.zero,
            child: Theme(
              data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
              child: Column(
                children: _faqs
                    .map((f) => ExpansionTile(
                          title: Text(f.$1, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                          expandedAlignment: Alignment.centerLeft,
                          children: [Text(f.$2, style: const TextStyle(color: AppColors.textBody, height: 1.4))],
                        ))
                    .toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
