import 'dart:async';
import 'dart:ui' as ui;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:restaurant_admin_panel/restaurant_admin/restaurant_orders_page.dart';

import '../uttils/responsive.dart';
import '../uttils/session_manager.dart';
import '../utils/snackbar_helper.dart';
import 'category_page.dart';
import 'customer_menu.dart';
import 'menu_page.dart';
import 'qr_download_io.dart' if (dart.library.html) 'qr_download_web.dart' as qr_download;
import 'settings_page.dart';

class RestaurantAdminPanel extends StatefulWidget {
  final String restaurantId;

  const RestaurantAdminPanel({super.key, required this.restaurantId});

  @override
  State<RestaurantAdminPanel> createState() => _RestaurantAdminPanelState();
}

class _RestaurantAdminPanelState extends State<RestaurantAdminPanel> {

  final AudioPlayer player = AudioPlayer();

  int newOrderCount = 0;
  Timer? notificationTimer;


  @override
  void initState() {
    super.initState();
    listenForNewOrders();
  }

  /// PLAY SOUND
  Future<void> playNewOrderSound() async {
    await player.stop();
    await player.play(AssetSource('sounds/new_order.mp3'));
  }

  void handleNewOrder() {
    newOrderCount++;

    notificationTimer?.cancel();

    notificationTimer = Timer(const Duration(seconds: 3), () {
      if (!mounted) return;

      if (newOrderCount > 0) {
        playNewOrderSound();

        SnackBarHelper.showInfo(context, "$newOrderCount New Orders Received");

        newOrderCount = 0;
      }
    });
  }
  /// LISTEN FOR NEW ORDERS
  void listenForNewOrders() {
    FirebaseFirestore.instance
        .collection("orders")
        .where("restaurantId", isEqualTo: widget.restaurantId)
        .snapshots()
        .listen((snapshot) {

      for (var change in snapshot.docChanges) {

        if (change.type == DocumentChangeType.added) {
          handleNewOrder();
        }
      }
    });
  }

  /// CUSTOMER MENU LINK
  String getMenuLink() {
    return "https://restaurant-menu-system-fc074.web.app/#/menu/${widget
        .restaurantId}";
  }

  /// GENERATE AND DOWNLOAD QR CODE (works on web and mobile/desktop)
  Future<void> downloadQRCode(String link) async {
    try {
      final qrValidationResult = QrValidator.validate(data: link);
      if (qrValidationResult.status == QrValidationStatus.error) {
        throw Exception('Invalid QR data');
      }

      final qrCode = QrPainter(
        data: link,
        version: QrVersions.auto,
        color: const Color(0xFF000000),
        emptyColor: const Color(0xFFFFFFFF),
        gapless: true,
      );

      final imageData = await qrCode.toImageData(300);
      final byteData = imageData?.buffer.asUint8List();

      if (byteData == null || byteData.isEmpty) {
        throw Exception('Failed to generate QR image');
      }

      final filename = 'menu_qr_${widget.restaurantId}.png';
      await qr_download.saveQrBytesToPlatform(byteData, filename);

      if (mounted) {
        SnackBarHelper.showSuccess(context, kIsWeb ? "QR Code downloaded!" : "QR Code saved to device!");
      }
    } catch (e) {
      if (mounted) {
        SnackBarHelper.showError(context, "Error generating QR: $e");
      }
    }
  }

  void showMenuLink(BuildContext context) {
    final String link = getMenuLink();

    showDialog(
      context: context,
      builder: (dialogContext) {
        final media = MediaQuery.of(dialogContext);
        final width = media.size.width;
        final height = media.size.height;
        final isNarrow = width < 400;
        final isShort = height < 600;

        // Responsive dimensions
        final dialogMaxWidth = (width * 0.92).clamp(280.0, 520.0);
        final padding = isNarrow ? 16.0 : 24.0;
        final qrSize = (width * 0.45).clamp(140.0, 220.0);
        final titleFontSize = isNarrow ? 11.0 : 12.0;
        final linkFontSize = isNarrow ? 12.0 : 14.0;
        final maxDialogHeight = height * 0.88;

        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(isNarrow ? 16.sp : 20.sp),
          ),
          child: Container(
            constraints: BoxConstraints(
              maxWidth: dialogMaxWidth,
              maxHeight: maxDialogHeight,
            ),
            padding: EdgeInsets.all(padding),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(isNarrow ? 16.sp : 20.sp),
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  adminHeader(dialogContext),
                  SizedBox(height: isShort ? 16.sp : 24.sp),

                  /// QR CODE DISPLAY
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.all(isNarrow ? 12.sp : 16.sp),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(12.sp),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Column(
                      children: [
                        Text(
                          "QR Code",
                          style: TextStyle(
                            fontSize: titleFontSize,
                            color: Colors.grey.shade600,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        SizedBox(height: isNarrow ? 8.sp : 12.sp),
                        Container(
                          padding: EdgeInsets.all(isNarrow ? 10.sp : 16.sp),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12.sp),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.05),
                                blurRadius: 10.sp,
                                offset:  Offset(0, 4.sp),
                              ),
                            ],
                          ),
                          child: QrImageView(
                            data: link,
                            version: QrVersions.auto,
                            size: qrSize,
                            eyeStyle: const QrEyeStyle(
                              eyeShape: QrEyeShape.square,
                              color: Color(0xFF000000),
                            ),
                            dataModuleStyle: const QrDataModuleStyle(
                              dataModuleShape: QrDataModuleShape.square,
                              color: Color(0xFF000000),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  SizedBox(height: isShort ? 12.sp : 20.sp),

                  /// LINK DISPLAY
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.all(isNarrow ? 12.sp : 16.sp),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(12.sp),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Menu URL",
                          style: TextStyle(
                            fontSize: titleFontSize,
                            color: Colors.grey.shade600,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        SizedBox(height: 8.h),
                        SelectableText(
                          link,
                          style: TextStyle(
                            fontSize: linkFontSize,
                            color: Colors.grey.shade800,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: isShort ? 16.h : 24.h),

                  /// Buttons: column on narrow, row otherwise
                  if (isNarrow) ...[
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: link));
                          SnackBarHelper.showSuccess(context, "Link copied to clipboard!");
                        },
                        icon:  Icon(Icons.copy, size: 18.sp),
                        label: const Text("Copy Link"),
                        style: OutlinedButton.styleFrom(
                          padding:  EdgeInsets.symmetric(vertical: 14.h),
                          side: BorderSide(color: Colors.purple.shade300),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12.sp),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () => downloadQRCode(link),
                        icon:  Icon(Icons.qr_code_scanner, size:  Responsive.isMobile(context) ? 12.sp : 18.sp),
                        label: const Text("Download"),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          side: BorderSide(color: Colors.grey.shade300),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: 8.h),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () => Navigator.pop(dialogContext),
                        icon:  Icon(Icons.close, size: 18.sp),
                        label: const Text("Close"),
                        style: OutlinedButton.styleFrom(
                          padding:  EdgeInsets.symmetric(vertical: 14.h),
                          side: BorderSide(color: Colors.grey.shade300),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12.sp),
                          ),
                        ),
                      ),
                    ),
                  ] else
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () {
                              Clipboard.setData(ClipboardData(text: link));
                              SnackBarHelper.showSuccess(context, "Link copied to clipboard!");
                            },
                            icon:  Icon(Icons.copy, size: 18.sp),
                            label: const Text("Copy Link"),
                            style: OutlinedButton.styleFrom(
                              padding:  EdgeInsets.symmetric(vertical: 14.h),
                              side: BorderSide(color: Colors.purple.shade300),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                         SizedBox(width: 12.w),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () => downloadQRCode(link),
                            icon:  Icon(Icons.qr_code_scanner, size: 18.sp),
                            label:  Text("Download QR"),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.purple.shade500,
                              padding:  EdgeInsets.symmetric(vertical: 14.sp),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                         SizedBox(width: 12.w),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => Navigator.pop(dialogContext),
                            icon:  Icon(Icons.close, size: 18.sp),
                            label: const Text("Close"),
                            style: OutlinedButton.styleFrom(
                              padding:  EdgeInsets.symmetric(vertical: 14.h),
                              side: BorderSide(color: Colors.grey.shade300),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12.sp),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  /// LOGOUT FUNCTION
  Future<void> logout() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context); // Close dialog
              
              // Show loading indicator
              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (context) => const AlertDialog(
                  content: Row(
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(width: 20),
                      Text('Logging out...'),
                    ],
                  ),
                ),
              );

              try {
                // 1. Clear SharedPreferences session data
                await SessionManager.logout();
                
                // 2. Sign out from Firebase Auth
                await FirebaseAuth.instance.signOut();
                
                // 3. Cancel any active timers/listeners
                notificationTimer?.cancel();
                
                // 4. Clear any image cache if needed
                PaintingBinding.instance.imageCache.clear();
                
                // 5. Navigate to login screen and clear all routes
                if (mounted) {
                  Navigator.of(context).pushNamedAndRemoveUntil(
                    '/login',
                    (route) => false,
                  );
                }
              } catch (e) {
                // Close loading dialog
                Navigator.of(context).pop();
                
                // Show error message
                if (mounted) {
                  SnackBarHelper.showError(context, 'Error during logout: $e');
                }
              }
            },
            child: const Text('Logout', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              colorScheme.primary.withOpacity(0.06),
              colorScheme.primary.withOpacity(0.14),
              colorScheme.secondary.withOpacity(0.10),
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.blue.shade400,
                                Colors.blue.shade600
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child:  Icon(
                            Icons.dashboard,
                            color: Colors.white,
                            size: 28,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Restaurant Admin",
                                style: TextStyle(
                                  fontSize: Responsive.isMobile(context) ? 16 : 20,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey.shade800,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                "Manage your restaurant efficiently",
                                style: TextStyle(
                                  fontSize: Responsive.isMobile(context) ? 14 : 16,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        GestureDetector(
                          onTap: logout,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.red.shade50,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: Colors.red.shade200),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.logout,
                                  color: Colors.red.shade700,
                                  size: kIsWeb ? 16 : 16.sp,
                                ),
                                SizedBox(width: kIsWeb ? 8 : 8.sp),
                                Text(
                                  "Logout",
                                  style: TextStyle(
                                    color: Colors.red.shade700,
                                    fontWeight: FontWeight.w600,
                                    fontSize:  kIsWeb ? 12 : 12.sp,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    int crossAxisCount = 2;

                    if (constraints.maxWidth > 900) {
                      crossAxisCount = 4; // Web large screen
                    } else if (constraints.maxWidth > 600) {
                      crossAxisCount = 3; // Tablet
                    }

                    return Padding(
                      padding: const EdgeInsets.all(24),
                      child: GridView.count(
                        crossAxisCount: crossAxisCount,
                        crossAxisSpacing: 20.sp,
                        mainAxisSpacing: 20.sp,
                        children: [
                          _modernMenuCard(
                            icon: Icons.category,
                            title: "Categories",
                            subtitle: "Manage food categories",
                            color: Colors.orange,
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      CategoryPage(
                                          restaurantId: widget.restaurantId),
                                ),
                              );
                            },
                          ),
                          _modernMenuCard(
                            icon: Icons.restaurant_menu,
                            title: "Menu Items",
                            subtitle: "Add & edit dishes",
                            color: Colors.blue,
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      MenuPage(
                                          restaurantId: widget.restaurantId),
                                ),
                              );
                            },
                          ),
                          _modernMenuCard(
                            icon: Icons.menu_book,
                            title: "Customer Menu",
                            subtitle: "Preview customer view",
                            color: Colors.green,
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      CustomerMenuPage(
                                          restaurantId: widget.restaurantId),
                                ),
                              );
                            },
                          ),
                          /// MENU LINK
                          _modernMenuCard(
                            icon: Icons.link,
                            title: "Menu Link",
                            subtitle: "Share with customers",
                            color: Colors.purple,
                            onTap: () {
                              showMenuLink(context);
                            },
                          ),

                          /// LIVE ORDERS COUNTER
                          StreamBuilder<QuerySnapshot>(
                            stream: FirebaseFirestore.instance
                                .collection("orders")
                                .where(
                                "restaurantId", isEqualTo: widget.restaurantId)
                                .where("status", isEqualTo: "pending")
                                .snapshots(),
                            builder: (context, snapshot) {
                              int orderCount = 0;

                              if (snapshot.hasData) {
                                orderCount = snapshot.data!.docs.length;
                              }

                              return _modernMenuCard(
                                icon: Icons.receipt_long,
                                title: "Live Orders",
                                subtitle: "Pending orders",
                                color: Colors.red,
                                count: orderCount,
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          RestaurantOrdersPage(
                                              restaurantId: widget
                                                  .restaurantId),
                                    ),
                                  );
                                },
                              );
                            },
                          ),

                          /// SETTINGS
                          _modernMenuCard(
                            icon: Icons.settings,
                            title: "Settings",
                            subtitle: "App preferences",
                            color: Colors.grey,
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      SettingsPage(
                                          restaurantId: widget.restaurantId),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget adminHeader(BuildContext context) {
    double width = MediaQuery.of(context).size.width;

    double iconSize = width * 0.02 + 18;
    double titleSize = width * 0.018 + 14;
    double subtitleSize = width * 0.005 + 10;

    return Row(
      children: [
        /// DASHBOARD ICON
        Container(
          padding: EdgeInsets.all(width * 0.012),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.blue.shade400,
                Colors.blue.shade600,
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(width * 0.01 + 10),
          ),
          child: Icon(
            Icons.dashboard,
            color: Colors.white,
            size: iconSize,
          ),
        ),

        SizedBox(width: width * 0.01 + 10),

        /// TITLE + SUBTITLE
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Restaurant Admin",
                style: TextStyle(
                  fontSize: titleSize,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade800,
                ),
              ),
              SizedBox(height: width * 0.003),
              Text(
                "Manage your restaurant efficiently",
                style: TextStyle(
                  fontSize: subtitleSize,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ),

        /// LOGOUT BUTTON
        GestureDetector(
          onTap: logout,
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: width * 0.008 + 10,
              vertical: width * 0.004 + 4,
            ),
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.red.shade200),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.logout,
                  color: Colors.red.shade700,
                  size: width * 0.005 + 12,
                ),
                SizedBox(width: width * 0.004 + 4),
                Text(
                  "Logout",
                  style: TextStyle(
                    color: Colors.red.shade700,
                    fontWeight: FontWeight.w600,
                    fontSize: subtitleSize,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _modernMenuCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
    int count = 0,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        double width = constraints.maxWidth;

        double iconSize = kIsWeb ? 24 : 24.sp;
        double padding = kIsWeb ? 20 : 20.sp;
        double titleSize = kIsWeb ? 16 : 16.sp;
        double subtitleSize = width * 0.08;
        double arrowSize = width * 0.09;

        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(width * 0.08),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(width * 0.08),
                boxShadow: [
                  BoxShadow(
                    color: color.withOpacity(0.2),
                    blurRadius: width * 0.06,
                    offset: const Offset(0, 8),
                  ),
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: width * 0.04,
                    offset: const Offset(0, 4),
                  ),
                ],
                border: Border.all(
                  color: color.withOpacity(0.1),
                  width: 1,
                ),
              ),
              child: Stack(
                children: [
                  Padding(
                    padding: EdgeInsets.all(padding),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: EdgeInsets.all(width * 0.06),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [color.withOpacity(0.8), color],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(width * 0.06),
                            boxShadow: [
                              BoxShadow(
                                color: color.withOpacity(0.3),
                                blurRadius: width * 0.04,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Icon(
                            icon,
                            color: Colors.white,
                            size: iconSize,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          title,
                          style: TextStyle(
                            fontSize: titleSize,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey.shade800,
                          ),
                        ),

                        SizedBox(height: width * 0.04),

                        /// ARROW
                        Container(
                          padding: EdgeInsets.all(width * 0.03),
                          decoration: BoxDecoration(
                            color: color.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(width * 0.05),
                          ),
                          child: Icon(
                            Icons.arrow_forward_ios,
                            color: color,
                            size: arrowSize,
                          ),
                        ),
                      ],
                    ),
                  )
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}