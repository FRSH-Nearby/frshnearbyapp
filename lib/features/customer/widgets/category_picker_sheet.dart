import 'package:flutter/material.dart' hide Text;

import '../../../l10n/localized_text.dart';
import '../consumer_data.dart';

const _green = Color(0xFF2F6B45);
const _ink = Color(0xFF1B2A20);
const _cream = Color(0xFFFBFAF5);
const _line = Color(0xFFE7E5DB);

/// "Show all" categories overlay — a white sheet listing every
/// [kProductCategories] entry, not just the row shown inline on Home.
class CategoryPickerSheet extends StatelessWidget {
  const CategoryPickerSheet({required this.onSelect, super.key});
  final ValueChanged<ProductCategory> onSelect;

  @override
  Widget build(BuildContext context) => FractionallySizedBox(
    heightFactor: .7,
    child: Material(
      color: _cream,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          const SizedBox(height: 10),
          Container(
            width: 42,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.black26,
              borderRadius: BorderRadius.circular(99),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    localizeText(context, 'Product categories'),
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                mainAxisSpacing: 16,
                crossAxisSpacing: 12,
                childAspectRatio: .82,
              ),
              itemCount: kProductCategories.length,
              itemBuilder: (context, index) {
                final category = kProductCategories[index];
                return InkWell(
                  borderRadius: BorderRadius.circular(18),
                  onTap: () {
                    Navigator.of(context).pop();
                    onSelect(category);
                  },
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 58,
                        height: 58,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          border: Border.all(color: _line),
                        ),
                        child: Icon(category.icon, color: _green),
                      ),
                      const SizedBox(height: 7),
                      Text(
                        localizeText(context, category.label),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: _ink,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    ),
  );
}
