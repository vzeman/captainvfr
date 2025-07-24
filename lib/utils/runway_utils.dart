/// Utility functions for runway operations
class RunwayUtils {
  // Pre-compiled regex for better performance
  static final _runwayNumberRegex = RegExp(r'^(\d{1,2})');
  
  /// Extract runway number from designator (e.g., "04L" -> 4)
  /// Returns null if no valid number found
  static int? extractRunwayNumber(String designator) {
    if (designator.isEmpty) return null;
    
    // Fast path for common cases
    if (designator.length >= 2) {
      final firstTwo = designator.substring(0, 2);
      final number = int.tryParse(firstTwo);
      if (number != null && number >= 1 && number <= 36) {
        return number;
      }
    }
    
    // Try single digit
    final firstChar = designator[0];
    final singleDigit = int.tryParse(firstChar);
    if (singleDigit != null && singleDigit >= 1 && singleDigit <= 9) {
      return singleDigit;
    }
    
    // Fallback to regex for edge cases
    final match = _runwayNumberRegex.firstMatch(designator);
    if (match != null) {
      return int.tryParse(match.group(1)!);
    }
    
    return null;
  }
  
  /// Convert runway number to magnetic heading
  static double runwayNumberToHeading(int runwayNumber) {
    return runwayNumber * 10.0;
  }
  
  /// Parse runway designator and get magnetic heading
  /// Returns null if designator is invalid
  static double? getHeadingFromDesignator(String designator) {
    final number = extractRunwayNumber(designator);
    return number != null ? runwayNumberToHeading(number) : null;
  }
  
  /// Calculate opposite runway number (e.g., 09 -> 27, 27 -> 09)
  static int calculateOppositeRunway(int runwayNumber) {
    return runwayNumber <= 18 ? runwayNumber + 18 : runwayNumber - 18;
  }
  
  /// Get opposite runway designator preserving suffix (e.g., "09L" -> "27R")
  static String getOppositeDesignator(String designator) {
    final number = extractRunwayNumber(designator);
    if (number == null) return '';
    
    final oppositeNumber = calculateOppositeRunway(number);
    final suffix = designator.replaceAll(RegExp(r'^\d+'), '');
    
    // Swap L/R suffixes for opposite end
    final oppositeSuffix = suffix
        .replaceAll('L', 'TEMP')
        .replaceAll('R', 'L')
        .replaceAll('TEMP', 'R');
    
    return oppositeNumber.toString().padLeft(2, '0') + oppositeSuffix;
  }
}