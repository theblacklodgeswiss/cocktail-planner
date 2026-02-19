/// Supported currencies in the application
enum Currency {
  chf('CHF', 'Fr.', 'Schweizer Franken'),
  eur('EUR', '€', 'Euro'),
  usd('USD', '\$', 'US Dollar');

  const Currency(this.code, this.symbol, this.name);

  /// ISO 4217 currency code
  final String code;

  /// Currency symbol
  final String symbol;

  /// Full name
  final String name;

  /// Format a price with currency symbol
  String format(double amount) => '${amount.toStringAsFixed(2)} $code';

  /// Get currency from code string
  static Currency fromCode(String code) {
    return Currency.values.firstWhere(
      (c) => c.code.toUpperCase() == code.toUpperCase(),
      orElse: () => Currency.chf,
    );
  }
}

/// Default currency for new orders
const Currency defaultCurrency = Currency.chf;
