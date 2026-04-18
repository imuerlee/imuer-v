import 'package:equatable/equatable.dart';
import '../../../domain/entities/vpn_connection.dart';

abstract class VpnEvent extends Equatable {
  const VpnEvent();

  @override
  List<Object?> get props => [];
}

class ConnectVpn extends VpnEvent {
  final String serverId;

  const ConnectVpn(this.serverId);

  @override
  List<Object?> get props => [serverId];
}

class DisconnectVpn extends VpnEvent {
  const DisconnectVpn();
}

class UpdateConnectionStats extends VpnEvent {
  final int? uploadSpeed;
  final int? downloadSpeed;
  final int? totalUpload;
  final int? totalDownload;
  final Duration? duration;

  const UpdateConnectionStats({
    this.uploadSpeed,
    this.downloadSpeed,
    this.totalUpload,
    this.totalDownload,
    this.duration,
  });

  @override
  List<Object?> get props => [
        uploadSpeed,
        downloadSpeed,
        totalUpload,
        totalDownload,
        duration,
      ];
}

class UpdateConnectionStatus extends VpnEvent {
  final VpnStatus status;
  final String? errorMessage;

  const UpdateConnectionStatus(this.status, {this.errorMessage});

  @override
  List<Object?> get props => [status, errorMessage];
}

class SelectServer extends VpnEvent {
  final String serverId;

  const SelectServer(this.serverId);

  @override
  List<Object?> get props => [serverId];
}

class LoadLastConnection extends VpnEvent {
  const LoadLastConnection();
}
