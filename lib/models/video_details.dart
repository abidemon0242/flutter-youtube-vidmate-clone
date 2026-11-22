/// Extra information shown under the player on the watch screen.
class VideoDetails {
  const VideoDetails({this.description = '', this.viewCount = 0, this.likeCount, this.uploadDate});

  final String description;
  final int viewCount;
  final int? likeCount;
  final DateTime? uploadDate;

  /// "1,234,567 views · Mar 4, 2025", skipping unknown parts.
  String get statsLine => [
    if (viewCount > 0) '${groupDigits(viewCount)} ${viewCount == 1 ? 'view' : 'views'}',
    if (likeCount != null && likeCount! > 0) '${groupDigits(likeCount!)} likes',
    if (uploadDate != null) formatDate(uploadDate!),
  ].join(' · ');

  static String groupDigits(int value) {
    final digits = value.abs().toString();
    final buffer = StringBuffer(value < 0 ? '-' : '');
    for (var i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(',');
      buffer.write(digits[i]);
    }
    return buffer.toString();
  }

  static const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

  static String formatDate(DateTime date) => '${_months[date.month - 1]} ${date.day}, ${date.year}';
}
