import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';


class AccountPage extends StatefulWidget {
  final String restaurantId;
  const AccountPage({Key? key, required this.restaurantId}) : super(key: key);

  @override
  State<AccountPage> createState() => _AccountPageState();
}

class _AccountPageState extends State<AccountPage> {
  static const Color _brown      = Color(0xFF6B3A1F);
  static const Color _brownLight = Color(0xFF8B4513);
  static const Color _cream      = Color(0xFFFAF3E8);
  static const Color _orange     = Color(0xFFE8621A);
  static const Color _green      = Color(0xFF2E7D32);

  // ─── Launch URL ────────────────────────────────────────────────────────────

  Future<void> _launch(String url) async {
  /*  final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }*/
  }

  // ─── Build ─────────────────────────────────────────────────────────────────

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
          backgroundColor: _cream,
          body: CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              // ── Hero banner ────────────────────────────────────────────────
              SliverToBoxAdapter(
                child: _buildHero(heroImage, name, tagline, data),
              ),

              // ── Info grid ─────────────────────────────────────────────────
              SliverToBoxAdapter(
                child: _buildInfoGrid(address, phone, openingTime, closingTime, delivery),
              ),

              // ── About us ──────────────────────────────────────────────────
              if (about.isNotEmpty)
                SliverToBoxAdapter(
                  child: _buildAboutUs(about),
                ),

              // ── CTA buttons ───────────────────────────────────────────────
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

  // ─── Hero banner ───────────────────────────────────────────────────────────

  Widget _buildHero(
      String? heroImage,
      String name,
      String tagline,
      Map<String, dynamic> data,
      ) {
    final String? logo = data['logo'] as String?;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        // Food photo background
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

        // Dark scrim at bottom of hero
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
                  Colors.black.withOpacity(0.55),
                ],
              ),
            ),
          ),
        ),

        // Name plate overlapping hero bottom
        Positioned(
          left: 0, right: 0,
          bottom: kIsWeb ? -50 : -50.h,
          child: Center(
            child: Container(
              margin: EdgeInsets.symmetric(horizontal: kIsWeb ? 32 : 32.w),
              padding: EdgeInsets.symmetric(
                  horizontal: kIsWeb ? 24 : 24.w,
                  vertical: kIsWeb ? 14 : 14.h),
              decoration: BoxDecoration(
                color: _brown,
                borderRadius: BorderRadius.circular(kIsWeb ? 14 : 14.sp),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.25),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Logo thumbnail
                  if (logo != null && logo.isNotEmpty) ...[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(kIsWeb ? 8 : 8.sp),
                      child: Image.network(
                        logo,
                        width: kIsWeb ? 44 : 44.sp,
                        height: kIsWeb ? 44 : 44.sp,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                      ),
                    ),
                    SizedBox(width: kIsWeb ? 12 : 12.w),
                  ],
                  Flexible(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          name,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.playfairDisplay(
                            fontSize: kIsWeb ? 22 : 22.sp,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                            letterSpacing: 0.3,
                          ),
                        ),
                        if (tagline.isNotEmpty) ...[
                          SizedBox(height: kIsWeb ? 2 : 2.h),
                          Text(
                            tagline,
                            textAlign: TextAlign.center,
                            style: GoogleFonts.lato(
                              fontSize: kIsWeb ? 11 : 11.sp,
                              color: Colors.white.withOpacity(0.85),
                              fontStyle: FontStyle.italic,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
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
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Icon(Icons.restaurant,
            size: kIsWeb ? 64 : 64.sp, color: Colors.white.withOpacity(0.3)),
      ),
    );
  }

  // ─── Info grid ─────────────────────────────────────────────────────────────

  Widget _buildInfoGrid(
      String address,
      String phone,
      String openingTime,
      String closingTime,
      String delivery,
      ) {
    return Container(
      margin: EdgeInsets.fromLTRB(
          kIsWeb ? 16 : 16.w,
          kIsWeb ? 66 : 66.h,   // space for overlapping name plate
          kIsWeb ? 16 : 16.w,
          0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(kIsWeb ? 16 : 16.sp),
        boxShadow: [
          BoxShadow(
            color: _brown.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          // Row 1: address | contact
          IntrinsicHeight(
            child: Row(
              children: [
                Expanded(child: _infoCell(
                  icon: Icons.location_on,
                  iconColor: _orange,
                  label: 'Address',
                  value: address.isNotEmpty ? address : 'Not set',
                  leftRadius: true,
                )),
                _vertDivider(),
                Expanded(child: _infoCell(
                  icon: Icons.phone,
                  iconColor: _brownLight,
                  label: 'Contact',
                  value: phone.isNotEmpty ? phone : 'Not set',
                  rightRadius: true,
                )),
              ],
            ),
          ),

          _horizDivider(),

          // Row 2: hours | delivery
          IntrinsicHeight(
            child: Row(
              children: [
                Expanded(child: _infoCell(
                  icon: Icons.access_time_rounded,
                  iconColor: _brownLight,
                  label: 'Opening Hours',
                  value: '$openingTime - $closingTime',
                  leftRadius: true,
                )),
                _vertDivider(),
                Expanded(child: _infoCell(
                  icon: Icons.delivery_dining_rounded,
                  iconColor: _orange,
                  label: 'Delivery Time',
                  value: delivery,
                  rightRadius: true,
                )),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoCell({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String value,
    bool leftRadius = false,
    bool rightRadius = false,
  }) {
    return Padding(
      padding: EdgeInsets.symmetric(
          horizontal: kIsWeb ? 16 : 16.w,
          vertical: kIsWeb ? 16 : 16.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Icon circle
          Container(
            width: kIsWeb ? 36 : 36.sp,
            height: kIsWeb ? 36 : 36.sp,
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: iconColor, size: kIsWeb ? 18 : 18.sp),
          ),
          SizedBox(width: kIsWeb ? 10 : 10.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: GoogleFonts.poppins(
                        fontSize: kIsWeb ? 12 : 12.sp,
                        fontWeight: FontWeight.w700,
                        color: _brown)),
                SizedBox(height: kIsWeb ? 2 : 2.h),
                Text(value,
                    style: GoogleFonts.poppins(
                        fontSize: kIsWeb ? 11 : 11.sp,
                        color: Colors.black54,
                        height: 1.4),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _vertDivider() => Container(
    width: 1,
    color: Colors.grey.withOpacity(0.15),
  );

  Widget _horizDivider() => Container(
    height: 1,
    color: Colors.grey.withOpacity(0.15),
  );

  // ─── About us ──────────────────────────────────────────────────────────────

  Widget _buildAboutUs(String about) {
    return Container(
      margin: EdgeInsets.fromLTRB(
          kIsWeb ? 16 : 16.w,
          kIsWeb ? 16 : 16.h,
          kIsWeb ? 16 : 16.w,
          0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(kIsWeb ? 16 : 16.sp),
        boxShadow: [
          BoxShadow(
            color: _brown.withOpacity(0.07),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(kIsWeb ? 20 : 20.sp),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Section title with decorative lines
            Row(
              children: [
                Expanded(child: Container(height: 1, color: Colors.grey.withOpacity(0.2))),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: kIsWeb ? 14 : 14.w),
                  child: Text(
                    'About Us',
                    style: GoogleFonts.playfairDisplay(
                      fontSize: kIsWeb ? 18 : 18.sp,
                      fontWeight: FontWeight.w700,
                      color: _brown,
                    ),
                  ),
                ),
                Expanded(child: Container(height: 1, color: Colors.grey.withOpacity(0.2))),
              ],
            ),

            SizedBox(height: kIsWeb ? 14 : 14.h),

            Text(
              about,
              textAlign: TextAlign.left,
              style: GoogleFonts.lato(
                fontSize: kIsWeb ? 13 : 13.sp,
                color: Colors.black.withOpacity(0.65),
                height: 1.7,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── CTA buttons ───────────────────────────────────────────────────────────

  Widget _buildCTAButtons(String phone, String whatsapp) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
          kIsWeb ? 16 : 16.w,
          kIsWeb ? 20 : 20.h,
          kIsWeb ? 16 : 16.w,
          0),
      child: Row(
        children: [
          // Call Us
          Expanded(
            child: GestureDetector(
              onTap: () => _launch('tel:$phone'),
              child: Container(
                height: kIsWeb ? 54 : 54.h,
                decoration: BoxDecoration(
                  color: _orange,
                  borderRadius: BorderRadius.circular(kIsWeb ? 30 : 30.sp),
                  boxShadow: [
                    BoxShadow(
                      color: _orange.withOpacity(0.35),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.phone_in_talk_rounded,
                        color: Colors.white, size: kIsWeb ? 20 : 20.sp),
                    SizedBox(width: kIsWeb ? 8 : 8.w),
                    Text('Call Us',
                        style: GoogleFonts.poppins(
                            fontSize: kIsWeb ? 14 : 14.sp,
                            fontWeight: FontWeight.w700,
                            color: Colors.white)),
                  ],
                ),
              ),
            ),
          ),

          SizedBox(width: kIsWeb ? 12 : 12.w),

          // WhatsApp
          Expanded(
            child: GestureDetector(
              onTap: () => _launch(
                  'https://wa.me/${whatsapp.replaceAll(RegExp(r'[^0-9]'), '')}'),
              child: Container(
                height: kIsWeb ? 54 : 54.h,
                decoration: BoxDecoration(
                  color: _green,
                  borderRadius: BorderRadius.circular(kIsWeb ? 30 : 30.sp),
                  boxShadow: [
                    BoxShadow(
                      color: _green.withOpacity(0.3),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // WhatsApp icon (SVG-like using paths not available, use chat icon)
                    Icon(Icons.chat_rounded,
                        color: Colors.white, size: kIsWeb ? 20 : 20.sp),
                    SizedBox(width: kIsWeb ? 8 : 8.w),
                    Text('WhatsApp',
                        style: GoogleFonts.poppins(
                            fontSize: kIsWeb ? 14 : 14.sp,
                            fontWeight: FontWeight.w700,
                            color: Colors.white)),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
