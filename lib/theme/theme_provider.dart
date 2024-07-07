import 'package:flutter/material.dart';
import 'theme.dart';

class ThemeProvider extends ChangeNotifier {
  // initially, starts with light mode
  ThemeData _themeData = lightMode;

  // getter method for theme data
  ThemeData get themeData => _themeData;

  // getter method for dark mode
  bool get isDarkMode => _themeData == darkMode;

  set themeData(ThemeData themeData) {
    _themeData = themeData;
    notifyListeners();
  }

  void toggleTheme() {
    _themeData = isDarkMode ? lightMode : darkMode;
    notifyListeners();
  } 
}
