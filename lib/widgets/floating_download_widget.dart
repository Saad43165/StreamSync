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

class _FloatingDownloadWidgetState extends State<FloatingDownloadWidget>
    with SingleTickerProviderStateMixin {
  bool _isExpanded = false;
  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<DownloadService>(
      builder: (context, svc, _) {
        if (svc.activeProgress.isEmpty) {
          if (_isExpanded) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) setState(() => _isExpanded = false);
            });
          }
          return const SizedBox.shrink();
        }

        final activeId = svc.activeProgress.keys.first;
        final progress = svc.activeProgress[activeId] ?? 0.0;
        final status   = svc.activeStatus[activeId]   ?? '';
        final details  = svc.activeDetails[activeId];
        final title    = details?['title'] ?? details?['name'] ?? 'Downloading…';
        final isPaused = status.contains('Paused');
        final isDone   = progress >= 1.0;

        return Positioned(
          bottom: 108,
          right: 16,
          child: GestureDetector(
            onTap: () => setState(() => _isExpanded = !_isExpanded),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 280),
              curve: Curves.easeOutQuart,
              width:  _isExpanded ? 260 : 58,
              height: _isExpanded ? 92  : 58,
              child: _DownloadCard(
                isExpanded: _isExpanded,
                progress:   progress,
                status:     status,
                title:      title,
                isPaused:   isPaused,
                isDone:     isDone,
                pulseAnim:  _pulseAnim,
                onCancel:   () => svc.cancelDownload(activeId),
                onPause:    () => svc.pauseDownload(activeId),
                onResume:   () => svc.resumeDownload(activeId),
              ),
            ),
          ),
        );
      },
    );
  }
}

// ── Card renderer (separated for clarity) ──────────────────────────────────

class _DownloadCard extends StatelessWidget {
  final bool isExpanded;
  final double progress;
  final String status;
  final String title;
  final bool isPaused;
  final bool isDone;
  final Animation<double> pulseAnim;
  final VoidCallback onCancel;
  final VoidCallback onPause;
  final VoidCallback onResume;

  const _DownloadCard({
    required this.isExpanded,
    required this.progress,
    required this.status,
    required this.title,
    required this.isPaused,
    required this.isDone,
    required this.pulseAnim,
    required this.onCancel,
    required this.onPause,
    required this.onResume,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(29),
      child: GlassCard(
        borderRadius: 29,
        padding: EdgeInsets.zero,
        child: isExpanded ? _expandedBody() : _collapsedBody(),
      ),
    );
  }

  // ── Collapsed: circular progress pill ──────────────────────────────────

  Widget _collapsedBody() {
    return SizedBox(
      width: 58,
      height: 58,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: 36,
            height: 36,
            child: CircularProgressIndicator(
              value: progress < 0.02 ? null : progress, // indeterminate while resolving
              backgroundColor: Colors.white12,
              color: isDone ? Colors.greenAccent : AppTheme.accent,
              strokeWidth: 3,
            ),
          ),
          AnimatedBuilder(
            animation: pulseAnim,
            builder: (_, child) => Transform.scale(scale: pulseAnim.value, child: child),
            child: Icon(
              isDone ? Icons.check_rounded : Icons.download_rounded,
              size: 16,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  // ── Expanded: full download card ────────────────────────────────────────

  Widget _expandedBody() {
    final pct = (progress * 100).toInt();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Title row
          Row(
            children: [
              const Icon(Icons.download_rounded, size: 14, color: AppTheme.accent),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: Colors.white,
                  ),
                ),
              ),
              // Cancel button
              GestureDetector(
                onTap: onCancel,
                child: const Icon(Icons.close_rounded, color: Colors.white54, size: 16),
              ),
            ],
          ),

          const SizedBox(height: 8),

          // Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress < 0.02 ? null : progress,
              backgroundColor: Colors.white12,
              valueColor: AlwaysStoppedAnimation<Color>(
                isDone ? Colors.greenAccent : AppTheme.accent,
              ),
              minHeight: 5,
            ),
          ),

          const SizedBox(height: 6),

          // Status row + pause/resume
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  isDone ? status : (progress >= 0.02 ? '$pct% · $status' : status),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: isDone ? Colors.greenAccent : Colors.white60,
                    fontSize: 11,
                  ),
                ),
              ),
              if (!isDone)
                GestureDetector(
                  onTap: isPaused ? onResume : onPause,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppTheme.accent.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isPaused ? Icons.play_arrow_rounded : Icons.pause_rounded,
                          size: 12,
                          color: AppTheme.accent,
                        ),
                        const SizedBox(width: 3),
                        Text(
                          isPaused ? 'Resume' : 'Pause',
                          style: const TextStyle(
                            color: AppTheme.accent,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}