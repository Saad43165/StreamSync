import 'dart:io';
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'database_service.dart';

class DownloadService extends ChangeNotifier {
  final DatabaseService dbService;
  
  // Track active downloads by media ID
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
    
    if (isDownloading(id)) return; // Already downloading

    _activeProgress[id] = 0.01;
    _activeStatus[id] = 'Initiating connection...';
    _activeDetails[id] = Map<String, dynamic>.from(details);
    _cancelTokens[id] = CancelToken();
    notifyListeners();

    try {
      final appDocDir = await getApplicationDocumentsDirectory();
      final downloadsDir = Directory('${appDocDir.path}/downloads');
      if (!await downloadsDir.exists()) {
        await downloadsDir.create(recursive: true);
      }
      final fileName = '${details['media_type']}_$id.mp4';
      final filePath = '${downloadsDir.path}/$fileName';

      // Check if we have intercepted a real direct movie stream URL previously
      final resolvedUrl = dbService.resolvedUrls[id];
      final sourceUrl = resolvedUrl ?? 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4';

      if (resolvedUrl == null) {
        _activeStatus[id] = 'Playing sample (Play online first for real source)...';
        notifyListeners();
        await Future.delayed(const Duration(seconds: 2));
      }
      
      final dio = Dio();
      
      await dio.download(
        sourceUrl,
        filePath,
        cancelToken: _cancelTokens[id],
        onReceiveProgress: (received, total) {
          if (total != -1) {
            _activeProgress[id] = (received / total).clamp(0.0, 1.0);
            final recMB = (received / (1024 * 1024)).toStringAsFixed(1);
            final totMB = (total / (1024 * 1024)).toStringAsFixed(1);
            _activeStatus[id] = resolvedUrl == null 
                ? '$recMB MB / $totMB MB (Sample)' 
                : '$recMB MB / $totMB MB';
            notifyListeners();
          }
        },
      );

      // Save to database
      final detailedItem = Map<String, dynamic>.from(details);
      detailedItem['download_quality'] = selectedQuality;
      detailedItem['download_language'] = selectedLanguage;
      detailedItem['local_file_path'] = filePath;
      detailedItem['file_size_bytes'] = File(filePath).lengthSync();
      detailedItem['download_date'] = DateTime.now().toIso8601String();
      
      await dbService.addDownload(detailedItem);
      
      _cleanup(id);
    } catch (e) {
      String errMsg = 'Download failed.';
      if (e is DioException && CancelToken.isCancel(e)) {
        debugPrint('Download cancelled manually for ID: $id');
        errMsg = 'Download cancelled.';
        _cleanup(id);
        return;
      } else if (e is FileSystemException || e.toString().contains('No space') || e.toString().contains('Disk full')) {
        errMsg = 'Out of space!';
      } else {
        errMsg = 'Network error!';
      }
      
      _activeProgress[id] = 0.0;
      _activeStatus[id] = errMsg;
      notifyListeners();
      
      // Leave error status visible for a brief moment
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
