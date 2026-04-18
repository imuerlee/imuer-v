import 'package:equatable/equatable.dart';

class TrafficStats extends Equatable {
  final int uploadBytes;
  final int downloadBytes;
  final int uploadSpeed;
  final int downloadSpeed;
  final Duration duration;
  final DateTime? timestamp;

  const TrafficStats({
    this.uploadBytes = 0,
    this.downloadBytes = 0,
    this.uploadSpeed = 0,
    this.downloadSpeed = 0,
    this.duration = Duration.zero,
    this.timestamp,
  });

  TrafficStats copyWith({
    int? uploadBytes,
    int? downloadBytes,
    int? uploadSpeed,
    int? downloadSpeed,
    Duration? duration,
    DateTime? timestamp,
  }) {
    return TrafficStats(
      uploadBytes: uploadBytes ?? this.uploadBytes,
      downloadBytes: downloadBytes ?? this.downloadBytes,
      uploadSpeed: uploadSpeed ?? this.uploadSpeed,
      downloadSpeed: downloadSpeed ?? this.downloadSpeed,
      duration: duration ?? this.duration,
      timestamp: timestamp ?? this.timestamp,
    );
  }

  @override
  List<Object?> get props => [
        uploadBytes,
        downloadBytes,
        uploadSpeed,
        downloadSpeed,
        duration,
        timestamp,
      ];
}

class DailyTraffic extends Equatable {
  final DateTime date;
  final int uploadBytes;
  final int downloadBytes;

  const DailyTraffic({
    required this.date,
    this.uploadBytes = 0,
    this.downloadBytes = 0,
  });

  @override
  List<Object?> get props => [date, uploadBytes, downloadBytes];
}
