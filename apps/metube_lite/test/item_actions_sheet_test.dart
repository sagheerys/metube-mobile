import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:metube_lite/di.dart';
import 'package:metube_lite/features/downloads_library/local_item.dart';
import 'package:metube_lite/features/downloads_library/widgets/item_actions_sheet.dart';
import 'package:mt_core/mt_core.dart';
import 'package:mt_ui/mt_ui.dart';

import 'device_matrix.dart';

/// The counterpart of the menu guard in Super: a clip's menu stopped at
/// nine sixteenths of a short screen and cut its last rows off, delete
/// among them.
void main() {
  final item = LocalItem(
    key: '/storage/emulated/0/Download/MeTube_Lite/zoo.mp4',
    path: '/storage/emulated/0/Download/MeTube_Lite/zoo.mp4',
    title: 'Me at the zoo',
    sizeBytes: 1024,
    modified: DateTime.utc(2026, 9, 30),
    canonicalUrl: 'https://www.youtube.com/watch?v=jNQXAC9IVRw',
  );

  for (final locale in const [Locale('en'), Locale('ar')]) {
    testWidgets(
      "a clip's menu holds on every device (${locale.languageCode})",
      (tester) async {
        await expectNoOverflow(
          tester,
          () => ProviderScope(
            overrides: [
              keyValueStoreProvider.overrideWithValue(MemoryKeyValueStore()),
              prefsMutexProvider.overrideWithValue(PrefsMutex()),
            ],
            child: MaterialApp(
              theme: mtTheme(MTVariant.lite, Brightness.light),
              locale: locale,
              localizationsDelegates: MTLocalizations.localizationsDelegates,
              supportedLocales: MTLocalizations.supportedLocales,
              home: Scaffold(
                body: _OpensMenu(
                  key: UniqueKey(),
                  open: (context, ref) =>
                      showItemActionsSheet(context, ref, item),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Opens the menu once built, so every size of the matrix lays it out.
class _OpensMenu extends ConsumerStatefulWidget {
  const _OpensMenu({super.key, required this.open});

  final void Function(BuildContext context, WidgetRef ref) open;

  @override
  ConsumerState<_OpensMenu> createState() => _OpensMenuState();
}

class _OpensMenuState extends ConsumerState<_OpensMenu> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => widget.open(context, ref),
    );
  }

  @override
  Widget build(BuildContext context) => const SizedBox.expand();
}
