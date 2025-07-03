import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/license.dart';
import '../services/license_service.dart';
import 'license_detail_screen.dart';

class LicensesScreen extends StatefulWidget {
  const LicensesScreen({super.key});

  @override
  State<LicensesScreen> createState() => _LicensesScreenState();
}

class _LicensesScreenState extends State<LicensesScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pilot Licenses'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _navigateToAddLicense(context),
            tooltip: 'Add License',
          ),
        ],
      ),
      body: Consumer<LicenseService>(
        builder: (context, licenseService, child) {
          if (licenseService.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (licenseService.licenses.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.card_membership,
                    size: 80,
                    color: Colors.grey,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'No licenses added yet',
                    style: TextStyle(fontSize: 18, color: Colors.grey),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () => _navigateToAddLicense(context),
                    icon: const Icon(Icons.add),
                    label: const Text('Add Your First License'),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: licenseService.licenses.length,
            itemBuilder: (context, index) {
              final license = licenseService.licenses[index];
              return _buildLicenseCard(context, license);
            },
          );
        },
      ),
    );
  }

  Widget _buildLicenseCard(BuildContext context, License license) {
    final isExpired = license.isExpired;
    final isExpiringSoon = license.willExpireWithinDays(30);
    
    Color? cardColor;
    IconData statusIcon;
    Color statusColor;

    if (isExpired) {
      cardColor = Colors.red.shade50;
      statusIcon = Icons.error;
      statusColor = Colors.red;
    } else if (isExpiringSoon) {
      cardColor = Colors.orange.shade50;
      statusIcon = Icons.warning;
      statusColor = Colors.orange;
    } else {
      cardColor = null;
      statusIcon = Icons.check_circle;
      statusColor = Colors.green;
    }

    return Card(
      color: cardColor,
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: Icon(
          statusIcon,
          color: statusColor,
          size: 32,
        ),
        title: Text(
          license.name,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(license.description),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(
                  Icons.calendar_today,
                  size: 14,
                  color: Colors.grey.shade600,
                ),
                const SizedBox(width: 4),
                Text(
                  'Issued: ${_formatDate(license.issueDate)}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(width: 16),
                Icon(
                  Icons.event_busy,
                  size: 14,
                  color: isExpired ? Colors.red : Colors.grey.shade600,
                ),
                const SizedBox(width: 4),
                Text(
                  'Expires: ${_formatDate(license.expirationDate)}',
                  style: TextStyle(
                    fontSize: 12,
                    color: isExpired ? Colors.red : Colors.grey.shade600,
                    fontWeight: isExpired ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              license.expirationStatus,
              style: TextStyle(
                fontSize: 12,
                color: isExpired ? Colors.red : (isExpiringSoon ? Colors.orange : Colors.green),
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () => _navigateToEditLicense(context, license),
              tooltip: 'Edit',
            ),
            IconButton(
              icon: const Icon(Icons.delete),
              onPressed: () => _confirmDelete(context, license),
              tooltip: 'Delete',
            ),
          ],
        ),
        onTap: () => _navigateToEditLicense(context, license),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  void _navigateToAddLicense(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const LicenseDetailScreen(),
      ),
    );
  }

  void _navigateToEditLicense(BuildContext context, License license) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => LicenseDetailScreen(license: license),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, License license) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete License'),
        content: Text('Are you sure you want to delete "${license.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      try {
        await context.read<LicenseService>().deleteLicense(license.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${license.name} deleted')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error deleting license: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }
}