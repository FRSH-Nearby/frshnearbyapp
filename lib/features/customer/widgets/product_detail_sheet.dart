import 'package:flutter/material.dart' hide Text;
import 'package:intl/intl.dart';

import '../../../l10n/localized_text.dart';
import '../consumer_data.dart';

const _green = Color(0xFF2F6B45);
const _muted = Color(0xFF66735F);
const _cream = Color(0xFFFBFAF5);
const _line = Color(0xFFE1E8DD);

/// The product "push-up" detail window. Ordering itself stays on the
/// Explore tab (where basket state already lives) — this sheet is a rich,
/// read-only detail view with a hand-off button, matching the reference
/// design's informational sections (production, pickup) without inventing
/// a second, disconnected basket.
class ProductDetailSheet extends StatelessWidget {
  const ProductDetailSheet({
    required this.product,
    required this.onOpenExplore,
    super.key,
  });

  final ProductPost product;
  final VoidCallback onOpenExplore;

  @override
  Widget build(BuildContext context) => FractionallySizedBox(
    heightFactor: .86,
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
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 16),
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: Stack(
                    children: [
                      Image.memory(
                        product.imageBytes,
                        height: 220,
                        width: double.infinity,
                        fit: BoxFit.cover,
                      ),
                      Positioned(
                        right: 12,
                        top: 12,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: .94),
                            borderRadius: BorderRadius.circular(99),
                          ),
                          child: Text(
                            '${product.quantity.toStringAsFixed(product.quantity % 1 == 0 ? 0 : 1)} ${product.unitFor(context)} ${localizeText(context, 'left')}',
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 11.5,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        product.titleFor(context),
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    Text(
                      product.priceFor(context),
                      style: const TextStyle(
                        color: _green,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 14,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    _InfoChip(
                      icon: Icons.place_outlined,
                      label:
                          '${product.distanceKm.toStringAsFixed(1)} ${localizeText(context, 'km away')}',
                    ),
                    if (product.rating != null)
                      _InfoChip(
                        icon: Icons.star_rounded,
                        label: product.rating!.toStringAsFixed(1),
                        iconColor: const Color(0xFFD9A441),
                      ),
                    if (product.producedAt != null)
                      _InfoChip(
                        icon: Icons.event_outlined,
                        label:
                            '${localizeText(context, 'Produced')} ${DateFormat('d MMM').format(product.producedAt!)}',
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  product.descriptionFor(context),
                  style: const TextStyle(height: 1.5),
                ),
                if (product.productionDetailFor(context)?.isNotEmpty ==
                    true) ...[
                  const SizedBox(height: 18),
                  Text(
                    localizeText(context, 'Production details'),
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    product.productionDetailFor(context)!,
                    style: const TextStyle(color: _muted, height: 1.4),
                  ),
                ],
                const SizedBox(height: 22),
                Text(
                  localizeText(context, 'Sold by'),
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(13),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 22,
                        backgroundColor: const Color(0xFFE5EFDF),
                        backgroundImage:
                            product.farmProfilePhotoUrl?.isNotEmpty == true
                                ? NetworkImage(product.farmProfilePhotoUrl!)
                                : null,
                        child:
                            product.farmProfilePhotoUrl?.isNotEmpty == true
                                ? null
                                : Text(
                                  product.farmName.characters.first
                                      .toUpperCase(),
                                  style: const TextStyle(
                                    color: _green,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                      ),
                      const SizedBox(width: 11),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              product.farmName,
                              style: const TextStyle(fontWeight: FontWeight.w900),
                            ),
                            if (product.farmLocation.isNotEmpty)
                              Text(
                                product.farmLocation,
                                style: const TextStyle(color: _muted, fontSize: 12.5),
                              ),
                          ],
                        ),
                      ),
                      const Icon(Icons.storefront_outlined, color: _green),
                    ],
                  ),
                ),
                if (product.availableAtFarm || product.rekoRings.isNotEmpty) ...[
                  const SizedBox(height: 22),
                  Text(
                    localizeText(context, 'Available at'),
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 8),
                  if (product.availableAtFarm)
                    _PickupCard(
                      icon: Icons.storefront_rounded,
                      title: localizeText(context, 'Farm pickup'),
                      subtitle:
                          product.farmLocation.isEmpty
                              ? product.farmName
                              : product.farmLocation,
                    ),
                  for (final ring in product.rekoRings)
                    _PickupCard(
                      icon: Icons.location_on_rounded,
                      title: ring.name,
                      subtitle: ring.details,
                    ),
                ],
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 8, 18, 14),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: onOpenExplore,
                  icon: const Icon(Icons.shopping_basket_outlined),
                  label: Text(localizeText(context, 'View & order on Explore')),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 15),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.icon, required this.label, this.iconColor});
  final IconData icon;
  final String label;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 16, color: iconColor ?? _muted),
      const SizedBox(width: 4),
      Text(
        label,
        style: const TextStyle(color: _muted, fontWeight: FontWeight.w700, fontSize: 12.5),
      ),
    ],
  );
}

class _PickupCard extends StatelessWidget {
  const _PickupCard({required this.icon, required this.title, required this.subtitle});
  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 9),
    padding: const EdgeInsets.all(13),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: _line),
    ),
    child: Row(
      children: [
        Icon(icon, color: _green),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
              Text(subtitle, style: const TextStyle(color: _muted)),
            ],
          ),
        ),
      ],
    ),
  );
}
