import 'package:equatable/equatable.dart';
import '../../../domain/entities/vpn_connection.dart';

class VpnState extends Equatable {
  final VpnConnection connection;
  final bool isLoading;
  final String? errorMessage;

  const VpnState({
    this.connection = const VpnConnection(),
    this.isLoading = false,
    this.errorMessage,
  });

  VpnState copyWith({
    VpnConnection? connection,
    bool? isLoading,
    String? errorMessage,
  }) {
    return VpnState(
      connection: connection ?? this.connection,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
    );
  }

  @override
  List<Object?> get props => [connection, isLoading, errorMessage];
}
