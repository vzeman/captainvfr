import 'package:flutter/material.dart';
import 'calculators/density_altitude_calculator.dart';
import 'calculators/weight_balance_calculator.dart';
import 'calculators/crosswind_calculator.dart';
import 'calculators/fuel_burn_calculator.dart';
import 'calculators/unit_conversion_calculator.dart';
import 'calculators/takeoff_landing_calculator.dart';
import 'calculators/wind_correction_calculator.dart';
import 'calculators/climb_performance_calculator.dart';
import 'calculators/cruise_performance_calculator.dart';
import 'calculators/descent_performance_calculator.dart';

class CalculatorsScreen extends StatelessWidget {
  const CalculatorsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.surface,
        title: const Text('Pilot Calculators'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: GridView.count(
        crossAxisCount: 2,
        padding: const EdgeInsets.all(16),
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        children: [
          _buildCalculatorTile(
            context,
            'Density Altitude',
            Icons.thermostat,
            () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const DensityAltitudeCalculator(),
                ),
              );
            },
          ),
          _buildCalculatorTile(context, 'Weight & Balance', Icons.balance, () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const WeightBalanceCalculator(),
              ),
            );
          }),
          _buildCalculatorTile(
            context,
            'Takeoff & Landing',
            Icons.flight_takeoff,
            () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const TakeoffLandingCalculator(),
                ),
              );
            },
          ),
          _buildCalculatorTile(
            context,
            'Fuel Burn',
            Icons.local_gas_station,
            () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const FuelBurnCalculator(),
                ),
              );
            },
          ),
          _buildCalculatorTile(
            context,
            'Climb Performance',
            Icons.trending_up,
            () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const ClimbPerformanceCalculator(),
                ),
              );
            },
          ),
          _buildCalculatorTile(context, 'Cruise Performance', Icons.flight, () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const CruisePerformanceCalculator(),
              ),
            );
          }),
          _buildCalculatorTile(
            context,
            'Descent Performance',
            Icons.trending_down,
            () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const DescentPerformanceCalculator(),
                ),
              );
            },
          ),
          _buildCalculatorTile(context, 'Crosswind', Icons.air, () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const CrosswindCalculator(),
              ),
            );
          }),
          _buildCalculatorTile(context, 'Wind Correction', Icons.explore, () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const WindCorrectionCalculator(),
              ),
            );
          }),
          _buildCalculatorTile(
            context,
            'Unit Conversion',
            Icons.swap_horiz,
            () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const UnitConversionCalculator(),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildCalculatorTile(
    BuildContext context,
    String title,
    IconData icon,
    VoidCallback onTap,
  ) {
    return Card(
      elevation: 2,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 48,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 12),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
