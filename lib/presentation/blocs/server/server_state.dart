import 'package:equatable/equatable.dart';
import '../../../domain/entities/server_node.dart';

enum ServerStatus { initial, loading, loaded, error }

class ServerState extends Equatable {
  final ServerStatus status;
  final List<ServerNode> servers;
  final String? errorMessage;
  final bool isTestingLatency;

  const ServerState({
    this.status = ServerStatus.initial,
    this.servers = const [],
    this.errorMessage,
    this.isTestingLatency = false,
  });

  ServerState copyWith({
    ServerStatus? status,
    List<ServerNode>? servers,
    String? errorMessage,
    bool? isTestingLatency,
  }) {
    return ServerState(
      status: status ?? this.status,
      servers: servers ?? this.servers,
      errorMessage: errorMessage,
      isTestingLatency: isTestingLatency ?? this.isTestingLatency,
    );
  }

  List<ServerNode> get serversByLatency {
    final sorted = List<ServerNode>.from(servers);
    sorted.sort((a, b) => (a.latency ?? 9999).compareTo(b.latency ?? 9999));
    return sorted;
  }

  List<ServerNode> get serversByCountry {
    final sorted = List<ServerNode>.from(servers);
    sorted.sort((a, b) => (a.country ?? '').compareTo(b.country ?? ''));
    return sorted;
  }

  @override
  List<Object?> get props => [status, servers, errorMessage, isTestingLatency];
}
