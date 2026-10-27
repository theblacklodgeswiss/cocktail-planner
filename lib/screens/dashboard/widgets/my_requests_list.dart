import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../models/order.dart';
import '../../../ui/tokens.dart';
import '../../../ui/widgets/buttons.dart';
import '../../../ui/widgets/date_tile.dart';
import '../../../ui/widgets/floating_card.dart';
import '../../../ui/widgets/states.dart';
import '../../../ui/widgets/status_dot.dart';

/// Customer-facing status kind: completed is already folded into accepted by
/// [SavedOrder.customerStatus].
StatusKind customerStatusKind(SavedOrder request) =>
    switch (request.customerStatus) {
      OrderStatus.quote => StatusKind.offer,
      OrderStatus.accepted => StatusKind.accepted,
      OrderStatus.completed => StatusKind.completed,
      OrderStatus.declined => StatusKind.declined,
    };

/// "80 Gäste · Köln", without the separator when there is no location.
String requestMeta(SavedOrder request) {
  final location = request.location.trim();
  return location.isEmpty
      ? 'dashboard.request_meta_no_location'.tr(
          args: ['${request.personCount}'],
        )
      : 'dashboard.request_meta'.tr(args: ['${request.personCount}', location]);
}

/// Customer-facing list of the signed-in user's own submitted requests.
/// Deliberately does not show total price or article count (see design
/// spec section 4) - only what a customer should see before an offer is
/// formally sent.
class MyRequestsList extends StatelessWidget {
  const MyRequestsList({
    super.key,
    required this.requests,
    required this.onTap,
  });

  final List<SavedOrder> requests;
  final void Function(SavedOrder request) onTap;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);

    if (requests.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpace.s24),
        child: Center(
          child: Text(
            'dashboard.no_requests_yet'.tr(),
            style: AppText.body.copyWith(color: p.textSecondary),
          ),
        ),
      );
    }

    return Column(
      children: [
        for (final request in requests)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpace.s8),
            child: MyRequestCard(request: request, onTap: () => onTap(request)),
          ),
      ],
    );
  }
}

/// One request: date tile, name, "N Gäste · Ort" and the status dot.
class MyRequestCard extends StatelessWidget {
  const MyRequestCard({super.key, required this.request, required this.onTap});

  final SavedOrder request;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return FloatingCard(
      onTap: onTap,
      child: Row(
        children: [
          DateTile(request.date),
          const SizedBox(width: AppSpace.s12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  request.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.section.copyWith(color: p.text),
                ),
                Text(
                  requestMeta(request),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.caption.copyWith(color: p.textSecondary),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpace.s12),
          StatusDot(customerStatusKind(request)),
        ],
      ),
    );
  }
}

/// Sliver body of the full "Meine Anfragen" screen: loading, error with
/// retry, empty state with a CTA, or the list. [streamFactory] is called
/// again on retry so the screen re-subscribes.
class MyRequestsContent extends StatefulWidget {
  const MyRequestsContent({
    super.key,
    required this.streamFactory,
    required this.onOpen,
  });

  final Stream<List<SavedOrder>> Function() streamFactory;
  final void Function(SavedOrder request) onOpen;

  @override
  State<MyRequestsContent> createState() => _MyRequestsContentState();
}

class _MyRequestsContentState extends State<MyRequestsContent> {
  late Stream<List<SavedOrder>> _stream = widget.streamFactory();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<SavedOrder>>(
      stream: _stream,
      builder: (context, snapshot) {
        if (snapshot.hasError && !snapshot.hasData) {
          return SliverFillRemaining(
            hasScrollBody: false,
            child: ErrorState(
              message: 'dashboard.requests_load_error'.tr(),
              onRetry: () => setState(() => _stream = widget.streamFactory()),
            ),
          );
        }
        if (!snapshot.hasData) {
          return const SliverFillRemaining(
            hasScrollBody: false,
            child: LoadingState(),
          );
        }
        final requests = snapshot.data!;
        if (requests.isEmpty) {
          return SliverFillRemaining(
            hasScrollBody: false,
            child: EmptyState(
              icon: Icons.inbox_outlined,
              title: 'dashboard.no_requests_yet'.tr(),
              body: 'dashboard.requests_empty_body'.tr(),
              action: PrimaryButton(
                label: 'start.cta'.tr(),
                onPressed: () => context.push('/order-form'),
              ),
            ),
          );
        }
        return SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpace.s16),
          sliver: SliverList.builder(
            itemCount: requests.length,
            itemBuilder: (context, i) => Padding(
              padding: const EdgeInsets.only(bottom: AppSpace.s8),
              child: MyRequestCard(
                request: requests[i],
                onTap: () => widget.onOpen(requests[i]),
              ),
            ),
          ),
        );
      },
    );
  }
}
