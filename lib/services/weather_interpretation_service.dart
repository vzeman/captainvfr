import 'weather_interpretation/weather_phenomena_constants.dart';
import 'weather_interpretation/cloud_type_constants.dart';
import 'weather_interpretation/aviation_abbreviations_constants.dart';
import 'weather_interpretation/special_conditions_constants.dart';
import 'weather_interpretation/uvwxyz_abbreviations_constants.dart';

/// Service for interpreting METAR and TAF weather codes into human-readable descriptions
class WeatherInterpretationService {
  /// Interprets weather phenomena codes from METAR/TAF
  static String interpretWeatherPhenomena(String code) {
    // Check for special combined cases first (like +FC)
    if (WeatherPhenomena.phenomena.containsKey(code)) {
      return WeatherPhenomena.phenomena[code]!;
    }

    // Check for intensity modifiers and temporal indicators
    String intensity = '';
    String remaining = code;

    // Sort keys by length (longest first) to match longer patterns first
    List<String> intensityKeys = WeatherPhenomena.intensities.keys.toList()
      ..sort((a, b) => b.length.compareTo(a.length));

    for (String key in intensityKeys) {
      if (code.startsWith(key)) {
        intensity = '${WeatherPhenomena.intensities[key]!} ';
        remaining = code.substring(key.length);
        break;
      }
    }

    // Check for descriptors
    String descriptor = '';
    List<String> descriptorKeys = WeatherPhenomena.descriptors.keys.toList()
      ..sort((a, b) => b.length.compareTo(a.length));

    for (String key in descriptorKeys) {
      if (remaining.startsWith(key)) {
        descriptor = '${WeatherPhenomena.descriptors[key]!} ';
        remaining = remaining.substring(key.length);
        break;
      }
    }

    // Check for phenomena
    String phenomenon = WeatherPhenomena.phenomena[remaining] ?? remaining;

    return '$intensity$descriptor$phenomenon'.trim();
  }

  /// Interprets cloud type codes from METAR/TAF
  static String interpretCloudType(String code) {
    return CloudTypeConstants.cloudTypes[code] ?? code;
  }

  /// Interprets aviation abbreviations
  static String interpretAviationAbbreviation(String code) {
    return AviationAbbreviations.abbreviations[code] ?? code;
  }

  /// Interprets U-Z aviation abbreviations
  static String interpretUVWXYZAbbreviation(String code) {
    return UVWXYZAbbreviations.abbreviations[code] ?? code;
  }

  /// Interprets special weather conditions
  static String interpretSpecialCondition(String code) {
    return SpecialConditions.conditions[code] ?? code;
  }

  /// Interprets a complete weather code by trying different interpretation methods
  static String interpretWeatherCode(String code) {
    // Try special conditions first
    String specialResult = interpretSpecialCondition(code);
    if (specialResult != code) return specialResult;

    // Try cloud types
    String cloudResult = interpretCloudType(code);
    if (cloudResult != code) return cloudResult;

    // Try weather phenomena
    String weatherResult = interpretWeatherPhenomena(code);
    if (weatherResult != code) return weatherResult;

    // Try aviation abbreviations
    String aviationResult = interpretAviationAbbreviation(code);
    if (aviationResult != code) return aviationResult;

    // Try U-Z aviation abbreviations
    String uvwxyzResult = interpretUVWXYZAbbreviation(code);
    if (uvwxyzResult != code) return uvwxyzResult;

    // Return original code if no interpretation found
    return code;
  }

  /// Interprets multiple weather codes separated by spaces
  static String interpretWeatherCodes(String codes) {
    return codes
        .split(' ')
        .map((code) => interpretWeatherCode(code.trim()))
        .where((result) => result.isNotEmpty)
        .join(' ');
  }

  /// Legacy method for backward compatibility - interprets any weather-related term
  static String interpret(String code) {
    return interpretWeatherCode(code);
  }

  /// Interprets a complete METAR report into human-readable format
  String interpretMetar(String metar) {
    if (metar.isEmpty) return 'No METAR data available';

    List<String> parts = metar.trim().split(RegExp(r'\s+'));
    List<String> interpretedParts = [];

    for (int i = 0; i < parts.length; i++) {
      String part = parts[i];
      String interpretation = _parseMetarComponent(part, i, parts);
      if (interpretation.isNotEmpty && interpretation != part) {
        interpretedParts.add(interpretation);
      }
    }

    return interpretedParts.isEmpty
        ? 'Weather conditions normal'
        : interpretedParts.join('. ');
  }

  /// Interprets a complete TAF report into human-readable format
  String interpretTaf(String taf) {
    if (taf.isEmpty) return 'No TAF data available';

    List<String> parts = taf.trim().split(RegExp(r'\s+'));
    List<String> interpretedParts = [];

    for (int i = 0; i < parts.length; i++) {
      String part = parts[i];
      String interpretation = _parseTafComponent(part, i, parts);
      if (interpretation.isNotEmpty && interpretation != part) {
        interpretedParts.add(interpretation);
      }
    }

    return interpretedParts.isEmpty
        ? 'Forecast conditions normal'
        : interpretedParts.join('. ');
  }

  /// Parses individual METAR components
  String _parseMetarComponent(
    String component,
    int index,
    List<String> allParts,
  ) {
    // Skip station identifier (first component)
    if (index == 0 && RegExp(r'^[A-Z]{4}$').hasMatch(component)) {
      return 'Station: $component';
    }

    // Date/time (e.g., 121853Z)
    if (RegExp(r'^\d{6}Z$').hasMatch(component)) {
      String day = component.substring(0, 2);
      String hour = component.substring(2, 4);
      String minute = component.substring(4, 6);
      return 'Observed on day $day at $hour:$minute UTC';
    }

    // Wind (e.g., 12008KT, 00000KT, VRB05KT)
    if (RegExp(r'^(\d{3}|VRB)\d{2,3}(G\d{2,3})?KT$').hasMatch(component)) {
      return _parseWind(component);
    }

    // Variable wind direction (e.g., 280V350)
    if (RegExp(r'^\d{3}V\d{3}$').hasMatch(component)) {
      List<String> directions = component.split('V');
      return 'Wind direction variable between ${directions[0]}° and ${directions[1]}°';
    }

    // Visibility (e.g., 10SM, 1/2SM, M1/4SM)
    if (RegExp(r'^(M)?(\d+|\d+/\d+|\d+\s+\d+/\d+)?SM$').hasMatch(component)) {
      return _parseVisibility(component);
    }

    // Runway visual range (e.g., R06/2400FT)
    if (RegExp(r'^R\d{2}[LCR]?/\d{4}(V\d{4})?FT$').hasMatch(component)) {
      return _parseRunwayVisualRange(component);
    }

    // Weather phenomena (e.g., -RA, +TSRA, VCSH)
    if (RegExp(
      r'^(\+|-|VC|RE)?(MI|PR|BC|DR|BL|SH|TS|FZ)?(DZ|RA|SN|SG|IC|PL|GR|GS|UP|BR|FG|FU|VA|DU|SA|HZ|PY|PO|SQ|FC|SS|DS)+$',
    ).hasMatch(component)) {
      return _parseWeatherPhenomena(component);
    }

    // Sky condition (e.g., SKC, CLR, FEW015, SCT025, BKN040, OVC100)
    if (RegExp(
      r'^(SKC|CLR|FEW|SCT|BKN|OVC|VV)(\d{3})?(CB|TCU)?$',
    ).hasMatch(component)) {
      return _parseSkyCondition(component);
    }

    // Temperature and dewpoint (e.g., 25/18, M05/M12)
    if (RegExp(r'^M?\d{2}/M?\d{2}$').hasMatch(component)) {
      return _parseTemperatureDewpoint(component);
    }

    // Altimeter setting (e.g., A3012, Q1013)
    if (RegExp(r'^[AQ]\d{4}$').hasMatch(component)) {
      return _parseAltimeter(component);
    }

    // Remarks section
    if (component == 'RMK') {
      return 'Remarks';
    }

    // Try other interpretation methods
    return interpretWeatherCode(component);
  }

  /// Parses individual TAF components
  String _parseTafComponent(
    String component,
    int index,
    List<String> allParts,
  ) {
    // TAF header
    if (component == 'TAF') {
      return 'Terminal Aerodrome Forecast';
    }

    // Station identifier (e.g., KJFK)
    if (index == 1 && RegExp(r'^[A-Z]{4}$').hasMatch(component)) {
      return 'Station: $component';
    }

    // Issue time (e.g., 121740Z)
    if (RegExp(r'^\d{6}Z$').hasMatch(component)) {
      String day = component.substring(0, 2);
      String hour = component.substring(2, 4);
      String minute = component.substring(4, 6);
      return 'Issued on day $day at $hour:$minute UTC';
    }

    // Valid period (e.g., 1218/1324)
    if (RegExp(r'^\d{4}/\d{4}$').hasMatch(component)) {
      List<String> period = component.split('/');
      String fromDay = period[0].substring(0, 2);
      String fromHour = period[0].substring(2, 4);
      String toDay = period[1].substring(0, 2);
      String toHour = period[1].substring(2, 4);
      return 'Valid from day $fromDay $fromHour:00 to day $toDay $toHour:00 UTC';
    }

    // Time periods (e.g., FM1200, TL1800)
    if (RegExp(r'^(FM|TL)\d{4}$').hasMatch(component)) {
      String prefix = component.substring(0, 2);
      String time = component.substring(2);
      String hour = time.substring(0, 2);
      String minute = time.substring(2);
      String meaning = prefix == 'FM' ? 'From' : 'Until';
      return '$meaning $hour:$minute UTC';
    }

    // Probability (e.g., PROB30, PROB40)
    if (RegExp(r'^PROB\d{2}$').hasMatch(component)) {
      String prob = component.substring(4);
      return '$prob% probability';
    }

    // Use METAR parsing for weather elements
    return _parseMetarComponent(component, index, allParts);
  }

  /// Parses wind information
  String _parseWind(String wind) {
    if (wind == '00000KT') {
      return 'Calm winds';
    }

    RegExp windRegex = RegExp(r'^(\d{3}|VRB)(\d{2,3})(G(\d{2,3}))?KT$');
    Match? match = windRegex.firstMatch(wind);

    if (match != null) {
      String direction = match.group(1)!;
      String speed = match.group(2)!;
      String? gust = match.group(4);

      String directionText = direction == 'VRB' ? 'variable' : '$direction°';
      String speedText = '${int.parse(speed)} knots';

      if (gust != null) {
        speedText += ' gusting to ${int.parse(gust)} knots';
      }

      return 'Wind from $directionText at $speedText';
    }

    return wind;
  }

  /// Parses visibility information
  String _parseVisibility(String visibility) {
    if (visibility == '10SM' || visibility == '9999') {
      return 'Visibility 10+ statute miles';
    }

    if (visibility.startsWith('M')) {
      String value = visibility.substring(1, visibility.length - 2);
      return 'Visibility less than $value statute miles';
    }

    if (visibility.endsWith('SM')) {
      String value = visibility.substring(0, visibility.length - 2);
      return 'Visibility $value statute miles';
    }

    return visibility;
  }

  /// Parses runway visual range
  String _parseRunwayVisualRange(String rvr) {
    RegExp rvrRegex = RegExp(r'^R(\d{2}[LCR]?)/(\d{4})(V(\d{4}))?FT$');
    Match? match = rvrRegex.firstMatch(rvr);

    if (match != null) {
      String runway = match.group(1)!;
      String vis1 = match.group(2)!;
      String? vis2 = match.group(4);

      if (vis2 != null) {
        return 'Runway $runway visual range variable from $vis1 to $vis2 feet';
      } else {
        return 'Runway $runway visual range $vis1 feet';
      }
    }

    return rvr;
  }

  /// Enhanced weather phenomena parsing
  String _parseWeatherPhenomena(String phenomena) {
    String result = '';
    String remaining = phenomena;

    // Check for intensity first
    if (remaining.startsWith('+')) {
      result += 'Heavy ';
      remaining = remaining.substring(1);
    } else if (remaining.startsWith('-')) {
      result += 'Light ';
      remaining = remaining.substring(1);
    }

    // Check for proximity/recent
    if (remaining.startsWith('VC')) {
      result += 'In vicinity ';
      remaining = remaining.substring(2);
    } else if (remaining.startsWith('RE')) {
      result += 'Recent ';
      remaining = remaining.substring(2);
    }

    // Check for descriptors
    Map<String, String> descriptors = {
      'MI': 'shallow',
      'PR': 'partial',
      'BC': 'patches of',
      'DR': 'low drifting',
      'BL': 'blowing',
      'SH': 'showers of',
      'TS': 'thunderstorm with',
      'FZ': 'freezing',
    };

    for (String desc in descriptors.keys) {
      if (remaining.startsWith(desc)) {
        result += '${descriptors[desc]} ';
        remaining = remaining.substring(desc.length);
        break;
      }
    }

    // Parse remaining phenomena
    Map<String, String> phenomenaMap = {
      'DZ': 'drizzle',
      'RA': 'rain',
      'SN': 'snow',
      'SG': 'snow grains',
      'IC': 'ice crystals',
      'PL': 'ice pellets',
      'GR': 'hail',
      'GS': 'small hail',
      'UP': 'unknown precipitation',
      'BR': 'mist',
      'FG': 'fog',
      'FU': 'smoke',
      'VA': 'volcanic ash',
      'DU': 'dust',
      'SA': 'sand',
      'HZ': 'haze',
      'PY': 'spray',
      'PO': 'dust whirls',
      'SQ': 'squalls',
      'FC': 'funnel cloud',
      'SS': 'sandstorm',
      'DS': 'duststorm',
    };

    // Parse all remaining phenomena codes
    String phenomenaText = '';
    for (String code in phenomenaMap.keys) {
      if (remaining.contains(code)) {
        if (phenomenaText.isNotEmpty) phenomenaText += ' and ';
        phenomenaText += phenomenaMap[code]!;
        remaining = remaining.replaceAll(code, '');
      }
    }

    result += phenomenaText;
    return result.trim();
  }

  /// Parses sky condition
  String _parseSkyCondition(String sky) {
    if (sky == 'SKC' || sky == 'CLR') {
      return sky == 'SKC' ? 'Sky clear' : 'Clear skies';
    }

    RegExp skyRegex = RegExp(r'^(FEW|SCT|BKN|OVC|VV)(\d{3})?(CB|TCU)?$');
    Match? match = skyRegex.firstMatch(sky);

    if (match != null) {
      String coverage = match.group(1)!;
      String? height = match.group(2);
      String? type = match.group(3);

      Map<String, String> coverageMap = {
        'FEW': 'Few clouds',
        'SCT': 'Scattered clouds',
        'BKN': 'Broken clouds',
        'OVC': 'Overcast',
        'VV': 'Vertical visibility',
      };

      String result = coverageMap[coverage] ?? coverage;

      if (height != null) {
        int heightFt = int.parse(height) * 100;
        result += ' at $heightFt feet';
      }

      if (type != null) {
        if (type == 'CB') result += ' (cumulonimbus)';
        if (type == 'TCU') result += ' (towering cumulus)';
      }

      return result;
    }

    return sky;
  }

  /// Parses temperature and dewpoint
  String _parseTemperatureDewpoint(String tempDew) {
    List<String> parts = tempDew.split('/');
    if (parts.length == 2) {
      String temp = parts[0].replaceAll('M', '-');
      String dewpoint = parts[1].replaceAll('M', '-');
      return 'Temperature $temp°C, dewpoint $dewpoint°C';
    }
    return tempDew;
  }

  /// Parses altimeter setting
  String _parseAltimeter(String altimeter) {
    if (altimeter.startsWith('A')) {
      String value = altimeter.substring(1);
      double inHg = double.parse(value) / 100;
      return 'Altimeter ${inHg.toStringAsFixed(2)} inches Hg';
    } else if (altimeter.startsWith('Q')) {
      String value = altimeter.substring(1);
      return 'QNH $value hectopascals';
    }
    return altimeter;
  }

  /// Checks if METAR contains dangerous weather conditions
  bool hasDangerousWeatherInMetar(String metar) {
    if (metar.isEmpty) return false;

    String upperMetar = metar.toUpperCase();

    // Comprehensive dangerous weather patterns
    List<String> dangerousPatterns = [
      // Thunderstorms - all variants
      'TS', 'TSRA', 'TSGR', 'TSGS', 'TSSN', 'TSDZ', 'TSPL', 'TSIC',
      '+TS', '-TS', 'VCTS', 'RETS',

      // Tornadoes and funnel clouds
      'FC', '+FC', 'VCFC',

      // Severe weather
      'SQ', // Squalls
      'SS', 'DS', // Sandstorm/Duststorm
      'GR', 'GS', // Hail of any size
      '+GR', '-GR', 'SHGR', 'TSGR',

      // Heavy precipitation (reduces visibility significantly)
      '+RA', '+SN', '+DZ', '+GS', '+PL', '+IC',

      // Freezing conditions (icing hazard)
      'FZ', 'FZRA', 'FZDZ', 'FZFG', 'FZUP',

      // Severe visibility restrictions
      'FG', 'BCFG', 'PRFG', 'MIFG', 'FZFG',

      // Blowing conditions
      'BLSN', 'BLDU', 'BLSA', 'BL',

      // Unknown precipitation (unpredictable)
      'UP', '+UP', '-UP', 'SHUP',

      // Low visibility conditions
      'BR', 'HZ', 'FU', 'VA', 'DU', 'SA',

      // Severe wind conditions (look for high winds in remarks)
      'WS', // Wind shear
    ];

    // Check for dangerous patterns
    bool hasDangerous = dangerousPatterns.any(
      (pattern) => upperMetar.contains(pattern),
    );

    // Additional checks for specific dangerous conditions
    if (!hasDangerous) {
      // Check for low visibility (less than 3SM is dangerous for VFR)
      // Be more specific with visibility patterns to avoid false positives
      RegExp lowVisRegex = RegExp(
        r'\b([0-2]SM|M1/4SM|1/4SM|1/2SM|3/4SM|1SM|2SM)\b',
      );
      if (lowVisRegex.hasMatch(upperMetar)) {
        // Double-check that it's not 10SM, 20SM etc.
        if (!RegExp(r'\b(10SM|[1-9][0-9]SM)\b').hasMatch(upperMetar)) {
          hasDangerous = true;
        }
      }

      // Check for low cloud ceilings (less than 1000ft is dangerous for VFR)
      RegExp lowCeilingRegex = RegExp(r'\b(BKN|OVC)(00[0-9]|0[0-9][0-9])\b');
      if (lowCeilingRegex.hasMatch(upperMetar)) hasDangerous = true;

      // Check for strong winds (>20 knots or gusts >25 knots)
      RegExp strongWindRegex = RegExp(
        r'\b(\d{3}[2-9][0-9]KT|\d{3}\d{2}G[2-9][0-9]KT|\d{3}\d{2}G\d{3}KT)\b',
      );
      if (strongWindRegex.hasMatch(upperMetar)) hasDangerous = true;

      // Check for variable wind direction with high speeds
      RegExp variableStrongWindRegex = RegExp(r'\bVRB[2-9][0-9]KT\b');
      if (variableStrongWindRegex.hasMatch(upperMetar)) hasDangerous = true;
    }

    return hasDangerous;
  }

  /// Checks if TAF contains dangerous weather conditions
  bool hasDangerousWeatherInTaf(String taf) {
    if (taf.isEmpty) return false;

    String upperTaf = taf.toUpperCase();

    // Same dangerous patterns as METAR
    List<String> dangerousPatterns = [
      // Thunderstorms - all variants
      'TS', 'TSRA', 'TSGR', 'TSGS', 'TSSN', 'TSDZ', 'TSPL', 'TSIC',
      '+TS', '-TS', 'VCTS', 'RETS',

      // Tornadoes and funnel clouds
      'FC', '+FC', 'VCFC',

      // Severe weather
      'SQ', // Squalls
      'SS', 'DS', // Sandstorm/Duststorm
      'GR', 'GS', // Hail of any size
      '+GR', '-GR', 'SHGR', 'TSGR',

      // Heavy precipitation
      '+RA', '+SN', '+DZ', '+GS', '+PL', '+IC',

      // Freezing conditions
      'FZ', 'FZRA', 'FZDZ', 'FZFG', 'FZUP',

      // Severe visibility restrictions
      'FG', 'BCFG', 'PRFG', 'MIFG', 'FZFG',

      // Blowing conditions
      'BLSN', 'BLDU', 'BLSA', 'BL',

      // Unknown precipitation
      'UP', '+UP', '-UP', 'SHUP',

      // Low visibility conditions
      'BR', 'HZ', 'FU', 'VA', 'DU', 'SA',

      // Wind shear
      'WS',
    ];

    // Check for dangerous patterns
    bool hasDangerous = dangerousPatterns.any(
      (pattern) => upperTaf.contains(pattern),
    );

    // Additional checks for TAF-specific dangerous conditions
    if (!hasDangerous) {
      // Check for low visibility forecasts
      // Be more specific with visibility patterns to avoid false positives
      RegExp lowVisRegex = RegExp(
        r'\b([0-2]SM|M1/4SM|1/4SM|1/2SM|3/4SM|1SM|2SM)\b',
      );
      if (lowVisRegex.hasMatch(upperTaf)) {
        // Double-check that it's not 10SM, 20SM etc.
        if (!RegExp(r'\b(10SM|[1-9][0-9]SM)\b').hasMatch(upperTaf)) {
          hasDangerous = true;
        }
      }

      // Check for low cloud ceiling forecasts
      RegExp lowCeilingRegex = RegExp(r'\b(BKN|OVC)(00[0-9]|0[0-9][0-9])\b');
      if (lowCeilingRegex.hasMatch(upperTaf)) hasDangerous = true;

      // Check for strong wind forecasts
      RegExp strongWindRegex = RegExp(
        r'\b(\d{3}[2-9][0-9]KT|\d{3}\d{2}G[2-9][0-9]KT|\d{3}\d{2}G\d{3}KT)\b',
      );
      if (strongWindRegex.hasMatch(upperTaf)) hasDangerous = true;

      // Check for variable strong winds
      RegExp variableStrongWindRegex = RegExp(r'\bVRB[2-9][0-9]KT\b');
      if (variableStrongWindRegex.hasMatch(upperTaf)) hasDangerous = true;

      // Check for probability of dangerous conditions
      RegExp probDangerousRegex = RegExp(r'PROB[3-9][0-9]');
      if (probDangerousRegex.hasMatch(upperTaf)) {
        // Check if the probability section contains dangerous weather
        String probSection = upperTaf.substring(upperTaf.indexOf('PROB'));
        if (dangerousPatterns.any((pattern) => probSection.contains(pattern))) {
          hasDangerous = true;
        }
      }
    }

    return hasDangerous;
  }

  /// Gets list of dangerous weather conditions detected in METAR
  List<String> getDangerousWeatherInMetar(String metar) {
    if (metar.isEmpty) return [];

    List<String> dangerousConditions = [];
    String upperMetar = metar.toUpperCase();

    // Check for specific dangerous conditions with detailed warnings
    if (upperMetar.contains('TS')) {
      dangerousConditions.add(
        '⚡ Thunderstorms present - AVOID all flight operations',
      );
    }
    if (upperMetar.contains('TSRA')) {
      dangerousConditions.add(
        '⛈️ Thunderstorms with rain - Severe turbulence and wind shear likely',
      );
    }
    if (upperMetar.contains('TSGR')) {
      dangerousConditions.add(
        '🧊 Thunderstorms with hail - EXTREME DANGER to aircraft',
      );
    }
    if (upperMetar.contains('SQ')) {
      dangerousConditions.add(
        '💨 Squalls present - Sudden violent wind changes possible',
      );
    }
    if (upperMetar.contains('FC') || upperMetar.contains('+FC')) {
      dangerousConditions.add(
        '🌪️ Funnel cloud/tornado - EXTREME DANGER - DO NOT FLY',
      );
    }
    if (upperMetar.contains('SS') || upperMetar.contains('DS')) {
      dangerousConditions.add(
        '🌪️ Sandstorm/duststorm - Zero visibility conditions',
      );
    }
    if (upperMetar.contains('GR') || upperMetar.contains('GS')) {
      dangerousConditions.add('🧊 Hail present - Aircraft damage risk');
    }
    if (RegExp(r'\+[A-Z]{2}').hasMatch(upperMetar)) {
      dangerousConditions.add(
        '🌧️ Heavy precipitation - Severe visibility reduction and turbulence',
      );
    }
    if (upperMetar.contains('FZ')) {
      dangerousConditions.add('🧊 Freezing conditions - SEVERE ICING HAZARD');
    }
    if (upperMetar.contains('FZRA')) {
      dangerousConditions.add(
        '🧊 Freezing rain - Severe icing, structural ice accumulation',
      );
    }

    // Low visibility warnings - be more precise
    RegExp lowVisRegex = RegExp(
      r'\b([0-2]SM|M1/4SM|1/4SM|1/2SM|3/4SM|1SM|2SM)\b',
    );
    if (lowVisRegex.hasMatch(upperMetar)) {
      // Double-check that it's not 10SM, 20SM etc.
      if (!RegExp(r'\b(10SM|[1-9][0-9]SM)\b').hasMatch(upperMetar)) {
        dangerousConditions.add(
          '👁️ Low visibility (≤3SM) - VFR flight NOT RECOMMENDED',
        );
      }
    }

    // Low ceiling warnings
    RegExp lowCeilingRegex = RegExp(r'\b(BKN|OVC)(00[0-9]|0[0-9][0-9])\b');
    if (lowCeilingRegex.hasMatch(upperMetar)) {
      dangerousConditions.add(
        '☁️ Low cloud ceiling (<1000ft) - VFR flight NOT RECOMMENDED',
      );
    }

    // Strong wind warnings
    RegExp strongWindRegex = RegExp(
      r'\b(\d{3}[2-9][0-9]KT|\d{3}\d{2}G[2-9][0-9]KT|\d{3}\d{2}G\d{3}KT)\b',
    );
    if (strongWindRegex.hasMatch(upperMetar)) {
      dangerousConditions.add(
        '💨 Strong winds (>20kt) or gusts (>25kt) - Turbulence and crosswind hazards',
      );
    }

    if (upperMetar.contains('WS')) {
      dangerousConditions.add(
        '⚠️ Wind shear reported - Dangerous for takeoff and landing',
      );
    }

    if (upperMetar.contains('BLSN') ||
        upperMetar.contains('BLDU') ||
        upperMetar.contains('BLSA')) {
      dangerousConditions.add(
        '🌪️ Blowing snow/dust/sand - Severe visibility reduction',
      );
    }

    if (upperMetar.contains('UP')) {
      dangerousConditions.add(
        '❓ Unknown precipitation - Unpredictable and potentially dangerous conditions',
      );
    }

    return dangerousConditions;
  }

  /// Gets list of dangerous weather conditions forecasted in TAF
  List<String> getDangerousWeatherInTaf(String taf) {
    if (taf.isEmpty) return [];

    List<String> dangerousConditions = [];
    String upperTaf = taf.toUpperCase();

    // Check for specific dangerous conditions in forecast with detailed warnings
    if (upperTaf.contains('TS')) {
      dangerousConditions.add(
        '⚡ Thunderstorms forecasted - AVOID flight operations during this period',
      );
    }
    if (upperTaf.contains('TSRA')) {
      dangerousConditions.add(
        '⛈️ Thunderstorms with rain forecasted - Expect severe turbulence and wind shear',
      );
    }
    if (upperTaf.contains('TSGR')) {
      dangerousConditions.add(
        '🧊 Thunderstorms with hail forecasted - EXTREME DANGER to aircraft',
      );
    }
    if (upperTaf.contains('SQ')) {
      dangerousConditions.add(
        '💨 Squalls forecasted - Expect sudden violent wind changes',
      );
    }
    if (upperTaf.contains('FC') || upperTaf.contains('+FC')) {
      dangerousConditions.add(
        '🌪️ Funnel cloud/tornado forecasted - EXTREME DANGER - Plan alternate route',
      );
    }
    if (upperTaf.contains('SS') || upperTaf.contains('DS')) {
      dangerousConditions.add(
        '🌪️ Sandstorm/duststorm forecasted - Zero visibility expected',
      );
    }
    if (upperTaf.contains('GR') || upperTaf.contains('GS')) {
      dangerousConditions.add('🧊 Hail forecasted - Aircraft damage risk');
    }
    if (RegExp(r'\+[A-Z]{2}').hasMatch(upperTaf)) {
      dangerousConditions.add(
        '🌧️ Heavy precipitation forecasted - Expect severe visibility reduction',
      );
    }
    if (upperTaf.contains('FZ')) {
      dangerousConditions.add(
        '🧊 Freezing conditions forecasted - SEVERE ICING HAZARD expected',
      );
    }
    if (upperTaf.contains('FZRA')) {
      dangerousConditions.add(
        '🧊 Freezing rain forecasted - Severe icing, structural ice accumulation expected',
      );
    }

    // Low visibility forecasts - be more precise
    RegExp lowVisRegex = RegExp(
      r'\b([0-2]SM|M1/4SM|1/4SM|1/2SM|3/4SM|1SM|2SM)\b',
    );
    if (lowVisRegex.hasMatch(upperTaf)) {
      // Double-check that it's not 10SM, 20SM etc.
      if (!RegExp(r'\b(10SM|[1-9][0-9]SM)\b').hasMatch(upperTaf)) {
        dangerousConditions.add(
          '👁️ Low visibility forecasted (≤3SM) - VFR flight NOT RECOMMENDED',
        );
      }
    }

    // Low ceiling forecasts
    RegExp lowCeilingRegex = RegExp(r'\b(BKN|OVC)(00[0-9]|0[0-9][0-9])\b');
    if (lowCeilingRegex.hasMatch(upperTaf)) {
      dangerousConditions.add(
        '☁️ Low cloud ceiling forecasted (<1000ft) - VFR flight NOT RECOMMENDED',
      );
    }

    // Strong wind forecasts
    RegExp strongWindRegex = RegExp(
      r'\b(\d{3}[2-9][0-9]KT|\d{3}\d{2}G[2-9][0-9]KT|\d{3}\d{2}G\d{3}KT)\b',
    );
    if (strongWindRegex.hasMatch(upperTaf)) {
      dangerousConditions.add(
        '💨 Strong winds forecasted (>20kt) or gusts (>25kt) - Expect turbulence',
      );
    }

    if (upperTaf.contains('WS')) {
      dangerousConditions.add(
        '⚠️ Wind shear forecasted - Dangerous for takeoff and landing',
      );
    }

    if (upperTaf.contains('BLSN') ||
        upperTaf.contains('BLDU') ||
        upperTaf.contains('BLSA')) {
      dangerousConditions.add(
        '🌪️ Blowing snow/dust/sand forecasted - Severe visibility reduction expected',
      );
    }

    if (upperTaf.contains('UP')) {
      dangerousConditions.add(
        '❓ Unknown precipitation forecasted - Unpredictable conditions expected',
      );
    }

    // Check for probability of dangerous conditions
    RegExp probRegex = RegExp(r'PROB[3-9][0-9]');
    if (probRegex.hasMatch(upperTaf)) {
      dangerousConditions.add(
        '📊 High probability of adverse weather conditions - Monitor closely',
      );
    }

    return dangerousConditions;
  }
}
