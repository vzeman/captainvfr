import 'package:flutter/material.dart';
import '../services/focus_manager_service.dart';

/// Mixin to automatically track text field focus in forms
/// This helps prevent background services from causing focus loss
mixin TextFieldFocusMixin<T extends StatefulWidget> on State<T> {
  final _focusManager = FocusManagerService();
  final Map<String, FocusNode> _focusNodes = {};
  
  /// Create a focus node that automatically tracks focus state
  FocusNode createFocusNode(String key) {
    if (_focusNodes.containsKey(key)) {
      return _focusNodes[key]!;
    }
    
    final focusNode = FocusNode();
    _focusNodes[key] = focusNode;
    
    focusNode.addListener(() {
      if (focusNode.hasFocus) {
        _focusManager.onTextFieldFocusGained();
      } else {
        _focusManager.onTextFieldFocusLost();
      }
    });
    
    return focusNode;
  }
  
  @override
  void dispose() {
    // Clean up all focus nodes
    for (final focusNode in _focusNodes.values) {
      focusNode.dispose();
    }
    _focusNodes.clear();
    super.dispose();
  }
}