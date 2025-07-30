import 'package:flutter/material.dart';
import '../models/airport.dart';
import '../models/navaid.dart';
import '../services/airport_service.dart';
import '../services/navaid_service.dart';
import '../constants/app_colors.dart';
import '../constants/app_theme.dart';

class AirportSearchDialog extends StatefulWidget {
  final AirportService airportService;
  final NavaidService? navaidService;
  final Function(Airport) onAirportSelected;
  final Function(Navaid)? onNavaidSelected;

  const AirportSearchDialog({
    super.key,
    required this.airportService,
    this.navaidService,
    required this.onAirportSelected,
    this.onNavaidSelected,
  });

  @override
  State<AirportSearchDialog> createState() => _AirportSearchDialogState();
}

class _AirportSearchDialogState extends State<AirportSearchDialog> {
  final _searchController = TextEditingController();
  List<Airport> _airportResults = [];
  List<Navaid> _navaidResults = [];
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
        _airportResults = [];
        _navaidResults = [];
        _isSearching = false;
      });
      return;
    }

    setState(() {
      _isSearching = true;
      _airportResults = widget.airportService.searchAirports(query);
      
      // Search navaids if service is available
      if (widget.navaidService != null) {
        _navaidResults = widget.navaidService!.searchNavaids(query);
      }
      
      _isSearching = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.dialogBackgroundColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        height: MediaQuery.of(context).size.height * 0.8,
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Search Airports & Navaids',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: AppColors.primaryTextColor,
              ),
            ),
            const SizedBox(height: 16),
            // Search field
            TextField(
              controller: _searchController,
              autofocus: true,
              style: TextStyle(color: AppColors.primaryTextColor),
              decoration: InputDecoration(
                labelText: 'Search',
                hintText: 'Enter airport/navaid name, code, or city',
                labelStyle: TextStyle(color: AppColors.secondaryTextColor),
                hintStyle: TextStyle(color: AppColors.secondaryTextColor.withValues(alpha: 0.5)),
                prefixIcon: Icon(Icons.search, color: AppColors.secondaryTextColor),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: Icon(Icons.clear, color: AppColors.secondaryTextColor),
                        onPressed: () {
                          _searchController.clear();
                        },
                      )
                    : null,
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: AppColors.primaryAccent.withValues(alpha: 0.3)),
                  borderRadius: BorderRadius.circular(8),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: AppColors.primaryAccent),
                  borderRadius: BorderRadius.circular(8),
                ),
                fillColor: AppColors.fillColorFaint,
                filled: true,
              ),
            ),
            const SizedBox(height: 16),
            // Results
            Expanded(
              child: _buildSearchResults(),
            ),
            const SizedBox(height: 16),
            // Actions
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.secondaryTextColor,
                  ),
                  child: const Text('Cancel'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchResults() {
    if (_searchController.text.isEmpty) {
      return Center(
        child: Text(
          'Search for airports and navaids by name or code\n(e.g., "KJFK", "Kennedy", "VOR", "SFO")',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 16, color: AppColors.secondaryTextColor),
        ),
      );
    }

    if (_isSearching) {
      return const Center(child: CircularProgressIndicator());
    }

    final hasResults = _airportResults.isNotEmpty || _navaidResults.isNotEmpty;
    
    if (!hasResults) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off, size: 64, color: AppColors.secondaryTextColor),
            const SizedBox(height: 16),
            Text(
              'No results found for "${_searchController.text}"',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.primaryTextColor,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Try searching by:\n• Airport name (e.g., "Kennedy")\n• ICAO code (e.g., "KJFK")\n• IATA code (e.g., "JFK")\n• Navaid ID (e.g., "SFO")\n• VOR/NDB name',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.secondaryTextColor),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: _airportResults.length + _navaidResults.length + (_airportResults.isNotEmpty && _navaidResults.isNotEmpty ? 2 : (_airportResults.isNotEmpty || _navaidResults.isNotEmpty ? 1 : 0)),
      itemBuilder: (context, index) {
        int currentIndex = 0;
        
        // Airports section
        if (_airportResults.isNotEmpty) {
          if (index == currentIndex) {
            return _buildSectionHeader('Airports (${_airportResults.length})');
          }
          currentIndex++;
          
          if (index < currentIndex + _airportResults.length) {
            final airport = _airportResults[index - currentIndex];
            return _buildAirportTile(context, airport);
          }
          currentIndex += _airportResults.length;
        }
        
        // Navaids section
        if (_navaidResults.isNotEmpty) {
          if (index == currentIndex) {
            return _buildSectionHeader('Navigation Aids (${_navaidResults.length})');
          }
          currentIndex++;
          
          if (index < currentIndex + _navaidResults.length) {
            final navaid = _navaidResults[index - currentIndex];
            return _buildNavaidTile(context, navaid);
          }
        }
        
        return const SizedBox.shrink();
      },
    );
  }
  
  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: AppColors.secondaryTextColor,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildAirportTile(BuildContext context, Airport airport) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.sectionBackgroundColor,
        borderRadius: AppTheme.defaultRadius,
        border: Border.all(color: AppColors.sectionBorderColor),
      ),
      child: ListTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: AppColors.primaryAccent.withValues(alpha: 0.1),
            borderRadius: AppTheme.defaultRadius,
          ),
          child: Icon(
            Icons.flight_takeoff,
            color: AppColors.primaryAccent,
          ),
        ),
        title: Text(
          airport.name,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: AppColors.primaryTextColor,
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
                color: AppColors.primaryAccent,
                fontWeight: FontWeight.w500,
              ),
            ),
            if (airport.municipality != null && airport.municipality!.isNotEmpty)
              Text(
                '${airport.municipality}, ${airport.country}',
                style: TextStyle(
                  color: AppColors.secondaryTextColor,
                  fontSize: 12,
                ),
              ),
          ],
        ),
        trailing: Icon(
          Icons.location_on,
          color: AppColors.secondaryTextColor,
        ),
        onTap: () {
          widget.onAirportSelected(airport);
        },
      ),
    );
  }
  
  Widget _buildNavaidTile(BuildContext context, Navaid navaid) {
    // Get appropriate icon based on navaid type
    IconData getNavaidIcon(String type) {
      switch (type.toUpperCase()) {
        case 'VOR':
        case 'VOR-DME':
        case 'VORTAC':
          return Icons.radio_button_checked;
        case 'NDB':
        case 'NDB-DME':
          return Icons.wb_iridescent;
        case 'DME':
          return Icons.track_changes;
        case 'TACAN':
          return Icons.gps_fixed;
        default:
          return Icons.navigation;
      }
    }
    
    // Format frequency based on type
    String formatFrequency(double freqKhz, String type) {
      if (type.toUpperCase().contains('NDB')) {
        // NDB frequencies in kHz
        return '${freqKhz.toStringAsFixed(0)} kHz';
      } else {
        // VOR/DME frequencies in MHz
        final freqMhz = freqKhz / 1000;
        return '${freqMhz.toStringAsFixed(2)} MHz';
      }
    }
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.sectionBackgroundColor,
        borderRadius: AppTheme.defaultRadius,
        border: Border.all(color: AppColors.sectionBorderColor),
      ),
      child: ListTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: Colors.blue.withValues(alpha: 0.1),
            borderRadius: AppTheme.defaultRadius,
          ),
          child: Icon(
            getNavaidIcon(navaid.type),
            color: Colors.blue,
            size: 20,
          ),
        ),
        title: Text(
          navaid.name,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: AppColors.primaryTextColor,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  navaid.ident,
                  style: TextStyle(
                    color: Colors.blue,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  navaid.type.toUpperCase(),
                  style: TextStyle(
                    color: AppColors.secondaryTextColor,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            Text(
              formatFrequency(navaid.frequencyKhz, navaid.type),
              style: TextStyle(
                color: AppColors.secondaryTextColor,
                fontSize: 12,
              ),
            ),
          ],
        ),
        trailing: Icon(
          Icons.navigation,
          color: AppColors.secondaryTextColor,
          size: 20,
        ),
        onTap: () {
          if (widget.onNavaidSelected != null) {
            widget.onNavaidSelected!(navaid);
          }
        },
      ),
    );
  }
}