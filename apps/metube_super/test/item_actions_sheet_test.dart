import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:metube_super/di.dart';
import 'package:metube_super/features/library/library_models.dart';
import 'package:metube_super/features/library/widgets/item_actions_sheet.dart';
import 'package:metube_super/features/settings/settings_state.dart';
import 'package:metube_super/features/transcripts/transcripts_state.dart';
import 'package:mt_core/mt_core.dart';
import 'package:mt_transcripts/mt_transcripts.dart';
import 'package:mt_ui/mt_ui.dart';

import 'device_matrix.dart';

/// A clip's menu stopped at nine sixteenths of a short screen and cut its
/// last rows off, delete among them; the transcript row made it longer.
/// Laid out here with every row it can have.
void main() {
  const watch = 'https://www.youtube.com/watch?v=jNQXAC9IVRw';
  const item = LibraryItem(
    canonicalUrl: watch,
    title: 'Me at the zoo',
    uploader: 'jawed',
    onServer: true,
  );

  Widget menu({Locale locale = const Locale('en')}) => ProviderScope(
    overrides: [
      keyValueStoreProvider.overrideWithValue(MemoryKeyValueStore()),
      secretStoreProvider.overrideWithValue(MemorySecretStore()),
      prefsMutexProvider.overrideWithValue(PrefsMutex()),
      initialSettingsProvider.overrideWithValue(const SuperSettings()),
      transcriptIndexProvider.overrideWith(
        (ref) async => TranscriptIndex()
          ..add(
            Transcript(
              canonicalUrl: watch,
              language: 'en',
              source: 'captions',
              fetchedAt: DateTime.utc(2026, 9, 30),
              segments: const [
                TranscriptSegment(
                  start: Duration.zero,
                  end: Duration(seconds: 2),
                  text: 'the elephants',
                ),
              ],
            ),
          ),
      ),
    ],
    child: MaterialApp(
      theme: mtTheme(MTVariant.superApp, Brightness.light),
      locale: locale,
      localizationsDelegates: MTLocalizations.localizationsDelegates,
      supportedLocales: MTLocalizations.supportedLocales,
      home: Scaffold(
        body: _OpensMenu(
          key: UniqueKey(),
          open: (context, ref) => showItemActionsSheet(context, ref, item),
        ),
      ),
    ),
  );

  for (final locale in const [Locale('en'), Locale('ar')]) {
    testWidgets(
      "a clip's menu holds on every device (${locale.languageCode})",
      (tester) async {
        await expectNoOverflow(tester, () => menu(locale: locale));
      },
    );
  }

  // Field report 2026-09-30: with the transcript row the menu outgrew the
  // default sheet height, and Delete sat below a scroll on a real
  // phone.
  testWidgets("on a 384x823 phone every row shows without scrolling", (
    tester,
  ) async {
    tester.view.physicalSize = const Size(384, 823);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(menu());
    await tester.pumpAndSettle();
    expect(find.text('Transcript').hitTestable(), findsOneWidget);
    expect(find.text('Delete From Server').hitTestable(), findsOneWidget);
  });
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
