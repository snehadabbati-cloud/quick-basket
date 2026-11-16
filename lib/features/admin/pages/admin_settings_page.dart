import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../models/banner_model.dart';
import '../../../services/mock_data_service.dart';
import '../../../services/supabase_service.dart';
import '../../../shared_widgets/promo_banner_card.dart';
import '../../../shared_widgets/qb_ui.dart';
import '../widgets/admin_ui.dart';

/// Store settings: profile, delivery areas & fees, banners, staff, notifications.
class AdminSettingsPage extends StatefulWidget {
  final Map<String, dynamic> managerData;
  final bool storeOpen;
  final ValueChanged<bool> onStoreOpenChanged;

  const AdminSettingsPage({
    super.key,
    required this.managerData,
    required this.storeOpen,
    required this.onStoreOpenChanged,
  });

  @override
  State<AdminSettingsPage> createState() => _AdminSettingsPageState();
}

class _AdminSettingsPageState extends State<AdminSettingsPage> {
  String _tab = 'delivery';

  final _storeName = TextEditingController(text: 'Quick Basket — Koramangala');
  final _storeCode = TextEditingController(text: 'QB-BLR-KRM');
  final _storePhone = TextEditingController(text: '+91 80 4000 1234');
  final _storeHours = TextEditingController(text: '7:00 AM – 11:00 PM');
  final _storeAddress = TextEditingController(text: '80 Feet Road, 4th Block, Koramangala, Bengaluru 560034');

  final List<Map<String, dynamic>> _areas = [
    {'name': 'Koramangala', 'pin': '560034', 'min': 99, 'fee': 25, 'free': 199, 'eta': 12, 'live': true},
    {'name': 'HSR Layout', 'pin': '560102', 'min': 99, 'fee': 25, 'free': 199, 'eta': 15, 'live': true},
    {'name': 'BTM Layout', 'pin': '560076', 'min': 99, 'fee': 25, 'free': 199, 'eta': 18, 'live': true},
  ];

  late final List<Map<String, String>> _staff = [
    {
      'name': (widget.managerData['name'] as String?) ?? 'Store Manager',
      'email': (widget.managerData['email'] as String?) ?? 'manager@quickbasket.com',
      'role': 'Admin',
      'access': 'Everything',
      'status': 'Active',
    },
  ];

  bool _notifyNewOrder = true;
  bool _notifyLowStock = true;
  bool _notifyDaily = false;

  List<BannerModel> _banners = MockDataService.banners;

  @override
  void initState() {
    super.initState();
    _loadBanners();
  }

  Future<void> _loadBanners() async {
    final b = await SupabaseService().getBanners();
    if (mounted) setState(() => _banners = b);
  }

  @override
  void dispose() {
    for (final c in [_storeName, _storeCode, _storePhone, _storeHours, _storeAddress]) {
      c.dispose();
    }
    super.dispose();
  }

  void _snack(String msg) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  @override
  Widget build(BuildContext context) {
    final mobile = Responsive.isMobile(context);
    final tabs = const [
      ('store', 'Store profile', Icons.storefront_outlined),
      ('delivery', 'Delivery & fees', Icons.local_shipping_outlined),
      ('banners', 'Banners', Icons.view_carousel_outlined),
      ('staff', 'Staff & roles', Icons.people_outline_rounded),
      ('notif', 'Notifications', Icons.notifications_none_rounded),
    ];

    final nav = Container(
      padding: const EdgeInsets.all(8),
      decoration: qbCard(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: tabs.map((t) {
          final on = t.$1 == _tab;
          return Padding(
            padding: const EdgeInsets.only(bottom: 2),
            child: Material(
              color: on ? AppColors.primaryLight : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => setState(() => _tab = t.$1),
                child: SizedBox(
                  height: 44,
                  child: Row(
                    children: [
                      const SizedBox(width: 12),
                      Icon(t.$3, size: 18, color: on ? AppColors.primaryDeep : AppColors.textBody),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(t.$2,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: on ? FontWeight.w800 : FontWeight.w600,
                              color: on ? AppColors.primaryDeep : AppColors.textBody,
                            )),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );

    Widget content;
    switch (_tab) {
      case 'store':
        content = _storeSection();
        break;
      case 'banners':
        content = _bannersSection();
        break;
      case 'staff':
        content = _staffSection();
        break;
      case 'notif':
        content = _notificationsSection();
        break;
      default:
        content = _deliverySection();
    }

    return ListView(
      padding: EdgeInsets.fromLTRB(mobile ? 16 : 32, 24, mobile ? 16 : 32, 40),
      children: [
        const AdminPageHeader(title: 'Settings', subtitle: 'Store details, delivery zones, fees, banners and staff access'),
        const SizedBox(height: 18),
        LayoutBuilder(
          builder: (context, c) {
            if (c.maxWidth < 760) return Column(children: [nav, const SizedBox(height: 16), content]);
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [SizedBox(width: 240, child: nav), const SizedBox(width: 18), Expanded(child: content)],
            );
          },
        ),
      ],
    );
  }

  Widget _sectionTitle(String title, {String? subtitle, Widget? action}) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
              if (subtitle != null) Text(subtitle, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
            ],
          ),
        ),
        ?action,
      ],
    );
  }

  Widget _labeled(String label, Widget field) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textBody)),
          const SizedBox(height: 6),
          field,
        ],
      );

  Widget _grid(List<Widget> children, {double minWidth = 220}) {
    return LayoutBuilder(builder: (context, c) {
      final cols = (c.maxWidth / minWidth).floor().clamp(1, 4);
      final w = (c.maxWidth - (cols - 1) * 14) / cols;
      return Wrap(spacing: 14, runSpacing: 14, children: children.map((e) => SizedBox(width: w, child: e)).toList());
    });
  }

  // ----------------------------------------------------------------- Store

  Widget _storeSection() {
    return AdminPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _sectionTitle(
            'Store profile',
            action: Material(
              color: Colors.white,
              shape: StadiumBorder(side: BorderSide(color: AppColors.border)),
              child: InkWell(
                customBorder: const StadiumBorder(),
                onTap: () => widget.onStoreOpenChanged(!widget.storeOpen),
                child: Padding(
                  padding: const EdgeInsets.only(left: 14, right: 2),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(widget.storeOpen ? 'Accepting orders' : 'Store closed',
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
                      AdminSwitch(value: widget.storeOpen, onChanged: widget.onStoreOpenChanged, semanticLabel: 'Accepting orders'),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          _grid([
            _labeled('Store name', TextField(controller: _storeName)),
            _labeled('Store code', TextField(controller: _storeCode)),
            _labeled('Phone number', TextField(controller: _storePhone, keyboardType: TextInputType.phone)),
            _labeled('Operating hours', TextField(controller: _storeHours)),
          ]),
          const SizedBox(height: 14),
          _labeled('Address', TextField(controller: _storeAddress)),
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerRight,
            child: ElevatedButton(
              onPressed: () {
                if (_storeName.text.trim().isEmpty) {
                  _snack('Store name cannot be empty');
                  return;
                }
                _snack('Store profile saved');
              },
              child: const Text('Save Changes'),
            ),
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------- Delivery

  void _addArea() {
    final name = TextEditingController();
    final pin = TextEditingController();
    final eta = TextEditingController(text: '15');
    String? error;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Add delivery area', style: TextStyle(fontWeight: FontWeight.w800)),
          content: SizedBox(
            width: 380,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: name, decoration: const InputDecoration(labelText: 'Area name')),
                const SizedBox(height: 12),
                TextField(controller: pin, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Pincode')),
                const SizedBox(height: 12),
                TextField(controller: eta, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'ETA (minutes)')),
                if (error != null) ...[
                  const SizedBox(height: 10),
                  Text(error!, style: const TextStyle(color: AppColors.error, fontWeight: FontWeight.w700)),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () {
                final etaVal = int.tryParse(eta.text.trim());
                if (name.text.trim().isEmpty || !RegExp(r'^\d{6}$').hasMatch(pin.text.trim()) || etaVal == null) {
                  setD(() => error = 'Enter an area name, a 6-digit pincode and an ETA');
                  return;
                }
                setState(() => _areas.add({
                      'name': name.text.trim(),
                      'pin': pin.text.trim(),
                      'min': 99,
                      'fee': 25,
                      'free': 199,
                      'eta': etaVal,
                      'live': true,
                    }));
                Navigator.pop(ctx);
                _snack('${name.text.trim()} added');
              },
              child: const Text('Add area'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _deliverySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AdminPanel(
          padding: EdgeInsets.zero,
          clip: true,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 16, 14),
                child: _sectionTitle(
                  'Delivery areas',
                  subtitle: 'Pincodes served by this store',
                  action: OutlinedButton(
                    onPressed: _addArea,
                    style: OutlinedButton.styleFrom(
                      backgroundColor: AppColors.primaryTint,
                      foregroundColor: AppColors.primary,
                      side: const BorderSide(color: AppColors.primary, width: 1.5),
                    ),
                    child: const Text('Add area'),
                  ),
                ),
              ),
              AdminTable(
                columns: const ['Area', 'Pincode', 'Min order', 'Delivery fee', 'Free above', 'ETA', 'Live'],
                flex: const [1.4, 0.9, 0.9, 0.9, 0.9, 0.7, 0.6],
                minWidth: 700,
                rows: _areas.map((a) {
                  return <Widget>[
                    Text(a['name'] as String, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
                    Text(a['pin'] as String, style: const TextStyle(fontSize: 13)),
                    Text('₹${a['min']}', style: const TextStyle(fontSize: 13)),
                    Text('₹${a['fee']}', style: const TextStyle(fontSize: 13)),
                    Text('₹${a['free']}', style: const TextStyle(fontSize: 13)),
                    Text('${a['eta']} min', style: const TextStyle(fontSize: 13)),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: AdminSwitch(
                        value: a['live'] as bool,
                        semanticLabel: 'Area live',
                        onChanged: (v) => setState(() => a['live'] = v),
                      ),
                    ),
                  ];
                }).toList(),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        AdminPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _sectionTitle('Fees & charges', subtitle: 'Applied automatically at customer checkout'),
              const SizedBox(height: 14),
              _grid([
                _labeled('Packaging fee (₹)', _readOnly('5')),
                _labeled('Default delivery fee (₹)', _readOnly('25')),
                _labeled('Free delivery above (₹)', _readOnly('199')),
                _labeled('Tip options (₹)', _readOnly('10, 20, 30, 50')),
              ], minWidth: 180),
            ],
          ),
        ),
      ],
    );
  }

  Widget _readOnly(String value) => TextField(
        controller: TextEditingController(text: value),
        readOnly: true,
        decoration: const InputDecoration(fillColor: AppColors.adminBackground, suffixIcon: Icon(Icons.lock_outline_rounded, size: 16)),
      );

  // --------------------------------------------------------------- Banners

  void _addBanner() {
    final title = TextEditingController();
    final subtitle = TextEditingController();
    final tag = TextEditingController(text: 'NEW');
    String? categoryId = MockDataService.categories.isNotEmpty ? MockDataService.categories.first.id : null;
    String? error;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('New banner', style: TextStyle(fontWeight: FontWeight.w800)),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: title, decoration: const InputDecoration(labelText: 'Title')),
                const SizedBox(height: 12),
                TextField(controller: subtitle, decoration: const InputDecoration(labelText: 'Subtitle')),
                const SizedBox(height: 12),
                TextField(controller: tag, decoration: const InputDecoration(labelText: 'Offer tag (e.g. FLAT ₹50 OFF)')),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: categoryId,
                  decoration: const InputDecoration(labelText: 'Opens category'),
                  items: MockDataService.categories.map((c) => DropdownMenuItem(value: c.id, child: Text(c.name))).toList(),
                  onChanged: (v) => categoryId = v,
                ),
                if (error != null) ...[
                  const SizedBox(height: 10),
                  Text(error!, style: const TextStyle(color: AppColors.error, fontWeight: FontWeight.w700)),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () {
                if (title.text.trim().isEmpty) {
                  setD(() => error = 'Please enter a title');
                  return;
                }
                MockDataService.banners.add(BannerModel(
                  id: 'banner-${DateTime.now().millisecondsSinceEpoch}',
                  title: title.text.trim(),
                  subtitle: subtitle.text.trim(),
                  imageUrl: '',
                  discountText: tag.text.trim().isEmpty ? null : tag.text.trim(),
                  backgroundColorHex: '#0C8340',
                  categoryId: categoryId,
                  displayOrder: MockDataService.banners.length + 1,
                ));
                Navigator.pop(ctx);
                _loadBanners();
                _snack('Banner added to the home carousel');
              },
              child: const Text('Add banner'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _bannersSection() {
    return AdminPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _sectionTitle(
            'Home banners',
            subtitle: 'Shown in the customer app carousel, in this order',
            action: OutlinedButton(
              onPressed: _addBanner,
              style: OutlinedButton.styleFrom(
                backgroundColor: AppColors.primaryTint,
                foregroundColor: AppColors.primary,
                side: const BorderSide(color: AppColors.primary, width: 1.5),
              ),
              child: const Text('New banner'),
            ),
          ),
          const SizedBox(height: 14),
          if (_banners.isEmpty) const Text('No banners yet', style: TextStyle(color: AppColors.textSecondary)),
          for (var i = 0; i < _banners.length; i++)
            Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.border)),
              child: Row(
                children: [
                  Container(
                    width: 120,
                    height: 64,
                    padding: const EdgeInsets.all(8),
                    alignment: Alignment.bottomLeft,
                    decoration: BoxDecoration(
                      color: PromoBannerCard.backgroundFor(_banners[i]),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(_banners[i].discountText ?? '',
                        style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800)),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_banners[i].title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
                        Text(_banners[i].subtitle, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                      ],
                    ),
                  ),
                  Text('Order ${i + 1}', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                  if (MockDataService.banners.contains(_banners[i]))
                    IconButton(
                      tooltip: 'Remove banner',
                      onPressed: () {
                        MockDataService.banners.remove(_banners[i]);
                        _loadBanners();
                      },
                      icon: const Icon(Icons.delete_outline_rounded, color: AppColors.error),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // ----------------------------------------------------------------- Staff

  void _inviteStaff() {
    final name = TextEditingController();
    final email = TextEditingController();
    String role = 'Picker';
    String? error;
    const access = {'Picker': 'Live orders, inventory', 'Editor': 'Products, categories', 'Admin': 'Everything'};
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Invite staff', style: TextStyle(fontWeight: FontWeight.w800)),
          content: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: name, decoration: const InputDecoration(labelText: 'Full name')),
                const SizedBox(height: 12),
                TextField(controller: email, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'Work email')),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: role,
                  decoration: const InputDecoration(labelText: 'Role'),
                  items: access.keys.map((r) => DropdownMenuItem(value: r, child: Text('$r · ${access[r]}'))).toList(),
                  onChanged: (v) => role = v ?? role,
                ),
                if (error != null) ...[
                  const SizedBox(height: 10),
                  Text(error!, style: const TextStyle(color: AppColors.error, fontWeight: FontWeight.w700)),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () {
                if (name.text.trim().isEmpty || !email.text.contains('@')) {
                  setD(() => error = 'Enter a name and a valid email');
                  return;
                }
                setState(() => _staff.add({
                      'name': name.text.trim(),
                      'email': email.text.trim(),
                      'role': role,
                      'access': access[role]!,
                      'status': 'Invited',
                    }));
                Navigator.pop(ctx);
                _snack('Invitation sent to ${email.text.trim()}');
              },
              child: const Text('Send invite'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _staffSection() {
    return AdminPanel(
      padding: EdgeInsets.zero,
      clip: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 16, 14),
            child: _sectionTitle(
              'Staff & roles',
              action: ElevatedButton(onPressed: _inviteStaff, child: const Text('Invite staff')),
            ),
          ),
          AdminTable(
            columns: const ['Name', 'Email', 'Role', 'Access', 'Status'],
            flex: const [1.4, 1.8, 0.8, 1.6, 0.8],
            minWidth: 700,
            rows: _staff.map((s) {
              final active = s['status'] == 'Active';
              return <Widget>[
                Text(s['name']!, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
                Text(s['email']!, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13, color: AppColors.textBody)),
                Text(s['role']!, style: const TextStyle(fontSize: 13)),
                Text(s['access']!, style: const TextStyle(fontSize: 13, color: AppColors.textBody)),
                Align(
                  alignment: Alignment.centerLeft,
                  child: QbPill(
                    label: s['status']!,
                    background: active ? AppColors.primaryLight : AppColors.surfaceMuted,
                    foreground: active ? AppColors.primaryDeep : AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ];
            }).toList(),
          ),
        ],
      ),
    );
  }

  // --------------------------------------------------------- Notifications

  Widget _notificationsSection() {
    Widget item(String label, bool value, ValueChanged<bool> onChanged) => CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          controlAffinity: ListTileControlAffinity.leading,
          activeColor: AppColors.primary,
          value: value,
          onChanged: (v) => onChanged(v ?? false),
          title: Text(label, style: const TextStyle(fontSize: 14)),
        );

    return AdminPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _sectionTitle('Notifications'),
          const SizedBox(height: 6),
          item('Sound alert for every new order', _notifyNewOrder, (v) => setState(() => _notifyNewOrder = v)),
          item('Low stock alert when an item drops below its reorder level', _notifyLowStock,
              (v) => setState(() => _notifyLowStock = v)),
          item('Daily sales summary email', _notifyDaily, (v) => setState(() => _notifyDaily = v)),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: ElevatedButton(onPressed: () => _snack('Notification preferences saved'), child: const Text('Save')),
          ),
        ],
      ),
    );
  }
}
