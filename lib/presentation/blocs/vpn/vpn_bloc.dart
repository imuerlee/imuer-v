import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../domain/entities/vpn_connection.dart';
import '../../../data/datasources/local_database.dart';
import '../../../data/datasources/preferences_manager.dart';
import 'vpn_event.dart';
import 'vpn_state.dart';

class VpnBloc extends Bloc<VpnEvent, VpnState> {
  final LocalDatabase _database;
  final PreferencesManager _preferences;
  Timer? _statsTimer;
  DateTime? _connectionStartTime;

  VpnBloc({
    required LocalDatabase database,
    required PreferencesManager preferences,
  })  : _database = database,
        _preferences = preferences,
        super(const VpnState()) {
    on<ConnectVpn>(_onConnectVpn);
    on<DisconnectVpn>(_onDisconnectVpn);
    on<UpdateConnectionStats>(_onUpdateConnectionStats);
    on<UpdateConnectionStatus>(_onUpdateConnectionStatus);
    on<SelectServer>(_onSelectServer);
    on<LoadLastConnection>(_onLoadLastConnection);
  }

  Future<void> _onConnectVpn(ConnectVpn event, Emitter<VpnState> emit) async {
    emit(state.copyWith(
      isLoading: true,
      connection: state.connection.copyWith(status: VpnStatus.connecting),
    ));

    try {
      final server = await _database.getServerById(event.serverId);
      if (server == null) {
        emit(state.copyWith(
          isLoading: false,
          errorMessage: 'Server not found',
          connection: state.connection.copyWith(status: VpnStatus.error),
        ));
        return;
      }

      _connectionStartTime = DateTime.now();
      _startStatsTimer();

      emit(state.copyWith(
        isLoading: false,
        connection: state.connection.copyWith(
          status: VpnStatus.connected,
          serverName: server.name,
          serverAddress: server.address,
          serverCountry: server.country,
          serverCity: server.city,
          connectedAt: _connectionStartTime,
        ),
      ));

      _preferences.selectedServerId = event.serverId;
    } catch (e) {
      emit(state.copyWith(
        isLoading: false,
        errorMessage: e.toString(),
        connection: state.connection.copyWith(status: VpnStatus.error),
      ));
    }
  }

  Future<void> _onDisconnectVpn(DisconnectVpn event, Emitter<VpnState> emit) async {
    _stopStatsTimer();

    emit(state.copyWith(
      isLoading: true,
      connection: state.connection.copyWith(status: VpnStatus.disconnecting),
    ));

    await Future.delayed(const Duration(milliseconds: 500));

    emit(state.copyWith(
      isLoading: false,
      connection: const VpnConnection(status: VpnStatus.disconnected),
    ));
  }

  void _onUpdateConnectionStats(UpdateConnectionStats event, Emitter<VpnState> emit) {
    if (_connectionStartTime == null) return;

    final duration = DateTime.now().difference(_connectionStartTime!);

    emit(state.copyWith(
      connection: state.connection.copyWith(
        uploadSpeed: event.uploadSpeed,
        downloadSpeed: event.downloadSpeed,
        totalUpload: event.totalUpload,
        totalDownload: event.totalDownload,
        connectionDuration: duration,
      ),
    ));
  }

  void _onUpdateConnectionStatus(UpdateConnectionStatus event, Emitter<VpnState> emit) {
    emit(state.copyWith(
      connection: state.connection.copyWith(
        status: event.status,
        errorMessage: event.errorMessage,
      ),
    ));
  }

  Future<void> _onSelectServer(SelectServer event, Emitter<VpnState> emit) async {
    final server = await _database.getServerById(event.serverId);
    if (server != null) {
      emit(state.copyWith(
        connection: state.connection.copyWith(
          serverName: server.name,
          serverAddress: server.address,
          serverCountry: server.country,
          serverCity: server.city,
        ),
      ));
    }
  }

  Future<void> _onLoadLastConnection(LoadLastConnection event, Emitter<VpnState> emit) async {
    final lastServerId = _preferences.selectedServerId;
    if (lastServerId != null) {
      final server = await _database.getServerById(lastServerId);
      if (server != null) {
        emit(state.copyWith(
          connection: state.connection.copyWith(
            serverName: server.name,
            serverAddress: server.address,
            serverCountry: server.country,
            serverCity: server.city,
          ),
        ));
      }
    }
  }

  void _startStatsTimer() {
    _statsTimer?.cancel();
    int uploadBytes = 0;
    int downloadBytes = 0;

    _statsTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      uploadBytes += (50 + (DateTime.now().millisecond % 100));
      downloadBytes += (100 + (DateTime.now().millisecond % 200));

      final duration = _connectionStartTime != null
          ? DateTime.now().difference(_connectionStartTime!)
          : Duration.zero;

      add(UpdateConnectionStats(
        uploadSpeed: 5000 + (DateTime.now().second * 100),
        downloadSpeed: 15000 + (DateTime.now().second * 500),
        totalUpload: uploadBytes,
        totalDownload: downloadBytes,
        duration: duration,
      ));
    });
  }

  void _stopStatsTimer() {
    _statsTimer?.cancel();
    _statsTimer = null;
    _connectionStartTime = null;
  }

  @override
  Future<void> close() {
    _stopStatsTimer();
    return super.close();
  }
}
