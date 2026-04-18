import 'package:shared_preferences/shared_preferences.dart';
import '../../core/constants/app_constants.dart';

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
