import 'package:equatable/equatable.dart';

enum VpnStatus {
  disconnected,
  connecting,
  connected,
  disconnecting,
  error,
}

class VpnConnection extends Equatable {
  final VpnStatus status;
  final String? serverName;
  final String? serverAddress;
  final String? serverCountry;
  final String? serverCity;
  final int? ping;
  final int? uploadSpeed;
  final int? downloadSpeed;
  final int? totalUpload;
  final int? totalDownload;
  final Duration? connectionDuration;
  final String? errorMessage;
  final DateTime? connectedAt;

  const VpnConnection({
    this.status = VpnStatus.disconnected,
    this.serverName,
    this.serverAddress,
    this.serverCountry,
    this.serverCity,
    this.ping,
    this.uploadSpeed,
    this.downloadSpeed,
    this.totalUpload,
    this.totalDownload,
    this.connectionDuration,
    this.errorMessage,
    this.connectedAt,
  });

  VpnConnection copyWith({
    VpnStatus? status,
    String? serverName,
    String? serverAddress,
    String? serverCountry,
    String? serverCity,
    int? ping,
    int? uploadSpeed,
    int? downloadSpeed,
    int? totalUpload,
    int? totalDownload,
    Duration? connectionDuration,
    String? errorMessage,
    DateTime? connectedAt,
  }) {
    return VpnConnection(
      status: status ?? this.status,
      serverName: serverName ?? this.serverName,
      serverAddress: serverAddress ?? this.serverAddress,
      serverCountry: serverCountry ?? this.serverCountry,
      serverCity: serverCity ?? this.serverCity,
      ping: ping ?? this.ping,
      uploadSpeed: uploadSpeed ?? this.uploadSpeed,
      downloadSpeed: downloadSpeed ?? this.downloadSpeed,
      totalUpload: totalUpload ?? this.totalUpload,
      totalDownload: totalDownload ?? this.totalDownload,
      connectionDuration: connectionDuration ?? this.connectionDuration,
      errorMessage: errorMessage ?? this.errorMessage,
      connectedAt: connectedAt ?? this.connectedAt,
    );
  }

  @override
  List<Object?> get props => [
        status,
        serverName,
        serverAddress,
        serverCountry,
        serverCity,
        ping,
        uploadSpeed,
        downloadSpeed,
        totalUpload,
        totalDownload,
        connectionDuration,
        errorMessage,
        connectedAt,
      ];
}
