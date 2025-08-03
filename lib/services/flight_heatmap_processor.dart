import 'dart:math' as math;
import 'package:latlong2/latlong.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:hive/hive.dart';
import '../models/flight.dart';
import '../models/heatmap_cell.dart';
import '../utils/frame_aware_scheduler.dart';

class FlightHeatmapProcessor {
  static const String _heatmapBoxName = 'flight_heatmap';
  static Box<HeatmapCell>? _heatmapBox;
  static final FrameAwareScheduler _scheduler = FrameAwareScheduler();
  
  static const Map<int, double> _gridSizes = {
    4: 2.0,    // ~222km cells for continent view
    5: 1.0,    // ~111km cells for country view  
    6: 0.5,    // ~55km cells for regional view
    7: 0.25,   // ~28km cells for state view
    8: 0.125,  // ~14km cells for metropolitan view
    9: 0.1,    // ~11km cells (existing grid size)
    10: 0.05,  // ~5.5km cells for city view
    11: 0.025, // ~2.8km cells for detailed view
    12: 0.0125 // ~1.4km cells for very detailed view
  };
  
  static const Map<int, int> _maxCellsPerZoom = {
    4: 200,   // Continental view
    5: 250,   // Country view
    6: 300,   // Regional view
    7: 400,   // State view
    8: 500,   // Metropolitan view
    9: 600,   // City view
    10: 700,  // City view
    11: 800,  // Detailed view
    12: 1000, // Very detailed view
  };

  static Future<void> init() async {
    if (_heatmapBox?.isOpen != true) {
      _heatmapBox = await Hive.openBox<HeatmapCell>(_heatmapBoxName);
    }
  }

  static Future<void> processFlightUpdate(Flight flight, {bool isRemoval = false}) async {
    await init();
    
    print('Heatmap: Processing flight ${flight.id} with ${flight.path.length} points (removal: $isRemoval)');
    
    _scheduler.scheduleOperation(
      id: 'heatmap_update_${flight.id}',
      operation: () => _updateHeatmapCells(flight, isRemoval),
      debounce: const Duration(milliseconds: 500),
      highPriority: false,
    );
  }

  static void _updateHeatmapCells(Flight flight, bool isRemoval) {
    if (flight.path.isEmpty) return;

    int totalCellsUpdated = 0;
    for (final entry in _gridSizes.entries) {
      final zoomLevel = entry.key;
      final gridSize = entry.value;
      
      final affectedCells = _getCellsForFlight(flight, gridSize);
      
      for (final cellId in affectedCells) {
        _updateCellData(cellId, zoomLevel, gridSize, flight, isRemoval);
        totalCellsUpdated++;
      }
    }
    print('Heatmap: Updated $totalCellsUpdated cells across all zoom levels');
  }

  static Set<String> _getCellsForFlight(Flight flight, double gridSize) {
    final cells = <String>{};
    
    for (final point in flight.path) {
      final cellId = _getCellId(point.latitude, point.longitude, gridSize);
      cells.add(cellId);
    }
    
    return cells;
  }

  static String _getCellId(double lat, double lng, double gridSize) {
    final cellLat = (lat / gridSize).floor() * gridSize;
    final cellLng = (lng / gridSize).floor() * gridSize;
    return '${cellLat.toStringAsFixed(6)}_${cellLng.toStringAsFixed(6)}';
  }

  static void _updateCellData(String cellId, int zoomLevel, double gridSize, Flight flight, bool isRemoval) {
    final key = '${zoomLevel}_$cellId';
    final existingCell = _heatmapBox!.get(key);
    
    if (existingCell != null) {
      final newCount = isRemoval 
          ? math.max(0, existingCell.flightCount - 1)
          : existingCell.flightCount + 1;
      
      final updatedFlightIds = List<String>.from(existingCell.flightIds ?? []);
      if (isRemoval) {
        updatedFlightIds.remove(flight.id);
      } else if (!updatedFlightIds.contains(flight.id)) {
        updatedFlightIds.add(flight.id);
      }
      
      final updatedCell = existingCell.copyWith(
        flightCount: newCount,
        intensity: _calculateIntensity(newCount),
        lastUpdate: DateTime.now(),
        flightIds: updatedFlightIds,
      );
      
      if (newCount > 0) {
        _heatmapBox!.put(key, updatedCell);
      } else {
        _heatmapBox!.delete(key);
      }
    } else if (!isRemoval) {
      final parts = cellId.split('_');
      final cellLat = double.parse(parts[0]) + (gridSize / 2);
      final cellLng = double.parse(parts[1]) + (gridSize / 2);
      
      final newCell = HeatmapCell(
        cellId: cellId,
        flightCount: 1,
        intensity: _calculateIntensity(1),
        zoomLevel: zoomLevel,
        centerLat: cellLat,
        centerLng: cellLng,
        cellSize: gridSize,
        lastUpdate: DateTime.now(),
        flightIds: [flight.id],
      );
      
      _heatmapBox!.put(key, newCell);
    }
  }

  static double _calculateIntensity(int flightCount) {
    return math.min(1.0, flightCount / 10.0);
  }

  static Future<List<HeatmapCell>> getHeatmapCells(
    int zoomLevel,
    LatLngBounds viewport,
  ) async {
    await init();
    
    final gridSize = _gridSizes[zoomLevel] ?? 0.1;
    final maxCells = _maxCellsPerZoom[zoomLevel] ?? 600;
    
    final expandedViewport = _expandBounds(viewport, 0.2);
    final cellIds = _getCellsForBounds(expandedViewport, gridSize);
    final cells = <HeatmapCell>[];
    
    for (final cellId in cellIds) {
      final key = '${zoomLevel}_$cellId';
      final cell = _heatmapBox!.get(key);
      if (cell != null) {
        cells.add(cell);
      }
      
      if (cells.length >= maxCells) break;
    }
    
    cells.sort((a, b) => b.intensity.compareTo(a.intensity));
    
    return cells;
  }

  static Set<String> _getCellsForBounds(LatLngBounds bounds, double gridSize) {
    final cells = <String>{};
    
    final minLat = (bounds.south / gridSize).floor() * gridSize;
    final maxLat = (bounds.north / gridSize).ceil() * gridSize;
    final minLng = (bounds.west / gridSize).floor() * gridSize;
    final maxLng = (bounds.east / gridSize).ceil() * gridSize;
    
    for (double lat = minLat; lat <= maxLat; lat += gridSize) {
      for (double lng = minLng; lng <= maxLng; lng += gridSize) {
        final cellId = _getCellId(lat, lng, gridSize);
        cells.add(cellId);
      }
    }
    
    return cells;
  }

  static LatLngBounds _expandBounds(LatLngBounds bounds, double factor) {
    final latRange = bounds.north - bounds.south;
    final lngRange = bounds.east - bounds.west;
    
    final latExpansion = latRange * factor / 2;
    final lngExpansion = lngRange * factor / 2;
    
    return LatLngBounds(
      LatLng(bounds.south - latExpansion, bounds.west - lngExpansion),
      LatLng(bounds.north + latExpansion, bounds.east + lngExpansion),
    );
  }

  static int selectOptimalZoomLevel(double currentZoom) {
    if (currentZoom < 5) return 4;
    if (currentZoom < 6.5) return 5;
    if (currentZoom < 7.5) return 6;
    if (currentZoom < 8.5) return 7;
    if (currentZoom < 9.5) return 8;
    if (currentZoom < 10.5) return 9;
    if (currentZoom < 11.5) return 10;
    if (currentZoom < 12.5) return 11;
    return 12;
  }

  static Future<void> rebuildHeatmapFromAllFlights(List<Flight> flights) async {
    await init();
    
    await _heatmapBox!.clear();
    
    for (final flight in flights) {
      _updateHeatmapCells(flight, false);
    }
  }
}