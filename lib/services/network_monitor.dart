import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';

/// Tells the downloads queue whether the phone is on Wi-Fi. Abstracted so
/// tests can switch networks on demand.
abstract class NetworkMonitor {
  /// True on Wi-Fi or Ethernet (unmetered), false on mobile data or offline.
  Future<bool> isOnWifi();

  /// Emits the new [isOnWifi] value whenever the connection changes.
  Stream<bool> get onWifiChanged;
}

bool isUnmetered(List<ConnectivityResult> results) =>
    results.contains(ConnectivityResult.wifi) || results.contains(ConnectivityResult.ethernet);

class ConnectivityNetworkMonitor implements NetworkMonitor {
  ConnectivityNetworkMonitor([Connectivity? connectivity]) : _connectivity = connectivity ?? Connectivity();
  final Connectivity _connectivity;

  @override
  Future<bool> isOnWifi() async => isUnmetered(await _connectivity.checkConnectivity());

  @override
  Stream<bool> get onWifiChanged => _connectivity.onConnectivityChanged.map(isUnmetered).distinct();
}
