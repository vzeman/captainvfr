import 'package:flutter/foundation.dart';

/// Global service to manage focus state and prevent background updates
/// when text fields have focus to prevent focus loss issues
class FocusManagerService extends ChangeNotifier {
  static final FocusManagerService _instance = FocusManagerService._internal();
  factory FocusManagerService() => _instance;
  FocusManagerService._internal();

  // Track number of active text fields with focus
  int _activeTextFieldCount = 0;
  
  // Track if any text field has focus
  bool get hasActiveTextFieldFocus => _activeTextFieldCount > 0;
  
  // Global flag to pause all background updates
  bool get shouldPauseBackgroundUpdates => hasActiveTextFieldFocus;
  
  // Called when a text field gains focus
  void onTextFieldFocusGained() {
    _activeTextFieldCount++;
    if (_activeTextFieldCount == 1) {
      // First text field gained focus
      notifyListeners();
    }
  }
  
  // Called when a text field loses focus
  void onTextFieldFocusLost() {
    if (_activeTextFieldCount > 0) {
      _activeTextFieldCount--;
      if (_activeTextFieldCount == 0) {
        // Last text field lost focus
        notifyListeners();
      }
    }
  }
  
  // Reset the focus count (useful for cleanup)
  void reset() {
    _activeTextFieldCount = 0;
    notifyListeners();
  }
}