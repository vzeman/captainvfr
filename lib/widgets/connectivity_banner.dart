import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/connectivity_service.dart';

class ConnectivityBanner extends StatefulWidget {
  final Widget child;

  const ConnectivityBanner({super.key, required this.child});

  @override
  State<ConnectivityBanner> createState() => _ConnectivityBannerState();
}

class _ConnectivityBannerState extends State<ConnectivityBanner> {
  bool _isBannerDismissed = false;

  @override
  Widget build(BuildContext context) {
    // Calculate responsive font size based on screen width
    final screenWidth = MediaQuery.of(context).size.width;
    final fontSize = screenWidth < 400
        ? 12.0
        : (screenWidth < 600 ? 13.0 : 14.0);
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

        return Stack(
          children: [
            // Main content fills the entire area
            widget.child,
            // Position banner at the bottom
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                height: !hasInternet && !isChecking && !_isBannerDismissed
                    ? null
                    : 0,
                child: Material(
                  color: Colors.red.shade700,
                  elevation: 8,
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
                            child: SafeArea(
                              top: false,
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
                                  // Close button with better touch target
                                  Material(
                                    color: Colors.transparent,
                                    child: InkWell(
                                      onTap: () {
                                        setState(() {
                                          _isBannerDismissed = true;
                                        });
                                      },
                                      borderRadius: BorderRadius.circular(20),
                                      child: Container(
                                        padding: const EdgeInsets.all(8),
                                        child: Icon(
                                          Icons.close,
                                          color: Colors.white,
                                          size: iconSize,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                        : const SizedBox.shrink(),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
