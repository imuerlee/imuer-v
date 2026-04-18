import 'package:equatable/equatable.dart';

enum RoutingMode { geographic, bypassLan, global }

class SettingsState extends Equatable {
  final bool autoConnect;
  final bool autoStart;
  final bool killSwitch;
  final String customDns;
  final String dnsFallback;
  final bool enableDns;
  final bool ipv6Support;
  final bool muxEnabled;
  final int muxCount;
  final RoutingMode routingMode;
  final bool bypassLan;
  final bool debugMode;
  final bool isLoading;

  const SettingsState({
    this.autoConnect = false,
    this.autoStart = false,
    this.killSwitch = false,
    this.customDns = '8.8.8.8',
    this.dnsFallback = '1.1.1.1',
    this.enableDns = false,
    this.ipv6Support = false,
    this.muxEnabled = false,
    this.muxCount = 8,
    this.routingMode = RoutingMode.geographic,
    this.bypassLan = true,
    this.debugMode = false,
    this.isLoading = false,
  });

  SettingsState copyWith({
    bool? autoConnect,
    bool? autoStart,
    bool? killSwitch,
    String? customDns,
    String? dnsFallback,
    bool? enableDns,
    bool? ipv6Support,
    bool? muxEnabled,
    int? muxCount,
    RoutingMode? routingMode,
    bool? bypassLan,
    bool? debugMode,
    bool? isLoading,
  }) {
    return SettingsState(
      autoConnect: autoConnect ?? this.autoConnect,
      autoStart: autoStart ?? this.autoStart,
      killSwitch: killSwitch ?? this.killSwitch,
      customDns: customDns ?? this.customDns,
      dnsFallback: dnsFallback ?? this.dnsFallback,
      enableDns: enableDns ?? this.enableDns,
      ipv6Support: ipv6Support ?? this.ipv6Support,
      muxEnabled: muxEnabled ?? this.muxEnabled,
      muxCount: muxCount ?? this.muxCount,
      routingMode: routingMode ?? this.routingMode,
      bypassLan: bypassLan ?? this.bypassLan,
      debugMode: debugMode ?? this.debugMode,
      isLoading: isLoading ?? this.isLoading,
    );
  }

  @override
  List<Object?> get props => [
        autoConnect,
        autoStart,
        killSwitch,
        customDns,
        dnsFallback,
        enableDns,
        ipv6Support,
        muxEnabled,
        muxCount,
        routingMode,
        bypassLan,
        debugMode,
        isLoading,
      ];
}
