import 'package:flutter/foundation.dart' show kIsWeb;

/// Service to handle CORS proxy for web platform
class CorsProxyService {
  // Option 1: Use a public CORS proxy (for development/testing)
  // Note: Don't use public proxies for production due to reliability/security
  static const String _publicProxy = 'https://corsproxy.io/?';
  
  // Option 2: Use your own CORS proxy server
  // Replace with your actual proxy server URL
  static const String _customProxy = 'https://your-proxy-server.com/proxy?url=';
  
  // Choose which proxy to use
  static const bool _useCustomProxy = false;
  
  /// Wrap URL with CORS proxy if running on web
  static String wrapUrl(String url) {
    if (!kIsWeb) {
      return url;
    }
    
    // Don't proxy URLs that already support CORS
    if (_supportsCors(url)) {
      return url;
    }
    
    // Use appropriate proxy
    final proxy = _useCustomProxy ? _customProxy : _publicProxy;
    return '$proxy${Uri.encodeComponent(url)}';
  }
  
  /// Check if URL already supports CORS
  static bool _supportsCors(String url) {
    final corsEnabledDomains = [
      'tile.openstreetmap.org',
      'davidmegginson.github.io',
      'api.core.openaip.net',
      'dns.google',
      'localhost',
    ];
    
    final uri = Uri.parse(url);
    return corsEnabledDomains.any((domain) => uri.host.contains(domain));
  }
  
  /// Check if we need CORS proxy for this URL
  static bool needsCorsProxy(String url) {
    return kIsWeb && !_supportsCors(url);
  }
}