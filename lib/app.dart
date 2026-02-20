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
    // Modern rounded input decoration theme
    InputDecorationTheme inputTheme(ColorScheme colorScheme) {
      return InputDecorationTheme(
        filled: true,
        fillColor: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colorScheme.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colorScheme.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colorScheme.error, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      );
    }

    final lightColorScheme = ColorScheme.fromSeed(
      seedColor: Colors.green,
      brightness: Brightness.light,
    );
    final darkColorScheme = ColorScheme.fromSeed(
      seedColor: Colors.green,
      brightness: Brightness.dark,
    );

    return MaterialApp.router(
      title: 'Cocktail Planner',
      debugShowCheckedModeBanner: false,
      themeMode: userPreferencesService.themeMode,
      theme: ThemeData(
        colorScheme: lightColorScheme,
        useMaterial3: true,
        inputDecorationTheme: inputTheme(lightColorScheme),
      ),
      darkTheme: ThemeData(
        colorScheme: darkColorScheme,
        useMaterial3: true,
        inputDecorationTheme: inputTheme(darkColorScheme),
      ),
      routerConfig: appRouter,
      localizationsDelegates: context.localizationDelegates,
      supportedLocales: context.supportedLocales,
      locale: context.locale,
    );
  }
}
