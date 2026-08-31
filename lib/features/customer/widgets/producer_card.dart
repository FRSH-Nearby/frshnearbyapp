import 'package:flutter/material.dart' hide Text;

import '../../../l10n/localized_text.dart';
import '../consumer_data.dart';

const _green = Color(0xFF2F6B45);
const _muted = Color(0xFF66735F);
const _line = Color(0xFFE7E5DB);
const _mist = Color(0xFFEEF2E7);

/// The base "producer thumbnail" element. Always renders a business-type
/// disclosure badge (legally required) — it shows "Not disclosed yet" when
/// the backend hasn't told us whether the farm is a registered business or
/// a hobby producer, rather than silently omitting the badge.
class ProducerCard extends StatelessWidget {
  const ProducerCard({
    required this.producer,
    required this.onTap,
    this.width = 190,
    super.key,
  });

  final ProducerSummary producer;
  final VoidCallback onTap;
  final double width;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(20),
    child: Container(
      width: width,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: _mist,
                backgroundImage:
                    producer.farmProfilePhotoUrl?.isNotEmpty == true
                        ? NetworkImage(producer.farmProfilePhotoUrl!)
                        : null,
                child:
                    producer.farmProfilePhotoUrl?.isNotEmpty == true
                        ? null
                        : Text(
                          producer.farmName.characters.first.toUpperCase(),
                          style: const TextStyle(
                            color: _green,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      producer.farmName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                      ),
                    ),
                    Text(
                      '${producer.distanceKm.toStringAsFixed(1)} ${localizeText(context, 'km away')}',
                      style: const TextStyle(color: _muted, fontSize: 11.5),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _BusinessTypeBadge(type: producer.businessType),
          const SizedBox(height: 6),
          Text(
            '${producer.products.length} ${localizeText(context, producer.products.length == 1 ? 'Hot Sale' : 'Hot Sales')}',
            style: const TextStyle(
              color: _green,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
        ],
      ),
    ),
  );
}

class _BusinessTypeBadge extends StatelessWidget {
  const _BusinessTypeBadge({required this.type});
  final String? type;

  @override
  Widget build(BuildContext context) {
    final String label;
    final Color color;
    switch (type) {
      case 'BUSINESS':
        label = localizeText(context, 'Registered business');
        color = _green;
      case 'HOBBY':
        label = localizeText(context, 'Hobby producer');
        color = const Color(0xFF8A6D1F);
      default:
        label = localizeText(context, 'Producer type not disclosed yet');
        color = _muted;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: _mist,
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(color: color, fontSize: 10.5, fontWeight: FontWeight.w800),
      ),
    );
  }
}
