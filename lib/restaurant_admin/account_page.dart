import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:restaurant_admin_panel/core/constants/app_colors.dart';
import 'package:url_launcher/url_launcher.dart';

class AccountPage extends StatefulWidget {
  final String restaurantId;
  const AccountPage({super.key, required this.restaurantId});

  @override
  State<AccountPage> createState() => _AccountPageState();
}

class _AccountPageState extends State<AccountPage>
    with SingleTickerProviderStateMixin {
  late AnimationController _animCtrl;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _fadeAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.06),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut));
    _animCtrl.forward();
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  Future<void> _launchCall(String phone) async {
    final clean = phone.replaceAll(RegExp(r'[^\d+]'), '');
    final uri = Uri(scheme: 'tel', path: clean);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not launch call to $phone'),
            backgroundColor: AppColors.brown,
          ),
        );
      }
    }
  }

  Future<void> _launchWhatsApp(String phone) async {
    final clean = phone.replaceAll(RegExp(r'[^\d]'), '');
    // Add country code if not present (India default)
    final number = clean.startsWith('91') ? clean : '91$clean';
    final uri = Uri.parse(
      'https://wa.me/$number?text=${Uri.encodeComponent("Hello! I'm contacting you from your restaurant app.")}',
    );
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('WhatsApp is not installed on this device'),
            backgroundColor: AppColors.brown,
          ),
        );
      }
    }
  }

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
            body: Center(
              child: CircularProgressIndicator(color: AppColors.brown),
            ),
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
        final String delivery    = data['deliveryTime'] ?? '30–40 mins';
        final String about       = data['about'] ?? data['aboutUs'] ?? tagline;
        final String? heroImage  = data['bannerImage'] ?? data['coverImage'];
        final String? logo       = data['logo'] as String?;

        return Scaffold(
          backgroundColor: const Color(0xFFFAF3E8),
          body: FadeTransition(
            opacity: _fadeAnim,
            child: SlideTransition(
              position: _slideAnim,
              child: CustomScrollView(
                physics: const BouncingScrollPhysics(),
                slivers: [
                  // ── Hero ──────────────────────────────────────────────
                  SliverToBoxAdapter(
                    child: _HeroBanner(
                      heroImage: heroImage,
                      logo: logo,
                      name: name,
                      tagline: tagline,
                    ),
                  ),

                  // ── Info Cards ────────────────────────────────────────
                  SliverPadding(
                    padding: EdgeInsets.fromLTRB(
                      kIsWeb ? 20 : 16.w,
                      kIsWeb ? 20 : 16.h,
                      kIsWeb ? 20 : 16.w,
                      0,
                    ),
                    sliver: SliverList(
                      delegate: SliverChildListDelegate([
                        _InfoRow(
                          icon: Icons.location_on_rounded,
                          color: const Color(0xFFE8622A),
                          label: 'Address',
                          value: address.isNotEmpty ? address : '—',
                        ),
                        SizedBox(height: kIsWeb ? 10 : 10.h),
                        _InfoRow(
                          icon: Icons.phone_rounded,
                          color: const Color(0xFF8B4513),
                          label: 'Contact',
                          value: phone.isNotEmpty ? phone : '—',
                        ),
                        SizedBox(height: kIsWeb ? 10 : 10.h),
                        Row(
                          children: [
                            Expanded(
                              child: _InfoRow(
                                icon: Icons.access_time_rounded,
                                color: const Color(0xFF2A7E8B),
                                label: 'Opens',
                                value: openingTime,
                              ),
                            ),
                            SizedBox(width: kIsWeb ? 10 : 10.w),
                            Expanded(
                              child: _InfoRow(
                                icon: Icons.nights_stay_rounded,
                                color: const Color(0xFF4A3080),
                                label: 'Closes',
                                value: closingTime,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: kIsWeb ? 10 : 10.h),
                        _InfoRow(
                          icon: Icons.delivery_dining_rounded,
                          color: const Color(0xFF2D8B4A),
                          label: 'Delivery Time',
                          value: delivery,
                        ),
                      ]),
                    ),
                  ),

                  // ── About Us ──────────────────────────────────────────
                  if (about.isNotEmpty)
                    SliverPadding(
                      padding: EdgeInsets.fromLTRB(
                        kIsWeb ? 20 : 16.w,
                        kIsWeb ? 20 : 16.h,
                        kIsWeb ? 20 : 16.w,
                        0,
                      ),
                      sliver: SliverToBoxAdapter(
                        child: _AboutSection(about: about),
                      ),
                    ),

                  // ── CTA Buttons ───────────────────────────────────────
                  SliverPadding(
                    padding: EdgeInsets.fromLTRB(
                      kIsWeb ? 20 : 16.w,
                      kIsWeb ? 24 : 20.h,
                      kIsWeb ? 20 : 16.w,
                      0,
                    ),
                    sliver: SliverToBoxAdapter(
                      child: _CTAButtons(
                        phone: phone,
                        whatsapp: whatsapp,
                        onCall: () => _launchCall(phone),
                        onWhatsApp: () => _launchWhatsApp(whatsapp),
                      ),
                    ),
                  ),

                  SliverToBoxAdapter(
                    child: SizedBox(height: kIsWeb ? 48 : 48.h),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Hero Banner
// ─────────────────────────────────────────────────────────────────────────────
class _HeroBanner extends StatelessWidget {
  final String? heroImage;
  final String? logo;
  final String name;
  final String tagline;

  const _HeroBanner({
    required this.heroImage,
    required this.logo,
    required this.name,
    required this.tagline,
  });

  @override
  Widget build(BuildContext context) {
    final double bannerH = kIsWeb ? 280.0 : 260.h;

    return SizedBox(
      height: bannerH + (kIsWeb ? 48 : 48.h),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Banner image / fallback
          ClipRRect(
            borderRadius: const BorderRadius.only(
              bottomLeft: Radius.circular(0),
              bottomRight: Radius.circular(0),
            ),
            child: SizedBox(
              height: bannerH,
              width: double.infinity,
              child: heroImage != null && heroImage!.isNotEmpty
                  ? Image.network(
                heroImage!,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _fallbackBg(),
              )
                  : _fallbackBg(),
            ),
          ),

          // Bottom gradient overlay
          Positioned(
            left: 0, right: 0,
            bottom: kIsWeb ? 48 : 48.h,
            height: kIsWeb ? 140 : 140.h,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.72),
                  ],
                ),
              ),
            ),
          ),

          // Name card that bleeds below banner
          Positioned(
            left: kIsWeb ? 20 : 16.w,
            right: kIsWeb ? 20 : 16.w,
            bottom: 0,
            child: _NameCard(logo: logo, name: name, tagline: tagline),
          ),
        ],
      ),
    );
  }

  Widget _fallbackBg() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF3E1F0A), Color(0xFF8B4513)],
        ),
      ),
      child: Center(
        child: Icon(
          Icons.restaurant_rounded,
          size: kIsWeb ? 72 : 72.sp,
          color: Colors.white.withValues(alpha: 0.18),
        ),
      ),
    );
  }
}

class _NameCard extends StatelessWidget {
  final String? logo;
  final String name;
  final String tagline;

  const _NameCard({required this.logo, required this.name, required this.tagline});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: kIsWeb ? 20 : 16.w,
        vertical: kIsWeb ? 16 : 14.h,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          if (logo != null && logo!.isNotEmpty) ...[
            Container(
              width: kIsWeb ? 52 : 52.sp,
              height: kIsWeb ? 52 : 52.sp,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF8B4513).withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(logo!, fit: BoxFit.cover),
              ),
            ),
            SizedBox(width: kIsWeb ? 14 : 14.w),
          ] else ...[
            Container(
              width: kIsWeb ? 52 : 52.sp,
              height: kIsWeb ? 52 : 52.sp,
              decoration: BoxDecoration(
                color: const Color(0xFF8B4513),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Text(
                  name.isNotEmpty ? name[0].toUpperCase() : 'R',
                  style: GoogleFonts.playfairDisplay(
                    fontSize: kIsWeb ? 24 : 24.sp,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            SizedBox(width: kIsWeb ? 14 : 14.w),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  name,
                  style: GoogleFonts.playfairDisplay(
                    fontSize: kIsWeb ? 20 : 20.sp,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF1A0A00),
                    height: 1.2,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (tagline.isNotEmpty) ...[
                  SizedBox(height: kIsWeb ? 3 : 3.h),
                  Text(
                    tagline,
                    style: GoogleFonts.lato(
                      fontSize: kIsWeb ? 12 : 12.sp,
                      color: const Color(0xFF8B4513),
                      fontStyle: FontStyle.italic,
                      height: 1.3,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          // Open badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFE8F5E9),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFF2D8B4A), width: 1),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(
                    color: Color(0xFF2D8B4A),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  'Open',
                  style: GoogleFonts.lato(
                    fontSize: kIsWeb ? 11 : 11.sp,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF2D8B4A),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Info Row Card
// ─────────────────────────────────────────────────────────────────────────────
class _InfoRow extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final String value;

  const _InfoRow({
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: kIsWeb ? 16 : 14.w,
        vertical: kIsWeb ? 14 : 12.h,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: kIsWeb ? 40 : 40.sp,
            height: kIsWeb ? 40 : 40.sp,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: kIsWeb ? 20 : 20.sp),
          ),
          SizedBox(width: kIsWeb ? 12 : 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.lato(
                    fontSize: kIsWeb ? 11 : 11.sp,
                    fontWeight: FontWeight.w600,
                    color: Colors.black45,
                    letterSpacing: 0.4,
                  ),
                ),
                SizedBox(height: kIsWeb ? 2 : 2.h),
                Text(
                  value,
                  style: GoogleFonts.lato(
                    fontSize: kIsWeb ? 14 : 14.sp,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF1A0A00),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// About Section
// ─────────────────────────────────────────────────────────────────────────────
class _AboutSection extends StatelessWidget {
  final String about;
  const _AboutSection({required this.about});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(kIsWeb ? 18 : 16.sp),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.info_outline_rounded,
                  color: Color(0xFF8B4513), size: 18),
              SizedBox(width: kIsWeb ? 8 : 8.w),
              Text(
                'About Us',
                style: GoogleFonts.playfairDisplay(
                  fontSize: kIsWeb ? 16 : 16.sp,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF1A0A00),
                ),
              ),
            ],
          ),
          SizedBox(height: kIsWeb ? 10 : 10.h),
          Text(
            about,
            style: GoogleFonts.lato(
              fontSize: kIsWeb ? 13.5 : 13.5.sp,
              color: Colors.black54,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// CTA Buttons
// ─────────────────────────────────────────────────────────────────────────────
class _CTAButtons extends StatelessWidget {
  final String phone;
  final String whatsapp;
  final VoidCallback onCall;
  final VoidCallback onWhatsApp;

  const _CTAButtons({
    required this.phone,
    required this.whatsapp,
    required this.onCall,
    required this.onWhatsApp,
  });

  @override
  Widget build(BuildContext context) {
    final bool hasPhone = phone.isNotEmpty;
    final bool hasWhatsApp = whatsapp.isNotEmpty;

    return Column(
      children: [
        // Divider label
        Row(
          children: [
            const Expanded(child: Divider(thickness: 1, color: Color(0xFFE0D5C8))),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: kIsWeb ? 12 : 12.w),
              child: Text(
                'Get in Touch',
                style: GoogleFonts.lato(
                  fontSize: kIsWeb ? 12 : 12.sp,
                  color: Colors.black38,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),
            ),
            const Expanded(child: Divider(thickness: 1, color: Color(0xFFE0D5C8))),
          ],
        ),
        SizedBox(height: kIsWeb ? 14 : 14.h),
        Row(
          children: [
            // Call Button
            Expanded(
              child: _ActionButton(
                icon: Icons.phone_rounded,
                label: 'Call Us',
                sublabel: hasPhone ? phone : 'Not available',
                gradientColors: hasPhone
                    ? [const Color(0xFFE8622A), const Color(0xFFD04E1A)]
                    : [Colors.grey.shade400, Colors.grey.shade500],
                onTap: hasPhone ? onCall : null,
              ),
            ),
            SizedBox(width: kIsWeb ? 12 : 12.w),
            // WhatsApp Button
            Expanded(
              child: _ActionButton(
                icon: Icons.chat_rounded,
                label: 'WhatsApp',
                sublabel: hasWhatsApp ? whatsapp : 'Not available',
                gradientColors: hasWhatsApp
                    ? [const Color(0xFF25D366), const Color(0xFF128C7E)]
                    : [Colors.grey.shade400, Colors.grey.shade500],
                onTap: hasWhatsApp ? onWhatsApp : null,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _ActionButton extends StatefulWidget {
  final IconData icon;
  final String label;
  final String sublabel;
  final List<Color> gradientColors;
  final VoidCallback? onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.sublabel,
    required this.gradientColors,
    this.onTap,
  });

  @override
  State<_ActionButton> createState() => _ActionButtonState();
}

class _ActionButtonState extends State<_ActionButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _pressCtrl;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _pressCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
      lowerBound: 0.95,
      upperBound: 1.0,
      value: 1.0,
    );
    _scaleAnim = _pressCtrl;
  }

  @override
  void dispose() {
    _pressCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scaleAnim,
      child: GestureDetector(
        onTapDown: widget.onTap != null
            ? (_) => _pressCtrl.reverse()
            : null,
        onTapUp: widget.onTap != null
            ? (_) {
          _pressCtrl.forward();
          widget.onTap!();
        }
            : null,
        onTapCancel: () => _pressCtrl.forward(),
        child: Container(
          padding: EdgeInsets.symmetric(
            vertical: kIsWeb ? 16 : 16.h,
            horizontal: kIsWeb ? 12 : 12.w,
          ),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: widget.gradientColors,
            ),
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: widget.gradientColors.first.withValues(alpha: 0.4),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  widget.icon,
                  color: Colors.white,
                  size: kIsWeb ? 22 : 22.sp,
                ),
              ),
              SizedBox(height: kIsWeb ? 8 : 8.h),
              Text(
                widget.label,
                style: GoogleFonts.lato(
                  fontSize: kIsWeb ? 14 : 14.sp,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  letterSpacing: 0.3,
                ),
              ),
              SizedBox(height: kIsWeb ? 3 : 3.h),
              Text(
                widget.sublabel,
                style: GoogleFonts.lato(
                  fontSize: kIsWeb ? 11 : 11.sp,
                  color: Colors.white.withValues(alpha: 0.82),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}