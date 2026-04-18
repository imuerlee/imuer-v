import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'core/theme/app_theme.dart';
import 'injection.dart';
import 'presentation/blocs/vpn/vpn_bloc.dart';
import 'presentation/blocs/vpn/vpn_event.dart';
import 'presentation/blocs/server/server_bloc.dart';
import 'presentation/blocs/server/server_event.dart';
import 'presentation/blocs/statistics/statistics_bloc.dart';
import 'presentation/blocs/statistics/statistics_event.dart';
import 'presentation/blocs/settings/settings_bloc.dart';
import 'presentation/blocs/settings/settings_event.dart';
import 'presentation/pages/main_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: AppColors.surface,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  await initDependencies();

  runApp(const NebulaVPNApp());
}

class NebulaVPNApp extends StatelessWidget {
  const NebulaVPNApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<VpnBloc>(
          create: (_) => getIt<VpnBloc>()..add(const LoadLastConnection()),
        ),
        BlocProvider<ServerBloc>(
          create: (_) => getIt<ServerBloc>()..add(const LoadServers()),
        ),
        BlocProvider<StatisticsBloc>(
          create: (_) => getIt<StatisticsBloc>()..add(const LoadStatistics()),
        ),
        BlocProvider<SettingsBloc>(
          create: (_) => getIt<SettingsBloc>()..add(const LoadSettings()),
        ),
      ],
      child: MaterialApp(
        title: 'NebulaVPN',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.darkTheme,
        home: const MainPage(),
      ),
    );
  }
}
