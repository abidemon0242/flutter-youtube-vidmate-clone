import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tube_arena/core/theme/app_theme.dart';
import 'package:tube_arena/data/paged_feed.dart';
import 'package:tube_arena/data/repositories/feed_repository.dart';
import 'package:tube_arena/models/video_details.dart';
import 'package:tube_arena/models/video_model.dart';
import 'package:tube_arena/providers/theme_controller.dart';
import 'package:tube_arena/providers/recommendation_settings.dart';
import 'package:tube_arena/services/youtube_extraction_service.dart';
import 'package:tube_arena/ui/screens/home_screen.dart';
import 'package:tube_arena/ui/widgets/video_description.dart';

VideoModel v(String id) =>
    VideoModel(id: id, youtubeId: id.padRight(11, '_'), title: 'Video $id', channelName: 'Channel');

/// Serves [pages] in order; each page knows how to load the next one.
class FakePages {
  FakePages(this.pages);
  final List<List<VideoModel>> pages;
  int requests = 0;
  Object? failNextWith;
  Completer<void>? gate;

  VideoPage page(int index) => VideoPage(
    pages[index],
    loadNext: index + 1 >= pages.length
        ? null
        : () async {
            requests++;
            final g = gate;
            if (g != null) await g.future;
            final error = failNextWith;
            if (error != null) {
              failNextWith = null;
              throw error;
            }
            return page(index + 1);
          },
  );
}

void main() {
  group('PagedFeed', () {
    test('appends pages and stops at the end', () async {
      final pages = FakePages([
        [v('a'), v('b')],
        [v('c')],
        [v('d')],
      ]);
      final feed = PagedFeed(pages.page(0));
      expect(feed.items.map((e) => e.id), ['a', 'b']);
      expect(feed.hasMore, isTrue);
      await feed.loadMore();
      await feed.loadMore();
      expect(feed.items.map((e) => e.id), ['a', 'b', 'c', 'd']);
      expect(feed.hasMore, isFalse);
      await feed.loadMore(); // no-op at the end
      expect(pages.requests, 2);
    });

    test('drops duplicates within and across pages', () async {
      final pages = FakePages([
        [v('a'), v('b'), v('a')],
        [v('b'), v('c'), v('c')],
      ]);
      final feed = PagedFeed(pages.page(0));
      await feed.loadMore();
      expect(feed.items.map((e) => e.id), ['a', 'b', 'c']);
    });

    test('skips pages with only duplicates and ends after too many', () async {
      final pages = FakePages([
        [v('a')],
        [v('a')],
        [v('b')],
      ]);
      final feed = PagedFeed(pages.page(0));
      await feed.loadMore();
      expect(feed.items.map((e) => e.id), ['a', 'b']);

      final repeating = FakePages(List.generate(10, (_) => [v('a')]));
      final stuck = PagedFeed(repeating.page(0));
      await stuck.loadMore();
      expect(stuck.hasMore, isFalse);
      expect(repeating.requests, PagedFeed.maxEmptyPages);
    });

    test('ignores concurrent loadMore calls', () async {
      final pages = FakePages([
        [v('a')],
        [v('b')],
        [v('c')],
      ])..gate = Completer<void>();
      final feed = PagedFeed(pages.page(0));
      final first = feed.loadMore();
      final second = feed.loadMore();
      expect(feed.isLoading, isTrue);
      pages.gate!.complete();
      await Future.wait([first, second]);
      expect(pages.requests, 1);
      expect(feed.items.map((e) => e.id), ['a', 'b']);
    });

    test('keeps items on error and can retry', () async {
      final pages = FakePages([
        [v('a')],
        [v('b')],
      ])..failNextWith = const YoutubeServiceException('No internet connection.');
      final feed = PagedFeed(pages.page(0));
      await feed.loadMore();
      expect(feed.error, 'No internet connection.');
      expect(feed.canAutoLoad, isFalse);
      expect(feed.items.length, 1);
      await feed.loadMore();
      expect(feed.error, isNull);
      expect(feed.items.map((e) => e.id), ['a', 'b']);
    });

    test('fixed feeds have no more pages', () {
      final feed = PagedFeed.fixed([v('a')]);
      expect(feed.hasMore, isFalse);
      expect(feed.canAutoLoad, isFalse);
    });
  });

  group('FeedRepository', () {
    test('caches the paged feed per category and query', () async {
      var calls = 0;
      final repo = FeedRepository.withSearch((query, {String category = 'All'}) async {
        calls++;
        return FakePages([
          [v('a')],
          [v('b')],
        ]).page(0);
      });
      final first = await repo.load(category: 'Tech');
      await first.feed.loadMore();
      final again = await repo.load(category: 'Tech');
      expect(identical(first.feed, again.feed), isTrue);
      expect(again.videos.length, 2);
      final refreshed = await repo.load(category: 'Tech', refresh: true);
      expect(refreshed.videos.length, 1);
      expect(calls, 2);
    });

    test('falls back to samples without paging when YouTube fails', () async {
      final repo = FeedRepository.withSearch(
        (query, {String category = 'All'}) async => throw const YoutubeServiceException('offline'),
      );
      final result = await repo.load();
      expect(result.isSample, isTrue);
      expect(result.feed.hasMore, isFalse);
      expect(result.videos, isNotEmpty);
    });
  });

  testWidgets('home feed loads the next page when scrolled to the end', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final recommendations = await RecommendationSettings.load();
    final pages = FakePages([List.generate(6, (i) => v('p0-$i')), List.generate(6, (i) => v('p1-$i'))]);
    final repo = FeedRepository.withSearch((query, {String category = 'All'}) async => pages.page(0));
    final router = GoRouter(
      routes: [GoRoute(path: '/', builder: (_, _) => const HomeScreen())],
    );
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => ThemeController()),
          ChangeNotifierProvider<RecommendationSettings>.value(value: recommendations),
          Provider<FeedRepository>.value(value: repo),
          Provider<YoutubeExtractionService>(create: (_) => YoutubeExtractionService()),
        ],
        child: MaterialApp.router(theme: AppTheme.lightTheme, routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Video p0-0'), findsOneWidget);
    expect(pages.requests, 0);

    await tester.dragUntilVisible(find.text('No more results'), find.byType(ListView).last, const Offset(0, -500));
    await tester.pumpAndSettle();
    expect(pages.requests, 1);
    expect(find.text('No more results'), findsOneWidget);
    expect(find.text('Video p1-5'), findsOneWidget);
  });

  testWidgets('description expands and collapses', (tester) async {
    final long = List.generate(20, (i) => 'Line $i of the description').join('\n');
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        home: Scaffold(
          body: VideoDescription(
            details: VideoDetails(description: long, viewCount: 1500, uploadDate: DateTime(2024, 12, 1)),
          ),
        ),
      ),
    );
    expect(find.text('1,500 views · Dec 1, 2024'), findsOneWidget);
    expect(find.text('Show more'), findsOneWidget);
    await tester.tap(find.text('Show more'));
    await tester.pumpAndSettle();
    expect(find.text('Show less'), findsOneWidget);
  });
}
