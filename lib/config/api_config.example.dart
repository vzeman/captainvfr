/// API Configuration Example
/// 
/// Copy this file to api_config.dart and update with your actual API keys
/// 
/// To use your own API key:
/// 1. Copy this file: cp api_config.example.dart api_config.dart
/// 2. Replace 'YOUR_DEFAULT_API_KEY_HERE' with your actual API key
/// 3. The api_config.dart file is gitignored to prevent accidental commits
/// 
/// To get an OpenAIP API key:
/// 1. Visit https://www.openaip.net/
/// 2. Create an account
/// 3. Generate an API key from your dashboard

class ApiConfig {
  // Default OpenAIP API key
  // TODO: Replace with your actual API key before building the app
  static const String defaultOpenAipApiKey = 'YOUR_DEFAULT_API_KEY_HERE';
  
  // Set to true to use the default key when no user key is provided
  // Set to false to require users to enter their own API key
  static const bool useDefaultApiKey = true;
  
  // Optional: Add other API keys here
  // static const String weatherApiKey = 'YOUR_WEATHER_API_KEY';
  // static const String mapboxApiKey = 'YOUR_MAPBOX_API_KEY';
}