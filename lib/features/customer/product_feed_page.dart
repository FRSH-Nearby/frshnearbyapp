import 'dart:math';

import 'package:flutter/material.dart' hide Text;

import '../../l10n/localized_text.dart';
import 'basket_controller.dart';
import 'consumer_data.dart';
import 'widgets/product_card.dart';
import 'widgets/product_detail_sheet.dart';

const _green = Color(0xFF2F6B45);
const _ink = Color(0xFF1B2A20);
const _muted = Color(0xFF66735F);
const _cream = Color(0xFFFBFAF5);

enum ProductSort {
  productRating('Rating of the product', available: false),
  producerRating('Rating of the producer', available: false),
  soonestDelivery('Soonest delivery date', available: false),
  soonestDeadline('Soonest order deadline', available: false),
  random('Random', available: true);

  const ProductSort(this.label, {required this.available});
  final String label;
  final bool available;
}

/// Vertical, 2-wide product feed: the shared destination for a category
/// tap, a search result, or a "Show all" link. Always fetches/receives a
/// full result set up front, so the bottom of the list keeps showing more
/// cards to scroll rather than paginating.
class ProductFeedPage extends StatefulWidget {
  const ProductFeedPage({
    required this.title,
    required this.products,
    required this.basket,
    required this.onOpenOrders,
    this.initialCategory,
    this.initialQuery = '',
    super.key,
  });

  final String title;
  final List<ProductPost> products;
  final BasketController basket;
  final VoidCallback onOpenOrders;
  final String? initialCategory;
  final String initialQuery;

  @override
  State<ProductFeedPage> createState() => _ProductFeedPageState();
}

class _ProductFeedPageState extends State<ProductFeedPage> {
  late String? _category = widget.initialCategory;
  late String _query = widget.initialQuery;
  late final _searchController = TextEditingController(text: widget.initialQuery);
  ProductSort _sort = ProductSort.random;
  late List<ProductPost> _randomOrder = _shuffled(widget.products);

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<ProductPost> _shuffled(List<ProductPost> source) {
    final copy = [...source];
    copy.shuffle(Random());
    return copy;
  }

  Future<void> _pickSort() async {
    final choice = await showModalBottomSheet<ProductSort>(
      context: context,
      backgroundColor: Colors.transparent,
      builder:
          (_) => Material(
            color: _cream,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            clipBehavior: Clip.antiAlias,
            child: SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
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
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 6),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        localizeText(context, 'Sort by'),
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                      ),
                    ),
                  ),
                  for (final option in ProductSort.values)
                    ListTile(
                      enabled: option.available,
                      onTap:
                          option.available
                              ? () => Navigator.of(context).pop(option)
                              : null,
                      title: Text(localizeText(context, option.label)),
                      trailing:
                          option == _sort
                              ? const Icon(Icons.check_rounded, color: _green)
                              : !option.available
                              ? Text(
                                localizeText(context, 'Needs backend support'),
                                style: const TextStyle(color: _muted, fontSize: 11),
                              )
                              : null,
                    ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
    );
    if (choice == null || !mounted) return;
    setState(() {
      _sort = choice;
      if (choice == ProductSort.random) {
        _randomOrder = _shuffled(widget.products);
      }
    });
  }

  void _openDetails(ProductPost product) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder:
          (_) => ProductDetailSheet(
            product: product,
            allProducts: widget.products,
            basket: widget.basket,
            onOpenOrders: widget.onOpenOrders,
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final query = _query.trim().toLowerCase();
    var visible =
        widget.products.where((product) {
          if (_category != null && !matchesCategory(product, _category!)) {
            return false;
          }
          if (query.isEmpty) return true;
          return product.titleFor(context).toLowerCase().contains(query) ||
              product.farmName.toLowerCase().contains(query);
        }).toList();
    if (_sort == ProductSort.random) {
      final randomIds = _randomOrder.map((p) => p.id).toList();
      visible.sort(
        (a, b) => randomIds.indexOf(a.id).compareTo(randomIds.indexOf(b.id)),
      );
    }

    return Scaffold(
      backgroundColor: _cream,
      appBar: AppBar(
        backgroundColor: _cream,
        surfaceTintColor: Colors.transparent,
        foregroundColor: _ink,
        title: Text(widget.title),
        actions: [
          TextButton.icon(
            onPressed: _pickSort,
            icon: const Icon(Icons.sort_rounded, color: _green),
            label: Text(
              localizeText(context, 'Sort by'),
              style: const TextStyle(color: _green, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
            child: TextField(
              controller: _searchController,
              onChanged: (value) => setState(() => _query = value),
              decoration: InputDecoration(
                hintText: localizeText(context, 'Search Hot Sales'),
                prefixIcon: const Icon(Icons.search_rounded),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final category in kProductCategories)
                  ChoiceChip(
                    label: Text(localizeText(context, category.label)),
                    selected: _category == category.key,
                    onSelected:
                        (selected) => setState(
                          () => _category = selected ? category.key : null,
                        ),
                    selectedColor: _green,
                    labelStyle: TextStyle(
                      color: _category == category.key ? Colors.white : _ink,
                      fontWeight: FontWeight.w700,
                    ),
                    backgroundColor: Colors.white,
                  ),
              ],
            ),
          ),
          Expanded(
            child:
                visible.isEmpty
                    ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(28),
                        child: Text(
                          localizeText(context, 'No Hot Sales match right now.'),
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: _muted),
                        ),
                      ),
                    )
                    : GridView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 30),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            mainAxisSpacing: 12,
                            crossAxisSpacing: 12,
                            childAspectRatio: .72,
                          ),
                      itemCount: visible.length,
                      itemBuilder:
                          (context, index) => ProductCard(
                            product: visible[index],
                            onTap: () => _openDetails(visible[index]),
                            width: double.infinity,
                          ),
                    ),
          ),
        ],
      ),
    );
  }
}
