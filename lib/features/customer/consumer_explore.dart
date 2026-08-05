import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
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
  late LatLng _position;
  late Future<List<_NearbySale>> _sales;
  bool _usingLiveLocation = false;
  bool _locating = false;
  bool _showFarmTile = false;
  String? _selectedId;
  List<_NearbySale> _selectedFarmSales = const [];

  @override
  void initState() {
    super.initState();
    _position = LatLng(widget.location.latitude, widget.location.longitude);
    _sales = _load(_position);
    _useCurrentLocation();
  }

  Future<List<_NearbySale>> _load(LatLng origin) async {
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
        'query': '''query NearbyHotSales(\$latitude: Float!, \$longitude: Float!) {
          nearbyHotSales(radiusKm: 50, limit: 50, latitude: \$latitude, longitude: \$longitude) {
            id originalTitle description unit customUnit quantityStep priceCents quantity
            productionDetail producedAt availableAtFarm
            imageMimeType imageBase64 farmId farmName farmProfilePhotoUrl
            latitude longitude farmAddress farmCity distanceKm
            rekoRings { id name municipality regionName addressLine postalCode
              schedule { frequency weekday startTime endTime timezone }
            }
          }
        }''',
        'variables': {
          'latitude': origin.latitude,
          'longitude': origin.longitude,
        },
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

  void _retry() => setState(() => _sales = _load(_position));

  Future<void> _useCurrentLocation() async {
    if (_locating) return;
    setState(() => _locating = true);
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return;
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return;
      }
      final current = await Geolocator.getCurrentPosition();
      if (!mounted) return;
      final point = LatLng(current.latitude, current.longitude);
      setState(() {
        _position = point;
        _usingLiveLocation = true;
        _sales = _load(point);
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _mapController.move(point, 13.5);
      });
    } catch (_) {
      // Keep using the confirmed registration location when live GPS is
      // unavailable, denied, or unsupported by the current browser.
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  void _showSaleDetails(_NearbySale sale) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _SaleDetailsSheet(sale: sale),
    );
  }

  void _openFarmSales(List<_NearbySale> sales) {
    setState(() {
      _selectedId = sales.first.id;
      _selectedFarmSales = sales;
      _showFarmTile = true;
    });
    _mapController.move(
      LatLng(sales.first.latitude, sales.first.longitude),
      15.5,
    );
  }

  void _toggleFarmTile(List<_NearbySale> sales) {
    if (_showFarmTile) {
      setState(() => _showFarmTile = false);
      return;
    }
    if (_selectedFarmSales.isNotEmpty) {
      setState(() => _showFarmTile = true);
      return;
    }
    if (sales.isEmpty) return;
    final nearestFarmId = sales.first.farmId;
    _openFarmSales(
      sales.where((sale) => sale.farmId == nearestFarmId).toList(),
    );
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
              child: _SalesMap(
                controller: _mapController,
                position: _position,
                sales: sales,
                selectedId: _selectedId,
                onFarmSelect: _openFarmSales,
              ),
            ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: _ExploreHeader(
                  locationName:
                      _usingLiveLocation
                          ? 'Current location'
                          : widget.location.city,
                  count: sales.length,
                  onRefresh: _retry,
                  onLocate: _useCurrentLocation,
                  locating: _locating,
                  showFarmTile: _showFarmTile,
                  onToggleFarmTile: () => _toggleFarmTile(sales),
                ),
              ),
            ),
            if (sales.isEmpty)
              const Positioned.fill(
                child: IgnorePointer(
                  child: Center(
                    child: _EmptyMapCard(),
                  ),
                ),
              ),
            if (_showFarmTile && _selectedFarmSales.isNotEmpty)
              Positioned(
                left: 0,
                right: 0,
                bottom: 14,
                child: _FarmProductCarousel(
                  sales: _selectedFarmSales,
                  onDetails: _showSaleDetails,
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
    required this.position,
    required this.sales,
    required this.selectedId,
    required this.onFarmSelect,
  });

  final MapController controller;
  final LatLng position;
  final List<_NearbySale> sales;
  final String? selectedId;
  final ValueChanged<List<_NearbySale>> onFarmSelect;

  @override
  Widget build(BuildContext context) {
    final center = position;
    final farms = <String, List<_NearbySale>>{};
    for (final sale in sales) {
      farms.putIfAbsent(sale.farmId, () => []).add(sale);
    }
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
            ...farms.values.map(
              (farmSales) => Marker(
                point: LatLng(
                  farmSales.first.latitude,
                  farmSales.first.longitude,
                ),
                width: 112,
                height: 82,
                alignment: Alignment.bottomCenter,
                child: _FarmMarker(
                  sales: farmSales,
                  selected: farmSales.any((sale) => sale.id == selectedId),
                  onTap: () => onFarmSelect(farmSales),
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
    required this.locationName,
    required this.count,
    required this.onRefresh,
    required this.onLocate,
    required this.locating,
    required this.showFarmTile,
    required this.onToggleFarmTile,
  });
  final String locationName;
  final int count;
  final VoidCallback onRefresh;
  final VoidCallback onLocate;
  final bool locating;
  final bool showFarmTile;
  final VoidCallback onToggleFarmTile;

  @override
  Widget build(BuildContext context) => Material(
    elevation: 5,
    borderRadius: BorderRadius.circular(22),
    color: Colors.white.withValues(alpha: .96),
    child: Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Use current location',
            onPressed: locating ? null : onLocate,
            icon:
                locating
                    ? const SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                    : const Icon(Icons.my_location_rounded, color: _green),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('$count Hot Sales nearby', style: const TextStyle(fontWeight: FontWeight.w800)),
                Text(locationName, maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          IconButton(onPressed: onRefresh, icon: const Icon(Icons.refresh_rounded)),
          IconButton(
            tooltip: showFarmTile ? 'Hide farm tile' : 'Show farm tile',
            onPressed: onToggleFarmTile,
            icon: Icon(
              showFarmTile
                  ? Icons.map_rounded
                  : Icons.view_carousel_outlined,
            ),
          ),
        ],
      ),
    ),
  );
}

// ignore: unused_element
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

class _FarmMarker extends StatelessWidget {
  const _FarmMarker({
    required this.sales,
    required this.selected,
    required this.onTap,
  });
  final List<_NearbySale> sales;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final farm = sales.first;
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              if (sales.isNotEmpty)
                Positioned(
                  left: -22,
                  bottom: 2,
                  child: Container(
                    width: 35,
                    height: 35,
                    padding: const EdgeInsets.all(2),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(color: Colors.black26, blurRadius: 6),
                      ],
                    ),
                    child: ClipOval(
                      child: Image.memory(sales.first.imageBytes, fit: BoxFit.cover),
                    ),
                  ),
                ),
              if (sales.length > 1)
                Positioned(
                  right: -22,
                  bottom: 2,
                  child: Container(
                    width: 35,
                    height: 35,
                    padding: const EdgeInsets.all(2),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(color: Colors.black26, blurRadius: 6),
                      ],
                    ),
                    child: ClipOval(
                      child: Image.memory(sales[1].imageBytes, fit: BoxFit.cover),
                    ),
                  ),
                ),
              AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: selected ? 60 : 54,
                height: selected ? 60 : 54,
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: selected ? _green : Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: const [
                    BoxShadow(color: Colors.black26, blurRadius: 9),
                  ],
                ),
                child: CircleAvatar(
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
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                ),
              ),
              Positioned(
                right: -9,
                top: -7,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                  decoration: BoxDecoration(
                    color: _green,
                    borderRadius: BorderRadius.circular(99),
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  child: Text(
                    '${sales.length}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
            ],
          ),
          Container(width: 3, height: 10, color: _green),
        ],
      ),
    );
  }
}

class _UserMarker extends StatelessWidget {
  const _UserMarker();
  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(color: Colors.blue, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 3), boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 5)]),
  );
}

class _FarmProductCarousel extends StatelessWidget {
  const _FarmProductCarousel({
    required this.sales,
    required this.onDetails,
  });
  final List<_NearbySale> sales;
  final ValueChanged<_NearbySale> onDetails;

  @override
  Widget build(BuildContext context) {
    final farm = sales.first;
    return Container(
      height: 218,
      margin: const EdgeInsets.symmetric(horizontal: 14),
      padding: const EdgeInsets.fromLTRB(14, 13, 14, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(color: Colors.black26, blurRadius: 16, offset: Offset(0, 7)),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 23,
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
                      farm.farmName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
                    ),
                    Text(
                      '${sales.length} Hot Sales • ${farm.distanceKm.toStringAsFixed(1)} km away',
                      style: const TextStyle(color: Colors.black54, fontSize: 12),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.swipe_rounded, color: _green),
            ],
          ),
          const SizedBox(height: 11),
          Expanded(
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: sales.length,
              separatorBuilder: (_, _) => const SizedBox(width: 9),
              itemBuilder:
                  (_, index) => _MapProductCard(
                    sale: sales[index],
                    onDetails: () => onDetails(sales[index]),
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MapProductCard extends StatelessWidget {
  const _MapProductCard({
    required this.sale,
    required this.onDetails,
  });
  final _NearbySale sale;
  final VoidCallback onDetails;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onDetails,
    borderRadius: BorderRadius.circular(16),
    child: SizedBox(
      width: 126,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.memory(sale.imageBytes, fit: BoxFit.cover),
                  Positioned(
                    left: 6,
                    bottom: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: .94),
                        borderRadius: BorderRadius.circular(99),
                      ),
                      child: Text(
                        sale.price,
                        style: const TextStyle(
                          color: _green,
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 5),
          Text(
            sale.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    ),
  );
}

// Order controls return in step 2 after the farm discovery UI is approved.
// ignore: unused_element
class _QuantityControl extends StatelessWidget {
  const _QuantityControl({
    required this.sale,
    required this.selectedQuantity,
    required this.onAdd,
    required this.onRemove,
  });
  final _NearbySale sale;
  final double selectedQuantity;
  final VoidCallback onAdd;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    if (selectedQuantity <= 0) {
      return SizedBox(
        width: double.infinity,
        child: FilledButton.icon(
          onPressed: sale.quantity > 0 ? onAdd : null,
          icon: const Icon(Icons.add_rounded, size: 18),
          label: const Text('Add'),
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 10),
          ),
        ),
      );
    }
    final canAdd = selectedQuantity + sale.quantityStep <= sale.quantity + .0001;
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFE6F0E1),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            onPressed: onRemove,
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.remove_rounded),
          ),
          Expanded(
            child: Text(
              sale.formatQuantity(selectedQuantity),
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
          ),
          IconButton(
            onPressed: canAdd ? onAdd : null,
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.add_rounded),
          ),
        ],
      ),
    );
  }
}

// ignore: unused_element
class _BasketBar extends StatelessWidget {
  const _BasketBar({required this.lines, required this.total, required this.onTap});
  final int lines;
  final double total;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => FilledButton(
    onPressed: onTap,
    style: FilledButton.styleFrom(
      backgroundColor: const Color(0xFF173F2B),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      elevation: 8,
    ),
    child: Row(
      children: [
        const Icon(Icons.shopping_basket_outlined),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            '$lines ${lines == 1 ? 'product' : 'products'} in basket',
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
        Text(
          '€${total.toStringAsFixed(2)}',
          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
        ),
      ],
    ),
  );
}

// ignore: unused_element
class _BasketSheet extends StatefulWidget {
  const _BasketSheet({
    required this.sales,
    required this.quantityFor,
    required this.onAdd,
    required this.onRemove,
  });
  final List<_NearbySale> sales;
  final double Function(_NearbySale) quantityFor;
  final ValueChanged<_NearbySale> onAdd;
  final ValueChanged<_NearbySale> onRemove;

  @override
  State<_BasketSheet> createState() => _BasketSheetState();
}

class _BasketSheetState extends State<_BasketSheet> {
  double get _total => widget.sales.fold(
    0.0,
    (total, sale) =>
        total + widget.quantityFor(sale) * sale.priceCents / 100,
  );

  @override
  Widget build(BuildContext context) => FractionallySizedBox(
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
                  for (final sale in widget.sales)
                    if (widget.quantityFor(sale) > 0)
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
                                  Text(sale.title, style: const TextStyle(fontWeight: FontWeight.w800)),
                                  Text(sale.farmName, style: const TextStyle(color: Colors.black54, fontSize: 12)),
                                ],
                              ),
                            ),
                            SizedBox(
                              width: 142,
                              child: _QuantityControl(
                                sale: sale,
                                selectedQuantity: widget.quantityFor(sale),
                                onAdd: () {
                                  widget.onAdd(sale);
                                  setState(() {});
                                },
                                onRemove: () {
                                  widget.onRemove(sale);
                                  setState(() {});
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Expanded(child: Text('Total', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800))),
                Text('€${_total.toStringAsFixed(2)}', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: null,
                style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
                child: const Text('Checkout comes after UI approval'),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

// ignore: unused_element
class _FarmSalesSheet extends StatelessWidget {
  const _FarmSalesSheet({required this.sales, required this.onSelect});
  final List<_NearbySale> sales;
  final ValueChanged<_NearbySale> onSelect;

  @override
  Widget build(BuildContext context) {
    final farm = sales.first;
    return FractionallySizedBox(
      heightFactor: .78,
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
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 28,
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
                                fontSize: 20,
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
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        Text(
                          '${sales.length} Hot Sales • ${farm.distanceKm.toStringAsFixed(1)} km away',
                          style: const TextStyle(color: Colors.black54),
                        ),
                        if (farm.farmLocation.isNotEmpty)
                          Text(
                            farm.farmLocation,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: Colors.black54),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.all(14),
                itemCount: sales.length,
                separatorBuilder: (_, _) => const SizedBox(height: 11),
                itemBuilder:
                    (_, index) => _SaleCard(
                      sale: sales[index],
                      onTap: () => onSelect(sales[index]),
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SaleDetailsSheet extends StatelessWidget {
  const _SaleDetailsSheet({required this.sale});
  final _NearbySale sale;

  @override
  Widget build(BuildContext context) => FractionallySizedBox(
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
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 32),
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: Image.memory(
                    sale.imageBytes,
                    height: 245,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        sale.title,
                        style: const TextStyle(
                          fontSize: 25,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    Text(
                      sale.price,
                      style: const TextStyle(
                        color: _green,
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  '${sale.quantityLabel} available • ${sale.distanceKm.toStringAsFixed(1)} km away',
                  style: const TextStyle(color: Colors.black54),
                ),
                const SizedBox(height: 18),
                Text(sale.description, style: const TextStyle(height: 1.5)),
                if (sale.productionDetail?.isNotEmpty == true) ...[
                  const SizedBox(height: 14),
                  Text(
                    sale.productionDetail!,
                    style: const TextStyle(
                      color: Colors.black54,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                const Text(
                  'Sold by',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 25,
                        backgroundColor: const Color(0xFFE5EFDF),
                        backgroundImage:
                            sale.farmProfilePhotoUrl?.isNotEmpty == true
                                ? NetworkImage(sale.farmProfilePhotoUrl!)
                                : null,
                        child:
                            sale.farmProfilePhotoUrl?.isNotEmpty == true
                                ? null
                                : Text(
                                  sale.farmName.characters.first.toUpperCase(),
                                  style: const TextStyle(
                                    color: _green,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(sale.farmName, style: const TextStyle(fontWeight: FontWeight.w900)),
                            if (sale.farmLocation.isNotEmpty)
                              Text(sale.farmLocation, style: const TextStyle(color: Colors.black54)),
                          ],
                        ),
                      ),
                      const Icon(Icons.storefront_outlined, color: _green),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Available at',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 10),
                if (sale.availableAtFarm)
                  _PickupCard(
                    icon: Icons.storefront_rounded,
                    title: 'Farm pickup',
                    subtitle:
                        sale.farmLocation.isEmpty
                            ? sale.farmName
                            : sale.farmLocation,
                  ),
                for (final ring in sale.rekoRings)
                  _PickupCard(
                    icon: Icons.location_on_rounded,
                    title: ring.name,
                    subtitle: ring.details,
                  ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class _PickupCard extends StatelessWidget {
  const _PickupCard({
    required this.icon,
    required this.title,
    required this.subtitle,
  });
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
      border: Border.all(color: const Color(0xFFE1E8DD)),
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
              Text(subtitle, style: const TextStyle(color: Colors.black54)),
            ],
          ),
        ),
      ],
    ),
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
  String get farmId => json['farmId'] as String;
  String get title => json['originalTitle'] as String;
  String get description => json['description'] as String;
  String? get productionDetail => json['productionDetail'] as String?;
  String get farmName => json['farmName'] as String;
  String? get farmProfilePhotoUrl => json['farmProfilePhotoUrl'] as String?;
  String get farmLocation => [
    json['farmAddress'] as String?,
    json['farmCity'] as String?,
  ].where((value) => value?.isNotEmpty == true).join(', ');
  double get latitude => (json['latitude'] as num).toDouble();
  double get longitude => (json['longitude'] as num).toDouble();
  double get distanceKm => (json['distanceKm'] as num).toDouble();
  double get quantity => (json['quantity'] as num).toDouble();
  double get quantityStep => (json['quantityStep'] as num?)?.toDouble() ?? 1;
  int get priceCents => (json['priceCents'] as num).toInt();
  bool get availableAtFarm => json['availableAtFarm'] as bool? ?? false;
  List<_RekoPickup> get rekoRings =>
      ((json['rekoRings'] as List<dynamic>?) ?? const [])
          .map((ring) => _RekoPickup(ring as Map<String, dynamic>))
          .toList();
  String get unit => (json['customUnit'] as String?) ?? (json['unit'] as String).toLowerCase();
  Uint8List get imageBytes => base64Decode(json['imageBase64'] as String);
  String get price => '€${(priceCents / 100).toStringAsFixed(2)} / $unit';
  String get quantityLabel => '${quantity.toStringAsFixed(quantity % 1 == 0 ? 0 : 1)} $unit';
  String formatQuantity(double value) =>
      '${value.toStringAsFixed(value % 1 == 0 ? 0 : 2)} $unit';
}

class _RekoPickup {
  const _RekoPickup(this.json);
  final Map<String, dynamic> json;
  String get name => json['name'] as String;
  String get details {
    final schedule = json['schedule'] as Map<String, dynamic>?;
    final weekday = schedule?['weekday'] as int?;
    const days = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];
    final when =
        weekday != null && weekday >= 1 && weekday <= 7
            ? '${days[weekday - 1]} ${schedule?['startTime']}–${schedule?['endTime']}'
            : null;
    return [
      json['addressLine'] as String?,
      json['municipality'] as String?,
      when,
    ].where((value) => value?.isNotEmpty == true).join(' • ');
  }
}
