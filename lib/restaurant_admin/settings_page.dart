import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import '../core/constants/app_colors.dart';

class SettingsPage extends StatefulWidget {
  final String restaurantId;

  const SettingsPage({super.key, required this.restaurantId});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  // Restaurant Information Controllers
  final _restaurantNameController = TextEditingController();
  final _addressController = TextEditingController();
  final _contactNumberController = TextEditingController();
  final _whatsappNumberController = TextEditingController();
  final _gstNumberController = TextEditingController();

  // Operating Hours
  TimeOfDay _openingTime = const TimeOfDay(hour: 9, minute: 0);
  TimeOfDay _closingTime = const TimeOfDay(hour: 22, minute: 0);

  // Billing Settings
  bool _enableGst = false;
  bool _enablePackagingCharge = false;
  final _gstPercentageController = TextEditingController();
  final _cessPercentageController = TextEditingController();
  final _packagingChargeController = TextEditingController();

  // Additional Notes
  List<TextEditingController> _noteControllers = [];

  // Restaurant Logo
  String? _existingLogoUrl;
  Uint8List? _newLogoBytes;
  bool _isUploadingLogo = false;
  final String _imgBBApiKey = "a923bc17d28cd6fe1be417700456eb69";

  // Responsive helpers
  bool get _isWeb => kIsWeb || MediaQuery.of(context).size.width > 768;
  double get _contentMaxWidth => 860;

  @override
  void initState() {
    super.initState();
    _loadRestaurantInfo();
  }

  @override
  void dispose() {
    _restaurantNameController.dispose();
    _addressController.dispose();
    _contactNumberController.dispose();
    _whatsappNumberController.dispose();
    _gstNumberController.dispose();
    _gstPercentageController.dispose();
    _cessPercentageController.dispose();
    _packagingChargeController.dispose();
    for (var c in _noteControllers) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _loadRestaurantInfo() async {
    try {
      DocumentSnapshot doc = await FirebaseFirestore.instance
          .collection('restaurants')
          .doc(widget.restaurantId)
          .get();

      if (doc.exists) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        setState(() {
          _restaurantNameController.text = data['restaurantName'] ?? '';
          _addressController.text = data['address'] ?? '';
          _contactNumberController.text = data['contactNumber'] ?? '';
          _whatsappNumberController.text = data['whatsappNumber'] ?? '';
          _gstNumberController.text = data['gstNumber'] ?? '';

          if (data['openingTime'] != null) {
            List<String> parts = (data['openingTime'] as String).split(':');
            _openingTime = TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
          }
          if (data['closingTime'] != null) {
            List<String> parts = (data['closingTime'] as String).split(':');
            _closingTime = TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
          }

          _enableGst = data['enableGst'] ?? false;
          _enablePackagingCharge = data['enablePackagingCharge'] ?? false;
          _gstPercentageController.text = data['gstPercentage'] ?? '';
          _cessPercentageController.text = data['cessPercentage'] ?? '';
          _packagingChargeController.text = data['packagingCharge'] ?? '';

          List<dynamic> notesData = data['additionalNotes'] ?? [];
          _noteControllers = notesData
              .map((n) => TextEditingController(text: n.toString()))
              .toList();

          _existingLogoUrl = data['logoUrl'] as String?;
        });
      }
    } catch (e) {
      debugPrint('Error loading restaurant info: $e');
    }
  }

  Future<void> _pickLogo() async {
    final picker = ImagePicker();
    final XFile? image = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 512,
      maxHeight: 512,
    );
    if (image != null) {
      final bytes = await image.readAsBytes();
      setState(() => _newLogoBytes = bytes);
    }
  }

  Future<String?> _uploadLogoToImgBB() async {
    if (_newLogoBytes == null) return null;
    try {
      var request = http.MultipartRequest(
        'POST',
        Uri.parse("https://api.imgbb.com/1/upload?key=$_imgBBApiKey"),
      );
      request.files.add(
        http.MultipartFile.fromBytes('image', _newLogoBytes!, filename: "logo.jpg"),
      );
      var response = await request.send();
      var responseData = await response.stream.bytesToString();
      var jsonData = json.decode(responseData);
      return jsonData['data']['url'] as String?;
    } catch (e) {
      if (kDebugMode) print("LOGO UPLOAD ERROR: $e");
      return null;
    }
  }

  Future<void> _saveRestaurantInfo() async {
    try {
      // Upload new logo if picked
      String? logoUrl = _existingLogoUrl;
      if (_newLogoBytes != null) {
        setState(() => _isUploadingLogo = true);
        logoUrl = await _uploadLogoToImgBB();
        if (logoUrl != null) {
          setState(() {
            _existingLogoUrl = logoUrl;
            _newLogoBytes = null;
          });
        }
        setState(() => _isUploadingLogo = false);
      }

      await FirebaseFirestore.instance
          .collection('restaurants')
          .doc(widget.restaurantId)
          .set({
        'restaurantName': _restaurantNameController.text.trim(),
        'address': _addressController.text.trim(),
        'contactNumber': _contactNumberController.text.trim(),
        'whatsappNumber': _whatsappNumberController.text.trim(),
        'gstNumber': _gstNumberController.text.trim(),
        'openingTime':
        '${_openingTime.hour.toString().padLeft(2, '0')}:${_openingTime.minute.toString().padLeft(2, '0')}',
        'closingTime':
        '${_closingTime.hour.toString().padLeft(2, '0')}:${_closingTime.minute.toString().padLeft(2, '0')}',
        'enableGst': _enableGst,
        'enablePackagingCharge': _enablePackagingCharge,
        'gstPercentage': _gstPercentageController.text.trim(),
        'cessPercentage': _cessPercentageController.text.trim(),
        'packagingCharge': _packagingChargeController.text.trim(),
        'additionalNotes':
        _noteControllers.map((c) => c.text.trim()).toList(),
        if (logoUrl != null) 'logoUrl': logoUrl,
        if (logoUrl != null) 'logo': logoUrl,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.check_circle_outline, color: Colors.white, size: 18),
                SizedBox(width: 8),
                Text("Restaurant information saved successfully!",
                    style: TextStyle(fontSize: 14)),
              ],
            ),
            backgroundColor: const Color(0xFF22C55E),
            behavior: SnackBarBehavior.floating,
            shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            margin: const EdgeInsets.all(16),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white, size: 18),
                const SizedBox(width: 8),
                Expanded(
                    child: Text("Error: $e",
                        style: const TextStyle(fontSize: 14))),
              ],
            ),
            backgroundColor: const Color(0xFFEF4444),
            behavior: SnackBarBehavior.floating,
            shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            margin: const EdgeInsets.all(16),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildPageHeader(),
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(
                  horizontal: _isWeb ? 32 : 20.w,
                  vertical: _isWeb ? 24 : 20.h,
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: _contentMaxWidth),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildLogoSection(),
                        SizedBox(height: _isWeb ? 20 : 18.h),
                        _buildRestaurantInformationSection(),
                        SizedBox(height: _isWeb ? 20 : 18.h),
                        _buildOperatingHoursSection(),
                        SizedBox(height: _isWeb ? 20 : 18.h),
                        _buildBillingSettingsSection(),
                        SizedBox(height: _isWeb ? 20 : 18.h),
                        _buildAdditionalNotesSection(),
                        SizedBox(height: _isWeb ? 28 : 24.h),
                        _buildSaveButton(),
                        SizedBox(height: _isWeb ? 32 : 24.h),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Page Header ──────────────────────────────────────────────────────────
  Widget _buildPageHeader() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: _isWeb ? 32 : 20.w,
        vertical: _isWeb ? 20 : 16.h,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: Color(0xFFE5E7EB), width: 1),
        ),
      ),
      child: Row(
        children: [
          if (!_isWeb) ...[
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                width: 36.w,
                height: 36.w,
                decoration: BoxDecoration(
                  color: const Color(0xFFF3F4F6),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.arrow_back_ios_new,
                    size: 16.sp, color: const Color(0xFF374151)),
              ),
            ),
            SizedBox(width: 12.w),
          ],
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Restaurant Settings",
                style: TextStyle(
                  fontSize: _isWeb ? 22 : 18.sp,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF111827),
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                "Manage your restaurant information",
                style: TextStyle(
                  fontSize: _isWeb ? 14 : 12.sp,
                  color: const Color(0xFF6B7280),
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─── Section Card Shell ───────────────────────────────────────────────────
  Widget _buildSectionCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required List<Widget> children,
  }) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(_isWeb ? 24 : 18.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(_isWeb ? 12 : 10.r),
        border: Border.all(color: const Color(0xFFE5E7EB), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section header
          Row(
            children: [
              Container(
                width: _isWeb ? 38 : 34.w,
                height: _isWeb ? 38 : 34.w,
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: iconColor, size: _isWeb ? 20 : 18.sp),
              ),
              SizedBox(width: _isWeb ? 12 : 10.w),
              Text(
                title,
                style: TextStyle(
                  fontSize: _isWeb ? 16 : 15.sp,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF111827),
                ),
              ),
            ],
          ),
          Padding(
            padding: EdgeInsets.only(top: _isWeb ? 20 : 16.h),
            child: const Divider(color: Color(0xFFF3F4F6), height: 1),
          ),
          SizedBox(height: _isWeb ? 20 : 16.h),
          ...children,
        ],
      ),
    );
  }

  // ─── Restaurant Logo ──────────────────────────────────────────────────────
  Widget _buildLogoSection() {
    final bool hasLogo = _newLogoBytes != null ||
        (_existingLogoUrl != null && _existingLogoUrl!.isNotEmpty);

    return _buildSectionCard(
      icon: Icons.storefront_outlined,
      iconColor: const Color(0xFFC4622D),
      title: "Restaurant Logo",
      children: [
        _isWeb
            ? Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            _buildLogoPreview(hasLogo),
            const SizedBox(width: 24),
            Expanded(child: _buildLogoActions(hasLogo)),
          ],
        )
            : Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(child: _buildLogoPreview(hasLogo)),
            SizedBox(height: 16.h),
            _buildLogoActions(hasLogo),
          ],
        ),
      ],
    );
  }

  Widget _buildLogoPreview(bool hasLogo) {
    return Stack(
      children: [
        Container(
          width: _isWeb ? 110 : 100.w,
          height: _isWeb ? 110 : 100.w,
          decoration: BoxDecoration(
            color: const Color(0xFFF9FAFB),
            borderRadius: BorderRadius.circular(_isWeb ? 16 : 14.r),
            border: Border.all(
              color: hasLogo
                  ? const Color(0xFFC4622D).withOpacity(0.5)
                  : const Color(0xFFD1D5DB),
              width: hasLogo ? 2 : 1,
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(_isWeb ? 14 : 12.r),
            child: _newLogoBytes != null
                ? Image.memory(_newLogoBytes!, fit: BoxFit.cover,
                width: double.infinity, height: double.infinity)
                : (_existingLogoUrl != null && _existingLogoUrl!.isNotEmpty
                ? Image.network(
              _existingLogoUrl!,
              fit: BoxFit.cover,
              width: double.infinity,
              height: double.infinity,
              loadingBuilder: (ctx, child, progress) {
                if (progress == null) return child;
                return const Center(
                  child: CircularProgressIndicator(strokeWidth: 2),
                );
              },
              errorBuilder: (ctx, _, __) => _logoPlaceholder(),
            )
                : _logoPlaceholder()),
          ),
        ),
        if (hasLogo)
          Positioned(
            bottom: 4,
            right: 4,
            child: Container(
              width: 24,
              height: 24,
              decoration: const BoxDecoration(
                color: Color(0xFFC4622D),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check, color: Colors.white, size: 14),
            ),
          ),
      ],
    );
  }

  Widget _logoPlaceholder() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.storefront_outlined,
            size: _isWeb ? 32 : 28.sp,
            color: const Color(0xFF9CA3AF)),
        SizedBox(height: _isWeb ? 6 : 4.h),
        Text(
          "No Logo",
          style: TextStyle(
            fontSize: _isWeb ? 11 : 10.sp,
            color: const Color(0xFF9CA3AF),
          ),
        ),
      ],
    );
  }

  Widget _buildLogoActions(bool hasLogo) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          hasLogo ? "Update Restaurant Logo" : "Upload Restaurant Logo",
          style: TextStyle(
            fontSize: _isWeb ? 14 : 13.sp,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF111827),
          ),
        ),
        SizedBox(height: _isWeb ? 4 : 4.h),
        Text(
          "This logo appears on bills and the customer menu. Use a square image for best results (PNG or JPG, max 512×512px).",
          style: TextStyle(
            fontSize: _isWeb ? 12 : 11.sp,
            color: const Color(0xFF6B7280),
            height: 1.5,
          ),
        ),
        SizedBox(height: _isWeb ? 14 : 12.h),
        Row(
          children: [
            // Pick / Change button
            GestureDetector(
              onTap: _isUploadingLogo ? null : _pickLogo,
              child: Container(
                padding: EdgeInsets.symmetric(
                  horizontal: _isWeb ? 16 : 14.w,
                  vertical: _isWeb ? 10 : 9.h,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF7ED),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: const Color(0xFFC4622D).withOpacity(0.4),
                    width: 1.5,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.upload_outlined,
                        color: Color(0xFFC4622D), size: 16),
                    const SizedBox(width: 6),
                    Text(
                      hasLogo ? "Change Logo" : "Upload Logo",
                      style: TextStyle(
                        fontSize: _isWeb ? 13 : 12.sp,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFFC4622D),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Remove button — only shown when a logo exists
            if (hasLogo) ...[
              SizedBox(width: _isWeb ? 10 : 8.w),
              GestureDetector(
                onTap: () => setState(() {
                  _newLogoBytes = null;
                  _existingLogoUrl = null;
                }),
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: _isWeb ? 14 : 12.w,
                    vertical: _isWeb ? 10 : 9.h,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF2F2),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFFECACA)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.delete_outline,
                          color: Color(0xFFEF4444), size: 16),
                      const SizedBox(width: 6),
                      Text(
                        "Remove",
                        style: TextStyle(
                          fontSize: _isWeb ? 13 : 12.sp,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFFEF4444),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
        // "Pending upload" badge when user picked but not yet saved
        if (_newLogoBytes != null) ...[
          SizedBox(height: _isWeb ? 10 : 8.h),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF0E6),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                  color: const Color(0xFFC4622D).withOpacity(0.3)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.info_outline,
                    size: 13, color: Color(0xFFC4622D)),
                const SizedBox(width: 5),
                Text(
                  "New logo will be saved when you tap Save",
                  style: TextStyle(
                    fontSize: _isWeb ? 11 : 10.sp,
                    color: const Color(0xFFC4622D),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  // ─── Restaurant Information ───────────────────────────────────────────────
  Widget _buildRestaurantInformationSection() {
    return _buildSectionCard(
      icon: Icons.info_outline_rounded,
      iconColor: AppColors.primary,
      title: "Restaurant Information",
      children: [
        _buildField(
          label: "Restaurant Name",
          controller: _restaurantNameController,
          icon: Icons.restaurant_menu_outlined,
          hint: "Enter restaurant name",
        ),
        SizedBox(height: _isWeb ? 16 : 14.h),
        _buildField(
          label: "Address",
          controller: _addressController,
          icon: Icons.location_on_outlined,
          hint: "Enter restaurant address",
        ),
        SizedBox(height: _isWeb ? 16 : 14.h),
        _buildField(
          label: "Contact Number",
          controller: _contactNumberController,
          icon: Icons.phone_outlined,
          hint: "Enter contact number",
          keyboardType: TextInputType.phone,
        ),
        SizedBox(height: _isWeb ? 16 : 14.h),
        _buildField(
          label: "WhatsApp Number",
          controller: _whatsappNumberController,
          icon: Icons.chat_bubble_outline_rounded,
          hint: "Enter WhatsApp number",
          keyboardType: TextInputType.phone,
        ),
        SizedBox(height: _isWeb ? 16 : 14.h),
        _buildField(
          label: "GST Number",
          controller: _gstNumberController,
          icon: Icons.receipt_long_outlined,
          hint: "Enter GST number",
        ),
      ],
    );
  }

  // ─── Operating Hours ──────────────────────────────────────────────────────
  Widget _buildOperatingHoursSection() {
    return _buildSectionCard(
      icon: Icons.schedule_outlined,
      iconColor: const Color(0xFF10B981),
      title: "Operating Hours",
      children: [
        _isWeb
            ? Row(
          children: [
            Expanded(child: _buildTimePickerTile("Opening Time", 'opening')),
            const SizedBox(width: 16),
            Expanded(child: _buildTimePickerTile("Closing Time", 'closing')),
          ],
        )
            : Column(
          children: [
            _buildTimePickerTile("Opening Time", 'opening'),
            SizedBox(height: 12.h),
            _buildTimePickerTile("Closing Time", 'closing'),
          ],
        ),
      ],
    );
  }

  Widget _buildTimePickerTile(String label, String type) {
    final TimeOfDay time = type == 'opening' ? _openingTime : _closingTime;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: _isWeb ? 13 : 12.sp,
            fontWeight: FontWeight.w500,
            color: const Color(0xFF374151),
          ),
        ),
        SizedBox(height: _isWeb ? 6 : 6.h),
        GestureDetector(
          onTap: () => _selectTime(context, type),
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: _isWeb ? 14 : 12.w,
              vertical: _isWeb ? 12 : 11.h,
            ),
            decoration: BoxDecoration(
              color: const Color(0xFFF9FAFB),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFD1D5DB), width: 1),
            ),
            child: Row(
              children: [
                const Icon(Icons.access_time_outlined,
                    size: 18, color: Color(0xFF9CA3AF)),
                const SizedBox(width: 10),
                Text(
                  _formatTime(time),
                  style: TextStyle(
                    fontSize: _isWeb ? 14 : 13.sp,
                    color: const Color(0xFF111827),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const Spacer(),
                const Icon(Icons.keyboard_arrow_down_rounded,
                    size: 18, color: Color(0xFF9CA3AF)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ─── Billing Settings ─────────────────────────────────────────────────────
  Widget _buildBillingSettingsSection() {
    return _buildSectionCard(
      icon: Icons.account_balance_wallet_outlined,
      iconColor: const Color(0xFF8B5CF6),
      title: "Billing Settings",
      children: [
        _buildToggleRow(
          title: "Enable GST",
          description: "Apply GST on all orders.",
          value: _enableGst,
          onChanged: (v) => setState(() => _enableGst = v),
        ),
        if (_enableGst) ...[
          SizedBox(height: _isWeb ? 16 : 14.h),
          _isWeb
              ? Row(
            children: [
              Expanded(
                  child: _buildPercentField(
                      controller: _gstPercentageController,
                      label: "GST %")),
              const SizedBox(width: 16),
              Expanded(
                  child: _buildPercentField(
                      controller: _cessPercentageController,
                      label: "Cess %")),
            ],
          )
              : Column(
            children: [
              _buildPercentField(
                  controller: _gstPercentageController, label: "GST %"),
              SizedBox(height: 12.h),
              _buildPercentField(
                  controller: _cessPercentageController, label: "Cess %"),
            ],
          ),
        ],
        SizedBox(height: _isWeb ? 16 : 14.h),
        _buildToggleRow(
          title: "Enable Packaging Charge",
          description: "Add packaging charge for parcel orders.",
          value: _enablePackagingCharge,
          onChanged: (v) => setState(() => _enablePackagingCharge = v),
        ),
        if (_enablePackagingCharge) ...[
          SizedBox(height: _isWeb ? 16 : 14.h),
          _buildCurrencyField(
              controller: _packagingChargeController,
              label: "Packaging Charge"),
        ],
      ],
    );
  }

  // ─── Additional Notes ─────────────────────────────────────────────────────
  Widget _buildAdditionalNotesSection() {
    return _buildSectionCard(
      icon: Icons.note_alt_outlined,
      iconColor: const Color(0xFFF97316),
      title: "Additional Notes",
      children: [
        ..._noteControllers.asMap().entries.map((entry) {
          return Padding(
            padding: EdgeInsets.only(bottom: _isWeb ? 12 : 10.h),
            child: _buildNoteField(entry.value, entry.key),
          );
        }),
        GestureDetector(
          onTap: _addNote,
          child: Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(vertical: _isWeb ? 12 : 11.h),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF7ED),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                  color: const Color(0xFFFED7AA), width: 1.5),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.add_circle_outline,
                    color: Color(0xFFF97316), size: 18),
                const SizedBox(width: 8),
                Text(
                  "Add Note",
                  style: TextStyle(
                    fontSize: _isWeb ? 14 : 13.sp,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFFF97316),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ─── Save Button ──────────────────────────────────────────────────────────
  Widget _buildSaveButton() {
    return SizedBox(
      width: double.infinity,
      height: _isWeb ? 48 : 48.h,
      child: ElevatedButton.icon(
        onPressed: _saveRestaurantInfo,
        icon: const Icon(Icons.save_outlined, size: 18, color: Colors.white),
        label: const Text(
          "Save Restaurant Information",
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: Colors.white,
            letterSpacing: 0.2,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      ),
    );
  }

  // ─── Reusable Widgets ─────────────────────────────────────────────────────
  Widget _buildField({
    required String label,
    required TextEditingController controller,
    required IconData icon,
    required String hint,
    TextInputType? keyboardType,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: _isWeb ? 13 : 12.sp,
            fontWeight: FontWeight.w500,
            color: const Color(0xFF374151),
          ),
        ),
        SizedBox(height: _isWeb ? 6 : 6.h),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          style: TextStyle(
            fontSize: _isWeb ? 14 : 13.sp,
            color: const Color(0xFF111827),
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: Color(0xFFBDBDBD), fontSize: 14),
            prefixIcon: Icon(icon, size: 18, color: const Color(0xFF9CA3AF)),
            contentPadding: EdgeInsets.symmetric(
                horizontal: _isWeb ? 14 : 12.w,
                vertical: _isWeb ? 12 : 11.h),
            filled: true,
            fillColor: const Color(0xFFF9FAFB),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFFD1D5DB)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFFD1D5DB)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: AppColors.primary, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildToggleRow({
    required String title,
    required String description,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(
          horizontal: _isWeb ? 14 : 12.w, vertical: _isWeb ? 12 : 11.h),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: _isWeb ? 14 : 13.sp,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFF111827),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: _isWeb ? 12 : 11.sp,
                    color: const Color(0xFF6B7280),
                  ),
                ),
              ],
            ),
          ),
          Transform.scale(
            scale: 0.85,
            child: Switch(
              value: value,
              onChanged: onChanged,
              activeColor: AppColors.primary,
              activeTrackColor: AppColors.primary.withOpacity(0.25),
              inactiveThumbColor: const Color(0xFFD1D5DB),
              inactiveTrackColor: const Color(0xFFE5E7EB),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPercentField({
    required TextEditingController controller,
    required String label,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: _isWeb ? 13 : 12.sp,
            fontWeight: FontWeight.w500,
            color: const Color(0xFF374151),
          ),
        ),
        SizedBox(height: _isWeb ? 6 : 6.h),
        TextFormField(
          controller: controller,
          keyboardType: TextInputType.number,
          style: TextStyle(fontSize: _isWeb ? 14 : 13.sp),
          decoration: InputDecoration(
            suffixText: '%',
            suffixStyle: const TextStyle(color: Color(0xFF6B7280), fontWeight: FontWeight.w500),
            contentPadding: EdgeInsets.symmetric(
                horizontal: _isWeb ? 14 : 12.w,
                vertical: _isWeb ? 12 : 11.h),
            filled: true,
            fillColor: const Color(0xFFF9FAFB),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFFD1D5DB)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFFD1D5DB)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: AppColors.primary, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCurrencyField({
    required TextEditingController controller,
    required String label,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: _isWeb ? 13 : 12.sp,
            fontWeight: FontWeight.w500,
            color: const Color(0xFF374151),
          ),
        ),
        SizedBox(height: _isWeb ? 6 : 6.h),
        TextFormField(
          controller: controller,
          keyboardType: TextInputType.number,
          style: TextStyle(fontSize: _isWeb ? 14 : 13.sp),
          decoration: InputDecoration(
            prefixText: '₹ ',
            prefixStyle: const TextStyle(
                color: Color(0xFF374151), fontWeight: FontWeight.w500),
            contentPadding: EdgeInsets.symmetric(
                horizontal: _isWeb ? 14 : 12.w,
                vertical: _isWeb ? 12 : 11.h),
            filled: true,
            fillColor: const Color(0xFFF9FAFB),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFFD1D5DB)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFFD1D5DB)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: AppColors.primary, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildNoteField(TextEditingController controller, int index) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: TextFormField(
            controller: controller,
            maxLines: 2,
            style: TextStyle(fontSize: _isWeb ? 14 : 13.sp),
            decoration: InputDecoration(
              hintText: 'Enter note ${index + 1}',
              hintStyle:
              const TextStyle(color: Color(0xFFBDBDBD), fontSize: 13),
              contentPadding: EdgeInsets.symmetric(
                  horizontal: _isWeb ? 14 : 12.w,
                  vertical: _isWeb ? 12 : 10.h),
              filled: true,
              fillColor: const Color(0xFFF9FAFB),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFFD1D5DB)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFFD1D5DB)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(
                    color: Color(0xFFF97316), width: 1.5),
              ),
            ),
          ),
        ),
        SizedBox(width: _isWeb ? 10 : 8.w),
        GestureDetector(
          onTap: () => _removeNote(index),
          child: Container(
            width: _isWeb ? 40 : 38.w,
            height: _isWeb ? 40 : 38.w,
            margin: const EdgeInsets.only(top: 1),
            decoration: BoxDecoration(
              color: const Color(0xFFFEF2F2),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFFECACA)),
            ),
            child: const Icon(Icons.delete_outline,
                color: Color(0xFFEF4444), size: 18),
          ),
        ),
      ],
    );
  }

  // ─── Time Picker ──────────────────────────────────────────────────────────
  Future<void> _selectTime(BuildContext context, String type) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: type == 'opening' ? _openingTime : _closingTime,
      builder: (ctx, child) => MediaQuery(
        data: MediaQuery.of(ctx).copyWith(alwaysUse24HourFormat: false),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() {
        if (type == 'opening') {
          _openingTime = picked;
        } else {
          _closingTime = picked;
        }
      });
    }
  }

  String _formatTime(TimeOfDay time) {
    final h = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
    final m = time.minute.toString().padLeft(2, '0');
    final period = time.period == DayPeriod.am ? 'AM' : 'PM';
    return '$h:$m $period';
  }

  void _addNote() {
    setState(() => _noteControllers.add(TextEditingController()));
  }

  void _removeNote(int index) {
    setState(() {
      _noteControllers[index].dispose();
      _noteControllers.removeAt(index);
    });
  }
}