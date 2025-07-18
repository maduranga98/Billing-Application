import 'package:flutter/material.dart';

// Theme Constants and Utilities
class ThemeConstants {
  // Spacing Constants
  static const double spacingXs = 4.0;
  static const double spacingSm = 8.0;
  static const double spacingMd = 16.0;
  static const double spacingLg = 24.0;
  static const double spacingXl = 32.0;
  static const double spacingXxl = 48.0;

  // Border Radius Constants
  static const double radiusXs = 4.0;
  static const double radiusSm = 8.0;
  static const double radiusMd = 12.0;
  static const double radiusLg = 16.0;
  static const double radiusXl = 24.0;
  static const double radiusFull = 100.0;

  // Elevation Constants
  static const double elevationNone = 0.0;
  static const double elevationXs = 1.0;
  static const double elevationSm = 2.0;
  static const double elevationMd = 4.0;
  static const double elevationLg = 8.0;
  static const double elevationXl = 12.0;

  // Font Sizes
  static const double fontSizeXs = 10.0;
  static const double fontSizeSm = 12.0;
  static const double fontSizeMd = 14.0;
  static const double fontSizeLg = 16.0;
  static const double fontSizeXl = 18.0;
  static const double fontSizeXxl = 20.0;
  static const double fontSizeXxxl = 24.0;

  // Icon Sizes
  static const double iconSizeXs = 16.0;
  static const double iconSizeSm = 20.0;
  static const double iconSizeMd = 24.0;
  static const double iconSizeLg = 32.0;
  static const double iconSizeXl = 40.0;

  // Layout Constants
  static const double maxContentWidth = 1200.0;
  static const double minButtonHeight = 48.0;
  static const double minTouchTarget = 44.0;
  static const double appBarHeight = 56.0;
  static const double bottomNavHeight = 60.0;
  static const double fabSize = 56.0;

  // Animation Durations
  static const Duration animationFast = Duration(milliseconds: 150);
  static const Duration animationNormal = Duration(milliseconds: 300);
  static const Duration animationSlow = Duration(milliseconds: 500);

  // Common Curves
  static const Curve curveDefault = Curves.easeInOut;
  static const Curve curveEaseIn = Curves.easeIn;
  static const Curve curveEaseOut = Curves.easeOut;
  static const Curve curveBounce = Curves.bounceOut;
}

// Theme Utilities
class ThemeUtils {
  // Get responsive font size based on screen size
  static double getResponsiveFontSize(
    BuildContext context,
    double baseFontSize,
  ) {
    final screenWidth = MediaQuery.of(context).size.width;
    if (screenWidth < 600) {
      return baseFontSize * 0.9;
    } else if (screenWidth < 1200) {
      return baseFontSize;
    } else {
      return baseFontSize * 1.1;
    }
  }

  // Get responsive padding based on screen size
  static EdgeInsets getResponsivePadding(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    if (screenWidth < 600) {
      return const EdgeInsets.all(ThemeConstants.spacingMd);
    } else if (screenWidth < 1200) {
      return const EdgeInsets.all(ThemeConstants.spacingLg);
    } else {
      return const EdgeInsets.all(ThemeConstants.spacingXl);
    }
  }

  // Get responsive margin based on screen size
  static EdgeInsets getResponsiveMargin(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    if (screenWidth < 600) {
      return const EdgeInsets.all(ThemeConstants.spacingSm);
    } else {
      return const EdgeInsets.all(ThemeConstants.spacingMd);
    }
  }

  // Check if screen is mobile
  static bool isMobile(BuildContext context) {
    return MediaQuery.of(context).size.width < 600;
  }

  // Check if screen is tablet
  static bool isTablet(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    return width >= 600 && width < 1200;
  }

  // Check if screen is desktop
  static bool isDesktop(BuildContext context) {
    return MediaQuery.of(context).size.width >= 1200;
  }

  // Get safe area padding
  static EdgeInsets getSafeAreaPadding(BuildContext context) {
    return MediaQuery.of(context).padding;
  }

  // Create consistent box shadow
  static List<BoxShadow> createShadow({
    Color? color,
    double blurRadius = 8.0,
    double spreadRadius = 0.0,
    Offset offset = const Offset(0, 2),
  }) {
    return [
      BoxShadow(
        color: color ?? Colors.black.withOpacity(0.1),
        blurRadius: blurRadius,
        spreadRadius: spreadRadius,
        offset: offset,
      ),
    ];
  }

  // Create consistent border radius
  static BorderRadius createBorderRadius({
    double? all,
    double? topLeft,
    double? topRight,
    double? bottomLeft,
    double? bottomRight,
  }) {
    if (all != null) {
      return BorderRadius.circular(all);
    }
    return BorderRadius.only(
      topLeft: Radius.circular(topLeft ?? 0),
      topRight: Radius.circular(topRight ?? 0),
      bottomLeft: Radius.circular(bottomLeft ?? 0),
      bottomRight: Radius.circular(bottomRight ?? 0),
    );
  }

  // Create consistent gradient
  static LinearGradient createGradient({
    required List<Color> colors,
    AlignmentGeometry begin = Alignment.topLeft,
    AlignmentGeometry end = Alignment.bottomRight,
  }) {
    return LinearGradient(colors: colors, begin: begin, end: end);
  }

  // Get color brightness
  static bool isColorDark(Color color) {
    return color.computeLuminance() < 0.5;
  }

  // Get contrast color
  static Color getContrastColor(Color color) {
    return isColorDark(color) ? Colors.white : Colors.black;
  }

  // Darken color
  static Color darkenColor(Color color, double amount) {
    final hsl = HSLColor.fromColor(color);
    return hsl
        .withLightness((hsl.lightness - amount).clamp(0.0, 1.0))
        .toColor();
  }

  // Lighten color
  static Color lightenColor(Color color, double amount) {
    final hsl = HSLColor.fromColor(color);
    return hsl
        .withLightness((hsl.lightness + amount).clamp(0.0, 1.0))
        .toColor();
  }

  // Create ripple effect
  static Widget createRipple({
    required Widget child,
    required VoidCallback onTap,
    BorderRadius? borderRadius,
    Color? splashColor,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius:
            borderRadius ?? BorderRadius.circular(ThemeConstants.radiusMd),
        splashColor: splashColor,
        child: child,
      ),
    );
  }
}

// Responsive Layout Helper
class ResponsiveLayout extends StatelessWidget {
  final Widget mobile;
  final Widget? tablet;
  final Widget? desktop;

  const ResponsiveLayout({
    super.key,
    required this.mobile,
    this.tablet,
    this.desktop,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= 1200) {
          return desktop ?? tablet ?? mobile;
        } else if (constraints.maxWidth >= 600) {
          return tablet ?? mobile;
        } else {
          return mobile;
        }
      },
    );
  }
}

// Responsive Grid Helper
class ResponsiveGrid extends StatelessWidget {
  final List<Widget> children;
  final double spacing;
  final int mobileColumns;
  final int tabletColumns;
  final int desktopColumns;

  const ResponsiveGrid({
    super.key,
    required this.children,
    this.spacing = ThemeConstants.spacingMd,
    this.mobileColumns = 1,
    this.tabletColumns = 2,
    this.desktopColumns = 3,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        int columns;
        if (constraints.maxWidth >= 1200) {
          columns = desktopColumns;
        } else if (constraints.maxWidth >= 600) {
          columns = tabletColumns;
        } else {
          columns = mobileColumns;
        }

        return GridView.builder(
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            crossAxisSpacing: spacing,
            mainAxisSpacing: spacing,
            childAspectRatio: 1.0,
          ),
          itemCount: children.length,
          itemBuilder: (context, index) => children[index],
        );
      },
    );
  }
}

// Theme Animation Helper
class ThemeAnimations {
  // Slide in from bottom
  static Widget slideInFromBottom({
    required Widget child,
    required AnimationController controller,
    Duration delay = Duration.zero,
  }) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        final animation = Tween<Offset>(
          begin: const Offset(0, 1),
          end: Offset.zero,
        ).animate(
          CurvedAnimation(
            parent: controller,
            curve: Interval(
              delay.inMilliseconds / controller.duration!.inMilliseconds,
              1.0,
              curve: ThemeConstants.curveDefault,
            ),
          ),
        );

        return SlideTransition(position: animation, child: child);
      },
      child: child,
    );
  }

  // Fade in
  static Widget fadeIn({
    required Widget child,
    required AnimationController controller,
    Duration delay = Duration.zero,
  }) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        final animation = Tween<double>(begin: 0.0, end: 1.0).animate(
          CurvedAnimation(
            parent: controller,
            curve: Interval(
              delay.inMilliseconds / controller.duration!.inMilliseconds,
              1.0,
              curve: ThemeConstants.curveDefault,
            ),
          ),
        );

        return FadeTransition(opacity: animation, child: child);
      },
      child: child,
    );
  }

  // Scale in
  static Widget scaleIn({
    required Widget child,
    required AnimationController controller,
    Duration delay = Duration.zero,
  }) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        final animation = Tween<double>(begin: 0.0, end: 1.0).animate(
          CurvedAnimation(
            parent: controller,
            curve: Interval(
              delay.inMilliseconds / controller.duration!.inMilliseconds,
              1.0,
              curve: ThemeConstants.curveBounce,
            ),
          ),
        );

        return ScaleTransition(scale: animation, child: child);
      },
      child: child,
    );
  }
}

// Common UI Components with Theme
class ThemedComponents {
  // Themed Divider
  static Widget divider({
    double? height,
    double? thickness,
    Color? color,
    double? indent,
    double? endIndent,
  }) {
    return Divider(
      height: height ?? ThemeConstants.spacingMd,
      thickness: thickness ?? 1.0,
      color: color,
      indent: indent,
      endIndent: endIndent,
    );
  }

  // Themed Spacer
  static Widget verticalSpace(double height) {
    return SizedBox(height: height);
  }

  static Widget horizontalSpace(double width) {
    return SizedBox(width: width);
  }

  // Themed Loading Button
  static Widget loadingButton({
    required String text,
    required bool isLoading,
    required VoidCallback? onPressed,
    IconData? icon,
    Color? backgroundColor,
    Color? foregroundColor,
  }) {
    return ElevatedButton(
      onPressed: isLoading ? null : onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: backgroundColor,
        foregroundColor: foregroundColor,
      ),
      child:
          isLoading
              ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
              : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: ThemeConstants.iconSizeSm),
                    const SizedBox(width: ThemeConstants.spacingSm),
                  ],
                  Text(text),
                ],
              ),
    );
  }

  // Themed Info Card
  static Widget infoCard({
    required String title,
    required String value,
    IconData? icon,
    Color? color,
    VoidCallback? onTap,
  }) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(ThemeConstants.radiusMd),
        child: Padding(
          padding: const EdgeInsets.all(ThemeConstants.spacingMd),
          child: Row(
            children: [
              if (icon != null) ...[
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: (color ?? Colors.blue).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(
                      ThemeConstants.radiusSm,
                    ),
                  ),
                  child: Icon(
                    icon,
                    color: color ?? Colors.blue,
                    size: ThemeConstants.iconSizeSm,
                  ),
                ),
                const SizedBox(width: ThemeConstants.spacingMd),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: ThemeConstants.fontSizeSm,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: ThemeConstants.spacingXs),
                    Text(
                      value,
                      style: TextStyle(
                        fontSize: ThemeConstants.fontSizeLg,
                        fontWeight: FontWeight.w600,
                        color: color ?? Colors.blue,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
