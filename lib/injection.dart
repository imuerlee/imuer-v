import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'data/datasources/local_database.dart';
import 'data/datasources/preferences_manager.dart';
import 'presentation/blocs/vpn/vpn_bloc.dart';
import 'presentation/blocs/server/server_bloc.dart';
import 'presentation/blocs/statistics/statistics_bloc.dart';
import 'presentation/blocs/settings/settings_bloc.dart';

final getIt = GetIt.instance;

Future<void> initDependencies() async {
  final sharedPreferences = await SharedPreferences.getInstance();
  getIt.registerSingleton<SharedPreferences>(sharedPreferences);

  getIt.registerSingleton<PreferencesManager>(
    PreferencesManager(getIt<SharedPreferences>()),
  );

  getIt.registerSingleton<LocalDatabase>(LocalDatabase());

  getIt.registerFactory<VpnBloc>(
    () => VpnBloc(
      database: getIt<LocalDatabase>(),
      preferences: getIt<PreferencesManager>(),
    ),
  );

  getIt.registerFactory<ServerBloc>(
    () => ServerBloc(database: getIt<LocalDatabase>()),
  );

  getIt.registerFactory<StatisticsBloc>(
    () => StatisticsBloc(
      database: getIt<LocalDatabase>(),
      preferences: getIt<PreferencesManager>(),
    ),
  );

  getIt.registerFactory<SettingsBloc>(
    () => SettingsBloc(preferences: getIt<PreferencesManager>()),
  );
}
