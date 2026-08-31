import 'package:flutter/material.dart' hide Text;

import '../../../l10n/localized_text.dart';
import '../consumer_data.dart';

const _green = Color(0xFF2F6B45);
const _muted = Color(0xFF66735F);
const _line = Color(0xFFE7E5DB);

/// The base "product post" element: image, name, price/unit, producer name,
/// distance, and rating (rating renders only once the backend supplies one).
class ProductCard extends StatelessWidget {
  const ProductCard({
    required this.product,
    required this.onTap,
    this.width = 168,
    super.key,
  });

  final ProductPost product;
  final VoidCallback onTap;
  final double width;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(20),
    child: Container(
      width: width,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(15),
            child: AspectRatio(
              aspectRatio: 1.35,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.memory(product.imageBytes, fit: BoxFit.cover),
                  Positioned(
                    left: 7,
                    bottom: 7,
                    child: _Pill(text: product.priceFor(context)),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 9),
          Text(
            product.titleFor(context),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              const Icon(Icons.storefront_rounded, size: 13, color: _green),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  product.farmName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _green,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 3),
          Row(
            children: [
              Expanded(
                child: Text(
                  '${product.distanceKm.toStringAsFixed(1)} ${localizeText(context, 'km away')}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: _muted, fontSize: 11.5),
                ),
              ),
              if (product.rating != null) ...[
                const Icon(Icons.star_rounded, size: 14, color: Color(0xFFD9A441)),
                const SizedBox(width: 2),
                Text(
                  product.rating!.toStringAsFixed(1),
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 11.5),
                ),
              ],
            ],
          ),
        ],
      ),
    ),
  );
}

class _Pill extends StatelessWidget {
  const _Pill({required this.text});
  final String text;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: .94),
      borderRadius: BorderRadius.circular(99),
    ),
    child: Text(
      text,
      style: const TextStyle(color: _green, fontSize: 10.5, fontWeight: FontWeight.w900),
    ),
  );
}
