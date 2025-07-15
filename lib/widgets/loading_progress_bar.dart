import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/background_data_service.dart';

class LoadingProgressBar extends StatefulWidget {
  const LoadingProgressBar({super.key});

  @override
  State<LoadingProgressBar> createState() => _LoadingProgressBarState();
}

class _LoadingProgressBarState extends State<LoadingProgressBar> {
  bool _isDismissed = false;

  @override
  Widget build(BuildContext context) {
    return Consumer<BackgroundDataService>(
      builder: (context, dataService, child) {
        // Hide if user dismissed
        if (_isDismissed) {
          return const SizedBox.shrink();
        }
        
        // Hide if not loading and airports are loaded (most important data)
        if (!dataService.isLoading && dataService.loadedData['airports'] == true) {
          return const SizedBox.shrink();
        }

        return Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: Theme.of(context).primaryColor.withValues(alpha: 0.9),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  if (dataService.isLoading) ...[
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    ),
                    const SizedBox(width: 12),
                  ],
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          dataService.isLoading
                              ? dataService.currentTask
                              : 'Some data may still be loading...',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        if (dataService.isLoading) ...[
                          const SizedBox(height: 4),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(2),
                            child: LinearProgressIndicator(
                              value: dataService.progress,
                              backgroundColor: Colors.white.withValues(
                                alpha: 0.3,
                              ),
                              valueColor: const AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                              minHeight: 3,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (!dataService.isLoading) ...[
                    TextButton(
                      onPressed: () {
                        // Dismiss by navigating to offline data settings
                        Navigator.pushNamed(context, '/offline_data');
                      },
                      child: const Text(
                        'Load Data',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                  IconButton(
                    icon: const Icon(
                      Icons.close,
                      color: Colors.white,
                      size: 20,
                    ),
                    onPressed: () {
                      setState(() {
                        _isDismissed = true;
                      });
                    },
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 32,
                      minHeight: 32,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
