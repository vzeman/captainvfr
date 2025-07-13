import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/license.dart';
import '../services/license_service.dart';
import '../screens/licenses_screen.dart';

class LicenseWarningWidget extends StatefulWidget {
  const LicenseWarningWidget({super.key});

  @override
  State<LicenseWarningWidget> createState() => _LicenseWarningWidgetState();
}

class _LicenseWarningWidgetState extends State<LicenseWarningWidget> {
  bool _isExpanded = false;
  bool _isDismissed = false;

  @override
  Widget build(BuildContext context) {
    return Consumer<LicenseService>(
      builder: (context, licenseService, child) {
        final licensesNeedingAttention =
            licenseService.licensesNeedingAttention;

        // Don't show if no licenses need attention or user dismissed
        if (licensesNeedingAttention.isEmpty || _isDismissed) {
          return const SizedBox.shrink();
        }

        final expiredCount = licenseService.expiredLicenses.length;
        final expiringCount = licenseService.expiringLicenses.length;

        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          margin: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: expiredCount > 0
                ? Colors.red.shade100
                : Colors.orange.shade100,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              InkWell(
                onTap: () => setState(() => _isExpanded = !_isExpanded),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Icon(
                        expiredCount > 0 ? Icons.error : Icons.warning,
                        color: expiredCount > 0 ? Colors.red : Colors.orange,
                        size: 24,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _getWarningTitle(expiredCount, expiringCount),
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            if (!_isExpanded)
                              Text(
                                _getWarningSubtitle(
                                  expiredCount,
                                  expiringCount,
                                ),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade700,
                                ),
                              ),
                          ],
                        ),
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.close, size: 20),
                            onPressed: () =>
                                setState(() => _isDismissed = true),
                            tooltip: 'Dismiss',
                          ),
                          Icon(
                            _isExpanded ? Icons.expand_less : Icons.expand_more,
                            color: Colors.grey,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              // Expanded content
              if (_isExpanded) ...[
                const Divider(height: 1),
                Container(
                  constraints: const BoxConstraints(maxHeight: 200),
                  child: ListView.builder(
                    shrinkWrap: true,
                    padding: const EdgeInsets.all(12),
                    itemCount: licensesNeedingAttention.length,
                    itemBuilder: (context, index) {
                      final license = licensesNeedingAttention[index];
                      return _buildLicenseItem(license);
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(
                    left: 12,
                    right: 12,
                    bottom: 12,
                  ),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => _navigateToLicenses(context),
                      icon: const Icon(Icons.card_membership),
                      label: const Text('Manage Licenses'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: expiredCount > 0
                            ? Colors.red
                            : Colors.orange,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildLicenseItem(License license) {
    final isExpired = license.isExpired;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(
            isExpired ? Icons.cancel : Icons.access_time,
            color: isExpired ? Colors.red : Colors.orange,
            size: 16,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  license.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w500,
                    fontSize: 14,
                  ),
                ),
                Text(
                  license.expirationStatus,
                  style: TextStyle(
                    fontSize: 12,
                    color: isExpired ? Colors.red : Colors.orange,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _getWarningTitle(int expiredCount, int expiringCount) {
    if (expiredCount > 0 && expiringCount > 0) {
      return 'License Attention Required';
    } else if (expiredCount > 0) {
      return expiredCount == 1
          ? 'License Expired'
          : '$expiredCount Licenses Expired';
    } else {
      return expiringCount == 1
          ? 'License Expiring Soon'
          : '$expiringCount Licenses Expiring Soon';
    }
  }

  String _getWarningSubtitle(int expiredCount, int expiringCount) {
    if (expiredCount > 0 && expiringCount > 0) {
      return '$expiredCount expired, $expiringCount expiring soon';
    } else if (expiredCount > 0) {
      return 'Immediate attention required';
    } else {
      return 'Within 30 days';
    }
  }

  void _navigateToLicenses(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const LicensesScreen()),
    );
  }
}
