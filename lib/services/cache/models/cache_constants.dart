/// Constants used throughout the cache service
class CacheConstants {
  // Box names
  static const String airportsBoxName = 'airports_cache';
  static const String navaidsBoxName = 'navaids_cache';
  static const String runwaysBoxName = 'runways_cache';
  static const String frequenciesBoxName = 'frequencies_cache';
  static const String airspacesBoxName = 'airspaces_cache';
  static const String reportingPointsBoxName = 'reporting_points_cache';
  static const String metadataBoxName = 'cache_metadata';
  static const String weatherBoxName = 'weather_cache';

  // Metadata keys
  static const String airportsLastFetchKey = 'airports_last_fetch';
  static const String navaidsLastFetchKey = 'navaids_last_fetch';
  static const String runwaysLastFetchKey = 'runways_last_fetch';
  static const String frequenciesLastFetchKey = 'frequencies_last_fetch';
  static const String airspacesLastFetchKey = 'airspaces_last_fetch';
  static const String reportingPointsLastFetchKey = 'reporting_points_last_fetch';
  static const String weatherLastFetchKey = 'weather_last_fetch';

  // Weather cache key prefixes
  static const String metarPrefix = 'metar_';
  static const String tafPrefix = 'taf_';
}