import 'package:flutter/material.dart';

class CommonTextField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final bool obscure;
  final Widget? suffix;
  final TextInputType keyboardType;
  final VoidCallback? onToggle;
  final Iterable<String>? autofillHints;
  final int maxLines;
  final String? errorText;
  final bool requiredField;

  const CommonTextField({
    super.key,
    required this.label,
    required this.controller,
    this.obscure = false,
    this.suffix,
    this.keyboardType = TextInputType.text,
    this.onToggle,
    this.autofillHints,
    this.maxLines = 1,
    this.errorText,
    this.requiredField = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                color: Theme.of(context).textTheme.bodyMedium?.color,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (requiredField) ...[
              const SizedBox(width: 4),
              const Icon(
                Icons.error_outline,
                size: 14,
                color: Colors.red,
              ),
            ],
          ],
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          obscureText: obscure,
          keyboardType: keyboardType,
          autofillHints: autofillHints,
          maxLines: maxLines,
          style: TextStyle(
            color: Theme.of(context).textTheme.bodyLarge?.color,
            fontSize: 16,
          ),
          decoration: InputDecoration(
            suffixIcon:
                suffix ??
                (onToggle != null
                    ? IconButton(
                        icon: Icon(
                          obscure ? Icons.visibility : Icons.visibility_off,
                        ),
                        onPressed: onToggle,
                      )
                    : null),
            errorText: errorText,
          ),
        ),
      ],
    );
  }
}
