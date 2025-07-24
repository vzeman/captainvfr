import 'package:hive_flutter/hive_flutter.dart';
import 'package:logger/logger.dart';
import '../../config/api_config.dart';

/// Handles OpenAIP API configuration and key management
class OpenAIPApiConfiguration {
  final Logger _logger = Logger(level: Level.warning);
  
  String? _apiKey;
  bool _initialized = false;

  /// Check if API key is available (either user-provided or default)
  bool get hasApiKey => _apiKey != null && _apiKey!.isNotEmpty;

  /// Check if using default API key
  bool get isUsingDefaultKey => _apiKey == ApiConfig.defaultOpenAipApiKey;

  /// Get the current API key
  String? get apiKey => _apiKey;

  /// Check if configuration is initialized
  bool get isInitialized => _initialized;

  /// Initialize API configuration
  Future<void> initialize() async {
    if (_initialized) return;

    try {
      final settingsBox = await Hive.openBox('settings');
      final storedApiKey = settingsBox.get('openaip_api_key', defaultValue: '');

      if (storedApiKey.isNotEmpty) {
        // User has provided their own API key
        _apiKey = storedApiKey;
        _logger.d(
          '✅ OpenAIP API key loaded from storage: ${storedApiKey.substring(0, 4)}... (${storedApiKey.length} chars)',
        );
      } else if (ApiConfig.useDefaultApiKey &&
          ApiConfig.defaultOpenAipApiKey != 'YOUR_DEFAULT_API_KEY_HERE') {
        // Use default API key if enabled and configured
        _apiKey = ApiConfig.defaultOpenAipApiKey;
        _logger.d('✅ Using default OpenAIP API key');
      } else {
        _logger.w('⚠️ No OpenAIP API key configured');
      }

      _initialized = true;
    } catch (e) {
      _logger.e('❌ Error loading OpenAIP API key from storage: $e');
      throw Exception('Failed to initialize OpenAIP configuration: $e');
    }
  }

  /// Update the API key
  void setApiKey(String apiKey) {
    _apiKey = apiKey;
    _logger.d('🔑 OpenAIP API key updated');
  }

  /// Get authorization headers for API requests
  Map<String, String> getAuthHeaders() {
    if (!hasApiKey) {
      throw Exception('No API key available');
    }
    
    return {
      'Authorization': 'Bearer $_apiKey',
      'Accept': 'application/json',
      'Content-Type': 'application/json',
    };
  }
}