// Producer Insights page: sales/orders/quantity/AOV summary, a sales trend
// chart, top products, fulfilment method split, best sales day, customer
// highlights, and PDF export — all driven by the backend's producerInsights
// query (see insights_data.dart / the backend's insights module).
import 'dart:typed_data';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart' hide Text;
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

import '../../l10n/localized_text.dart';
import 'insights_data.dart';

const _green = Color(0xFF2F6B45);
const _lightGreen = Color(0xFFA9C6A0);
const _blue = Color(0xFF3E7CB1);
const _ink = Color(0xFF1B2A20);
const _muted = Color(0xFF66735F);
const _line = Color(0xFFE7E5DB);
const _cream = Color(0xFFFBFAF5);
const _red = Color(0xFFB3413B);

class ProducerInsightsPage extends StatefulWidget {
  const ProducerInsightsPage({super.key});

  @override
  State<ProducerInsightsPage> createState() => _ProducerInsightsPageState();
}

class _ProducerInsightsPageState extends State<ProducerInsightsPage> {
  InsightsRange _range = InsightsRange.forPreset(InsightsPreset.thisWeek);
  late Future<ProducerInsightsReport> _future = fetchProducerInsights(_range);
  bool _exportingReport = false;
  bool _exportingReceipts = false;

  void _applyRange(InsightsRange range) {
    setState(() {
      _range = range;
      _future = fetchProducerInsights(range);
    });
  }

  Future<void> _refresh() async {
    final next = fetchProducerInsights(_range);
    setState(() => _future = next);
    await next;
  }

  Future<void> _pickCustomRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 3),
      lastDate: now,
      initialDateRange: DateTimeRange(start: _range.from, end: _range.lastDay),
      builder:
          (context, child) => Theme(
            data: Theme.of(context).copyWith(
              colorScheme: Theme.of(context).colorScheme.copyWith(primary: _green),
            ),
            child: child!,
          ),
    );
    if (picked == null) return;
    _applyRange(InsightsRange.custom(picked.start, picked.end));
  }

  Future<void> _exportReport() async {
    if (_exportingReport) return;
    setState(() => _exportingReport = true);
    try {
      final bytes = await fetchInsightsReportPdf(_range);
      await _shareBytes(bytes, 'insights-report.pdf');
    } catch (error) {
      _showError(error);
    } finally {
      if (mounted) setState(() => _exportingReport = false);
    }
  }

  Future<void> _exportReceipts() async {
    if (_exportingReceipts) return;
    setState(() => _exportingReceipts = true);
    try {
      final bytes = await fetchReceiptsPdf(_range);
      await _shareBytes(bytes, 'receipts.pdf');
    } catch (error) {
      _showError(error);
    } finally {
      if (mounted) setState(() => _exportingReceipts = false);
    }
  }

  // XFile.fromData keeps the PDF entirely in memory rather than writing to a
  // temp file — dart:io has no meaningful implementation on Flutter Web,
  // and this same page is part of the web build (see deploy-pages.yml), so
  // any dart:io usage here would break that build, not just look untidy.
  Future<void> _shareBytes(Uint8List bytes, String filename) async {
    final file = XFile.fromData(bytes, name: filename, mimeType: 'application/pdf');
    await SharePlus.instance.share(ShareParams(files: [file]));
  }

  void _showError(Object error) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(error.toString().replaceFirst('Bad state: ', ''))),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _cream,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _refresh,
          color: _green,
          child: FutureBuilder<ProducerInsightsReport>(
            future: _future,
            builder: (context, snapshot) {
              return ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                children: [
                  _Header(exporting: _exportingReport, onExportReport: _exportReport),
                  const SizedBox(height: 16),
                  _RangeSelector(range: _range, onPickCustom: _pickCustomRange),
                  const SizedBox(height: 10),
                  _PresetChips(selected: _range.preset, onSelect: (preset) => _applyRange(InsightsRange.forPreset(preset))),
                  const SizedBox(height: 18),
                  if (snapshot.connectionState == ConnectionState.waiting)
                    const Padding(
                      padding: EdgeInsets.only(top: 60),
                      child: Center(child: CircularProgressIndicator(color: _green)),
                    )
                  else if (snapshot.hasError)
                    _ErrorState(
                      message: snapshot.error.toString().replaceFirst('Bad state: ', ''),
                      onRetry: () => setState(() => _future = fetchProducerInsights(_range)),
                    )
                  else if (snapshot.hasData)
                    _ReportBody(
                      report: snapshot.data!,
                      range: _range,
                      exportingReport: _exportingReport,
                      exportingReceipts: _exportingReceipts,
                      onExportReport: _exportReport,
                      onExportReceipts: _exportReceipts,
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.exporting, required this.onExportReport});
  final bool exporting;
  final VoidCallback onExportReport;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                localizeText(context, 'Insights'),
                style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w700, color: _ink),
              ),
              const SizedBox(height: 2),
              Text(
                localizeText(context, 'Track your sales, orders and business performance.'),
                style: const TextStyle(fontSize: 13, color: _muted),
              ),
            ],
          ),
        ),
        OutlinedButton.icon(
          onPressed: exporting ? null : onExportReport,
          style: OutlinedButton.styleFrom(
            foregroundColor: _green,
            side: const BorderSide(color: _line),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          icon:
              exporting
                  ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2, color: _green),
                  )
                  : const Icon(Icons.picture_as_pdf_outlined, size: 18),
          label: Text(localizeText(context, 'PDF report')),
        ),
      ],
    );
  }
}

class _RangeSelector extends StatelessWidget {
  const _RangeSelector({required this.range, required this.onPickCustom});
  final InsightsRange range;
  final VoidCallback onPickCustom;

  @override
  Widget build(BuildContext context) {
    final formatter = DateFormat('d MMM y');
    return Row(
      children: [
        Expanded(
          child: InkWell(
            onTap: onPickCustom,
            borderRadius: BorderRadius.circular(14),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: _line),
              ),
              child: Row(
                children: [
                  const Icon(Icons.calendar_today_outlined, size: 17, color: _green),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '${formatter.format(range.from)} – ${formatter.format(range.lastDay)}',
                      style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: _ink),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const Icon(Icons.keyboard_arrow_down_rounded, size: 20, color: _muted),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        OutlinedButton.icon(
          onPressed: onPickCustom,
          style: OutlinedButton.styleFrom(
            foregroundColor: _green,
            side: const BorderSide(color: Color(0xFFBFDAB6)),
            backgroundColor: const Color(0xFFF0F7ED),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
          icon: const Icon(Icons.date_range_outlined, size: 17),
          label: Text(localizeText(context, 'Custom range')),
        ),
      ],
    );
  }
}

class _PresetChips extends StatelessWidget {
  const _PresetChips({required this.selected, required this.onSelect});
  final InsightsPreset selected;
  final ValueChanged<InsightsPreset> onSelect;

  @override
  Widget build(BuildContext context) {
    final presets = InsightsPreset.values.where((preset) => preset != InsightsPreset.custom).toList();
    return SizedBox(
      height: 38,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: presets.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final preset = presets[index];
          final isSelected = preset == selected;
          return ChoiceChip(
            label: Text(localizeText(context, presetLabel(preset))),
            selected: isSelected,
            onSelected: (_) => onSelect(preset),
            selectedColor: _green,
            backgroundColor: Colors.white,
            side: BorderSide(color: isSelected ? _green : _line),
            labelStyle: TextStyle(
              color: isSelected ? Colors.white : _ink,
              fontWeight: FontWeight.w600,
              fontSize: 12.5,
            ),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          );
        },
      ),
    );
  }
}

class _ReportBody extends StatelessWidget {
  const _ReportBody({
    required this.report,
    required this.range,
    required this.exportingReport,
    required this.exportingReceipts,
    required this.onExportReport,
    required this.onExportReceipts,
  });

  final ProducerInsightsReport report;
  final InsightsRange range;
  final bool exportingReport;
  final bool exportingReceipts;
  final VoidCallback onExportReport;
  final VoidCallback onExportReceipts;

  @override
  Widget build(BuildContext context) {
    final summary = report.summary;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 1.55,
          children: [
            _MetricCard(
              icon: Icons.euro_rounded,
              iconColor: _green,
              iconBackground: const Color(0xFFDCEBD7),
              label: localizeText(context, 'Total sales'),
              value: _formatCents(summary.totalSalesCents),
              changePercent: summary.totalSalesChangePercent,
            ),
            _MetricCard(
              icon: Icons.shopping_bag_outlined,
              iconColor: _blue,
              iconBackground: const Color(0xFFDCE9F3),
              label: localizeText(context, 'Completed orders'),
              value: '${summary.completedOrders}',
              changePercent: summary.completedOrdersChangePercent,
            ),
            _MetricCard(
              icon: Icons.inventory_2_outlined,
              iconColor: const Color(0xFF8E5FBF),
              iconBackground: const Color(0xFFE9DFF3),
              label: localizeText(context, 'Quantity sold'),
              value: summary.quantitySold.toStringAsFixed(summary.quantitySold % 1 == 0 ? 0 : 1),
              changePercent: summary.quantitySoldChangePercent,
            ),
            _MetricCard(
              icon: Icons.bar_chart_rounded,
              iconColor: const Color(0xFFC98A2C),
              iconBackground: const Color(0xFFF3E7D2),
              label: localizeText(context, 'Average order value'),
              value: _formatCents(summary.averageOrderValueCents),
              changePercent: summary.averageOrderValueChangePercent,
            ),
          ],
        ),
        const SizedBox(height: 16),
        _Card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      localizeText(context, 'Sales trend'),
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: _ink),
                    ),
                  ),
                  _Legend(),
                ],
              ),
              const SizedBox(height: 16),
              SizedBox(height: 180, child: _SalesTrendChart(points: report.salesTrend)),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _Card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                localizeText(context, 'Top products'),
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: _ink),
              ),
              const SizedBox(height: 12),
              if (report.topProducts.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    localizeText(context, 'No completed orders in this period.'),
                    style: const TextStyle(color: _muted, fontSize: 13),
                  ),
                )
              else
                ...report.topProducts.map((product) => _TopProductRow(product: product)),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _Card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                localizeText(context, 'Fulfilment method'),
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: _ink),
              ),
              const SizedBox(height: 12),
              _FulfilmentChart(slices: report.fulfilment, totalOrders: summary.completedOrders),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: _BestSalesDayCard(bestDay: report.bestSalesDay)),
            const SizedBox(width: 10),
            Expanded(child: _CustomerHighlightsCard(highlights: report.customerHighlights)),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          localizeText(context, 'Reports & receipts'),
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: _ink),
        ),
        const SizedBox(height: 10),
        _ReportRow(
          icon: Icons.description_outlined,
          title: localizeText(context, 'See PDF report'),
          subtitle: localizeText(context, 'Download a detailed business report for the selected period.'),
          loading: exportingReport,
          onTap: onExportReport,
        ),
        const SizedBox(height: 10),
        _ReportRow(
          icon: Icons.receipt_long_outlined,
          title: localizeText(context, 'Download receipts of all sales'),
          subtitle: localizeText(context, 'Get a PDF with all sales receipts for the selected period.'),
          loading: exportingReceipts,
          onTap: onExportReceipts,
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFFFBF0E4),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              const Icon(Icons.lightbulb_outline_rounded, size: 18, color: Color(0xFFC98A2C)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  localizeText(context, 'Reports include completed orders only. Data is updated daily.'),
                  style: const TextStyle(fontSize: 12, color: _muted),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _line),
      ),
      child: child,
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.icon,
    required this.iconColor,
    required this.iconBackground,
    required this.label,
    required this.value,
    required this.changePercent,
  });

  final IconData icon;
  final Color iconColor;
  final Color iconBackground;
  final String label;
  final String value;
  final double? changePercent;

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(color: iconBackground, borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, size: 18, color: iconColor),
          ),
          const Spacer(),
          Text(label, style: const TextStyle(fontSize: 12.5, color: _muted)),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w700, color: _ink),
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          _ChangeBadge(changePercent: changePercent),
        ],
      ),
    );
  }
}

class _ChangeBadge extends StatelessWidget {
  const _ChangeBadge({required this.changePercent});
  final double? changePercent;

  @override
  Widget build(BuildContext context) {
    if (changePercent == null) {
      return const Text('—', style: TextStyle(fontSize: 11.5, color: _muted));
    }
    final positive = changePercent! >= 0;
    final color = positive ? _green : _red;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(positive ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded, size: 13, color: color),
        const SizedBox(width: 2),
        Text(
          '${changePercent!.abs().toStringAsFixed(1)}%',
          style: TextStyle(fontSize: 11.5, color: color, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}

class _Legend extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _legendDot(_green, localizeText(context, 'This period')),
        const SizedBox(width: 10),
        _legendDot(_lightGreen, localizeText(context, 'Previous period')),
      ],
    );
  }

  Widget _legendDot(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 10.5, color: _muted)),
      ],
    );
  }
}

class _SalesTrendChart extends StatelessWidget {
  const _SalesTrendChart({required this.points});
  final List<InsightsTrendPoint> points;

  @override
  Widget build(BuildContext context) {
    if (points.isEmpty) {
      return Center(
        child: Text(
          localizeText(context, 'No data for this period.'),
          style: const TextStyle(color: _muted, fontSize: 13),
        ),
      );
    }
    final maxValue = points.fold<double>(
      0,
      (max, point) => [max, point.totalCents.toDouble(), point.previousPeriodTotalCents.toDouble()].reduce(
        (a, b) => a > b ? a : b,
      ),
    );
    final ceiling = maxValue <= 0 ? 100.0 : maxValue * 1.2;
    final formatter = points.length <= 31 ? DateFormat('d MMM') : DateFormat('MMM');
    final labelStep = (points.length / 5).ceil().clamp(1, points.length);

    return LineChart(
      LineChartData(
        minY: 0,
        maxY: ceiling,
        gridData: FlGridData(
          drawVerticalLine: false,
          horizontalInterval: ceiling / 3,
          getDrawingHorizontalLine: (_) => FlLine(color: _line, strokeWidth: 1),
        ),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 42,
              interval: ceiling / 3,
              getTitlesWidget:
                  (value, meta) => Text(
                    '€${value.toInt()}',
                    style: const TextStyle(fontSize: 9.5, color: _muted),
                  ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 24,
              interval: labelStep.toDouble(),
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index < 0 || index >= points.length) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    formatter.format(points[index].date),
                    style: const TextStyle(fontSize: 9.5, color: _muted),
                  ),
                );
              },
            ),
          ),
        ),
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipItems:
                (spots) =>
                    spots
                        .map(
                          (spot) => LineTooltipItem(
                            '€${(spot.y / 100).toStringAsFixed(2)}',
                            const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
                          ),
                        )
                        .toList(),
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: [
              for (var i = 0; i < points.length; i++)
                FlSpot(i.toDouble(), points[i].previousPeriodTotalCents.toDouble()),
            ],
            isCurved: true,
            color: _lightGreen,
            barWidth: 2,
            dashArray: [6, 4],
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(show: false),
          ),
          LineChartBarData(
            spots: [for (var i = 0; i < points.length; i++) FlSpot(i.toDouble(), points[i].totalCents.toDouble())],
            isCurved: true,
            color: _green,
            barWidth: 2.5,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(show: false),
          ),
        ],
      ),
    );
  }
}

class _TopProductRow extends StatelessWidget {
  const _TopProductRow({required this.product});
  final InsightsTopProduct product;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Image.memory(product.imageBytes, width: 42, height: 42, fit: BoxFit.cover),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  product.title,
                  style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: _ink),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: product.shareOfTopRevenue.clamp(0.0, 1.0).toDouble(),
                    minHeight: 6,
                    backgroundColor: const Color(0xFFEFEEE6),
                    color: _green,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${product.quantity.toStringAsFixed(product.quantity % 1 == 0 ? 0 : 1)} ${product.unit}',
                style: const TextStyle(fontSize: 11.5, color: _muted),
              ),
              Text(
                _formatCents(product.revenueCents),
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _ink),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FulfilmentChart extends StatelessWidget {
  const _FulfilmentChart({required this.slices, required this.totalOrders});
  final List<InsightsFulfilmentSlice> slices;
  final int totalOrders;

  Color _colorFor(String pickupType) => pickupType == 'REKO' ? _blue : _green;
  String _labelFor(BuildContext context, String pickupType) =>
      pickupType == 'REKO' ? localizeText(context, 'Reko meetup') : localizeText(context, 'Farm pickup');

  @override
  Widget build(BuildContext context) {
    if (totalOrders == 0) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Text(
          localizeText(context, 'No completed orders in this period.'),
          style: const TextStyle(color: _muted, fontSize: 13),
        ),
      );
    }
    return Row(
      children: [
        SizedBox(
          width: 110,
          height: 110,
          child: Stack(
            alignment: Alignment.center,
            children: [
              PieChart(
                PieChartData(
                  sectionsSpace: 2,
                  centerSpaceRadius: 32,
                  sections: [
                    for (final slice in slices)
                      PieChartSectionData(
                        value: slice.orderCount.toDouble(),
                        color: _colorFor(slice.pickupType),
                        radius: 20,
                        showTitle: false,
                      ),
                  ],
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '$totalOrders',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: _ink),
                  ),
                  Text(localizeText(context, 'orders'), style: const TextStyle(fontSize: 10, color: _muted)),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final slice in slices)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Container(
                        width: 9,
                        height: 9,
                        decoration: BoxDecoration(color: _colorFor(slice.pickupType), shape: BoxShape.circle),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(_labelFor(context, slice.pickupType), style: const TextStyle(fontSize: 12.5, color: _ink)),
                      ),
                      Text(
                        '${slice.orderCount} (${slice.percent.toStringAsFixed(0)}%)',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _muted),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _BestSalesDayCard extends StatelessWidget {
  const _BestSalesDayCard({required this.bestDay});
  final InsightsBestDay bestDay;

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.event_available_outlined, size: 17, color: _green),
              const SizedBox(width: 6),
              Text(
                localizeText(context, 'Best sales day'),
                style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: _muted),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (bestDay.date == null)
            Text(localizeText(context, 'No data yet'), style: const TextStyle(fontSize: 13, color: _muted))
          else ...[
            Text(
              DateFormat('EEEE d MMM').format(bestDay.date!),
              style: const TextStyle(fontSize: 12, color: _muted),
            ),
            const SizedBox(height: 2),
            Text(
              _formatCents(bestDay.totalCents),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: _ink),
            ),
            Text(
              '${bestDay.orderCount} ${localizeText(context, 'orders')}',
              style: const TextStyle(fontSize: 11.5, color: _muted),
            ),
          ],
        ],
      ),
    );
  }
}

class _CustomerHighlightsCard extends StatelessWidget {
  const _CustomerHighlightsCard({required this.highlights});
  final InsightsCustomerHighlights highlights;

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.person_outline_rounded, size: 17, color: _green),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  localizeText(context, 'Customer highlights'),
                  style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: _muted),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _highlightColumn(
                  context,
                  localizeText(context, 'New'),
                  highlights.newCustomers,
                  highlights.newCustomersChangePercent,
                ),
              ),
              Expanded(
                child: _highlightColumn(
                  context,
                  localizeText(context, 'Returning'),
                  highlights.returningCustomers,
                  highlights.returningCustomersChangePercent,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _highlightColumn(BuildContext context, String label, int value, double? changePercent) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 11, color: _muted)),
        Text('$value', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: _ink)),
        _ChangeBadge(changePercent: changePercent),
      ],
    );
  }
}

class _ReportRow extends StatelessWidget {
  const _ReportRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.loading,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool loading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: loading ? null : onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _line),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(color: const Color(0xFFDCEBD7), borderRadius: BorderRadius.circular(10)),
              child: Icon(icon, size: 18, color: _green),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: _ink)),
                  const SizedBox(height: 2),
                  Text(subtitle, style: const TextStyle(fontSize: 11.5, color: _muted)),
                ],
              ),
            ),
            const SizedBox(width: 8),
            loading
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: _green))
                : const Icon(Icons.chevron_right_rounded, color: _muted),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 60),
      child: Column(
        children: [
          const Icon(Icons.error_outline_rounded, size: 36, color: _muted),
          const SizedBox(height: 10),
          Text(message, textAlign: TextAlign.center, style: const TextStyle(color: _muted, fontSize: 13)),
          const SizedBox(height: 12),
          TextButton(onPressed: onRetry, child: Text(localizeText(context, 'Try again'))),
        ],
      ),
    );
  }
}

String _formatCents(int cents) => '€${(cents / 100).toStringAsFixed(2)}';
