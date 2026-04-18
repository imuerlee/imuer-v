import 'package:shared_preferences/shared_preferences.dart';
import '../../core/constants/app_constants.dart';
import '../../presentation/blocs/settings/settings_state.dart';

class PreferencesManager {
  final SharedPreferences _prefs;

  PreferencesManager(this._prefs);

  bool get vpnEnabled => _prefs.getBool(AppConstants.prefVpnEnabled) ?? false;
  set vpnEnabled(bool value) => _prefs.setBool(AppConstants.prefVpnEnabled, value);

  bool get autoConnect => _prefs.getBool(AppConstants.prefAutoConnect) ?? false;
  set autoConnect(bool value) => _prefs.setBool(AppConstants.prefAutoConnect, value);

  bool get autoStart => _prefs.getBool(AppConstants.prefAutoStart) ?? false;
  set autoStart(bool value) => _prefs.setBool(AppConstants.prefAutoStart, value);

  bool get killSwitch => _prefs.getBool(AppConstants.prefKillSwitch) ?? false;
  set killSwitch(bool value) => _prefs.setBool(AppConstants.prefKillSwitch, value);

  String get customDns => _prefs.getString(AppConstants.prefCustomDns) ?? '8.8.8.8';
  set customDns(String value) => _prefs.setString(AppConstants.prefCustomDns, value);

  String get dnsFallback => _prefs.getString(AppConstants.prefDnsFallback) ?? '1.1.1.1';
  set dnsFallback(String value) => _prefs.setString(AppConstants.prefDnsFallback, value);

  bool get enableDns => _prefs.getBool(AppConstants.prefEnableDns) ?? false;
  set enableDns(bool value) => _prefs.setBool(AppConstants.prefEnableDns, value);

  bool get ipv6Support => _prefs.getBool(AppConstants.prefIpv6Support) ?? false;
  set ipv6Support(bool value) => _prefs.setBool(AppConstants.prefIpv6Support, value);

  bool get muxEnabled => _prefs.getBool(AppConstants.prefMuxEnabled) ?? false;
  set muxEnabled(bool value) => _prefs.setBool(AppConstants.prefMuxEnabled, value);

  int get muxCount => _prefs.getInt(AppConstants.prefMuxCount) ?? 8;
  set muxCount(int value) => _prefs.setInt(AppConstants.prefMuxCount, value);

  RoutingMode get routingMode {
    final index = _prefs.getInt(AppConstants.prefRoutingMode) ?? 0;
    return RoutingMode.values[index.clamp(0, RoutingMode.values.length - 1)];
  }
  set routingMode(RoutingMode value) => _prefs.setInt(AppConstants.prefRoutingMode, value.index);

  bool get bypassLan => _prefs.getBool(AppConstants.prefBypassLan) ?? true;
  set bypassLan(bool value) => _prefs.setBool(AppConstants.prefBypassLan, value);

  bool get debugMode => _prefs.getBool(AppConstants.prefDebugMode) ?? false;
  set debugMode(bool value) => _prefs.setBool(AppConstants.prefDebugMode, value);

  String? get selectedServerId => _prefs.getString(AppConstants.prefSelectedServer);
  set selectedServerId(String? value) {
    if (value != null) {
      _prefs.setString(AppConstants.prefSelectedServer, value);
    } else {
      _prefs.remove(AppConstants.prefSelectedServer);
    }
  }

  int get totalUpload => _prefs.getInt(AppConstants.prefTotalUpload) ?? 0;
  set totalUpload(int value) => _prefs.setInt(AppConstants.prefTotalUpload, value);

  int get totalDownload => _prefs.getInt(AppConstants.prefTotalDownload) ?? 0;
  set totalDownload(int value) => _prefs.setInt(AppConstants.prefTotalDownload, value);

  Future<void> clear() async {
    await _prefs.clear();
  }
}
