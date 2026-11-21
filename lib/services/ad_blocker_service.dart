import 'package:logger/logger.dart';

/// URL classifier used by request filters. This service does not itself
/// intercept WebView or player traffic.
class AdBlockerService {
  static final AdBlockerService _instance = AdBlockerService._internal();
  final logger = Logger();

  static const Set<String> _blockedHosts = {
    'doubleclick.net',
    'google-analytics.com',
    'googleadservices.com',
    'googlesyndication.com',
    'adservice.google.com',
    'ads.youtube.com',
    'dart.doubleclick.net',
    'googleads.g.doubleclick.net',
    'pagead1.googlesyndication.com',
    'pagead2.googlesyndication.com',
    'tpc.googlesyndication.com',
    'connect.facebook.net',
    'staticxx.facebook.com',
    'criteo.net',
    'amazon-adsystem.com',
    'ads.amazon.com',
    'adn.ebay.com',
    'ad.yandex.ru',
    'an.yandex.ru',
    'mc.yandex.ru',
    'analytics.google.com',
    'api.mixpanel.com',
    'api-js.mixpanel.com',
    'cdn.mxpnl.com',
    'api.segment.io',
    'cdn.segment.com',
  };

  /// Matched against "host/path" only (never the query string), and only
  /// as whole path prefixes, so ordinary pages that merely mention words
  /// like "analytics" or "tracker" are not blocked.
  static const List<String> _blockedPathPrefixes = [
    'facebook.com/tr',
    'www.facebook.com/tr',
    'www.googletagmanager.com/gtag/js',
    'www.youtube.com/pagead/',
    'www.youtube.com/api/stats/ads',
    'www.youtube.com/ptracking',
    'm.youtube.com/pagead/',
    'm.youtube.com/api/stats/ads',
  ];

  /// Exact path segments that are tracking pixels.
  static const Set<String> _pixelSegments = {'pixel', 'pixel.gif', 'tracking-pixel', 'tr.gif'};

  factory AdBlockerService() => _instance;

  AdBlockerService._internal();

  Uri? _parseUri(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return null;
    final uri = Uri.tryParse(trimmed.contains('://') ? trimmed : 'https://$trimmed');
    if (uri == null || (uri.scheme != 'http' && uri.scheme != 'https') || uri.host.isEmpty || uri.userInfo.isNotEmpty) {
      return null;
    }
    return uri;
  }

  bool isAdDomain(String value) {
    final uri = _parseUri(value);
    if (uri == null) return false;

    final host = uri.host.toLowerCase();
    final hostBlocked = _blockedHosts.any((domain) => host == domain || host.endsWith('.$domain'));
    if (hostBlocked) {
      logger.d('Blocked advertising host: $host');
      return true;
    }

    final hostAndPath = '$host${uri.path.toLowerCase()}';
    return _blockedPathPrefixes.any(
      (prefix) => hostAndPath == prefix || hostAndPath.startsWith(prefix.endsWith('/') ? prefix : '$prefix/'),
    );
  }

  List<String> filterAdUrls(List<String> urls) => urls.where((url) => !isAdDomain(url)).toList();

  bool shouldBlockRequest(String url, String? method) {
    final uri = _parseUri(url);
    if (uri == null) return false;
    if (isAdDomain(url)) return true;

    return uri.pathSegments.any((segment) => _pixelSegments.contains(segment.toLowerCase()));
  }

  int getBlockedCount(List<String> urls) => urls.where(isAdDomain).length;

  Map<String, dynamic> getStatistics(List<String> requestedUrls) {
    final blockedUrls = requestedUrls.where(isAdDomain).toList();
    final total = requestedUrls.length;
    final blocked = blockedUrls.length;
    final rate = total == 0 ? '0' : (blocked / total * 100).toStringAsFixed(2);
    return {
      'total_requests': total,
      'blocked_requests': blocked,
      'block_rate': '$rate%',
      'blocked_domains': blockedUrls,
    };
  }
}
