import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../models/order.dart';
import '../services/gemini_service.dart';
import '../widgets/order_setup_dialog.dart';

class GeminiPlanDialog extends StatefulWidget {
  final OrderSetupData? setup;
  final SavedOrder? order;
  final List<String> cocktails;
  final List<String> shots;

  const GeminiPlanDialog({
    super.key,
    this.setup,
    this.order,
    required this.cocktails,
    required this.shots,
  }) : assert(setup != null || order != null);

  @override
  State<GeminiPlanDialog> createState() => _GeminiPlanDialogState();
}

class _GeminiPlanDialogState extends State<GeminiPlanDialog> {
  String? _plan;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _generate();
  }

  Future<void> _generate() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      String eventName;
      int guestCount;
      String drinkerType;
      String? timeStr;
      DateTime? eventDate;
      String? location;

      if (widget.order != null) {
        eventName = widget.order!.name;
        guestCount = widget.order!.personCount;
        drinkerType = widget.order!.drinkerType;
        timeStr = widget.order!.eventTime;
        eventDate = widget.order!.date;
        location = widget.order!.location;
      } else {
        eventName = widget.setup!.orderName;
        guestCount = widget.setup!.personCount;
        drinkerType = widget.setup!.drinkerType;
        timeStr = widget.setup!.eventTime != null
            ? '${widget.setup!.eventTime!.hour.toString().padLeft(2, '0')}:${widget.setup!.eventTime!.minute.toString().padLeft(2, '0')}'
            : null;
        eventDate = widget.setup!.eventDate;
        location = widget.setup!.address;
      }

      final plan = await geminiService.generateEventPlan(
        eventName: eventName,
        guestCount: guestCount,
        cocktails: widget.cocktails,
        shots: widget.shots,
        drinkerType: drinkerType,
        eventTime: timeStr,
        eventDate: eventDate,
        location: location,
      );

      if (plan == null) {
        setState(() {
          _error = 'orders.gemini_error'.tr();
          _loading = false;
        });
      } else {
        setState(() {
          _plan = plan;
          _loading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'orders.gemini_error'.tr();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Dialog(
      insetPadding: const EdgeInsets.all(24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        width: 800,
        height: 600,
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Row(
              children: [
                Icon(Icons.auto_awesome, color: colorScheme.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'orders.generate_with_gemini'.tr(),
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const Divider(height: 32),
            Expanded(
              child: _loading
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const CircularProgressIndicator(),
                          const SizedBox(height: 16),
                          Text('orders.gemini_generating'.tr()),
                        ],
                      ),
                    )
                  : _error != null
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.error_outline,
                            size: 48,
                            color: colorScheme.error,
                          ),
                          const SizedBox(height: 16),
                          Text(_error!),
                          const SizedBox(height: 24),
                          FilledButton(
                            onPressed: _generate,
                            child: Text(
                              'common.undo'.tr(),
                            ), // Using undo as retry for now
                          ),
                        ],
                      ),
                    )
                  : Markdown(
                      data: _plan!,
                      selectable: true,
                      styleSheet: MarkdownStyleSheet(
                        h1: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                        h2: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                        h3: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                        p: const TextStyle(fontSize: 14, height: 1.5),
                      ),
                    ),
            ),
            const Divider(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (!_loading && _error == null)
                  IconButton(
                    onPressed: () {
                      // Implementation for copying to clipboard or similar could go here
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Plan in Zwischenablage kopiert (Coming soon)',
                          ),
                        ),
                      );
                    },
                    icon: const Icon(Icons.copy),
                    tooltip: 'Kopieren',
                  ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text('common.close'.tr()),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
