import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/download_service.dart';
import '../theme/app_theme.dart';
import 'glass_card.dart';

class FloatingDownloadWidget extends StatefulWidget {
  const FloatingDownloadWidget({super.key});

  @override
  State<FloatingDownloadWidget> createState() => _FloatingDownloadWidgetState();
}

class _FloatingDownloadWidgetState extends State<FloatingDownloadWidget> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    return Consumer<DownloadService>(
      builder: (context, downloadService, child) {
        if (downloadService.activeProgress.isEmpty) {
          // If was expanded and now finished, reset state for next time
          if (_isExpanded) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) setState(() => _isExpanded = false);
            });
          }
          return const SizedBox.shrink();
        }

        final activeId = downloadService.activeProgress.keys.first;
        final progress = downloadService.activeProgress[activeId] ?? 0.0;
        final status = downloadService.activeStatus[activeId] ?? '';
        final details = downloadService.activeDetails[activeId];
        final title = details?['title'] ?? details?['name'] ?? 'Downloading...';

        return Positioned(
          bottom: 100, // Above the bottom navigation bar
          right: 20,
          child: GestureDetector(
            onTap: () {
              setState(() {
                _isExpanded = !_isExpanded;
              });
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOutQuart,
              width: _isExpanded ? 240 : 56,
              height: 56,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.3),
                    blurRadius: 16,
                    offset: const Offset(0, 8),
                  )
                ],
              ),
              child: GlassCard(
                borderRadius: 28,
                padding: EdgeInsets.zero,
                child: Row(
                  children: [
                    SizedBox(
                      width: 56,
                      height: 56,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          SizedBox(
                            width: 32,
                            height: 32,
                            child: CircularProgressIndicator(
                              value: progress,
                              backgroundColor: Colors.white.withValues(alpha: 0.1),
                              color: AppTheme.accent,
                              strokeWidth: 3,
                            ),
                          ),
                          Icon(
                            _isExpanded ? Icons.close_fullscreen_rounded : Icons.download_rounded, 
                            size: 16, 
                            color: Colors.white
                          ),
                        ],
                      ),
                    ),
                    if (_isExpanded)
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(right: 12.0),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                              ),
                              const SizedBox(height: 2),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    status,
                                    style: const TextStyle(color: Colors.white70, fontSize: 11),
                                  ),
                                  GestureDetector(
                                    onTap: () => downloadService.cancelDownload(activeId),
                                    child: const Icon(Icons.cancel_rounded, color: Colors.redAccent, size: 16),
                                  )
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
