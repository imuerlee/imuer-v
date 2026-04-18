import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../data/datasources/preferences_manager.dart';
import 'settings_event.dart';
import 'settings_state.dart';

class SettingsBloc extends Bloc<SettingsEvent, SettingsState> {
  final PreferencesManager _preferences;

  SettingsBloc({required PreferencesManager preferences})
      : _preferences = preferences,
        super(const SettingsState()) {
    on<LoadSettings>(_onLoadSettings);
    on<ToggleAutoConnect>(_onToggleAutoConnect);
    on<ToggleAutoStart>(_onToggleAutoStart);
    on<ToggleKillSwitch>(_onToggleKillSwitch);
    on<UpdateDns>(_onUpdateDns);
  }

  Future<void> _onLoadSettings(LoadSettings event, Emitter<SettingsState> emit) async {
    emit(state.copyWith(isLoading: true));

    emit(state.copyWith(
      isLoading: false,
      autoConnect: _preferences.autoConnect,
      autoStart: _preferences.autoStart,
      killSwitch: _preferences.killSwitch,
    ));
  }

  void _onToggleAutoConnect(ToggleAutoConnect event, Emitter<SettingsState> emit) {
    _preferences.autoConnect = event.enabled;
    emit(state.copyWith(autoConnect: event.enabled));
  }

  void _onToggleAutoStart(ToggleAutoStart event, Emitter<SettingsState> emit) {
    _preferences.autoStart = event.enabled;
    emit(state.copyWith(autoStart: event.enabled));
  }

  void _onToggleKillSwitch(ToggleKillSwitch event, Emitter<SettingsState> emit) {
    _preferences.killSwitch = event.enabled;
    emit(state.copyWith(killSwitch: event.enabled));
  }

  void _onUpdateDns(UpdateDns event, Emitter<SettingsState> emit) {
    emit(state.copyWith(customDns: event.dns));
  }
}
