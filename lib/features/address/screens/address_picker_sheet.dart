import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../models/address_model.dart';
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
  bool _isLoading = true;
  bool _isAddingNew = false;
  bool _isSaving = false;

  // New Address Form Controllers
  String _selectedType = 'Home';
  final _flatController = TextEditingController();
  final _areaController = TextEditingController();
  final _landmarkController = TextEditingController();
  final _pincodeController = TextEditingController(text: '560001');
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadAddresses();
  }

  @override
  void dispose() {
    _flatController.dispose();
    _areaController.dispose();
    _landmarkController.dispose();
    _pincodeController.dispose();
    super.dispose();
  }

  Future<void> _loadAddresses() async {
    setState(() => _isLoading = true);
    final addresses = await SupabaseService().getUserAddresses(widget.userId);
    if (mounted) {
      setState(() {
        _addresses = addresses;
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
        pincode: pincode.isNotEmpty ? pincode : '560001',
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
        maxHeight: MediaQuery.of(context).size.height * 0.85,
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
                  Text(
                    _isAddingNew ? 'Add New Address' : 'Select Delivery Address',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
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
            _buildNewAddressForm()
          else
            _buildAddressList(),
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

          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            decoration: BoxDecoration(
              color: isSelected ? AppColors.primaryLight.withValues(alpha: 0.3) : Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isSelected ? AppColors.primary : AppColors.border,
                width: isSelected ? 1.5 : 0.8,
              ),
            ),
            child: ListTile(
              onTap: () => Navigator.pop(context, addr),
              leading: CircleAvatar(
                backgroundColor: isSelected ? AppColors.primary : Colors.grey.shade100,
                child: Icon(
                  addr.type == 'Home'
                      ? Icons.home_rounded
                      : (addr.type == 'Work' ? Icons.work_rounded : Icons.place_rounded),
                  color: isSelected ? Colors.white : AppColors.textSecondary,
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
                  ? const Icon(Icons.check_circle, color: AppColors.primary, size: 22)
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

          // Flat / Building
          const Text('House / Flat / Floor No.', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          TextField(
            controller: _flatController,
            decoration: InputDecoration(
              hintText: 'e.g. Flat 301, 3rd Floor, Shanti Towers',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            ),
          ),
          const SizedBox(height: 14),

          // Area / Street
          const Text('Area / Street / Sector', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          TextField(
            controller: _areaController,
            decoration: InputDecoration(
              hintText: 'e.g. 100 Feet Road, Indiranagar',
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
              hintText: 'e.g. Near Metro Station / Park',
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
