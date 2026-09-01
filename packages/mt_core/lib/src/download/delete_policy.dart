/// سياسة ما بعد السحب (`05-DATA-SCHEMA.md` §2.5):
/// - [autoDelete] — Lite: حذف تلقائي من السيرفر بعد السحب (تنظيف ذاتي).
/// - [keepOnServer] — Super: يبقى على السيرفر، والحذف يدوي فقط.
enum DeletePolicy { autoDelete, keepOnServer }
