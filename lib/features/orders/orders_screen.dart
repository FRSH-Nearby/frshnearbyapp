import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart' hide Text;
import 'package:intl/intl.dart';

import '../../config/api_config.dart';
import '../../l10n/localized_text.dart';
import '../customer/basket_controller.dart';
import '../customer/consumer_data.dart';
import '../customer/widgets/basket_sheet.dart';
import '../customer/widgets/quantity_control.dart';

const _green = Color(0xFF2F6B45);
const _muted = Color(0xFF66735F);
const _line = Color(0xFFE7E5DB);
const _cream = Color(0xFFFBFAF5);

/// Producer order lifecycle: REQUESTED/ACCEPTED live under "Orders",
/// READY_FOR_PICKUP under "On delivery", everything terminal under
/// "History". The backend only allows forward transitions between these
/// (REQUESTED→ACCEPTED/REJECTED→READY_FOR_PICKUP→COMPLETED, no way back),
/// so there's deliberately no "send back" action here — a button for one
/// would just fail against the API every time.
enum _SellerTab { orders, onDelivery, history }

enum _SummaryMode { list, byConsumer, byProduct }

class OrdersScreen extends StatefulWidget {
  const OrdersScreen({required this.seller, this.basket, super.key})
    : assert(
        seller || basket != null,
        'basket is required for the consumer Orders screen',
      );

  final bool seller;

  /// The shared basket, used to render the consumer "Shopping cart" tab.
  /// Unused (and unneeded) in seller mode.
  final BasketController? basket;

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  late Future<List<_Order>> _orders = _load();
  late Future<List<Map<String, dynamic>>> _notifications = _loadNotifications();

  @override
  void initState() {
    super.initState();
    widget.basket?.addListener(_onBasketChanged);
  }

  @override
  void dispose() {
    widget.basket?.removeListener(_onBasketChanged);
    super.dispose();
  }

  void _onBasketChanged() {
    if (mounted) setState(() {});
  }

  Future<Map<String, dynamic>> _send(
    String query, [
    Map<String, dynamic> variables = const {},
  ]) async {
    final token = await FirebaseAuth.instance.currentUser?.getIdToken();
    if (token == null) throw StateError('Please sign in again.');
    final dio = Dio(BaseOptions(baseUrl: ApiConfig.graphqlUrl));
    final response = await dio.post<Map<String, dynamic>>(
      '',
      data: {'query': query, 'variables': variables},
      options: Options(headers: {'authorization': 'Bearer $token'}),
    );
    final body = response.data ?? const {};
    final errors = body['errors'] as List<dynamic>?;
    if (errors?.isNotEmpty == true) {
      throw StateError(
        (errors!.first as Map<String, dynamic>)['message'] as String? ??
            'Order request failed.',
      );
    }
    return body['data'] as Map<String, dynamic>;
  }

  Future<List<_Order>> _load() async {
    const fields =
        'id status pickupType rekoRingId pickupName pickupAddress pickupSchedule '
        'farmName consumerName consumerEmail consumerPhone totalCents createdAt updatedAt '
        'items { id hotSaleId title imageMimeType imageBase64 unit quantityStep quantity unitPriceCents lineTotalCents }';
    final name = widget.seller ? 'sellerOrders' : 'myOrders';
    final data = await _send('query { $name { $fields } }');
    return (data[name] as List<dynamic>)
        .map((item) => _Order(item as Map<String, dynamic>))
        .toList();
  }

  Future<List<Map<String, dynamic>>> _loadNotifications() async {
    if (!widget.seller) return const [];
    final data = await _send(
      'query { farmNotifications { id type message actorName read createdAt } }',
    );
    return (data['farmNotifications'] as List<dynamic>).cast<Map<String, dynamic>>();
  }

  Future<void> _readNotification(String id) async {
    await _send(
      'mutation(\$id: String!) { markFarmNotificationRead(id: \$id) }',
      {'id': id},
    );
    if (mounted) setState(() => _notifications = _loadNotifications());
  }

  Future<void> _status(_Order order, String status) async {
    try {
      if (status == 'CANCELLED') {
        await _send(
          'mutation(\$id: String!) { cancelOrder(id: \$id) { id } }',
          {'id': order.id},
        );
      } else {
        await _send(
          'mutation(\$input: UpdateOrderStatusInput!) { updateOrderStatus(input: \$input) { id } }',
          {
            'input': {'id': order.id, 'status': status},
          },
        );
      }
      if (mounted) setState(() => _orders = _load());
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.toString().replaceFirst('Bad state: ', ''))),
        );
      }
    }
  }

  void _openFullCard(_Order order) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder:
          (_) => _FullOrderCard(
            order: order,
            seller: widget.seller,
            onStatus: (status) => _status(order, status),
          ),
    );
  }

  void _openFarmCheckout(String farmId, List<ProductPost> farmSales) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder:
          (_) => BasketSheet(
            farmId: farmId,
            farmSales: farmSales,
            basket: widget.basket!,
          ),
    ).then((_) => setState(() => _orders = _load()));
  }

  @override
  Widget build(BuildContext context) {
    final tabCount = widget.seller ? 3 : 2;
    return DefaultTabController(
      length: tabCount,
      child: ColoredBox(
        color: _cream,
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
                child: Text(
                  widget.seller ? 'Farm orders' : 'Orders',
                  style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900),
                ),
              ),
              TabBar(
                labelColor: _green,
                unselectedLabelColor: _muted,
                indicatorColor: _green,
                tabs: [
                  if (widget.seller) ...const [
                    Tab(text: 'Orders'),
                    Tab(text: 'On delivery'),
                    Tab(text: 'History'),
                  ] else ...const [
                    Tab(text: 'Shopping cart'),
                    Tab(text: 'My orders'),
                  ],
                ],
              ),
              Expanded(
                child: TabBarView(
                  children: [
                    if (widget.seller) ...[
                      _SellerOrdersTab(
                        tab: _SellerTab.orders,
                        ordersFuture: _orders,
                        notificationsFuture: _notifications,
                        onRetry: () => setState(() => _orders = _load()),
                        onReadNotification: _readNotification,
                        onOpenCard: _openFullCard,
                      ),
                      _SellerOrdersTab(
                        tab: _SellerTab.onDelivery,
                        ordersFuture: _orders,
                        onRetry: () => setState(() => _orders = _load()),
                        onOpenCard: _openFullCard,
                      ),
                      _SellerOrdersTab(
                        tab: _SellerTab.history,
                        ordersFuture: _orders,
                        onRetry: () => setState(() => _orders = _load()),
                        onOpenCard: _openFullCard,
                      ),
                    ] else ...[
                      _ShoppingCartTab(
                        basket: widget.basket!,
                        onCheckout: _openFarmCheckout,
                      ),
                      _MyOrdersTab(
                        ordersFuture: _orders,
                        onRetry: () => setState(() => _orders = _load()),
                        onOpenCard: _openFullCard,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---- shopping cart (consumer) ----

class _ShoppingCartTab extends StatelessWidget {
  const _ShoppingCartTab({required this.basket, required this.onCheckout});
  final BasketController basket;
  final void Function(String farmId, List<ProductPost> farmSales) onCheckout;

  @override
  Widget build(BuildContext context) {
    final farmIds = basket.farmIds;
    if (farmIds.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.shopping_basket_outlined, size: 44, color: _green),
              const SizedBox(height: 12),
              Text(
                localizeText(context, 'Your cart is empty'),
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 4),
              Text(
                localizeText(context, 'Add products from Home or Explore.'),
                textAlign: TextAlign.center,
                style: const TextStyle(color: _muted),
              ),
            ],
          ),
        ),
      );
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 30),
      children: [
        for (final farmId in farmIds)
          _FarmCartCard(
            farmId: farmId,
            lines: basket.linesFor(farmId),
            basket: basket,
            onCheckout:
                () => onCheckout(
                  farmId,
                  basket.linesFor(farmId).map((line) => line.product).toList(),
                ),
          ),
      ],
    );
  }
}

class _FarmCartCard extends StatelessWidget {
  const _FarmCartCard({
    required this.farmId,
    required this.lines,
    required this.basket,
    required this.onCheckout,
  });
  final String farmId;
  final List<BasketLine> lines;
  final BasketController basket;
  final VoidCallback onCheckout;

  @override
  Widget build(BuildContext context) {
    if (lines.isEmpty) return const SizedBox.shrink();
    final farmName = lines.first.product.farmName;
    final total = lines.fold<double>(
      0,
      (sum, line) => sum + line.quantity * line.product.priceCents / 100,
    );
    // The soonest of this farm's lines to expire is the one worth showing —
    // it's the one that determines when this card starts losing items.
    final expiryTimes = lines.map((line) => line.expiresAt).whereType<DateTime>();
    final soonestExpiry =
        expiryTimes.isEmpty
            ? null
            : expiryTimes.reduce((a, b) => a.isBefore(b) ? a : b);
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
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
              Expanded(
                child: Text(
                  farmName,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
                ),
              ),
              if (soonestExpiry != null) _ExpiryCountdown(expiresAt: soonestExpiry),
            ],
          ),
          const SizedBox(height: 10),
          for (final line in lines)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.memory(
                      line.product.imageBytes,
                      width: 48,
                      height: 48,
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          line.product.titleFor(context),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        Text(
                          line.product.priceFor(context),
                          style: const TextStyle(color: _muted, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(
                    width: 120,
                    child: QuantityControl(
                      sale: line.product,
                      selectedQuantity: line.quantity,
                      onAdd:
                          () => basket.changeQuantity(
                            line.product,
                            line.product.quantityStep,
                          ),
                      onRemove:
                          () => basket.changeQuantity(
                            line.product,
                            -line.product.quantityStep,
                          ),
                    ),
                  ),
                ],
              ),
            ),
          const Divider(),
          Row(
            children: [
              Expanded(
                child: Text(
                  '${lines.length} ${localizeText(context, lines.length == 1 ? 'item' : 'items')}',
                  style: const TextStyle(color: _muted),
                ),
              ),
              Text(
                '€${total.toStringAsFixed(2)}',
                style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: onCheckout,
              child: Text(localizeText(context, 'View cart')),
            ),
          ),
        ],
      ),
    );
  }
}

/// A live "reserved for mm:ss" badge — the reservation is real (it's holding
/// actual stock server-side), so this ticks down for real rather than being
/// decorative.
class _ExpiryCountdown extends StatefulWidget {
  const _ExpiryCountdown({required this.expiresAt});
  final DateTime expiresAt;

  @override
  State<_ExpiryCountdown> createState() => _ExpiryCountdownState();
}

class _ExpiryCountdownState extends State<_ExpiryCountdown> {
  late Timer _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => setState(() {}));
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final remaining = widget.expiresAt.difference(DateTime.now());
    final seconds = remaining.inSeconds.clamp(0, 30 * 60);
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    final urgent = seconds <= 60;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: urgent ? const Color(0xFFFBE7E4) : const Color(0xFFE6F0E1),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}',
        style: TextStyle(
          color: urgent ? const Color(0xFFB3392C) : _green,
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

// ---- my orders (consumer) ----

class _MyOrdersTab extends StatelessWidget {
  const _MyOrdersTab({
    required this.ordersFuture,
    required this.onRetry,
    required this.onOpenCard,
  });
  final Future<List<_Order>> ordersFuture;
  final VoidCallback onRetry;
  final ValueChanged<_Order> onOpenCard;

  @override
  Widget build(BuildContext context) => FutureBuilder<List<_Order>>(
    future: ordersFuture,
    builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done) {
        return const Center(child: CircularProgressIndicator());
      }
      if (snapshot.hasError) {
        return _ErrorState(
          message: snapshot.error.toString().replaceFirst('Bad state: ', ''),
          onRetry: onRetry,
        );
      }
      final orders = snapshot.data ?? const [];
      if (orders.isEmpty) {
        return const _EmptyState(text: 'No orders yet');
      }
      return RefreshIndicator(
        onRefresh: () async => onRetry(),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 30),
          children: [
            for (final order in orders)
              _OrderThumbnail(
                order: order,
                seller: false,
                onTap: () => onOpenCard(order),
              ),
          ],
        ),
      );
    },
  );
}

// ---- seller orderbook ----

List<_Order> _forTab(List<_Order> orders, _SellerTab tab) => orders.where((order) {
  switch (tab) {
    case _SellerTab.orders:
      return order.status == 'REQUESTED' || order.status == 'ACCEPTED';
    case _SellerTab.onDelivery:
      return order.status == 'READY_FOR_PICKUP';
    case _SellerTab.history:
      return order.status == 'COMPLETED' ||
          order.status == 'REJECTED' ||
          order.status == 'CANCELLED';
  }
}).toList();

class _SellerOrdersTab extends StatefulWidget {
  const _SellerOrdersTab({
    required this.tab,
    required this.ordersFuture,
    required this.onRetry,
    required this.onOpenCard,
    this.notificationsFuture,
    this.onReadNotification,
  });
  final _SellerTab tab;
  final Future<List<_Order>> ordersFuture;
  final VoidCallback onRetry;
  final ValueChanged<_Order> onOpenCard;
  final Future<List<Map<String, dynamic>>>? notificationsFuture;
  final ValueChanged<String>? onReadNotification;

  @override
  State<_SellerOrdersTab> createState() => _SellerOrdersTabState();
}

class _SellerOrdersTabState extends State<_SellerOrdersTab> {
  _SummaryMode _mode = _SummaryMode.list;

  @override
  Widget build(BuildContext context) => FutureBuilder<List<_Order>>(
    future: widget.ordersFuture,
    builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done) {
        return const Center(child: CircularProgressIndicator());
      }
      if (snapshot.hasError) {
        return _ErrorState(
          message: snapshot.error.toString().replaceFirst('Bad state: ', ''),
          onRetry: widget.onRetry,
        );
      }
      final orders = _forTab(snapshot.data ?? const [], widget.tab);
      return RefreshIndicator(
        onRefresh: () async => widget.onRetry(),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 30),
          children: [
            if (widget.notificationsFuture != null)
              FutureBuilder<List<Map<String, dynamic>>>(
                future: widget.notificationsFuture,
                builder: (context, noticeSnapshot) {
                  final notices = noticeSnapshot.data ?? const [];
                  if (notices.isEmpty) return const SizedBox.shrink();
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Notifications',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
                      ),
                      const SizedBox(height: 8),
                      for (final notice in notices.take(5))
                        ListTile(
                          onTap:
                              notice['read'] == true
                                  ? null
                                  : () => widget.onReadNotification?.call(notice['id'] as String),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                          tileColor:
                              notice['read'] == true ? Colors.white : const Color(0xFFE6F0E1),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                          leading: const Icon(Icons.person_add_alt_1_rounded, color: _green),
                          title: Text(notice['message'] as String),
                          subtitle: Text(notice['actorName'] as String),
                          trailing:
                              notice['read'] == true
                                  ? null
                                  : const Icon(Icons.circle, size: 9, color: _green),
                        ),
                      const SizedBox(height: 16),
                    ],
                  );
                },
              ),
            Row(
              children: [
                Text(
                  '${orders.length} ${localizeText(context, orders.length == 1 ? 'order' : 'orders')}',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                const Spacer(),
                DropdownButton<_SummaryMode>(
                  value: _mode,
                  underline: const SizedBox.shrink(),
                  items: [
                    DropdownMenuItem(
                      value: _SummaryMode.list,
                      child: Text(localizeText(context, 'List')),
                    ),
                    DropdownMenuItem(
                      value: _SummaryMode.byConsumer,
                      child: Text(localizeText(context, 'By consumer')),
                    ),
                    DropdownMenuItem(
                      value: _SummaryMode.byProduct,
                      child: Text(localizeText(context, 'By product')),
                    ),
                  ],
                  onChanged: (mode) => setState(() => _mode = mode ?? _SummaryMode.list),
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (orders.isEmpty)
              _EmptyState(text: _emptyLabel(widget.tab))
            else
              switch (_mode) {
                _SummaryMode.list => Column(
                  children: [
                    for (final order in orders)
                      _OrderThumbnail(
                        order: order,
                        seller: true,
                        onTap: () => widget.onOpenCard(order),
                      ),
                  ],
                ),
                _SummaryMode.byConsumer => _ByConsumerSummary(orders: orders),
                _SummaryMode.byProduct => _ByProductSummary(orders: orders),
              },
          ],
        ),
      );
    },
  );

  String _emptyLabel(_SellerTab tab) => switch (tab) {
    _SellerTab.orders => 'No open orders',
    _SellerTab.onDelivery => 'Nothing on delivery',
    _SellerTab.history => 'No past orders yet',
  };
}

class _ByConsumerSummary extends StatelessWidget {
  const _ByConsumerSummary({required this.orders});
  final List<_Order> orders;

  @override
  Widget build(BuildContext context) {
    final byConsumer = <String, List<_Order>>{};
    for (final order in orders) {
      byConsumer.putIfAbsent(order.consumerName, () => []).add(order);
    }
    final entries =
        byConsumer.entries.toList()
          ..sort((a, b) => b.value.length.compareTo(a.value.length));
    return Column(
      children: [
        for (final entry in entries)
          Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _line),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    entry.key,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
                Text(
                  '${entry.value.length} ${localizeText(context, entry.value.length == 1 ? 'order' : 'orders')}',
                  style: const TextStyle(color: _muted, fontSize: 12.5),
                ),
                const SizedBox(width: 10),
                Text(
                  '€${(entry.value.fold<int>(0, (sum, o) => sum + o.totalCents) / 100).toStringAsFixed(2)}',
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _ByProductSummary extends StatelessWidget {
  const _ByProductSummary({required this.orders});
  final List<_Order> orders;

  @override
  Widget build(BuildContext context) {
    final byProduct = <String, ({double quantity, String unit, int orders})>{};
    for (final order in orders) {
      for (final item in order.items) {
        final title = item['title'] as String;
        final quantity = (item['quantity'] as num).toDouble();
        final unit = item['unit'] as String;
        final existing = byProduct[title];
        byProduct[title] = (
          quantity: (existing?.quantity ?? 0) + quantity,
          unit: unit,
          orders: (existing?.orders ?? 0) + 1,
        );
      }
    }
    final entries =
        byProduct.entries.toList()
          ..sort((a, b) => b.value.quantity.compareTo(a.value.quantity));
    return Column(
      children: [
        for (final entry in entries)
          Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _line),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    entry.key,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
                Text(
                  '${entry.value.orders} ${localizeText(context, entry.value.orders == 1 ? 'order' : 'orders')}',
                  style: const TextStyle(color: _muted, fontSize: 12.5),
                ),
                const SizedBox(width: 10),
                Text(
                  '${entry.value.quantity.toStringAsFixed(entry.value.quantity % 1 == 0 ? 0 : 1)} ${entry.value.unit}',
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

// ---- order thumbnail + full card ----

class _OrderThumbnail extends StatelessWidget {
  const _OrderThumbnail({required this.order, required this.seller, required this.onTap});
  final _Order order;
  final bool seller;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.white,
    borderRadius: BorderRadius.circular(18),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: _line),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    seller ? order.consumerName : order.farmName,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
                  ),
                ),
                _StatusChip(status: order.status),
              ],
            ),
            const SizedBox(height: 3),
            Text(
              order.orderNumber,
              style: const TextStyle(color: _muted, fontSize: 11.5),
            ),
            const SizedBox(height: 10),
            Text(
              order.itemsSummary,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12.5),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: Text(
                    order.pickupName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: _muted, fontSize: 12),
                  ),
                ),
                Text(
                  '€${(order.totalCents / 100).toStringAsFixed(2)}',
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

class _FullOrderCard extends StatelessWidget {
  const _FullOrderCard({required this.order, required this.seller, required this.onStatus});
  final _Order order;
  final bool seller;
  final ValueChanged<String> onStatus;

  @override
  Widget build(BuildContext context) => FractionallySizedBox(
    heightFactor: .82,
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
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 20),
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        seller ? order.consumerName : order.farmName,
                        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
                      ),
                    ),
                    _StatusChip(status: order.status),
                  ],
                ),
                const SizedBox(height: 4),
                Text(order.orderNumber, style: const TextStyle(color: _muted)),
                if (order.createdAt != null)
                  Text(
                    DateFormat('d MMM y · HH:mm').format(order.createdAt!),
                    style: const TextStyle(color: _muted, fontSize: 12.5),
                  ),
                const SizedBox(height: 20),
                const Text('Products', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900)),
                const SizedBox(height: 8),
                for (final item in order.items)
                  Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Image.memory(
                            base64Decode(item['imageBase64'] as String),
                            width: 46,
                            height: 46,
                            fit: BoxFit.cover,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item['title'] as String,
                                style: const TextStyle(fontWeight: FontWeight.w700),
                              ),
                              Text(
                                '${(item['quantity'] as num)} ${item['unit']} · €${((item['unitPriceCents'] as num) / 100).toStringAsFixed(2)}',
                                style: const TextStyle(color: _muted, fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          '€${((item['lineTotalCents'] as num) / 100).toStringAsFixed(2)}',
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    const Expanded(
                      child: Text('Total', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                    ),
                    Text(
                      '€${(order.totalCents / 100).toStringAsFixed(2)}',
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                const Text('Delivery', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900)),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(13),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        order.pickupType == 'REKO'
                            ? Icons.location_on_rounded
                            : Icons.storefront_rounded,
                        color: _green,
                      ),
                      const SizedBox(width: 11),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(order.pickupName, style: const TextStyle(fontWeight: FontWeight.w800)),
                            Text(order.pickupAddress, style: const TextStyle(color: _muted)),
                            if (order.pickupSchedule.isNotEmpty)
                              Text(
                                order.pickupSchedule,
                                style: const TextStyle(color: _muted, fontSize: 12),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 8, 18, 14),
              child: _ActionRow(order: order, seller: seller, onStatus: onStatus),
            ),
          ),
        ],
      ),
    ),
  );
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({required this.order, required this.seller, required this.onStatus});
  final _Order order;
  final bool seller;
  final ValueChanged<String> onStatus;

  @override
  Widget build(BuildContext context) {
    if (seller && order.status == 'REQUESTED') {
      return Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: () => onStatus('REJECTED'),
              child: Text(localizeText(context, 'Reject')),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: FilledButton(
              onPressed: () => onStatus('ACCEPTED'),
              child: Text(localizeText(context, 'Accept')),
            ),
          ),
        ],
      );
    }
    if (seller && order.status == 'ACCEPTED') {
      return SizedBox(
        width: double.infinity,
        child: FilledButton(
          onPressed: () => onStatus('READY_FOR_PICKUP'),
          child: Text(localizeText(context, 'Ready for the delivery')),
        ),
      );
    }
    if (seller && order.status == 'READY_FOR_PICKUP') {
      return SizedBox(
        width: double.infinity,
        child: FilledButton(
          onPressed: () => onStatus('COMPLETED'),
          child: Text(localizeText(context, 'Delivered')),
        ),
      );
    }
    if (!seller && order.status == 'REQUESTED') {
      return SizedBox(
        width: double.infinity,
        child: OutlinedButton(
          onPressed: () => onStatus('CANCELLED'),
          child: Text(localizeText(context, 'Cancel request')),
        ),
      );
    }
    return const SizedBox.shrink();
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});
  final String status;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
    decoration: BoxDecoration(
      color: const Color(0xFFE6F0E1),
      borderRadius: BorderRadius.circular(99),
    ),
    child: Text(
      _label(context),
      style: const TextStyle(color: _green, fontSize: 11, fontWeight: FontWeight.w800),
    ),
  );

  String _label(BuildContext context) => switch (status) {
    'REQUESTED' => localizeText(context, 'Requested'),
    'ACCEPTED' => localizeText(context, 'Accepted'),
    'REJECTED' => localizeText(context, 'Rejected'),
    'READY_FOR_PICKUP' => localizeText(context, 'Ready for pickup'),
    'COMPLETED' => localizeText(context, 'Completed'),
    'CANCELLED' => localizeText(context, 'Cancelled'),
    _ => status,
  };
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.text});
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 60),
    child: Column(
      children: [
        const Icon(Icons.receipt_long_outlined, size: 44, color: _green),
        const SizedBox(height: 12),
        Text(
          localizeText(context, text),
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ],
    ),
  );
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 12),
          FilledButton(onPressed: onRetry, child: Text(localizeText(context, 'Try again'))),
        ],
      ),
    ),
  );
}

class _Order {
  const _Order(this.json);
  final Map<String, dynamic> json;
  String get id => json['id'] as String;
  String get status => json['status'] as String;
  String get pickupType => json['pickupType'] as String? ?? '';
  String get pickupName => json['pickupName'] as String;
  String get pickupAddress => json['pickupAddress'] as String;
  String get pickupSchedule => json['pickupSchedule'] as String? ?? '';
  String get farmName => json['farmName'] as String;
  String get consumerName => json['consumerName'] as String;
  int get totalCents => json['totalCents'] as int;
  DateTime? get createdAt => DateTime.tryParse(json['createdAt'] as String? ?? '');
  List<Map<String, dynamic>> get items =>
      (json['items'] as List<dynamic>).cast<Map<String, dynamic>>();

  /// There's no dedicated human-facing order number in the schema — the
  /// id is a cuid, so this is a short, stable stand-in for one.
  String get orderNumber => '#${id.length > 8 ? id.substring(0, 8).toUpperCase() : id.toUpperCase()}';

  String get itemsSummary =>
      items.map((item) => '${item['quantity']} ${item['unit']} ${item['title']}').join(', ');
}
