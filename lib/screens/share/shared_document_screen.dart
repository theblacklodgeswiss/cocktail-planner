import 'dart:typed_data';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:printing/printing.dart';

import '../../data/share_link_repository.dart';
import '../../models/offer.dart';
import '../../models/order.dart';
import '../../services/invoice_pdf_generator.dart';
import '../../services/offer_pdf_generator.dart';
import '../../ui/tokens.dart';
import '../../ui/widgets/app_sheet.dart';
import '../../ui/widgets/buttons.dart';
import '../../ui/widgets/floating_card.dart';
import '../../ui/widgets/glass_cta_bar.dart';
import '../../ui/widgets/hero_card.dart';
import '../../ui/widgets/large_title_scaffold.dart';
import '../../ui/widgets/states.dart';
import '../../ui/widgets/status_dot.dart';
import '../../utils/currency.dart';

/// Brand name shown above the summary. Not translated on purpose; the
/// snapshots carry no firm name.
const _brandName = 'BlackLodge';

/// Public, signed-out-accessible screen that resolves a `/s/:code` share
/// link created by [ShareLinkRepository] and shows a summary of the stored
/// snapshot. The PDF is regenerated lazily from the snapshot when the
/// visitor opens it. No Firebase Auth session is required or assumed — see
/// app_router.dart's redirect exemption for '/s/'.
///
/// For an offer link, the customer can accept/decline (after a confirmation
/// sheet) — see [ShareLinkRepository.respondToOffer] and the
/// `isShareLinkResponse` Firestore rule, which is the actual security
/// boundary for that write.
class SharedDocumentScreen extends StatefulWidget {
  const SharedDocumentScreen({
    super.key,
    required this.code,
    this.repository,
    this.pdfBuilder,
  });

  final String code;

  /// Defaults to the global [shareLinkRepository]. Overridable for tests.
  final ShareLinkRepository? repository;

  /// Defaults to the real offer/invoice PDF generators. Overridable for tests.
  final Future<Uint8List> Function(ShareLinkResult result)? pdfBuilder;

  @override
  State<SharedDocumentScreen> createState() => _SharedDocumentScreenState();
}

class _Position {
  const _Position({
    required this.name,
    required this.quantity,
    required this.price,
    required this.total,
  });

  final String name;
  final int quantity;
  final double price;
  final double total;

  /// Same convention as the PDF tables: quantity 0 means "to be defined".
  bool get isTbd => quantity == 0;
}

/// Values read from the snapshot; prices are never recomputed here beyond
/// the helpers the PDF generators themselves use.
class _Summary {
  const _Summary({
    required this.currency,
    required this.eventTypes,
    required this.name,
    required this.date,
    required this.location,
    required this.positions,
    required this.discount,
    required this.discountText,
    required this.total,
  });

  final Currency currency;
  final List<String> eventTypes;
  final String name;
  final DateTime date;
  final String location;
  final List<_Position> positions;
  final double discount;
  final String discountText;
  final double total;

  static _Position _position(ExtraPosition p) => _Position(
    name: p.name,
    quantity: p.quantity,
    price: p.price,
    total: p.total,
  );

  factory _Summary.from(ShareLinkResult result) {
    if (result.type == 'offer') {
      final offer = OfferData.fromJson(result.snapshot!);
      return _Summary(
        currency: Currency.fromCode(offer.currency),
        eventTypes: [for (final t in offer.eventTypes) t.name],
        name: offer.orderName,
        date: offer.eventDate,
        location: offer.eventLocation,
        positions: [for (final p in offer.offerPositions) _position(p)],
        discount: offer.discount,
        discountText: discountLabel(
          isEnglish: offer.language == 'en',
          percent: offer.discountPercent,
        ),
        // Same getter the offer PDF prints in its total row.
        total: offer.grandTotal,
      );
    }
    final order = SavedOrder.fromFirestore('shared', result.snapshot!);
    return _Summary(
      currency: Currency.fromCode(order.currency),
      eventTypes: order.offerEventTypes,
      name: order.name,
      date: order.date,
      location: order.location,
      positions: [
        for (final p in order.offerPositions)
          _position(ExtraPosition.fromJson(p)),
      ],
      discount: order.offerDiscount,
      discountText: discountLabel(
        isEnglish: order.offerLanguage == 'en',
        percent: order.offerDiscountPercent,
      ),
      // Same helper the invoice PDF uses for its total row.
      total: InvoicePdfGenerator.grandTotalOf(order),
    );
  }

  String get dateText =>
      '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';

  String occasion() {
    final labels = [
      for (final t in eventTypes)
        if (EventType.values.any((e) => e.name == t)) 'offer.event_$t'.tr(),
    ];
    if (labels.isNotEmpty) return labels.join(', ');
    return name;
  }
}

class _SharedDocumentScreenState extends State<SharedDocumentScreen> {
  bool _loading = true;
  ShareLinkResult? _result;
  _Summary? _summary;
  Future<Uint8List>? _pdfFuture;

  /// Mirrors [ShareLinkResult.response] once known, whether that came from
  /// the initial fetch (a prior visit already responded) or from this
  /// visitor's own click just now.
  String? _localResponse;
  bool _responding = false;

  ShareLinkRepository get _repo => widget.repository ?? shareLinkRepository;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final result = await _repo.fetchShareLink(widget.code);
    _Summary? summary;
    if (result.found) {
      try {
        summary = _Summary.from(result);
      } catch (_) {
        summary = null; // Unreadable snapshot: treated like an invalid link.
      }
    }
    if (!mounted) return;
    setState(() {
      _result = result;
      _summary = summary;
      _localResponse = result.response;
      _loading = false;
    });
  }

  Future<Uint8List> _buildPdf(ShareLinkResult result) async {
    final custom = widget.pdfBuilder;
    if (custom != null) return custom(result);
    switch (result.type) {
      case 'offer':
        return OfferPdfGenerator.generatePdfBytes(
          OfferData.fromJson(result.snapshot!),
        );
      default:
        final order = SavedOrder.fromFirestore('shared', result.snapshot!);
        return InvoicePdfGenerator.generateBytes(
          order,
          language: order.offerLanguage,
        );
    }
  }

  /// Starts generation; the error is observed right away so a failure
  /// before the sheet's FutureBuilder subscribes is not reported as unhandled.
  Future<Uint8List> _startPdf(ShareLinkResult result) {
    final future = _buildPdf(result);
    future.then<void>((_) {}, onError: (_) {});
    return future;
  }

  void _openPdf() {
    final result = _result!;
    _pdfFuture ??= _startPdf(result);
    showAppSheet<void>(
      context,
      full: true,
      builder: (sheet) => StatefulBuilder(
        builder: (context, setSheet) => FutureBuilder<Uint8List>(
          future: _pdfFuture,
          builder: (context, snap) {
            if (snap.hasError) {
              return ErrorState(
                message: 'share.pdf_error'.tr(),
                onRetry: () => setSheet(() => _pdfFuture = _startPdf(result)),
              );
            }
            final bytes = snap.data;
            if (bytes == null) return const LoadingState();
            return PdfPreview(
              build: (format) async => bytes,
              allowSharing: true,
              allowPrinting: true,
              canDebug: false,
            );
          },
        ),
      ),
    );
  }

  Future<void> _confirmAndRespond(bool accepted) async {
    final ok = await showConfirmSheet(
      context,
      title: accepted
          ? 'share.confirm_accept_title'.tr()
          : 'share.confirm_decline_title'.tr(),
      body: accepted
          ? 'share.confirm_accept_body'.tr()
          : 'share.confirm_decline_body'.tr(),
      confirmLabel: accepted ? 'share.accept'.tr() : 'share.decline'.tr(),
      destructive: !accepted,
    );
    if (ok && mounted) await _respond(accepted);
  }

  Future<void> _respond(bool accepted) async {
    final result = _result;
    if (result == null || result.orderId == null) return;
    setState(() => _responding = true);
    try {
      await _repo.respondToOffer(
        orderId: result.orderId!,
        code: widget.code,
        accepted: accepted,
      );
      if (mounted) {
        setState(() => _localResponse = accepted ? 'accepted' : 'declined');
      }
    } catch (e) {
      // Denied because the offer was already resolved — either by this
      // visitor's own earlier click (whose link-marking step never
      // completed, e.g. the tab closed mid-request) or by someone/
      // something else. Try to self-heal: if the order's real status
      // already matches what was just clicked, this succeeds and the
      // page can show the true outcome instead of a hard error.
      final recovered = await _repo.recoverLinkResponse(
        code: widget.code,
        accepted: accepted,
      );
      if (mounted) {
        if (recovered) {
          setState(() => _localResponse = accepted ? 'accepted' : 'declined');
        } else {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('share.response_error'.tr())));
        }
      }
    } finally {
      if (mounted) setState(() => _responding = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final result = _result;
    final summary = _summary;
    if (_loading) {
      return const Scaffold(body: SafeArea(child: LoadingState()));
    }
    if (result == null || summary == null) {
      return Scaffold(
        body: SafeArea(
          child: EmptyState(
            icon: Icons.link_off,
            title: 'share.expired_title'.tr(),
            body: 'share.expired_body'.tr(),
          ),
        ),
      );
    }

    final isOffer = result.type == 'offer';
    final p = AppPalette.of(context);
    final bullets = result.bullets ?? const <String>[];
    final meta = [
      if (summary.occasion().trim().isNotEmpty) summary.occasion().trim(),
      summary.dateText,
      if (summary.location.trim().isNotEmpty) summary.location.trim(),
    ].join(' · ');

    return LargeTitleScaffold(
      title: isOffer ? 'orders.offer'.tr() : 'orders.invoice'.tr(),
      bottomBar: isOffer ? _buildResponse(context) : null,
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpace.s16),
          sliver: SliverList.list(
            children: [
              HeroCard(
                kicker: _brandName,
                title: summary.currency.format(summary.total),
                meta: meta,
              ),
              if (bullets.isNotEmpty) ...[
                const SizedBox(height: AppSpace.s12),
                FloatingCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (final bullet in bullets)
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            vertical: AppSpace.s4,
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '•  ',
                                style: AppText.body.copyWith(color: p.text),
                              ),
                              Expanded(
                                child: Text(
                                  bullet,
                                  style: AppText.body.copyWith(color: p.text),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ],
              for (final pos in summary.positions) ...[
                const SizedBox(height: AppSpace.s12),
                _PositionCard(position: pos, currency: summary.currency),
              ],
              if (summary.discount > 0) ...[
                const SizedBox(height: AppSpace.s12),
                FloatingCard(
                  child: _Line(
                    title: summary.discountText,
                    amount: '-${summary.currency.format(summary.discount)}',
                  ),
                ),
              ],
              const SizedBox(height: AppSpace.s16),
              SecondaryButton(
                label: isOffer
                    ? 'share.view_offer'.tr()
                    : 'share.view_invoice'.tr(),
                onPressed: _openPdf,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget? _buildResponse(BuildContext context) {
    if (_localResponse == 'accepted' || _localResponse == 'declined') {
      final accepted = _localResponse == 'accepted';
      final p = AppPalette.of(context);
      return Padding(
        padding: EdgeInsets.fromLTRB(
          AppSize.barSide,
          0,
          AppSize.barSide,
          bottomBarInset(context) + AppSize.barGap,
        ),
        child: Center(
          heightFactor: 1,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: AppSize.maxBarWidth),
            child: FloatingCard(
              padding: const EdgeInsets.all(AppSpace.s16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  StatusDot(
                    accepted ? StatusKind.accepted : StatusKind.declined,
                  ),
                  const SizedBox(height: AppSpace.s8),
                  Text(
                    accepted
                        ? 'share.responded_accepted'.tr()
                        : 'share.responded_declined'.tr(),
                    style: AppText.body.copyWith(color: p.text),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        TextAction(
          label: 'share.decline'.tr(),
          onPressed: _responding ? null : () => _confirmAndRespond(false),
        ),
        GlassCtaBar(
          label: 'share.accept'.tr(),
          onPressed: _responding ? null : () => _confirmAndRespond(true),
        ),
      ],
    );
  }
}

class _PositionCard extends StatelessWidget {
  const _PositionCard({required this.position, required this.currency});

  final _Position position;
  final Currency currency;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final detail = position.isTbd
        ? null
        : position.quantity > 1
        ? '${position.quantity} × ${currency.format(position.price)}'
        : null;
    return FloatingCard(
      child: _Line(
        title: position.name,
        detail: detail,
        amount: position.isTbd ? 'tbd' : currency.format(position.total),
        color: p.text,
      ),
    );
  }
}

class _Line extends StatelessWidget {
  const _Line({
    required this.title,
    required this.amount,
    this.detail,
    this.color,
  });

  final String title;
  final String amount;
  final String? detail;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: AppText.section.copyWith(color: p.text)),
              if (detail != null)
                Text(
                  detail!,
                  style: AppText.caption.copyWith(color: p.textSecondary),
                ),
            ],
          ),
        ),
        const SizedBox(width: AppSpace.s12),
        Text(amount, style: AppText.number.copyWith(color: p.text)),
      ],
    );
  }
}
