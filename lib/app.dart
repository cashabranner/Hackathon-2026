import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'repositories/app_state.dart';
import 'router.dart';
import 'theme/app_theme.dart';

class FuelWindowApp extends StatefulWidget {
  const FuelWindowApp({super.key});

  @override
  State<FuelWindowApp> createState() => _FuelWindowAppState();
}

class _FuelWindowAppState extends State<FuelWindowApp> {
  late final AppState _appState;

  @override
  void initState() {
    super.initState();
    _appState = AppState();
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
            title: 'FuelWindow',
            theme: AppTheme.light,
            routerConfig: router,
            debugShowCheckedModeBanner: false,
          );
        },
      ),
    );
  }
}
