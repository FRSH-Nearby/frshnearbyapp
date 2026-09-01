import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../../config/api_config.dart';
import 'consumer_data.dart';

/// One basket line: how many of a product, the product itself so the basket
/// can be rendered from anywhere in the app, and when this reservation
/// expires server-side (null only in the brief window before the first
/// server round-trip for this line completes).
class BasketLine {
  const BasketLine({required this.product, required this.quantity, this.expiresAt});
  final ProductPost product;
  final double quantity;
  final DateTime? expiresAt;
}

/// The single cross-tab source of truth for "what's in each farm's basket".
/// One instance lives in the app shell and is handed to both the Explore
/// map and the Home product sheet, so adding an item from either place is
/// the same basket.
///
/// This is backed by the backend's real cart (`CartItem` + a 20-minute
/// reservation that actually decrements shared inventory) rather than being
/// purely local state: every quantity change is an optimistic local update
/// immediately followed by a server round-trip that reserves or releases
/// real stock, with a rollback if the server rejects it (e.g. someone else
/// took the last unit). [loadFromServer] restores the cart from the backend
/// on app start, so a reservation survives an app restart the same way it
/// does on the server.
class BasketController extends ChangeNotifier {
  final Map<String, Map<String, BasketLine>> _baskets = {};

  /// hotSaleId -> the server's CartItem id, needed to update/remove a line.
  /// Absence means this product has no server-side reservation yet.
  final Map<String, String> _cartItemIds = {};

  bool _loading = false;
  String? _lastError;

  bool get isLoading => _loading;
  String? get lastError => _lastError;

  double quantityFor(ProductPost product) =>
      _baskets[product.farmId]?[product.id]?.quantity ?? 0;

  List<BasketLine> linesFor(String farmId) =>
      List<BasketLine>.unmodifiable(_baskets[farmId]?.values ?? const []);

  /// Every farm that currently has at least one item in its basket.
  List<String> get farmIds => _baskets.keys.toList();

  bool hasItems(String farmId) => _baskets[farmId]?.isNotEmpty ?? false;
  bool get hasAnyItems => _baskets.values.any((basket) => basket.isNotEmpty);

  int lineCount(String farmId) => _baskets[farmId]?.length ?? 0;
  int get totalLineCount =>
      _baskets.values.fold(0, (total, basket) => total + basket.length);

  /// Restores the cart from the server. Call once at app start; safe to
  /// call again (e.g. pull-to-refresh) since it just replaces local state
  /// with the server's current view.
  Future<void> loadFromServer() async {
    _loading = true;
    notifyListeners();
    try {
      final items = await _fetchMyCart();
      _baskets.clear();
      _cartItemIds.clear();
      for (final item in items) {
        final product = _productFromCartItem(item);
        _baskets
            .putIfAbsent(product.farmId, () => {})
            [product.id] = BasketLine(
              product: product,
              quantity: (item['quantity'] as num).toDouble(),
              expiresAt: DateTime.parse(item['expiresAt'] as String),
            );
        _cartItemIds[product.id] = item['id'] as String;
      }
      _lastError = null;
    } catch (error) {
      _lastError = error.toString().replaceFirst('Bad state: ', '');
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> setQuantity(ProductPost product, double quantity) async {
    final previous = _baskets[product.farmId]?[product.id];
    final clamped = quantity.clamp(0, product.quantity).toDouble();
    if (clamped == (previous?.quantity ?? 0)) return;

    // Optimistic local update so the UI feels instant.
    _apply(product, clamped, previous?.expiresAt);
    notifyListeners();

    try {
      final existingId = _cartItemIds[product.id];
      if (clamped <= 0) {
        if (existingId != null) {
          await _removeCartItemRemote(existingId);
          _cartItemIds.remove(product.id);
        }
      } else if (existingId == null) {
        final view = await _addToCartRemote(product.id, clamped);
        _cartItemIds[product.id] = view['id'] as String;
        _apply(
          product,
          (view['quantity'] as num).toDouble(),
          DateTime.parse(view['expiresAt'] as String),
        );
      } else {
        final view = await _updateCartItemRemote(existingId, clamped);
        _apply(
          product,
          (view['quantity'] as num).toDouble(),
          DateTime.parse(view['expiresAt'] as String),
        );
      }
      _lastError = null;
    } catch (error) {
      // Roll back to whatever was true before this attempt.
      if (previous == null) {
        _apply(product, 0, null);
      } else {
        _apply(product, previous.quantity, previous.expiresAt);
      }
      _lastError = error.toString().replaceFirst('Bad state: ', '');
    }
    notifyListeners();
  }

  Future<void> changeQuantity(ProductPost product, double delta) =>
      setQuantity(product, quantityFor(product) + delta);

  void _apply(ProductPost product, double quantity, DateTime? expiresAt) {
    final basket = _baskets.putIfAbsent(product.farmId, () => {});
    if (quantity <= 0) {
      basket.remove(product.id);
      if (basket.isEmpty) _baskets.remove(product.farmId);
    } else {
      basket[product.id] = BasketLine(
        product: product,
        quantity: quantity,
        expiresAt: expiresAt,
      );
    }
  }

  void clearFarm(String farmId) {
    final removed = _baskets.remove(farmId);
    if (removed == null) return;
    for (final hotSaleId in removed.keys) {
      _cartItemIds.remove(hotSaleId);
    }
    notifyListeners();
  }

  /// Checks out one farm's basket: creates a real order from its (already
  /// reserved) cart lines and clears them locally on success.
  Future<void> submitOrder({
    required String farmId,
    required String pickupType,
    String? rekoRingId,
  }) async {
    final basket = _baskets[farmId];
    if (basket == null || basket.isEmpty) return;
    final sellerId = basket.values.first.product.farmOwnerId;
    await _checkoutCartRemote(
      sellerId: sellerId,
      pickupType: pickupType,
      rekoRingId: rekoRingId,
    );
    clearFarm(farmId);
  }

  // ---- networking ----

  Future<Map<String, dynamic>> _send(
    String query,
    Map<String, dynamic> variables,
  ) async {
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
            'Cart request failed.',
      );
    }
    return (body['data'] as Map<String, dynamic>?) ?? const {};
  }

  Future<List<Map<String, dynamic>>> _fetchMyCart() async {
    final data = await _send('query { myCart { $_cartItemFields } }', const {});
    return (data['myCart'] as List<dynamic>).cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>> _addToCartRemote(
    String hotSaleId,
    double quantity,
  ) async {
    final data = await _send(
      'mutation(\$input: AddToCartInput!) { addToCart(input: \$input) { $_cartItemFields } }',
      {
        'input': {'hotSaleId': hotSaleId, 'quantity': quantity},
      },
    );
    return data['addToCart'] as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> _updateCartItemRemote(
    String id,
    double quantity,
  ) async {
    final data = await _send(
      'mutation(\$input: UpdateCartItemInput!) { updateCartItemQuantity(input: \$input) { $_cartItemFields } }',
      {
        'input': {'id': id, 'quantity': quantity},
      },
    );
    return data['updateCartItemQuantity'] as Map<String, dynamic>;
  }

  Future<void> _removeCartItemRemote(String id) =>
      _send('mutation(\$id: String!) { removeCartItem(id: \$id) }', {'id': id});

  Future<void> _checkoutCartRemote({
    required String sellerId,
    required String pickupType,
    String? rekoRingId,
  }) => _send(
    'mutation(\$input: CheckoutCartInput!) { checkoutCart(input: \$input) { id status } }',
    {
      'input': {
        'pickups': [
          {
            'sellerId': sellerId,
            'pickupType': pickupType,
            if (rekoRingId != null) 'rekoRingId': rekoRingId,
          },
        ],
      },
    },
  );
}

const _cartItemFields =
    'id hotSaleId categoryKey originalLanguage detectedLanguage originalTitle description '
    'productionDetail unit customUnit quantityStep priceCents availableAtFarm '
    'translations { locale title description productionDetail status } '
    'rekoRings { id name municipality regionName addressLine postalCode '
    'schedule { frequency weekday startTime endTime timezone } } '
    'imageMimeType imageBase64 farmId sellerId farmName farmProfilePhotoUrl farmAddress farmCity '
    'availableQuantity quantity unitPriceCents lineTotalCents expiresAt secondsRemaining';

/// Reshapes a CartItemView response into the JSON shape [ProductPost]
/// expects. CartItemView is deliberately field-compatible with
/// nearbyHotSales' NearbyHotSaleView (see the backend's cart.types.ts) —
/// distance/geo fields and follow status aren't part of a cart line, so
/// they get safe placeholders rather than being left to throw if some
/// future screen reads them off a restored cart item.
ProductPost _productFromCartItem(Map<String, dynamic> item) => ProductPost({
  'id': item['hotSaleId'],
  'farmId': item['farmId'],
  'farmOwnerId': item['sellerId'],
  'categoryKey': item['categoryKey'],
  'originalLanguage': item['originalLanguage'],
  'detectedLanguage': item['detectedLanguage'],
  'originalTitle': item['originalTitle'],
  'description': item['description'],
  'productionDetail': item['productionDetail'],
  'unit': item['unit'],
  'customUnit': item['customUnit'],
  'quantityStep': item['quantityStep'],
  'priceCents': item['priceCents'],
  'availableAtFarm': item['availableAtFarm'],
  'translations': item['translations'],
  'rekoRings': item['rekoRings'],
  'imageMimeType': item['imageMimeType'],
  'imageBase64': item['imageBase64'],
  'farmName': item['farmName'],
  'farmProfilePhotoUrl': item['farmProfilePhotoUrl'],
  'farmCoverPhotoUrl': null,
  'farmDescription': null,
  'followerCount': 0,
  'isFollowed': false,
  'farmAddress': item['farmAddress'],
  'farmCity': item['farmCity'],
  'latitude': 0.0,
  'longitude': 0.0,
  'distanceKm': 0.0,
  'producedAt': null,
  'quantity': item['availableQuantity'],
});
