import 'dart:developer' show log;
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class UrlLauncherUtils {
  /// Launches a URL in the default browser or phone app
  static Future<void> launch(BuildContext context, String url) async {
    try {
      final uri = _parseUrl(url);

      if (!await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      )) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Could not launch $url')),
          );
        }
      }
    } on FormatException {
      log('Invalid URL format: $url');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Invalid URL format')),
        );
      }
    } catch (e) {
      log('Could not launch $url', error: e);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not launch $url')),
        );
      }
    }
  }

  /// Parses a URL string into a Uri object, handling various URL formats
  static Uri _parseUrl(String url) {
    if (url.startsWith('http://') ||
        url.startsWith('https://') ||
        url.startsWith('tel:')) {
      return Uri.parse(url);
    } else if (url.startsWith('www.')) {
      return Uri.https(url.substring(4));
    } else if (url.contains('@')) {
      return Uri(scheme: 'mailto', path: url);
    } else {
      // Default to https if no scheme is provided
      return Uri.https(url);
    }
  }
}
