import 'package:flutter/material.dart' hide Text;
import 'package:intl/intl.dart';

import '../../../l10n/localized_text.dart';
import '../basket_controller.dart';
import '../consumer_data.dart';
import 'basket_sheet.dart';
import 'quantity_control.dart';

const _green = Color(0xFF2F6B45);
const _muted = Color(0xFF66735F);
const _cream = Color(0xFFFBFAF5);
const _line = Color(0xFFE1E8DD);
const _basketTint = Color(0xFFE6F0E1);

/// The product "push-up" detail window: full info plus the same add-to-basket
/// flow Explore uses (shared [BasketController]), so adding a product here
/// and checking out lands in the same order regardless of which tab you
/// started from.
class ProductDetailSheet extends StatelessWidget {
  const ProductDetailSheet({
    required this.product,
    required this.allProducts,
    required this.basket,
    super.key,
  });

  final ProductPost product;

  /// The full loaded catalog, used to find this farm's other products for
  /// "Complete this farm order".
  final List<ProductPost> allProducts;
  final BasketController basket;

  void _openCheckout(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder:
          (_) => BasketSheet(
            farmId: product.farmId,
            farmSales:
                allProducts.where((sale) => sale.farmId == product.farmId).toList(),
            basket: basket,
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final otherFarmSales =
        allProducts
            .where((sale) => sale.farmId == product.farmId && sale.id != product.id)
            .toList();

    return AnimatedBuilder(
      animation: basket,
      builder: (context, _) {
        final quantity = basket.quantityFor(product.farmId, product.id);
        final farmLines = basket.lineCount(product.farmId);
        final farmTotal = allProducts
            .where((sale) => sale.farmId == product.farmId)
            .fold<double>(
              0,
              (total, sale) =>
                  total +
                  basket.quantityFor(product.farmId, sale.id) *
                      sale.priceCents /
                      100,
            );

        return FractionallySizedBox(
          heightFactor: .9,
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
                              child: _Pill(
                                text:
                                    '${product.quantity.toStringAsFixed(product.quantity % 1 == 0 ? 0 : 1)} ${product.unitFor(context)} ${localizeText(context, 'left')}',
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
                              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
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
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900),
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
                          ],
                        ),
                      ),
                      if (product.availableAtFarm ||
                          product.rekoRings.isNotEmpty) ...[
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
                      const SizedBox(height: 22),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: quantity > 0 ? _basketTint : Colors.white,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: quantity > 0 ? _green.withValues(alpha: .35) : _line,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.shopping_basket_outlined, size: 18, color: _green),
                                const SizedBox(width: 7),
                                Expanded(
                                  child: Text(
                                    '${localizeText(context, 'Your')} ${product.farmName} ${localizeText(context, 'basket')}',
                                    style: const TextStyle(fontWeight: FontWeight.w800),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(10),
                                  child: Image.memory(
                                    product.imageBytes,
                                    width: 48,
                                    height: 48,
                                    fit: BoxFit.cover,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    '${product.titleFor(context)} · ${product.quantityLabelFor(context)} · ${product.priceFor(context)}',
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontSize: 12.5),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                SizedBox(
                                  width: 110,
                                  child: QuantityControl(
                                    sale: product,
                                    selectedQuantity: quantity,
                                    onAdd:
                                        () => basket.changeQuantity(
                                          product.farmId,
                                          product.id,
                                          product.quantityStep,
                                          product.quantity,
                                        ),
                                    onRemove:
                                        () => basket.changeQuantity(
                                          product.farmId,
                                          product.id,
                                          -product.quantityStep,
                                          product.quantity,
                                        ),
                                  ),
                                ),
                              ],
                            ),
                            if (farmLines > 0) ...[
                              const SizedBox(height: 8),
                              Text(
                                localizeText(
                                  context,
                                  'One checkout, one pickup conversation, one farmer relationship.',
                                ),
                                style: const TextStyle(color: _muted, fontSize: 11),
                              ),
                            ],
                          ],
                        ),
                      ),
                      if (otherFarmSales.isNotEmpty) ...[
                        const SizedBox(height: 22),
                        Text(
                          localizeText(context, 'Complete this farm order'),
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900),
                        ),
                        const SizedBox(height: 10),
                        SizedBox(
                          height: 168,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: otherFarmSales.length,
                            separatorBuilder: (_, _) => const SizedBox(width: 10),
                            itemBuilder:
                                (context, index) => _OtherFarmSaleTile(
                                  sale: otherFarmSales[index],
                                  quantity: basket.quantityFor(
                                    product.farmId,
                                    otherFarmSales[index].id,
                                  ),
                                  onAdd:
                                      () => basket.changeQuantity(
                                        product.farmId,
                                        otherFarmSales[index].id,
                                        otherFarmSales[index].quantityStep,
                                        otherFarmSales[index].quantity,
                                      ),
                                  onRemove:
                                      () => basket.changeQuantity(
                                        product.farmId,
                                        otherFarmSales[index].id,
                                        -otherFarmSales[index].quantityStep,
                                        otherFarmSales[index].quantity,
                                      ),
                                ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (farmLines > 0)
                  SafeArea(
                    top: false,
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(18, 10, 18, 14),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        boxShadow: [
                          BoxShadow(color: Colors.black12, blurRadius: 12, offset: Offset(0, -3)),
                        ],
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '$farmLines ${localizeText(context, 'selected')}',
                                  style: const TextStyle(color: _muted, fontSize: 12),
                                ),
                                Text(
                                  '€${farmTotal.toStringAsFixed(2)}',
                                  style: const TextStyle(
                                    color: _green,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          FilledButton.icon(
                            onPressed: () => _openCheckout(context),
                            icon: const Icon(Icons.shopping_basket_outlined),
                            label: Text(localizeText(context, 'Add all')),
                            style: FilledButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _OtherFarmSaleTile extends StatelessWidget {
  const _OtherFarmSaleTile({
    required this.sale,
    required this.quantity,
    required this.onAdd,
    required this.onRemove,
  });
  final ProductPost sale;
  final double quantity;
  final VoidCallback onAdd;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) => Container(
    width: 128,
    padding: const EdgeInsets.all(8),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: _line),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.memory(
            sale.imageBytes,
            height: 64,
            width: double.infinity,
            fit: BoxFit.cover,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          sale.titleFor(context),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
        ),
        Text(
          sale.priceFor(context),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: _green, fontSize: 10.5, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 5),
        SizedBox(
          height: 38,
          child: QuantityControl(
            sale: sale,
            selectedQuantity: quantity,
            onAdd: onAdd,
            onRemove: onRemove,
          ),
        ),
      ],
    ),
  );
}

class _Pill extends StatelessWidget {
  const _Pill({required this.text});
  final String text;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: .94),
      borderRadius: BorderRadius.circular(99),
    ),
    child: Text(text, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 11.5)),
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
