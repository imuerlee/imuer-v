import 'package:equatable/equatable.dart';

abstract class StatisticsEvent extends Equatable {
  const StatisticsEvent();

  @override
  List<Object?> get props => [];
}

class LoadStatistics extends StatisticsEvent {
  const LoadStatistics();
}

class UpdateRealTimeStats extends StatisticsEvent {
  final int uploadSpeed;
  final int downloadSpeed;
  final int totalUpload;
  final int totalDownload;
  final Duration duration;

  const UpdateRealTimeStats({
    required this.uploadSpeed,
    required this.downloadSpeed,
    required this.totalUpload,
    required this.totalDownload,
    required this.duration,
  });

  @override
  List<Object?> get props => [uploadSpeed, downloadSpeed, totalUpload, totalDownload, duration];
}

class LoadHistoricalData extends StatisticsEvent {
  final int days;

  const LoadHistoricalData({this.days = 7});

  @override
  List<Object?> get props => [days];
}
