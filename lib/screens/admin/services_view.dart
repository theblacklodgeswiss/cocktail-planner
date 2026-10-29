import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../models/additional_service.dart';
import '../../ui/tokens.dart';
import '../../ui/widgets/app_sheet.dart';
import '../../ui/widgets/buttons.dart';
import '../../ui/widgets/states.dart';
import 'admin_widgets.dart';

/// Mutable draft of a [ServiceVariant] while editing in the sheet.
class VariantDraft {
  VariantDraft({String? id, String name = '', double? price})
    : id = id ?? UniqueKey().toString(),
      nameController = TextEditingController(text: name),
      priceController = TextEditingController(
        text: price != null ? price.toStringAsFixed(2) : '',
      );

  final String id;
  final TextEditingController nameController;
  final TextEditingController priceController;

  ServiceVariant toVariant() {
    final priceText = priceController.text.trim();
    return ServiceVariant(
      id: id,
      name: nameController.text.trim(),
      price: priceText.isEmpty
          ? null
          : double.tryParse(priceText.replaceAll(',', '.')),
    );
  }

  void dispose() {
    nameController.dispose();
    priceController.dispose();
  }
}

/// Values of the service form; unnamed variants are already dropped.
typedef ServiceFormResult = ({
  String name,
  String? imageUrl,
  List<ServiceVariant> variants,
});

/// Pure service list: FloatingCard rows (drag to reorder), add via FAB, edit
/// in a sheet, delete after a confirm sheet. Writes are injected.
class ServicesView extends StatefulWidget {
  const ServicesView({
    super.key,
    required this.services,
    required this.loading,
    required this.errorMessage,
    required this.onRetry,
    required this.onAdd,
    required this.onUpdate,
    required this.onDelete,
    required this.onReorder,
    required this.onPickImage,
    required this.showImportLegacy,
    required this.onImportLegacy,
  });

  final List<AdditionalService> services;
  final bool loading;
  final String? errorMessage;
  final VoidCallback onRetry;
  final Future<bool> Function(ServiceFormResult result) onAdd;
  final Future<bool> Function(String id, ServiceFormResult result) onUpdate;
  final Future<bool> Function(AdditionalService service) onDelete;
  final Future<void> Function(int oldIndex, int newIndex) onReorder;

  /// Picks and uploads an image; returns its URL or null (cancelled/failed).
  final Future<String?> Function() onPickImage;

  /// Whether the one-off legacy import is still offered.
  final bool showImportLegacy;

  /// Returns the number of imported services.
  final Future<int> Function() onImportLegacy;

  @override
  State<ServicesView> createState() => _ServicesViewState();
}

class _ServicesViewState extends State<ServicesView> {
  bool _importing = false;

  Future<void> _edit([AdditionalService? service]) async {
    final messenger = ScaffoldMessenger.of(context);
    final ok = await showAppSheet<bool>(
      context,
      scrollable: false,
      builder: (_) => ServiceForm(
        service: service,
        onPickImage: widget.onPickImage,
        onSubmit: (r) =>
            service == null ? widget.onAdd(r) : widget.onUpdate(service.id, r),
      ),
    );
    if (ok == true) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            (service == null ? 'admin.service_added' : 'admin.service_updated')
                .tr(),
          ),
        ),
      );
    }
  }

  Future<void> _delete(AdditionalService service) async {
    final messenger = ScaffoldMessenger.of(context);
    final ok = await showConfirmSheet(
      context,
      title: 'admin.delete_service_confirm_title'.tr(),
      body: 'admin.delete_service_confirm_message'.tr(
        namedArgs: {'name': service.name},
      ),
      confirmLabel: 'common.delete'.tr(),
      destructive: true,
    );
    if (!ok) return;
    final success = await widget.onDelete(service);
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          success ? 'admin.service_deleted'.tr() : 'common.error'.tr(),
        ),
      ),
    );
  }

  Future<void> _import() async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _importing = true);
    final count = await widget.onImportLegacy();
    if (!mounted) return;
    setState(() => _importing = false);
    messenger.showSnackBar(
      SnackBar(
        content: Text('admin.service_legacy_imported'.tr(args: ['$count'])),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final services = widget.services;
    return AdminPage(
      title: 'admin.tab_services'.tr(),
      loading: widget.loading,
      errorMessage: widget.errorMessage,
      onRetry: widget.onRetry,
      onAdd: () => _edit(),
      addLabel: 'admin.add_service'.tr(),
      header: widget.showImportLegacy
          ? Align(
              alignment: Alignment.centerLeft,
              child: TextAction(
                label: 'admin.service_import_legacy'.tr(),
                loading: _importing,
                onPressed: _importing ? null : _import,
              ),
            )
          : null,
      slivers: [
        if (services.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: EmptyState(
              icon: Icons.local_offer_outlined,
              title: 'admin.services_empty'.tr(),
            ),
          )
        else
          AdminSliverList(
            count: services.length,
            idAt: (i) => services[i].id,
            onReorder: widget.onReorder,
            itemBuilder: (context, i, handle) {
              final s = services[i];
              final image = s.imageUrl;
              return AdminRowCard(
                title: s.name,
                subtitle: 'admin.service_variant_count'.tr(
                  namedArgs: {'count': '${s.variants.length}'},
                ),
                leading: handle,
                onTap: () => _edit(s),
                trailing: [
                  if (image != null && image.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(right: AppSpace.s4),
                      child: _Thumb(url: image),
                    ),
                  RowIconButton(
                    icon: Icons.delete_outline,
                    label: 'common.delete'.tr(),
                    destructive: true,
                    onPressed: () => _delete(s),
                  ),
                ],
              );
            },
          ),
      ],
    );
  }
}

class _Thumb extends StatelessWidget {
  const _Thumb({required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Semantics(
      image: true,
      label: 'admin2.image_preview'.tr(),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.control),
        child: Image.network(
          url,
          width: AppSize.avatar,
          height: AppSize.avatar,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => SizedBox.square(
            dimension: AppSize.avatar,
            child: Icon(Icons.broken_image_outlined, color: p.textSecondary),
          ),
        ),
      ),
    );
  }
}

/// Sheet form for adding or editing a service with its variants.
class ServiceForm extends StatefulWidget {
  const ServiceForm({
    super.key,
    this.service,
    required this.onPickImage,
    required this.onSubmit,
  });

  final AdditionalService? service;
  final Future<String?> Function() onPickImage;
  final Future<bool> Function(ServiceFormResult result) onSubmit;

  @override
  State<ServiceForm> createState() => _ServiceFormState();
}

class _ServiceFormState extends State<ServiceForm> {
  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.service?.name ?? '');
  late String _imageUrl = widget.service?.imageUrl ?? '';
  late final List<VariantDraft> _drafts = [
    for (final v in widget.service?.variants ?? const <ServiceVariant>[])
      VariantDraft(id: v.id, name: v.name, price: v.price),
  ];
  bool _uploading = false;

  @override
  void dispose() {
    _name.dispose();
    for (final d in _drafts) {
      d.dispose();
    }
    super.dispose();
  }

  Future<void> _pick() async {
    setState(() => _uploading = true);
    final url = await widget.onPickImage();
    if (!mounted) return;
    setState(() {
      _uploading = false;
      if (url != null) _imageUrl = url;
    });
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final adding = widget.service == null;
    return AdminFormSheet(
      title: adding ? 'admin.add_service'.tr() : 'admin.edit_service'.tr(),
      saveLabel: adding ? 'common.add'.tr() : 'common.save'.tr(),
      errorText: adding ? 'common.add_error'.tr() : 'common.error'.tr(),
      validate: () => _formKey.currentState!.validate(),
      onSubmit: () {
        final url = _imageUrl.trim();
        return widget.onSubmit((
          name: _name.text.trim(),
          imageUrl: url.isEmpty ? null : url,
          variants: _drafts
              .map((d) => d.toVariant())
              .where((v) => v.name.isNotEmpty)
              .toList(),
        ));
      },
      fields: [
        Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                key: const Key('service-name'),
                controller: _name,
                decoration: InputDecoration(
                  labelText: 'admin.service_name'.tr(),
                ),
                validator: (v) => v?.trim().isEmpty ?? true
                    ? 'offer.field_required'.tr()
                    : null,
              ),
              AdminFormSheet.gap,
              SecondaryButton(
                label: 'admin.service_image_upload'.tr(),
                loading: _uploading,
                onPressed: _uploading ? null : _pick,
              ),
              if (_imageUrl.trim().isNotEmpty) ...[
                const SizedBox(height: AppSpace.s8),
                Row(
                  children: [
                    _Thumb(url: _imageUrl.trim()),
                    const Spacer(),
                    RowIconButton(
                      icon: Icons.close,
                      label: 'admin.service_image_remove'.tr(),
                      onPressed: () => setState(() => _imageUrl = ''),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: AppSpace.s16),
              Semantics(
                header: true,
                child: Text(
                  'admin.service_variants'.tr(),
                  style: AppText.section.copyWith(color: p.text),
                ),
              ),
              const SizedBox(height: AppSpace.s8),
              for (final draft in _drafts)
                _VariantFields(
                  key: ValueKey(draft.id),
                  draft: draft,
                  onRemove: () => setState(() {
                    _drafts.remove(draft);
                    draft.dispose();
                  }),
                ),
              TextAction(
                label: 'admin.add_variant'.tr(),
                onPressed: () => setState(() => _drafts.add(VariantDraft())),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _VariantFields extends StatelessWidget {
  const _VariantFields({super.key, required this.draft, required this.onRemove});

  final VariantDraft draft;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpace.s12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              children: [
                TextField(
                  controller: draft.nameController,
                  decoration: InputDecoration(
                    labelText: 'admin.variant_name'.tr(),
                  ),
                ),
                const SizedBox(height: AppSpace.s8),
                TextField(
                  controller: draft.priceController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: InputDecoration(
                    labelText: 'admin.variant_price'.tr(),
                    hintText: 'admin.variant_price_hint'.tr(),
                  ),
                ),
              ],
            ),
          ),
          RowIconButton(
            icon: Icons.delete_outline,
            label: 'common.delete'.tr(),
            destructive: true,
            onPressed: onRemove,
          ),
        ],
      ),
    );
  }
}
