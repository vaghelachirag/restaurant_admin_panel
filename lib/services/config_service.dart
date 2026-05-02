import 'dart:convert';
import 'package:flutter/services.dart';

class AppConfig {
  final Map<String, String> apiKeys;
  final Map<String, String> baseUrls;

  AppConfig({
    required this.apiKeys,
    required this.baseUrls,
  });

  factory AppConfig.fromJson(Map<String, dynamic> json) {
    return AppConfig(
      apiKeys: Map<String, String>.from(json['api_keys'] ?? {}),
      baseUrls: Map<String, String>.from(json['base_urls'] ?? {}),
    );
  }

  String? getApiKey(String service) => apiKeys[service];
  String? getBaseUrl(String service) => baseUrls[service];
}

class ConfigService {
  static AppConfig? _config;
  static bool _isLoaded = false;

  static Future<AppConfig> getConfig() async {
    if (!_isLoaded) {
      await _loadConfig();
    }
    return _config!;
  }

  static Future<void> _loadConfig() async {
    try {
      final String configString = await rootBundle.loadString('config/app_config.json');
      final Map<String, dynamic> configJson = json.decode(configString);
      _config = AppConfig.fromJson(configJson);
      _isLoaded = true;
    } catch (e) {
      throw Exception('Failed to load configuration: $e');
    }
  }

  static String? getApiKey(String service) {
    if (!_isLoaded) {
      throw Exception('Configuration not loaded. Call getConfig() first.');
    }
    return _config!.getApiKey(service);
  }

  static String? getBaseUrl(String service) {
    if (!_isLoaded) {
      throw Exception('Configuration not loaded. Call getConfig() first.');
    }
    return _config!.getBaseUrl(service);
  }

  static Future<void> reloadConfig() async {
    _isLoaded = false;
    await _loadConfig();
  }
}
