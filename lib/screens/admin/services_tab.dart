import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../data/additional_service_repository.dart';
import '../../models/additional_service.dart';
import '../../services/cloudinary_uploader.dart';

/// Tab for managing the additional-services catalog (add/edit/delete
/// services and their variants), with responsive design mirroring
/// `employees_tab.dart`.
///
/// Image handling: an admin uploads an image from their device via
/// Cloudinary's unsigned-upload API (`CloudinaryUploader`) - no Firebase
/// Storage needed, no secret key in this app. There is deliberately no
/// manual URL-paste field anymore; upload is the only path.
class ServicesTab extends StatefulWidget {
  const ServicesTab({super.key});

  @override
  State<ServicesTab> createState() => _ServicesTabState();
}

/// Mutable draft of a [ServiceVariant] used while editing in the add/edit
/// dialog, before it is converted back to an immutable [ServiceVariant].
class _VariantDraft {
  _VariantDraft({String? id, String name = '', double? price})
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
      price: priceText.isEmpty ? null : double.tryParse(priceText.replaceAll(',', '.')),
    );
  }

  void dispose() {
    nameController.dispose();
    priceController.dispose();
  }
}

class _ServicesTabState extends State<ServicesTab> {
  final _nameController = TextEditingController();
  final _imageUrlController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isAdding = false;
  bool _isReordering = false;
  bool _isUploadingImage = false;
  bool _isImportingLegacy = false;

  /// The 10 services that used to be hardcoded flat button IDs (see
  /// `lib/utils/order_option_labels.dart`'s `_additionalServiceLabelsDe`),
  /// grouped into services with variants where the legacy list had more
  /// than one price point for the same real-world offering (PhotoBox).
  /// `other_services` ("Sonstiges") is deliberately excluded - it stays a
  /// plain flag on the order form, not a catalog entry (see the design
  /// spec's section 5).
  static final List<(String, List<(String, double?)>)> _legacyServices = [
    ('BlackLodge - 360 Booth', [('Standard', 600.0)]),
    (
      'BlackLodge - PhotoBox',
      [('inkl. 300 Druck', 500.0), ('Digital mit QR-Code', 300.0)],
    ),
    ('BlackLodge - Bubble Waffles', [('Standard', 250.0)]),
    ('BlackLodge - Catering', [('Standard', null)]),
    ('Nirosi Singh - Choreographer', [('Standard', null)]),
    ('Extern - DJs', [('Standard', null)]),
    ('Extern - LED Screen', [('Standard', null)]),
    ('Mudanca Security', [('min. 2 Securitys á 40 CHF/h', null)]),
    ('Entry Song mit Geige - Praveen', [('Standard', 300.0)]),
  ];

  /// True once every legacy service name already exists in the catalog -
  /// used to hide the import button once it has done its job, rather than
  /// a one-time flag, so it stays hidden even after a reload and reappears
  /// correctly if a legacy-named service is ever deleted again.
  bool get _allLegacyServicesImported => _legacyServices.every(
        (entry) => _localServices.any((s) => s.name == entry.$1),
      );

  /// One-off migration: adds any of `_legacyServices` not already present
  /// in the catalog (matched by name, so it's safe to run more than once).
  Future<void> _importLegacyServices() async {
    setState(() => _isImportingLegacy = true);
    final existingNames = _localServices.map((s) => s.name).toSet();
    var importedCount = 0;
    for (final (name, variantSpecs) in _legacyServices) {
      if (existingNames.contains(name)) continue;
      final success = await additionalServiceRepository.addService(
        name: name,
        variants: variantSpecs
            .map(
              (spec) => ServiceVariant(
                id: UniqueKey().toString(),
                name: spec.$1,
                price: spec.$2,
              ),
            )
            .toList(),
      );
      if (success) importedCount++;
    }
    setState(() => _isImportingLegacy = false);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'admin.service_legacy_imported'.tr(args: ['$importedCount']),
        ),
      ),
    );
  }
  List<_VariantDraft> _addVariantDrafts = [];
  List<AdditionalService> _localServices = [];

  @override
  void dispose() {
    _nameController.dispose();
    _imageUrlController.dispose();
    for (final draft in _addVariantDrafts) {
      draft.dispose();
    }
    super.dispose();
  }

  /// Picks an image from the admin's device and uploads it to Cloudinary,
  /// setting [controller]'s text to the resulting URL on success.
  ///
  /// [setFormState] must rebuild whichever widget subtree is showing the
  /// upload button: the outer `setState` for the inline add-form, or the
  /// edit dialog's own `setDialogState` (a `StatefulBuilder` opened via
  /// `showDialog` is a separate subtree from this State, so this State's
  /// own `setState` would not repaint the dialog's spinner/disabled state).
  Future<void> _pickAndUploadImage(
    TextEditingController controller,
    void Function(void Function()) setFormState,
  ) async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (picked == null) return;

    setFormState(() => _isUploadingImage = true);
    final bytes = await picked.readAsBytes();
    final url = await cloudinaryUploader.uploadImage(bytes, picked.name);
    setFormState(() => _isUploadingImage = false);

    if (!mounted) return;

    if (url != null) {
      controller.text = url;
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('admin.service_image_upload_failed'.tr())),
      );
    }
  }

  Future<void> _addService() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isAdding = true);
    final imageUrl = _imageUrlController.text.trim();
    final variants = _addVariantDrafts
        .map((d) => d.toVariant())
        .where((v) => v.name.isNotEmpty)
        .toList();
    final success = await additionalServiceRepository.addService(
      name: _nameController.text.trim(),
      imageUrl: imageUrl.isEmpty ? null : imageUrl,
      variants: variants,
    );
    setState(() => _isAdding = false);

    if (!mounted) return;

    if (success) {
      _nameController.clear();
      _imageUrlController.clear();
      setState(() {
        for (final draft in _addVariantDrafts) {
          draft.dispose();
        }
        _addVariantDrafts = [];
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('admin.service_added'.tr())),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('common.add_error'.tr())),
      );
    }
  }

  void _addVariantDraftRow() {
    setState(() => _addVariantDrafts.add(_VariantDraft()));
  }

  void _removeVariantDraftRow(_VariantDraft draft) {
    setState(() {
      _addVariantDrafts.remove(draft);
      draft.dispose();
    });
  }

  Future<void> _deleteService(AdditionalService service) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('admin.delete_service_confirm_title'.tr()),
        content: Text(
          'admin.delete_service_confirm_message'.tr(
            namedArgs: {'name': service.name},
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('common.cancel'.tr()),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('common.delete'.tr()),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    final success = await additionalServiceRepository.deleteService(
      service.id,
    );
    if (!mounted) return;

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('admin.service_deleted'.tr())),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('common.error'.tr())),
      );
    }
  }

  Future<void> _editService(AdditionalService service) async {
    final nameController = TextEditingController(text: service.name);
    final imageUrlController = TextEditingController(
      text: service.imageUrl ?? '',
    );
    final drafts = service.variants
        .map(
          (v) => _VariantDraft(id: v.id, name: v.name, price: v.price),
        )
        .toList();
    final formKey = GlobalKey<FormState>();

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text('admin.edit_service'.tr()),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: _buildServiceForm(
                nameController: nameController,
                imageUrlController: imageUrlController,
                drafts: drafts,
                onAddVariant: () =>
                    setDialogState(() => drafts.add(_VariantDraft())),
                onRemoveVariant: (draft) => setDialogState(() {
                  drafts.remove(draft);
                  draft.dispose();
                }),
                setFormState: setDialogState,
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text('common.cancel'.tr()),
            ),
            TextButton(
              onPressed: () {
                if (formKey.currentState!.validate()) {
                  Navigator.pop(ctx, true);
                }
              },
              child: Text('common.save'.tr()),
            ),
          ],
        ),
      ),
    );

    if (result != true) {
      for (final draft in drafts) {
        draft.dispose();
      }
      nameController.dispose();
      imageUrlController.dispose();
      return;
    }

    final imageUrl = imageUrlController.text.trim();
    final variants = drafts
        .map((d) => d.toVariant())
        .where((v) => v.name.isNotEmpty)
        .toList();
    final success = await additionalServiceRepository.updateService(
      id: service.id,
      name: nameController.text.trim(),
      imageUrl: imageUrl.isEmpty ? null : imageUrl,
      variants: variants,
    );

    for (final draft in drafts) {
      draft.dispose();
    }
    nameController.dispose();
    imageUrlController.dispose();

    if (!mounted) return;

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('admin.service_updated'.tr())),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('common.error'.tr())),
      );
    }
  }

  Future<void> _onReorder(int oldIndex, int newIndex) async {
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }
    setState(() => _isReordering = true);
    final service = _localServices.removeAt(oldIndex);
    _localServices.insert(newIndex, service);

    await additionalServiceRepository.reorderServices(_localServices);
    if (mounted) {
      setState(() => _isReordering = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth > 900;
        final isTablet =
            constraints.maxWidth > 600 && constraints.maxWidth <= 900;

        return StreamBuilder<List<AdditionalService>>(
          stream: additionalServiceRepository.watchServices(),
          builder: (context, snapshot) {
            if (snapshot.hasData && !_isReordering) {
              _localServices = List.from(snapshot.data!);
            }
            final services = _localServices;

            if (isDesktop) {
              return _buildDesktopLayout(services);
            } else if (isTablet) {
              return _buildTabletLayout(services);
            } else {
              return _buildMobileLayout(services);
            }
          },
        );
      },
    );
  }

  Widget _buildDesktopLayout(List<AdditionalService> services) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 2,
          child: _buildServiceList(services, compact: false),
        ),
        const VerticalDivider(width: 1),
        Expanded(
          flex: 1,
          child: _buildAddForm(),
        ),
      ],
    );
  }

  Widget _buildTabletLayout(List<AdditionalService> services) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildAddForm(),
          const SizedBox(height: 24),
          _buildServiceList(services, compact: false),
        ],
      ),
    );
  }

  Widget _buildMobileLayout(List<AdditionalService> services) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildAddForm(),
          const SizedBox(height: 16),
          _buildServiceList(services, compact: true),
        ],
      ),
    );
  }

  Widget _buildServiceForm({
    required TextEditingController nameController,
    required TextEditingController imageUrlController,
    required List<_VariantDraft> drafts,
    required VoidCallback onAddVariant,
    required void Function(_VariantDraft draft) onRemoveVariant,
    required void Function(void Function()) setFormState,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextFormField(
          controller: nameController,
          decoration: InputDecoration(
            labelText: 'admin.service_name'.tr(),
            border: const OutlineInputBorder(),
            prefixIcon: const Icon(Icons.local_offer),
          ),
          validator: (v) =>
              v?.trim().isEmpty ?? true ? 'offer.field_required'.tr() : null,
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            OutlinedButton.icon(
              onPressed: _isUploadingImage
                  ? null
                  : () => _pickAndUploadImage(imageUrlController, setFormState),
              icon: _isUploadingImage
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.upload),
              label: Text('admin.service_image_upload'.tr()),
            ),
            const SizedBox(width: 12),
            if (imageUrlController.text.trim().isNotEmpty) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: Image.network(
                  imageUrlController.text.trim(),
                  width: 40,
                  height: 40,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) =>
                      const Icon(Icons.broken_image_outlined),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, size: 18),
                tooltip: 'admin.service_image_remove'.tr(),
                onPressed: () =>
                    setFormState(() => imageUrlController.clear()),
              ),
            ],
          ],
        ),
        const SizedBox(height: 24),
        Align(
          alignment: Alignment.centerLeft,
          child: Text(
            'admin.service_variants'.tr(),
            style: Theme.of(context).textTheme.titleSmall,
          ),
        ),
        const SizedBox(height: 8),
        for (final draft in drafts) _buildVariantRow(draft, onRemoveVariant),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: onAddVariant,
            icon: const Icon(Icons.add),
            label: Text('admin.add_variant'.tr()),
          ),
        ),
      ],
    );
  }

  Widget _buildVariantRow(
    _VariantDraft draft,
    void Function(_VariantDraft draft) onRemove,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            flex: 2,
            child: TextField(
              controller: draft.nameController,
              decoration: InputDecoration(
                labelText: 'admin.variant_name'.tr(),
                border: const OutlineInputBorder(),
                isDense: true,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: draft.priceController,
              decoration: InputDecoration(
                labelText: 'admin.variant_price'.tr(),
                hintText: 'admin.variant_price_hint'.tr(),
                border: const OutlineInputBorder(),
                isDense: true,
              ),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: () => onRemove(draft),
            tooltip: 'common.delete'.tr(),
          ),
        ],
      ),
    );
  }

  Widget _buildAddForm() {
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'admin.add_service'.tr(),
                style: Theme.of(context).textTheme.titleLarge,
              ),
              if (!_allLegacyServicesImported) ...[
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed:
                        _isImportingLegacy ? null : _importLegacyServices,
                    icon: _isImportingLegacy
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.download),
                    label: Text('admin.service_import_legacy'.tr()),
                  ),
                ),
              ],
              const SizedBox(height: 16),
              _buildServiceForm(
                nameController: _nameController,
                imageUrlController: _imageUrlController,
                drafts: _addVariantDrafts,
                onAddVariant: _addVariantDraftRow,
                onRemoveVariant: _removeVariantDraftRow,
                setFormState: setState,
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _isAdding ? null : _addService,
                icon: _isAdding
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.add),
                label: Text('common.add'.tr()),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildServiceList(
    List<AdditionalService> services, {
    required bool compact,
  }) {
    if (services.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(
            'admin.services_empty'.tr(),
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Colors.grey,
                ),
          ),
        ),
      );
    }

    return ReorderableListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: services.length,
      onReorder: _onReorder,
      buildDefaultDragHandles: false,
      itemBuilder: (context, index) {
        final service = services[index];
        return Card(
          key: ValueKey(service.id),
          margin: EdgeInsets.symmetric(
            horizontal: compact ? 0 : 16,
            vertical: 4,
          ),
          child: ListTile(
            leading: ReorderableDragStartListener(
              index: index,
              child: const Icon(Icons.drag_handle),
            ),
            title: Text(service.name),
            subtitle: Text(
              'admin.service_variant_count'.tr(
                namedArgs: {'count': '${service.variants.length}'},
              ),
            ),
            onTap: () => _editService(service),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (service.imageUrl != null &&
                    service.imageUrl!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: Image.network(
                        service.imageUrl!,
                        width: 40,
                        height: 40,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) =>
                            const Icon(Icons.broken_image, size: 40),
                      ),
                    ),
                  ),
                IconButton(
                  icon: const Icon(Icons.edit),
                  onPressed: () => _editService(service),
                  tooltip: 'common.edit'.tr(),
                ),
                IconButton(
                  icon: const Icon(Icons.delete),
                  onPressed: () => _deleteService(service),
                  tooltip: 'common.delete'.tr(),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
