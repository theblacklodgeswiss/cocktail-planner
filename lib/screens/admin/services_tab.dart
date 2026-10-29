import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../data/additional_service_repository.dart';
import '../../models/additional_service.dart';
import '../../services/cloudinary_uploader.dart';
import 'services_view.dart';

/// Data wrapper of the additional-services page (stream + repository writes).
///
/// Image handling: an admin uploads an image from their device via
/// Cloudinary's unsigned-upload API (`CloudinaryUploader`) - no Firebase
/// Storage needed, no secret key in this app. There is deliberately no
/// manual URL-paste field; upload is the only path.
class ServicesTab extends StatefulWidget {
  const ServicesTab({super.key});

  @override
  State<ServicesTab> createState() => _ServicesTabState();
}

class _ServicesTabState extends State<ServicesTab> {
  bool _isReordering = false;
  List<AdditionalService> _local = [];
  late Stream<List<AdditionalService>> _stream =
      additionalServiceRepository.watchServices();

  /// The services that used to be hardcoded flat button IDs (see
  /// `lib/utils/order_option_labels.dart`'s `_additionalServiceLabelsDe`),
  /// grouped into services with variants where the legacy list had more
  /// than one price point for the same real-world offering (PhotoBox).
  /// `other_services` ("Sonstiges") is deliberately excluded - it stays a
  /// plain flag on the order form, not a catalog entry.
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

  /// True once every legacy service name already exists in the catalog.
  bool get _allLegacyImported => _legacyServices.every(
    (entry) => _local.any((s) => s.name == entry.$1),
  );

  /// One-off migration: adds any of `_legacyServices` not already present
  /// (matched by name, so it is safe to run more than once).
  Future<int> _importLegacy() async {
    final existing = _local.map((s) => s.name).toSet();
    var imported = 0;
    for (final (name, specs) in _legacyServices) {
      if (existing.contains(name)) continue;
      final success = await additionalServiceRepository.addService(
        name: name,
        variants: specs
            .map(
              (spec) => ServiceVariant(
                id: UniqueKey().toString(),
                name: spec.$1,
                price: spec.$2,
              ),
            )
            .toList(),
      );
      if (success) imported++;
    }
    return imported;
  }

  /// Picks an image from the device and uploads it to Cloudinary; null when
  /// cancelled or failed (then a snackbar explains).
  Future<String?> _pickImage() async {
    final messenger = ScaffoldMessenger.of(context);
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (picked == null) return null;
    final bytes = await picked.readAsBytes();
    final url = await cloudinaryUploader.uploadImage(bytes, picked.name);
    if (url == null) {
      messenger.showSnackBar(
        SnackBar(content: Text('admin.service_image_upload_failed'.tr())),
      );
    }
    return url;
  }

  Future<void> _onReorder(int oldIndex, int newIndex) async {
    if (oldIndex < newIndex) newIndex -= 1;
    setState(() => _isReordering = true);
    final service = _local.removeAt(oldIndex);
    _local.insert(newIndex, service);
    await additionalServiceRepository.reorderServices(_local);
    if (mounted) setState(() => _isReordering = false);
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<AdditionalService>>(
      stream: _stream,
      builder: (context, snapshot) {
        if (snapshot.hasData && !_isReordering) {
          _local = List.from(snapshot.data!);
        }
        return ServicesView(
          services: _local,
          loading: !snapshot.hasData && !snapshot.hasError,
          errorMessage: snapshot.hasError && !snapshot.hasData
              ? 'admin2.load_error'.tr()
              : null,
          onRetry: () => setState(() {
            _stream = additionalServiceRepository.watchServices();
          }),
          onAdd: (r) => additionalServiceRepository.addService(
            name: r.name,
            imageUrl: r.imageUrl,
            variants: r.variants,
          ),
          onUpdate: (id, r) => additionalServiceRepository.updateService(
            id: id,
            name: r.name,
            imageUrl: r.imageUrl,
            variants: r.variants,
          ),
          onDelete: (s) => additionalServiceRepository.deleteService(s.id),
          onReorder: _onReorder,
          onPickImage: _pickImage,
          showImportLegacy: snapshot.hasData && !_allLegacyImported,
          onImportLegacy: _importLegacy,
        );
      },
    );
  }
}
