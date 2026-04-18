import 'package:equatable/equatable.dart';

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
