import 'package:flutter/material.dart';

/// Champ de texte standard avec label au-dessus (plus lisible qu'un
/// label flottant pour des utilisateurs peu à l'aise avec l'informatique).
class AppTextField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final String? hint;
  final bool obscureText;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;
  final void Function(String)? onChanged;
  final IconData? prefixIcon;
  final int maxLines;
  final bool autofocus;
  final bool enabled;
  final FocusNode? focusNode;

  const AppTextField({
    super.key,
    required this.label,
    required this.controller,
    this.hint,
    this.obscureText = false,
    this.keyboardType,
    this.validator,
    this.onChanged,
    this.prefixIcon,
    this.maxLines = 1,
    this.autofocus = false,
    this.enabled = true,
    this.focusNode,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          focusNode: focusNode,
          obscureText: obscureText,
          keyboardType: keyboardType,
          validator: validator,
          onChanged: onChanged,
          maxLines: maxLines,
          autofocus: autofocus,
          enabled: enabled,
          style: const TextStyle(fontSize: 16),
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: prefixIcon != null ? Icon(prefixIcon) : null,
          ),
        ),
      ],
    );
  }
}
