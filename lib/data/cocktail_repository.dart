import 'dart:convert';

import 'package:flutter/services.dart';

import '../models/cocktail_data.dart';

class CocktailRepository {
  CocktailRepository({
    this.assetPath = 'assets/data/cocktail_data.json',
    this.wertigkeitenPath = 'assets/data/wertigkeiten.json',
  });

  final String assetPath;
  final String wertigkeitenPath;
  CocktailData? _cached;

  Future<CocktailData> load() async {
    if (_cached != null) {
      return _cached!;
    }

    final raw = await rootBundle.loadString(assetPath);
    final decoded = jsonDecode(raw) as Map<String, dynamic>;

    final wertigkeitenRaw = await rootBundle.loadString(wertigkeitenPath);
    final wertigkeitenDecoded = jsonDecode(wertigkeitenRaw) as Map<String, dynamic>;

    _cached = CocktailData.fromJson({
      ...decoded,
      'fixedValues':
          wertigkeitenDecoded['fixedValues'] ??
          wertigkeitenDecoded['wertigkeiten'] ??
          const [],
    });
    return _cached!;
  }
}

final CocktailRepository cocktailRepository = CocktailRepository();
