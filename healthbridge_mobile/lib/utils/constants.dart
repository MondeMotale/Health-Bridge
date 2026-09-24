class AppConstants {
  // Colors
  static const int primaryBlue = 0xFF1E3A8A; // <--- CHANGED TO DARK NAVY
  static const int darkNavy = 0xFF0F172A;    // Even darker for gradients
  static const int successGreen = 0xFF10B981;
  static const int dangerRed = 0xFFEF4444;
  static const int warningOrange = 0xFFF59E0B;
  static const int backgroundGray = 0xFFF9FAFB;
  static const int cardWhite = 0xFFFFFFFF;
  static const int textPrimary = 0xFF1A1A2E;
  static const int textSecondary = 0xFF6B7280;

  // Storage Keys
  static const String prefUserId = 'user_id';
  static const String prefUserRole = 'user_role';
  static const String prefUserName = 'user_name';
}

class UserRole {
  static const String chw = 'CHW';
  static const String patient = 'PATIENT';
}

/// ⚠️ IMPORTANT — Token Server Configuration
///
/// Your laptop runs the Next.js backend that generates Agora tokens.
/// Phones must be on the SAME Wi-Fi as the laptop to reach this IP.
///
/// When your laptop's LAN IP changes (which happens whenever you switch
/// Wi-Fi networks), you only need to update `_laptopIp` below.
/// Everything else in the app uses `ApiConfig.baseUrl` automatically.
///
/// To find your current laptop IP on Windows:
///   1. Open PowerShell
///   2. Run:  ipconfig
///   3. Look for "IPv4 Address" under your Wi-Fi adapter
class ApiConfig {
  // 👇👇👇 UPDATE THIS ONE LINE WHEN YOUR LAPTOP IP CHANGES 👇👇👇
  static const String _laptopIp = '10.0.1.77';
  static const String _port = '3000';

  // Full base URL
  static const String baseUrl = 'http://$_laptopIp:$_port';

  // Agora token endpoint (used by chat screens before starting a call)
  static const String agoraTokenEndpoint = '$baseUrl/api/agora-token';
}