/// Weather phenomena constants for METAR/TAF interpretation
class WeatherPhenomena {
  static const Map<String, String> intensities = {
    '+': 'Heavy',
    '-': 'Light',
    'VC': 'In the vicinity',
    'RE': 'Recent',
    'B': 'Began',
    'E': 'Ended',
  };

  static const Map<String, String> descriptors = {
    'MI': 'Shallow',
    'PR': 'Partial',
    'BC': 'Patches',
    'DR': 'Low drifting',
    'BL': 'Blowing',
    'SH': 'Showers',
    'TS': 'Thunderstorm',
    'FZ': 'Freezing',
  };

  static const Map<String, String> phenomena = {
    // Precipitation types
    'RA': 'rain',
    'SN': 'snow',
    'DZ': 'drizzle',
    'SG': 'snow grains',
    'IC': 'ice crystals',
    'PL': 'ice pellets',
    'GR': 'hail (>5mm)',
    'GS': 'small hail/snow pellets (<5mm)',
    'UP': 'unknown precipitation',

    // Obstruction to vision
    'FG': 'fog',
    'BR': 'mist (>=5/8)',
    'HZ': 'haze',
    'FU': 'smoke',
    'VA': 'volcanic ash',
    'DU': 'dust',
    'SA': 'sand',
    'PY': 'spray',

    // Other phenomena
    'SQ': 'squalls',
    'FC': 'funnel cloud',
    '+FC': 'well-developed funnel cloud/tornado/waterspout',
    'SS': 'sandstorm',
    'DS': 'dust storm',
    'PO': 'well-developed dust/sand whirls',
  };
}
