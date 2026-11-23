import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import 'package:tube_arena/data/paged_feed.dart';
import 'package:tube_arena/data/repositories/feed_repository.dart';
import 'package:tube_arena/ui/screens/search_screen.dart';

void main() {
  testWidgets('search uses a full screen instead of a popup dialog', (tester) async {
    final repository = FeedRepository.withSearch(
      (query, {category = 'All'}) async => VideoPage.last(const []),
    );

    await tester.pumpWidget(
      Provider<FeedRepository>.value(
        value: repository,
        child: const MaterialApp(home: SearchScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(TextField), findsOneWidget);
    expect(find.text('Search Tube Arena'), findsOneWidget);
    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets('submitting a query displays matching search results', (tester) async {
    final repository = FeedRepository.withSearch((query, {category = 'All'}) async {
      expect(query, 'flutter tutorial');
      return VideoPage.last([sampleVideos[1]]);
    });

    await tester.pumpWidget(
      Provider<FeedRepository>.value(
        value: repository,
        child: const MaterialApp(home: SearchScreen()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'flutter tutorial');
    await tester.tap(find.byTooltip('Search'));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text('Results for “flutter tutorial”'), findsOneWidget);
    expect(find.text(sampleVideos[1].title), findsOneWidget);
    expect(find.byType(AlertDialog), findsNothing);
  });
}
