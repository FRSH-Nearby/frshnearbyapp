import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../../config/api_config.dart';

/// The single cross-tab source of truth for "what's in each farm's basket".
/// One instance lives in the app shell and is handed to both the Explore
/// map and the Home product sheet, so adding an item from either place is
/// the same basket — nothing gets silently dropped at checkout.
class BasketController extends ChangeNotifier {
  final Map<String, Map<String, double>> _baskets = {};

  double quantityFor(String farmId, String saleId) =>
      _baskets[farmId]?[saleId] ?? 0;

  Map<String, double> basketFor(String farmId) =>
      Map<String, double>.unmodifiable(_baskets[farmId] ?? const {});

  bool hasItems(String farmId) => _baskets[farmId]?.isNotEmpty ?? false;

  int lineCount(String farmId) => _baskets[farmId]?.length ?? 0;

  void setQuantity(String farmId, String saleId, double quantity, double max) {
    final basket = _baskets.putIfAbsent(farmId, () => {});
    final clamped = quantity.clamp(0, max).toDouble();
    if (clamped <= 0) {
      basket.remove(saleId);
      if (basket.isEmpty) _baskets.remove(farmId);
    } else {
      basket[saleId] = clamped;
    }
    notifyListeners();
  }

  void changeQuantity(String farmId, String saleId, double delta, double max) {
    setQuantity(farmId, saleId, quantityFor(farmId, saleId) + delta, max);
  }

  void clearFarm(String farmId) {
    if (_baskets.remove(farmId) != null) notifyListeners();
  }

  Future<void> submitOrder({
    required String farmId,
    required String pickupType,
    String? rekoRingId,
  }) async {
    final basket = _baskets[farmId] ?? const {};
    if (basket.isEmpty) return;
    final token = await FirebaseAuth.instance.currentUser?.getIdToken();
    if (token == null) throw StateError('Please sign in again.');
    final dio = Dio(BaseOptions(baseUrl: ApiConfig.graphqlUrl));
    final response = await dio.post<Map<String, dynamic>>(
      '',
      data: {
        'query':
            'mutation RequestOrder(\$input: RequestOrderInput!) { requestOrder(input: \$input) { id status } }',
        'variables': {
          'input': {
            'pickupType': pickupType,
            if (rekoRingId != null) 'rekoRingId': rekoRingId,
            'items':
                basket.entries
                    .map(
                      (entry) => {
                        'hotSaleId': entry.key,
                        'quantity': entry.value,
                      },
                    )
                    .toList(),
          },
        },
      },
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
    clearFarm(farmId);
  }
}
