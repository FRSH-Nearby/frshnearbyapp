import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart' hide Text;

import '../../../config/api_config.dart';
import '../../../l10n/localized_text.dart';
import '../basket_controller.dart';
import '../consumer_data.dart';
import 'product_detail_sheet.dart';
import 'quantity_control.dart';

const _green = Color(0xFF2F6B45);
const _cream = Color(0xFFFBFAF5);

/// A producer's own public page — reached by tapping a producer's name
/// anywhere in the app (product push-up, producer thumbnail, farm marker),
/// so there's one shared "producer's home page" instead of a copy per entry
/// point.
class ProducerProfilePage extends StatefulWidget {
  const ProducerProfilePage({
    required this.sales,
    required this.basket,
    required this.onOpenOrders,
    super.key,
  });

  /// All of this farm's currently-visible sales (the same nearby list every
  /// screen already loaded — sold-out/inactive listings never reach here
  /// since `nearbyHotSales` itself excludes them).
  final List<ProductPost> sales;
  final BasketController basket;
  final VoidCallback onOpenOrders;

  @override
  State<ProducerProfilePage> createState() => _ProducerProfilePageState();
}

class _ProducerProfilePageState extends State<ProducerProfilePage> {
  late bool _followed = widget.sales.first.isFollowed;
  late int _followers = widget.sales.first.followerCount;
  bool _busy = false;

  Future<void> _toggleFollow() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final token = await FirebaseAuth.instance.currentUser?.getIdToken();
      if (token == null) throw StateError('Please sign in again.');
      final dio = Dio(BaseOptions(baseUrl: ApiConfig.graphqlUrl));
      final response = await dio.post<Map<String, dynamic>>(
        '',
        data: {
          'query':
              'mutation(\$farmId: String!) { toggleFarmFollow(farmId: \$farmId) { followed followerCount } }',
          'variables': {'farmId': widget.sales.first.farmId},
        },
        options: Options(headers: {'authorization': 'Bearer $token'}),
      );
      final body = response.data ?? const {};
      final errors = body['errors'] as List<dynamic>?;
      if (errors?.isNotEmpty == true) {
        throw StateError(
          (errors!.first as Map<String, dynamic>)['message'] as String? ??
              'Could not update follow.',
        );
      }
      final state =
          (body['data'] as Map<String, dynamic>)['toggleFarmFollow']
              as Map<String, dynamic>;
      if (!mounted) return;
      setState(() {
        _followed = state['followed'] as bool;
        _followers = state['followerCount'] as int;
        for (final sale in widget.sales) {
          sale.json['isFollowed'] = _followed;
          sale.json['followerCount'] = _followers;
        }
      });
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.toString().replaceFirst('Bad state: ', ''))),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _openDetails(ProductPost sale) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder:
          (_) => ProductDetailSheet(
            product: sale,
            allProducts: widget.sales,
            basket: widget.basket,
            onOpenOrders: widget.onOpenOrders,
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final farm = widget.sales.first;
    return Scaffold(
      backgroundColor: _cream,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 245,
            pinned: true,
            backgroundColor: _green,
            foregroundColor: Colors.white,
            flexibleSpace: FlexibleSpaceBar(
              background:
                  farm.farmCoverPhotoUrl?.isNotEmpty == true
                      ? Image.network(farm.farmCoverPhotoUrl!, fit: BoxFit.cover)
                      : Image.asset('assets/images/role_producer.jpg', fit: BoxFit.cover),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 34,
                        backgroundColor: const Color(0xFFE5EFDF),
                        backgroundImage:
                            farm.farmProfilePhotoUrl?.isNotEmpty == true
                                ? NetworkImage(farm.farmProfilePhotoUrl!)
                                : null,
                        child:
                            farm.farmProfilePhotoUrl?.isNotEmpty == true
                                ? null
                                : Text(
                                  farm.farmName.characters.first.toUpperCase(),
                                  style: const TextStyle(
                                    color: _green,
                                    fontSize: 24,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              farm.farmName,
                              style: const TextStyle(fontSize: 25, fontWeight: FontWeight.w900),
                            ),
                            Text(
                              '$_followers ${localizeText(context, _followers == 1 ? 'follower' : 'followers')}',
                              style: const TextStyle(color: Colors.black54),
                            ),
                          ],
                        ),
                      ),
                      FilledButton.icon(
                        onPressed: _busy ? null : _toggleFollow,
                        icon: Icon(_followed ? Icons.check_rounded : Icons.add_rounded),
                        label: Text(_followed ? 'Following' : 'Follow'),
                      ),
                    ],
                  ),
                  if (farm.farmDescription?.isNotEmpty == true) ...[
                    const SizedBox(height: 16),
                    Text(farm.farmDescription!, style: const TextStyle(height: 1.5)),
                  ],
                  const SizedBox(height: 22),
                  Text(
                    '${widget.sales.length} ${localizeText(context, 'Hot Sales')}',
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
                  ),
                ],
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(18, 8, 18, 30),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: .68,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final sale = widget.sales[index];
                  return Material(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    clipBehavior: Clip.antiAlias,
                    child: Padding(
                      padding: const EdgeInsets.all(9),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: InkWell(
                              onTap: () => _openDetails(sale),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(14),
                                child: Image.memory(
                                  sale.imageBytes,
                                  width: double.infinity,
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 7),
                          Text(
                            sale.titleFor(context),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w900),
                          ),
                          Text(
                            sale.priceFor(context),
                            style: const TextStyle(
                              color: _green,
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 6),
                          AnimatedBuilder(
                            animation: widget.basket,
                            builder:
                                (context, _) => QuantityControl(
                                  sale: sale,
                                  selectedQuantity: widget.basket.quantityFor(sale),
                                  onAdd:
                                      () => widget.basket.changeQuantity(
                                        sale,
                                        sale.quantityStep,
                                      ),
                                  onRemove:
                                      () => widget.basket.changeQuantity(
                                        sale,
                                        -sale.quantityStep,
                                      ),
                                ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
                childCount: widget.sales.length,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
