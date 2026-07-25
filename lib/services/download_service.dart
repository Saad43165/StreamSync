import 'dart:io';
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'database_service.dart';
import 'stream_resolver_service.dart';

class DownloadService extends ChangeNotifier {
  final DatabaseService dbService;

  final Map<int, double> _activeProgress = {};
  final Map<int, String> _activeStatus = {};
  final Map<int, CancelToken> _cancelTokens = {};
  final Map<int, Map<String, dynamic>> _activeDetails = {};

  DownloadService({required this.dbService});

  Map<int, double> get activeProgress => _activeProgress;
  Map<int, String> get activeStatus => _activeStatus;
  Map<int, Map<String, dynamic>> get activeDetails => _activeDetails;

  bool isDownloading(int id) => _activeProgress.containsKey(id);

  Future<void> startDownload({
    required Map<String, dynamic> details,
    required String selectedQuality,
    required String selectedLanguage,
  }) async {
    final id = details['id'] as int;
    if (isDownloading(id)) return;

    final title = details['title'] ?? details['name'] ?? 'Unknown';
    final mediaType = details['media_type'] as String? ?? 'movie';

    _activeProgress[id] = 0.01;
    _activeStatus[id] = 'Resolving stream...';
    _activeDetails[id] = Map<String, dynamic>.from(details);
    _cancelTokens[id] = CancelToken();
    notifyListeners();

    try {
      // ── Step 1: Resolve stream URL via Consumet ─────────────────────────
      _activeStatus[id] = 'Finding download source for "$title"...';
      notifyListeners();

      StreamResult? result;
      try {
        if (mediaType == 'movie') {
          result = await StreamResolverService.resolveMovie(id, title);
        } else {
          result = await StreamResolverService.resolveTv(id, 1, 1, title);
        }
      } catch (_) {
        result = null;
      }

      // Must be a native (direct URL) stream to download
      if (result == null || !result.isNative) {
        _activeStatus[id] = 'No downloadable source found.\nTry playing first to cache URL.';
        notifyListeners();
        await Future.delayed(const Duration(seconds: 3));
        _cleanup(id);
        return;
      }

      final sourceUrl = result.url;

      // ── Step 2: Set up local file path ────────────────────────────────
      Directory downloadsDir;
      try {
        // Try external storage first (visible in Files app)
        final extDir = await getExternalStorageDirectory();
        downloadsDir = Directory('${extDir!.path}/StreamSync');
      } catch (_) {
        final appDir = await getApplicationDocumentsDirectory();
        downloadsDir = Directory('${appDir.path}/StreamSync');
      }

      if (!await downloadsDir.exists()) {
        await downloadsDir.create(recursive: true);
      }

      // Clean title for filename
      final cleanTitle = title
          .replaceAll(RegExp(r'[^\w\s-]'), '')
          .replaceAll(RegExp(r'\s+'), '_')
          .toLowerCase();
      final ext = sourceUrl.contains('.m3u8') ? 'mp4' : 'mp4';
      final fileName = '${cleanTitle}_$id.$ext';
      final filePath = '${downloadsDir.path}/$fileName';

      _activeStatus[id] = 'Starting download via ${result.source}...';
      notifyListeners();

      // ── Step 3: Download the file ─────────────────────────────────────
      final dio = Dio();
      dio.options.headers = {
        'User-Agent': 'Mozilla/5.0 (Linux; Android 12) AppleWebKit/537.36',
        'Referer': 'https://vidlink.pro/',
      };

      await dio.download(
        sourceUrl,
        filePath,
        cancelToken: _cancelTokens[id],
        onReceiveProgress: (received, total) {
          if (total != -1) {
            _activeProgress[id] = (received / total).clamp(0.0, 1.0);
            final recMB = (received / (1024 * 1024)).toStringAsFixed(1);
            final totMB = (total / (1024 * 1024)).toStringAsFixed(1);
            _activeStatus[id] = 'Downloading: $recMB / $totMB MB';
            notifyListeners();
          } else {
            // Unknown total — show received
            final recMB = (received / (1024 * 1024)).toStringAsFixed(1);
            _activeStatus[id] = 'Downloading: ${recMB} MB...';
            notifyListeners();
          }
        },
      );

      // ── Step 4: Save record to database ──────────────────────────────
      final detailedItem = Map<String, dynamic>.from(details);
      detailedItem['download_quality'] = selectedQuality;
      detailedItem['download_language'] = selectedLanguage;
      detailedItem['local_file_path'] = filePath;
      detailedItem['stream_source'] = result.source;
      detailedItem['file_size_bytes'] = File(filePath).existsSync()
          ? File(filePath).lengthSync()
          : 0;
      detailedItem['download_date'] = DateTime.now().toIso8601String();

      await dbService.addDownload(detailedItem);

      _activeStatus[id] = '✅ Downloaded!';
      notifyListeners();
      await Future.delayed(const Duration(seconds: 1));
      _cleanup(id);

    } catch (e) {
      String errMsg;
      if (e is DioException && CancelToken.isCancel(e)) {
        _cleanup(id);
        return;
      } else if (e.toString().contains('No space') || e.toString().contains('Disk full')) {
        errMsg = '❌ Not enough storage space!';
      } else if (e.toString().contains('SocketException') || e.toString().contains('network')) {
        errMsg = '❌ Network error. Check your connection.';
      } else {
        errMsg = '❌ Download failed. Try again.';
        debugPrint('Download error: $e');
      }

      _activeStatus[id] = errMsg;
      notifyListeners();
      await Future.delayed(const Duration(seconds: 3));
      _cleanup(id);
    }
  }

  void cancelDownload(int id) {
    if (_cancelTokens.containsKey(id)) {
      _cancelTokens[id]?.cancel();
      _cleanup(id);
    }
  }

  void _cleanup(int id) {
    _activeProgress.remove(id);
    _activeStatus.remove(id);
    _cancelTokens.remove(id);
    _activeDetails.remove(id);
    notifyListeners();
  }
}
