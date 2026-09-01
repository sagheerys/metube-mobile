import 'package:flutter/material.dart';

import '../l10n/l10n.dart';

/// حوار إدخال نص واحد (اسم قائمة، اسم وسم، رابط نقطة نهاية…).
///
/// **لماذا ودجت مُحالة (Stateful) لا دالة** (فحص شامل 2026-09-02): كل
/// موضع كان ينشئ `TextEditingController` داخل دالة بناء الحوار ولا
/// يصرّفه أبداً — خمسة تسريبات في التطبيقين. وتصريفه بعد
/// `await showDialog` **ليس حلاً**: المستقبل يكتمل عند الـpop بينما
/// حركة الإغلاق ما زالت تُعيد بناء الحقل، وهو بالضبط ما فجّر «الشاشة
/// الحمراء» في المرحلة 8. المالك الوحيد الصحيح للمتحكم هو الودجت التي
/// تحمله، تصرّفه في `dispose` بعد أن تخرج من الشجرة فعلاً.
Future<String?> promptMTText(
  BuildContext context, {
  required String title,
  required String confirmLabel,
  String? initialValue,
  String? labelText,
  String? hintText,
  TextDirection? fieldDirection,
}) =>
    showDialog<String>(
      context: context,
      builder: (_) => _MTTextPrompt(
        title: title,
        confirmLabel: confirmLabel,
        initialValue: initialValue,
        labelText: labelText,
        hintText: hintText,
        fieldDirection: fieldDirection,
      ),
    );

class _MTTextPrompt extends StatefulWidget {
  const _MTTextPrompt({
    required this.title,
    required this.confirmLabel,
    this.initialValue,
    this.labelText,
    this.hintText,
    this.fieldDirection,
  });

  final String title;
  final String confirmLabel;
  final String? initialValue;
  final String? labelText;
  final String? hintText;

  /// الروابط تُكتب LTR ولو كانت الواجهة عربية.
  final TextDirection? fieldDirection;

  @override
  State<_MTTextPrompt> createState() => _MTTextPromptState();
}

class _MTTextPromptState extends State<_MTTextPrompt> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.initialValue);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() => Navigator.of(context).pop(_controller.text.trim());

  @override
  Widget build(BuildContext context) {
    final l10n = context.mtl;
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _controller,
        autofocus: true,
        textDirection: widget.fieldDirection,
        textInputAction: TextInputAction.done,
        decoration: InputDecoration(
          labelText: widget.labelText,
          hintText: widget.hintText,
        ),
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.cancel),
        ),
        FilledButton(onPressed: _submit, child: Text(widget.confirmLabel)),
      ],
    );
  }
}
