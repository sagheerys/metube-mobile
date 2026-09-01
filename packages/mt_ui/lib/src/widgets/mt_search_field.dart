import 'package:flutter/material.dart';

import '../theme/mt_theme.dart';

/// حقل البحث الدائم (النموذج أ: البحث ظاهر دائماً لا خلف أيقونة).
class MTSearchField extends StatelessWidget {
  const MTSearchField({
    super.key,
    required this.hint,
    this.controller,
    this.onChanged,
    this.autofocus = false,
  });

  final String hint;
  final TextEditingController? controller;
  final ValueChanged<String>? onChanged;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    final x = MTThemeX.of(context);
    return TextField(
      controller: controller,
      onChanged: onChanged,
      autofocus: autofocus,
      textInputAction: TextInputAction.search,
      style: Theme.of(context).textTheme.bodyMedium,
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: Icon(Icons.search_rounded, size: 20, color: x.palette.ink3),
        isDense: true,
      ),
    );
  }
}
