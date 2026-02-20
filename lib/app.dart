import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import 'router/app_router.dart';
import 'services/user_preferences_service.dart';

class CocktailPlannerApp extends StatefulWidget {
  const CocktailPlannerApp({super.key});

  @override
  State<CocktailPlannerApp> createState() => _CocktailPlannerAppState();
}

class _CocktailPlannerAppState extends State<CocktailPlannerApp> {
  @override
  void initState() {
    super.initState();
    userPreferencesService.addListener(_onPreferencesChanged);
  }

  @override
  void dispose() {
    userPreferencesService.removeListener(_onPreferencesChanged);
    super.dispose();
  }

  void _onPreferencesChanged() {
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Cocktail Planner',
      debugShowCheckedModeBanner: false,
      themeMode: userPreferencesService.themeMode,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.green,
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.green,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      routerConfig: appRouter,
      localizationsDelegates: context.localizationDelegates,
      supportedLocales: context.supportedLocales,
      locale: context.locale,
    );
  }
}
