import 'package:flutter/material.dart' hide Text;

import '../../../l10n/localized_text.dart';
import '../basket_controller.dart';
import '../consumer_data.dart';
import 'quantity_control.dart';

const _cream = Color(0xFFFBFAF5);

/// The checkout step for one farm's basket: review lines, choose a pickup
/// place, submit. Shared by Explore's basket bar and Home's "Add all" so
/// there is exactly one order-submission code path.
class BasketSheet extends StatefulWidget {
  const BasketSheet({
    required this.farmId,
    required this.farmSales,
    required this.basket,
    super.key,
  });

  final String farmId;

  /// All of this farm's products (not just the ones in the basket) — needed
  /// to resolve farm-pickup eligibility and shared REKO rings.
  final List<ProductPost> farmSales;
  final BasketController basket;

  @override
  State<BasketSheet> createState() => _BasketSheetState();
}

class _BasketSheetState extends State<BasketSheet> {
  String? _pickupType;
  String? _rekoRingId;
  bool _submitting = false;
  String? _error;

  List<ProductPost> get _activeSales =>
      widget.farmSales
          .where((sale) => widget.basket.quantityFor(widget.farmId, sale.id) > 0)
          .toList();
  bool get _farmEligible =>
      _activeSales.isNotEmpty && _activeSales.every((sale) => sale.availableAtFarm);
  List<RekoPickup> get _commonRings {
    if (_activeSales.isEmpty) return const [];
    return _activeSales.first.rekoRings
        .where(
          (ring) => _activeSales.every(
            (sale) => sale.rekoRings.any((candidate) => candidate.id == ring.id),
          ),
        )
        .toList();
  }

  double get _total => _activeSales.fold(
    0.0,
    (total, sale) =>
        total +
        widget.basket.quantityFor(widget.farmId, sale.id) * sale.priceCents / 100,
  );

  Future<void> _requestOrder() async {
    if (_pickupType == null || (_pickupType == 'REKO' && _rekoRingId == null)) {
      setState(() => _error = 'Select a pickup place.');
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await widget.basket.submitOrder(
        farmId: widget.farmId,
        pickupType: _pickupType!,
        rekoRingId: _rekoRingId,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Order request sent to the farm.')),
      );
      Navigator.of(context).pop();
    } catch (error) {
      if (mounted) {
        setState(() => _error = error.toString().replaceFirst('Bad state: ', ''));
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: widget.basket,
    builder:
        (context, _) => FractionallySizedBox(
          heightFactor: .78,
          child: Material(
            color: _cream,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 42,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.black26,
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    'Your basket',
                    style: TextStyle(fontSize: 25, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 14),
                  Expanded(
                    child: ListView(
                      children: [
                        for (final sale in _activeSales)
                          Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(18),
                            ),
                            child: Row(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(13),
                                  child: Image.memory(
                                    sale.imageBytes,
                                    width: 62,
                                    height: 62,
                                    fit: BoxFit.cover,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        sale.titleFor(context),
                                        style: const TextStyle(fontWeight: FontWeight.w800),
                                      ),
                                      Text(
                                        sale.farmName,
                                        style: const TextStyle(color: Colors.black54, fontSize: 12),
                                      ),
                                    ],
                                  ),
                                ),
                                SizedBox(
                                  width: 142,
                                  child: QuantityControl(
                                    sale: sale,
                                    selectedQuantity: widget.basket.quantityFor(
                                      widget.farmId,
                                      sale.id,
                                    ),
                                    onAdd:
                                        () => widget.basket.changeQuantity(
                                          widget.farmId,
                                          sale.id,
                                          sale.quantityStep,
                                          sale.quantity,
                                        ),
                                    onRemove:
                                        () => widget.basket.changeQuantity(
                                          widget.farmId,
                                          sale.id,
                                          -sale.quantityStep,
                                          sale.quantity,
                                        ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Pickup place',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
                  ),
                  if (_farmEligible)
                    RadioListTile<String>(
                      value: 'FARM',
                      groupValue: _pickupType,
                      onChanged:
                          (value) => setState(() {
                            _pickupType = value;
                            _rekoRingId = null;
                          }),
                      title: const Text('Farm pickup'),
                      subtitle: Text(
                        _activeSales.isEmpty ? '' : _activeSales.first.farmLocation,
                      ),
                    ),
                  for (final ring in _commonRings)
                    RadioListTile<String>(
                      value: ring.id,
                      groupValue: _pickupType == 'REKO' ? _rekoRingId : null,
                      onChanged:
                          (value) => setState(() {
                            _pickupType = 'REKO';
                            _rekoRingId = value;
                          }),
                      title: Text(ring.name),
                      subtitle: Text(ring.details),
                    ),
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(_error!, style: const TextStyle(color: Colors.red)),
                    ),
                  Row(
                    children: [
                      const Expanded(
                        child: Text('Total', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                      ),
                      Text(
                        '€${_total.toStringAsFixed(2)}',
                        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed:
                          _submitting || _activeSales.isEmpty ? null : _requestOrder,
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: Text(
                        _submitting
                            ? 'Sending request…'
                            : '${localizeText(context, 'Request order')} • €${_total.toStringAsFixed(2)}',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
  );
}
