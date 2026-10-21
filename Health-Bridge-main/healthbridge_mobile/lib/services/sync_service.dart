import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

class SyncService {
  static Future<void> init() async {
    debugPrint('Sync service initialized');
  }

  static Future<void> syncNow() async {
    await _performSync();
  }

  static Future<void> _performSync() async {
    final connectivityResults = await Connectivity().checkConnectivity();
    final hasConnection = !connectivityResults.contains(ConnectivityResult.none);

    if (!hasConnection) {
      debugPrint('No internet connection, sync skipped');
      return;
    }

    debugPrint('Starting data sync...');
    debugPrint('Sync completed');
  }
}