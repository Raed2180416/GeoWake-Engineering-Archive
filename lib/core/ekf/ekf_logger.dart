// EKF telemetry ring buffer logger (§12 + §22.12).
//
// Produces CSV logs compatible with simulation playground.
// Ring buffer limited to 10 MB per session; oldest records dropped.

import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import 'ekf_types.dart';

/// A single telemetry record for CSV serialization.
class EkfLogEntry {
  EkfLogEntry({
    required this.monotonicMs,
    required this.wallClockMs,
    this.imuAx,
    this.imuAy,
    this.imuAz,
    this.imuGx,
    this.imuGy,
    this.imuGz,
    this.gravityX,
    this.gravityY,
    this.gravityZ,
    this.filteredAx,
    this.filteredAy,
    this.filteredAz,
    this.ekfS,
    this.ekfV,
    this.ekfBiasA,
    this.sigmaS,
    this.sigmaV,
    this.gpsLat,
    this.gpsLng,
    this.gpsAccuracy,
    this.gpsInnovation,
    this.gpsInnovationSigma,
    this.motionState,
    this.zuptEvent,
    this.zuptDwell,
    this.mode,
    this.stationSnapIndex,
    this.eventType,
    this.routeKey,
    this.routeProgress,
    this.routeRemaining,
    this.etaSeconds,
    this.gpsAccepted,
    this.alarmCheck,
  });

  final int monotonicMs;
  final int wallClockMs;

  // Raw IMU (m/s², rad/s)
  final double? imuAx;
  final double? imuAy;
  final double? imuAz;
  final double? imuGx;
  final double? imuGy;
  final double? imuGz;

  // Gravity estimate (unit vector)
  final double? gravityX;
  final double? gravityY;
  final double? gravityZ;

  // Filtered / world-frame accel
  final double? filteredAx;
  final double? filteredAy;
  final double? filteredAz;

  // EKF state
  final double? ekfS;
  final double? ekfV;
  final double? ekfBiasA;
  final double? sigmaS;
  final double? sigmaV;

  // GPS update
  final double? gpsLat;
  final double? gpsLng;
  final double? gpsAccuracy;
  final double? gpsInnovation;
  final double? gpsInnovationSigma;

  // Motion classification
  final String? motionState;

  // ZUPT events
  final String? zuptEvent; // 'candidate', 'confirmed', null
  final double? zuptDwell;

  // Mode and station
  final String? mode;
  final int? stationSnapIndex;

  // Field-validation context (appended so existing CSV consumers remain valid).
  final String? eventType;
  final String? routeKey;
  final double? routeProgress;
  final double? routeRemaining;
  final double? etaSeconds;
  final bool? gpsAccepted;
  final String? alarmCheck;

  static const _headers = [
    'monotonic_ms',
    'wall_clock_ms',
    'imu_ax',
    'imu_ay',
    'imu_az',
    'imu_gx',
    'imu_gy',
    'imu_gz',
    'gravity_x',
    'gravity_y',
    'gravity_z',
    'filtered_ax',
    'filtered_ay',
    'filtered_az',
    'ekf_s',
    'ekf_v',
    'ekf_bias_a',
    'sigma_s',
    'sigma_v',
    'gps_lat',
    'gps_lng',
    'gps_accuracy',
    'gps_innovation',
    'gps_innovation_sigma',
    'motion_state',
    'zupt_event',
    'zupt_dwell',
    'mode',
    'station_snap_index',
    'event_type',
    'route_key',
    'route_progress',
    'route_remaining',
    'eta_seconds',
    'gps_accepted',
    'alarm_check',
  ];

  static String headerLine() => _headers.join(',');

  String toCsvLine() {
    return [
      monotonicMs,
      wallClockMs,
      _fmt(imuAx),
      _fmt(imuAy),
      _fmt(imuAz),
      _fmt(imuGx),
      _fmt(imuGy),
      _fmt(imuGz),
      _fmt(gravityX),
      _fmt(gravityY),
      _fmt(gravityZ),
      _fmt(filteredAx),
      _fmt(filteredAy),
      _fmt(filteredAz),
      _fmt(ekfS),
      _fmt(ekfV),
      _fmt(ekfBiasA),
      _fmt(sigmaS),
      _fmt(sigmaV),
      _fmt(gpsLat),
      _fmt(gpsLng),
      _fmt(gpsAccuracy),
      _fmt(gpsInnovation),
      _fmt(gpsInnovationSigma),
      motionState ?? '',
      zuptEvent ?? '',
      _fmt(zuptDwell),
      mode ?? '',
      stationSnapIndex?.toString() ?? '',
      _csvText(eventType),
      _csvText(routeKey),
      _fmt(routeProgress),
      _fmt(routeRemaining),
      _fmt(etaSeconds),
      gpsAccepted == null ? '' : (gpsAccepted! ? 'true' : 'false'),
      _csvText(alarmCheck),
    ].join(',');
  }

  static String _fmt(double? v) {
    if (v == null || v.isNaN || v.isInfinite) return '';
    return v.toStringAsFixed(6);
  }

  static String _csvText(String? value) =>
      value == null ? '' : value.replaceAll(',', ';').replaceAll('\n', ' ');
}

/// Ring buffer telemetry logger for EKF.
///
/// Writes CSV to app documents directory, capped at [maxSizeBytes].
/// When buffer exceeds limit, oldest half of entries are dropped.
///
/// Usage:
/// ```dart
/// final logger = EkfLogger();
/// await logger.startSession();
/// logger.logImu(entry);
/// await logger.endSession();
/// ```
class EkfLogger {
  EkfLogger({this.maxSizeBytes = 10 * 1024 * 1024});

  /// Maximum buffer size before pruning oldest entries.
  final int maxSizeBytes;

  final List<String> _buffer = [];
  int _bufferSizeBytes = 0;
  bool _sessionActive = false;
  File? _currentFile;
  DateTime? _sessionStart;
  Future<void>? _flushInFlight;
  int _sessionGeneration = 0;

  // At 50 Hz this is roughly five seconds of samples.  Keeping the ring
  // buffer bounded is useful for performance, but waiting until session end
  // would lose the entire tail when an OEM kills the process in a tunnel.
  static const int _autoFlushEntryThreshold = 256;

  /// Enable/disable logging globally (for battery/performance gating).
  bool enabled = true;

  /// Whether a logging session is currently active.
  bool get isActive => _sessionActive;

  /// Current buffer size in bytes.
  int get bufferSizeBytes => _bufferSizeBytes;

  /// Number of entries in buffer.
  int get entryCount => _buffer.length;

  /// Start a new logging session. Creates output file.
  Future<void> startSession() async {
    if (_sessionActive) return;
    // A route can stop and immediately restart on an OEM lifecycle callback.
    // Do not let the new session overwrite the old session's buffer/file while
    // its final append is still in flight.
    final priorFlush = _flushInFlight;
    if (priorFlush != null) {
      await priorFlush;
      if (_sessionActive) return;
    }

    final generation = ++_sessionGeneration;
    _sessionActive = true;
    _sessionStart = DateTime.now();
    _buffer.clear();
    _bufferSizeBytes = 0;

    if (!kIsWeb) {
      try {
        final dir = await getApplicationDocumentsDirectory();
        final logDir = Directory('${dir.path}/ekf_logs');
        if (!await logDir.exists()) {
          await logDir.create(recursive: true);
        }
        final timestamp = _sessionStart!.toIso8601String().replaceAll(':', '-');
        final file = File('${logDir.path}/ekf_$timestamp.csv');
        await file.writeAsString('${EkfLogEntry.headerLine()}\n');
        if (!_sessionActive || generation != _sessionGeneration) {
          // Stop may have won the race while the platform was opening the
          // file.  Do not resurrect a closed session or leak an orphan file.
          try {
            await file.delete();
          } catch (_) {}
          return;
        }
        _currentFile = file;
      } catch (_) {
        // Fail silently; logging is non-critical.
        _currentFile = null;
      }
    }
  }

  /// Log a telemetry entry.
  void log(EkfLogEntry entry) {
    if (!_sessionActive || !enabled) return;
    final line = entry.toCsvLine();
    _buffer.add(line);
    _bufferSizeBytes += line.length + 1; // +1 for newline

    _maybePrune();
    if (_buffer.length >= _autoFlushEntryThreshold) {
      unawaited(_flushToFileSerialized());
    }
  }

  /// Log a raw IMU sample.
  void logImu({
    required Duration timestamp,
    required double ax,
    required double ay,
    required double az,
    required double gx,
    required double gy,
    required double gz,
    List<double>? gravity,
    List<double>? filteredAccel,
    EkfPublicState? ekfState,
    String? motionState,
    EkfMode? mode,
  }) {
    log(EkfLogEntry(
      monotonicMs: timestamp.inMilliseconds,
      wallClockMs: DateTime.now().millisecondsSinceEpoch,
      imuAx: ax,
      imuAy: ay,
      imuAz: az,
      imuGx: gx,
      imuGy: gy,
      imuGz: gz,
      gravityX: gravity?[0],
      gravityY: gravity?[1],
      gravityZ: gravity?[2],
      filteredAx: filteredAccel?[0],
      filteredAy: filteredAccel?[1],
      filteredAz: filteredAccel?[2],
      ekfS: ekfState?.s,
      ekfV: ekfState?.v,
      ekfBiasA: ekfState?.biasA,
      sigmaS: ekfState?.sigmaS,
      sigmaV: ekfState?.sigmaV,
      motionState: motionState,
      mode: mode?.name,
    ));
  }

  /// Log a GPS update event.
  void logGps({
    required Duration timestamp,
    required double lat,
    required double lng,
    required double accuracy,
    double? innovation,
    double? innovationSigma,
    EkfPublicState? ekfState,
    EkfMode? mode,
  }) {
    log(EkfLogEntry(
      monotonicMs: timestamp.inMilliseconds,
      wallClockMs: DateTime.now().millisecondsSinceEpoch,
      gpsLat: lat,
      gpsLng: lng,
      gpsAccuracy: accuracy,
      gpsInnovation: innovation,
      gpsInnovationSigma: innovationSigma,
      ekfS: ekfState?.s,
      ekfV: ekfState?.v,
      ekfBiasA: ekfState?.biasA,
      sigmaS: ekfState?.sigmaS,
      sigmaV: ekfState?.sigmaV,
      mode: mode?.name,
    ));
  }

  /// Log a ZUPT event.
  void logZupt({
    required Duration timestamp,
    required bool confirmed,
    double? dwellSeconds,
    EkfPublicState? ekfState,
    int? stationSnapIndex,
  }) {
    log(EkfLogEntry(
      monotonicMs: timestamp.inMilliseconds,
      wallClockMs: DateTime.now().millisecondsSinceEpoch,
      zuptEvent: confirmed ? 'confirmed' : 'candidate',
      zuptDwell: dwellSeconds,
      ekfS: ekfState?.s,
      ekfV: ekfState?.v,
      ekfBiasA: ekfState?.biasA,
      sigmaS: ekfState?.sigmaS,
      sigmaV: ekfState?.sigmaV,
      stationSnapIndex: stationSnapIndex,
    ));
  }

  /// Log one route/alarm context row during field validation.  This is kept
  /// separate from high-rate IMU rows so diagnostics can be enabled on a real
  /// device without changing the production alarm path or network egress.
  void logContext({
    required Duration timestamp,
    required String eventType,
    String? routeKey,
    double? routeProgress,
    double? routeRemaining,
    double? etaSeconds,
    bool? gpsAccepted,
    String? alarmCheck,
    EkfPublicState? ekfState,
  }) {
    log(EkfLogEntry(
      monotonicMs: timestamp.inMilliseconds,
      wallClockMs: DateTime.now().millisecondsSinceEpoch,
      ekfS: ekfState?.s,
      ekfV: ekfState?.v,
      ekfBiasA: ekfState?.biasA,
      sigmaS: ekfState?.sigmaS,
      sigmaV: ekfState?.sigmaV,
      mode: ekfState?.mode.name,
      eventType: eventType,
      routeKey: routeKey,
      routeProgress: routeProgress,
      routeRemaining: routeRemaining,
      etaSeconds: etaSeconds,
      gpsAccepted: gpsAccepted,
      alarmCheck: alarmCheck,
    ));
  }

  /// End the current session and flush buffer to file.
  Future<void> endSession() async {
    if (!_sessionActive) return;
    _sessionActive = false;
    _sessionGeneration++;

    // A scheduled flush may already be writing a previous snapshot.  Make a
    // second pass for samples appended while that write was in flight.
    await _flushToFileSerialized();
    if (_buffer.isNotEmpty) {
      await _flushToFileSerialized();
    }

    _buffer.clear();
    _bufferSizeBytes = 0;
    _currentFile = null;
    _sessionStart = null;
  }

  /// Flush current buffer to file (for periodic saves).
  Future<void> flush() async {
    if (!_sessionActive) return;
    await _flushToFileSerialized();
    if (_buffer.isNotEmpty) {
      await _flushToFileSerialized();
    }
  }

  /// Get all EKF log files for export.
  Future<List<File>> getLogFiles() async {
    if (kIsWeb) return [];
    try {
      final dir = await getApplicationDocumentsDirectory();
      final logDir = Directory('${dir.path}/ekf_logs');
      if (!await logDir.exists()) return [];
      final files = <File>[];
      await for (final entity in logDir.list()) {
        if (entity is File && entity.path.endsWith('.csv')) {
          files.add(entity);
        }
      }
      files.sort((a, b) => b.path.compareTo(a.path)); // Newest first
      return files;
    } catch (_) {
      return [];
    }
  }

  /// Delete log files older than [days].
  Future<void> cleanupOldLogs({int days = 7}) async {
    if (kIsWeb) return;
    try {
      final cutoff = DateTime.now().subtract(Duration(days: days));
      final files = await getLogFiles();
      for (final file in files) {
        final stat = await file.stat();
        if (stat.modified.isBefore(cutoff)) {
          await file.delete();
        }
      }
    } catch (_) {
      // Fail silently.
    }
  }

  void _maybePrune() {
    if (_bufferSizeBytes <= maxSizeBytes) return;

    // Drop oldest half.
    final dropCount = _buffer.length ~/ 2;
    if (dropCount == 0) return;

    int bytesToRemove = 0;
    for (int i = 0; i < dropCount; i++) {
      bytesToRemove += _buffer[i].length + 1;
    }
    _buffer.removeRange(0, dropCount);
    _bufferSizeBytes = math.max(0, _bufferSizeBytes - bytesToRemove);
  }

  Future<void> _flushToFile() async {
    if (_currentFile == null || _buffer.isEmpty) return;
    // Remove exactly the snapshot being written.  Samples arriving while the
    // platform write is pending stay in the live buffer and cannot be lost.
    final batch = List<String>.from(_buffer);
    _buffer.clear();
    _bufferSizeBytes = 0;
    try {
      final content = '${batch.join('\n')}\n';
      await _currentFile!.writeAsString(content, mode: FileMode.append);
    } catch (_) {
      // Preserve the batch for a later retry when storage is temporarily
      // unavailable.  Diagnostics are non-critical, but silently dropping a
      // process-death tail defeats the field-validation purpose.
      _buffer.insertAll(0, batch);
      _bufferSizeBytes += batch.fold<int>(
        0,
        (sum, line) => sum + line.length + 1,
      );
    }
  }

  /// Serialize file writes so lifecycle flushes and the 5-second auto flush
  /// cannot race and clear each other's samples.
  Future<void> _flushToFileSerialized() {
    final inFlight = _flushInFlight;
    if (inFlight != null) return inFlight;

    final future = _flushToFile();
    _flushInFlight = future;
    future.whenComplete(() {
      if (identical(_flushInFlight, future)) {
        _flushInFlight = null;
      }
      if (_sessionActive && _buffer.length >= _autoFlushEntryThreshold) {
        unawaited(_flushToFileSerialized());
      }
    });
    return future;
  }
}

/// Global EKF logger instance.
final ekfLogger = EkfLogger();
