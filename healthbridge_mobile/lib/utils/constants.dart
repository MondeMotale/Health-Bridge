class AppConstants {
  // Colors
  static const int primaryBlue = 0xFF1E3A8A;
  static const int darkNavy = 0xFF0F172A;
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

/// Token Server Configuration
///
/// The Next.js backend that generates Agora tokens is hosted on Vercel.
/// It is publicly reachable, so phones can be on ANY network (Wi-Fi,
/// mobile data, different countries — doesn't matter).
///
/// To redeploy after making changes to the server:
///   git push
/// Vercel auto-deploys within ~1 minute.
class ApiConfig {
  static const String baseUrl = 'https://health-bridge-orpin.vercel.app';
  static const String agoraTokenEndpoint = '$baseUrl/api/agora-token';
}