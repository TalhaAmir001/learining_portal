import 'package:flutter/material.dart';

class InboxSearchBar extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String>? onChanged;
  final String? hintText;
  final double borderRadius;
  final EdgeInsetsGeometry? padding;
  final Color? borderColor;

  const InboxSearchBar({
    super.key,
    required this.controller,
    this.onChanged,
    this.hintText,
    this.borderRadius = 25.0,
    this.padding,
    this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    final defaultBorderColor = borderColor ?? Colors.grey.withOpacity(0.3);

    return Container(
      color: Colors.transparent,
      padding: padding ?? const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(borderRadius),
          border: Border.all(color: defaultBorderColor, width: 1.0),
        ),
        child: TextField(
          controller: controller,
          decoration: InputDecoration(
            hintText: hintText ?? 'Search',
            hintStyle: TextStyle(color: Colors.grey.withOpacity(0.7)),
            prefixIcon: Icon(Icons.search, color: Colors.grey.withOpacity(0.7)),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 12,
            ),
            filled: false,
          ),
          onChanged: onChanged,
        ),
      ),
    );
  }
}
