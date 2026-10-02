import 'package:logger/logger.dart';

class AdBlockerService {
  static final AdBlockerService _instance = AdBlockerService._internal();
  final logger = Logger();

  // Comprehensive list of ad-related domains and patterns
  static const List<String> _adDomains = [
    // Google Ads
    'doubleclick.net',
    'google-analytics.com',
    'googleadservices.com',
    'googlesyndication.com',
    'adservice.google.com',
    'pagead',
    'adsense',

    // Video Ad Networks
    'ads.youtube.com',
    'youtube-nocookie.com',
    'ad.doubleclick.net',
    'dart.doubleclick.net',
    'googleads.g.doubleclick.net',
    'pagead1.googlesyndication.com',
    'pagead2.googlesyndication.com',
    'tpc.googlesyndication.com',

    // Facebook/Meta
    'facebook.com/tr',
    'connect.facebook.net',
    'staticxx.facebook.com',

    // Other Ad Networks
    'criteo.net',
    'tripadvisor.com/affiliate',
    'amazon-adsystem.com',
    'ads.amazon.com',
    'adn.ebay.com',
    'ad.yandex.ru',
    'yandex.net',

    // Tracking
    'facebook-pixel',
    'analytics.google.com',
    'gtag.js',
    'mixpanel.com',
    'segment.com',
  ];

  factory AdBlockerService() {
    return _instance;
  }

  AdBlockerService._internal();

  /// Check if a URL is an ad/tracker domain
  bool isAdDomain(String url) {
    try {
      final lowerUrl = url.toLowerCase();
      for (final domain in _adDomains) {
        if (lowerUrl.contains(domain)) {
          logger.d('Ad domain blocked: $domain in $url');
          return true;
        }
      }
      return false;
    } catch (e) {
      logger.e('Error checking ad domain: $e');
      return false;
    }
  }

  /// Filter URLs to remove ad/tracker domains
  List<String> filterAdUrls(List<String> urls) {
    return urls.where((url) => !isAdDomain(url)).toList();
  }

  /// Check if a request should be blocked
  bool shouldBlockRequest(String url, String? method) {
    try {
      // Block ad requests
      if (isAdDomain(url)) {
        logger.i('Blocking ad request: $url');
        return true;
      }

      // Block tracking pixels
      if (url.contains('/pixel') || url.contains('tracker')) {
        logger.i('Blocking tracking request: $url');
        return true;
      }

      // Block analytics
      if (url.contains('/analytics') || url.contains('/metrics')) {
        logger.i('Blocking analytics request: $url');
        return true;
      }

      return false;
    } catch (e) {
      logger.e('Error checking request block: $e');
      return false;
    }
  }

  /// Get number of blocked ads/trackers in a session
  int getBlockedCount(List<String> urls) {
    return urls.where((url) => isAdDomain(url)).length;
  }

  /// Get ad blocking statistics
  Map<String, dynamic> getStatistics(List<String> requestedUrls) {
    final blockedUrls = requestedUrls.where((url) => isAdDomain(url)).toList();
    final blockedCount = blockedUrls.length;
    final totalCount = requestedUrls.length;
    final blockRate =
        totalCount > 0 ? ((blockedCount / totalCount) * 100).toStringAsFixed(2) : '0';

    return {
      'total_requests': totalCount,
      'blocked_requests': blockedCount,
      'block_rate': '$blockRate%',
      'blocked_domains': blockedUrls,
    };
  }
}
