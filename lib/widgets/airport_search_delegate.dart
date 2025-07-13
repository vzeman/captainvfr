import 'package:flutter/material.dart';
import '../models/airport.dart';
import '../services/airport_service.dart';

class AirportSearchDelegate extends SearchDelegate<Airport?> {
  final AirportService airportService;
  final Function(Airport) onAirportSelected;

  AirportSearchDelegate({
    required this.airportService,
    required this.onAirportSelected,
  });

  @override
  String get searchFieldLabel => 'Search airports (name or code)';

  @override
  List<Widget> buildActions(BuildContext context) {
    return [
      IconButton(
        icon: const Icon(Icons.clear),
        onPressed: () {
          query = '';
        },
      ),
    ];
  }

  @override
  Widget buildLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back),
      onPressed: () {
        close(context, null);
      },
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    return _buildSearchResults();
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    return _buildSearchResults();
  }

  Widget _buildSearchResults() {
    if (query.isEmpty) {
      return const Center(
        child: Text(
          'Search for airports by name or code\n(e.g., "KJFK", "Kennedy", "London")',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 16, color: Colors.grey),
        ),
      );
    }

    final searchResults = airportService.searchAirports(query);

    if (searchResults.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.search_off, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            Text(
              'No airports found for "$query"',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Try searching by:\n• Airport name (e.g., "Kennedy")\n• ICAO code (e.g., "KJFK")\n• IATA code (e.g., "JFK")\n• City name (e.g., "New York")',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: searchResults.length,
      itemBuilder: (context, index) {
        final airport = searchResults[index];
        return _buildAirportTile(context, airport);
      },
    );
  }

  Widget _buildAirportTile(BuildContext context, Airport airport) {
    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          Icons.flight_takeoff,
          color: Theme.of(context).primaryColor,
        ),
      ),
      title: Text(
        airport.name,
        style: const TextStyle(fontWeight: FontWeight.bold),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${airport.icao}${airport.iata != null && airport.iata!.isNotEmpty ? ' • ${airport.iata}' : ''}',
            style: TextStyle(
              color: Theme.of(context).primaryColor,
              fontWeight: FontWeight.w500,
            ),
          ),
          if (airport.municipality != null && airport.municipality!.isNotEmpty)
            Text(
              '${airport.municipality}, ${airport.country}',
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
            ),
        ],
      ),
      trailing: Icon(Icons.location_on, color: Colors.grey[400]),
      onTap: () {
        onAirportSelected(airport);
        close(context, airport);
      },
    );
  }
}
