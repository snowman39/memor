import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';

// Animation constants for native-like feel
class AppAnimations {
  static const Duration fast = Duration(milliseconds: 150);
  static const Duration normal = Duration(milliseconds: 200);
  static const Duration slow = Duration(milliseconds: 300);

  static const Curve defaultCurve = Curves.easeOutCubic;
  static const Curve bounceCurve = Curves.easeOutBack;
}

/// Custom scroll physics like iOS Notes app
/// - Hard limit on overscroll distance (~60px)
/// - Weighty, premium feel with drag resistance
class NativeScrollPhysics extends BouncingScrollPhysics {
  const NativeScrollPhysics({super.parent});

  static const double maxOverscroll = 70.0;
  static const double dragResistance = 0.9; // 0.0 = no resistance, 1.0 = immovable

  @override
  NativeScrollPhysics applyTo(ScrollPhysics? ancestor) {
    return NativeScrollPhysics(parent: buildParent(ancestor));
  }

  // Heavier, slower spring for premium feel
  @override
  SpringDescription get spring => const SpringDescription(
        mass: 2.0,      // heavier = slower movement
        stiffness: 100, // lower = slower bounce-back
        damping: 22,    // balanced damping
      );

  // Apply drag resistance in overscroll zone
  @override
  double applyPhysicsToUserOffset(ScrollMetrics position, double offset) {
    // Check if we're in or entering overscroll territory
    final pixels = position.pixels;
    final minExtent = position.minScrollExtent;
    final maxExtent = position.maxScrollExtent;

    // In overscroll zone - apply resistance
    if (pixels < minExtent || pixels > maxExtent) {
      return offset * (1.0 - dragResistance);
    }

    // About to enter overscroll - apply gradual resistance
    final newPixels = pixels + offset;
    if (newPixels < minExtent) {
      final normalPart = minExtent - pixels;
      final overscrollPart = offset - normalPart;
      return normalPart + overscrollPart * (1.0 - dragResistance);
    }
    if (newPixels > maxExtent) {
      final normalPart = maxExtent - pixels;
      final overscrollPart = offset - normalPart;
      return normalPart + overscrollPart * (1.0 - dragResistance);
    }

    return offset;
  }

  // Hard limit on overscroll distance
  @override
  double applyBoundaryConditions(ScrollMetrics position, double value) {
    final double minBound = position.minScrollExtent - maxOverscroll;
    final double maxBound = position.maxScrollExtent + maxOverscroll;

    if (value < minBound) return value - minBound;
    if (value > maxBound) return value - maxBound;
    return 0.0;
  }

  // Custom ballistic simulation - directly handle overscroll bounce-back
  @override
  Simulation? createBallisticSimulation(
      ScrollMetrics position, double velocity) {
    final clampedVelocity = velocity.clamp(-2000.0, 2000.0);
    final pixels = position.pixels;
    final minExtent = position.minScrollExtent;
    final maxExtent = position.maxScrollExtent;

    // If overscrolled, create spring simulation to bounce back
    if (pixels < minExtent) {
      // Overscrolled at top - velocity must point toward target (>= 0)
      final bounceVelocity = clampedVelocity > 0 ? clampedVelocity : 0.0;
      return ScrollSpringSimulation(spring, pixels, minExtent, bounceVelocity);
    } else if (pixels > maxExtent) {
      // Overscrolled at bottom - velocity must point toward target (<= 0)
      final bounceVelocity = clampedVelocity < 0 ? clampedVelocity : 0.0;
      return ScrollSpringSimulation(spring, pixels, maxExtent, bounceVelocity);
    }

    // Not overscrolled - use parent's behavior
    return super.createBallisticSimulation(position, clampedVelocity);
  }
}

// Common page transitions theme (Cupertino style for Apple platforms)
const _pageTransitionsTheme = PageTransitionsTheme(
  builders: {
    TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
    TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
    TargetPlatform.android: CupertinoPageTransitionsBuilder(),
    TargetPlatform.windows: CupertinoPageTransitionsBuilder(),
    TargetPlatform.linux: CupertinoPageTransitionsBuilder(),
  },
);

// light mode
ThemeData lightMode = ThemeData(
  brightness: Brightness.light,
  colorScheme: ColorScheme.light(
    surface: Colors.white,
    primary: const Color(0xFFEDEDED),
    secondary: Colors.grey.shade400,
    inversePrimary: const Color(0xFF454545),
  ),
  fontFamily: 'SFProText',
  textSelectionTheme: TextSelectionThemeData(
    cursorColor: const Color(0xFFD0EAC8),
    selectionColor: const Color(0xFFD0EAC8).withOpacity(1.0),
    selectionHandleColor: const Color(0xFFD0EAC8),
  ),
  pageTransitionsTheme: _pageTransitionsTheme,
  // Smooth scrolling behavior
  scrollbarTheme: ScrollbarThemeData(
    thumbVisibility: WidgetStateProperty.all(false),
    thickness: WidgetStateProperty.all(6),
    radius: const Radius.circular(3),
  ),
);

// dark mode
ThemeData darkMode = ThemeData(
  brightness: Brightness.dark,
  colorScheme: ColorScheme.dark(
    surface: const Color.fromARGB(255, 24, 24, 24),
    primary: const Color.fromARGB(255, 34, 34, 34),
    secondary: const Color.fromARGB(255, 49, 49, 49),
    inversePrimary: Colors.grey.shade300,
  ),
  fontFamily: 'SFProText',
  textSelectionTheme: TextSelectionThemeData(
    cursorColor: const Color(0xFFD0EAC8),
    selectionColor: const Color(0xFFD0EAC8).withOpacity(1.0),
    selectionHandleColor: const Color(0xFFD0EAC8),
  ),
  pageTransitionsTheme: _pageTransitionsTheme,
  // Smooth scrolling behavior
  scrollbarTheme: ScrollbarThemeData(
    thumbVisibility: WidgetStateProperty.all(false),
    thickness: WidgetStateProperty.all(6),
    radius: const Radius.circular(3),
  ),
);
