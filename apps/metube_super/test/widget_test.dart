import 'package:flutter_test/flutter_test.dart';
import 'package:metube_super/main.dart';
import 'package:mt_ui/mt_ui.dart';

void main() {
  testWidgets('مضيف المعرض المؤقت يرسم بهوية Super', (tester) async {
    await tester
        .pumpWidget(const GalleryHostApp(initialVariant: MTVariant.superApp));
    await tester.pump(const Duration(milliseconds: 50));
    expect(tester.takeException(), isNull);
    expect(find.byType(MTGalleryScreen), findsOneWidget);
  });
}
