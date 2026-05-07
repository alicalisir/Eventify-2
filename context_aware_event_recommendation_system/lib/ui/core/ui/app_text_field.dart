import 'package:flutter/material.dart';

/// Custom text field with validation
class AppTextField extends StatelessWidget {
  final TextEditingController? controller;
  final String? label;
  final String? hint;
  final String? errorText;
  final bool obscureText;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onChanged;
  final FormFieldValidator<String>? validator;
  final Widget? suffixIcon;
  final Widget? prefixIcon;
  final bool enabled;
  final bool autofocus;
  final int maxLines;
  final FocusNode? focusNode;
  final VoidCallback? onEditingComplete;

  const AppTextField({
    super.key,
    this.controller,
    this.label,
    this.hint,
    this.errorText,
    this.obscureText = false,
    this.keyboardType,
    this.textInputAction,
    this.onChanged,
    this.validator,
    this.suffixIcon,
    this.prefixIcon,
    this.enabled = true,
    this.autofocus = false,
    this.maxLines = 1,
    this.focusNode,
    this.onEditingComplete,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      textField: true,
      label: label,
      child: TextFormField(
        controller: controller,
        obscureText: obscureText,
        keyboardType: keyboardType,
        textInputAction: textInputAction,
        onChanged: onChanged,
        validator: validator,
        enabled: enabled,
        autofocus: autofocus,
        maxLines: maxLines,
        focusNode: focusNode,
        onEditingComplete: onEditingComplete,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          errorText: errorText,
          suffixIcon: suffixIcon,
          prefixIcon: prefixIcon,
        ),
      ),
    );
  }
}
