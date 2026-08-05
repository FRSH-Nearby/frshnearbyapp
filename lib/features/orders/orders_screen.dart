import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

const _green = Color(0xFF2F6B45);
const _cream = Color(0xFFFBFAF5);

class OrdersScreen extends StatefulWidget {
  const OrdersScreen({required this.seller, super.key});
  final bool seller;

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  late Future<List<_Order>> _orders = _load();

  Future<Map<String, dynamic>> _send(String query, [Map<String, dynamic> variables = const {}]) async {
    final token = await FirebaseAuth.instance.currentUser?.getIdToken();
    if (token == null) throw StateError('Please sign in again.');
    final dio = Dio(BaseOptions(baseUrl: const String.fromEnvironment('FRSH_API_URL', defaultValue: 'https://frshnearby-api.onrender.com/graphql')));
    final response = await dio.post<Map<String, dynamic>>('', data: {'query': query, 'variables': variables}, options: Options(headers: {'authorization': 'Bearer $token'}));
    final body = response.data ?? const {};
    final errors = body['errors'] as List<dynamic>?;
    if (errors?.isNotEmpty == true) throw StateError((errors!.first as Map<String, dynamic>)['message'] as String? ?? 'Order request failed.');
    return body['data'] as Map<String, dynamic>;
  }

  Future<List<_Order>> _load() async {
    const fields = 'id status pickupType rekoRingId pickupName pickupAddress pickupSchedule farmName consumerName consumerEmail consumerPhone totalCents createdAt updatedAt items { id hotSaleId title imageMimeType imageBase64 unit quantityStep quantity unitPriceCents lineTotalCents }';
    final name = widget.seller ? 'sellerOrders' : 'myOrders';
    final data = await _send('query { $name { $fields } }');
    return (data[name] as List<dynamic>).map((item) => _Order(item as Map<String, dynamic>)).toList();
  }

  Future<void> _status(_Order order, String status) async {
    try {
      if (status == 'CANCELLED') {
        await _send('mutation(\$id: String!) { cancelOrder(id: \$id) { id } }', {'id': order.id});
      } else {
        await _send('mutation(\$input: UpdateOrderStatusInput!) { updateOrderStatus(input: \$input) { id } }', {'input': {'id': order.id, 'status': status}});
      }
      if (mounted) setState(() => _orders = _load());
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.toString().replaceFirst('Bad state: ', ''))));
    }
  }

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: _cream,
    child: SafeArea(
      child: FutureBuilder<List<_Order>>(
        future: _orders,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
          if (snapshot.hasError) return Center(child: Padding(padding: const EdgeInsets.all(28), child: Text(snapshot.error.toString(), textAlign: TextAlign.center)));
          final orders = snapshot.data ?? const [];
          return RefreshIndicator(
            onRefresh: () async => setState(() => _orders = _load()),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 30),
              children: [
                Text(widget.seller ? 'Farm orders' : 'Your orders', style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900)),
                const SizedBox(height: 6),
                Text(widget.seller ? 'Review and prepare customer requests.' : 'Track requests and pickup details.', style: const TextStyle(color: Colors.black54)),
                const SizedBox(height: 18),
                if (orders.isEmpty)
                  const Padding(padding: EdgeInsets.only(top: 80), child: Column(children: [Icon(Icons.receipt_long_outlined, size: 44, color: _green), SizedBox(height: 12), Text('No orders yet', style: TextStyle(fontWeight: FontWeight.w800))])),
                for (final order in orders)
                  _OrderCard(order: order, seller: widget.seller, onStatus: (status) => _status(order, status)),
              ],
            ),
          );
        },
      ),
    ),
  );
}

class _OrderCard extends StatelessWidget {
  const _OrderCard({required this.order, required this.seller, required this.onStatus});
  final _Order order;
  final bool seller;
  final ValueChanged<String> onStatus;

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 13),
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Expanded(child: Text(seller ? order.consumerName : order.farmName, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900))),
        _StatusChip(status: order.status),
      ]),
      const SizedBox(height: 5),
      Text('${order.pickupName} • ${order.pickupAddress}', style: const TextStyle(color: Colors.black54)),
      const SizedBox(height: 12),
      for (final item in order.items)
        Padding(padding: const EdgeInsets.only(bottom: 8), child: Row(children: [
          ClipRRect(borderRadius: BorderRadius.circular(10), child: Image.memory(base64Decode(item['imageBase64'] as String), width: 46, height: 46, fit: BoxFit.cover)),
          const SizedBox(width: 9),
          Expanded(child: Text(item['title'] as String, style: const TextStyle(fontWeight: FontWeight.w700))),
          Text('${(item['quantity'] as num)} ${item['unit']}'),
        ])),
      const Divider(),
      Row(children: [const Expanded(child: Text('Total', style: TextStyle(fontWeight: FontWeight.w700))), Text('€${(order.totalCents / 100).toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.w900))]),
      if (seller && order.status == 'REQUESTED') ...[
        const SizedBox(height: 10),
        Row(children: [Expanded(child: OutlinedButton(onPressed: () => onStatus('REJECTED'), child: const Text('Reject'))), const SizedBox(width: 8), Expanded(child: FilledButton(onPressed: () => onStatus('ACCEPTED'), child: const Text('Accept')))]),
      ],
      if (seller && order.status == 'ACCEPTED') Padding(padding: const EdgeInsets.only(top: 10), child: SizedBox(width: double.infinity, child: FilledButton(onPressed: () => onStatus('READY_FOR_PICKUP'), child: const Text('Mark ready for pickup')))),
      if (seller && order.status == 'READY_FOR_PICKUP') Padding(padding: const EdgeInsets.only(top: 10), child: SizedBox(width: double.infinity, child: FilledButton(onPressed: () => onStatus('COMPLETED'), child: const Text('Mark collected')))),
      if (!seller && order.status == 'REQUESTED') Padding(padding: const EdgeInsets.only(top: 10), child: SizedBox(width: double.infinity, child: OutlinedButton(onPressed: () => onStatus('CANCELLED'), child: const Text('Cancel request')))),
    ]),
  );
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});
  final String status;
  @override
  Widget build(BuildContext context) => Container(padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5), decoration: BoxDecoration(color: const Color(0xFFE6F0E1), borderRadius: BorderRadius.circular(99)), child: Text(status.replaceAll('_', ' ').toLowerCase(), style: const TextStyle(color: _green, fontSize: 11, fontWeight: FontWeight.w800)));
}

class _Order {
  const _Order(this.json);
  final Map<String, dynamic> json;
  String get id => json['id'] as String;
  String get status => json['status'] as String;
  String get pickupName => json['pickupName'] as String;
  String get pickupAddress => json['pickupAddress'] as String;
  String get farmName => json['farmName'] as String;
  String get consumerName => json['consumerName'] as String;
  int get totalCents => json['totalCents'] as int;
  List<Map<String, dynamic>> get items => (json['items'] as List<dynamic>).cast<Map<String, dynamic>>();
}
