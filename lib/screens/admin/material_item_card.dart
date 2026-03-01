import 'package:flutter/material.dart';

import '../../models/material_item.dart';

/// Card widget for displaying a material item in the admin list.
class MaterialItemCard extends StatelessWidget {
  const MaterialItemCard({
    super.key,
    required this.item,
    required this.onEdit,
    required this.onDelete,
    this.leading,
  });

  final MaterialItem item;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    final isInactive = !item.active;
    final isHidden = !item.visible;
    final colorScheme = Theme.of(context).colorScheme;

    return Opacity(
      opacity: isInactive || isHidden ? 0.5 : 1.0,
      child: Card(
        child: ListTile(
          leading: leading,
          title: Row(
            children: [
              Expanded(child: Text(item.name)),
              if (item.category != null) _buildCategoryChip(item.category!, colorScheme),
              if (isInactive) _buildInactiveIcon(),
              if (isHidden) _buildHiddenIcon(),
            ],
          ),
          subtitle: Text(_buildSubtitle()),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.edit),
                onPressed: onEdit,
              ),
              IconButton(
                icon: const Icon(Icons.delete, color: Colors.red),
                onPressed: onDelete,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryChip(String category, ColorScheme colorScheme) {
    final categoryLabels = {
      'supervisor': '👤 Supervisor',
      'purchase': '🛒 Kaufen',
      'bring': '🚚 Mitbringen',
      'other': '➕ Sonstige',
    };
    
    final categoryColors = {
      'supervisor': Colors.purple,
      'purchase': Colors.green,
      'bring': Colors.blue,
      'other': Colors.grey,
    };

    return Padding(
      padding: const EdgeInsets.only(left: 8, right: 4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: (categoryColors[category] ?? Colors.grey).withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          categoryLabels[category] ?? category,
          style: TextStyle(
            fontSize: 11,
            color: categoryColors[category] ?? Colors.grey,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildInactiveIcon() {
    return const Padding(
      padding: EdgeInsets.only(left: 4),
      child: Tooltip(
        message: 'Inaktiv – nicht in Einkaufsliste',
        child: Icon(Icons.block, size: 16, color: Colors.orange),
      ),
    );
  }

  Widget _buildHiddenIcon() {
    return const Padding(
      padding: EdgeInsets.only(left: 4),
      child: Tooltip(
        message: 'Versteckt',
        child: Icon(Icons.visibility_off, size: 16, color: Colors.grey),
      ),
    );
  }

  String _buildSubtitle() {
    final base = '${item.unit} • ${item.price.toStringAsFixed(2)} ${item.currency}';
    if (item.note.isNotEmpty) {
      return '$base • ${item.note}';
    }
    return base;
  }
}
