import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mt_ui/mt_ui.dart';

/// **Field report 2026-09-30:** scrolled far down the library, the search
/// field was disposed with its text, while the query stayed on and kept
/// filtering; back at the top the field was empty above filtered results.
void main() {
  Widget page({required String query, required int rows}) => MaterialApp(
    theme: mtTheme(MTVariant.superApp, Brightness.light),
    home: Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverList.list(
            children: [
              MTQuerySearchField(
                hint: 'Search',
                query: query,
                onChanged: (_) {},
              ),
              for (var i = 0; i < rows; i++)
                SizedBox(height: 100, child: Text('row $i')),
            ],
          ),
        ],
      ),
    ),
  );

  String fieldText(WidgetTester tester) =>
      tester.widget<TextField>(find.byType(TextField)).controller!.text;

  testWidgets('scrolled away and back, the field shows the query again', (
    tester,
  ) async {
    await tester.pumpWidget(page(query: 'trunks', rows: 60));
    expect(fieldText(tester), 'trunks');

    await tester.drag(find.byType(CustomScrollView), const Offset(0, -5000));
    await tester.pumpAndSettle();
    expect(
      find.byType(TextField, skipOffstage: false),
      findsNothing,
      reason: 'the lazy list disposed it, as on the phone',
    );

    await tester.drag(find.byType(CustomScrollView), const Offset(0, 5000));
    await tester.pumpAndSettle();
    expect(fieldText(tester), 'trunks');
  });

  testWidgets('a query cleared elsewhere clears the field', (tester) async {
    await tester.pumpWidget(page(query: 'trunks', rows: 1));
    await tester.pumpWidget(page(query: '', rows: 1));
    expect(fieldText(tester), '');
  });

  testWidgets('typing reports each change', (tester) async {
    final typed = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        theme: mtTheme(MTVariant.superApp, Brightness.light),
        home: Scaffold(
          body: MTQuerySearchField(
            hint: 'Search',
            query: '',
            onChanged: typed.add,
          ),
        ),
      ),
    );
    await tester.enterText(find.byType(TextField), 'zoo');
    expect(typed, ['zoo']);
  });
}
