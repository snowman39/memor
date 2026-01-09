import 'package:flutter/material.dart';

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
    cursorColor: const Color(0xFFD0EAC8), // 더 순수한 연두색
    selectionColor: const Color(0xFFD0EAC8).withOpacity(1.0),
    selectionHandleColor: const Color(0xFFD0EAC8),
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
    cursorColor: const Color(0xFFD0EAC8), // 더 순수한 연두색
    selectionColor: const Color(0xFFD0EAC8).withOpacity(1.0),
    selectionHandleColor: const Color(0xFFD0EAC8),
  ),
);
