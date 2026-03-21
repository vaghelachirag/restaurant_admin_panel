import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
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
  List<String> _notes = [];

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
    for (var controller in _noteControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _loadRestaurantInfo() async {
    try {
      DocumentSnapshot restaurantDoc = await FirebaseFirestore.instance
          .collection('restaurants')
          .doc(widget.restaurantId)
          .get();

      if (restaurantDoc.exists) {
        Map<String, dynamic> data = restaurantDoc.data() as Map<String, dynamic>;
        setState(() {
          _restaurantNameController.text = data['restaurantName'] ?? '';
          _addressController.text = data['address'] ?? '';
          _contactNumberController.text = data['contactNumber'] ?? '';
          _whatsappNumberController.text = data['whatsappNumber'] ?? '';
          _gstNumberController.text = data['gstNumber'] ?? '';
          
          // Parse opening time
          if (data['openingTime'] != null) {
            List<String> timeParts = (data['openingTime'] as String).split(':');
            _openingTime = TimeOfDay(
              hour: int.parse(timeParts[0]),
              minute: int.parse(timeParts[1]),
            );
          }
          
          // Parse closing time
          if (data['closingTime'] != null) {
            List<String> timeParts = (data['closingTime'] as String).split(':');
            _closingTime = TimeOfDay(
              hour: int.parse(timeParts[0]),
              minute: int.parse(timeParts[1]),
            );
          }
          
          // Load billing settings
          _enableGst = data['enableGst'] ?? false;
          _enablePackagingCharge = data['enablePackagingCharge'] ?? false;
          _gstPercentageController.text = data['gstPercentage'] ?? '';
          _cessPercentageController.text = data['cessPercentage'] ?? '';
          _packagingChargeController.text = data['packagingCharge'] ?? '';
          
          // Load additional notes
          List<dynamic> notesData = data['additionalNotes'] ?? [];
          _notes = List<String>.from(notesData);
          _noteControllers.clear();
          for (String note in _notes) {
            _noteControllers.add(TextEditingController(text: note));
          }
        });
      }
    } catch (e) {
      print('Error loading restaurant info: $e');
    }
  }

  Future<void> _saveRestaurantInfo() async {
    try {
      await FirebaseFirestore.instance
          .collection('restaurants')
          .doc(widget.restaurantId)
          .set({
        'restaurantName': _restaurantNameController.text.trim(),
        'address': _addressController.text.trim(),
        'contactNumber': _contactNumberController.text.trim(),
        'whatsappNumber': _whatsappNumberController.text.trim(),
        'gstNumber': _gstNumberController.text.trim(),
        'openingTime': '${_openingTime.hour.toString().padLeft(2, '0')}:${_openingTime.minute.toString().padLeft(2, '0')}',
        'closingTime': '${_closingTime.hour.toString().padLeft(2, '0')}:${_closingTime.minute.toString().padLeft(2, '0')}',
        'enableGst': _enableGst,
        'enablePackagingCharge': _enablePackagingCharge,
        'gstPercentage': _gstPercentageController.text.trim(),
        'cessPercentage': _cessPercentageController.text.trim(),
        'packagingCharge': _packagingChargeController.text.trim(),
        'additionalNotes': _noteControllers.map((controller) => controller.text.trim()).toList(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.white),
              SizedBox(width: 8.w),
              const Text("Restaurant information saved successfully!"),
            ],
          ),
          backgroundColor: Colors.green.shade500,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error, color: Colors.white),
              SizedBox(width: 8.w),
              Text("Error saving restaurant info: $e"),
            ],
          ),
          backgroundColor: Colors.red.shade500,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.blue.shade50,
              Colors.blue.shade100,
              Colors.purple.shade50,
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(),
              Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.all(kIsWeb ? 24 : 24.w),
                  child: Column(
                    children: [
                      _buildRestaurantInformationSection(),
                      SizedBox(height: kIsWeb ? 24 : 24.h),
                      _buildOperatingHoursSection(),
                      SizedBox(height: kIsWeb ? 24 : 24.h),
                      _buildBillingSettingsSection(),
                      SizedBox(height: kIsWeb ? 24 : 24.h),
                      _buildAdditionalNotesSection(),
                      SizedBox(height: kIsWeb ? 32 : 32.h),
                      _buildSaveButton(),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all( kIsWeb ? 24 : 24.sp),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              padding: EdgeInsets.all(kIsWeb ? 12 : 12.sp),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.grey.shade300, Colors.grey.shade400],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.arrow_back,
                color: Colors.white,
                size: kIsWeb ? 20 : 20.sp,
              ),
            ),
          ),
          SizedBox(width: 16.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Restaurant Settings",
                  style: TextStyle(
                    fontSize:  kIsWeb ? 20 : 20.sp,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade800,
                  ),
                ),
                SizedBox(height: 4.h),
                Text(
                  "Manage your restaurant information",
                  style: TextStyle(
                    fontSize: kIsWeb ? 14 : 14.sp,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: EdgeInsets.all(kIsWeb ? 12 : 12.sp),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [AppColors.primary.withOpacity(0.8), AppColors.primary],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withOpacity(0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Icon(
              Icons.restaurant,
              color: Colors.white,
              size:  kIsWeb ? 20 : 24.sp,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRestaurantInformationSection() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all( kIsWeb ? 24 : 24.sp),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(kIsWeb ? 24 : 20.sp),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
          BoxShadow(
            color: AppColors.primary.withOpacity(0.05),
            blurRadius: 15,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(
          color: AppColors.primary.withOpacity(0.08),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all( kIsWeb ? 14 : 10.sp),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [AppColors.primary.withOpacity(0.8), AppColors.primary],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.info,
                  color: Colors.white,
                  size:  kIsWeb ? 20 : 20.sp,
                ),
              ),
              SizedBox(width: 12.w),
              Text(
                "Restaurant Information",
                style: TextStyle(
                  fontSize:  kIsWeb ? 20 : 20.sp,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade800,
                ),
              ),
            ],
          ),
          SizedBox(height: 24.h),
          
          _buildTextField(
            controller: _restaurantNameController,
            label: "Restaurant Name",
            icon: Icons.restaurant,
            hintText: "Enter restaurant name",
          ),
          
          SizedBox(height: kIsWeb ? 16 : 16.h),
          
          _buildTextField(
            controller: _addressController,
            label: "Address",
            icon: Icons.location_on,
            hintText: "Enter restaurant address",
          ),
          
          SizedBox(height: kIsWeb ? 16 : 16.h),
          
          _buildTextField(
            controller: _contactNumberController,
            label: "Contact Number",
            icon: Icons.phone,
            hintText: "Enter contact number",
            keyboardType: TextInputType.phone,
          ),
          
          SizedBox(height: kIsWeb ? 16 : 16.h),
          
          _buildTextField(
            controller: _whatsappNumberController,
            label: "WhatsApp Number",
            icon: Icons.multiline_chart,
            hintText: "Enter WhatsApp number",
            keyboardType: TextInputType.phone,
          ),
          
          SizedBox(height: kIsWeb ? 16 : 16.h),
          
          _buildTextField(
            controller: _gstNumberController,
            label: "GST Number",
            icon: Icons.receipt,
            hintText: "Enter GST number",
          ),
        ],
      ),
    );
  }

  Widget _buildOperatingHoursSection() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(kIsWeb ? 24 : 24.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
          BoxShadow(
            color: AppColors.primary.withOpacity(0.05),
            blurRadius: 15,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(
          color: AppColors.primary.withOpacity(0.08),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(kIsWeb ? 10 : 10.sp),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.green.withOpacity(0.8), Colors.green],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.schedule,
                  color: Colors.white,
                  size: kIsWeb ? 20 : 20.sp,
                ),
              ),
              SizedBox(width: kIsWeb ? 12 : 12.sp),
              Text(
                "Operating Hours",
                style: TextStyle(
                  fontSize: kIsWeb ? 20 : 20.sp,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade800,
                ),
              ),
            ],
          ),
          SizedBox(height: kIsWeb ? 24 : 24.h),
          
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Opening Time",
                      style: TextStyle(
                        fontSize: kIsWeb ? 16 : 16.sp,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade700,
                      ),
                    ),
                    SizedBox(height: kIsWeb ? 8 : 8.h),
                    GestureDetector(
                      onTap: () => _selectTime(context, 'opening'),
                      child: Container(
                        padding: EdgeInsets.symmetric(horizontal: kIsWeb ? 16 : 16.w, vertical: kIsWeb ? 16 : 16.h),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.green.withOpacity(0.3),
                            width: 1,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.access_time,
                              color: Colors.green,
                              size: kIsWeb ? 20 : 20.sp,
                            ),
                            SizedBox(width: kIsWeb ? 12 : 12.sp),
                            Expanded(
                              child: Text(
                                _formatTime(_openingTime),
                                style: TextStyle(
                                  fontSize: kIsWeb ? 16 : 16.sp,
                                  color: Colors.grey.shade800,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            Icon(
                              Icons.keyboard_arrow_down,
                              color: Colors.green,
                              size: kIsWeb ? 20 : 20.sp,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              
              SizedBox(width: kIsWeb ? 16 : 16.sp),
              
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Closing Time",
                      style: TextStyle(
                        fontSize: kIsWeb ? 16 : 16.sp,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade700,
                      ),
                    ),
                    SizedBox(height: kIsWeb ? 8 : 8.h),
                    GestureDetector(
                      onTap: () => _selectTime(context, 'closing'),
                      child: Container(
                        padding: EdgeInsets.symmetric(horizontal: kIsWeb ? 16 : 16.w, vertical: kIsWeb ? 16 : 16.h),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.red.withOpacity(0.3),
                            width: 1,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.access_time,
                              color: Colors.red,
                              size: kIsWeb ? 20 : 20.sp,
                            ),
                            SizedBox(width: kIsWeb ? 12 : 12.sp),
                            Expanded(
                              child: Text(
                                _formatTime(_closingTime),
                                style: TextStyle(
                                  fontSize: kIsWeb ? 16 : 16.sp,
                                  color: Colors.grey.shade800,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            Icon(
                              Icons.keyboard_arrow_down,
                              color: Colors.red,
                              size: kIsWeb ? 20 : 20.sp,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBillingSettingsSection() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(kIsWeb ? 24 : 24.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
          BoxShadow(
            color: AppColors.primary.withOpacity(0.05),
            blurRadius: 15,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(
          color: AppColors.primary.withOpacity(0.08),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(kIsWeb ? 10 : 10.sp),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.purple.withOpacity(0.8), Colors.purple],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.receipt,
                  color: Colors.white,
                  size: kIsWeb ? 20 : 20.sp,
                ),
              ),
              SizedBox(width: kIsWeb ? 12 : 12.sp),
              Text(
                "Billing Settings",
                style: TextStyle(
                  fontSize: kIsWeb ? 20 : 20.sp,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade800,
                ),
              ),
            ],
          ),
          SizedBox(height: 24.h),
          
          _buildToggleSetting(
            title: "Enable GST",
            description: "Add GST and cess to customer bills.",
            value: _enableGst,
            onChanged: (value) {
              setState(() {
                _enableGst = value;
              });
            },
          ),
          
          if (_enableGst) ...[
            SizedBox(height: kIsWeb ? 16 : 16.h),
            Row(
              children: [
                Expanded(
                  child: _buildPercentageInputField(
                    controller: _gstPercentageController,
                    label: "GST %",
                  ),
                ),
                SizedBox(width: 16.w),
                Expanded(
                  child: _buildPercentageInputField(
                    controller: _cessPercentageController,
                    label: "Cess %",
                  ),
                ),
              ],
            ),
          ],
          
          SizedBox(height: 24.h),
          
          _buildToggleSetting(
            title: "Enable Packaging Charge",
            description: "Add packaging charge for parcel orders.",
            value: _enablePackagingCharge,
            onChanged: (value) {
              setState(() {
                _enablePackagingCharge = value;
              });
            },
          ),
          
          if (_enablePackagingCharge) ...[
            SizedBox(height: kIsWeb ? 16 : 16.h),
            _buildCurrencyInputField(
              controller: _packagingChargeController,
              label: "Packaging Charge",
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAdditionalNotesSection() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(kIsWeb ? 24 : 24.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
          BoxShadow(
            color: AppColors.primary.withOpacity(0.05),
            blurRadius: 15,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(
          color: AppColors.primary.withOpacity(0.08),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(kIsWeb ? 10 : 10.sp),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.orange.withOpacity(0.8), Colors.orange],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.note_add,
                  color: Colors.white,
                  size: kIsWeb ? 20 : 20.sp,
                ),
              ),
              SizedBox(width: kIsWeb ? 12 : 12.sp),
              Text(
                "Additional Notes",
                style: TextStyle(
                  fontSize: kIsWeb ? 20 : 20.sp,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade800,
                ),
              ),
            ],
          ),
          SizedBox(height: 24.h),
          
          // Display existing notes
          ..._noteControllers.asMap().entries.map((entry) {
            int index = entry.key;
            TextEditingController controller = entry.value;
            return Padding(
              padding: EdgeInsets.only(bottom: 16.h),
              child: _buildNoteField(controller, index),
            );
          }).toList(),
          
          // Add Note Button
          Container(
            width: double.infinity,
            height: 50.h,
            decoration: BoxDecoration(
              border: Border.all(
                color: Colors.orange.withOpacity(0.3),
                width: 2,
                style: BorderStyle.solid,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: OutlinedButton.icon(
              onPressed: _addNote,
              icon: Icon(
                Icons.add,
                color: Colors.orange,
                size: kIsWeb ? 20 : 20.sp,
              ),
              label: Text(
                "Add Note",
                style: TextStyle(
                  fontSize: kIsWeb ? 16 : 16.sp,
                  fontWeight: FontWeight.w600,
                  color: Colors.orange,
                ),
              ),
              style: OutlinedButton.styleFrom(
                side: BorderSide.none,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSaveButton() {
    return Container(
      width: double.infinity,
      height: kIsWeb ? 56 : 56.h,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.primary.withOpacity(0.8), AppColors.primary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.4),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: _saveRestaurantInfo,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          padding: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.save,
              color: Colors.white,
              size: kIsWeb ? 20 : 20.sp,
            ),
            SizedBox(width: kIsWeb ? 12 : 12.sp),
            Text(
              "Save Restaurant Information",
              style: TextStyle(
                fontSize: kIsWeb ? 16 : 16.sp,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required String hintText,
    TextInputType? keyboardType,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: kIsWeb ? 16 : 16.sp,
            fontWeight: FontWeight.w600,
            color: Colors.grey.shade700,
          ),
        ),
        SizedBox(height: kIsWeb ? 8 : 8.h),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          decoration: InputDecoration(
            hintText: hintText,
            prefixIcon: Icon(icon, color: AppColors.primary),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppColors.primary, width: 2),
            ),
            contentPadding: EdgeInsets.symmetric(horizontal: kIsWeb ? 16 : 16.w, vertical: kIsWeb ? 12 : 12.h),
          ),
        ),
      ],
    );
  }

  Future<void> _selectTime(BuildContext context, String type) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: type == 'opening' ? _openingTime : _closingTime,
      builder: (BuildContext context, Widget? child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: false),
          child: child!,
        );
      },
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
    final hour = time.hourOfPeriod;
    final minute = time.minute;
    final period = time.period == DayPeriod.am ? 'AM' : 'PM';
    
    return '${hour.toString().padLeft(1, '0')}:${minute.toString().padLeft(2, '0')} $period';
  }

  Widget _buildToggleSetting({
    required String title,
    required String description,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      padding: EdgeInsets.all(kIsWeb ? 16 : 16.w),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.grey.shade200,
          width: 1,
        ),
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
                    fontSize: kIsWeb ? 16 : 16.sp,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade800,
                  ),
                ),
                SizedBox(height: kIsWeb ? 4 : 4.h),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: kIsWeb ? 13 : 13.sp,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: AppColors.primary,
            activeTrackColor: AppColors.primary.withOpacity(0.3),
            inactiveThumbColor: Colors.grey.shade400,
            inactiveTrackColor: Colors.grey.shade200,
          ),
        ],
      ),
    );
  }

  Widget _buildPercentageInputField({
    required TextEditingController controller,
    required String label,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: kIsWeb ? 14 : 14.sp,
            fontWeight: FontWeight.w600,
            color: Colors.grey.shade700,
          ),
        ),
        SizedBox(height: kIsWeb ? 8 : 8.h),
        TextFormField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            suffixText: '%',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppColors.primary, width: 2),
            ),
            contentPadding: EdgeInsets.symmetric(horizontal: kIsWeb ? 16 : 16.w, vertical: kIsWeb ? 12 : 12.h),
          ),
        ),
      ],
    );
  }

  Widget _buildCurrencyInputField({
    required TextEditingController controller,
    required String label,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: kIsWeb ? 16 : 16.sp,
            fontWeight: FontWeight.w600,
            color: Colors.grey.shade700,
          ),
        ),
        SizedBox(height: kIsWeb ? 8 : 8.h),
        TextFormField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            prefixText: '₹',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppColors.primary, width: 2),
            ),
            contentPadding: EdgeInsets.symmetric(horizontal: kIsWeb ? 16 : 16.w, vertical: kIsWeb ? 12 : 12.h),
          ),
        ),
      ],
    );
  }

  Widget _buildNoteField(TextEditingController controller, int index) {
    return Row(
      children: [
        Expanded(
          child: TextFormField(
            controller: controller,
            maxLines: 2,
            decoration: InputDecoration(
              hintText: 'Enter note ${index + 1}',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.orange, width: 2),
              ),
              contentPadding: EdgeInsets.symmetric(horizontal: kIsWeb ? 16 : 16.w, vertical: kIsWeb ? 12 : 12.h),
            ),
          ),
        ),
        SizedBox(width: kIsWeb ? 12 : 12.sp),
        Container(
          width: kIsWeb ? 48 : 48.w,
          height: kIsWeb ? 48 : 48.w,
          decoration: BoxDecoration(
            color: Colors.red.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Colors.red.withOpacity(0.3),
              width: 1,
            ),
          ),
          child: IconButton(
            onPressed: () => _removeNote(index),
            icon: Icon(
              Icons.delete,
              color: Colors.red,
              size: kIsWeb ? 20 : 20.sp,
            ),
            padding: EdgeInsets.zero,
          ),
        ),
      ],
    );
  }

  void _addNote() {
    setState(() {
      _noteControllers.add(TextEditingController());
    });
  }

  void _removeNote(int index) {
    setState(() {
      _noteControllers[index].dispose();
      _noteControllers.removeAt(index);
    });
  }
}
