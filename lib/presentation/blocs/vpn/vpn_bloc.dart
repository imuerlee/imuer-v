import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../domain/entities/vpn_connection.dart';
import '../../../data/datasources/local_database.dart';
import '../../../data/datasources/preferences_manager.dart';
import '../../../data/services/vpn_service.dart';
import 'vpn_event.dart';
import 'vpn_state.dart';

class VpnBloc extends Bloc<VpnEvent, VpnState> {
  final LocalDatabase _database;
  final PreferencesManager _preferences;
  final VpnService _vpnService;
  Timer? _statsTimer;
  DateTime? _connectionStartTime;

  VpnBloc({
    required LocalDatabase database,
    required PreferencesManager preferences,
    VpnService? vpnService,
  })  : _database = database,
        _preferences = preferences,
        _vpnService = vpnService ?? VpnService(),
        super(const VpnState()) {
    on<ConnectVpn>(_onConnectVpn);
    on<DisconnectVpn>(_onDisconnectVpn);
    on<UpdateConnectionStats>(_onUpdateConnectionStats);
    on<UpdateConnectionStatus>(_onUpdateConnectionStatus);
    on<SelectServer>(_onSelectServer);
    on<LoadLastConnection>(_onLoadLastConnection);

    // 监听 VPN 事件
    _vpnService.eventStream.listen((event) {
      _handleVpnEvent(event);
    });
  }

  void _handleVpnEvent(Map<String, dynamic> event) {
    final type = event['type'] as String?;
    switch (type) {
      case 'connected':
        add(const UpdateConnectionStatus(VpnStatus.connected));
        break;
      case 'disconnected':
        add(const UpdateConnectionStatus(VpnStatus.disconnected));
        break;
      case 'error':
        add(UpdateConnectionStatus(VpnStatus.error, errorMessage: event['message'] as String?));
        break;
      case 'stats':
        add(UpdateConnectionStats(
          uploadSpeed: event['uploadSpeed'] as int? ?? 0,
          downloadSpeed: event['downloadSpeed'] as int? ?? 0,
          totalUpload: event['totalUpload'] as int? ?? 0,
          totalDownload: event['totalDownload'] as int? ?? 0,
          duration: Duration.zero,
        ));
        break;
    }
  }

  Future<void> _onConnectVpn(ConnectVpn event, Emitter<VpnState> emit) async {
    print('VpnBloc._onConnectVpn: starting');
    
    emit(state.copyWith(
      isLoading: true,
      connection: state.connection.copyWith(status: VpnStatus.connecting),
    ));

    try {
      // 如果没有指定 serverId，使用选中的服务器
      String serverId = event.serverId;
      if (serverId.isEmpty) {
        serverId = _preferences.selectedServerId ?? '';
      }
      print('VpnBloc._onConnectVpn: serverId = $serverId');
      
      if (serverId.isEmpty) {
        emit(state.copyWith(
          isLoading: false,
          errorMessage: 'Please select a server first',
          connection: state.connection.copyWith(status: VpnStatus.error),
        ));
        return;
      }

      final server = await _database.getServerById(serverId);
      print('VpnBloc._onConnectVpn: server = ${server?.name}, ${server?.address}');
      if (server == null) {
        emit(state.copyWith(
          isLoading: false,
          errorMessage: 'Server not found',
          connection: state.connection.copyWith(status: VpnStatus.error),
        ));
        return;
      }

      // 实际启动 VPN 连接
      print('VpnBloc._onConnectVpn: calling _vpnService.connect');
      final success = await _vpnService.connect(server);
      print('VpnBloc._onConnectVpn: connect result = $success');
      
      if (!success) {
        emit(state.copyWith(
          isLoading: false,
          errorMessage: 'Failed to start VPN service',
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

      _preferences.selectedServerId = serverId;
    } catch (e) {
      print('VpnBloc._onConnectVpn: Exception = $e');
      emit(state.copyWith(
        isLoading: false,
        errorMessage: 'Connection error: ${e.toString()}',
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

    try {
      // 实际断开 VPN 连接
      await _vpnService.disconnect();
    } catch (e) {
      // ignore: avoid_print
      print('Error disconnecting VPN: $e');
    }

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

    _statsTimer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      try {
        // 从原生平台获取实际的统计数据
        final stats = await _vpnService.getStatus();
        
        final uploadSpeed = stats['uploadSpeed'] as int? ?? 0;
        final downloadSpeed = stats['downloadSpeed'] as int? ?? 0;
        final totalUpload = stats['totalUpload'] as int? ?? 0;
        final totalDownload = stats['totalDownload'] as int? ?? 0;

        final duration = _connectionStartTime != null
            ? DateTime.now().difference(_connectionStartTime!)
            : Duration.zero;

        add(UpdateConnectionStats(
          uploadSpeed: uploadSpeed,
          downloadSpeed: downloadSpeed,
          totalUpload: totalUpload,
          totalDownload: totalDownload,
          duration: duration,
        ));
      } catch (e) {
        // 如果获取失败，发送 0 值
        add(UpdateConnectionStats(
          uploadSpeed: 0,
          downloadSpeed: 0,
          totalUpload: 0,
          totalDownload: 0,
          duration: Duration.zero,
        ));
      }
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
