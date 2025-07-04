import 'package:latlong2/latlong.dart';
import 'package:hive/hive.dart';

part 'flight_plan.g.dart';

@HiveType(typeId: 10)
class FlightPlan extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String name;

  @HiveField(2)
  DateTime createdAt;

  @HiveField(3)
  DateTime? modifiedAt;

  @HiveField(4)
  List<Waypoint> waypoints;

  @HiveField(5)
  String? aircraftId; // Reference to selected aircraft

  @HiveField(6)
  double? cruiseSpeed; // Knots - from aircraft or manual input

  @HiveField(7)
  FlightRules? flightRules;

  @HiveField(8)
  double? fuelConsumptionRate; // Gallons per hour - from aircraft or manual input

  FlightPlan({
    required this.id,
    required this.name,
    required this.createdAt,
    this.modifiedAt,
    required this.waypoints,
    this.aircraftId,
    this.cruiseSpeed,
    this.flightRules,
    this.fuelConsumptionRate,
  });

  // Calculate total distance in nautical miles
  double get totalDistance {
    if (waypoints.length < 2) return 0.0;

    double total = 0.0;
    for (int i = 0; i < waypoints.length - 1; i++) {
      total += waypoints[i].distanceTo(waypoints[i + 1]);
    }
    return total;
  }

  // Calculate total estimated flight time in minutes
  double get totalFlightTime {
    if (cruiseSpeed == null || cruiseSpeed! <= 0) return 0.0;
    return (totalDistance / cruiseSpeed!) * 60; // Convert hours to minutes
  }

  // Get flight segments with calculations
  List<FlightSegment> get segments {
    if (waypoints.length < 2) return [];

    List<FlightSegment> segments = [];
    for (int i = 0; i < waypoints.length - 1; i++) {
      segments.add(FlightSegment(
        from: waypoints[i],
        to: waypoints[i + 1],
        cruiseSpeed: cruiseSpeed,
        fuelConsumptionRate: fuelConsumptionRate,
      ));
    }
    return segments;
  }

  // Calculate total fuel consumption in gallons
  double get totalFuelConsumption {
    if (fuelConsumptionRate == null || fuelConsumptionRate! <= 0) return 0.0;
    return (totalFlightTime / 60) * fuelConsumptionRate!; // Convert minutes to hours
  }
}

@HiveType(typeId: 11)
class Waypoint extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  double latitude;

  @HiveField(2)
  double longitude;

  @HiveField(3)
  double altitude; // Feet MSL

  @HiveField(4)
  String? name;

  @HiveField(5)
  String? notes;

  @HiveField(6)
  WaypointType type;

  Waypoint({
    required this.id,
    required this.latitude,
    required this.longitude,
    required this.altitude,
    this.name,
    this.notes,
    this.type = WaypointType.user,
  });

  LatLng get latLng => LatLng(latitude, longitude);

  // Calculate distance to another waypoint in nautical miles
  double distanceTo(Waypoint other) {
    const Distance distance = Distance();
    return distance.as(LengthUnit.Meter, latLng, other.latLng) * 0.000539957; // Convert meters to nautical miles
  }

  // Calculate bearing to another waypoint in degrees
  double bearingTo(Waypoint other) {
    const Distance distance = Distance();
    return distance.bearing(latLng, other.latLng);
  }
}

@HiveType(typeId: 12)
enum WaypointType {
  @HiveField(0)
  user,
  @HiveField(1)
  airport,
  @HiveField(2)
  navaid,
  @HiveField(3)
  fix,
}

@HiveType(typeId: 13)
enum FlightRules {
  @HiveField(0)
  vfr,
  @HiveField(1)
  ifr,
}

class FlightSegment {
  final Waypoint from;
  final Waypoint to;
  final double? cruiseSpeed;
  final double? fuelConsumptionRate;

  FlightSegment({
    required this.from,
    required this.to,
    this.cruiseSpeed,
    this.fuelConsumptionRate,
  });

  double get distance => from.distanceTo(to);
  double get bearing => from.bearingTo(to);

  // Flight time in minutes
  double get flightTime {
    if (cruiseSpeed == null || cruiseSpeed! <= 0) return 0.0;
    return (distance / cruiseSpeed!) * 60;
  }

  // Altitude change
  double get altitudeChange => to.altitude - from.altitude;

  // Fuel consumption in gallons for this segment
  double get fuelConsumption {
    if (fuelConsumptionRate == null || fuelConsumptionRate! <= 0) return 0.0;
    return (flightTime / 60) * fuelConsumptionRate!; // Convert minutes to hours
  }
}
