import 'package:equatable/equatable.dart';

class SettingsState extends Equatable {
  final bool autoConnect;
  final bool autoStart;
  final bool killSwitch;
  final String customDns;
  final bool isLoading;

  const SettingsState({
    this.autoConnect = false,
    this.autoStart = false,
    this.killSwitch = false,
    this.customDns = '8.8.8.8',
    this.isLoading = false,
  });

  SettingsState copyWith({
    bool? autoConnect,
    bool? autoStart,
    bool? killSwitch,
    String? customDns,
    bool? isLoading,
  }) {
    return SettingsState(
      autoConnect: autoConnect ?? this.autoConnect,
      autoStart: autoStart ?? this.autoStart,
      killSwitch: killSwitch ?? this.killSwitch,
      customDns: customDns ?? this.customDns,
      isLoading: isLoading ?? this.isLoading,
    );
  }

  @override
  List<Object?> get props => [autoConnect, autoStart, killSwitch, customDns, isLoading];
}
