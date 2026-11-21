import 'dart:async';
import 'dart:math' as math;

import '../providers/downloads_provider.dart';
import 'youtube_extraction_service.dart';

class BatchFailure<T> {
  const BatchFailure(this.item, this.reason);
  final T item;
  final String reason;
}

class BatchResult<T> {
  BatchResult({required this.total});
  final int total;
  int succeeded = 0;
  final List<BatchFailure<T>> failures = [];
}

/// A short user-facing reason for a failed batch item.
String describeBatchError(Object error) => switch (error) {
  YoutubeServiceException(:final message) => message,
  DownloadException(:final message) => message,
  _ => 'Could not prepare the download.',
};

/// Runs [task] for every item with at most [concurrency] running at once.
/// [onProgress] is called with the number of finished items (success or
/// failure) after each one. Failures never stop the rest of the batch.
Future<BatchResult<T>> runBatch<T>(
  List<T> items,
  Future<void> Function(T item) task, {
  int concurrency = 3,
  void Function(int done, int total)? onProgress,
  String Function(Object error) describe = describeBatchError,
}) async {
  final result = BatchResult<T>(total: items.length);
  var next = 0;
  var done = 0;
  onProgress?.call(0, items.length);

  Future<void> worker() async {
    while (next < items.length) {
      final item = items[next++];
      try {
        await task(item);
        result.succeeded++;
      } catch (error) {
        result.failures.add(BatchFailure(item, describe(error)));
      }
      done++;
      onProgress?.call(done, items.length);
    }
  }

  await Future.wait([for (var i = 0; i < math.min(math.max(concurrency, 1), items.length); i++) worker()]);
  return result;
}

/// "Preparing 3 of 10" while a batch is being set up.
String batchProgressLabel(int done, int total) => 'Preparing ${math.min(done + 1, total)} of $total';

/// One-line summary shown when a batch finishes. [titleOf] names failed items.
String batchSummary<T>(BatchResult<T> result, String Function(T item) titleOf, {int skipped = 0}) {
  final parts = <String>[
    if (result.succeeded > 0) 'Started ${result.succeeded} download(s).',
    if (result.succeeded == 0 && result.failures.isNotEmpty) 'No downloads were started.',
  ];
  if (result.failures.isNotEmpty) {
    final shown = result.failures.take(2).map((f) => '"${titleOf(f.item)}" (${f.reason})');
    final more = result.failures.length > 2 ? ' and ${result.failures.length - 2} more' : '';
    parts.add('${result.failures.length} failed: ${shown.join(', ')}$more.');
  }
  if (skipped > 0) parts.add('$skipped sample video(s) skipped.');
  return parts.join(' ');
}
