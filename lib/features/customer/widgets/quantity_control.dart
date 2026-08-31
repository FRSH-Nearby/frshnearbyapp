import 'package:flutter/material.dart' hide Text;

import '../../../l10n/localized_text.dart';
import '../consumer_data.dart';

/// Add / stepper control for one product's basket quantity. Shared between
/// Explore's map sheets and Home's product push-up so both read/write the
/// same [ProductPost] quantity semantics identically.
class QuantityControl extends StatelessWidget {
  const QuantityControl({
    required this.sale,
    required this.selectedQuantity,
    required this.onAdd,
    required this.onRemove,
    super.key,
  });
  final ProductPost sale;
  final double selectedQuantity;
  final VoidCallback onAdd;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    if (selectedQuantity <= 0) {
      return SizedBox(
        width: double.infinity,
        child: FilledButton.icon(
          onPressed: sale.quantity > 0 ? onAdd : null,
          icon: const Icon(Icons.add_rounded, size: 18),
          label: const Text('Add'),
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 10),
          ),
        ),
      );
    }
    final canAdd = selectedQuantity + sale.quantityStep <= sale.quantity + .0001;
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFE6F0E1),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            onPressed: onRemove,
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.remove_rounded),
          ),
          Expanded(
            child: Text(
              sale.formatQuantity(context, selectedQuantity),
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
          ),
          IconButton(
            onPressed: canAdd ? onAdd : null,
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.add_rounded),
          ),
        ],
      ),
    );
  }
}
