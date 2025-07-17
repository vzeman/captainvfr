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
import '../utils/form_theme_helper.dart';

class CalculatorsScreen extends StatelessWidget {
  const CalculatorsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final calculators = _getCalculators(context);
    
    return Scaffold(
      backgroundColor: FormThemeHelper.backgroundColor,
      appBar: AppBar(
        backgroundColor: FormThemeHelper.dialogBackgroundColor,
        title: const Text(
          'Pilot Calculators',
          style: TextStyle(color: FormThemeHelper.primaryTextColor),
        ),
        foregroundColor: FormThemeHelper.primaryTextColor,
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          // Calculate the number of columns based on screen width
          // Each tile is max 100px + 12px spacing
          const double tileSize = 100;
          const double spacing = 12;
          final int crossAxisCount = (constraints.maxWidth / (tileSize + spacing)).floor().clamp(2, 8);
          
          return GridView.builder(
            padding: const EdgeInsets.all(12),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: crossAxisCount,
              childAspectRatio: 1.0,
              crossAxisSpacing: spacing,
              mainAxisSpacing: spacing,
            ),
            itemCount: calculators.length,
            itemBuilder: (context, index) {
              final calculator = calculators[index];
              return SizedBox(
                width: tileSize,
                height: tileSize,
                child: _buildCalculatorTile(
                  context,
                  calculator['title'] as String,
                  calculator['icon'] as IconData,
                  calculator['onTap'] as VoidCallback,
                ),
              );
            },
          );
        },
      ),
    );
  }

  // Define calculators list
  List<Map<String, dynamic>> _getCalculators(BuildContext context) => [
    {
      'title': 'Density Altitude',
      'icon': Icons.thermostat,
      'onTap': () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const DensityAltitudeCalculator(),
          ),
        );
      },
    },
    {
      'title': 'Weight & Balance',
      'icon': Icons.balance,
      'onTap': () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const WeightBalanceCalculator(),
          ),
        );
      },
    },
    {
      'title': 'Takeoff & Landing',
      'icon': Icons.flight_takeoff,
      'onTap': () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const TakeoffLandingCalculator(),
          ),
        );
      },
    },
    {
      'title': 'Fuel Burn',
      'icon': Icons.local_gas_station,
      'onTap': () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const FuelBurnCalculator(),
          ),
        );
      },
    },
    {
      'title': 'Climb Performance',
      'icon': Icons.trending_up,
      'onTap': () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const ClimbPerformanceCalculator(),
          ),
        );
      },
    },
    {
      'title': 'Cruise Performance',
      'icon': Icons.flight,
      'onTap': () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const CruisePerformanceCalculator(),
          ),
        );
      },
    },
    {
      'title': 'Descent Performance',
      'icon': Icons.trending_down,
      'onTap': () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const DescentPerformanceCalculator(),
          ),
        );
      },
    },
    {
      'title': 'Crosswind',
      'icon': Icons.air,
      'onTap': () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const CrosswindCalculator(),
          ),
        );
      },
    },
    {
      'title': 'Wind Correction',
      'icon': Icons.explore,
      'onTap': () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const WindCorrectionCalculator(),
          ),
        );
      },
    },
    {
      'title': 'Unit Conversion',
      'icon': Icons.swap_horiz,
      'onTap': () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const UnitConversionCalculator(),
          ),
        );
      },
    },
  ];

  Widget _buildCalculatorTile(
    BuildContext context,
    String title,
    IconData icon,
    VoidCallback onTap,
  ) {
    return Container(
      constraints: const BoxConstraints(
        maxWidth: 100,
        maxHeight: 100,
      ),
      decoration: BoxDecoration(
        color: const Color(0x1A448AFF),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0x7F448AFF)),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(8),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 32,
                color: const Color(0xFF448AFF),
              ),
              const SizedBox(height: 4),
              Text(
                title,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}