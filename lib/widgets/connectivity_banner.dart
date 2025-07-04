import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/connectivity_service.dart';

class ConnectivityBanner extends StatelessWidget {
  final Widget child;
  
  const ConnectivityBanner({
    super.key,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<ConnectivityService>(
      builder: (context, connectivityService, _) {
        final hasInternet = connectivityService.hasInternetConnection;
        final isChecking = connectivityService.isCheckingConnection;
        
        return Column(
          children: [
            // Show banner when there's no internet or when checking
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              height: (!hasInternet || isChecking) ? null : 0,
              child: Material(
                color: isChecking 
                    ? Colors.orange.shade700
                    : Colors.red.shade700,
                child: InkWell(
                  onTap: !hasInternet ? () => _showDetailsDialog(context, connectivityService) : null,
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    child: (!hasInternet || isChecking)
                        ? Container(
                            key: ValueKey('banner_${hasInternet}_$isChecking'),
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  isChecking 
                                      ? Icons.sync 
                                      : Icons.wifi_off,
                                  color: Colors.white,
                                  size: 20,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    connectivityService.getConnectionStatusMessage(),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                                if (!hasInternet && !isChecking) ...[
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withAlpha(51),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: const Text(
                                      'TAP FOR INFO',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                                if (isChecking) ...[
                                  const SizedBox(width: 8),
                                  const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        Colors.white,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          )
                        : const SizedBox.shrink(),
                  ),
                ),
              ),
            ),
            // Main content
            Expanded(child: child),
          ],
        );
      },
    );
  }
  
  void _showDetailsDialog(BuildContext context, ConnectivityService connectivityService) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.wifi_off, color: Colors.red),
            SizedBox(width: 8),
            Text('No Internet Connection'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'CaptainVFR requires an internet connection for some features. '
              'The following features may be limited or unavailable:',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 16),
            ...connectivityService.getAffectedFeatures().map(
              (feature) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.warning_amber,
                      size: 16,
                      color: Colors.orange,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        feature,
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Core features like GPS tracking, flight recording, and offline maps will continue to work.',
              style: TextStyle(
                fontSize: 13,
                fontStyle: FontStyle.italic,
                color: Colors.green,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () async {
              Navigator.of(context).pop();
              // Trigger a manual connectivity check
              await connectivityService.checkInternetConnection();
            },
            child: const Text('RETRY'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}