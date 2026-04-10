/// Central config for the CSV upload feature.
/// Replace [cloudFunctionImageUrl] with your deployed Firebase Function URL.
///
/// How to get your URL after deploying:
///   firebase deploy --only functions:getMenuImage
///   → https://us-central1-YOUR_PROJECT.cloudfunctions.net/getMenuImage
class AppConfig {
  AppConfig._();

  /// Your deployed Firebase Cloud Function URL for Unsplash image lookup.
  /// Set to empty string '' to skip API calls and rely only on
  /// keyword matching + category fallback.
  static const String cloudFunctionImageUrl =
      'https://us-central1-YOUR_PROJECT_ID.cloudfunctions.net/getMenuImage';


  static const String oneSignalAppId = "1dbbdcbd-590f-475c-88d0-7c6d953d63ca";

  // User Roles
  static const String superAdmin = "super_admin";
  static const String admin = "admin";
  static const String manager = "manager";
  static const String waiter = "waiter";
  static const String customer = "customer";
}