import 'dart:developer' show log;

/// Service for interpreting METAR and TAF weather codes into human-readable descriptions
class WeatherInterpretationService {

  /// Interpret a METAR string into human-readable format
  String interpretMetar(String metar) {
    try {
      final parts = metar.split(' ');
      final List<String> interpretations = [];

      // Extract basic information
      String? timeGroup;
      String? windInfo;
      String? visibilityInfo;
      String? weatherInfo;
      String? cloudInfo;
      String? temperatureInfo;
      String? pressureInfo;

      for (int i = 0; i < parts.length; i++) {
        final part = parts[i].trim();
        if (part.isEmpty) continue;

        // Time group (6 digits followed by Z)
        if (RegExp(r'^\d{6}Z$').hasMatch(part)) {
          timeGroup = _interpretTimeGroup(part);
        }
        // Wind information
        else if (RegExp(r'^\d{3}\d{2,3}(G\d{2,3})?KT$').hasMatch(part) ||
                 RegExp(r'^\d{3}V\d{3}$').hasMatch(part) ||
                 part == 'VRB' || part.startsWith('VRB')) {
          windInfo = _interpretWind(part);
        }
        // Visibility
        else if (RegExp(r'^\d{4}$').hasMatch(part) ||
                 RegExp(r'^\d+SM$').hasMatch(part) ||
                 RegExp(r'^\d+/\d+SM$').hasMatch(part)) {
          visibilityInfo = _interpretVisibility(part);
        }
        // Weather phenomena
        else if (_isWeatherPhenomena(part)) {
          weatherInfo = _interpretWeatherPhenomena(part);
        }
        // Cloud information
        else if (RegExp(r'^(SKC|CLR|FEW|SCT|BKN|OVC)\d{3}$').hasMatch(part) ||
                 part == 'SKC' || part == 'CLR') {
          cloudInfo = _interpretClouds(part);
        }
        // Temperature and dewpoint
        else if (RegExp(r'^M?\d{2}/M?\d{2}$').hasMatch(part)) {
          temperatureInfo = _interpretTemperature(part);
        }
        // Pressure
        else if (RegExp(r'^A\d{4}$').hasMatch(part) || RegExp(r'^Q\d{4}$').hasMatch(part)) {
          pressureInfo = _interpretPressure(part);
        }
      }

      // Build interpretation
      if (timeGroup != null) interpretations.add(timeGroup);
      if (windInfo != null) interpretations.add(windInfo);
      if (visibilityInfo != null) interpretations.add(visibilityInfo);
      if (weatherInfo != null) interpretations.add(weatherInfo);
      if (cloudInfo != null) interpretations.add(cloudInfo);
      if (temperatureInfo != null) interpretations.add(temperatureInfo);
      if (pressureInfo != null) interpretations.add(pressureInfo);

      if (interpretations.isEmpty) {
        return 'Unable to interpret weather data';
      }

      return '${interpretations.join('. ')}.';

    } catch (e) {
      log('Error interpreting METAR: $e');
      return 'Unable to interpret weather data';
    }
  }

  /// Interpret a TAF string into human-readable format
  String interpretTaf(String taf) {
    try {
      // Clean and normalize the TAF string
      final cleanTaf = taf.replaceAll('\n', ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
      final parts = cleanTaf.split(' ');
      final List<String> interpretations = [];

      int i = 0;

      // Handle TAF header
      if (i < parts.length && parts[i] == 'TAF') {
        interpretations.add('Terminal Aerodrome Forecast');
        i++;
      }

      // Handle AMD (amendment) if present
      if (i < parts.length && parts[i] == 'AMD') {
        interpretations.add('Amendment');
        i++;
      }

      // Handle ICAO code
      String? icaoCode;
      if (i < parts.length && RegExp(r'^[A-Z]{4}$').hasMatch(parts[i])) {
        icaoCode = parts[i];
        interpretations.add('for $icaoCode');
        i++;
      }

      // Handle issue time (DDHHMM format followed by Z)
      if (i < parts.length && RegExp(r'^\d{6}Z$').hasMatch(parts[i])) {
        final issueTime = _interpretTafIssueTime(parts[i]);
        interpretations.add('issued $issueTime');
        i++;
      }

      // Handle validity period (DDHH/DDHH format)
      if (i < parts.length && RegExp(r'^\d{4}/\d{4}$').hasMatch(parts[i])) {
        final validityPeriod = _interpretValidityPeriod(parts[i]);
        interpretations.add('valid $validityPeriod');
        i++;
      }

      // Parse main forecast and conditional periods
      while (i < parts.length) {
        final forecastGroup = _parseForecastGroup(parts, i);
        if (forecastGroup.interpretation.isNotEmpty) {
          interpretations.add(forecastGroup.interpretation);
        }
        i = forecastGroup.nextIndex;
      }

      if (interpretations.isEmpty) {
        return 'Unable to interpret forecast data';
      }

      return '${interpretations.join('. ')}.';

    } catch (e) {
      log('Error interpreting TAF: $e');
      return 'Unable to interpret forecast data';
    }
  }

  String _interpretTafIssueTime(String timeGroup) {
    final day = timeGroup.substring(0, 2);
    final hour = timeGroup.substring(2, 4);
    final minute = timeGroup.substring(4, 6);
    return 'on day $day at $hour:$minute UTC';
  }

  String _interpretValidityPeriod(String validityGroup) {
    final parts = validityGroup.split('/');
    final fromDay = parts[0].substring(0, 2);
    final fromHour = parts[0].substring(2, 4);
    final toDay = parts[1].substring(0, 2);
    final toHour = parts[1].substring(2, 4);
    return 'from day $fromDay at $fromHour:00 UTC to day $toDay at $toHour:00 UTC';
  }

  ForecastGroup _parseForecastGroup(List<String> parts, int startIndex) {
    int i = startIndex;
    final List<String> groupInterpretations = [];

    // Handle forecast period indicators
    if (i < parts.length) {
      String? periodInfo;

      if (parts[i].startsWith('FM')) {
        periodInfo = _interpretForecastPeriod(parts[i]);
        i++;
      } else if (parts[i].startsWith('TEMPO')) {
        if (i + 1 < parts.length && RegExp(r'^\d{4}/\d{4}$').hasMatch(parts[i + 1])) {
          final timeRange = _interpretTempoBecmgTime(parts[i + 1]);
          periodInfo = 'Temporarily $timeRange';
          i += 2;
        } else {
          periodInfo = 'Temporarily';
          i++;
        }
      } else if (parts[i].startsWith('BECMG')) {
        if (i + 1 < parts.length && RegExp(r'^\d{4}/\d{4}$').hasMatch(parts[i + 1])) {
          final timeRange = _interpretTempoBecmgTime(parts[i + 1]);
          periodInfo = 'Becoming $timeRange';
          i += 2;
        } else {
          periodInfo = 'Becoming';
          i++;
        }
      } else if (parts[i].startsWith('PROB')) {
        final prob = parts[i].substring(4);
        if (i + 1 < parts.length && RegExp(r'^\d{4}/\d{4}$').hasMatch(parts[i + 1])) {
          final timeRange = _interpretTempoBecmgTime(parts[i + 1]);
          periodInfo = '$prob% probability $timeRange';
          i += 2;
        } else {
          periodInfo = '$prob% probability';
          i++;
        }
      }

      if (periodInfo != null) {
        groupInterpretations.add(periodInfo);
      }
    }

    // Parse weather elements for this group
    String? windInfo;
    String? visibilityInfo;
    String? weatherInfo;
    final List<String> cloudInfos = [];
    String? temperatureInfo;
    final List<String> weatherPhenomena = [];

    while (i < parts.length) {
      final part = parts[i];

      // Stop if we hit another forecast period
      if (part.startsWith('FM') || part.startsWith('TEMPO') ||
          part.startsWith('BECMG') || part.startsWith('PROB')) {
        break;
      }

      // Wind information
      if (RegExp(r'^\d{3}\d{2,3}(G\d{2,3})?KT$').hasMatch(part) ||
          RegExp(r'^\d{3}V\d{3}$').hasMatch(part) ||
          part == 'VRB' || part.startsWith('VRB')) {
        windInfo = _interpretWind(part);
      }
      // Visibility
      else if (RegExp(r'^\d{4}$').hasMatch(part) ||
               RegExp(r'^\d+SM$').hasMatch(part) ||
               RegExp(r'^\d+/\d+SM$').hasMatch(part) ||
               part == 'CAVOK') {
        if (part == 'CAVOK') {
          visibilityInfo = 'Ceiling and visibility OK (visibility >10km, no clouds below 5000ft, no significant weather)';
        } else {
          visibilityInfo = _interpretVisibility(part);
        }
      }
      // Weather phenomena
      else if (_isWeatherPhenomena(part)) {
        final phenomenon = _interpretWeatherPhenomena(part);
        if (phenomenon != null) {
          weatherPhenomena.add(phenomenon);
        }
      }
      // Cloud information
      else if (RegExp(r'^(SKC|CLR|FEW|SCT|BKN|OVC)\d{3}$').hasMatch(part) ||
               part == 'SKC' || part == 'CLR' || part == 'NSC') {
        if (part == 'NSC') {
          cloudInfos.add('No significant cloud');
        } else {
          final cloudInfo = _interpretClouds(part);
          if (cloudInfo != null) {
            cloudInfos.add(cloudInfo);
          }
        }
      }
      // Temperature forecast (TX/TN format)
      else if (RegExp(r'^T[XN]M?\d{2}/\d{4}Z$').hasMatch(part)) {
        temperatureInfo = _interpretTemperatureForecast(part);
      }
      // Wind shear
      else if (part == 'WS' && i + 1 < parts.length) {
        final wsInfo = _interpretWindShear(parts[i + 1]);
        if (wsInfo != null) {
          groupInterpretations.add(wsInfo);
          i++; // Skip the next part as we consumed it
        }
      }

      i++;
    }

    // Combine weather phenomena
    if (weatherPhenomena.isNotEmpty) {
      weatherInfo = weatherPhenomena.join(', ');
    }

    // Build interpretation for this group
    final elementInterpretations = <String>[];
    if (windInfo != null) elementInterpretations.add(windInfo);
    if (visibilityInfo != null) elementInterpretations.add(visibilityInfo);
    if (weatherInfo != null) elementInterpretations.add(weatherInfo);
    if (cloudInfos.isNotEmpty) elementInterpretations.add(cloudInfos.join(', '));
    if (temperatureInfo != null) elementInterpretations.add(temperatureInfo);

    if (elementInterpretations.isNotEmpty) {
      groupInterpretations.add(elementInterpretations.join(': '));
    }

    return ForecastGroup(
      interpretation: groupInterpretations.join(': '),
      nextIndex: i,
    );
  }

  String _interpretTempoBecmgTime(String timeRange) {
    final parts = timeRange.split('/');
    final fromHour = parts[0].substring(0, 2);
    final fromMin = parts[0].substring(2, 4);
    final toHour = parts[1].substring(0, 2);
    final toMin = parts[1].substring(2, 4);
    return 'between $fromHour:$fromMin and $toHour:$toMin UTC';
  }

  String? _interpretTemperatureForecast(String tempForecast) {
    // Format: TX25/1214Z or TNM02/0506Z
    final isMax = tempForecast.startsWith('TX');
    final tempPart = tempForecast.substring(2);
    final parts = tempPart.split('/');

    if (parts.length == 2) {
      final temp = _parseTemperature(parts[0]);
      final time = parts[1].substring(0, 4); // Remove Z
      final day = time.substring(0, 2);
      final hour = time.substring(2, 4);

      final tempType = isMax ? 'Maximum' : 'Minimum';
      return '$tempType temperature $temp°C on day $day at $hour:00 UTC';
    }

    return null;
  }

  String? _interpretWindShear(String windShearInfo) {
    // Format: WS020/24045KT (wind shear at 2000ft, wind 240/45KT)
    final match = RegExp(r'^(\d{3})/(\d{3})(\d{2,3})(G\d{2,3})?KT$').firstMatch(windShearInfo);
    if (match != null) {
      final altitude = int.parse(match.group(1)!) * 100;
      final direction = match.group(2)!;
      final speed = match.group(3)!;
      final gust = match.group(4);

      String windDesc = 'Wind shear at $altitude feet: wind from $direction degrees at $speed knots';
      if (gust != null) {
        final gustSpeed = gust.substring(1); // Remove 'G'
        windDesc += ', gusting to $gustSpeed knots';
      }
      return windDesc;
    }

    return null;
  }

  String _interpretTimeGroup(String timeGroup) {
    final day = timeGroup.substring(0, 2);
    final hour = timeGroup.substring(2, 4);
    final minute = timeGroup.substring(4, 6);
    return 'Observed on day $day at $hour:$minute UTC';
  }

  String? _interpretWind(String wind) {
    if (wind.startsWith('VRB')) {
      final speedMatch = RegExp(r'VRB(\d+)KT').firstMatch(wind);
      if (speedMatch != null) {
        return 'Variable wind at ${speedMatch.group(1)} knots';
      }
      return 'Variable wind';
    }

    final windMatch = RegExp(r'^(\d{3})(\d{2,3})(G(\d{2,3}))?KT$').firstMatch(wind);
    if (windMatch != null) {
      final direction = windMatch.group(1)!;
      final speed = windMatch.group(2)!;
      final gust = windMatch.group(4);

      String windDesc = 'Wind from $direction degrees at $speed knots';
      if (gust != null) {
        windDesc += ', gusting to $gust knots';
      }
      return windDesc;
    }

    if (RegExp(r'^\d{3}V\d{3}$').hasMatch(wind)) {
      final parts = wind.split('V');
      return 'Wind direction variable between ${parts[0]} and ${parts[1]} degrees';
    }

    return null;
  }

  String? _interpretVisibility(String visibility) {
    if (RegExp(r'^\d{4}$').hasMatch(visibility)) {
      final vis = int.parse(visibility);
      if (vis >= 9999) {
        return 'Visibility greater than 10 kilometers';
      } else {
        return 'Visibility $vis meters';
      }
    }

    if (visibility.endsWith('SM')) {
      final visValue = visibility.substring(0, visibility.length - 2);
      if (visValue.contains('/')) {
        return 'Visibility $visValue statute miles';
      } else {
        return 'Visibility $visValue statute miles';
      }
    }

    return null;
  }

  bool _isWeatherPhenomena(String code) {
    final phenomena = [
      'RA', 'SN', 'DZ', 'FG', 'BR', 'HZ', 'FU', 'VA', 'DU', 'SA', 'PY',
      'SQ', 'FC', 'SS', 'DS', 'PO', 'GR', 'GS', 'UP', 'IC', 'PL', 'SG'
    ];

    final intensities = ['+', '-', 'VC'];
    final descriptors = ['MI', 'PR', 'BC', 'DR', 'BL', 'SH', 'TS', 'FZ'];

    String workingCode = code;

    // Remove intensity
    for (final intensity in intensities) {
      if (workingCode.startsWith(intensity)) {
        workingCode = workingCode.substring(intensity.length);
        break;
      }
    }

    // Remove descriptor
    for (final descriptor in descriptors) {
      if (workingCode.startsWith(descriptor)) {
        workingCode = workingCode.substring(descriptor.length);
        break;
      }
    }

    // Check if remaining code contains weather phenomena
    for (final phenomenon in phenomena) {
      if (workingCode.contains(phenomenon)) {
        return true;
      }
    }

    return false;
  }

  String? _interpretWeatherPhenomena(String code) {
    final Map<String, String> intensities = {
      '+': 'Heavy',
      '-': 'Light',
      'VC': 'In the vicinity',
    };

    final Map<String, String> descriptors = {
      'MI': 'Shallow',
      'PR': 'Partial',
      'BC': 'Patches',
      'DR': 'Drifting',
      'BL': 'Blowing',
      'SH': 'Showers',
      'TS': 'Thunderstorm',
      'FZ': 'Freezing',
    };

    final Map<String, String> phenomena = {
      'RA': 'rain',
      'SN': 'snow',
      'DZ': 'drizzle',
      'FG': 'fog',
      'BR': 'mist',
      'HZ': 'haze',
      'FU': 'smoke',
      'VA': 'volcanic ash',
      'DU': 'dust',
      'SA': 'sand',
      'PY': 'spray',
      'SQ': 'squalls',
      'FC': 'funnel cloud',
      'SS': 'sandstorm',
      'DS': 'duststorm',
      'PO': 'dust/sand whirls',
      'GR': 'hail',
      'GS': 'small hail',
      'UP': 'unknown precipitation',
      'IC': 'ice crystals',
      'PL': 'ice pellets',
      'SG': 'snow grains',
    };

    String workingCode = code;
    final List<String> parts = [];

    // Extract intensity
    for (final entry in intensities.entries) {
      if (workingCode.startsWith(entry.key)) {
        parts.add(entry.value.toLowerCase());
        workingCode = workingCode.substring(entry.key.length);
        break;
      }
    }

    // Extract descriptor
    for (final entry in descriptors.entries) {
      if (workingCode.startsWith(entry.key)) {
        parts.add(entry.value.toLowerCase());
        workingCode = workingCode.substring(entry.key.length);
        break;
      }
    }

    // Extract phenomena
    final foundPhenomena = <String>[];
    String remaining = workingCode;
    for (final entry in phenomena.entries) {
      if (remaining.contains(entry.key)) {
        foundPhenomena.add(entry.value);
        remaining = remaining.replaceAll(entry.key, '');
      }
    }

    if (foundPhenomena.isNotEmpty) {
      parts.addAll(foundPhenomena);
    }

    if (parts.isNotEmpty) {
      return parts.join(' ').trim();
    }

    return null;
  }

  String? _interpretClouds(String cloud) {
    if (cloud == 'SKC' || cloud == 'CLR') {
      return 'Clear skies';
    }

    final cloudMatch = RegExp(r'^(FEW|SCT|BKN|OVC)(\d{3})$').firstMatch(cloud);
    if (cloudMatch != null) {
      final coverage = cloudMatch.group(1)!;
      final altitude = int.parse(cloudMatch.group(2)!) * 100;

      final Map<String, String> coverageTypes = {
        'FEW': 'Few clouds',
        'SCT': 'Scattered clouds',
        'BKN': 'Broken clouds',
        'OVC': 'Overcast',
      };

      return '${coverageTypes[coverage]} at $altitude feet';
    }

    return null;
  }

  String? _interpretTemperature(String temp) {
    final parts = temp.split('/');
    if (parts.length == 2) {
      final temperature = _parseTemperature(parts[0]);
      final dewpoint = _parseTemperature(parts[1]);

      return 'Temperature $temperature°C, dewpoint $dewpoint°C';
    }
    return null;
  }

  String _parseTemperature(String temp) {
    if (temp.startsWith('M')) {
      return '-${temp.substring(1)}';
    }
    return temp;
  }

  String? _interpretPressure(String pressure) {
    if (pressure.startsWith('A')) {
      final value = pressure.substring(1);
      final inHg = double.parse(value) / 100;
      return 'Barometric pressure ${inHg.toStringAsFixed(2)} inHg';
    } else if (pressure.startsWith('Q')) {
      final value = pressure.substring(1);
      return 'Barometric pressure $value hPa';
    }
    return null;
  }

  String? _interpretForecastPeriod(String period) {
    if (period.startsWith('FM')) {
      final time = period.substring(2);
      if (time.length >= 4) {
        final hour = time.substring(0, 2);
        final minute = time.substring(2, 4);
        return 'From $hour:$minute UTC';
      }
    } else if (period.startsWith('TEMPO')) {
      return 'Temporarily';
    } else if (period.startsWith('BECMG')) {
      return 'Becoming';
    } else if (period.startsWith('PROB')) {
      final prob = period.substring(4);
      return '$prob% probability';
    }
    return null;
  }
}

class ForecastGroup {
  final String interpretation;
  final int nextIndex;

  ForecastGroup({
    required this.interpretation,
    required this.nextIndex,
  });
}
