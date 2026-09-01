import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:metube_super/app.dart';
import 'package:metube_super/di.dart';
import 'package:metube_super/features/settings/settings_state.dart';
import 'package:mt_core/mt_core.dart';
import 'package:mt_ui/mt_ui.dart';

void main() {
  testWidgets('الإقلاع بلا سيرفر ⇒ المكتبة بحالة «لا سيرفر بعد» (ر-1)',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          keyValueStoreProvider.overrideWithValue(MemoryKeyValueStore()),
          secretStoreProvider.overrideWithValue(MemorySecretStore()),
          initialSettingsProvider
              .overrideWithValue(const SuperSettings()),
        ],
        child: const SuperApp(),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.takeException(), isNull);
    expect(find.byType(MTEmptyState), findsOneWidget);
    expect(find.byType(MTFab), findsOneWidget);
  });
}
