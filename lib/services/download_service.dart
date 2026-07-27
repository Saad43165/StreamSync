import 'dart:io';
import 'dart:isolate';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_downloader/flutter_downloader.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

import 'database_service.dart';
import 'stream_resolver_service.dart';

/// Matches the port name registered in [FloatingDownloadWidget] / wherever
/// you listen to progress.
const _portName = 'downloader_send_port';

class DownloadService extends ChangeNotifier {
  final DatabaseService dbService;

  // keyed by TMDB id (int)
  final Map<int, double> _activeProgress = {};
  final Map<int, String> _activeStatus = {};
  final Map<int, Map<String, dynamic>> _activeDetails = {};

  // keyed by flutter_downloader taskId (String)
  final Map<String, int> _taskToId = {};          // taskId → TMDB id
  final Map<int, String> _idToTask = {};           // TMDB id → taskId
  final Map<int, String> _idToFilePath = {};       // TMDB id → local file path
  final Map<int, Map<String, dynamic>> _pendingMeta = {}; // saved until task finishes

  // IsolateNameServer receive port
  final ReceivePort _port = ReceivePort();

  DownloadService({required this.dbService}) {
    _registerIsolatePort();
    FlutterDownloader.registerCallback(_downloadCallback, step: 1);
  }

  // ── Public getters ───────────────────────────────────────────────────────

  Map<int, double>               get activeProgress => _activeProgress;
  Map<int, String>               get activeStatus   => _activeStatus;
  Map<int, Map<String, dynamic>> get activeDetails  => _activeDetails;

  bool isDownloading(int id) => _activeProgress.containsKey(id);

  // ── IsolateNameServer wiring ─────────────────────────────────────────────

  void _registerIsolatePort() {
    IsolateNameServer.removePortNameMapping(_portName);
    IsolateNameServer.registerPortWithName(_port.sendPort, _portName);
    _port.listen(_onPortMessage);
  }

  /// Static callback — runs in background isolate, must be top-level or static.
  @pragma('vm:entry-point')
  static void _downloadCallback(String id, int status, int progress) {
    final send = IsolateNameServer.lookupPortByName(_portName);
    send?.send([id, status, progress]);
  }

  void _onPortMessage(dynamic data) {
    if (data is! List || data.length < 3) return;
    final taskId   = data[0] as String;
    final status   = DownloadTaskStatus.fromInt(data[1] as int);
    final progress = data[2] as int; // 0-100

    final mediaId = _taskToId[taskId];
    if (mediaId == null) return;

    if (status == DownloadTaskStatus.running) {
      _activeProgress[mediaId] = (progress / 100).clamp(0.0, 1.0);
      _activeStatus[mediaId]   = 'Downloading... $progress%';
      notifyListeners();
    } else if (status == DownloadTaskStatus.complete) {
      _activeProgress[mediaId] = 1.0;
      _activeStatus[mediaId]   = '✅ Download complete!';
      notifyListeners();
      _finaliseDownload(mediaId, taskId);
    } else if (status == DownloadTaskStatus.failed) {
      _activeStatus[mediaId] = '❌ Download failed. Try again.';
      notifyListeners();
      _delayedCleanup(mediaId);
    } else if (status == DownloadTaskStatus.canceled) {
      _cleanup(mediaId);
    } else if (status == DownloadTaskStatus.paused) {
      _activeStatus[mediaId] = '⏸ Paused';
      notifyListeners();
    }
  }

  // ── Start download ───────────────────────────────────────────────────────

  Future<void> startDownload({
    required Map<String, dynamic> details,
    required String selectedQuality,
    required String selectedLanguage,
  }) async {
    final id        = details['id'] as int;
    final title     = details['title'] ?? details['name'] ?? 'Unknown';
    final mediaType = details['media_type'] as String? ?? 'movie';

    if (isDownloading(id)) return;

    // ── Request storage permission (Android ≤ 12) ────────────────────────
    if (Platform.isAndroid) {
      final status = await Permission.storage.request();
      if (!status.isGranted) {
        _showOneShot(id, '❌ Storage permission denied.');
        return;
      }
    }

    _activeProgress[id] = 0.01;
    _activeStatus[id]   = 'Resolving stream…';
    _activeDetails[id]  = Map<String, dynamic>.from(details);
    notifyListeners();

    try {
      // ── Step 1: Resolve stream URL ─────────────────────────────────────
      _activeStatus[id] = 'Finding source for "$title"…';
      notifyListeners();

      StreamResult? result;
      try {
        result = mediaType == 'movie'
            ? await StreamResolverService.resolveMovie(id, title)
            : await StreamResolverService.resolveTv(id, 1, 1, title);
      } catch (_) {
        result = null;
      }

      if (result == null || !result.isNative) {
        _showOneShot(id, '❌ No downloadable source found.');
        return;
      }

      final sourceUrl = result.url;

      // ── Step 2: Build save directory ──────────────────────────────────
      final saveDir = await _resolveDownloadDir();

      // ── Step 3: Build clean filename ──────────────────────────────────
      final cleanTitle = title
          .replaceAll(RegExp(r'[^\w\s\-]'), '')
          .replaceAll(RegExp(r'\s+'), '_')
          .toLowerCase();
      final fileName = '${cleanTitle}_$id.mp4';
      final filePath = '${saveDir.path}/$fileName';

      // Delete stale partial file if it exists
      final existing = File(filePath);
      if (await existing.exists()) await existing.delete();

      // ── Step 4: Store metadata for when task finishes ─────────────────
      _pendingMeta[id] = {
        ...details,
        'download_quality':   selectedQuality,
        'download_language':  selectedLanguage,
        'local_file_path':    filePath,
        'stream_source':      result.source,
        'download_date':      DateTime.now().toIso8601String(),
      };
      _idToFilePath[id] = filePath;

      _activeStatus[id] = 'Starting download…';
      notifyListeners();

      // ── Step 5: Enqueue with flutter_downloader ───────────────────────
      final taskId = await FlutterDownloader.enqueue(
        url:               sourceUrl,
        savedDir:          saveDir.path,
        fileName:          fileName,
        showNotification:  true,   // shows in notification tray like YouTube
        openFileFromNotification: false,
        headers: {
          'User-Agent': 'Mozilla/5.0 (Linux; Android 12) AppleWebKit/537.36',
          'Referer':    'https://vidlink.pro/',
        },
      );

      if (taskId == null) {
        _showOneShot(id, '❌ Could not start download task.');
        return;
      }

      _taskToId[taskId] = id;
      _idToTask[id]     = taskId;

      _activeStatus[id] = 'Downloading…';
      notifyListeners();

    } catch (e) {
      final msg = _errorMessage(e);
      _showOneShot(id, msg);
      debugPrint('DownloadService error: $e');
    }
  }

  // ── Finalise after completion ────────────────────────────────────────────

  Future<void> _finaliseDownload(int mediaId, String taskId) async {
    final meta     = _pendingMeta[mediaId];
    final filePath = _idToFilePath[mediaId];

    if (meta != null && filePath != null) {
      final file       = File(filePath);
      final sizeBytes  = file.existsSync() ? file.lengthSync() : 0;

      final record = Map<String, dynamic>.from(meta)
        ..['file_size_bytes'] = sizeBytes;

      await dbService.addDownload(record);
    }

    await Future.delayed(const Duration(seconds: 2));
    _cleanup(mediaId);
  }

  // ── Cancel ───────────────────────────────────────────────────────────────

  Future<void> cancelDownload(int id) async {
    final taskId = _idToTask[id];
    if (taskId != null) {
      await FlutterDownloader.cancel(taskId: taskId);
    }
    _cleanup(id);
  }

  Future<void> pauseDownload(int id) async {
    final taskId = _idToTask[id];
    if (taskId != null) await FlutterDownloader.pause(taskId: taskId);
  }

  Future<void> resumeDownload(int id) async {
    final taskId = _idToTask[id];
    if (taskId == null) return;
    final newTaskId = await FlutterDownloader.resume(taskId: taskId);
    if (newTaskId != null) {
      _taskToId.remove(taskId);
      _taskToId[newTaskId] = id;
      _idToTask[id]        = newTaskId;
    }
  }

  // ── Helpers ──────────────────────────────────────────────────────────────

  Future<Directory> _resolveDownloadDir() async {
    Directory? dir;
    if (Platform.isAndroid) {
      try {
        final ext = await getExternalStorageDirectory();
        if (ext != null) dir = Directory('${ext.path}/StreamSync');
      } catch (_) {}
    }
    dir ??= Directory('${(await getApplicationDocumentsDirectory()).path}/StreamSync');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  String _errorMessage(Object e) {
    final s = e.toString();
    if (s.contains('No space') || s.contains('Disk full'))  return '❌ Not enough storage space!';
    if (s.contains('SocketException') || s.contains('network')) return '❌ Network error. Check your connection.';
    return '❌ Download failed. Try again.';
  }

  /// Show error briefly then clean up — no permanent state left behind.
  Future<void> _showOneShot(int id, String message) async {
    _activeStatus[id] = message;
    notifyListeners();
    await Future.delayed(const Duration(seconds: 3));
    _cleanup(id);
  }

  Future<void> _delayedCleanup(int id) async {
    await Future.delayed(const Duration(seconds: 3));
    _cleanup(id);
  }

  void _cleanup(int id) {
    final taskId = _idToTask.remove(id);
    if (taskId != null) _taskToId.remove(taskId);
    _activeProgress.remove(id);
    _activeStatus.remove(id);
    _activeDetails.remove(id);
    _idToFilePath.remove(id);
    _pendingMeta.remove(id);
    notifyListeners();
  }

  @override
  void dispose() {
    IsolateNameServer.removePortNameMapping(_portName);
    _port.close();
    super.dispose();
  }
}