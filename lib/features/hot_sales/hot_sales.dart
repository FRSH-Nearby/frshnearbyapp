// ignore_for_file: curly_braces_in_flow_control_structures

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../config/api_config.dart';
import '../../l10n/localized_text.dart' show localizeText;
import '../notifications/device_installation_store.dart';

const _green = Color(0xFF2F6B45);
const _ink = Color(0xFF1B2A20);
const _muted = Color(0xFF66735F);
const _surface = Color(0xFFF1F6ED);
const _saleFields =
    'id categoryKey originalLanguage detectedLanguage originalTitle description productionDetail unit customUnit quantityStep priceCents quantity producedAt availableAtFarm status imageName imageMimeType imageBase64 translations { locale title description productionDetail status provider model } rekoRings { id name municipality regionName }';

// Decoding is otherwise repeated (and reallocated) on every rebuild of the
// list, which made Image.memory treat unchanged photos as new images and
// re-flash them whenever any single card's quantity/availability changed.
final _decodedImageCache = <String, Uint8List>{};

class _Ring {
  const _Ring({
    required this.id,
    required this.name,
    required this.region,
    required this.municipality,
    required this.address,
    required this.priority,
    required this.schedule,
  });
  final String id;
  final String name;
  final String region;
  final String municipality;
  final String address;
  final int priority;
  final String schedule;

  factory _Ring.fromJson(Map<String, dynamic> json) {
    final raw = json['schedule'] as Map<String, dynamic>?;
    final schedule =
        raw == null
            ? ''
            : '${raw['frequency'] == 'BIWEEKLY' ? 'Every other week' : 'Every week'} · ${_weekday(raw['weekday'] as int? ?? 1)} ${raw['startTime']}–${raw['endTime']}';
    return _Ring(
      id: json['id'] as String,
      name: json['name'] as String,
      region: json['regionName'] as String? ?? '',
      municipality: json['municipality'] as String,
      address: [
        json['addressLine'],
        json['postalCode'],
      ].whereType<String>().where((v) => v.isNotEmpty).join(', '),
      priority: json['priority'] as int? ?? 2,
      schedule: schedule,
    );
  }
}

String _weekday(int value) =>
    const [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ][value.clamp(1, 7) - 1];

String _scheduleLabel(BuildContext context, String schedule) {
  if (schedule.isEmpty) return '';
  final parts = schedule.split(' · ');
  if (parts.length != 2) return schedule;
  final time = parts[1].split(' ');
  if (time.length < 2) return schedule;
  return '${localizeText(context, parts[0])} · '
      '${localizeText(context, time.first)} ${time.skip(1).join(' ')}';
}

class _Sale {
  const _Sale(this.json);
  final Map<String, dynamic> json;
  String get id => json['id'] as String;
  String get originalTitle => json['originalTitle'] as String;
  String get originalDescription => json['description'] as String;
  String get originalLanguage =>
      json['detectedLanguage'] as String? ?? json['originalLanguage'] as String;
  Map<String, dynamic>? translation(String locale) =>
      (json['translations'] as List<dynamic>)
          .cast<Map<String, dynamic>>()
          .where(
            (item) => item['locale'] == locale && item['status'] == 'COMPLETED',
          )
          .firstOrNull;
  String title(String locale) =>
      translation(locale)?['title'] as String? ?? originalTitle;
  String description(String locale) =>
      translation(locale)?['description'] as String? ?? originalDescription;
  bool isTranslated(String locale) =>
      locale != originalLanguage && translation(locale) != null;
  double get quantity => (json['quantity'] as num).toDouble();
  int get priceCents => json['priceCents'] as int;
  String get unit => json['unit'] as String;
  String? get customUnit => json['customUnit'] as String?;
  double get quantityStep =>
      (json['quantityStep'] as num?)?.toDouble() ??
      _defaultQuantityStep(unit);
  String? get productionDetail => json['productionDetail'] as String?;
  bool get availableAtFarm => json['availableAtFarm'] as bool;
  String get status => json['status'] as String;
  String get imageName => json['imageName'] as String;
  String get imageMimeType => json['imageMimeType'] as String;
  List<String> get rekoRingIds =>
      (json['rekoRings'] as List<dynamic>)
          .map((ring) => (ring as Map<String, dynamic>)['id'] as String)
          .toList();
  Uint8List get image {
    final base64 = json['imageBase64'] as String;
    return _decodedImageCache.putIfAbsent(base64, () => base64Decode(base64));
  }

  _Sale changed({double? quantity, String? status}) => _Sale({
    ...json,
    if (quantity != null) 'quantity': quantity,
    if (status != null) 'status': status,
  });
}

class _HotSalesApi {
  _HotSalesApi()
    : _dio = Dio(
        BaseOptions(
          baseUrl: ApiConfig.graphqlUrl,
          connectTimeout: const Duration(seconds: 20),
          receiveTimeout: const Duration(seconds: 45),
        ),
      );
  final Dio _dio;
  final DeviceInstallationStore _installations = DeviceInstallationStore();

  Future<Map<String, dynamic>> send(
    String query, [
    Map<String, dynamic> variables = const {},
  ]) async {
    final token = await FirebaseAuth.instance.currentUser?.getIdToken();
    if (token == null) throw StateError('Please sign in again.');
    final response = await _dio.post<Map<String, dynamic>>(
      '',
      data: {'query': query, 'variables': variables},
      options: Options(
        headers: {
          'authorization': 'Bearer $token',
          'x-frsh-installation-id': await _installations.id(),
        },
        validateStatus: (_) => true,
      ),
    );
    final body = response.data ?? const {};
    final errors = body['errors'] as List<dynamic>?;
    if (errors?.isNotEmpty == true)
      throw StateError(
        (errors!.first as Map<String, dynamic>)['message'] as String? ??
            'Server request failed.',
      );
    final status = response.statusCode ?? 0;
    if (status < 200 || status >= 300) {
      throw StateError('Server rejected the request (HTTP $status).');
    }
    return body['data'] as Map<String, dynamic>;
  }

  Future<List<_Sale>> sales() async {
    Map<String, dynamic> data;
    try {
      data = await send('query { myHotSales { $_saleFields } }');
    } on StateError catch (error) {
      final message = error.message.toString();
      if (!message.contains('customUnit') &&
          !message.contains('quantityStep')) {
        rethrow;
      }
      // Keep the listing usable while a newly deployed API field is rolling out.
      data = await send(
        'query { myHotSales { ${_saleFields.replaceFirst('customUnit ', '').replaceFirst('quantityStep ', '')} } }',
      );
    }
    return (data['myHotSales'] as List<dynamic>)
        .map((v) => _Sale(v as Map<String, dynamic>))
        .toList();
  }

  Future<List<_Ring>> rings() async {
    final data = await send(
      'query { availableRekoRings { id name regionName municipality addressLine postalCode priority schedule { frequency weekday startTime endTime timezone } } }',
    );
    return (data['availableRekoRings'] as List<dynamic>)
        .map((v) => _Ring.fromJson(v as Map<String, dynamic>))
        .toList();
  }

  Future<_Sale> create(Map<String, dynamic> input) async {
    final data = await send(
      'mutation(\$input: CreateHotSaleInput!) { createHotSale(input: \$input) { $_saleFields } }',
      {'input': input},
    );
    return _Sale(data['createHotSale'] as Map<String, dynamic>);
  }

  Future<_Sale> update(Map<String, dynamic> input) async {
    final data = await send(
      'mutation(\$input: UpdateHotSaleInput!) { updateHotSale(input: \$input) { $_saleFields } }',
      {'input': input},
    );
    return _Sale(data['updateHotSale'] as Map<String, dynamic>);
  }
  Future<void> quantity(String id, double value) => send(
    'mutation(\$input: HotSaleQuantityInput!) { setHotSaleQuantity(input: \$input) { id } }',
    {
      'input': {'id': id, 'quantity': value},
    },
  );
  Future<void> availability(String id, bool available) => send(
    'mutation(\$input: HotSaleAvailabilityInput!) { setHotSaleAvailability(input: \$input) { id } }',
    {
      'input': {'id': id, 'available': available},
    },
  );
  Future<void> archive(String id) =>
      send('mutation(\$id: String!) { archiveHotSale(id: \$id) }', {'id': id});
}

class HotSalesScreen extends StatefulWidget {
  const HotSalesScreen({super.key});
  @override
  State<HotSalesScreen> createState() => _HotSalesScreenState();
}

class _HotSalesScreenState extends State<HotSalesScreen> {
  final _api = _HotSalesApi();
  late Future<List<_Sale>> _sales = _api.sales();

  @override
  Widget build(BuildContext context) {
    final language = Localizations.localeOf(context).languageCode;
    return Scaffold(
      backgroundColor: _surface,
      appBar: AppBar(
        backgroundColor: _surface,
        title: Text(localizeText(context, 'Hot Sales')),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: FilledButton.icon(
              onPressed: _add,
              icon: const Icon(Icons.add_rounded),
              label: Text(localizeText(context, 'Add product')),
            ),
          ),
        ],
      ),
      body: FutureBuilder<List<_Sale>>(
        future: _sales,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done)
            return const Center(child: CircularProgressIndicator());
          if (snapshot.hasError)
            return _Message(
              icon: Icons.cloud_off_outlined,
              text:
                  '${localizeText(context, 'Could not load Hot Sales')}\n${snapshot.error}',
            );
          final sales = snapshot.data ?? const [];
          if (sales.isEmpty)
            return _Message(
              icon: Icons.local_offer_outlined,
              text: localizeText(
                context,
                'Add your first seasonal product for nearby customers.',
              ),
            );
          return ListView.separated(
            padding: const EdgeInsets.all(14),
            itemCount: sales.length,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder:
                (_, index) => _SaleCard(
                  sale: sales[index],
                  language: language,
                  onChanged: (value) async {
                    await _api.quantity(sales[index].id, value);
                    if (mounted) {
                      setState(() {
                        _sales = _api.sales();
                      });
                    }
                  },
                  onEdit: () => _edit(sales[index]),
                  onDelete: () => _delete(sales[index]),
                  onAvailabilityChanged: (available) async {
                    await _api.availability(sales[index].id, available);
                    if (mounted) {
                      setState(() {
                        _sales = _api.sales();
                      });
                    }
                  },
                ),
          );
        },
      ),
    );
  }

  Future<void> _add() async {
    final saved = await Navigator.of(context).push<_Sale>(
      MaterialPageRoute(builder: (_) => _CreateHotSaleScreen(api: _api)),
    );
    if (saved != null && mounted) {
      setState(() {
        _sales = _api.sales();
      });
    }
  }

  Future<void> _edit(_Sale sale) async {
    final saved = await Navigator.of(context).push<_Sale>(
      MaterialPageRoute(
        builder: (_) => _CreateHotSaleScreen(api: _api, sale: sale),
      ),
    );
    if (saved != null && mounted) {
      setState(() {
        _sales = _api.sales();
      });
    }
  }

  Future<void> _delete(_Sale sale) async {
    final confirmed = await _confirmDelete(context, sale);
    if (!confirmed) return;
    await _api.archive(sale.id);
    if (mounted) {
      setState(() {
        _sales = _api.sales();
      });
    }
  }
}

class HotSalesDashboardSection extends StatefulWidget {
  const HotSalesDashboardSection({super.key});

  @override
  State<HotSalesDashboardSection> createState() =>
      _HotSalesDashboardSectionState();
}

class _HotSalesDashboardSectionState extends State<HotSalesDashboardSection> {
  final _api = _HotSalesApi();
  List<_Sale> _visibleSales = const [];
  final Map<String, Timer> _quantityTimers = {};
  final Map<String, double> _pendingQuantities = {};
  final Map<String, Timer> _availabilityTimers = {};
  final Map<String, bool> _pendingAvailability = {};
  bool _loading = true;
  Object? _loadError;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final timer in _quantityTimers.values) {
      timer.cancel();
    }
    for (final timer in _availabilityTimers.values) {
      timer.cancel();
    }
    for (final entry in _pendingQuantities.entries) {
      _api.quantity(entry.key, entry.value);
    }
    for (final entry in _pendingAvailability.entries) {
      _api.availability(entry.key, entry.value);
    }
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final sales = await _api.sales();
      if (!mounted) return;
      setState(() {
        _visibleSales = sales;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loadError = error;
        _loading = false;
      });
    }
  }

  void _showImmediately(_Sale changed) {
    final updated = [
      changed,
      ..._visibleSales.where((sale) => sale.id != changed.id),
    ];
    setState(() {
      _visibleSales = updated;
    });
    _refreshSilently();
  }

  Future<void> _refreshSilently() async {
    try {
      final fresh = await _api.sales();
      if (!mounted) return;
      setState(() {
        _visibleSales = fresh;
      });
    } catch (_) {
      // The confirmed mutation is already visible; retry on the next action.
    }
  }

  Future<void> _add() async {
    final saved = await Navigator.of(context).push<_Sale>(
      MaterialPageRoute(builder: (_) => _CreateHotSaleScreen(api: _api)),
    );
    if (saved != null && mounted) _showImmediately(saved);
  }

  Future<void> _edit(_Sale sale) async {
    final saved = await Navigator.of(context).push<_Sale>(
      MaterialPageRoute(
        builder: (_) => _CreateHotSaleScreen(api: _api, sale: sale),
      ),
    );
    if (saved != null && mounted) _showImmediately(saved);
  }

  Future<void> _delete(_Sale sale) async {
    if (!await _confirmDelete(context, sale)) return;
    final before = _visibleSales;
    _setVisible(before.where((item) => item.id != sale.id).toList());
    try {
      await _api.archive(sale.id);
    } catch (error) {
      if (mounted) {
        _setVisible(before);
        _showError(context, error);
      }
    }
  }

  void _changeQuantity(_Sale sale, double value) {
    final status =
        sale.status == 'PAUSED'
            ? 'PAUSED'
            : value == 0
            ? 'SOLD_OUT'
            : 'ACTIVE';
    _replaceVisible(sale.changed(quantity: value, status: status));

    _quantityTimers[sale.id]?.cancel();
    _pendingQuantities[sale.id] = value;
    _quantityTimers[sale.id] = Timer(const Duration(seconds: 1), () async {
      try {
        await _api.quantity(sale.id, value);
        if (_pendingQuantities[sale.id] == value) {
          _pendingQuantities.remove(sale.id);
        }
      } catch (error) {
        if (_pendingQuantities[sale.id] == value) {
          _pendingQuantities.remove(sale.id);
        }
        if (mounted) {
          _showError(context, error);
          _refreshSilently();
        }
      } finally {
        if (_pendingQuantities[sale.id] == value ||
            !_pendingQuantities.containsKey(sale.id)) {
          _quantityTimers.remove(sale.id);
        }
      }
    });
  }

  Future<void> _enterExactQuantity(_Sale sale) async {
    final controller = TextEditingController(
      text: _formatQuantity(sale.quantity),
    );
    final value = await showDialog<double>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text(localizeText(context, 'Set exact quantity')),
            content: TextField(
              controller: controller,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: InputDecoration(
                suffixText:
                    sale.unit == 'OTHER'
                        ? sale.customUnit
                        : _unitLabel(context, sale.unit),
                helperText: localizeText(
                  context,
                  'Decimals are allowed for weight and liquid.',
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(localizeText(context, 'Cancel')),
              ),
              FilledButton(
                onPressed: () {
                  final parsed = double.tryParse(
                    controller.text.trim().replaceAll(',', '.'),
                  );
                  if (parsed == null || parsed < 0) return;
                  Navigator.pop(context, _cleanQuantity(parsed));
                },
                child: Text(localizeText(context, 'Save')),
              ),
            ],
          ),
    );
    controller.dispose();
    if (value != null && mounted) _changeQuantity(sale, value);
  }

  void _changeAvailability(_Sale sale, bool available) {
    _replaceVisible(
      sale.changed(
        status:
            available
                ? sale.quantity == 0
                    ? 'SOLD_OUT'
                    : 'ACTIVE'
                : 'PAUSED',
      ),
    );

    _availabilityTimers[sale.id]?.cancel();
    _pendingAvailability[sale.id] = available;
    _availabilityTimers[sale.id] = Timer(
      const Duration(seconds: 1),
      () async {
        try {
          await _api.availability(sale.id, available);
          if (_pendingAvailability[sale.id] == available) {
            _pendingAvailability.remove(sale.id);
          }
        } catch (error) {
          if (_pendingAvailability[sale.id] == available) {
            _pendingAvailability.remove(sale.id);
          }
          if (mounted) {
            _showError(context, error);
            _refreshSilently();
          }
        } finally {
          if (_pendingAvailability[sale.id] == available ||
              !_pendingAvailability.containsKey(sale.id)) {
            _availabilityTimers.remove(sale.id);
          }
        }
      }
    );
  }

  void _replaceVisible(_Sale changed) {
    _setVisible(
      _visibleSales
          .map((sale) => sale.id == changed.id ? changed : sale)
          .toList(),
    );
  }

  void _setVisible(List<_Sale> sales) {
    setState(() {
      _visibleSales = sales;
    });
  }

  @override
  Widget build(BuildContext context) {
    final language = Localizations.localeOf(context).languageCode;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                localizeText(context, 'Hot Sales'),
                style: const TextStyle(
                  color: _ink,
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            FilledButton.icon(
              onPressed: _add,
              icon: const Icon(Icons.add_rounded),
              label: Text(localizeText(context, 'Add product')),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (_loading && _visibleSales.isEmpty)
          const _HotSalesSkeleton()
        else if (_loadError != null && _visibleSales.isEmpty)
          _InlineMessage(
            icon: Icons.cloud_off_outlined,
            text: localizeText(context, 'Could not load Hot Sales'),
            actionLabel: localizeText(context, 'Try again'),
            onAction: _load,
          )
        else if (_visibleSales.isEmpty)
          _InlineMessage(
            icon: Icons.local_offer_outlined,
            text: localizeText(
              context,
              'No products yet. Add your first seasonal product.',
            ),
          )
        else
          Column(
            children: [
              for (var index = 0; index < _visibleSales.length; index++) ...[
                if (index > 0) const SizedBox(height: 12),
                _SaleCard(
                  sale: _visibleSales[index],
                  language: language,
                  onChanged:
                      (value) =>
                          _changeQuantity(_visibleSales[index], value),
                  onExactQuantity:
                      () => _enterExactQuantity(_visibleSales[index]),
                  onEdit: () => _edit(_visibleSales[index]),
                  onDelete: () => _delete(_visibleSales[index]),
                  onAvailabilityChanged:
                      (available) => _changeAvailability(
                        _visibleSales[index],
                        available,
                      ),
                ),
              ],
            ],
          ),
      ],
    );
  }
}

class _SaleCard extends StatelessWidget {
  const _SaleCard({
    required this.sale,
    required this.language,
    required this.onChanged,
    this.onExactQuantity,
    required this.onEdit,
    required this.onDelete,
    required this.onAvailabilityChanged,
  });
  final _Sale sale;
  final String language;
  final ValueChanged<double> onChanged;
  final VoidCallback? onExactQuantity;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final ValueChanged<bool> onAvailabilityChanged;

  @override
  Widget build(BuildContext context) {
    final unit =
        sale.unit == 'OTHER' && sale.customUnit?.trim().isNotEmpty == true
            ? sale.customUnit!.trim()
            : _unitLabel(context, sale.unit);
    final isPaused = sale.status == 'PAUSED';
    final isSoldOut =
        !isPaused && (sale.status == 'SOLD_OUT' || sale.quantity == 0);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isPaused ? const Color(0xFFF6F7F3) : Colors.white,
        border: Border.all(
          color: isPaused ? const Color(0xFFE2E7DD) : const Color(0xFFDCE6D6),
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow:
            isPaused
                ? null
                : const [
                  BoxShadow(
                    color: Color(0x0F1B2A20),
                    blurRadius: 18,
                    offset: Offset(0, 8),
                  ),
                ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: SizedBox(
                  width: 88,
                  height: 88,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.memory(sale.image, fit: BoxFit.cover),
                      if (isPaused)
                        Container(
                          color: Colors.white.withValues(alpha: .55),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            sale.title(language),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 16.5,
                              fontWeight: FontWeight.w800,
                              color: isPaused ? _muted : _ink,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        _statusPill(context, isPaused, isSoldOut),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '€${(sale.priceCents / 100).toStringAsFixed(2)} / $unit',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: isPaused ? _muted : _green,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      sale.description(language),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: _muted, height: 1.35),
                    ),
                    if (sale.isTranslated(language))
                      TextButton(
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.zero,
                          minimumSize: const Size(0, 30),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        onPressed:
                            () => showDialog<void>(
                              context: context,
                              builder:
                                  (context) => AlertDialog(
                                    title: Text(
                                      localizeText(context, 'Original text'),
                                    ),
                                    content: Text(
                                      '${sale.originalTitle}\n\n${sale.originalDescription}',
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.pop(context),
                                        child: Text(
                                          localizeText(context, 'Close'),
                                        ),
                                      ),
                                    ],
                                  ),
                            ),
                        child: Text(
                          '${localizeText(context, 'AI translated from')} ${sale.originalLanguage.toUpperCase()} · ${localizeText(context, 'See original')}',
                        ),
                      ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert_rounded, color: _muted),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                onSelected: (value) {
                  if (value == 'edit') onEdit();
                  if (value == 'delete') onDelete();
                },
                itemBuilder:
                    (context) => [
                      PopupMenuItem(
                        value: 'edit',
                        child: ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.edit_outlined),
                          title: Text(localizeText(context, 'Edit')),
                        ),
                      ),
                      PopupMenuItem(
                        value: 'delete',
                        child: ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(
                            Icons.delete_outline,
                            color: Colors.red,
                          ),
                          title: Text(
                            localizeText(context, 'Delete'),
                            style: const TextStyle(color: Colors.red),
                          ),
                        ),
                      ),
                    ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: isPaused
                  ? const Color(0xFFEFF0EC)
                  : const Color(0xFFF3F7EF),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Icon(
                        isPaused
                            ? Icons.visibility_off_rounded
                            : Icons.visibility_rounded,
                        size: 19,
                        color: isPaused ? _muted : _green,
                      ),
                      const SizedBox(width: 9),
                      Expanded(
                        child: Text(
                          localizeText(
                            context,
                            isPaused
                                ? 'Hidden from customers'
                                : 'Visible to customers',
                          ),
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                            color: isPaused ? _muted : _ink,
                          ),
                        ),
                      ),
                      Switch.adaptive(
                        value: !isPaused,
                        activeColor: _green,
                        onChanged: onAvailabilityChanged,
                      ),
                    ],
                  ),
                ),
                Container(height: 1, color: const Color(0xFFE3EADD)),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          localizeText(context, 'Quantity'),
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      _quantityStepper(context, unit),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusPill(BuildContext context, bool isPaused, bool isSoldOut) {
    final (Color bg, Color fg, String label) =
        isPaused
            ? (const Color(0xFFE7E7E1), _muted, 'Unavailable')
            : isSoldOut
            ? (const Color(0xFFFCE7B8), const Color(0xFF6B4A00), 'Sold out')
            : (const Color(0xFFDDEBD7), _green, 'Available');
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        localizeText(context, label),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: fg,
          letterSpacing: .2,
        ),
      ),
    );
  }

  Widget _quantityStepper(BuildContext context, String unit) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFD3DECE)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _stepButton(
            icon: Icons.remove_rounded,
            onTap:
                sale.quantity > 0
                    ? () => onChanged(
                      _cleanQuantity(
                        (sale.quantity - sale.quantityStep).clamp(
                          0,
                          double.infinity,
                        ),
                      ),
                    )
                    : null,
          ),
          InkWell(
            onTap: onExactQuantity,
            borderRadius: BorderRadius.circular(8),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 62),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 9),
                child: Text(
                  '${_formatQuantity(sale.quantity)} $unit',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    color: _ink,
                  ),
                ),
              ),
            ),
          ),
          _stepButton(
            icon: Icons.add_rounded,
            onTap:
                () => onChanged(
                  _cleanQuantity(sale.quantity + sale.quantityStep),
                ),
          ),
        ],
      ),
    );
  }

  Widget _stepButton({required IconData icon, VoidCallback? onTap}) {
    final enabled = onTap != null;
    return Material(
      color: Colors.transparent,
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(9),
          child: Icon(
            icon,
            size: 20,
            color: enabled ? _green : const Color(0xFFB7C1B2),
          ),
        ),
      ),
    );
  }
}

class _CreateHotSaleScreen extends StatefulWidget {
  const _CreateHotSaleScreen({required this.api, this.sale});
  final _HotSalesApi api;
  final _Sale? sale;
  @override
  State<_CreateHotSaleScreen> createState() => _CreateHotSaleScreenState();
}

class _CreateHotSaleScreenState extends State<_CreateHotSaleScreen> {
  final _form = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _description = TextEditingController();
  final _production = TextEditingController();
  final _quantity = TextEditingController();
  final _price = TextEditingController();
  final _customUnit = TextEditingController();
  final _quantityStep = TextEditingController(text: '1');
  final _search = TextEditingController();
  String _unit = 'KILOGRAM';
  bool _farm = true;
  XFile? _photo;
  Uint8List? _photoBytes;
  bool _saving = false;
  late final Future<List<_Ring>> _rings = widget.api.rings();
  final Set<String> _ringIds = {};

  @override
  void initState() {
    super.initState();
    final sale = widget.sale;
    if (sale == null) return;
    _title.text = sale.originalTitle;
    _description.text = sale.originalDescription;
    _production.text = sale.productionDetail ?? '';
    _quantity.text = sale.quantity.toString();
    _price.text = (sale.priceCents / 100).toStringAsFixed(2);
    _unit = sale.unit;
    _customUnit.text = sale.customUnit ?? '';
    _quantityStep.text = _formatQuantity(sale.quantityStep);
    _farm = sale.availableAtFarm;
    _photoBytes = sale.image;
    _ringIds.addAll(sale.rekoRingIds);
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _production.dispose();
    _quantity.dispose();
    _price.dispose();
    _customUnit.dispose();
    _quantityStep.dispose();
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _surface,
      appBar: AppBar(
        backgroundColor: _surface,
        title: Text(
          localizeText(
            context,
            widget.sale == null ? 'Add Hot Sale' : 'Edit Hot Sale',
          ),
        ),
      ),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 36),
          children: [
            _section(
              context,
              'Product',
              'Choose what customers will see on your farm page.',
            ),
            TextFormField(
              controller: _title,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                labelText: localizeText(context, 'Product name'),
                hintText: localizeText(
                  context,
                  'For example: Fresh new potatoes',
                ),
                prefixIcon: const Icon(Icons.eco_outlined),
              ),
              validator:
                  (value) =>
                      (value?.trim().length ?? 0) < 2
                          ? localizeText(context, 'Enter a product name.')
                          : null,
            ),
            const SizedBox(height: 22),
            _section(
              context,
              'Stock and price',
              'Tell us how much is available and how you sell it.',
            ),
            DropdownButtonFormField<String>(
              value: _unit,
              decoration: InputDecoration(
                labelText: localizeText(context, 'How do you sell it?'),
                prefixIcon: const Icon(Icons.scale_outlined),
              ),
              items:
                  const [
                        'KILOGRAM',
                        'GRAM',
                        'LITRE',
                        'PIECE',
                        'BUNCH',
                        'BOX',
                        'DOZEN',
                        'OTHER',
                      ]
                      .map(
                        (u) => DropdownMenuItem(
                          value: u,
                          child: Text(_unitChoiceLabel(context, u)),
                        ),
                      )
                      .toList(),
              onChanged:
                  (value) => setState(() {
                    _unit = value!;
                    _quantityStep.text = _formatQuantity(
                      _defaultQuantityStep(_unit),
                    );
                  }),
            ),
            if (_unit == 'OTHER') ...[
              const SizedBox(height: 12),
              TextFormField(
                controller: _customUnit,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  labelText: localizeText(context, 'Custom selling unit'),
                  hintText: localizeText(
                    context,
                    'For example: bag, tray, jar, or 5 kg box',
                  ),
                  prefixIcon: const Icon(Icons.edit_outlined),
                ),
                onChanged: (_) => setState(() {}),
                validator:
                    (value) =>
                        (value?.trim().isEmpty ?? true)
                            ? localizeText(context, 'Enter your selling unit.')
                            : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _quantityStep,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(
                  labelText: localizeText(context, 'Quantity button step'),
                  helperText: localizeText(
                    context,
                    'Amount added or removed with each + or − tap.',
                  ),
                  prefixIcon: const Icon(Icons.exposure_outlined),
                ),
                validator: _positive,
              ),
            ],
            const SizedBox(height: 12),
            TextFormField(
              controller: _quantity,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: InputDecoration(
                labelText: localizeText(context, 'Quantity available'),
                helperText: localizeText(
                  context,
                  'Enter how many selected units are available.',
                ),
                prefixIcon: const Icon(Icons.inventory_2_outlined),
              ),
              validator: _positive,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _price,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: InputDecoration(
                labelText:
                    '${localizeText(context, 'Price per')} '
                    '${_unit == 'OTHER' ? (_customUnit.text.trim().isEmpty ? localizeText(context, 'custom unit') : _customUnit.text.trim()) : _unitLabel(context, _unit)}',
                prefixText: '€ ',
              ),
              validator: _positive,
            ),
            const SizedBox(height: 22),
            _section(
              context,
              'Product details',
              'A clear description helps customers decide.',
            ),
            TextFormField(
              controller: _description,
              maxLines: 4,
              decoration: InputDecoration(
                labelText: localizeText(context, 'Description'),
              ),
              validator:
                  (value) =>
                      (value?.trim().length ?? 0) < 3
                          ? localizeText(context, 'Add a short description.')
                          : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _production,
              decoration: InputDecoration(
                labelText: localizeText(
                  context,
                  'Production details (optional)',
                ),
                prefixIcon: const Icon(Icons.info_outline),
              ),
            ),
            const SizedBox(height: 16),
            _photoPicker(),
            const SizedBox(height: 22),
            _section(
              context,
              'Available from',
              'Choose farm pickup, one or more REKO rings, or both.',
            ),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: Text(localizeText(context, 'At the farm')),
              subtitle: Text(
                localizeText(
                  context,
                  'Customers collect from your registered farm address.',
                ),
              ),
              value: _farm,
              onChanged: (value) => setState(() => _farm = value),
            ),
            FutureBuilder<List<_Ring>>(
              future: _rings,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done)
                  return const Padding(
                    padding: EdgeInsets.all(18),
                    child: Center(child: CircularProgressIndicator()),
                  );
                if (snapshot.hasError)
                  return Text(
                    '${localizeText(context, 'Could not load REKO rings')}: ${snapshot.error}',
                  );
                final rings = snapshot.data ?? const [];
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: _search,
                      decoration: InputDecoration(
                        labelText: localizeText(
                          context,
                          'Search REKO rings across Finland',
                        ),
                        prefixIcon: const Icon(Icons.search),
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: 10),
                    if (_ringIds.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Wrap(
                          spacing: 7,
                          runSpacing: 7,
                          children:
                              rings
                                  .where((ring) => _ringIds.contains(ring.id))
                                  .map(
                                    (ring) => InputChip(
                                      avatar: const Icon(
                                        Icons.location_on_outlined,
                                        size: 17,
                                      ),
                                      label: Text(ring.name),
                                      onPressed: () => _showRing(ring),
                                      onDeleted:
                                          () => setState(
                                            () => _ringIds.remove(ring.id),
                                          ),
                                    ),
                                  )
                                  .toList(),
                        ),
                      ),
                    if (rings.any((ring) => ring.priority < 2) &&
                        _search.text.isEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 7),
                        child: Text(
                          localizeText(context, 'Suggested near you'),
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            color: _green,
                          ),
                        ),
                      ),
                    ...rings
                        .where((ring) {
                          final q = _search.text.trim().toLowerCase();
                          return q.isEmpty ||
                              '${ring.name} ${ring.municipality} ${ring.region}'
                                  .toLowerCase()
                                  .contains(q);
                        })
                        .map(
                          (ring) => CheckboxListTile(
                            contentPadding: EdgeInsets.zero,
                            value: _ringIds.contains(ring.id),
                            onChanged:
                                (selected) => setState(
                                  () =>
                                      selected == true
                                          ? _ringIds.add(ring.id)
                                          : _ringIds.remove(ring.id),
                                ),
                            title: Row(
                              children: [
                                Expanded(child: Text(ring.name)),
                                if (ring.priority < 2)
                                  const Icon(
                                    Icons.near_me_outlined,
                                    size: 17,
                                    color: _green,
                                  ),
                              ],
                            ),
                            subtitle: Text(
                              '${ring.municipality}${ring.region.isEmpty ? '' : ', ${ring.region}'}\n${ring.address}${ring.schedule.isEmpty ? '' : '\n${_scheduleLabel(context, ring.schedule)}'}',
                            ),
                            isThreeLine: true,
                          ),
                        ),
                  ],
                );
              },
            ),
            const SizedBox(height: 22),
            FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon:
                  _saving
                      ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                      : const Icon(Icons.add),
              label: Text(
                localizeText(
                  context,
                  widget.sale == null ? 'Publish Hot Sale' : 'Save changes',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _section(BuildContext context, String title, String subtitle) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 11),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              localizeText(context, title),
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: _ink,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              localizeText(context, subtitle),
              style: const TextStyle(color: _muted),
            ),
          ],
        ),
      );

  Widget _photoPicker() => InkWell(
    onTap: () async {
      final photo = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        imageQuality: 82,
        maxWidth: 1800,
      );
      if (photo == null) return;
      final bytes = await photo.readAsBytes();
      if (mounted)
        setState(() {
          _photo = photo;
          _photoBytes = bytes;
        });
    },
    borderRadius: BorderRadius.circular(18),
    child: Container(
      height: 200,
      decoration: BoxDecoration(
        color: const Color(0xFFF3F7EF),
        border: Border.all(color: const Color(0xFFB9C8B5)),
        borderRadius: BorderRadius.circular(18),
      ),
      clipBehavior: Clip.antiAlias,
      child:
          _photoBytes == null
              ? Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.add_a_photo_outlined, color: _green),
                    const SizedBox(height: 8),
                    Text(localizeText(context, 'Add product photo')),
                  ],
                ),
              )
              : Stack(
                fit: StackFit.expand,
                children: [
                  Image.memory(_photoBytes!, fit: BoxFit.contain),
                  const Align(
                    alignment: Alignment.topRight,
                    child: Padding(
                      padding: EdgeInsets.all(9),
                      child: CircleAvatar(child: Icon(Icons.edit_outlined)),
                    ),
                  ),
                ],
              ),
    ),
  );

  String? _positive(String? value) =>
      (double.tryParse((value ?? '').replaceAll(',', '.')) ?? 0) <= 0
          ? localizeText(context, 'Enter a value greater than zero.')
          : null;

  Future<void> _showRing(_Ring ring) => showDialog<void>(
    context: context,
    builder:
        (context) => AlertDialog(
          title: Text(ring.name),
          content: Text(
            '${ring.address}\n${ring.municipality}'
            '${ring.region.isEmpty ? '' : ', ${ring.region}'}'
            '${ring.schedule.isEmpty ? '' : '\n\n${_scheduleLabel(context, ring.schedule)}'}',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(localizeText(context, 'Close')),
            ),
          ],
        ),
  );

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    if (_photoBytes == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(localizeText(context, 'Add one product photo.')),
        ),
      );
      return;
    }
    if (!_farm && _ringIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            localizeText(
              context,
              'Choose farm pickup or at least one REKO ring.',
            ),
          ),
        ),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      final imageName = _photo?.name ?? widget.sale!.imageName;
      final extension = imageName.toLowerCase();
      final mime =
          _photo == null
              ? widget.sale!.imageMimeType
              : extension.endsWith('.png')
              ? 'image/png'
              : extension.endsWith('.webp')
              ? 'image/webp'
              : 'image/jpeg';
      final input = <String, dynamic>{
        if (widget.sale != null) 'id': widget.sale!.id,
        'originalLanguage':
            widget.sale?.originalLanguage ??
            Localizations.localeOf(context).languageCode,
        'originalTitle': _title.text.trim(),
        'description': _description.text.trim(),
        if (_production.text.trim().isNotEmpty)
          'productionDetail': _production.text.trim(),
        'unit': _unit,
        if (_unit == 'OTHER') 'customUnit': _customUnit.text.trim(),
        'quantityStep':
            _unit == 'OTHER'
                ? double.parse(_quantityStep.text.replaceAll(',', '.'))
                : _defaultQuantityStep(_unit),
        'priceCents':
            ((double.parse(_price.text.replaceAll(',', '.'))) * 100).round(),
        'quantity': double.parse(_quantity.text.replaceAll(',', '.')),
        'availableAtFarm': _farm,
        'rekoRingIds': _ringIds.toList(),
        'imageName': imageName,
        'imageMimeType': mime,
        'imageBase64': base64Encode(_photoBytes!),
      };
      final saved =
          widget.sale == null
              ? await widget.api.create(input)
              : await widget.api.update(input);
      if (mounted) Navigator.of(context).pop(saved);
    } catch (error) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$error')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

String _unitLabel(BuildContext context, String unit) =>
    localizeText(context, switch (unit) {
      'KILOGRAM' => 'kg',
      'GRAM' => 'g',
      'LITRE' => 'litre',
      'PIECE' => 'piece',
      'BUNCH' => 'bunch',
      'BOX' => 'box',
      'DOZEN' => 'dozen',
      'OTHER' => 'Other / custom unit',
      _ => unit,
    });

double _defaultQuantityStep(String unit) => switch (unit) {
  'KILOGRAM' || 'LITRE' => 0.1,
  'GRAM' => 50,
  _ => 1,
};

double _cleanQuantity(double value) =>
    (value * 1000).roundToDouble() / 1000;

String _formatQuantity(double value) {
  final cleaned = _cleanQuantity(value);
  if (cleaned == cleaned.roundToDouble()) return cleaned.toInt().toString();
  return cleaned
      .toStringAsFixed(3)
      .replaceFirst(RegExp(r'0+$'), '')
      .replaceFirst(RegExp(r'\.$'), '');
}

String _unitChoiceLabel(BuildContext context, String unit) =>
    localizeText(context, switch (unit) {
      'KILOGRAM' => 'Kilogram (kg)',
      'GRAM' => 'Gram (g)',
      'LITRE' => 'Litre (L)',
      'PIECE' => 'Piece',
      'BUNCH' => 'Bunch',
      'BOX' => 'Box',
      'DOZEN' => 'Dozen (12 pieces)',
      'OTHER' => 'My own unit',
      _ => unit,
    });

class _HotSalesSkeleton extends StatelessWidget {
  const _HotSalesSkeleton();

  @override
  Widget build(BuildContext context) => Column(
    children: [
      for (var index = 0; index < 2; index++) ...[
        if (index > 0) const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: const Color(0xFFDCE6D6)),
            borderRadius: BorderRadius.circular(24),
            boxShadow: const [
              BoxShadow(
                color: Color(0x0F1B2A20),
                blurRadius: 18,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _skeletonBlock(width: 88, height: 88, radius: 16),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _skeletonBlock(width: 150, height: 16),
                        const SizedBox(height: 9),
                        _skeletonBlock(width: 90, height: 12),
                        const SizedBox(height: 9),
                        _skeletonBlock(height: 11),
                        const SizedBox(height: 6),
                        _skeletonBlock(width: 130, height: 11),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFF3F7EF),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        _skeletonBlock(width: 150, height: 14),
                        const Spacer(),
                        _skeletonBlock(width: 46, height: 26, radius: 13),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        _skeletonBlock(width: 70, height: 14),
                        const Spacer(),
                        _skeletonBlock(width: 132, height: 38, radius: 19),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    ],
  );

  Widget _skeletonBlock({
    double? width,
    required double height,
    double radius = 7,
  }) => Container(
    width: width ?? double.infinity,
    height: height,
    decoration: BoxDecoration(
      color: const Color(0xFFE8EEE5),
      borderRadius: BorderRadius.circular(radius),
    ),
  );
}

Future<bool> _confirmDelete(BuildContext context, _Sale sale) async =>
    await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text(localizeText(context, 'Delete product?')),
            content: Text(
              '${localizeText(context, 'This will remove')} '
              '"${sale.originalTitle}" '
              '${localizeText(context, 'from your Hot Sales list.')}',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(localizeText(context, 'Cancel')),
              ),
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: Colors.red),
                onPressed: () => Navigator.pop(context, true),
                child: Text(localizeText(context, 'Delete')),
              ),
            ],
          ),
    ) ??
    false;

void _showError(BuildContext context, Object error) =>
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(error.toString().replaceFirst('Bad state: ', ''))),
    );

class _InlineMessage extends StatelessWidget {
  const _InlineMessage({
    required this.icon,
    required this.text,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String text;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: Colors.white,
      border: Border.all(color: const Color(0xFFD5DED1)),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Row(
      children: [
        Icon(icon, color: _green),
        const SizedBox(width: 12),
        Expanded(child: Text(text, style: const TextStyle(color: _muted))),
        if (onAction != null)
          TextButton(onPressed: onAction, child: Text(actionLabel ?? 'Retry')),
      ],
    ),
  );
}

class _Message extends StatelessWidget {
  const _Message({required this.icon, required this.text});
  final IconData icon;
  final String text;
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 42, color: _green),
          const SizedBox(height: 12),
          Text(text, textAlign: TextAlign.center),
        ],
      ),
    ),
  );
}
