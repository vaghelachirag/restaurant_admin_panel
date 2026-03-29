import 'package:flutter/foundation.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'professional_loader.dart';

class LoadingCard extends StatefulWidget {
  final double? width;
  final double? height;
  final BorderRadius? borderRadius;
  final Color? backgroundColor;
  final LoaderType loaderType;
  final String? message;

  const LoadingCard({
    super.key,
    this.width,
    this.height,
    this.borderRadius,
    this.backgroundColor,
    this.loaderType = LoaderType.pulseDots,
    this.message,
  });

  @override
  State<LoadingCard> createState() => _LoadingCardState();
}

class _LoadingCardState extends State<LoadingCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );

    _scaleAnimation = Tween<double>(begin: 0.95, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutBack),
    );

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return FadeTransition(
          opacity: _fadeAnimation,
          child: ScaleTransition(
            scale: _scaleAnimation,
            child: Container(
              width: widget.width ?? double.infinity,
              height: widget.height ?? (kIsWeb ? 200 : 200.h),
              decoration: BoxDecoration(
                color: widget.backgroundColor ?? Colors.white,
                borderRadius: widget.borderRadius ?? BorderRadius.circular(kIsWeb ? 12 : 12.sp),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Center(
                child: ProfessionalLoader(
                  type: widget.loaderType,
                  message: widget.message,
                  size: kIsWeb ? 50 : 50.w,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class ShimmerLoadingCard extends StatefulWidget {
  final double? width;
  final double? height;
  final BorderRadius? borderRadius;
  final Widget? child;

  const ShimmerLoadingCard({
    super.key,
    this.width,
    this.height,
    this.borderRadius,
    this.child,
  });

  @override
  State<ShimmerLoadingCard> createState() => _ShimmerLoadingCardState();
}

class _ShimmerLoadingCardState extends State<ShimmerLoadingCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _animation = Tween<double>(begin: -2.0, end: 2.0).animate(
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
    return Container(
      width: widget.width ?? double.infinity,
      height: widget.height ?? (kIsWeb ? 120 : 120.h),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: widget.borderRadius ?? BorderRadius.circular(kIsWeb ? 12 : 12.sp),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Stack(
        children: [
          if (widget.child != null) widget.child!,
          AnimatedBuilder(
            animation: _animation,
            builder: (context, child) {
              return Container(
                decoration: BoxDecoration(
                  borderRadius: widget.borderRadius ?? BorderRadius.circular(kIsWeb ? 12 : 12.sp),
                  gradient: LinearGradient(
                    begin: Alignment(-1.0 + _animation.value, 0.0),
                    end: Alignment(1.0 + _animation.value, 0.0),
                    colors: [
                      Colors.transparent,
                      Colors.white.withOpacity(0.3),
                      Colors.transparent,
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class MenuCardSkeleton extends StatelessWidget {
  final double? width;
  final double? height;

  const MenuCardSkeleton({
    super.key,
    this.width,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width ?? double.infinity,
      height: height ?? (kIsWeb ? 140 : 140.h),
      margin: EdgeInsets.symmetric(
        horizontal: kIsWeb ? 16 : 16.w,
        vertical: kIsWeb ? 5 : 5.h,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(kIsWeb ? 14 : 14.sp),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          // Image skeleton
          ShimmerLoadingCard(
            width: kIsWeb ? 120 : 120.w,
            height: double.infinity,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(kIsWeb ? 14 : 14.sp),
              bottomLeft: Radius.circular(kIsWeb ? 14 : 14.sp),
            ),
          ),
          // Content skeleton
          Expanded(
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: kIsWeb ? 14 : 14.w,
                vertical: kIsWeb ? 10 : 10.h,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title skeleton
                  ShimmerLoadingCard(
                    height: kIsWeb ? 16 : 16.h,
                    width: double.infinity,
                    borderRadius: BorderRadius.circular(kIsWeb ? 4 : 4.sp),
                  ),
                  SizedBox(height: kIsWeb ? 7 : 7.h),
                  // Description skeleton
                  ShimmerLoadingCard(
                    height: kIsWeb ? 12 : 12.h,
                    width: kIsWeb ? 200 : 200.w,
                    borderRadius: BorderRadius.circular(kIsWeb ? 4 : 4.sp),
                  ),
                  SizedBox(height: kIsWeb ? 7 : 7.h),
                  // Variant skeleton
                  ShimmerLoadingCard(
                    height: kIsWeb ? 24 : 24.h,
                    width: kIsWeb ? 100 : 100.w,
                    borderRadius: BorderRadius.circular(kIsWeb ? 12 : 12.sp),
                  ),
                  const Spacer(),
                  // Price and button skeleton
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      ShimmerLoadingCard(
                        height: kIsWeb ? 20 : 20.h,
                        width: kIsWeb ? 50 : 50.w,
                        borderRadius: BorderRadius.circular(kIsWeb ? 4 : 4.sp),
                      ),
                      ShimmerLoadingCard(
                        height: kIsWeb ? 34 : 34.h,
                        width: kIsWeb ? 60 : 60.w,
                        borderRadius: BorderRadius.circular(kIsWeb ? 8 : 8.sp),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class CategoryCardSkeleton extends StatelessWidget {
  final double? width;
  final double? height;

  const CategoryCardSkeleton({
    super.key,
    this.width,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width ?? (kIsWeb ? 150 : 150.w),
      height: height ?? (kIsWeb ? 80 : 80.h),
      margin: EdgeInsets.only(right: kIsWeb ? 10 : 10.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(kIsWeb ? 24 : 24.sp),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ShimmerLoadingCard(
        borderRadius: BorderRadius.circular(kIsWeb ? 24 : 24.sp),
      ),
    );
  }
}

class AnimatedLoadingState extends StatefulWidget {
  final Widget child;
  final bool isLoading;
  final Duration duration;

  const AnimatedLoadingState({
    super.key,
    required this.child,
    required this.isLoading,
    this.duration = const Duration(milliseconds: 300),
  });

  @override
  State<AnimatedLoadingState> createState() => _AnimatedLoadingState();
}

class _AnimatedLoadingState extends State<AnimatedLoadingState>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: widget.duration,
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );

    if (!widget.isLoading) {
      _controller.forward();
    }
  }

  @override
  void didUpdateWidget(AnimatedLoadingState oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isLoading != widget.isLoading) {
      if (widget.isLoading) {
        _controller.reverse();
      } else {
        _controller.forward();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: widget.duration,
      child: widget.isLoading
          ? const SizedBox.shrink()
          : FadeTransition(
              opacity: _fadeAnimation,
              child: widget.child,
            ),
    );
  }
}
