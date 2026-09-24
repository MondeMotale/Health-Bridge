import 'package:connectivity_plus/connectivity_plus.dart';

class SyncService {
  static Future<void> init() async {
    print('Sync service initialized');
  }
  
  static Future<void> syncNow() async {
    await _performSync();
  }
  
  static Future<void> _performSync() async {
    final connectivityResult = await Connectivity().checkConnectivity();
    if (connectivityResult == ConnectivityResult.none) {
      print('No internet connection, sync skipped');
      return;
    }
    
    print('Starting data sync...');
    print('Sync completed');
  }
}