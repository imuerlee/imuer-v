import 'dart:async';
import 'dart:io';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../data/datasources/local_database.dart';
import '../../../data/models/server_node_model.dart';
import '../../../data/services/config_parser_service.dart';
import '../../../data/services/geo_location_service.dart';
import '../../../injection.dart';
import 'server_event.dart';
import 'server_state.dart';

class ServerBloc extends Bloc<ServerEvent, ServerState> {
  final LocalDatabase _database;
  final GeoLocationService _geoService;

  ServerBloc({required LocalDatabase database})
      : _database = database,
        _geoService = getIt<GeoLocationService>(),
        super(const ServerState()) {
    on<LoadServers>(_onLoadServers);
    on<AddServer>(_onAddServer);
    on<UpdateServer>(_onUpdateServer);
    on<DeleteServer>(_onDeleteServer);
    on<TestServerLatency>(_onTestServerLatency);
    on<TestAllServersLatency>(_onTestAllServersLatency);
    on<ImportServerConfig>(_onImportServerConfig);
    on<LookupServerLocation>(_onLookupServerLocation);
  }

  Future<void> _onLoadServers(LoadServers event, Emitter<ServerState> emit) async {
    emit(state.copyWith(status: ServerStatus.loading));

    try {
      final servers = await _database.getServers();
      
      // 查找位置未知的服务器的地理位置
      for (var server in servers) {
        if (server.country == null || server.country == 'Unknown' || server.country!.isEmpty) {
          try {
            final updatedServer = await _geoService.lookupServerLocation(server);
            if (updatedServer.country != null && updatedServer.country != 'Unknown') {
              await _database.updateServer(ServerNodeModel.fromEntity(updatedServer));
            }
          } catch (_) {
            // 忽略地理位置查询错误
          }
        }
      }
      
      // 重新加载服务器（带更新后的位置）
      final updatedServers = await _database.getServers();
      emit(state.copyWith(
        status: ServerStatus.loaded,
        servers: updatedServers,
      ));
    } catch (e) {
      emit(state.copyWith(
        status: ServerStatus.error,
        errorMessage: 'Database error: ${e.toString()}',
      ));
    }
  }

  Future<void> _onAddServer(AddServer event, Emitter<ServerState> emit) async {
    try {
      final model = ServerNodeModel.fromEntity(event.server);
      final success = await _database.insertServer(model);
      if (success) {
        add(const LoadServers());
      } else {
        emit(state.copyWith(
          status: ServerStatus.error,
          errorMessage: 'Failed to insert server into database',
        ));
      }
    } catch (e) {
      emit(state.copyWith(
        status: ServerStatus.error,
        errorMessage: 'Failed to add server: ${e.toString()}',
      ));
    }
  }

  Future<void> _onUpdateServer(UpdateServer event, Emitter<ServerState> emit) async {
    try {
      final model = ServerNodeModel.fromEntity(event.server);
      await _database.updateServer(model);
      add(const LoadServers());
    } catch (e) {
      emit(state.copyWith(
        status: ServerStatus.error,
        errorMessage: 'Failed to update server: ${e.toString()}',
      ));
    }
  }

  Future<void> _onDeleteServer(DeleteServer event, Emitter<ServerState> emit) async {
    try {
      await _database.deleteServer(event.serverId);
      add(const LoadServers());
    } catch (e) {
      emit(state.copyWith(
        status: ServerStatus.error,
        errorMessage: 'Failed to delete server: ${e.toString()}',
      ));
    }
  }

  Future<void> _onTestServerLatency(TestServerLatency event, Emitter<ServerState> emit) async {
    try {
      final server = await _database.getServerById(event.serverId);
      if (server == null) {
        emit(state.copyWith(
          status: ServerStatus.error,
          errorMessage: 'Server not found',
        ));
        return;
      }

      // 实际测试 TCP 连接延迟
      final latency = await _testTcpLatency(server.address, server.port);
      
      if (latency > 0) {
        await _database.updateServerLatency(event.serverId, latency);
        add(const LoadServers());
      } else {
        emit(state.copyWith(
          status: ServerStatus.error,
          errorMessage: 'Connection timeout',
        ));
      }
    } catch (e) {
      emit(state.copyWith(
        status: ServerStatus.error,
        errorMessage: 'Failed to test latency: ${e.toString()}',
      ));
    }
  }

  Future<void> _onTestAllServersLatency(TestAllServersLatency event, Emitter<ServerState> emit) async {
    emit(state.copyWith(isTestingLatency: true));

    try {
      for (final server in state.servers) {
        final latency = await _testTcpLatency(server.address, server.port);
        if (latency > 0) {
          await _database.updateServerLatency(server.id, latency);
        }
      }
      add(const LoadServers());
    } catch (e) {
      emit(state.copyWith(
        status: ServerStatus.error,
        errorMessage: 'Failed to test latency: ${e.toString()}',
      ));
    } finally {
      emit(state.copyWith(isTestingLatency: false));
    }
  }

  /// 测试 TCP 连接延迟
  Future<int> _testTcpLatency(String host, int port) async {
    try {
      final stopwatch = Stopwatch()..start();
      final socket = await Socket.connect(host, port, timeout: const Duration(seconds: 5));
      await socket.close();
      return stopwatch.elapsedMilliseconds;
    } catch (e) {
      return -1;
    }
  }

  Future<void> _onImportServerConfig(ImportServerConfig event, Emitter<ServerState> emit) async {
    try {
      final servers = ConfigParserService.parseConfig(event.config);
      if (servers.isNotEmpty) {
        for (final server in servers) {
          final model = ServerNodeModel.fromEntity(server);
          await _database.insertServer(model);
        }
        add(LoadServers());
      }
    } catch (e) {
      emit(state.copyWith(errorMessage: 'Failed to import config: ${e.toString()}'));
    }
  }

  Future<void> _onLookupServerLocation(LookupServerLocation event, Emitter<ServerState> emit) async {
    try {
      final server = await _database.getServerById(event.serverId);
      if (server == null) return;

      final updatedServer = await _geoService.lookupServerLocation(server);
      if (updatedServer.country != null && updatedServer.country != 'Unknown') {
        await _database.updateServer(ServerNodeModel.fromEntity(updatedServer));
        add(const LoadServers());
      }
    } catch (_) {
      // 忽略地理位置查询错误
    }
  }

}
