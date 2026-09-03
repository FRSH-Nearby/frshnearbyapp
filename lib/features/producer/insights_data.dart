// Data layer for the producer Insights page: date-range presets, response
// models, and the GraphQL fetchers that back them (see the backend's
// insights.resolver.ts for the matching producerInsights/*Pdf queries).
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../config/api_config.dart';

// ---- date range ----

enum InsightsPreset { thisWeek, thisMonth, last30Days, lastMonth, thisYear, custom }

class InsightsRange {
  const InsightsRange({required this.preset, required this.from, required this.to});

  final InsightsPreset preset;

  /// Inclusive start of day.
  final DateTime from;

  /// Exclusive — midnight of the day *after* the last day covered.
  final DateTime to;

  DateTime get lastDay => to.subtract(const Duration(days: 1));

  static DateTime _dayStart(DateTime d) => DateTime(d.year, d.month, d.day);

  factory InsightsRange.forPreset(InsightsPreset preset, {DateTime? now}) {
    final today = _dayStart(now ?? DateTime.now());
    switch (preset) {
      case InsightsPreset.thisWeek:
        final start = today.subtract(Duration(days: today.weekday - 1));
        return InsightsRange(preset: preset, from: start, to: today.add(const Duration(days: 1)));
      case InsightsPreset.thisMonth:
        final start = DateTime(today.year, today.month, 1);
        return InsightsRange(preset: preset, from: start, to: today.add(const Duration(days: 1)));
      case InsightsPreset.last30Days:
        return InsightsRange(
          preset: preset,
          from: today.subtract(const Duration(days: 29)),
          to: today.add(const Duration(days: 1)),
        );
      case InsightsPreset.lastMonth:
        final firstOfThisMonth = DateTime(today.year, today.month, 1);
        final firstOfLastMonth = DateTime(today.year, today.month - 1, 1);
        return InsightsRange(preset: preset, from: firstOfLastMonth, to: firstOfThisMonth);
      case InsightsPreset.thisYear:
        return InsightsRange(
          preset: preset,
          from: DateTime(today.year, 1, 1),
          to: today.add(const Duration(days: 1)),
        );
      case InsightsPreset.custom:
        return InsightsRange(preset: preset, from: today, to: today.add(const Duration(days: 1)));
    }
  }

  factory InsightsRange.custom(DateTime from, DateTime to) => InsightsRange(
    preset: InsightsPreset.custom,
    from: _dayStart(from),
    to: _dayStart(to).add(const Duration(days: 1)),
  );
}

String presetLabel(InsightsPreset preset) => switch (preset) {
  InsightsPreset.thisWeek => 'This week',
  InsightsPreset.thisMonth => 'This month',
  InsightsPreset.last30Days => 'Last 30 days',
  InsightsPreset.lastMonth => 'Last month',
  InsightsPreset.thisYear => 'This year',
  InsightsPreset.custom => 'Custom range',
};

// ---- models (mirrors ProducerInsightsReport in the backend) ----

class InsightsSummary {
  InsightsSummary(this.json);
  final Map<String, dynamic> json;
  int get totalSalesCents => (json['totalSalesCents'] as num).toInt();
  double? get totalSalesChangePercent => (json['totalSalesChangePercent'] as num?)?.toDouble();
  int get completedOrders => (json['completedOrders'] as num).toInt();
  double? get completedOrdersChangePercent => (json['completedOrdersChangePercent'] as num?)?.toDouble();
  double get quantitySold => (json['quantitySold'] as num).toDouble();
  double? get quantitySoldChangePercent => (json['quantitySoldChangePercent'] as num?)?.toDouble();
  int get averageOrderValueCents => (json['averageOrderValueCents'] as num).toInt();
  double? get averageOrderValueChangePercent => (json['averageOrderValueChangePercent'] as num?)?.toDouble();
}

class InsightsTrendPoint {
  InsightsTrendPoint(this.json);
  final Map<String, dynamic> json;
  DateTime get date => DateTime.parse(json['date'] as String);
  int get totalCents => (json['totalCents'] as num).toInt();
  int get previousPeriodTotalCents => (json['previousPeriodTotalCents'] as num).toInt();
  int get orderCount => (json['orderCount'] as num).toInt();
}

class InsightsTopProduct {
  InsightsTopProduct(this.json);
  final Map<String, dynamic> json;
  String get hotSaleId => json['hotSaleId'] as String;
  String get title => json['title'] as String;
  String get imageMimeType => json['imageMimeType'] as String;
  Uint8List get imageBytes => base64Decode(json['imageBase64'] as String);
  double get quantity => (json['quantity'] as num).toDouble();
  String get unit => json['unit'] as String;
  int get revenueCents => (json['revenueCents'] as num).toInt();
  double get shareOfTopRevenue => (json['shareOfTopRevenue'] as num).toDouble();
}

class InsightsFulfilmentSlice {
  InsightsFulfilmentSlice(this.json);
  final Map<String, dynamic> json;
  String get pickupType => json['pickupType'] as String;
  int get orderCount => (json['orderCount'] as num).toInt();
  double get percent => (json['percent'] as num).toDouble();
}

class InsightsBestDay {
  InsightsBestDay(this.json);
  final Map<String, dynamic> json;
  DateTime? get date =>
      json['date'] == null ? null : DateTime.parse(json['date'] as String);
  int get totalCents => (json['totalCents'] as num).toInt();
  int get orderCount => (json['orderCount'] as num).toInt();
}

class InsightsCustomerHighlights {
  InsightsCustomerHighlights(this.json);
  final Map<String, dynamic> json;
  int get newCustomers => (json['newCustomers'] as num).toInt();
  int get returningCustomers => (json['returningCustomers'] as num).toInt();
  double? get newCustomersChangePercent => (json['newCustomersChangePercent'] as num?)?.toDouble();
  double? get returningCustomersChangePercent =>
      (json['returningCustomersChangePercent'] as num?)?.toDouble();
}

class ProducerInsightsReport {
  ProducerInsightsReport(this.json);
  final Map<String, dynamic> json;
  InsightsSummary get summary => InsightsSummary(json['summary'] as Map<String, dynamic>);
  List<InsightsTrendPoint> get salesTrend => ((json['salesTrend'] as List<dynamic>?) ?? const [])
      .map((item) => InsightsTrendPoint(item as Map<String, dynamic>))
      .toList();
  List<InsightsTopProduct> get topProducts => ((json['topProducts'] as List<dynamic>?) ?? const [])
      .map((item) => InsightsTopProduct(item as Map<String, dynamic>))
      .toList();
  List<InsightsFulfilmentSlice> get fulfilment => ((json['fulfilment'] as List<dynamic>?) ?? const [])
      .map((item) => InsightsFulfilmentSlice(item as Map<String, dynamic>))
      .toList();
  InsightsBestDay get bestSalesDay => InsightsBestDay(json['bestSalesDay'] as Map<String, dynamic>);
  InsightsCustomerHighlights get customerHighlights =>
      InsightsCustomerHighlights(json['customerHighlights'] as Map<String, dynamic>);
}

// ---- networking ----

Future<String> _authToken() async {
  final token = await FirebaseAuth.instance.currentUser?.getIdToken();
  if (token == null) throw StateError('Please sign in again.');
  return token;
}

Future<Map<String, dynamic>> _send(String query, Map<String, dynamic> variables) async {
  final token = await _authToken();
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
      (errors!.first as Map<String, dynamic>)['message'] as String? ?? 'Insights request failed.',
    );
  }
  return (body['data'] as Map<String, dynamic>?) ?? const {};
}

// .toUtc() first: [InsightsRange.from]/[to] are local wall-clock instants
// (e.g. "midnight in the producer's own timezone"), and toIso8601String()
// on a local DateTime omits the offset — which the backend's Date scalar
// would then parse as *server* local time (UTC on Render), silently
// shifting the boundary. Converting to UTC first keeps it the same instant,
// just spelled unambiguously.
Map<String, dynamic> _rangeVariables(InsightsRange range) => {
  'range': {
    'from': range.from.toUtc().toIso8601String(),
    'to': range.to.toUtc().toIso8601String(),
  },
};

const _reportFields = '''
  summary {
    totalSalesCents totalSalesChangePercent
    completedOrders completedOrdersChangePercent
    quantitySold quantitySoldChangePercent
    averageOrderValueCents averageOrderValueChangePercent
  }
  salesTrend { date totalCents previousPeriodTotalCents orderCount }
  topProducts { hotSaleId title imageMimeType imageBase64 quantity unit revenueCents shareOfTopRevenue }
  fulfilment { pickupType orderCount percent }
  bestSalesDay { date totalCents orderCount }
  customerHighlights { newCustomers returningCustomers newCustomersChangePercent returningCustomersChangePercent }
''';

Future<ProducerInsightsReport> fetchProducerInsights(InsightsRange range) async {
  final data = await _send(
    'query(\$range: InsightsRangeInput!) { producerInsights(range: \$range) { $_reportFields } }',
    _rangeVariables(range),
  );
  return ProducerInsightsReport(data['producerInsights'] as Map<String, dynamic>);
}

Future<Uint8List> fetchInsightsReportPdf(InsightsRange range) async {
  final data = await _send(
    'query(\$range: InsightsRangeInput!) { producerInsightsReportPdf(range: \$range) }',
    _rangeVariables(range),
  );
  return base64Decode(data['producerInsightsReportPdf'] as String);
}

Future<Uint8List> fetchReceiptsPdf(InsightsRange range) async {
  final data = await _send(
    'query(\$range: InsightsRangeInput!) { producerReceiptsPdf(range: \$range) }',
    _rangeVariables(range),
  );
  return base64Decode(data['producerReceiptsPdf'] as String);
}
