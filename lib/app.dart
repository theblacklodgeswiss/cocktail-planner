import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import 'router/app_router.dart';
import 'services/user_preferences_service.dart';
import 'ui/app_theme.dart';

class CocktailPlanerApp extends StatefulWidget {
  const CocktailPlanerApp({super.key});

  @override
  State<CocktailPlanerApp> createState() => _CocktailPlanerAppState();
}

class _CocktailPlanerAppState extends State<CocktailPlanerApp> {
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
    const String flavor = String.fromEnvironment('FLAVOR', defaultValue: 'dev');
    final String appTitle = flavor == 'prod'
        ? 'Cocktail Planer'
        : '[DEV] Cocktail Planer';

    return MaterialApp.router(
      title: appTitle,
      debugShowCheckedModeBanner: false,
      themeMode: userPreferencesService.themeMode,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      routerConfig: appRouter,
      localizationsDelegates: context.localizationDelegates,
      supportedLocales: context.supportedLocales,
      locale: context.locale,
      // Red "DEV" corner ribbon on every screen for non-prod builds, so
      // the dev deployment is visually unmistakable from production at a
      // glance - separate from debugShowCheckedModeBanner above, which is
      // Flutter's own debug-mode banner and stays off regardless of flavor.
      builder: (context, child) {
        if (flavor == 'prod' || child == null) return child ?? const SizedBox.shrink();
        return Banner(
          message: 'DEV',
          location: BannerLocation.topEnd,
          color: Colors.red.shade700,
          child: child,
        );
      },
    );
  }
}
