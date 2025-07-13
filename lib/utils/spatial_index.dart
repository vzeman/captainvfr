import 'package:latlong2/latlong.dart';
import 'package:flutter_map/flutter_map.dart';
import '../models/airspace.dart';

/// Interface for objects that can be spatially indexed
abstract class SpatialIndexable {
  LatLngBounds? get boundingBox;
  bool containsPoint(LatLng point);
}

/// A spatial index using simplified approach for efficient spatial queries
/// This dramatically improves performance when searching for objects in a geographic area
class SpatialIndex {
  final List<SpatialIndexable> _items = [];
  
  /// Insert an item into the spatial index
  void insert(SpatialIndexable item) {
    if (item.boundingBox == null) return;
    _items.add(item);
  }

  /// Search for items within the given bounding box
  List<SpatialIndexable> search(LatLngBounds bounds) {
    return _items.where((item) {
      final itemBounds = item.boundingBox;
      if (itemBounds == null) return false;
      
      // Check if bounding boxes intersect
      return !(itemBounds.northEast.latitude < bounds.southWest.latitude ||
               itemBounds.southWest.latitude > bounds.northEast.latitude ||
               itemBounds.northEast.longitude < bounds.southWest.longitude ||
               itemBounds.southWest.longitude > bounds.northEast.longitude);
    }).toList();
  }

  /// Search for items that contain the given point
  List<SpatialIndexable> searchPoint(LatLng point) {
    return _items.where((item) => 
        item.containsPoint(point)).toList();
  }

  /// Clear the index
  void clear() {
    _items.clear();
  }

  /// Get the number of indexed items
  int get size => _items.length;

  /// Build index from a list of airspaces
  void buildFromAirspaces(List<Airspace> airspaces) {
    clear();
    
    for (final airspace in airspaces) {
      insert(airspace);
        }
  }
}

/// Grid-based spatial index for fast point queries
class GridSpatialIndex {
  static const double _gridSize = 0.1; // ~11km at equator
  
  final Map<String, List<SpatialIndexable>> _grid = {};
  
  void insert(SpatialIndexable item) {
    final bounds = item.boundingBox;
    if (bounds == null) return;
    
    final cells = _getCellsForBounds(bounds);
    for (final cell in cells) {
      _grid.putIfAbsent(cell, () => []).add(item);
    }
  }

  List<SpatialIndexable> search(LatLngBounds bounds) {
    final results = <SpatialIndexable>{};
    final cells = _getCellsForBounds(bounds);
    
    for (final cell in cells) {
      final items = _grid[cell];
      if (items != null) {
        results.addAll(items);
      }
    }
    
    return results.toList();
  }

  List<SpatialIndexable> searchPoint(LatLng point) {
    final cell = _getCellForPoint(point);
    final candidates = _grid[cell] ?? [];
    
    return candidates.where((item) => 
        item.containsPoint(point)).toList();
  }

  void clear() {
    _grid.clear();
  }

  void buildFromAirspaces(List<Airspace> airspaces) {
    clear();
    for (final airspace in airspaces) {
      insert(airspace);
        }
  }

  List<String> _getCellsForBounds(LatLngBounds bounds) {
    final cells = <String>[];
    
    final startLat = (bounds.southWest.latitude / _gridSize).floor();
    final endLat = (bounds.northEast.latitude / _gridSize).ceil();
    final startLng = (bounds.southWest.longitude / _gridSize).floor();
    final endLng = (bounds.northEast.longitude / _gridSize).ceil();
    
    for (int lat = startLat; lat <= endLat; lat++) {
      for (int lng = startLng; lng <= endLng; lng++) {
        cells.add('${lat}_$lng');
      }
    }
    
    return cells;
  }

  String _getCellForPoint(LatLng point) {
    final lat = (point.latitude / _gridSize).floor();
    final lng = (point.longitude / _gridSize).floor();
    return '${lat}_$lng';
  }
}

/// Multi-level spatial index combining bounding box filtering and grid for optimal performance
class HybridSpatialIndex {
  final SpatialIndex _spatialIndex = SpatialIndex();
  final GridSpatialIndex _grid = GridSpatialIndex();
  
  void buildFromAirspaces(List<Airspace> airspaces) {
    _spatialIndex.buildFromAirspaces(airspaces);
    _grid.buildFromAirspaces(airspaces);
  }

  void insert(SpatialIndexable item) {
    _spatialIndex.insert(item);
    _grid.insert(item);
  }

  /// Use grid for point queries (faster)
  List<SpatialIndexable> searchPoint(LatLng point) {
    return _grid.searchPoint(point);
  }

  /// Use spatial index for area queries
  List<SpatialIndexable> search(LatLngBounds bounds) {
    return _spatialIndex.search(bounds);
  }

  void clear() {
    _spatialIndex.clear();
    _grid.clear();
  }

  int get size => _spatialIndex.size;
}