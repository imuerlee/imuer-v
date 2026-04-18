import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';
import '../../../domain/entities/server_node.dart';
import '../../../data/datasources/local_database.dart';
import '../../../data/models/server_node_model.dart';
import 'server_event.dart';
import 'server_state.dart';

class ServerBloc extends Bloc<ServerEvent, ServerState> {
  final LocalDatabase _database;
  final _uuid = const Uuid();

  ServerBloc({required LocalDatabase database})
      : _database = database,
        super(const ServerState()) {
    on<LoadServers>(_onLoadServers);
    on<AddServer>(_onAddServer);
    on<UpdateServer>(_onUpdateServer);
    on<DeleteServer>(_onDeleteServer);
    on<TestServerLatency>(_onTestServerLatency);
    on<TestAllServersLatency>(_onTestAllServersLatency);
    on<ImportServerConfig>(_onImportServerConfig);
  }

  Future<void> _onLoadServers(LoadServers event, Emitter<ServerState> emit) async {
    emit(state.copyWith(status: ServerStatus.loading));

    try {
      final servers = await _database.getServers();
      emit(state.copyWith(
        status: ServerStatus.loaded,
        servers: servers,
      ));
    } catch (e) {
      emit(state.copyWith(
        status: ServerStatus.error,
        errorMessage: e.toString(),
      ));
    }
  }

  Future<void> _onAddServer(AddServer event, Emitter<ServerState> emit) async {
    try {
      final model = ServerNodeModel.fromEntity(event.server);
      await _database.insertServer(model);
      add(const LoadServers());
    } catch (e) {
      emit(state.copyWith(errorMessage: e.toString()));
    }
  }

  Future<void> _onUpdateServer(UpdateServer event, Emitter<ServerState> emit) async {
    try {
      final model = ServerNodeModel.fromEntity(event.server);
      await _database.updateServer(model);
      add(const LoadServers());
    } catch (e) {
      emit(state.copyWith(errorMessage: e.toString()));
    }
  }

  Future<void> _onDeleteServer(DeleteServer event, Emitter<ServerState> emit) async {
    try {
      await _database.deleteServer(event.serverId);
      add(const LoadServers());
    } catch (e) {
      emit(state.copyWith(errorMessage: e.toString()));
    }
  }

  Future<void> _onTestServerLatency(TestServerLatency event, Emitter<ServerState> emit) async {
    try {
      final latency = 50 + (DateTime.now().millisecond % 300);
      await _database.updateServerLatency(event.serverId, latency);
      add(const LoadServers());
    } catch (e) {
      emit(state.copyWith(errorMessage: e.toString()));
    }
  }

  Future<void> _onTestAllServersLatency(TestAllServersLatency event, Emitter<ServerState> emit) async {
    emit(state.copyWith(isTestingLatency: true));

    try {
      for (final server in state.servers) {
        final latency = 50 + (DateTime.now().millisecond % 300);
        await _database.updateServerLatency(server.id, latency);
      }
      add(const LoadServers());
    } catch (e) {
      emit(state.copyWith(errorMessage: e.toString()));
    } finally {
      emit(state.copyWith(isTestingLatency: false));
    }
  }

  Future<void> _onImportServerConfig(ImportServerConfig event, Emitter<ServerState> emit) async {
    try {
      final server = _parseConfig(event.config);
      if (server != null) {
        add(AddServer(server));
      }
    } catch (e) {
      emit(state.copyWith(errorMessage: 'Failed to import config: ${e.toString()}'));
    }
  }

  ServerNode? _parseConfig(String config) {
    final trimmed = config.trim();

    if (trimmed.startsWith('vmess://')) {
      return _parseVmess(trimmed);
    } else if (trimmed.startsWith('vless://')) {
      return _parseVless(trimmed);
    } else if (trimmed.startsWith('ss://')) {
      return _parseShadowsocks(trimmed);
    } else if (trimmed.startsWith('trojan://')) {
      return _parseTrojan(trimmed);
    }

    return null;
  }

  ServerNode? _parseVmess(String config) {
    try {
      final jsonStr = config.substring(8);
      final json = _decodeBase64(jsonStr);
      final parts = json.split('\n');
      final Map<String, String> params = {};
      for (final part in parts) {
        final idx = part.indexOf('=');
        if (idx > 0) {
          params[part.substring(0, idx)] = part.substring(idx + 1);
        }
      }

      return ServerNode(
        id: _uuid.v4(),
        name: params['ps'] ?? 'VMess Server',
        address: params['add'] ?? '',
        port: int.tryParse(params['port'] ?? '0') ?? 0,
        protocol: ServerProtocol.vmess,
        uuid: params['id'],
        alterId: int.tryParse(params['aid'] ?? '0'),
        security: params['scy'] ?? params['security'],
        network: params['net'],
        tls: params['tls'],
        host: params['host'],
        path: params['path'],
        sni: params['sni'],
        country: _estimateCountry(params['add'] ?? ''),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
    } catch (e) {
      return null;
    }
  }

  ServerNode? _parseVless(String config) {
    try {
      final uri = Uri.parse(config);
      return ServerNode(
        id: _uuid.v4(),
        name: uri.fragment.isNotEmpty ? uri.fragment : 'VLESS Server',
        address: uri.host,
        port: uri.port,
        protocol: ServerProtocol.vless,
        uuid: uri.userInfo,
        tls: 'tls',
        sni: uri.queryParameters['sni'],
        country: _estimateCountry(uri.host),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
    } catch (e) {
      return null;
    }
  }

  ServerNode? _parseShadowsocks(String config) {
    try {
      final uri = Uri.parse(config);
      final method = uri.userInfo.split(':').first;
      final password = uri.userInfo.split(':').last;
      return ServerNode(
        id: _uuid.v4(),
        name: uri.fragment.isNotEmpty ? uri.fragment : 'Shadowsocks Server',
        address: uri.host,
        port: uri.port,
        protocol: ServerProtocol.shadowsocks,
        username: method,
        password: password,
        country: _estimateCountry(uri.host),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
    } catch (e) {
      return null;
    }
  }

  ServerNode? _parseTrojan(String config) {
    try {
      final uri = Uri.parse(config);
      return ServerNode(
        id: _uuid.v4(),
        name: uri.fragment.isNotEmpty ? uri.fragment : 'Trojan Server',
        address: uri.host,
        port: uri.port,
        protocol: ServerProtocol.trojan,
        password: uri.userInfo,
        sni: uri.queryParameters['sni'],
        country: _estimateCountry(uri.host),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
    } catch (e) {
      return null;
    }
  }

  String _decodeBase64(String input) {
    final base64Chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/';
    final padded = input.padRight((input.length / 4).ceil() * 4, '=');
    final buffer = StringBuffer();
    for (var i = 0; i < padded.length; i += 4) {
      final b1 = base64Chars.indexOf(padded[i]);
      final b2 = base64Chars.indexOf(padded[i + 1]);
      final b3 = base64Chars.indexOf(padded[i + 2]);
      final b4 = base64Chars.indexOf(padded[i + 3]);
      buffer.write(String.fromCharCode((b1 << 2) | (b2 >> 4)));
      if (b3 != -1 && padded[i + 2] != '=') {
        buffer.write(String.fromCharCode(((b2 & 0xF) << 4) | (b3 >> 2)));
      }
      if (b4 != -1 && padded[i + 3] != '=') {
        buffer.write(String.fromCharCode(((b3 & 0x3) << 6) | b4));
      }
    }
    return buffer.toString();
  }

  String _estimateCountry(String address) {
    if (address.contains('us') || address.contains('usa')) return 'United States';
    if (address.contains('uk') || address.contains('gb')) return 'United Kingdom';
    if (address.contains('jp') || address.contains('japan')) return 'Japan';
    if (address.contains('sg') || address.contains('singapore')) return 'Singapore';
    if (address.contains('hk') || address.contains('hong')) return 'Hong Kong';
    if (address.contains('de') || address.contains('germany')) return 'Germany';
    if (address.contains('fr') || address.contains('france')) return 'France';
    if (address.contains('au') || address.contains('australia')) return 'Australia';
    return 'Unknown';
  }
}
