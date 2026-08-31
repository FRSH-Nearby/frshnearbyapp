// Shared data layer for the consumer-facing Home / product-feed /
// producer-feed screens: models, category definitions, and the GraphQL
// fetchers that back them. Kept in one place so every screen reads the
// same shape of data instead of drifting into copy/paste variants.
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart' hide Text;

import '../../config/api_config.dart';
import '../../l10n/localized_text.dart';

// ---- categories ----

class ProductCategory {
  const ProductCategory(this.key, this.label, this.icon);
  final String key;
  final String label;
  final IconData icon;
}

/// The full category list the product catalog is organised into. Matching
/// against a sale's [ProductPost.categoryKey] happens in [matchesCategory].
const kProductCategories = [
  ProductCategory('MEAT', 'Meat', Icons.kebab_dining_outlined),
  ProductCategory('FISH', 'Fish', Icons.set_meal_outlined),
  ProductCategory('VEGETABLES', 'Vegetables', Icons.eco_outlined),
  ProductCategory('FRUIT', 'Fruit', Icons.local_florist_outlined),
  ProductCategory('BERRIES', 'Berries', Icons.grain_outlined),
  ProductCategory('DAIRY', 'Dairy', Icons.icecream_outlined),
  ProductCategory('EGGS', 'Eggs', Icons.egg_outlined),
  ProductCategory('BAKERY', 'Bakery', Icons.bakery_dining_outlined),
  ProductCategory('HONEY', 'Honey', Icons.hive_outlined),
  ProductCategory('PRESERVES', 'Preserves', Icons.soup_kitchen_outlined),
  ProductCategory('DRINKS', 'Drinks', Icons.local_bar_outlined),
  ProductCategory('OTHER', 'Other', Icons.category_outlined),
];

/// How many category circles show inline on Home before "Show all".
const kHomeCategoryPreviewCount = 6;

bool matchesCategory(ProductPost sale, String key) {
  final raw = sale.categoryKey?.toUpperCase().trim();
  if (raw == null || raw.isEmpty) return false;
  return raw == key || raw.contains(key) || key.contains(raw);
}

// ---- product model ----

class ProductPost {
  ProductPost(this.json);
  final Map<String, dynamic> json;

  String get id => json['id'] as String;
  String get farmId => json['farmId'] as String;
  String? get categoryKey => json['categoryKey'] as String?;
  String get originalTitle => json['originalTitle'] as String;
  String get originalDescription => json['description'] as String;
  String? get originalProductionDetail =>
      json['productionDetail'] as String?;
  String get sourceLanguage =>
      (json['detectedLanguage'] as String? ??
              json['originalLanguage'] as String? ??
              'en')
          .toLowerCase();

  Map<String, dynamic>? _translationFor(String locale) {
    for (final item in (json['translations'] as List<dynamic>? ?? const [])) {
      final translation = item as Map<String, dynamic>;
      if (translation['locale'] == locale &&
          translation['status'] == 'COMPLETED') {
        return translation;
      }
    }
    return null;
  }

  String titleFor(BuildContext context) {
    final locale = Localizations.localeOf(context).languageCode;
    return _translationFor(locale)?['title'] as String? ?? originalTitle;
  }

  String descriptionFor(BuildContext context) {
    final locale = Localizations.localeOf(context).languageCode;
    return _translationFor(locale)?['description'] as String? ??
        originalDescription;
  }

  String? productionDetailFor(BuildContext context) {
    final locale = Localizations.localeOf(context).languageCode;
    return _translationFor(locale)?['productionDetail'] as String? ??
        originalProductionDetail;
  }

  String get farmOwnerId => json['farmOwnerId'] as String;
  String get farmName => json['farmName'] as String;
  String? get farmProfilePhotoUrl => json['farmProfilePhotoUrl'] as String?;
  String? get farmCoverPhotoUrl => json['farmCoverPhotoUrl'] as String?;
  String? get farmDescription => json['farmDescription'] as String?;
  int get followerCount => (json['followerCount'] as num?)?.toInt() ?? 0;
  bool get isFollowed => json['isFollowed'] as bool? ?? false;
  String get farmLocation => [
    json['farmAddress'] as String?,
    json['farmCity'] as String?,
  ].where((value) => value?.isNotEmpty == true).join(', ');
  double get latitude => (json['latitude'] as num).toDouble();
  double get longitude => (json['longitude'] as num).toDouble();
  double get distanceKm => (json['distanceKm'] as num).toDouble();
  DateTime? get producedAt =>
      DateTime.tryParse(json['producedAt'] as String? ?? '');
  double get quantity => (json['quantity'] as num).toDouble();
  double get quantityStep => (json['quantityStep'] as num?)?.toDouble() ?? 1;
  int get priceCents => (json['priceCents'] as num).toInt();
  bool get availableAtFarm => json['availableAtFarm'] as bool? ?? false;
  String get unit =>
      (json['customUnit'] as String?) ?? (json['unit'] as String).toLowerCase();
  String unitFor(BuildContext context) =>
      json['customUnit'] as String? ?? localizeText(context, unit);
  Uint8List get imageBytes => base64Decode(json['imageBase64'] as String);
  String priceFor(BuildContext context) =>
      '€${(priceCents / 100).toStringAsFixed(2)} / ${unitFor(context)}';
  String quantityLabelFor(BuildContext context) =>
      '${quantity.toStringAsFixed(quantity % 1 == 0 ? 0 : 1)} ${unitFor(context)}';
  String formatQuantity(BuildContext context, double value) =>
      '${value.toStringAsFixed(value % 1 == 0 ? 0 : 2)} ${unitFor(context)}';
  bool hasTranslationFor(BuildContext context) {
    final locale = Localizations.localeOf(context).languageCode;
    return locale != sourceLanguage && _translationFor(locale) != null;
  }
  List<RekoPickup> get rekoRings =>
      ((json['rekoRings'] as List<dynamic>?) ?? const [])
          .map((ring) => RekoPickup(ring as Map<String, dynamic>))
          .toList();

  // The backend does not compute product or producer ratings yet, so these
  // always evaluate to null today. Card widgets treat a null rating as
  // "hide the rating row" rather than showing a fake value — they're wired
  // up so a rating starts showing the moment the API returns one.
  double? get rating => (json['rating'] as num?)?.toDouble();
  double? get producerRating => (json['producerRating'] as num?)?.toDouble();
}

class RekoPickup {
  const RekoPickup(this.json);
  final Map<String, dynamic> json;
  String get id => json['id'] as String;
  String get name => json['name'] as String;
  String get municipality => json['municipality'] as String? ?? '';
  Map<String, dynamic>? get _schedule =>
      json['schedule'] as Map<String, dynamic>?;
  int? get weekday => _schedule?['weekday'] as int?;
  String? get startTime => _schedule?['startTime'] as String?;
  String? get endTime => _schedule?['endTime'] as String?;
  String get details {
    const days = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];
    final day = weekday;
    final when =
        day != null && day >= 1 && day <= 7
            ? '${days[day - 1]} $startTime–$endTime'
            : null;
    return [
      json['addressLine'] as String?,
      municipality,
      when,
    ].where((value) => value?.isNotEmpty == true).join(' • ');
  }
}

// ---- producer model (derived by grouping products by farm) ----

class ProducerSummary {
  const ProducerSummary({
    required this.farmId,
    required this.farmName,
    required this.farmProfilePhotoUrl,
    required this.farmDescription,
    required this.isFollowed,
    required this.followerCount,
    required this.distanceKm,
    required this.products,
    required this.farmLocation,
  });

  final String farmId;
  final String farmName;
  final String? farmProfilePhotoUrl;
  final String? farmDescription;
  final bool isFollowed;
  final int followerCount;
  final double distanceKm;
  final List<ProductPost> products;
  final String farmLocation;

  // Whether this is a registered business or a hobby/private producer is a
  // real legal-disclosure requirement, but `nearbyHotSales` doesn't expose
  // an account-type field for OTHER users' farms today (only for your own
  // account, via BackendService.session). Left nullable/hidden on the card
  // until the backend adds it here rather than guessing.
  String? get businessType => null;
}

List<ProducerSummary> groupProducers(List<ProductPost> sales) {
  final byFarm = <String, List<ProductPost>>{};
  for (final sale in sales) {
    byFarm.putIfAbsent(sale.farmId, () => []).add(sale);
  }
  final producers =
      byFarm.values.map((group) {
        final first = group.first;
        final nearest = group
            .map((sale) => sale.distanceKm)
            .reduce((a, b) => a < b ? a : b);
        return ProducerSummary(
          farmId: first.farmId,
          farmName: first.farmName,
          farmProfilePhotoUrl: first.farmProfilePhotoUrl,
          farmDescription: first.farmDescription,
          isFollowed: first.isFollowed,
          followerCount: first.followerCount,
          distanceKm: nearest,
          products: group,
          farmLocation: first.farmLocation,
        );
      }).toList();
  producers.sort((a, b) => a.distanceKm.compareTo(b.distanceKm));
  return producers;
}

Future<List<ProductPost>> fetchNearbyProducts({
  required double latitude,
  required double longitude,
}) async {
  final token = await FirebaseAuth.instance.currentUser?.getIdToken();
  if (token == null) throw StateError('Please sign in again.');
  final dio = Dio(BaseOptions(baseUrl: ApiConfig.graphqlUrl));
  final response = await dio.post<Map<String, dynamic>>(
    '',
    data: {
      'query': '''query NearbyHotSales(\$latitude: Float!, \$longitude: Float!) {
        nearbyHotSales(radiusKm: 50, limit: 50, latitude: \$latitude, longitude: \$longitude) {
          id categoryKey originalLanguage detectedLanguage originalTitle description unit customUnit quantityStep priceCents quantity
          productionDetail availableAtFarm
          translations { locale title description productionDetail status }
          imageMimeType imageBase64 farmId farmName farmProfilePhotoUrl
          farmOwnerId farmCoverPhotoUrl farmDescription followerCount isFollowed
          latitude longitude farmAddress farmCity distanceKm
          rekoRings { id name municipality regionName addressLine postalCode
            schedule { frequency weekday startTime endTime timezone }
          }
        }
      }''',
      'variables': {'latitude': latitude, 'longitude': longitude},
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
  final loaded = ((data?['nearbyHotSales'] as List<dynamic>?) ?? const [])
      .map((item) => ProductPost(item as Map<String, dynamic>))
      .toList();
  loaded.sort((a, b) => a.distanceKm.compareTo(b.distanceKm));
  return loaded;
}

/// Server-side full-text search over Hot Sale titles/descriptions (original
/// text and all completed translations). Only `id`s are requested: the
/// backend's `searchHotSales` returns the bare `HotSaleView` shape (no farm,
/// distance, or follow data), so callers intersect the returned ids against
/// an already-loaded `nearbyHotSales` list to keep farm context for display
/// and basket actions. The backend itself ignores queries under 2 chars, so
/// we skip the round trip for those too.
Future<Set<String>> searchHotSaleIds(String query, {int limit = 25}) async {
  final trimmed = query.trim();
  if (trimmed.length < 2) return {};
  final token = await FirebaseAuth.instance.currentUser?.getIdToken();
  if (token == null) throw StateError('Please sign in again.');
  final dio = Dio(BaseOptions(baseUrl: ApiConfig.graphqlUrl));
  final response = await dio.post<Map<String, dynamic>>(
    '',
    data: {
      'query':
          'query SearchHotSales(\$search: String!, \$limit: Int) { searchHotSales(search: \$search, limit: \$limit) { id } }',
      'variables': {'search': trimmed, 'limit': limit},
    },
    options: Options(headers: {'authorization': 'Bearer $token'}),
  );
  final body = response.data ?? const {};
  final errors = body['errors'] as List<dynamic>?;
  if (errors?.isNotEmpty == true) {
    throw StateError(
      (errors!.first as Map<String, dynamic>)['message'] as String? ??
          'Search failed.',
    );
  }
  final data = body['data'] as Map<String, dynamic>?;
  return ((data?['searchHotSales'] as List<dynamic>?) ?? const [])
      .map((item) => (item as Map<String, dynamic>)['id'] as String)
      .toSet();
}

// ---- orders (real order history, used for "recent orders" + "upcoming pickups") ----

class OrderItem {
  const OrderItem(this.json);
  final Map<String, dynamic> json;
  String get hotSaleId => json['hotSaleId'] as String;
  String get title => json['title'] as String;
  String get unit => json['unit'] as String;
  double get quantity => (json['quantity'] as num).toDouble();
  Uint8List get imageBytes => base64Decode(json['imageBase64'] as String);
}

class RecentOrder {
  const RecentOrder(this.json);
  final Map<String, dynamic> json;
  String get id => json['id'] as String;
  String get status => json['status'] as String;
  String get pickupType => json['pickupType'] as String? ?? '';
  String get pickupName => json['pickupName'] as String? ?? '';
  String get pickupAddress => json['pickupAddress'] as String? ?? '';
  String get pickupSchedule => json['pickupSchedule'] as String? ?? '';
  String get farmName => json['farmName'] as String;
  int get totalCents => (json['totalCents'] as num).toInt();
  DateTime? get createdAt =>
      DateTime.tryParse(json['createdAt'] as String? ?? '');
  List<OrderItem> get items =>
      ((json['items'] as List<dynamic>?) ?? const [])
          .map((item) => OrderItem(item as Map<String, dynamic>))
          .toList();

  /// An order the farm has confirmed but that hasn't been collected yet —
  /// the closest real signal to "an upcoming pickup you've ordered into".
  bool get isUpcoming => status == 'ACCEPTED' || status == 'READY_FOR_PICKUP';
}

Future<List<RecentOrder>> fetchMyOrders() async {
  final token = await FirebaseAuth.instance.currentUser?.getIdToken();
  if (token == null) throw StateError('Please sign in again.');
  final dio = Dio(BaseOptions(baseUrl: ApiConfig.graphqlUrl));
  const fields =
      'id status pickupType rekoRingId pickupName pickupAddress pickupSchedule '
      'farmName totalCents createdAt updatedAt '
      'items { id hotSaleId title imageMimeType imageBase64 unit quantityStep quantity unitPriceCents lineTotalCents }';
  final response = await dio.post<Map<String, dynamic>>(
    '',
    data: {'query': 'query { myOrders { $fields } }'},
    options: Options(headers: {'authorization': 'Bearer $token'}),
  );
  final body = response.data ?? const {};
  final errors = body['errors'] as List<dynamic>?;
  if (errors?.isNotEmpty == true) {
    throw StateError(
      (errors!.first as Map<String, dynamic>)['message'] as String? ??
          'Could not load your orders.',
    );
  }
  final data = body['data'] as Map<String, dynamic>?;
  final orders = ((data?['myOrders'] as List<dynamic>?) ?? const [])
      .map((item) => RecentOrder(item as Map<String, dynamic>))
      .toList();
  orders.sort((a, b) {
    final aTime = a.createdAt;
    final bTime = b.createdAt;
    if (aTime == null || bTime == null) return 0;
    return bTime.compareTo(aTime);
  });
  return orders;
}
