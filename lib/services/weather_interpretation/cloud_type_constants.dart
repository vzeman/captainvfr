/// Cloud type constants for METAR/TAF interpretation
class CloudTypeConstants {
  static const Map<String, String> cloudTypes = {
    'SKC': 'Sky clear',
    'CLR': 'Clear',
    'FEW': 'Few clouds (1-2 oktas)',
    'SCT': 'Scattered clouds (3-4 oktas)',
    'BKN': 'Broken clouds (5-7 oktas)',
    'OVC': 'Overcast (8 oktas)',
    'VV': 'Vertical visibility',
    'CB': 'Cumulonimbus',
    'TCU': 'Towering cumulus',
    'CI': 'Cirrus',
    'CC': 'Cirrocumulus',
    'CS': 'Cirrostratus',
    'AC': 'Altocumulus',
    'AS': 'Altostratus',
    'NS': 'Nimbostratus',
    'SC': 'Stratocumulus',
    'ST': 'Stratus',
    'CU': 'Cumulus',
  };
}
