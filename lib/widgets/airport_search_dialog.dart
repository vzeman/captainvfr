import 'package:flutter/material.dart';
import '../models/airport.dart';
import '../services/airport_service.dart';
import 'keyboard_aware_focus_field.dart';
import '../utils/form_theme_helper.dart';

class AirportSearchDialog extends StatefulWidget {
  final AirportService airportService;
  final Function(Airport) onAirportSelected;

  const AirportSearchDialog({
    super.key,
    required this.airportService,
    required this.onAirportSelected,
  });

  @override
  State<AirportSearchDialog> createState() => _AirportSearchDialogState();
}

class _AirportSearchDialogState extends State<AirportSearchDialog> {
  final _searchController = TextEditingController();
  List<Airport> _searchResults = [];
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    final query = _searchController.text.trim();
    if (query.isEmpty) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
      return;
    }

    setState(() {
      _isSearching = true;
      _searchResults = widget.airportService.searchAirports(query);
      _isSearching = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return FormThemeHelper.buildDialog(
      context: context,
      title: 'Search Airports',
      width: MediaQuery.of(context).size.width * 0.9,
      height: MediaQuery.of(context).size.height * 0.8,
      content: Column(
        children: [
          // Search field
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: KeyboardAwareFocusField(
              controller: _searchController,
              autofocus: true,
              style: FormThemeHelper.inputTextStyle,
              decoration: FormThemeHelper.getInputDecoration(
                'Search airports',
                hintText: 'Enter airport name, ICAO, IATA, or city',
              ).copyWith(
                prefixIcon: Icon(Icons.search, color: FormThemeHelper.secondaryTextColor),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: Icon(Icons.clear, color: FormThemeHelper.secondaryTextColor),
                        onPressed: () {
                          _searchController.clear();
                        },
                      )
                    : null,
              ),
            ),
          ),
          
          // Results
          Expanded(
            child: _buildSearchResults(),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          style: FormThemeHelper.getSecondaryButtonStyle(),
          child: const Text('Cancel'),
        ),
      ],
    );
  }

  Widget _buildSearchResults() {
    if (_searchController.text.isEmpty) {
      return Center(
        child: Text(
          'Search for airports by name or code\n(e.g., "KJFK", "Kennedy", "London")',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 16, color: FormThemeHelper.secondaryTextColor),
        ),
      );
    }

    if (_isSearching) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_searchResults.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off, size: 64, color: FormThemeHelper.secondaryTextColor),
            const SizedBox(height: 16),
            Text(
              'No airports found for "${_searchController.text}"',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: FormThemeHelper.primaryTextColor,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Try searching by:\n• Airport name (e.g., "Kennedy")\n• ICAO code (e.g., "KJFK")\n• IATA code (e.g., "JFK")\n• City name (e.g., "New York")',
              textAlign: TextAlign.center,
              style: TextStyle(color: FormThemeHelper.secondaryTextColor),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: _searchResults.length,
      itemBuilder: (context, index) {
        final airport = _searchResults[index];
        return _buildAirportTile(context, airport);
      },
    );
  }

  Widget _buildAirportTile(BuildContext context, Airport airport) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: FormThemeHelper.sectionBackgroundColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: FormThemeHelper.sectionBorderColor),
      ),
      child: ListTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: FormThemeHelper.primaryAccent.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            Icons.flight_takeoff,
            color: FormThemeHelper.primaryAccent,
          ),
        ),
        title: Text(
          airport.name,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: FormThemeHelper.primaryTextColor,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${airport.icao}${airport.iata != null && airport.iata!.isNotEmpty ? ' • ${airport.iata}' : ''}',
              style: TextStyle(
                color: FormThemeHelper.primaryAccent,
                fontWeight: FontWeight.w500,
              ),
            ),
            if (airport.municipality != null && airport.municipality!.isNotEmpty)
              Text(
                '${airport.municipality}, ${airport.country}',
                style: TextStyle(
                  color: FormThemeHelper.secondaryTextColor,
                  fontSize: 12,
                ),
              ),
          ],
        ),
        trailing: Icon(
          Icons.location_on,
          color: FormThemeHelper.secondaryTextColor,
        ),
        onTap: () {
          widget.onAirportSelected(airport);
          Navigator.of(context).pop();
        },
      ),
    );
  }
}