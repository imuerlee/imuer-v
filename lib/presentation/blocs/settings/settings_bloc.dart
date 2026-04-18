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
    on<UpdateDnsFallback>(_onUpdateDnsFallback);
    on<ToggleEnableDns>(_onToggleEnableDns);
    on<ToggleIpv6Support>(_onToggleIpv6Support);
    on<ToggleMux>(_onToggleMux);
    on<UpdateMuxCount>(_onUpdateMuxCount);
    on<UpdateRoutingMode>(_onUpdateRoutingMode);
    on<ToggleBypassLan>(_onToggleBypassLan);
    on<ToggleDebugMode>(_onToggleDebugMode);
  }

  Future<void> _onLoadSettings(LoadSettings event, Emitter<SettingsState> emit) async {
    emit(state.copyWith(isLoading: true));

    emit(state.copyWith(
      isLoading: false,
      autoConnect: _preferences.autoConnect,
      autoStart: _preferences.autoStart,
      killSwitch: _preferences.killSwitch,
      customDns: _preferences.customDns,
      dnsFallback: _preferences.dnsFallback,
      enableDns: _preferences.enableDns,
      ipv6Support: _preferences.ipv6Support,
      muxEnabled: _preferences.muxEnabled,
      muxCount: _preferences.muxCount,
      routingMode: _preferences.routingMode,
      bypassLan: _preferences.bypassLan,
      debugMode: _preferences.debugMode,
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
    _preferences.customDns = event.dns;
    emit(state.copyWith(customDns: event.dns));
  }

  void _onUpdateDnsFallback(UpdateDnsFallback event, Emitter<SettingsState> emit) {
    _preferences.dnsFallback = event.dns;
    emit(state.copyWith(dnsFallback: event.dns));
  }

  void _onToggleEnableDns(ToggleEnableDns event, Emitter<SettingsState> emit) {
    _preferences.enableDns = event.enabled;
    emit(state.copyWith(enableDns: event.enabled));
  }

  void _onToggleIpv6Support(ToggleIpv6Support event, Emitter<SettingsState> emit) {
    _preferences.ipv6Support = event.enabled;
    emit(state.copyWith(ipv6Support: event.enabled));
  }

  void _onToggleMux(ToggleMux event, Emitter<SettingsState> emit) {
    _preferences.muxEnabled = event.enabled;
    emit(state.copyWith(muxEnabled: event.enabled));
  }

  void _onUpdateMuxCount(UpdateMuxCount event, Emitter<SettingsState> emit) {
    _preferences.muxCount = event.count;
    emit(state.copyWith(muxCount: event.count));
  }

  void _onUpdateRoutingMode(UpdateRoutingMode event, Emitter<SettingsState> emit) {
    _preferences.routingMode = event.mode;
    emit(state.copyWith(routingMode: event.mode));
  }

  void _onToggleBypassLan(ToggleBypassLan event, Emitter<SettingsState> emit) {
    _preferences.bypassLan = event.enabled;
    emit(state.copyWith(bypassLan: event.enabled));
  }

  void _onToggleDebugMode(ToggleDebugMode event, Emitter<SettingsState> emit) {
    _preferences.debugMode = event.enabled;
    emit(state.copyWith(debugMode: event.enabled));
  }
}
