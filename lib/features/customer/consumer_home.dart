import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart' hide Text;

import '../auth/backend_service.dart';
import '../../l10n/localized_text.dart';

const _green = Color(0xFF2F6B45);
const _ink = Color(0xFF1B2A20);
const _muted = Color(0xFF66735F);
const _line = Color(0xFFE7E5DB);
const _cream = Color(0xFFFBFAF5);

class ConsumerHomePage extends StatefulWidget {
  const ConsumerHomePage({
    required this.location,
    required this.onOpenExplore,
    super.key,
  });

  final ConfirmedLocation location;
  final VoidCallback onOpenExplore;

  @override
  State<ConsumerHomePage> createState() => _ConsumerHomePageState();
}

class _ConsumerHomePageState extends State<ConsumerHomePage> {
  late Future<List<_HomeSale>> _sales;
  String? _selectedCategory;
  String _search = '';

  @override
  void initState() {
    super.initState();
    _sales = _fetchNearbySales(widget.location);
  }

  void _retry() => setState(() => _sales = _fetchNearbySales(widget.location));

  void _toggleCategory(String key) {
    setState(() => _selectedCategory = _selectedCategory == key ? null : key);
  }

  void _openSaleDetails(_HomeSale sale) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _HomeSaleDetailsSheet(sale: sale),
    );
  }

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: _cream,
    child: SafeArea(
      bottom: false,
      child: FutureBuilder<List<_HomeSale>>(
        future: _sales,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return _HomeMessage(
              message: snapshot.error.toString().replaceFirst(
                'Bad state: ',
                '',
              ),
              onRetry: _retry,
            );
          }
          final sales = snapshot.data ?? const [];
          final query = _search.trim().toLowerCase();
          final hotSales =
              sales.where((sale) {
                if (_selectedCategory != null &&
                    !_matchesCategory(sale, _selectedCategory!)) {
                  return false;
                }
                if (query.isEmpty) return true;
                return sale.titleFor(context).toLowerCase().contains(query) ||
                    sale.farmName.toLowerCase().contains(query);
              }).toList();
          final followed = sales.where((sale) => sale.isFollowed).toList();
          final events = _upcomingEvents(sales);
          return ListView(
            padding: const EdgeInsets.fromLTRB(18, 10, 18, 30),
            children: [
              _HomeHeader(
                locationLabel: widget.location.city,
                onRefresh: _retry,
                onSearchChanged: (value) => setState(() => _search = value),
              ),
              const SizedBox(height: 18),
              SizedBox(
                height: 92,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _categories.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 14),
                  itemBuilder:
                      (_, index) => _CategoryCircle(
                        category: _categories[index],
                        selected: _selectedCategory == _categories[index].key,
                        onTap: () => _toggleCategory(_categories[index].key),
                      ),
                ),
              ),
              const SizedBox(height: 26),
              _SectionHeader(title: localizeText(context, 'Hot sales near you')),
              const SizedBox(height: 12),
              if (hotSales.isEmpty)
                _InlineEmptyNote(
                  text: localizeText(
                    context,
                    'No Hot Sales match right now.',
                  ),
                )
              else
                SizedBox(
                  height: 226,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: hotSales.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 12),
                    itemBuilder:
                        (_, index) => _HomeSaleCard(
                          sale: hotSales[index],
                          onTap: () => _openSaleDetails(hotSales[index]),
                        ),
                  ),
                ),
              const SizedBox(height: 26),
              _SectionHeader(
                title: localizeText(context, 'From farms you follow'),
              ),
              const SizedBox(height: 12),
              if (followed.isEmpty)
                _InlineEmptyNote(
                  text: localizeText(
                    context,
                    'Follow farms in Explore to see their Hot Sales here.',
                  ),
                  actionLabel: localizeText(context, 'Go to Explore'),
                  onAction: widget.onOpenExplore,
                )
              else
                SizedBox(
                  height: 226,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: followed.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 12),
                    itemBuilder:
                        (_, index) => _HomeSaleCard(
                          sale: followed[index],
                          onTap: () => _openSaleDetails(followed[index]),
                        ),
                  ),
                ),
              const SizedBox(height: 26),
              _SectionHeader(
                title: localizeText(context, 'Upcoming near you'),
              ),
              const SizedBox(height: 12),
              if (events.isEmpty)
                _InlineEmptyNote(
                  text: localizeText(
                    context,
                    'No upcoming pickups nearby yet.',
                  ),
                )
              else
                Column(
                  children: [
                    for (final event in events)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _HomeEventCard(event: event),
                      ),
                  ],
                ),
            ],
          );
        },
      ),
    ),
  );
}

// ---- data ----

class _HomeCategory {
  const _HomeCategory(this.key, this.label, this.icon);
  final String key;
  final String label;
  final IconData icon;
}

const _categories = [
  _HomeCategory('VEGETABLES', 'Vegetables', Icons.eco_outlined),
  _HomeCategory('MEAT', 'Meat', Icons.kebab_dining_outlined),
  _HomeCategory('EGGS', 'Eggs', Icons.egg_outlined),
  _HomeCategory('DAIRY', 'Dairy', Icons.icecream_outlined),
  _HomeCategory('HONEY', 'Honey', Icons.hive_outlined),
];

bool _matchesCategory(_HomeSale sale, String key) {
  final raw = sale.categoryKey?.toUpperCase().trim();
  if (raw == null || raw.isEmpty) return false;
  return raw == key || raw.contains(key) || key.contains(raw);
}

class _HomeSale {
  _HomeSale(this.json);
  final Map<String, dynamic> json;

  String get id => json['id'] as String;
  String get farmId => json['farmId'] as String;
  String? get categoryKey => json['categoryKey'] as String?;
  String get originalTitle => json['originalTitle'] as String;
  String get originalDescription => json['description'] as String;
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

  String get farmName => json['farmName'] as String;
  String? get farmProfilePhotoUrl => json['farmProfilePhotoUrl'] as String?;
  bool get isFollowed => json['isFollowed'] as bool? ?? false;
  double get distanceKm => (json['distanceKm'] as num).toDouble();
  int get priceCents => (json['priceCents'] as num).toInt();
  String get unit =>
      (json['customUnit'] as String?) ?? (json['unit'] as String).toLowerCase();
  String unitFor(BuildContext context) =>
      json['customUnit'] as String? ?? localizeText(context, unit);
  Uint8List get imageBytes => base64Decode(json['imageBase64'] as String);
  String priceFor(BuildContext context) =>
      '€${(priceCents / 100).toStringAsFixed(2)} / ${unitFor(context)}';
  List<_HomeRekoRing> get rekoRings =>
      ((json['rekoRings'] as List<dynamic>?) ?? const [])
          .map((ring) => _HomeRekoRing(ring as Map<String, dynamic>))
          .toList();
}

class _HomeRekoRing {
  const _HomeRekoRing(this.json);
  final Map<String, dynamic> json;
  String get id => json['id'] as String;
  String get name => json['name'] as String;
  String get municipality => json['municipality'] as String? ?? '';
  Map<String, dynamic>? get _schedule =>
      json['schedule'] as Map<String, dynamic>?;
  int? get weekday => _schedule?['weekday'] as int?;
  String? get startTime => _schedule?['startTime'] as String?;
  String? get endTime => _schedule?['endTime'] as String?;
}

class _HomeEvent {
  const _HomeEvent({
    required this.ringName,
    required this.municipality,
    required this.farmName,
    required this.occurrence,
    required this.startTime,
    required this.endTime,
  });
  final String ringName;
  final String municipality;
  final String farmName;
  final DateTime occurrence;
  final String startTime;
  final String endTime;

  String dayLabel() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(occurrence.year, occurrence.month, occurrence.day);
    final diff = day.difference(today).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Tomorrow';
    const names = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return names[occurrence.weekday - 1];
  }
}

DateTime? _nextOccurrence(int weekday, String startTime) {
  if (weekday < 1 || weekday > 7) return null;
  final parts = startTime.split(':');
  final hour = int.tryParse(parts.isNotEmpty ? parts[0] : '');
  if (hour == null) return null;
  final minute = parts.length > 1 ? (int.tryParse(parts[1]) ?? 0) : 0;
  final now = DateTime.now();
  final daysUntil = (weekday - now.weekday) % 7;
  var candidate = DateTime(
    now.year,
    now.month,
    now.day,
    hour,
    minute,
  ).add(Duration(days: daysUntil));
  if (candidate.isBefore(now)) candidate = candidate.add(const Duration(days: 7));
  return candidate;
}

// A REKO pickup ring is a shared, weekly-recurring pickup point that can
// serve several farms. We surface the next occurrence per ring (deduped by
// id) as the closest thing to a "farm event" the backend currently models.
List<_HomeEvent> _upcomingEvents(List<_HomeSale> sales) {
  final byRing = <String, _HomeEvent>{};
  for (final sale in sales) {
    for (final ring in sale.rekoRings) {
      if (byRing.containsKey(ring.id)) continue;
      final weekday = ring.weekday;
      final start = ring.startTime;
      if (weekday == null || start == null) continue;
      final occurrence = _nextOccurrence(weekday, start);
      if (occurrence == null) continue;
      byRing[ring.id] = _HomeEvent(
        ringName: ring.name,
        municipality: ring.municipality,
        farmName: sale.farmName,
        occurrence: occurrence,
        startTime: start,
        endTime: ring.endTime ?? '',
      );
    }
  }
  final events = byRing.values.toList()
    ..sort((a, b) => a.occurrence.compareTo(b.occurrence));
  return events.take(6).toList();
}

Future<List<_HomeSale>> _fetchNearbySales(ConfirmedLocation location) async {
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
      'variables': {
        'latitude': location.latitude,
        'longitude': location.longitude,
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
  final loaded = ((data?['nearbyHotSales'] as List<dynamic>?) ?? const [])
      .map((item) => _HomeSale(item as Map<String, dynamic>))
      .toList();
  loaded.sort((a, b) => a.distanceKm.compareTo(b.distanceKm));
  return loaded;
}

// ---- widgets ----

class _HomeHeader extends StatelessWidget {
  const _HomeHeader({
    required this.locationLabel,
    required this.onRefresh,
    required this.onSearchChanged,
  });
  final String locationLabel;
  final VoidCallback onRefresh;
  final ValueChanged<String> onSearchChanged;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          const Icon(Icons.location_on_rounded, color: _green, size: 20),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              locationLabel,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
            ),
          ),
          IconButton(
            tooltip: localizeText(context, 'Refresh'),
            onPressed: onRefresh,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      const SizedBox(height: 8),
      TextField(
        onChanged: onSearchChanged,
        decoration: InputDecoration(
          hintText: localizeText(context, 'Search Hot Sales'),
          prefixIcon: const Icon(Icons.search_rounded),
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(vertical: 14),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    ],
  );
}

class _CategoryCircle extends StatelessWidget {
  const _CategoryCircle({
    required this.category,
    required this.selected,
    required this.onTap,
  });
  final _HomeCategory category;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(18),
    child: SizedBox(
      width: 66,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 58,
            height: 58,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: selected ? _green : Colors.white,
              shape: BoxShape.circle,
              border: Border.all(
                color: selected ? _green : _line,
                width: selected ? 0 : 1,
              ),
              boxShadow:
                  selected
                      ? null
                      : const [
                        BoxShadow(
                          color: Colors.black12,
                          blurRadius: 6,
                          offset: Offset(0, 2),
                        ),
                      ],
            ),
            child: Icon(
              category.icon,
              color: selected ? Colors.white : _green,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            category.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: selected ? _green : _ink,
            ),
          ),
        ],
      ),
    ),
  );
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});
  final String title;
  @override
  Widget build(BuildContext context) => Text(
    title,
    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: _ink),
  );
}

class _InlineEmptyNote extends StatelessWidget {
  const _InlineEmptyNote({required this.text, this.actionLabel, this.onAction});
  final String text;
  final String? actionLabel;
  final VoidCallback? onAction;

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
        Text(text, style: const TextStyle(color: _muted)),
        if (actionLabel != null && onAction != null) ...[
          const SizedBox(height: 8),
          TextButton(
            onPressed: onAction,
            style: TextButton.styleFrom(padding: EdgeInsets.zero),
            child: Text(actionLabel!),
          ),
        ],
      ],
    ),
  );
}

class _PricePill extends StatelessWidget {
  const _PricePill({required this.text});
  final String text;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: .94),
      borderRadius: BorderRadius.circular(99),
    ),
    child: Text(
      text,
      style: const TextStyle(color: _green, fontSize: 10.5, fontWeight: FontWeight.w900),
    ),
  );
}

class _HomeSaleCard extends StatelessWidget {
  const _HomeSaleCard({required this.sale, required this.onTap});
  final _HomeSale sale;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(20),
    child: Container(
      width: 168,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(15),
            child: Stack(
              children: [
                Image.memory(
                  sale.imageBytes,
                  height: 108,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
                Positioned(
                  left: 7,
                  bottom: 7,
                  child: _PricePill(text: sale.priceFor(context)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 9),
          Text(
            sale.titleFor(context),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              const Icon(Icons.storefront_rounded, size: 13, color: _green),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  sale.farmName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _green,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 3),
          Text(
            '${sale.distanceKm.toStringAsFixed(1)} km away',
            style: const TextStyle(color: _muted, fontSize: 11.5),
          ),
        ],
      ),
    ),
  );
}

class _HomeEventCard extends StatelessWidget {
  const _HomeEventCard({required this.event});
  final _HomeEvent event;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: _line),
    ),
    child: Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            color: const Color(0xFFE6F0E1),
            borderRadius: BorderRadius.circular(99),
          ),
          child: Text(
            '${event.dayLabel()} ${event.startTime}'
            '${event.endTime.isNotEmpty ? '–${event.endTime}' : ''}',
            style: const TextStyle(
              color: _green,
              fontWeight: FontWeight.w800,
              fontSize: 12,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                event.ringName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              Text(
                [
                  event.farmName,
                  if (event.municipality.isNotEmpty) event.municipality,
                ].join(' • '),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: _muted, fontSize: 12),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _HomeMessage extends StatelessWidget {
  const _HomeMessage({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.cloud_off_outlined, size: 40, color: _green),
          const SizedBox(height: 12),
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Try again'),
          ),
        ],
      ),
    ),
  );
}

class _HomeSaleDetailsSheet extends StatelessWidget {
  const _HomeSaleDetailsSheet({required this.sale});
  final _HomeSale sale;

  @override
  Widget build(BuildContext context) => FractionallySizedBox(
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
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 30),
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: Image.memory(
                    sale.imageBytes,
                    height: 220,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        sale.titleFor(context),
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    Text(
                      sale.priceFor(context),
                      style: const TextStyle(
                        color: _green,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  '${sale.farmName} • ${sale.distanceKm.toStringAsFixed(1)} km away',
                  style: const TextStyle(color: _muted),
                ),
                const SizedBox(height: 16),
                Text(
                  sale.descriptionFor(context),
                  style: const TextStyle(height: 1.5),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}
