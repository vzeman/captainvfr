import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/focus_manager_service.dart';

/// A text field that automatically notifies the FocusManagerService
/// when it gains or loses focus to prevent background updates from
/// interfering with text input
class FocusAwareTextField extends StatefulWidget {
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
  final FocusNode? focusNode;
  final TextInputAction? textInputAction;
  final int? maxLength;
  final bool? showCursor;
  final bool readOnly;
  final VoidCallback? onTap;
  final ScrollController? scrollController;
  final TextAlign textAlign;
  final TextCapitalization textCapitalization;
  final List<TextInputFormatter>? inputFormatters;
  
  const FocusAwareTextField({
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
    this.focusNode,
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
  State<FocusAwareTextField> createState() => _FocusAwareTextFieldState();
}

class _FocusAwareTextFieldState extends State<FocusAwareTextField> {
  late FocusNode _focusNode;
  final _focusManager = FocusManagerService();
  bool _hadFocus = false;

  @override
  void initState() {
    super.initState();
    _focusNode = widget.focusNode ?? FocusNode();
    _focusNode.addListener(_onFocusChange);
  }

  @override
  void dispose() {
    if (_hadFocus) {
      // Make sure we clean up if we had focus
      _focusManager.onTextFieldFocusLost();
    }
    if (widget.focusNode == null) {
      _focusNode.dispose();
    } else {
      _focusNode.removeListener(_onFocusChange);
    }
    super.dispose();
  }

  void _onFocusChange() {
    if (_focusNode.hasFocus && !_hadFocus) {
      _hadFocus = true;
      _focusManager.onTextFieldFocusGained();
    } else if (!_focusNode.hasFocus && _hadFocus) {
      _hadFocus = false;
      _focusManager.onTextFieldFocusLost();
    }
  }

  @override
  Widget build(BuildContext context) {
    // Check if this is being used in a form
    final isFormField = widget.validator != null;
    
    if (isFormField) {
      return TextFormField(
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
        autofocus: widget.autofocus,
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
      );
    } else {
      return TextField(
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
        autofocus: widget.autofocus,
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
      );
    }
  }
}

