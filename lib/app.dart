import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'repositories/app_state.dart';
import 'router.dart';
import 'theme/app_theme.dart';

class FuelApp extends StatefulWidget {
  const FuelApp({super.key});

  @override
  State<FuelApp> createState() => _FuelAppState();
}

class _FuelAppState extends State<FuelApp> {
  late final AppState _appState;

  @override
  void initState() {
    super.initState();
    _appState = AppState();
    _appState.loadPersistedState();
  }

  @override
  void dispose() {
    _appState.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _appState,
      child: Builder(
        builder: (context) {
          final router = buildRouter(_appState);
          return MaterialApp.router(
            title: 'Fuel',
            theme: AppTheme.light,
            darkTheme: AppTheme.dark,
            themeMode: context.watch<AppState>().themeMode,
            routerConfig: router,
            debugShowCheckedModeBanner: false,
          );
        },
      ),
    );
  }
}
