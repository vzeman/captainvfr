import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/focus_manager_service.dart';

/// An enhanced text field that maintains focus even when keyboard appears/disappears
/// This widget uses a persistent FocusNode and handles keyboard-related rebuilds
class KeyboardAwareFocusField extends StatefulWidget {
  final TextEditingController? controller;
  final InputDecoration? decoration;
  final TextStyle? style;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onEditingComplete;
  final ValueChanged<String>? onSubmitted;
  final FormFieldValidator<String>? validator;
  final int? maxLines;
  final bool obscureText;
  final TextInputType? keyboardType;
  final bool enabled;
  final bool autofocus;
  final TextInputAction? textInputAction;
  final int? maxLength;
  final bool? showCursor;
  final bool readOnly;
  final VoidCallback? onTap;
  final ScrollController? scrollController;
  final TextAlign textAlign;
  final TextCapitalization textCapitalization;
  final List<TextInputFormatter>? inputFormatters;
  
  const KeyboardAwareFocusField({
    super.key,
    this.controller,
    this.decoration,
    this.style,
    this.onChanged,
    this.onEditingComplete,
    this.onSubmitted,
    this.validator,
    this.maxLines = 1,
    this.obscureText = false,
    this.keyboardType,
    this.enabled = true,
    this.autofocus = false,
    this.textInputAction,
    this.maxLength,
    this.showCursor,
    this.readOnly = false,
    this.onTap,
    this.scrollController,
    this.textAlign = TextAlign.start,
    this.textCapitalization = TextCapitalization.none,
    this.inputFormatters,
  });

  @override
  State<KeyboardAwareFocusField> createState() => _KeyboardAwareFocusFieldState();
}

class _KeyboardAwareFocusFieldState extends State<KeyboardAwareFocusField> 
    with WidgetsBindingObserver {
  late FocusNode _focusNode;
  final _focusManager = FocusManagerService();
  bool _hadFocus = false;
  bool _isKeyboardVisible = false;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode(debugLabel: 'KeyboardAwareFocusField');
    _focusNode.addListener(_onFocusChange);
    WidgetsBinding.instance.addObserver(this);
    
    // Auto-focus after frame if needed
    if (widget.autofocus) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !_focusNode.hasFocus) {
          _focusNode.requestFocus();
        }
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    if (_hadFocus) {
      _focusManager.onTextFieldFocusLost();
    }
    _focusNode.removeListener(_onFocusChange);
    _focusNode.dispose();
    super.dispose();
  }

  @override
  void didChangeMetrics() {
    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;
    final wasKeyboardVisible = _isKeyboardVisible;
    _isKeyboardVisible = keyboardHeight > 0;
    
    // If keyboard just appeared and we had focus, maintain it
    if (_isKeyboardVisible && !wasKeyboardVisible && _hadFocus) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !_focusNode.hasFocus) {
          _focusNode.requestFocus();
        }
      });
    }
  }

  void _onFocusChange() {
    if (_focusNode.hasFocus && !_hadFocus) {
      _hadFocus = true;
      _focusManager.onTextFieldFocusGained();
    } else if (!_focusNode.hasFocus && _hadFocus) {
      _hadFocus = false;
      _focusManager.onTextFieldFocusLost();
      
      // If we lost focus unexpectedly while keyboard is visible, try to regain it
      if (_isKeyboardVisible && mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && !_focusNode.hasFocus && _isKeyboardVisible) {
            _focusNode.requestFocus();
          }
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Wrap in a RepaintBoundary to prevent unnecessary repaints
    return RepaintBoundary(
      child: widget.validator != null
          ? TextFormField(
              controller: widget.controller,
              decoration: widget.decoration,
              style: widget.style,
              onChanged: widget.onChanged,
              onEditingComplete: widget.onEditingComplete,
              onFieldSubmitted: widget.onSubmitted,
              validator: widget.validator,
              maxLines: widget.maxLines,
              obscureText: widget.obscureText,
              keyboardType: widget.keyboardType,
              enabled: widget.enabled,
              autofocus: false, // We handle this manually
              focusNode: _focusNode,
              textInputAction: widget.textInputAction,
              maxLength: widget.maxLength,
              showCursor: widget.showCursor,
              readOnly: widget.readOnly,
              onTap: widget.onTap,
              scrollController: widget.scrollController,
              textAlign: widget.textAlign,
              textCapitalization: widget.textCapitalization,
              inputFormatters: widget.inputFormatters,
            )
          : TextField(
              controller: widget.controller,
              decoration: widget.decoration,
              style: widget.style,
              onChanged: widget.onChanged,
              onEditingComplete: widget.onEditingComplete,
              onSubmitted: widget.onSubmitted,
              maxLines: widget.maxLines,
              obscureText: widget.obscureText,
              keyboardType: widget.keyboardType,
              enabled: widget.enabled,
              autofocus: false, // We handle this manually
              focusNode: _focusNode,
              textInputAction: widget.textInputAction,
              maxLength: widget.maxLength,
              showCursor: widget.showCursor,
              readOnly: widget.readOnly,
              onTap: widget.onTap,
              scrollController: widget.scrollController,
              textAlign: widget.textAlign,
              textCapitalization: widget.textCapitalization,
              inputFormatters: widget.inputFormatters,
            ),
    );
  }
}