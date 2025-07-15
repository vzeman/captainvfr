import 'package:latlong2/latlong.dart';
import 'package:flutter_map/flutter_map.dart';

/// Serializable spatial index data that can be pre-computed and bundled
class SerializableSpatialIndex {
  /// Grid size in degrees (~11km at equator)
  static const double gridSize = 0.1;
  
  /// Grid-based index: cell key -> list of item IDs
  final Map<String, List<String>> gridIndex;
  
  /// Bounding boxes for each item: item ID -> [minLat, minLon, maxLat, maxLon]
  final Map<String, List<double>> boundingBoxes;
  
  /// Additional metadata for items (e.g., type, altitude limits)
  final Map<String, Map<String, dynamic>> metadata;
  
  SerializableSpatialIndex({
    required this.gridIndex,
    required this.boundingBoxes,
    required this.metadata,
  });
  
  /// Create from JSON
  factory SerializableSpatialIndex.fromJson(Map<String, dynamic> json) {
    return SerializableSpatialIndex(
      gridIndex: (json['gridIndex'] as Map<String, dynamic>).map(
        (key, value) => MapEntry(key, List<String>.from(value)),
      ),
      boundingBoxes: (json['boundingBoxes'] as Map<String, dynamic>).map(
        (key, value) => MapEntry(key, List<double>.from(value)),
      ),
      metadata: (json['metadata'] as Map<String, dynamic>).map(
        (key, value) => MapEntry(key, Map<String, dynamic>.from(value)),
      ),
    );
  }
  
  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'version': 1,
      'gridSize': gridSize,
      'gridIndex': gridIndex,
      'boundingBoxes': boundingBoxes,
      'metadata': metadata,
    };
  }
  
  /// Get all item IDs in the given bounds
  Set<String> queryBounds(LatLngBounds bounds) {
    final results = <String>{};
    final cells = _getCellsForBounds(bounds);
    
    for (final cell in cells) {
      final itemIds = gridIndex[cell];
      if (itemIds != null) {
        // Filter by actual bounding box intersection
        for (final id in itemIds) {
          final bbox = boundingBoxes[id];
          if (bbox != null && _boundsIntersect(bounds, bbox)) {
            results.add(id);
          }
        }
      }
    }
    
    return results;
  }
  
  /// Get all item IDs at the given point
  List<String> queryPoint(LatLng point) {
    final cell = _getCellForPoint(point);
    final candidates = gridIndex[cell] ?? [];
    
    // Filter by actual bounding box containment
    return candidates.where((id) {
      final bbox = boundingBoxes[id];
      if (bbox == null) return false;
      
      return point.latitude >= bbox[0] && 
             point.latitude <= bbox[2] &&
             point.longitude >= bbox[1] && 
             point.longitude <= bbox[3];
    }).toList();
  }
  
  List<String> _getCellsForBounds(LatLngBounds bounds) {
    final cells = <String>[];
    
    final startLat = (bounds.southWest.latitude / gridSize).floor();
    final endLat = (bounds.northEast.latitude / gridSize).ceil();
    final startLng = (bounds.southWest.longitude / gridSize).floor();
    final endLng = (bounds.northEast.longitude / gridSize).ceil();
    
    for (int lat = startLat; lat <= endLat; lat++) {
      for (int lng = startLng; lng <= endLng; lng++) {
        cells.add('${lat}_$lng');
      }
    }
    
    return cells;
  }
  
  String _getCellForPoint(LatLng point) {
    final lat = (point.latitude / gridSize).floor();
    final lng = (point.longitude / gridSize).floor();
    return '${lat}_$lng';
  }
  
  bool _boundsIntersect(LatLngBounds bounds, List<double> bbox) {
    return !(bbox[2] < bounds.southWest.latitude ||
             bbox[0] > bounds.northEast.latitude ||
             bbox[3] < bounds.southWest.longitude ||
             bbox[1] > bounds.northEast.longitude);
  }
}

/// Builder for creating serializable spatial indexes
class SpatialIndexBuilder {
  final Map<String, List<String>> _gridIndex = {};
  final Map<String, List<double>> _boundingBoxes = {};
  final Map<String, Map<String, dynamic>> _metadata = {};
  
  /// Add an item to the index
  void addItem({
    required String id,
    required List<double> boundingBox, // [minLat, minLon, maxLat, maxLon]
    Map<String, dynamic>? metadata,
  }) {
    _boundingBoxes[id] = boundingBox;
    if (metadata != null) {
      _metadata[id] = metadata;
    }
    
    // Add to grid cells
    final cells = _getCellsForBoundingBox(boundingBox);
    for (final cell in cells) {
      _gridIndex.putIfAbsent(cell, () => []).add(id);
    }
  }
  
  /// Build the final index
  SerializableSpatialIndex build() {
    return SerializableSpatialIndex(
      gridIndex: _gridIndex,
      boundingBoxes: _boundingBoxes,
      metadata: _metadata,
    );
  }
  
  List<String> _getCellsForBoundingBox(List<double> bbox) {
    final cells = <String>[];
    
    final startLat = (bbox[0] / SerializableSpatialIndex.gridSize).floor();
    final endLat = (bbox[2] / SerializableSpatialIndex.gridSize).ceil();
    final startLng = (bbox[1] / SerializableSpatialIndex.gridSize).floor();
    final endLng = (bbox[3] / SerializableSpatialIndex.gridSize).ceil();
    
    for (int lat = startLat; lat <= endLat; lat++) {
      for (int lng = startLng; lng <= endLng; lng++) {
        cells.add('${lat}_$lng');
      }
    }
    
    return cells;
  }
}