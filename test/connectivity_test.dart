import 'package:flutter_test/flutter_test.dart';
import 'package:captainvfr/services/connectivity_service.dart';

void main() {
  group('ConnectivityService', () {
    late ConnectivityService service;

    setUp(() {
      service = ConnectivityService();
    });

    test('initializes correctly', () async {
      await service.initialize();
      expect(service.hasInternetConnection, isNotNull);
    });

    test('getConnectionStatusMessage returns appropriate messages', () {
      // Test when checking
      expect(
        service.getConnectionStatusMessage(),
        anyOf([
          equals('Checking internet connection...'),
          equals('No internet connection. Some features may be limited.'),
          equals('Connected to internet'),
        ]),
      );
    });

    test('getAffectedFeatures returns list of features', () {
      final features = service.getAffectedFeatures();
      expect(features, isNotEmpty);
      expect(features, contains('Live weather updates'));
      expect(features, contains('Airport information updates'));
    });
  });
}