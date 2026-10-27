import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../utils/order_option_labels.dart';
import '../order_form_state.dart';

/// Step 8: read-only summary of everything entered.
class OverviewStep extends StatelessWidget {
  const OverviewStep({
    super.key,
    required this.form,
    required this.desktopActions,
    required this.isEmployeeOrHigher,
    required this.onGenerateShoppingList,
  });

  /// The shared wizard state (read for display, mutated via `update`).
  final OrderFormState form;

  /// Builds the desktop back/next row (only shown at width >= 600).
  final Widget Function() desktopActions;

  /// Staff see the order wording and the Claude shopping-list button.
  final bool isEmployeeOrHigher;

  /// Staff-only: generate the shopping list with Claude.
  final VoidCallback onGenerateShoppingList;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isEnglish = context.locale.languageCode == 'en';

    String formatDate(DateTime? d) =>
        d != null ? DateFormat('EEEE, dd. MMMM yyyy').format(d) : '–';
    String formatTime(TimeOfDay? t) => t != null ? t.format(context) : '–';

    Widget section(String title, List<_OverviewRow> rows) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 20),
        child: Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: colorScheme.outlineVariant),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 12),
                ...rows.map(
                  (row) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: 130,
                          child: Text(
                            row.label,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            row.value,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final serviceLabel = form.serviceType == 'cocktail_barservice'
        ? (isEnglish ? 'Cocktail & bar' : 'Cocktail & Bar')
        : form.serviceType == 'cocktail_service'
        ? (isEnglish ? 'Cocktails only' : 'Nur Cocktails')
        : form.serviceType == 'mocktail_service'
        ? (isEnglish ? 'Mocktails only' : 'Nur Mocktails')
        : (isEnglish ? 'Bar only' : 'Nur Bar');

    final drinkerLabel = form.drinkerType == 'light'
        ? (isEnglish ? 'Light drinkers' : 'Leichte Trinker')
        : form.drinkerType == 'heavy'
        ? (isEnglish ? 'Heavy drinkers' : 'Starke Trinker')
        : 'Normal';

    final barDrinkLabels = formatOrderBarDrinkLabels(
      form.selectedBarDrinks,
      isEnglish: isEnglish,
    );
    final alcoholLabels = formatOrderAlcoholLabels(
      form.selectedAlcoholItems,
      isEnglish: isEnglish,
    );
    final additionalServiceLabels = form.additionalServicesList
        .map(
          (value) => resolveAdditionalServiceLabel(
            value,
            catalog: form.serviceCatalog,
            isEnglish: isEnglish,
            currencyCode: form.currency,
          ),
        )
        .toList(growable: false);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isEmployeeOrHigher
                ? (isEnglish ? 'Order review' : 'Auftragsübersicht')
                : (isEnglish ? 'Request review' : 'Anfrageübersicht'),
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            isEmployeeOrHigher
                ? (isEnglish
                      ? 'Please review everything before you generate the shopping list.'
                      : 'Bitte alles prüfen, bevor du den Auftrag abschließt.')
                : (isEnglish
                      ? 'Please review everything before you submit your request.'
                      : 'Bitte alles prüfen, bevor du deine Anfrage einreichst.'),
            style: theme.textTheme.bodyLarge?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 24),
          section('Service', [_OverviewRow('Service-Typ', serviceLabel)]),
          section('Kontakt', [
            _OverviewRow(
              'Name',
              form.nameController.text.trim().isEmpty
                  ? '–'
                  : form.nameController.text.trim(),
            ),
            _OverviewRow(
              'Telefon',
              form.phoneController.text.trim().isEmpty
                  ? '–'
                  : form.phoneController.text.trim(),
            ),
          ]),
          section('Event-Details', [
            _OverviewRow('Datum', formatDate(form.eventDate)),
            _OverviewRow('Uhrzeit', formatTime(form.eventTime)),
            _OverviewRow(
              'Ort',
              form.addressController.text.trim().isEmpty
                  ? '–'
                  : form.addressController.text.trim(),
            ),
          ]),
          section('Präferenzen', [
            _OverviewRow('Personen', '${form.personCount}'),
            _OverviewRow('Entfernung', '${form.distanceKm} km'),
            _OverviewRow('Währung', form.currency),
            _OverviewRow('Trinkverhalten', drinkerLabel),
          ]),
          if (form.selectedRecipes.isNotEmpty)
            section('Cocktails (${form.selectedRecipes.length})', [
              ...form.selectedRecipes.map((r) {
                final pop = (form.cocktailPopularity[r.name] ?? 50).round();
                return _OverviewRow(r.name, '$pop% Beliebtheit');
              }),
            ]),
          if (form.selectedBarDrinks.isNotEmpty ||
              form.selectedAlcoholItems.isNotEmpty)
            section('Bardrinks & Alkohol', [
              if (barDrinkLabels.isNotEmpty)
                _OverviewRow('Bardrinks', barDrinkLabels.join(', ')),
              ...alcoholLabels.map((label) => _OverviewRow('Alkohol', label)),
            ]),
          if (additionalServiceLabels.isNotEmpty)
            section('Zusatzleistungen', [
              ...additionalServiceLabels.map(
                (label) => _OverviewRow('Service', label),
              ),
            ]),
          if (form.remarksController.text.trim().isNotEmpty)
            section('Bemerkungen', [
              _OverviewRow('Hinweis', form.remarksController.text.trim()),
            ]),
          const SizedBox(height: 8),
          if (MediaQuery.of(context).size.width >= 600 &&
              isEmployeeOrHigher) ...[
            OutlinedButton.icon(
              onPressed: onGenerateShoppingList,
              icon: const Icon(Icons.auto_awesome),
              label: Text('order_form.generate_with_claude'.tr()),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 16,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
          desktopActions(),
        ],
      ),
    );
  }
}

class _OverviewRow {
  final String label;
  final String value;
  const _OverviewRow(this.label, this.value);
}
