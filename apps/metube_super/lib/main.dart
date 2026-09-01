import 'package:flutter/material.dart';
import 'package:mt_ui/mt_ui.dart';

// مؤقت للمرحلة 3: مضيف معرض «وهج» لفحص بوابة الهوية على جهاز حقيقي.
// TODO(المرحلة-4): يُستبدل بـ bootstrap التطبيق الفعلي (app/router/di).
void main() {
  initMTL10n();
  runApp(const GalleryHostApp(initialVariant: MTVariant.superApp));
}

class GalleryHostApp extends StatefulWidget {
  const GalleryHostApp({super.key, required this.initialVariant});

  final MTVariant initialVariant;

  @override
  State<GalleryHostApp> createState() => _GalleryHostAppState();
}

class _GalleryHostAppState extends State<GalleryHostApp> {
  late MTVariant _variant = widget.initialVariant;
  ThemeMode _mode = ThemeMode.light;
  TextDirection _direction = TextDirection.rtl;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'وهج Gallery',
      debugShowCheckedModeBanner: false,
      theme: mtTheme(_variant, Brightness.light),
      darkTheme: mtTheme(_variant, Brightness.dark),
      themeMode: _mode,
      locale: Locale(_direction == TextDirection.rtl ? 'ar' : 'en'),
      localizationsDelegates: MTLocalizations.localizationsDelegates,
      supportedLocales: MTLocalizations.supportedLocales,
      home: Directionality(
        textDirection: _direction,
        child: MTGalleryScreen(
          onToggleTheme: () => setState(() => _mode =
              _mode == ThemeMode.light ? ThemeMode.dark : ThemeMode.light),
          onToggleDirection: () => setState(() => _direction =
              _direction == TextDirection.rtl
                  ? TextDirection.ltr
                  : TextDirection.rtl),
          onToggleVariant: () => setState(() => _variant =
              _variant == MTVariant.lite
                  ? MTVariant.superApp
                  : MTVariant.lite),
        ),
      ),
    );
  }
}
