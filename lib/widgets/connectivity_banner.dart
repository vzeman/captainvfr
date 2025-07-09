import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/connectivity_service.dart';

class ConnectivityBanner extends StatefulWidget {
  final Widget child;
  
  const ConnectivityBanner({
    super.key,
    required this.child,
  });

  @override
  State<ConnectivityBanner> createState() => _ConnectivityBannerState();
}

class _ConnectivityBannerState extends State<ConnectivityBanner> {
  bool _isBannerDismissed = false;

  @override
  Widget build(BuildContext context) {
    // Calculate responsive font size based on screen width
    final screenWidth = MediaQuery.of(context).size.width;
    final fontSize = screenWidth < 400 ? 12.0 : (screenWidth < 600 ? 13.0 : 14.0);
    final iconSize = screenWidth < 400 ? 18.0 : 20.0;
    
    return Consumer<ConnectivityService>(
      builder: (context, connectivityService, _) {
        final hasInternet = connectivityService.hasInternetConnection;
        final isChecking = connectivityService.isCheckingConnection;
        
        // Reset dismissed state when internet comes back
        if (hasInternet && _isBannerDismissed) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              setState(() {
                _isBannerDismissed = false;
              });
            }
          });
        }
        
        return Column(
          children: [
            // Show banner only when there's no internet (not when checking) and not dismissed
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              height: !hasInternet && !isChecking && !_isBannerDismissed ? null : 0,
              child: Material(
                color: Colors.red.shade700,
                child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    child: !hasInternet && !isChecking && !_isBannerDismissed
                        ? Container(
                            key: ValueKey('banner_${hasInternet}_$isChecking'),
                            width: double.infinity,
                            padding: EdgeInsets.symmetric(
                              horizontal: screenWidth < 400 ? 12 : 16,
                              vertical: screenWidth < 400 ? 8 : 12,
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.wifi_off,
                                  color: Colors.white,
                                  size: iconSize,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    'No internet connection. Some features may be limited.',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: fontSize,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                                // Close button
                                GestureDetector(
                                  onTap: () {
                                    setState(() {
                                      _isBannerDismissed = true;
                                    });
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withAlpha(51),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Icon(
                                      Icons.close,
                                      color: Colors.white,
                                      size: iconSize - 4,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          )
                        : const SizedBox.shrink(),
                ),
              ),
            ),
            // Main content
            Expanded(child: widget.child),
          ],
        );
      },
    );
  }
}