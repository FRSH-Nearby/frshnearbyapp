import 'package:flutter/material.dart' hide Text;
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_marker_cluster/flutter_map_marker_cluster.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../auth/backend_service.dart';
import '../../l10n/localized_text.dart';
import 'basket_controller.dart';
import 'consumer_data.dart';
import 'widgets/basket_sheet.dart';
import 'widgets/producer_profile_page.dart';
import 'widgets/quantity_control.dart';

const _green = Color(0xFF2F6B45);
const _cream = Color(0xFFFBFAF5);

class ConsumerExplorePage extends StatefulWidget {
  const ConsumerExplorePage({
    required this.location,
    required this.basket,
    required this.onOpenOrders,
    super.key,
  });

  final ConfirmedLocation location;
  final BasketController basket;
  final VoidCallback onOpenOrders;

  @override
  State<ConsumerExplorePage> createState() => _ConsumerExplorePageState();
}

class _ConsumerExplorePageState extends State<ConsumerExplorePage> {
  final _mapController = MapController();
  late LatLng _position;
  late Future<List<ProductPost>> _sales;
  bool _usingLiveLocation = false;
  bool _locating = false;
  bool _showFarmTile = false;
  String? _selectedId;
  List<ProductPost> _selectedFarmSales = const [];
  List<ProductPost> _knownSales = const [];

  @override
  void initState() {
    super.initState();
    _position = LatLng(widget.location.latitude, widget.location.longitude);
    _sales = _load(_position);
    _useCurrentLocation();
    widget.basket.addListener(_onBasketChanged);
  }

  @override
  void dispose() {
    widget.basket.removeListener(_onBasketChanged);
    super.dispose();
  }

  void _onBasketChanged() {
    if (mounted) setState(() {});
  }

  Future<List<ProductPost>> _load(LatLng origin) async {
    final loaded = await fetchNearbyProducts(
      latitude: origin.latitude,
      longitude: origin.longitude,
    );
    _knownSales = loaded;
    return loaded;
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

  void _showSaleDetails(ProductPost sale) {
    setState(() {
      _selectedId = sale.id;
      _selectedFarmSales =
          _knownSales.where((item) => item.farmId == sale.farmId).toList();
    });
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder:
          (_) => StatefulBuilder(
            builder:
                (_, modalSetState) => _SaleDetailsSheet(
                  sale: sale,
                  selectedQuantity: _basketQuantity(sale),
                  onAdd: () {
                    _changeBasket(sale, sale.quantityStep);
                    modalSetState(() {});
                  },
                  onRemove: () {
                    _changeBasket(sale, -sale.quantityStep);
                    modalSetState(() {});
                  },
                ),
          ),
    );
  }

  double _basketQuantity(ProductPost sale) => widget.basket.quantityFor(sale);

  void _changeBasket(ProductPost sale, double change) =>
      widget.basket.changeQuantity(sale, change);

  List<ProductPost> _basketSales(String farmId) {
    // Join against the freshest fetched list rather than the basket's own
    // cached product snapshot, so price/quantity stay current.
    final ids =
        widget.basket.linesFor(farmId).map((line) => line.product.id).toSet();
    return _knownSales.where((sale) => sale.farmId == farmId && ids.contains(sale.id)).toList();
  }

  void _openBasket(String farmId) {
    if (!widget.basket.hasItems(farmId)) return;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder:
          (_) => BasketSheet(
            farmId: farmId,
            farmSales: _knownSales.where((sale) => sale.farmId == farmId).toList(),
            basket: widget.basket,
          ),
    ).then((_) => _retry());
  }

  void _openFarmSales(List<ProductPost> sales) {
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

  Future<void> _openPublicFarm(List<ProductPost> sales) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder:
            (_) => ProducerProfilePage(
              sales: sales,
              basket: widget.basket,
              onOpenOrders: widget.onOpenOrders,
            ),
      ),
    );
    if (mounted) setState(() {});
  }

  void _toggleFarmTile(List<ProductPost> sales) {
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
  Widget build(BuildContext context) => FutureBuilder<List<ProductPost>>(
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
      final activeFarmId =
          _selectedFarmSales.isEmpty ? null : _selectedFarmSales.first.farmId;
      final activeBasketSales =
          activeFarmId == null ? const <ProductPost>[] : _basketSales(activeFarmId);
      final activeTotal = activeBasketSales.fold<double>(
        0,
        (total, sale) => total + _basketQuantity(sale) * sale.priceCents / 100,
      );
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
                onProductSelect: _showSaleDetails,
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
                bottom: activeBasketSales.isEmpty ? 14 : 76,
                child: _FarmProductCarousel(
                  sales: _selectedFarmSales,
                  onDetails: _showSaleDetails,
                  quantityFor: _basketQuantity,
                  onAdd: (sale) => _changeBasket(sale, sale.quantityStep),
                  onRemove: (sale) => _changeBasket(sale, -sale.quantityStep),
                  onOpenFarm: () => _openPublicFarm(_selectedFarmSales),
                ),
              ),
            if (activeFarmId != null && activeBasketSales.isNotEmpty)
              Positioned(
                left: 14,
                right: 14,
                bottom: 12,
                child: _BasketBar(
                  lines: activeBasketSales.length,
                  total: activeTotal,
                  onTap: () => _openBasket(activeFarmId),
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
    required this.onProductSelect,
  });

  final MapController controller;
  final LatLng position;
  final List<ProductPost> sales;
  final String? selectedId;
  final ValueChanged<List<ProductPost>> onFarmSelect;
  final ValueChanged<ProductPost> onProductSelect;

  @override
  Widget build(BuildContext context) {
    final center = position;
    final farms = <String, List<ProductPost>>{};
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
          ],
        ),
        MarkerClusterLayerWidget(
          options: MarkerClusterLayerOptions(
            // Farm pins render as a 54-60px circle; a ~34px pixel radius
            // groups pins once they'd overlap by roughly half or more.
            maxClusterRadius: 34,
            size: const Size(60, 70),
            alignment: Alignment.bottomCenter,
            padding: const EdgeInsets.fromLTRB(40, 100, 40, 40),
            maxZoom: 18,
            zoomToBoundsOnClick: true,
            markerChildBehavior: true,
            markers:
                farms.values
                    .map(
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
                          selected: farmSales.any(
                            (sale) => sale.id == selectedId,
                          ),
                          onTap: () => onFarmSelect(farmSales),
                          onProductTap: onProductSelect,
                        ),
                      ),
                    )
                    .toList(),
            builder:
                (context, markers) =>
                    _FarmClusterMarker(count: markers.length),
          ),
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
            tooltip: localizeText(context, 'Use current location'),
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
                Text('$count ${localizeText(context, 'Hot Sales nearby')}', style: const TextStyle(fontWeight: FontWeight.w800)),
                Text(locationName, maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          IconButton(onPressed: onRefresh, icon: const Icon(Icons.refresh_rounded)),
          IconButton(
            tooltip:
                localizeText(
                  context,
                  showFarmTile ? 'Hide farm tile' : 'Show farm tile',
                ),
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
  final List<ProductPost> sales;
  final ValueChanged<ProductPost> onSelect;

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
  final ProductPost sale;
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
                  Text(sale.titleFor(context), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                  const SizedBox(height: 4),
                  Text(sale.farmName, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _green, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  Text('${sale.priceFor(context)}  •  ${sale.distanceKm.toStringAsFixed(1)} km', style: const TextStyle(fontWeight: FontWeight.w700)),
                  Text('${sale.quantityLabelFor(context)} ${localizeText(context, 'available')}', style: const TextStyle(color: Colors.black54, fontSize: 12)),
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
    required this.onProductTap,
  });
  final List<ProductPost> sales;
  final bool selected;
  final VoidCallback onTap;
  final ValueChanged<ProductPost> onProductTap;

  @override
  Widget build(BuildContext context) {
    final farm = sales.first;
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 104,
            height: 60,
            child: Stack(
              alignment: Alignment.center,
              children: [
              if (sales.isNotEmpty)
                Positioned(
                  left: 0,
                  bottom: 2,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => onProductTap(sales.first),
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
                        child: Image.memory(
                          sales.first.imageBytes,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  ),
                ),
              if (sales.length > 1)
                Positioned(
                  right: 0,
                  bottom: 2,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => onProductTap(sales[1]),
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
                        child: Image.memory(
                          sales[1].imageBytes,
                          fit: BoxFit.cover,
                        ),
                      ),
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
                right: 18,
                top: 0,
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
          ),
          Container(width: 3, height: 10, color: _green),
        ],
      ),
    );
  }
}

class _FarmClusterMarker extends StatelessWidget {
  const _FarmClusterMarker({required this.count});
  final int count;

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 60,
        height: 60,
        alignment: Alignment.center,
        decoration: const BoxDecoration(
          color: _green,
          shape: BoxShape.circle,
          border: Border.fromBorderSide(
            BorderSide(color: Colors.white, width: 3),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black38,
              blurRadius: 10,
              offset: Offset(0, 3),
            ),
          ],
        ),
        child: Text(
          '$count',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
      Container(width: 3, height: 10, color: _green),
    ],
  );
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
    required this.quantityFor,
    required this.onAdd,
    required this.onRemove,
    required this.onOpenFarm,
  });
  final List<ProductPost> sales;
  final ValueChanged<ProductPost> onDetails;
  final double Function(ProductPost) quantityFor;
  final ValueChanged<ProductPost> onAdd;
  final ValueChanged<ProductPost> onRemove;
  final VoidCallback onOpenFarm;

  @override
  Widget build(BuildContext context) {
    final farm = sales.first;
    return Container(
      height: 246,
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
          InkWell(
            onTap: onOpenFarm,
            borderRadius: BorderRadius.circular(16),
            child: Row(
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
                      '${sales.length} ${localizeText(context, 'Hot Sales')} • ${farm.distanceKm.toStringAsFixed(1)} ${localizeText(context, 'km away')}',
                      style: const TextStyle(color: Colors.black54, fontSize: 12),
                    ),
                  ],
                ),
              ),
                const Icon(Icons.chevron_right_rounded, color: _green),
              ],
            ),
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
                    selectedQuantity: quantityFor(sales[index]),
                    onAdd: () => onAdd(sales[index]),
                    onRemove: () => onRemove(sales[index]),
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
    required this.selectedQuantity,
    required this.onAdd,
    required this.onRemove,
  });
  final ProductPost sale;
  final VoidCallback onDetails;
  final double selectedQuantity;
  final VoidCallback onAdd;
  final VoidCallback onRemove;

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
                        sale.priceFor(context),
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
            sale.titleFor(context),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 5),
          SizedBox(
            height: 42,
            child: QuantityControl(
              sale: sale,
              selectedQuantity: selectedQuantity,
              onAdd: onAdd,
              onRemove: onRemove,
            ),
          ),
        ],
      ),
    ),
  );
}

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
            '$lines ${localizeText(context, lines == 1 ? 'product in basket' : 'products in basket')}',
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
class _FarmSalesSheet extends StatelessWidget {
  const _FarmSalesSheet({required this.sales, required this.onSelect});
  final List<ProductPost> sales;
  final ValueChanged<ProductPost> onSelect;

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
                          '${sales.length} ${localizeText(context, 'Hot Sales')} • ${farm.distanceKm.toStringAsFixed(1)} ${localizeText(context, 'km away')}',
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
  const _SaleDetailsSheet({
    required this.sale,
    required this.selectedQuantity,
    required this.onAdd,
    required this.onRemove,
  });
  final ProductPost sale;
  final double selectedQuantity;
  final VoidCallback onAdd;
  final VoidCallback onRemove;

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
                        sale.titleFor(context),
                        style: const TextStyle(
                          fontSize: 25,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    Text(
                      sale.priceFor(context),
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
                  '${sale.quantityLabelFor(context)} ${localizeText(context, 'available')} • ${sale.distanceKm.toStringAsFixed(1)} ${localizeText(context, 'km away')}',
                  style: const TextStyle(color: Colors.black54),
                ),
                const SizedBox(height: 14),
                QuantityControl(
                  sale: sale,
                  selectedQuantity: selectedQuantity,
                  onAdd: onAdd,
                  onRemove: onRemove,
                ),
                if (selectedQuantity > 0) ...[
                  const SizedBox(height: 8),
                  Text(
                    '${localizeText(context, 'Subtotal')} €${(selectedQuantity * sale.priceCents / 100).toStringAsFixed(2)}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: _green, fontWeight: FontWeight.w900),
                  ),
                ],
                const SizedBox(height: 18),
                Text(sale.descriptionFor(context), style: const TextStyle(height: 1.5)),
                if (sale.productionDetailFor(context)?.isNotEmpty == true) ...[
                  const SizedBox(height: 14),
                  Text(
                    sale.productionDetailFor(context)!,
                    style: const TextStyle(
                      color: Colors.black54,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
                if (sale.hasTranslationFor(context)) ...[
                  const SizedBox(height: 18),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0F5EC),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFDCE8D6)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.translate_rounded, size: 18, color: _green),
                            const SizedBox(width: 7),
                            Expanded(
                              child: Text(
                                '${localizeText(context, 'Translated from')} ${sale.sourceLanguage.toUpperCase()}',
                                style: const TextStyle(color: _green, fontWeight: FontWeight.w800),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(localizeText(context, 'Original'), style: const TextStyle(fontSize: 12, color: Colors.black54, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 3),
                        Text(sale.originalTitle, style: const TextStyle(fontWeight: FontWeight.w800)),
                        const SizedBox(height: 5),
                        Text(sale.originalDescription, style: const TextStyle(height: 1.4)),
                        if (sale.originalProductionDetail?.isNotEmpty == true) ...[
                          const SizedBox(height: 5),
                          Text(sale.originalProductionDetail!, style: const TextStyle(color: Colors.black54, fontStyle: FontStyle.italic)),
                        ],
                      ],
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
