import 'package:equatable/equatable.dart';
import 'settings_state.dart';

abstract class SettingsEvent extends Equatable {
  const SettingsEvent();

  @override
  List<Object?> get props => [];
}

class LoadSettings extends SettingsEvent {
  const LoadSettings();
}

class ToggleAutoConnect extends SettingsEvent {
  final bool enabled;

  const ToggleAutoConnect(this.enabled);

  @override
  List<Object?> get props => [enabled];
}

class ToggleAutoStart extends SettingsEvent {
  final bool enabled;

  const ToggleAutoStart(this.enabled);

  @override
  List<Object?> get props => [enabled];
}

class ToggleKillSwitch extends SettingsEvent {
  final bool enabled;

  const ToggleKillSwitch(this.enabled);

  @override
  List<Object?> get props => [enabled];
}

class UpdateDns extends SettingsEvent {
  final String dns;

  const UpdateDns(this.dns);

  @override
  List<Object?> get props => [dns];
}

class UpdateDnsFallback extends SettingsEvent {
  final String dns;

  const UpdateDnsFallback(this.dns);

  @override
  List<Object?> get props => [dns];
}

class ToggleEnableDns extends SettingsEvent {
  final bool enabled;

  const ToggleEnableDns(this.enabled);

  @override
  List<Object?> get props => [enabled];
}

class ToggleIpv6Support extends SettingsEvent {
  final bool enabled;

  const ToggleIpv6Support(this.enabled);

  @override
  List<Object?> get props => [enabled];
}

class ToggleMux extends SettingsEvent {
  final bool enabled;

  const ToggleMux(this.enabled);

  @override
  List<Object?> get props => [enabled];
}

class UpdateMuxCount extends SettingsEvent {
  final int count;

  const UpdateMuxCount(this.count);

  @override
  List<Object?> get props => [count];
}

class UpdateRoutingMode extends SettingsEvent {
  final RoutingMode mode;

  const UpdateRoutingMode(this.mode);

  @override
  List<Object?> get props => [mode];
}

class ToggleBypassLan extends SettingsEvent {
  final bool enabled;

  const ToggleBypassLan(this.enabled);

  @override
  List<Object?> get props => [enabled];
}

class ToggleDebugMode extends SettingsEvent {
  final bool enabled;

  const ToggleDebugMode(this.enabled);

  @override
  List<Object?> get props => [enabled];
}
