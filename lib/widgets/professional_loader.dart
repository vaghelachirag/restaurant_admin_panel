import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';

enum LoaderType {
  pulseDots,
  waveBounce,
  rotatingSquares,
  slidingBars,
  morphingCircle,
  foodLoader,
}

class ProfessionalLoader extends StatefulWidget {
  final LoaderType type;
  final Color? primaryColor;
  final Color? secondaryColor;
  final double? size;
  final String? message;
  final Duration duration;

  const ProfessionalLoader({
    super.key,
    this.type = LoaderType.foodLoader,
    this.primaryColor,
    this.secondaryColor,
    this.size,
    this.message,
    this.duration = const Duration(milliseconds: 1500),
  });

  @override
  State<ProfessionalLoader> createState() => _ProfessionalLoaderState();
}

class _ProfessionalLoaderState extends State<ProfessionalLoader>
    with TickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: widget.duration,
      vsync: this,
    );
    _animation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
    _controller.repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = widget.primaryColor ?? const Color(0xFF7C3AED);
    final secondaryColor = widget.secondaryColor ?? const Color(0xFFEC4899);
    final size = widget.size ?? (kIsWeb ? 80.0 : 80.w);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildLoader(primaryColor, secondaryColor, size),
        if (widget.message != null) ...[
          SizedBox(height: kIsWeb ? 24 : 24.h),
          Text(
            widget.message!,
            style: GoogleFonts.poppins(
              fontSize: kIsWeb ? 16 : 16.sp,
              fontWeight: FontWeight.w500,
              color: Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ],
    );
  }

  Widget _buildLoader(Color primaryColor, Color secondaryColor, double size) {
    switch (widget.type) {
      case LoaderType.pulseDots:
        return _PulseDotsLoader(
          animation: _animation,
          primaryColor: primaryColor,
          secondaryColor: secondaryColor,
          size: size,
        );
      case LoaderType.waveBounce:
        return _WaveBounceLoader(
          animation: _animation,
          primaryColor: primaryColor,
          secondaryColor: secondaryColor,
          size: size,
        );
      case LoaderType.rotatingSquares:
        return _RotatingSquaresLoader(
          animation: _animation,
          primaryColor: primaryColor,
          secondaryColor: secondaryColor,
          size: size,
        );
      case LoaderType.slidingBars:
        return _SlidingBarsLoader(
          animation: _animation,
          primaryColor: primaryColor,
          secondaryColor: secondaryColor,
          size: size,
        );
      case LoaderType.morphingCircle:
        return _MorphingCircleLoader(
          animation: _animation,
          primaryColor: primaryColor,
          secondaryColor: secondaryColor,
          size: size,
        );
      case LoaderType.foodLoader:
        return _FoodLoader(
          animation: _animation,
          primaryColor: primaryColor,
          secondaryColor: secondaryColor,
          size: size,
        );
    }
  }
}

class _PulseDotsLoader extends StatelessWidget {
  final Animation<double> animation;
  final Color primaryColor;
  final Color secondaryColor;
  final double size;

  const _PulseDotsLoader({
    required this.animation,
    required this.primaryColor,
    required this.secondaryColor,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: List.generate(3, (index) {
          final delay = index * 0.2;
          return AnimatedBuilder(
            animation: animation,
            builder: (context, child) {
              final value = (animation.value + delay) % 1.0;
              final scale = 0.5 + (sin(value * pi * 2) + 1) * 0.25;
              final opacity = 0.3 + (sin(value * pi * 2) + 1) * 0.35;
              return Transform.scale(
                scale: scale,
                child: Container(
                  width: size * 0.2,
                  height: size * 0.2,
                  decoration: BoxDecoration(
                    color: index == 1 ? primaryColor : secondaryColor,
                    shape: BoxShape.circle,
                  ),
                ),
              );
            },
          );
        }),
      ),
    );
  }
}

class _WaveBounceLoader extends StatelessWidget {
  final Animation<double> animation;
  final Color primaryColor;
  final Color secondaryColor;
  final double size;

  const _WaveBounceLoader({
    required this.animation,
    required this.primaryColor,
    required this.secondaryColor,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: List.generate(4, (index) {
          final delay = index * 0.15;
          return AnimatedBuilder(
            animation: animation,
            builder: (context, child) {
              final value = (animation.value + delay) % 1.0;
              final height = size * 0.3 + (sin(value * pi * 2) + 1) * size * 0.2;
              return Container(
                width: size * 0.15,
                height: height,
                decoration: BoxDecoration(
                  color: index % 2 == 0 ? primaryColor : secondaryColor,
                  borderRadius: BorderRadius.circular(size * 0.075),
                ),
              );
            },
          );
        }),
      ),
    );
  }
}

class _RotatingSquaresLoader extends StatelessWidget {
  final Animation<double> animation;
  final Color primaryColor;
  final Color secondaryColor;
  final double size;

  const _RotatingSquaresLoader({
    required this.animation,
    required this.primaryColor,
    required this.secondaryColor,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        children: List.generate(4, (index) {
          return AnimatedBuilder(
            animation: animation,
            builder: (context, child) {
              final rotation = animation.value * 2 * pi + (index * pi / 2);
              final scale = 0.6 + sin(animation.value * 2 * pi + index) * 0.2;
              return Transform.rotate(
                angle: rotation,
                child: Transform.scale(
                  scale: scale,
                  child: Center(
                    child: Container(
                      width: size * 0.3,
                      height: size * 0.3,
                      decoration: BoxDecoration(
                        color: index % 2 == 0 ? primaryColor : secondaryColor,
                        borderRadius: BorderRadius.circular(size * 0.05),
                      ),
                    ),
                  ),
                ),
              );
            },
          );
        }),
      ),
    );
  }
}

class _SlidingBarsLoader extends StatelessWidget {
  final Animation<double> animation;
  final Color primaryColor;
  final Color secondaryColor;
  final double size;

  const _SlidingBarsLoader({
    required this.animation,
    required this.primaryColor,
    required this.secondaryColor,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: List.generate(5, (index) {
          final delay = index * 0.1;
          return AnimatedBuilder(
            animation: animation,
            builder: (context, child) {
              final value = (animation.value + delay) % 1.0;
              final width = size * 0.2 + (sin(value * pi * 2) + 1) * size * 0.3;
              return Container(
                height: size * 0.08,
                width: width,
                decoration: BoxDecoration(
                  color: index % 2 == 0 ? primaryColor : secondaryColor,
                  borderRadius: BorderRadius.circular(size * 0.04),
                ),
              );
            },
          );
        }),
      ),
    );
  }
}

class _MorphingCircleLoader extends StatelessWidget {
  final Animation<double> animation;
  final Color primaryColor;
  final Color secondaryColor;
  final double size;

  const _MorphingCircleLoader({
    required this.animation,
    required this.primaryColor,
    required this.secondaryColor,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        final value = animation.value;
        final borderRadius = BorderRadius.circular(
          size * 0.1 + (sin(value * pi * 2) + 1) * size * 0.3,
        );
        final rotation = value * 2 * pi;
        
        return Transform.rotate(
          angle: rotation,
          child: Container(
            width: size * 0.6,
            height: size * 0.6,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [primaryColor, secondaryColor],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: borderRadius,
            ),
          ),
        );
      },
    );
  }
}

class _FoodLoader extends StatelessWidget {
  final Animation<double> animation;
  final Color primaryColor;
  final Color secondaryColor;
  final double size;

  const _FoodLoader({
    required this.animation,
    required this.primaryColor,
    required this.secondaryColor,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: AnimatedBuilder(
        animation: animation,
        builder: (context, child) {
          final rotation = animation.value * 2 * pi;
          final scale = 0.8 + sin(animation.value * pi * 2) * 0.1;
          
          return Transform.scale(
            scale: scale,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Outer rotating ring
                Transform.rotate(
                  angle: rotation,
                  child: Container(
                    width: size * 0.8,
                    height: size * 0.8,
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: primaryColor.withOpacity(0.3),
                        width: size * 0.04,
                      ),
                      borderRadius: BorderRadius.circular(size * 0.4),
                    ),
                  ),
                ),
                // Inner rotating ring (opposite direction)
                Transform.rotate(
                  angle: -rotation * 1.5,
                  child: Container(
                    width: size * 0.6,
                    height: size * 0.6,
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: secondaryColor.withOpacity(0.3),
                        width: size * 0.04,
                      ),
                      borderRadius: BorderRadius.circular(size * 0.3),
                    ),
                  ),
                ),
                // Center icon
                Container(
                  width: size * 0.4,
                  height: size * 0.4,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [primaryColor, secondaryColor],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(size * 0.2),
                  ),
                  child: Icon(
                    Icons.restaurant_rounded,
                    color: Colors.white,
                    size: size * 0.2,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class FullScreenLoader extends StatelessWidget {
  final LoaderType type;
  final String message;
  final Color? backgroundColor;
  final Color? primaryColor;
  final Color? secondaryColor;

  const FullScreenLoader({
    super.key,
    this.type = LoaderType.foodLoader,
    this.message = 'Loading...',
    this.backgroundColor,
    this.primaryColor,
    this.secondaryColor,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor ?? Colors.white,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: kIsWeb ? 20 : 20.w),
            child: ProfessionalLoader(
              type: type,
              message: message,
              primaryColor: primaryColor,
              secondaryColor: secondaryColor,
              size: kIsWeb ? 100 : 100.w,
            ),
          ),
        ),
      ),
    );
  }
}

class OverlayLoader extends StatelessWidget {
  final Widget child;
  final bool isLoading;
  final LoaderType type;
  final String message;
  final Color? overlayColor;
  final Color? primaryColor;
  final Color? secondaryColor;

  const OverlayLoader({
    super.key,
    required this.child,
    required this.isLoading,
    this.type = LoaderType.foodLoader,
    this.message = 'Loading...',
    this.overlayColor,
    this.primaryColor,
    this.secondaryColor,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,
        if (isLoading)
          Container(
            color: (overlayColor ?? Colors.black).withOpacity(0.5),
            child: Center(
              child: Card(
                elevation: 8,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(kIsWeb ? 16 : 16.sp),
                ),
                child: Padding(
                  padding: EdgeInsets.all(kIsWeb ? 32 : 32.sp),
                  child: ProfessionalLoader(
                    type: type,
                    message: message,
                    primaryColor: primaryColor,
                    secondaryColor: secondaryColor,
                    size: kIsWeb ? 80 : 80.w,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
