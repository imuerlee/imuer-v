import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';

enum LogLevel {
  debug,
  info,
  warning,
  error,
}

class LogEntry {
  final DateTime timestamp;
  final LogLevel level;
  final String message;
  final String? source;

  LogEntry({
    required this.timestamp,
    required this.level,
    required this.message,
    this.source,
  });

  String get formattedTimestamp {
    return DateFormat('yyyy-MM-dd HH:mm:ss.SSS').format(timestamp);
  }

  String get levelString {
    switch (level) {
      case LogLevel.debug:
        return 'D';
      case LogLevel.info:
        return 'I';
      case LogLevel.warning:
        return 'W';
      case LogLevel.error:
        return 'E';
    }
  }

  String toFormattedString() {
    final sourceStr = source != null ? '[$source] ' : '';
    return '$formattedTimestamp ${levelString}/$sourceStr$message';
  }

  Map<String, dynamic> toJson() {
    return {
      'timestamp': timestamp.toIso8601String(),
      'level': level.name,
      'message': message,
      'source': source,
    };
  }

  factory LogEntry.fromJson(Map<String, dynamic> json) {
    return LogEntry(
      timestamp: DateTime.parse(json['timestamp'] as String),
      level: LogLevel.values.firstWhere(
        (e) => e.name == json['level'],
        orElse: () => LogLevel.info,
      ),
      message: json['message'] as String,
      source: json['source'] as String?,
    );
  }
}

class LogService {
  static final LogService _instance = LogService._internal();
  factory LogService() => _instance;
  LogService._internal();

  static const String _logFileName = 'nebula_vpn.log';
  static const int _maxLogEntries = 1000;
  static const int _maxFileSizeBytes = 5 * 1024 * 1024; // 5MB

  final List<LogEntry> _memoryLogs = [];
  File? _logFile;

  Future<void> initialize() async {
    final directory = await getApplicationDocumentsDirectory();
    _logFile = File('${directory.path}/$_logFileName');
    await _loadRecentLogs();
  }

  Future<void> _loadRecentLogs() async {
    if (_logFile == null || !await _logFile!.exists()) {
      return;
    }

    try {
      final lines = await _logFile!.readAsLines();
      _memoryLogs.clear();
      
      for (final line in lines.reversed.take(_maxLogEntries)) {
        final entry = _parseLogLine(line);
        if (entry != null) {
          _memoryLogs.add(entry);
        }
      }
      
      _memoryLogs.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    } catch (e) {
      // Ignore errors reading logs
    }
  }

  LogEntry? _parseLogLine(String line) {
    try {
      // Format: 2024-01-15 10:30:45.123 D/[source] message
      final regex = RegExp(
        r'^(\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}\.\d{3}) ([DIWE])/\[([^\]]+)\] (.*)$'
      );
      final match = regex.firstMatch(line);
      
      if (match != null) {
        final timestamp = DateFormat('yyyy-MM-dd HH:mm:ss.SSS').parse(match.group(1)!);
        final levelChar = match.group(2)!;
        final source = match.group(3);
        final message = match.group(4)!;
        
        LogLevel level;
        switch (levelChar) {
          case 'D':
            level = LogLevel.debug;
            break;
          case 'I':
            level = LogLevel.info;
            break;
          case 'W':
            level = LogLevel.warning;
            break;
          case 'E':
            level = LogLevel.error;
            break;
          default:
            level = LogLevel.info;
        }
        
        return LogEntry(
          timestamp: timestamp,
          level: level,
          message: message,
          source: source,
        );
      }
      
      // Fallback: try simple parsing
      if (line.length > 23) {
        try {
          final timestamp = DateFormat('yyyy-MM-dd HH:mm:ss.SSS').parse(line.substring(0, 23));
          return LogEntry(
            timestamp: timestamp,
            level: LogLevel.info,
            message: line.substring(23).trim(),
          );
        } catch (_) {}
      }
    } catch (_) {}
    
    return null;
  }

  Future<void> log(LogLevel level, String message, {String? source}) async {
    final entry = LogEntry(
      timestamp: DateTime.now(),
      level: level,
      message: message,
      source: source,
    );

    _memoryLogs.add(entry);
    if (_memoryLogs.length > _maxLogEntries) {
      _memoryLogs.removeAt(0);
    }

    await _writeToFile(entry);
  }

  Future<void> _writeToFile(LogEntry entry) async {
    if (_logFile == null) return;

    try {
      await _logFile!.writeAsString(
        '${entry.toFormattedString()}\n',
        mode: FileMode.append,
      );

      final size = await _logFile!.length();
      if (size > _maxFileSizeBytes) {
        await _rotateLogFile();
      }
    } catch (e) {
      // Ignore write errors
    }
  }

  Future<void> _rotateLogFile() async {
    if (_logFile == null) return;

    try {
      final archivePath = '${_logFile!.path}.archive';
      final archiveFile = File(archivePath);
      
      if (await archiveFile.exists()) {
        await archiveFile.delete();
      }
      
      await _logFile!.rename(archivePath);
      _logFile = File(_logFile!.path);
    } catch (e) {
      // Ignore rotation errors
    }
  }

  List<LogEntry> getLogs({LogLevel? minLevel, int? limit}) {
    var logs = _memoryLogs.toList();
    
    if (minLevel != null) {
      logs = logs.where((log) => log.level.index >= minLevel.index).toList();
    }
    
    if (limit != null && limit > 0) {
      logs = logs.reversed.take(limit).toList().reversed.toList();
    }
    
    return logs;
  }

  List<LogEntry> getLogsSince(DateTime since) {
    return _memoryLogs.where((log) => log.timestamp.isAfter(since)).toList();
  }

  List<LogEntry> searchLogs(String query, {LogLevel? minLevel}) {
    var logs = _memoryLogs.toList();
    
    if (minLevel != null) {
      logs = logs.where((log) => log.level.index >= minLevel.index).toList();
    }
    
    final lowerQuery = query.toLowerCase();
    return logs.where((log) => 
      log.message.toLowerCase().contains(lowerQuery) ||
      (log.source?.toLowerCase().contains(lowerQuery) ?? false)
    ).toList();
  }

  Future<void> clearLogs() async {
    _memoryLogs.clear();
    
    if (_logFile != null && await _logFile!.exists()) {
      await _logFile!.delete();
    }
  }

  Future<String> exportLogs() async {
    final buffer = StringBuffer();
    buffer.writeln('NebulaVPN Logs Export');
    buffer.writeln('Exported at: ${DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now())}');
    buffer.writeln('=' * 60);
    buffer.writeln();

    for (final log in _memoryLogs) {
      buffer.writeln(log.toFormattedString());
    }

    return buffer.toString();
  }

  void d(String message, {String? source}) => log(LogLevel.debug, message, source: source);
  void i(String message, {String? source}) => log(LogLevel.info, message, source: source);
  void w(String message, {String? source}) => log(LogLevel.warning, message, source: source);
  void e(String message, {String? source}) => log(LogLevel.error, message, source: source);
}
