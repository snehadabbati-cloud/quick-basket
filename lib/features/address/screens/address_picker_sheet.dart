import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../models/address_model.dart';
import '../../../models/delivery_area_model.dart';
import '../../../services/supabase_service.dart';

class AddressPickerSheet extends StatefulWidget {
  final AddressModel? selectedAddress;
  final String userId;

  const AddressPickerSheet({
    super.key,
    this.selectedAddress,
    required this.userId,
  });

  static Future<AddressModel?> show(
    BuildContext context, {
    AddressModel? currentAddress,
    required String userId,
  }) {
    return showModalBottomSheet<AddressModel>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => AddressPickerSheet(
        selectedAddress: currentAddress,
        userId: userId,
      ),
    );
  }

  @override
  State<AddressPickerSheet> createState() => _AddressPickerSheetState();
}

class _AddressPickerSheetState extends State<AddressPickerSheet> {
  List<AddressModel> _addresses = [];
  Map<String, ServiceabilityResult> _serviceabilityMap = {};
  bool _isLoading = true;
  bool _isAddingNew = false;
  bool _isSaving = false;

  // New Address Form Controllers
  String _selectedType = 'Home';
  final _flatController = TextEditingController();
  final _areaController = TextEditingController();
  final _landmarkController = TextEditingController();
  final _pincodeController = TextEditingController(text: '500090');
  ServiceabilityResult? _pincodeCheckResult;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadAddresses();
    _validatePincode('500090');
  }

  @override
  void dispose() {
    _flatController.dispose();
    _areaController.dispose();
    _landmarkController.dispose();
    _pincodeController.dispose();
    super.dispose();
  }

  Future<void> _validatePincode(String pin) async {
    final res = await SupabaseService().checkServiceability(pincode: pin);
    if (mounted) {
      setState(() => _pincodeCheckResult = res);
    }
  }

  Future<void> _loadAddresses() async {
    setState(() => _isLoading = true);
    final addresses = await SupabaseService().getUserAddresses(widget.userId);
    final Map<String, ServiceabilityResult> results = {};
    for (final a in addresses) {
      results[a.id] = await SupabaseService().checkServiceability(
        pincode: a.pincode,
        lat: a.latitude,
        lng: a.longitude,
      );
    }

    if (mounted) {
      setState(() {
        _addresses = addresses;
        _serviceabilityMap = results;
        _isLoading = false;
      });
    }
  }

  Future<void> _saveNewAddress() async {
    final flat = _flatController.text.trim();
    final area = _areaController.text.trim();
    final landmark = _landmarkController.text.trim();
    final pincode = _pincodeController.text.trim();

    if (flat.isEmpty || area.isEmpty) {
      setState(() => _errorMessage = 'Please enter house/flat and area details');
      return;
    }

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      final newAddress = AddressModel(
        id: 'addr-${DateTime.now().millisecondsSinceEpoch}',
        userId: widget.userId,
        type: _selectedType,
        flatHouseNumber: flat,
        areaStreet: area,
        landmark: landmark.isNotEmpty ? landmark : null,
        city: 'Hyderabad',
        state: 'Telangana',
        pincode: pincode.isNotEmpty ? pincode : '500090',
        isDefault: _addresses.isEmpty,
      );

      final saved = await SupabaseService().saveAddress(newAddress);
      if (mounted) {
        Navigator.pop(context, saved);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSaving = false;
          _errorMessage = 'Failed to save address: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.88,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.location_on_rounded, color: AppColors.primary, size: 24),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _isAddingNew ? 'Add New Address' : 'Select Delivery Address',
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const Text(
                        'Nizampet Dark Store Hub (500090)',
                        style: TextStyle(fontSize: 11, color: AppColors.textSecondary, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ],
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
          const SizedBox(height: 12),

          if (_isAddingNew)
            Flexible(child: _buildNewAddressForm())
          else
            Flexible(child: SingleChildScrollView(child: _buildAddressList())),
        ],
      ),
    );
  }

  Widget _buildAddressList() {
    if (_isLoading) {
      return const SizedBox(
        height: 160,
        child: Center(child: CircularProgressIndicator(color: AppColors.primary)),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // List of saved addresses
        ..._addresses.map((addr) {
          final isSelected = widget.selectedAddress?.id == addr.id ||
              (widget.selectedAddress == null && addr.isDefault);
          final srv = _serviceabilityMap[addr.id];
          final isServiceable = srv?.isServiceable ?? true;

          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            decoration: BoxDecoration(
              color: isSelected
                  ? (isServiceable ? AppColors.primaryLight.withValues(alpha: 0.3) : const Color(0xFFFFF3E0))
                  : Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isSelected
                    ? (isServiceable ? AppColors.primary : const Color(0xFFFFB74D))
                    : AppColors.border,
                width: isSelected ? 1.5 : 0.8,
              ),
            ),
            child: ListTile(
              onTap: () => Navigator.pop(context, addr),
              leading: CircleAvatar(
                backgroundColor: isSelected
                    ? (isServiceable ? AppColors.primary : const Color(0xFFE65100))
                    : (isServiceable ? Colors.grey.shade100 : const Color(0xFFFFE0B2)),
                child: Icon(
                  addr.type == 'Home'
                      ? Icons.home_rounded
                      : (addr.type == 'Work' ? Icons.work_rounded : Icons.place_rounded),
                  color: isSelected ? Colors.white : (isServiceable ? AppColors.textSecondary : const Color(0xFFE65100)),
                  size: 20,
                ),
              ),
              title: Row(
                children: [
                  Text(
                    addr.type,
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                  ),
                  if (addr.isDefault) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        'DEFAULT',
                        style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: Colors.white),
                      ),
                    ),
                  ],
                  const Spacer(),
                  // Serviceability Badge
                  if (isServiceable)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.primaryLight,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.flash_on_rounded, size: 11, color: AppColors.primaryDeep),
                          const SizedBox(width: 2),
                          Text(
                            '${srv?.estimatedMinutes ?? 12} MINS',
                            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: AppColors.primaryDeep),
                          ),
                        ],
                      ),
                    )
                  else
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFEBEE),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.warning_amber_rounded, size: 11, color: AppColors.error),
                          SizedBox(width: 2),
                          Text(
                            'OUT OF ZONE',
                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: AppColors.error),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  addr.formattedAddress,
                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, height: 1.3),
                ),
              ),
              trailing: isSelected
                  ? Icon(
                      Icons.check_circle,
                      color: isServiceable ? AppColors.primary : const Color(0xFFE65100),
                      size: 22,
                    )
                  : null,
            ),
          );
        }),

        const SizedBox(height: 8),

        // Add New Address Button
        OutlinedButton.icon(
          onPressed: () => setState(() => _isAddingNew = true),
          icon: const Icon(Icons.add_rounded, color: AppColors.primary),
          label: const Text(
            'Add New Delivery Address',
            style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.primary),
          ),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(double.infinity, 48),
            side: const BorderSide(color: AppColors.primary, width: 1.2),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ],
    );
  }

  Widget _buildNewAddressForm() {
    final srv = _pincodeCheckResult;
    final isPinServiceable = srv?.isServiceable ?? true;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_errorMessage != null) ...[
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(_errorMessage!, style: const TextStyle(color: AppColors.error, fontSize: 12)),
            ),
            const SizedBox(height: 12),
          ],

          // Type Chips
          const Text('Save Address As', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Row(
            children: ['Home', 'Work', 'Other'].map((type) {
              final isSel = _selectedType == type;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(type),
                  selected: isSel,
                  onSelected: (val) => setState(() => _selectedType = type),
                  selectedColor: AppColors.primary,
                  labelStyle: TextStyle(
                    color: isSel ? Colors.white : AppColors.textPrimary,
                    fontWeight: isSel ? FontWeight.w800 : FontWeight.w600,
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 14),

          // Pincode with live geofence verification
          const Text('Pincode (Telangana)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          TextField(
            controller: _pincodeController,
            keyboardType: TextInputType.number,
            onChanged: (val) {
              if (val.trim().length >= 6) {
                _validatePincode(val.trim());
              }
            },
            decoration: InputDecoration(
              hintText: 'e.g. 500090, 500072, 500085',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              suffixIcon: IconButton(
                icon: const Icon(Icons.check_circle_outline, size: 20),
                onPressed: () => _validatePincode(_pincodeController.text.trim()),
              ),
            ),
          ),
          if (srv != null) ...[
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: isPinServiceable ? AppColors.primaryLight : const Color(0xFFFFEBEE),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    isPinServiceable ? Icons.check_circle_rounded : Icons.info_outline_rounded,
                    size: 15,
                    color: isPinServiceable ? AppColors.primaryDeep : AppColors.error,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      isPinServiceable
                          ? '✅ ${srv.matchedArea?.name ?? 'Nizampet Area'} · ${srv.estimatedMinutes} min delivery available'
                          : '⚠️ Outside delivery zone (Quick Basket delivers within 5 km of Nizampet 500090)',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: isPinServiceable ? AppColors.primaryDeep : AppColors.error,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 14),

          // Flat / Building
          const Text('House / Flat / Floor No.', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          TextField(
            controller: _flatController,
            decoration: InputDecoration(
              hintText: 'e.g. Flat 301, Sri Sai Residency',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            ),
          ),
          const SizedBox(height: 14),

          // Area / Street
          const Text('Area / Street / Colony', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          TextField(
            controller: _areaController,
            decoration: InputDecoration(
              hintText: 'e.g. Road No. 1, Pragathi Nagar, Nizampet',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            ),
          ),
          const SizedBox(height: 14),

          // Landmark
          const Text('Nearby Landmark (Optional)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          TextField(
            controller: _landmarkController,
            decoration: InputDecoration(
              hintText: 'e.g. Near Pragathi Nagar Lake / Gram Panchayat',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            ),
          ),
          const SizedBox(height: 20),

          // Buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => setState(() => _isAddingNew = false),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 48),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text('Back'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _saveNewAddress,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    minimumSize: const Size(double.infinity, 48),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: _isSaving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : const Text(
                          'Save & Deliver Here',
                          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                        ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
