import 'package:equatable/equatable.dart';
import '../../../domain/entities/server_node.dart';

abstract class ServerEvent extends Equatable {
  const ServerEvent();

  @override
  List<Object?> get props => [];
}

class LoadServers extends ServerEvent {
  const LoadServers();
}

class AddServer extends ServerEvent {
  final ServerNode server;

  const AddServer(this.server);

  @override
  List<Object?> get props => [server];
}

class UpdateServer extends ServerEvent {
  final ServerNode server;

  const UpdateServer(this.server);

  @override
  List<Object?> get props => [server];
}

class DeleteServer extends ServerEvent {
  final String serverId;

  const DeleteServer(this.serverId);

  @override
  List<Object?> get props => [serverId];
}

class TestServerLatency extends ServerEvent {
  final String serverId;

  const TestServerLatency(this.serverId);

  @override
  List<Object?> get props => [serverId];
}

class TestAllServersLatency extends ServerEvent {
  const TestAllServersLatency();
}

class ImportServerConfig extends ServerEvent {
  final String config;

  const ImportServerConfig(this.config);

  @override
  List<Object?> get props => [config];
}
