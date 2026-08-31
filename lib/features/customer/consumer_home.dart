import 'dart:async';

import 'package:flutter/material.dart' hide Text;
import 'package:geolocator/geolocator.dart';

import '../../l10n/localized_text.dart';
import '../auth/backend_service.dart';
import 'basket_controller.dart';
import 'consumer_data.dart';
import 'product_feed_page.dart';
import 'producer_feed_page.dart';
import 'widgets/category_picker_sheet.dart';
import 'widgets/producer_card.dart';
import 'widgets/product_card.dart';
import 'widgets/product_detail_sheet.dart';

const _green = Color(0xFF2F6B45);
const _ink = Color(0xFF1B2A20);
const _muted = Color(0xFF66735F);
const _line = Color(0xFFE7E5DB);
const _cream = Color(0xFFFBFAF5);

class ConsumerHomePage extends StatefulWidget {
  const ConsumerHomePage({
    required this.location,
    required this.basket,
    required this.onOpenExplore,
    required this.onOpenOrders,
    super.key,
  });

  final ConfirmedLocation location;
  final BasketController basket;
  final VoidCallback onOpenExplore;
  final VoidCallback onOpenOrders;

  @override
  State<ConsumerHomePage> createState() => _ConsumerHomePageState();
}

class _ConsumerHomePageState extends State<ConsumerHomePage> {
  late double _latitude = widget.location.latitude;
  late double _longitude = widget.location.longitude;
  late String _locationLabel = widget.location.city;
  bool _locating = false;

  late Future<List<ProductPost>> _productsFuture = _loadProducts();
  late Future<List<RecentOrder>> _ordersFuture = _loadOrders();
  List<ProductPost> _lastLoadedProducts = const [];

  bool _searchOpen = false;
  final _searchController = TextEditingController();
  String _searchQuery = '';
  Timer? _searchDebounce;
  List<ProductPost> _searchResults = const [];
  bool _searching = false;
  Object? _searchError;

  @override
  void initState() {
    super.initState();
    _useCurrentLocation();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchDebounce?.cancel();
    super.dispose();
  }

  Future<List<ProductPost>> _loadProducts() async {
    final products = await fetchNearbyProducts(
      latitude: _latitude,
      longitude: _longitude,
    );
    _lastLoadedProducts = products;
    return products;
  }

  Future<List<RecentOrder>> _loadOrders() => fetchMyOrders();

  void _retryProducts() => setState(() => _productsFuture = _loadProducts());
  void _retryOrders() => setState(() => _ordersFuture = _loadOrders());

  // Location defaults to the phone's physical position (matching Explore's
  // behaviour) and falls back to the confirmed signup address when GPS is
  // unavailable, denied, or unsupported by the current browser.
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
      setState(() {
        _latitude = current.latitude;
        _longitude = current.longitude;
        _locationLabel = localizeText(context, 'Current location');
        _productsFuture = _loadProducts();
      });
    } catch (_) {
      // Keep using the confirmed registration location when live GPS is
      // unavailable, denied, or unsupported by the current browser.
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  void _openCategoryPicker() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder:
          (_) => CategoryPickerSheet(
            onSelect: (category) => _openProductFeed(category: category),
          ),
    );
  }

  void _openProductFeed({ProductCategory? category, String query = ''}) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder:
            (_) => ProductFeedPage(
              title:
                  category != null
                      ? localizeText(context, category.label)
                      : localizeText(context, 'Hot Sales'),
              products: _lastLoadedProducts,
              initialCategory: category?.key,
              initialQuery: query,
              basket: widget.basket,
            ),
      ),
    );
  }

  void _openProducerFeed(String title, List<ProducerSummary> producers) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder:
            (_) => ProducerFeedPage(
              title: title,
              producers: producers,
              basket: widget.basket,
            ),
      ),
    );
  }

  void _openProductDetails(ProductPost product) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder:
          (_) => ProductDetailSheet(
            product: product,
            allProducts: _lastLoadedProducts,
            basket: widget.basket,
          ),
    );
  }

  void _submitSearch(String query) {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return;
    setState(() => _searchOpen = false);
    _openProductFeed(query: trimmed);
  }

  // Live suggestions call the backend's own search (title/description across
  // all locales) rather than substring-matching only the already-loaded
  // nearby list, debounced so we're not firing a request per keystroke.
  void _onSearchQueryChanged(String value) {
    setState(() => _searchQuery = value);
    _searchDebounce?.cancel();
    final trimmed = value.trim();
    if (trimmed.length < 2) {
      setState(() {
        _searchResults = const [];
        _searching = false;
        _searchError = null;
      });
      return;
    }
    setState(() => _searching = true);
    _searchDebounce = Timer(const Duration(milliseconds: 350), () async {
      try {
        final ids = await searchHotSaleIds(trimmed);
        if (!mounted || _searchController.text.trim() != trimmed) return;
        setState(() {
          _searchResults =
              _lastLoadedProducts.where((p) => ids.contains(p.id)).toList();
          _searching = false;
          _searchError = null;
        });
      } catch (error) {
        if (!mounted || _searchController.text.trim() != trimmed) return;
        setState(() {
          _searching = false;
          _searchError = error;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: _cream,
    child: SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(18, 10, 18, 30),
        children: [
          _HomeHeader(
            locationLabel: _locationLabel,
            locating: _locating,
            onRelocate: _useCurrentLocation,
            searchOpen: _searchOpen,
            onToggleSearch:
                () => setState(() {
                  _searchOpen = !_searchOpen;
                  if (!_searchOpen) {
                    _searchDebounce?.cancel();
                    _searchController.clear();
                    _searchQuery = '';
                    _searchResults = const [];
                    _searching = false;
                    _searchError = null;
                  }
                }),
          ),
          if (_searchOpen) ...[
            const SizedBox(height: 12),
            _SearchPanel(
              controller: _searchController,
              query: _searchQuery,
              results: _searchResults,
              searching: _searching,
              error: _searchError,
              onQueryChanged: _onSearchQueryChanged,
              onSubmit: _submitSearch,
              onPickCategory:
                  (category) => setState(() {
                    _searchOpen = false;
                    _openProductFeed(category: category);
                  }),
              onPickProduct: (product) {
                setState(() => _searchOpen = false);
                _openProductDetails(product);
              },
            ),
          ],
          const SizedBox(height: 22),
          Row(
            children: [
              Expanded(
                child: _SectionHeader(
                  title: localizeText(context, 'Product categories'),
                ),
              ),
              TextButton(
                onPressed: _openCategoryPicker,
                child: Text(localizeText(context, 'Show all')),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              for (final category
                  in kProductCategories.take(kHomeCategoryPreviewCount))
                Expanded(
                  child: _CategoryCircle(
                    category: category,
                    onTap: () => _openProductFeed(category: category),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 26),
          FutureBuilder<List<ProductPost>>(
            future: _productsFuture,
            builder:
                (context, snapshot) => _HotSalesSection(
                  connectionState: snapshot.connectionState,
                  error: snapshot.error,
                  products: snapshot.data ?? const [],
                  onRetry: _retryProducts,
                  onOpenDetails: _openProductDetails,
                  onShowAll: () => _openProductFeed(),
                ),
          ),
          const SizedBox(height: 26),
          FutureBuilder<List<ProductPost>>(
            future: _productsFuture,
            builder: (context, snapshot) {
              final producers = groupProducers(snapshot.data ?? const []);
              final favorites =
                  producers.where((producer) => producer.isFollowed).toList();
              return _FavoriteProducersSection(
                connectionState: snapshot.connectionState,
                error: snapshot.error,
                favorites: favorites,
                onRetry: _retryProducts,
                onOpenExplore: widget.onOpenExplore,
                basket: widget.basket,
                onDiscoverProducer:
                    () => _openProducerFeed(
                      localizeText(context, 'Producers near you'),
                      producers,
                    ),
                onShowAll:
                    () => _openProducerFeed(
                      localizeText(context, 'Favorite producers'),
                      favorites,
                    ),
              );
            },
          ),
          const SizedBox(height: 26),
          FutureBuilder<List<RecentOrder>>(
            future: _ordersFuture,
            builder:
                (context, snapshot) => _UpcomingPickupsSection(
                  connectionState: snapshot.connectionState,
                  error: snapshot.error,
                  orders: snapshot.data ?? const [],
                  onRetry: _retryOrders,
                  onShowAll: widget.onOpenOrders,
                ),
          ),
        ],
      ),
    ),
  );
}

// ---- header + search ----

class _HomeHeader extends StatelessWidget {
  const _HomeHeader({
    required this.locationLabel,
    required this.locating,
    required this.onRelocate,
    required this.searchOpen,
    required this.onToggleSearch,
  });

  final String locationLabel;
  final bool locating;
  final VoidCallback onRelocate;
  final bool searchOpen;
  final VoidCallback onToggleSearch;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      IconButton(
        tooltip: localizeText(context, 'Search a product'),
        onPressed: onToggleSearch,
        icon: Icon(searchOpen ? Icons.close_rounded : Icons.search_rounded),
      ),
      const Spacer(),
      InkWell(
        borderRadius: BorderRadius.circular(99),
        onTap: locating ? null : onRelocate,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (locating)
                const SizedBox.square(
                  dimension: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                const Icon(Icons.location_on_rounded, color: _green, size: 18),
              const SizedBox(width: 4),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 150),
                child: Text(
                  locationLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                ),
              ),
              const Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: _muted),
            ],
          ),
        ),
      ),
    ],
  );
}

class _SearchPanel extends StatelessWidget {
  const _SearchPanel({
    required this.controller,
    required this.query,
    required this.results,
    required this.searching,
    required this.error,
    required this.onQueryChanged,
    required this.onSubmit,
    required this.onPickCategory,
    required this.onPickProduct,
  });

  final TextEditingController controller;
  final String query;
  final List<ProductPost> results;
  final bool searching;
  final Object? error;
  final ValueChanged<String> onQueryChanged;
  final ValueChanged<String> onSubmit;
  final ValueChanged<ProductCategory> onPickCategory;
  final ValueChanged<ProductPost> onPickProduct;

  @override
  Widget build(BuildContext context) {
    final trimmed = query.trim().toLowerCase();
    // Category chips are a small fixed list, so matching them stays local —
    // only product results go through the server search.
    final matchingCategories =
        trimmed.isEmpty
            ? const <ProductCategory>[]
            : kProductCategories
                .where((c) => c.label.toLowerCase().contains(trimmed))
                .take(4)
                .toList();
    final hasResults = matchingCategories.isNotEmpty || results.isNotEmpty;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _line),
      ),
      padding: const EdgeInsets.all(10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: controller,
            autofocus: true,
            onChanged: onQueryChanged,
            onSubmitted: onSubmit,
            decoration: InputDecoration(
              hintText: localizeText(context, 'Search a product'),
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon:
                  searching
                      ? const Padding(
                        padding: EdgeInsets.all(14),
                        child: SizedBox.square(
                          dimension: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                      : null,
              filled: true,
              fillColor: const Color(0xFFF3F2EA),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          if (trimmed.isNotEmpty) ...[
            const SizedBox(height: 8),
            if (error != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  error.toString().replaceFirst('Bad state: ', ''),
                  style: const TextStyle(color: Colors.red),
                ),
              )
            else if (!hasResults && !searching)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  localizeText(context, 'No results — search again.'),
                  style: const TextStyle(color: _muted),
                ),
              )
            else ...[
              for (final category in matchingCategories)
                ListTile(
                  dense: true,
                  leading: Icon(category.icon, color: _green),
                  title: Text(localizeText(context, category.label)),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => onPickCategory(category),
                ),
              for (final product in results)
                ListTile(
                  dense: true,
                  leading: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.memory(
                      product.imageBytes,
                      width: 34,
                      height: 34,
                      fit: BoxFit.cover,
                    ),
                  ),
                  title: Text(
                    product.titleFor(context),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    product.farmName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  onTap: () => onPickProduct(product),
                ),
            ],
          ],
        ],
      ),
    );
  }
}

// ---- categories ----

class _CategoryCircle extends StatelessWidget {
  const _CategoryCircle({required this.category, required this.onTap});
  final ProductCategory category;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(18),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 52,
          height: 52,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            border: Border.all(color: _line),
            boxShadow: const [
              BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 2)),
            ],
          ),
          child: Icon(category.icon, color: _green),
        ),
        const SizedBox(height: 6),
        Text(
          localizeText(context, category.label),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: _ink),
        ),
      ],
    ),
  );
}

// ---- shared section chrome ----

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});
  final String title;
  @override
  Widget build(BuildContext context) => Text(
    title,
    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: _ink),
  );
}

class _SectionError extends StatelessWidget {
  const _SectionError({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: _line),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(message, style: const TextStyle(color: _muted)),
        const SizedBox(height: 8),
        TextButton(onPressed: onRetry, child: Text(localizeText(context, 'Try again'))),
      ],
    ),
  );
}

class _TwoButtonEmptyState extends StatelessWidget {
  const _TwoButtonEmptyState({
    required this.text,
    required this.primaryLabel,
    required this.onPrimary,
    required this.secondaryLabel,
    required this.onSecondary,
  });
  final String text;
  final String primaryLabel;
  final VoidCallback onPrimary;
  final String secondaryLabel;
  final VoidCallback onSecondary;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: _line),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(text, style: const TextStyle(color: _muted)),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(onPressed: onPrimary, child: Text(primaryLabel)),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: FilledButton(onPressed: onSecondary, child: Text(secondaryLabel)),
            ),
          ],
        ),
      ],
    ),
  );
}

Widget _loadingRow() => const SizedBox(
  height: 96,
  child: Center(child: CircularProgressIndicator(strokeWidth: 2.4)),
);

// ---- hot sales ----

class _HotSalesSection extends StatelessWidget {
  const _HotSalesSection({
    required this.connectionState,
    required this.error,
    required this.products,
    required this.onRetry,
    required this.onOpenDetails,
    required this.onShowAll,
  });

  final ConnectionState connectionState;
  final Object? error;
  final List<ProductPost> products;
  final VoidCallback onRetry;
  final ValueChanged<ProductPost> onOpenDetails;
  final VoidCallback onShowAll;

  @override
  Widget build(BuildContext context) {
    final header = Row(
      children: [
        Expanded(
          child: _SectionHeader(title: localizeText(context, 'Hot sales near you')),
        ),
        if (products.isNotEmpty)
          TextButton(onPressed: onShowAll, child: Text(localizeText(context, 'See all'))),
      ],
    );
    if (connectionState != ConnectionState.done) {
      return Column(children: [header, const SizedBox(height: 12), _loadingRow()]);
    }
    if (error != null) {
      return Column(
        children: [
          header,
          const SizedBox(height: 12),
          _SectionError(
            message: error.toString().replaceFirst('Bad state: ', ''),
            onRetry: onRetry,
          ),
        ],
      );
    }
    if (products.isEmpty) {
      return Column(
        children: [
          header,
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _line),
            ),
            child: Text(
              localizeText(context, 'No Hot Sales nearby yet.'),
              style: const TextStyle(color: _muted),
            ),
          ),
        ],
      );
    }
    return Column(
      children: [
        header,
        const SizedBox(height: 12),
        SizedBox(
          height: 226,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: products.length,
            separatorBuilder: (_, _) => const SizedBox(width: 12),
            itemBuilder:
                (_, index) => ProductCard(
                  product: products[index],
                  onTap: () => onOpenDetails(products[index]),
                ),
          ),
        ),
      ],
    );
  }
}

// ---- favorite producers ----

class _FavoriteProducersSection extends StatelessWidget {
  const _FavoriteProducersSection({
    required this.connectionState,
    required this.error,
    required this.favorites,
    required this.onRetry,
    required this.onOpenExplore,
    required this.onDiscoverProducer,
    required this.onShowAll,
    required this.basket,
  });

  final ConnectionState connectionState;
  final Object? error;
  final List<ProducerSummary> favorites;
  final VoidCallback onRetry;
  final VoidCallback onOpenExplore;
  final VoidCallback onDiscoverProducer;
  final BasketController basket;
  final VoidCallback onShowAll;

  @override
  Widget build(BuildContext context) {
    final header = Row(
      children: [
        Expanded(
          child: _SectionHeader(title: localizeText(context, 'Favorite producers')),
        ),
        if (favorites.isNotEmpty)
          TextButton(onPressed: onShowAll, child: Text(localizeText(context, 'See all'))),
      ],
    );
    if (connectionState != ConnectionState.done) {
      return Column(children: [header, const SizedBox(height: 12), _loadingRow()]);
    }
    if (error != null) {
      return Column(
        children: [
          header,
          const SizedBox(height: 12),
          _SectionError(
            message: error.toString().replaceFirst('Bad state: ', ''),
            onRetry: onRetry,
          ),
        ],
      );
    }
    if (favorites.isEmpty) {
      return Column(
        children: [
          header,
          const SizedBox(height: 12),
          _TwoButtonEmptyState(
            text: localizeText(context, "You aren't following any producers yet."),
            primaryLabel: localizeText(context, 'Discover producers'),
            onPrimary: onDiscoverProducer,
            secondaryLabel: localizeText(context, 'Go to map'),
            onSecondary: onOpenExplore,
          ),
        ],
      );
    }
    return Column(
      children: [
        header,
        const SizedBox(height: 12),
        SizedBox(
          height: 150,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: favorites.length,
            separatorBuilder: (_, _) => const SizedBox(width: 12),
            itemBuilder:
                (context, index) => ProducerCard(
                  producer: favorites[index],
                  onTap:
                      () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder:
                              (_) => ProductFeedPage(
                                title: favorites[index].farmName,
                                products: favorites[index].products,
                                basket: basket,
                              ),
                        ),
                      ),
                ),
          ),
        ),
      ],
    );
  }
}

// ---- upcoming pickups ----

class _UpcomingPickupsSection extends StatelessWidget {
  const _UpcomingPickupsSection({
    required this.connectionState,
    required this.error,
    required this.orders,
    required this.onRetry,
    required this.onShowAll,
  });

  final ConnectionState connectionState;
  final Object? error;
  final List<RecentOrder> orders;
  final VoidCallback onRetry;
  final VoidCallback onShowAll;

  @override
  Widget build(BuildContext context) {
    final upcomingCount = orders.where((order) => order.isUpcoming).length;
    final header = Row(
      children: [
        Expanded(
          child: _SectionHeader(title: localizeText(context, 'Upcoming pickups')),
        ),
        if (upcomingCount > 0)
          TextButton(onPressed: onShowAll, child: Text(localizeText(context, 'See all'))),
      ],
    );
    if (connectionState != ConnectionState.done) {
      return Column(
        children: [header, const SizedBox(height: 12), _loadingRow()],
      );
    }
    if (error != null) {
      return Column(
        children: [
          header,
          const SizedBox(height: 12),
          _SectionError(
            message: error.toString().replaceFirst('Bad state: ', ''),
            onRetry: onRetry,
          ),
        ],
      );
    }
    final upcoming = orders.where((order) => order.isUpcoming).toList();
    if (upcoming.isEmpty) {
      return Column(
        children: [
          header,
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _line),
            ),
            child: Text(
              localizeText(context, 'No upcoming pickups yet.'),
              style: const TextStyle(color: _muted),
            ),
          ),
        ],
      );
    }
    return Column(
      children: [
        header,
        const SizedBox(height: 12),
        SizedBox(
          height: 100,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: upcoming.length,
            separatorBuilder: (_, _) => const SizedBox(width: 12),
            itemBuilder: (_, index) => _UpcomingPickupCard(order: upcoming[index]),
          ),
        ),
      ],
    );
  }
}

class _UpcomingPickupCard extends StatelessWidget {
  const _UpcomingPickupCard({required this.order});
  final RecentOrder order;

  @override
  Widget build(BuildContext context) => Container(
    width: 220,
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: _line),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.event_available_outlined, size: 16, color: _green),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                order.pickupName.isEmpty
                    ? localizeText(context, 'Pickup')
                    : order.pickupName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          order.farmName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: _green, fontWeight: FontWeight.w700, fontSize: 12),
        ),
        if (order.pickupSchedule.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            order.pickupSchedule,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: _muted, fontSize: 11.5),
          ),
        ] else if (order.pickupAddress.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            order.pickupAddress,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: _muted, fontSize: 11.5),
          ),
        ],
      ],
    ),
  );
}
