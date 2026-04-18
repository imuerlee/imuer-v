import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../domain/entities/traffic_stats.dart';
import '../../../data/datasources/local_database.dart';
import '../../../data/datasources/preferences_manager.dart';
import 'statistics_event.dart';
import 'statistics_state.dart';

class StatisticsBloc extends Bloc<StatisticsEvent, StatisticsState> {
  final LocalDatabase _database;
  final PreferencesManager _preferences;

  StatisticsBloc({
    required LocalDatabase database,
    required PreferencesManager preferences,
  })  : _database = database,
        _preferences = preferences,
        super(const StatisticsState()) {
    on<LoadStatistics>(_onLoadStatistics);
    on<UpdateRealTimeStats>(_onUpdateRealTimeStats);
    on<LoadHistoricalData>(_onLoadHistoricalData);
  }

  Future<void> _onLoadStatistics(LoadStatistics event, Emitter<StatisticsState> emit) async {
    emit(state.copyWith(isLoading: true));

    try {
      final logs = await _database.getTrafficLogs();
      final dailyTraffic = logs.map((log) => DailyTraffic(
        date: DateTime.parse(log['date'] as String),
        uploadBytes: log['upload_bytes'] as int? ?? 0,
        downloadBytes: log['download_bytes'] as int? ?? 0,
      )).toList();

      emit(state.copyWith(
        isLoading: false,
        dailyTraffic: dailyTraffic,
        currentStats: TrafficStats(
          uploadBytes: _preferences.totalUpload,
          downloadBytes: _preferences.totalDownload,
          timestamp: DateTime.now(),
        ),
      ));
    } catch (e) {
      emit(state.copyWith(
        isLoading: false,
        errorMessage: e.toString(),
      ));
    }
  }

  void _onUpdateRealTimeStats(UpdateRealTimeStats event, Emitter<StatisticsState> emit) {
    emit(state.copyWith(
      currentStats: TrafficStats(
        uploadBytes: event.totalUpload,
        downloadBytes: event.totalDownload,
        uploadSpeed: event.uploadSpeed,
        downloadSpeed: event.downloadSpeed,
        duration: event.duration,
        timestamp: DateTime.now(),
      ),
    ));
  }

  Future<void> _onLoadHistoricalData(LoadHistoricalData event, Emitter<StatisticsState> emit) async {
    try {
      final logs = await _database.getTrafficLogs(days: event.days);
      final dailyTraffic = logs.map((log) => DailyTraffic(
        date: DateTime.parse(log['date'] as String),
        uploadBytes: log['upload_bytes'] as int? ?? 0,
        downloadBytes: log['download_bytes'] as int? ?? 0,
      )).toList();

      emit(state.copyWith(dailyTraffic: dailyTraffic));
    } catch (e) {
      emit(state.copyWith(errorMessage: e.toString()));
    }
  }
}
