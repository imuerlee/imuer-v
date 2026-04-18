import 'package:equatable/equatable.dart';
import '../../../domain/entities/traffic_stats.dart';

class StatisticsState extends Equatable {
  final TrafficStats currentStats;
  final List<DailyTraffic> dailyTraffic;
  final bool isLoading;
  final String? errorMessage;

  const StatisticsState({
    this.currentStats = const TrafficStats(),
    this.dailyTraffic = const [],
    this.isLoading = false,
    this.errorMessage,
  });

  StatisticsState copyWith({
    TrafficStats? currentStats,
    List<DailyTraffic>? dailyTraffic,
    bool? isLoading,
    String? errorMessage,
  }) {
    return StatisticsState(
      currentStats: currentStats ?? this.currentStats,
      dailyTraffic: dailyTraffic ?? this.dailyTraffic,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
    );
  }

  int get totalBytesThisWeek => dailyTraffic.fold(
        0,
        (sum, traffic) => sum + traffic.uploadBytes + traffic.downloadBytes,
      );

  int get averageDailyBytes {
    if (dailyTraffic.isEmpty) return 0;
    return totalBytesThisWeek ~/ dailyTraffic.length;
  }

  @override
  List<Object?> get props => [currentStats, dailyTraffic, isLoading, errorMessage];
}
