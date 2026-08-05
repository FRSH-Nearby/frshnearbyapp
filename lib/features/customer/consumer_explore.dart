import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../auth/backend_service.dart';

const _green = Color(0xFF2F6B45);
const _cream = Color(0xFFFBFAF5);

class ConsumerExplorePage extends StatefulWidget {
  const ConsumerExplorePage({required this.location, super.key});

  final ConfirmedLocation location;

  @override
  State<ConsumerExplorePage> createState() => _ConsumerExplorePageState();
}

class _ConsumerExplorePageState extends State<ConsumerExplorePage> {
  final _mapController = MapController();
  late Future<List<_NearbySale>> _sales = _load();
  bool _showList = false;
  String? _selectedId;

  Future<List<_NearbySale>> _load() async {
    final token = await FirebaseAuth.instance.currentUser?.getIdToken();
    if (token == null) throw StateError('Please sign in again.');
    final dio = Dio(
      BaseOptions(
        baseUrl: const String.fromEnvironment(
          'FRSH_API_URL',
          defaultValue: 'https://frshnearby-api.onrender.com/graphql',
        ),
      ),
    );
    final response = await dio.post<Map<String, dynamic>>(
      '',
      data: {
        'query': '''query NearbyHotSales {
          nearbyHotSales(radiusKm: 50, limit: 50) {
            id originalTitle description unit customUnit priceCents quantity
            imageMimeType imageBase64 farmId farmName farmProfilePhotoUrl
            latitude longitude farmAddress farmCity distanceKm
          }
        }''',
      },
      options: Options(headers: {'authorization': 'Bearer $token'}),
    );
    final body = response.data ?? const {};
    final errors = body['errors'] as List<dynamic>?;
    if (errors?.isNotEmpty == true) {
      throw StateError(
        (errors!.first as Map<String, dynamic>)['message'] as String? ??
            'Could not load nearby Hot Sales.',
      );
    }
    final data = body['data'] as Map<String, dynamic>?;
    return ((data?['nearbyHotSales'] as List<dynamic>?) ?? const [])
        .map((item) => _NearbySale(item as Map<String, dynamic>))
        .toList();
  }

  void _retry() => setState(() => _sales = _load());

  void _select(_NearbySale sale) {
    setState(() => _selectedId = sale.id);
    _mapController.move(LatLng(sale.latitude, sale.longitude), 15.5);
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<List<_NearbySale>>(
    future: _sales,
    builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done) {
        return const Center(child: CircularProgressIndicator());
      }
      if (snapshot.hasError) {
        return _ExploreMessage(
          icon: Icons.cloud_off_outlined,
          title: 'Could not load nearby Hot Sales',
          message: snapshot.error.toString().replaceFirst('Bad state: ', ''),
          action: _retry,
        );
      }
      final sales = snapshot.data ?? const [];
      return SizedBox.expand(
        child: Stack(
          children: [
            Positioned.fill(
              child:
                  _showList
                      ? _SalesList(sales: sales, onSelect: _select)
                      : _SalesMap(
                        controller: _mapController,
                        location: widget.location,
                        sales: sales,
                        selectedId: _selectedId,
                        onSelect: _select,
                      ),
            ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: _ExploreHeader(
                  location: widget.location,
                  count: sales.length,
                  showList: _showList,
                  onToggle: () => setState(() => _showList = !_showList),
                  onRefresh: _retry,
                ),
              ),
            ),
            if (!_showList && sales.isEmpty)
              const Positioned.fill(
                child: IgnorePointer(
                  child: Center(
                    child: _EmptyMapCard(),
                  ),
                ),
              ),
          ],
        ),
      );
    },
  );
}

class _SalesMap extends StatelessWidget {
  const _SalesMap({
    required this.controller,
    required this.location,
    required this.sales,
    required this.selectedId,
    required this.onSelect,
  });

  final MapController controller;
  final ConfirmedLocation location;
  final List<_NearbySale> sales;
  final String? selectedId;
  final ValueChanged<_NearbySale> onSelect;

  @override
  Widget build(BuildContext context) {
    final center = LatLng(location.latitude, location.longitude);
    return FlutterMap(
      mapController: controller,
      options: MapOptions(initialCenter: center, initialZoom: 12.5),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.frshnearby.frshnearby',
        ),
        MarkerLayer(
          markers: [
            Marker(
              point: center,
              width: 28,
              height: 28,
              child: const _UserMarker(),
            ),
            ...sales.map(
              (sale) => Marker(
                point: LatLng(sale.latitude, sale.longitude),
                width: 76,
                height: 76,
                alignment: Alignment.bottomCenter,
                child: _SaleMarker(
                  sale: sale,
                  selected: sale.id == selectedId,
                  onTap: () => onSelect(sale),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _ExploreHeader extends StatelessWidget {
  const _ExploreHeader({
    required this.location,
    required this.count,
    required this.showList,
    required this.onToggle,
    required this.onRefresh,
  });
  final ConfirmedLocation location;
  final int count;
  final bool showList;
  final VoidCallback onToggle;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) => Material(
    elevation: 5,
    borderRadius: BorderRadius.circular(22),
    color: Colors.white.withValues(alpha: .96),
    child: Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
      child: Row(
        children: [
          const Icon(Icons.near_me_rounded, color: _green),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('$count Hot Sales nearby', style: const TextStyle(fontWeight: FontWeight.w800)),
                Text(location.city, maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          IconButton(onPressed: onRefresh, icon: const Icon(Icons.refresh_rounded)),
          IconButton(
            tooltip: showList ? 'Map view' : 'List view',
            onPressed: onToggle,
            icon: Icon(showList ? Icons.map_rounded : Icons.view_agenda_rounded),
          ),
        ],
      ),
    ),
  );
}

class _SalesList extends StatelessWidget {
  const _SalesList({required this.sales, required this.onSelect});
  final List<_NearbySale> sales;
  final ValueChanged<_NearbySale> onSelect;

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: _cream,
    child: ListView(
      padding: const EdgeInsets.fromLTRB(14, 102, 14, 28),
      children: [
        if (sales.isEmpty) const _EmptyMapCard(),
        for (final sale in sales)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _SaleCard(sale: sale, onTap: () => onSelect(sale)),
          ),
      ],
    ),
  );
}

class _SaleCard extends StatelessWidget {
  const _SaleCard({required this.sale, required this.onTap});
  final _NearbySale sale;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.white,
    borderRadius: BorderRadius.circular(20),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(15),
              child: Image.memory(sale.imageBytes, width: 86, height: 86, fit: BoxFit.cover),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(sale.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                  const SizedBox(height: 4),
                  Text(sale.farmName, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _green, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  Text('${sale.price}  •  ${sale.distanceKm.toStringAsFixed(1)} km', style: const TextStyle(fontWeight: FontWeight.w700)),
                  Text('${sale.quantityLabel} available', style: const TextStyle(color: Colors.black54, fontSize: 12)),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _SaleMarker extends StatelessWidget {
  const _SaleMarker({required this.sale, required this.selected, required this.onTap});
  final _NearbySale sale;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: selected ? 54 : 46,
          height: selected ? 54 : 46,
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(color: selected ? _green : Colors.white, shape: BoxShape.circle, boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 8)]),
          child: ClipOval(child: Image.memory(sale.imageBytes, fit: BoxFit.cover)),
        ),
        Container(width: 3, height: 10, color: _green),
      ],
    ),
  );
}

class _UserMarker extends StatelessWidget {
  const _UserMarker();
  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(color: Colors.blue, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 3), boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 5)]),
  );
}

class _EmptyMapCard extends StatelessWidget {
  const _EmptyMapCard();
  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.all(30),
    child: const Padding(
      padding: EdgeInsets.all(22),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.eco_outlined, size: 34, color: _green),
        SizedBox(height: 10),
        Text('No farm Hot Sales within 50 km yet', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.w800)),
        SizedBox(height: 5),
        Text('New seasonal products will appear here.', textAlign: TextAlign.center),
      ]),
    ),
  );
}

class _ExploreMessage extends StatelessWidget {
  const _ExploreMessage({required this.icon, required this.title, required this.message, required this.action});
  final IconData icon;
  final String title;
  final String message;
  final VoidCallback action;
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(28),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 42, color: _green),
        const SizedBox(height: 12),
        Text(title, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
        const SizedBox(height: 6),
        Text(message, textAlign: TextAlign.center),
        const SizedBox(height: 16),
        FilledButton.icon(onPressed: action, icon: const Icon(Icons.refresh_rounded), label: const Text('Try again')),
      ]),
    ),
  );
}

class _NearbySale {
  _NearbySale(this.json);
  final Map<String, dynamic> json;
  String get id => json['id'] as String;
  String get title => json['originalTitle'] as String;
  String get farmName => json['farmName'] as String;
  double get latitude => (json['latitude'] as num).toDouble();
  double get longitude => (json['longitude'] as num).toDouble();
  double get distanceKm => (json['distanceKm'] as num).toDouble();
  double get quantity => (json['quantity'] as num).toDouble();
  String get unit => (json['customUnit'] as String?) ?? (json['unit'] as String).toLowerCase();
  Uint8List get imageBytes => base64Decode(json['imageBase64'] as String);
  String get price => '€${((json['priceCents'] as num) / 100).toStringAsFixed(2)} / $unit';
  String get quantityLabel => '${quantity.toStringAsFixed(quantity % 1 == 0 ? 0 : 1)} $unit';
}
