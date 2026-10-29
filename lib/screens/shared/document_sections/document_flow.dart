import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../../models/order.dart';
import '../../../ui/motion.dart';
import '../../../ui/tokens.dart';
import '../../../ui/widgets/app_sheet.dart';
import '../../../ui/widgets/buttons.dart';
import '../../../ui/widgets/glass_cta_bar.dart' show bottomBarInset;
import '../../../ui/widgets/pressable.dart';
import '../../../ui/widgets/states.dart';
import '../../../ui/widgets/step_scaffold.dart';
import '../../forms/steps/wizard_widgets.dart' show CheckMark;

/// A missing or invalid value: the step that shows it, the field id (key
/// of the hint/anchor) and the translation key of the hint.
class DocIssue {
  const DocIssue(this.step, this.field, this.messageKey);

  final int step;
  final String field;
  final String messageKey;

  @override
  String toString() => 'DocIssue($step, $field, $messageKey)';
}

/// The four steps of the offer and invoice flows.
const documentStepTitleKeys = [
  'docflow.step_client',
  'docflow.step_services',
  'docflow.step_positions',
  'docflow.step_price',
];

const documentStepCount = 4;

/// An entry of the "…" menu.
class DocMenuAction {
  const DocMenuAction(this.label, this.icon, this.onTap);

  final String label;
  final IconData icon;
  final VoidCallback onTap;
}

/// Step state shared by the offer and invoice flows: current step, which
/// steps already explained their missing fields, field anchors and the
/// soft "Weiter" (first tap shows hints, second tap continues - these are
/// staff-only screens, like the order form for staff).
mixin DocumentStepFlow<T extends StatefulWidget> on State<T> {
  int step = 0;
  final Set<int> attemptedSteps = {};
  final ScrollController scrollController = ScrollController();
  final Map<String, GlobalKey> _anchors = {};

  /// Set by a failed final action: every hint shows.
  bool showAllHints = false;

  /// The fixed bottom area (menu + primary); snackbars float above it.
  final GlobalKey bottomAreaKey = GlobalKey(debugLabel: 'doc-bottom');

  /// Shows the message [key] as a floating snackbar just above the bottom
  /// area, so it never covers "Weiter"/"Senden" or the "…" menu.
  void showSnack(String key) {
    if (!mounted) return;
    final box = bottomAreaKey.currentContext?.findRenderObject();
    final screen = MediaQuery.sizeOf(context).height;
    final lift = box is RenderBox && box.hasSize
        ? screen - box.localToGlobal(Offset.zero).dy
        : AppSize.minTap + bottomBarInset(context);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(key.tr()),
          behavior: SnackBarBehavior.floating,
          margin: EdgeInsets.fromLTRB(
            AppSpace.s16,
            0,
            AppSpace.s16,
            lift + AppSpace.s8,
          ),
        ),
      );
  }

  /// All current issues of the form.
  List<DocIssue> get issues;

  GlobalKey anchorOf(String field) =>
      _anchors.putIfAbsent(field, () => GlobalKey(debugLabel: field));

  /// The hint key shown at [field], or null.
  String? hintOf(String field) {
    for (final issue in issues) {
      if (issue.field != field) continue;
      if (showAllHints || attemptedSteps.contains(issue.step)) {
        return issue.messageKey;
      }
      return null;
    }
    return null;
  }

  bool stepComplete(int s) => !issues.any((i) => i.step == s);

  void disposeStepFlow() => scrollController.dispose();

  void goToStep(int s) {
    setState(() => step = s);
    if (scrollController.hasClients) scrollController.jumpTo(0);
  }

  /// "Weiter": soft gate (see mixin doc).
  void nextStep() {
    if (!stepComplete(step) && !attemptedSteps.contains(step)) {
      revealStep(step);
      return;
    }
    HapticFeedback.lightImpact();
    goToStep(step + 1);
  }

  void previousStep() {
    if (step > 0) goToStep(step - 1);
  }

  /// Shows the hints of [s] and scrolls to its first missing field.
  void revealStep(int s) {
    setState(() => attemptedSteps.add(s));
    final first = issues.where((i) => i.step == s).firstOrNull;
    if (first == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final anchor = _anchors[first.field]?.currentContext;
      if (!mounted || anchor == null) return;
      Scrollable.ensureVisible(
        anchor,
        alignment: 0.2,
        duration: AppMotion.reduced(context) ? Duration.zero : AppMotion.page,
        curve: AppMotion.easeOut,
      );
    });
  }

  /// Before a final action: when anything is missing, jumps to the first
  /// faulty step, shows all hints and returns that issue.
  DocIssue? checkAll() {
    final all = issues;
    if (all.isEmpty) return null;
    FocusManager.instance.primaryFocus?.unfocus();
    final first = all.first;
    setState(() => showAllHints = true);
    if (first.step != step) goToStep(first.step);
    revealStep(first.step);
    return first;
  }

  /// Staff: sheet listing the steps; picking one jumps without checks.
  Future<void> showStepPicker() async {
    final picked = await showAppSheet<int>(
      context,
      builder: (sheet) {
        final p = AppPalette.of(sheet);
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'ui.jump_to_step'.tr(),
              style: AppText.heroTitle.copyWith(color: p.text),
            ),
            const SizedBox(height: AppSpace.s8),
            for (var i = 0; i < documentStepCount; i++)
              Pressable(
                minSize: AppSize.minTap,
                selected: i == step,
                onTap: () => Navigator.of(sheet).pop(i),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppSpace.s8),
                  child: Row(
                    children: [
                      SizedBox(
                        width: AppSize.stepDigit,
                        child: Text(
                          '${i + 1}',
                          style: AppText.number.copyWith(
                            color: p.textSecondary,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          documentStepTitleKeys[i].tr(),
                          style: AppText.button.copyWith(color: p.text),
                        ),
                      ),
                      CheckMark(selected: i == step),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
    if (picked != null && mounted && picked != step) {
      HapticFeedback.selectionClick();
      goToStep(picked);
    }
  }

  /// Arrow back: previous step, or leave from the first one.
  void leaveOrBack() {
    if (step > 0) {
      previousStep();
    } else if (context.canPop()) {
      context.pop();
    } else {
      context.go('/orders');
    }
  }
}

/// [StepScaffold] with the flows' bottom area: the "…" menu (all other
/// actions) and ONE primary button. Wrapped in a [PopScope] whose back
/// goes to the previous step; after a successful "save" ([saved]) back
/// leaves to the orders overview.
class DocumentFlowScaffold extends StatelessWidget {
  const DocumentFlowScaffold({
    super.key,
    required this.flow,
    required this.child,
    required this.primaryLabel,
    required this.onPrimary,
    required this.menu,
    this.loading = false,
    this.dimmed = false,
    this.saved = false,
  });

  final DocumentStepFlow flow;
  final Widget child;
  final String primaryLabel;
  final VoidCallback onPrimary;
  final List<DocMenuAction> menu;
  final bool loading;
  final bool dimmed;
  final bool saved;

  @override
  Widget build(BuildContext context) {
    final step = flow.step;
    return PopScope(
      canPop: step == 0 && !saved,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (saved) {
          context.go('/orders');
        } else {
          flow.previousStep();
        }
      },
      child: StepScaffold(
        step: step + 1,
        total: documentStepCount,
        title: documentStepTitleKeys[step].tr(),
        controller: flow.scrollController,
        onBack: flow.leaveOrBack,
        onStepLabelTap: flow.showStepPicker,
        bottom: Row(
          key: flow.bottomAreaKey,
          children: [
            _MenuButton(actions: menu, enabled: !loading),
            const SizedBox(width: AppSpace.s8),
            Expanded(
              child: PrimaryButton(
                expand: true,
                label: primaryLabel,
                loading: loading,
                dimmed: dimmed,
                onPressed: loading ? null : onPrimary,
              ),
            ),
          ],
        ),
        child: KeyedSubtree(key: ValueKey('doc-step-$step'), child: child),
      ),
    );
  }
}

class _MenuButton extends StatelessWidget {
  const _MenuButton({required this.actions, required this.enabled});

  final List<DocMenuAction> actions;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Pressable(
      minSize: AppSize.minTap,
      radius: AppRadius.pill,
      semanticLabel: 'docflow.more_actions'.tr(),
      onTap: enabled ? () => _open(context) : null,
      child: SizedBox.square(
        dimension: AppSize.minTap,
        child: DecoratedBox(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: p.border),
          ),
          child: Icon(Icons.more_horiz, color: enabled ? p.text : p.disabled),
        ),
      ),
    );
  }

  Future<void> _open(BuildContext context) async {
    final picked = await showAppSheet<DocMenuAction>(
      context,
      builder: (sheet) {
        final p = AppPalette.of(sheet);
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'docflow.more_actions'.tr(),
              style: AppText.heroTitle.copyWith(color: p.text),
            ),
            const SizedBox(height: AppSpace.s8),
            for (final a in actions)
              Pressable(
                minSize: AppSize.minTap,
                onTap: () => Navigator.of(sheet).pop(a),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: AppSize.minTap),
                  child: Row(
                    children: [
                      Icon(a.icon, size: AppSize.rowIcon, color: p.text),
                      const SizedBox(width: AppSpace.s12),
                      Expanded(
                        child: Text(
                          a.label,
                          style: AppText.button.copyWith(color: p.text),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
    picked?.onTap();
  }
}

/// Shown when /create-offer or /create-invoice is opened without an order
/// (e.g. a reload drops the route `extra`): explains and leads to /orders.
class MissingDocumentOrder extends StatelessWidget {
  const MissingDocumentOrder({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppPalette.of(context).surface,
      body: SafeArea(
        child: EmptyState(
          icon: Icons.receipt_long,
          title: 'docflow.missing_title'.tr(),
          body: 'docflow.missing_body'.tr(),
          action: PrimaryButton(
            label: 'docflow.to_orders'.tr(),
            onPressed: () => context.go('/orders'),
          ),
        ),
      ),
    );
  }
}

/// Route builder for the document screens: the `extra` must be the order;
/// anything else shows [MissingDocumentOrder] instead of a cast error.
Widget documentRoute(Object? extra, Widget Function(SavedOrder) builder) =>
    extra is SavedOrder ? builder(extra) : const MissingDocumentOrder();
