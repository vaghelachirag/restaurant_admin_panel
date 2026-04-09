import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:restaurant_admin_panel/core/constants/app_colors.dart';

class AccountPage extends StatefulWidget {
  final String restaurantId;
  const AccountPage({super.key, required this.restaurantId});

  @override
  State<AccountPage> createState() => _AccountPageState();
}

class _AccountPageState extends State<AccountPage> {


  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('restaurants')
          .doc(widget.restaurantId)
          .snapshots(),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Scaffold(
            backgroundColor: Color(0xFFFAF3E8),
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final data = snap.data!.data() as Map<String, dynamic>? ?? {};

        final String name        = data['name'] ?? data['restaurantName'] ?? 'Restaurant';
        final String tagline     = data['tagline'] ?? data['description'] ?? '';
        final String address     = data['address'] ?? '';
        final String phone       = data['phone'] ?? data['contact'] ?? '';
        final String whatsapp    = data['whatsapp'] ?? phone;
        final String openingTime = data['openingTime'] ?? '9:00 AM';
        final String closingTime = data['closingTime'] ?? '10:00 PM';
        final String delivery    = data['deliveryTime'] ?? '30-40 mins';
        final String about       = data['about'] ?? data['aboutUs'] ?? tagline;
        final String? heroImage  = data['bannerImage'] ?? data['coverImage'] ?? data['logo'];

        return Scaffold(
          backgroundColor: AppColors.cream,
          body: CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: _buildHero(heroImage, name, tagline, data),
              ),
              SliverToBoxAdapter(
                child: _buildInfoGrid(address, phone, openingTime, closingTime, delivery),
              ),
              if (about.isNotEmpty)
                SliverToBoxAdapter(
                  child: _buildAboutUs(about),
                ),
              SliverToBoxAdapter(
                child: _buildCTAButtons(phone, whatsapp),
              ),
              SliverToBoxAdapter(
                child: SizedBox(height: kIsWeb ? 40 : 40.h),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHero(String? heroImage, String name, String tagline, Map<String, dynamic> data) {
    final String? logo = data['logo'] as String?;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        SizedBox(
          height: kIsWeb ? 260 : 260.h,
          width: double.infinity,
          child: heroImage != null && heroImage.isNotEmpty
              ? Image.network(
            heroImage,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => _heroBgFallback(),
          )
              : _heroBgFallback(),
        ),

        Positioned(
          left: 0, right: 0, bottom: 0,
          child: Container(
            height: kIsWeb ? 100 : 100.h,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  AppColors.black.withValues(alpha: 0.55),
                ],
              ),
            ),
          ),
        ),

        Positioned(
          left: 0, right: 0,
          bottom: kIsWeb ? -50 : -50.h,
          child: Center(
            child: Container(
              margin: EdgeInsets.symmetric(horizontal: kIsWeb ? 32 : 32.w),
              padding: EdgeInsets.symmetric(
                horizontal: kIsWeb ? 24 : 24.w,
                vertical: kIsWeb ? 14 : 14.h,
              ),
              decoration: BoxDecoration(
                color: AppColors.brown,
                borderRadius: BorderRadius.circular(kIsWeb ? 14 : 14.sp),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.black.withValues(alpha: 0.25),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (logo != null && logo.isNotEmpty) ...[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(kIsWeb ? 8 : 8.sp),
                      child: Image.network(
                        logo,
                        width: kIsWeb ? 44 : 44.sp,
                        height: kIsWeb ? 44 : 44.sp,
                        fit: BoxFit.cover,
                      ),
                    ),
                    SizedBox(width: kIsWeb ? 12 : 12.w),
                  ],
                  Flexible(
                    child: Column(
                      children: [
                        Text(
                          name,
                          style: GoogleFonts.playfairDisplay(
                            fontSize: kIsWeb ? 22 : 22.sp,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                        if (tagline.isNotEmpty)
                          Text(
                            tagline,
                            style: GoogleFonts.lato(
                              fontSize: kIsWeb ? 11 : 11.sp,
                              color: AppColors.white.withValues(alpha: 0.85),
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _heroBgFallback() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF6B3A1F), Color(0xFF8B4513)],
        ),
      ),
      child: Center(
        child: Icon(
          Icons.restaurant,
          size: kIsWeb ? 64 : 64.sp,
          color: Colors.white.withValues(alpha: 0.3),
        ),
      ),
    );
  }

  Widget _buildInfoGrid(String address, String phone, String openingTime, String closingTime, String delivery) {
    return Container(
      margin: EdgeInsets.all(kIsWeb ? 16 : 16.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.brown.withValues(alpha: 0.08),
            blurRadius: 12,
          ),
        ],
      ),
      child: Column(
        children: [
          _infoCell(Icons.location_on, AppColors.orange, 'Address', address),
          _infoCell(Icons.phone, AppColors.brownLight, 'Contact', phone),
        ],
      ),
    );
  }

  Widget _infoCell(IconData icon, Color color, String label, String value) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Container(
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            padding: const EdgeInsets.all(8),
            child: Icon(icon, color: color),
          ),
          const SizedBox(width: 10),
          Text(value),
        ],
      ),
    );
  }

  Widget _buildAboutUs(String about) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Text(
        about,
        style: GoogleFonts.lato(
          color: Colors.black.withValues(alpha: 0.65),
        ),
      ),
    );
  }

  Widget _buildCTAButtons(String phone, String whatsapp) {
    return Row(
      children: [
        Expanded(
          child: Container(
            color: AppColors.orange,
            child: const Center(child: Text('Call Us')),
          ),
        ),
        Expanded(
          child: Container(
            color: AppColors.green,
            child: const Center(child: Text('WhatsApp')),
          ),
        ),
      ],
    );
  }
}