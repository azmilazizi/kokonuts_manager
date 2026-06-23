import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'package:fl_chart/fl_chart.dart';
import '../../app/app_state.dart';
import '../../services/auth_service.dart';
import '../../services/auth_expiration_handler.dart';

class DashboardTab extends StatefulWidget {
  final AppState state;

  const DashboardTab({super.key, required this.state});

  @override
  State<DashboardTab> createState() => _DashboardTabState();
}

class _DashboardTabState extends State<DashboardTab>
    with AutomaticKeepAliveClientMixin {
  Map<String, dynamic>? _summary;
  List<Map<String, dynamic>> _dailyTrend = [];
  List<Map<String, dynamic>> _recentShifts = [];
  List<Map<String, dynamic>> _paymentBreakdown = [];
  bool _loading = false;
  String? _error;
  int? _lastWarehouseId;

  String _preset = 'Today';
  DateTimeRange _range = DateTimeRange(
    start: DateTime(
        DateTime.now().year, DateTime.now().month, DateTime.now().day),
    end: DateTime(
        DateTime.now().year, DateTime.now().month, DateTime.now().day),
  );

  static const _presets = [
    'Today',
    'Yesterday',
    'Last 7 Days',
    'Last 30 Days',
    'This Month',
    'Last Month',
    'Custom',
  ];

  static DateTimeRange _rangeForPreset(String preset) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    switch (preset) {
      case 'Today':
        return DateTimeRange(start: today, end: today);
      case 'Yesterday':
        final y = today.subtract(const Duration(days: 1));
        return DateTimeRange(start: y, end: y);
      case 'Last 7 Days':
        return DateTimeRange(
            start: today.subtract(const Duration(days: 6)), end: today);
      case 'Last 30 Days':
        return DateTimeRange(
            start: today.subtract(const Duration(days: 29)), end: today);
      case 'This Month':
        return DateTimeRange(
            start: DateTime(now.year, now.month, 1), end: today);
      case 'Last Month':
        final firstOfThisMonth = DateTime(now.year, now.month, 1);
        final lastOfLastMonth =
            firstOfThisMonth.subtract(const Duration(days: 1));
        return DateTimeRange(
          start:
              DateTime(lastOfLastMonth.year, lastOfLastMonth.month, 1),
          end: lastOfLastMonth,
        );
      default:
        return DateTimeRange(
            start: today.subtract(const Duration(days: 6)), end: today);
    }
  }

  static final _currency = NumberFormat('#,##0.00');
  static final _dateFmt = DateFormat('d MMM');

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _lastWarehouseId = widget.state.selectedWarehouse?.id;
    widget.state.addListener(_onStateChanged);
    _load();
  }

  @override
  void didUpdateWidget(DashboardTab old) {
    super.didUpdateWidget(old);
    if (old.state != widget.state) {
      old.state.removeListener(_onStateChanged);
      widget.state.addListener(_onStateChanged);
      _lastWarehouseId = widget.state.selectedWarehouse?.id;
      _load();
    }
  }

  void _onStateChanged() {
    if (!mounted) return;
    final newId = widget.state.selectedWarehouse?.id;
    if (newId != _lastWarehouseId) {
      _lastWarehouseId = newId;
      _load();
    }
  }

  @override
  void dispose() {
    widget.state.removeListener(_onStateChanged);
    super.dispose();
  }

  Future<void> _load() async {
    if (!mounted || _loading) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final token = widget.state.token!;
      final wid = widget.state.selectedWarehouse?.id;
      final from = DateFormat('yyyy-MM-dd').format(_range.start);
      final to = DateFormat('yyyy-MM-dd').format(_range.end);

      final results = await Future.wait([
        _get(token, 'dashboard/summary', {
          'date_from': from,
          'date_to': to,
          'compare': 'true',
          if (wid != null) 'warehouse_id': '$wid'
        }),
        _get(token, 'dashboard/daily-trend', {
          'date_from': from,
          'date_to': to,
          if (wid != null) 'warehouse_id': '$wid'
        }),
        _get(token, 'dashboard/payment-breakdown', {
          'date_from': from,
          'date_to': to,
          if (wid != null) 'warehouse_id': '$wid'
        }),
        _get(token, 'dashboard/recent-shifts', {
          'date_from': from,
          'date_to': to,
          if (wid != null) 'warehouse_id': '$wid',
          'limit': '5',
        }),
      ]);

      if (!mounted) return;
      setState(() {
        _summary = results[0];
        _dailyTrend = (results[1]['data'] as List? ?? [])
            .cast<Map<String, dynamic>>();
        _paymentBreakdown = (results[2]['data'] as List? ?? [])
            .cast<Map<String, dynamic>>();
        _recentShifts = (results[3]['data'] as List? ?? [])
            .cast<Map<String, dynamic>>();
      });
    } on AuthException catch (e) {
      if (e.statusCode == 401) {
        AuthExpirationHandler().handleExpired();
        return;
      }
      if (mounted) setState(() => _error = e.message);
    } catch (e) {
      if (mounted) setState(() => _error = 'Failed to load dashboard data.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<Map<String, dynamic>> _get(
      String token, String path, Map<String, String> params) async {
    final uri = Uri.parse('$kManagerApiBase/$path')
        .replace(queryParameters: params);
    final resp =
        await http.get(uri, headers: {'Authorization': 'Bearer $token'});
    final body = jsonDecode(resp.body) as Map<String, dynamic>;
    if (resp.statusCode == 401) {
      throw const AuthException('Session expired', 401);
    }
    if (resp.statusCode != 200) {
      throw AuthException(
          body['error'] as String? ?? 'Request failed', resp.statusCode);
    }
    return body;
  }

  String? _formatPeriodLabel(Map<String, dynamic>? prev) {
    if (prev == null) return null;
    final fromStr = prev['date_from'] as String?;
    final toStr = prev['date_to'] as String?;
    if (fromStr == null || toStr == null) return null;
    final from = DateTime.tryParse(fromStr);
    final to = DateTime.tryParse(toStr);
    if (from == null || to == null) return null;
    final d = DateFormat('d MMM');
    if (from.year == to.year && from.month == to.month && from.day == to.day) {
      return 'vs ${d.format(from)}';
    }
    if (from.year == to.year && from.month == to.month) {
      return 'vs ${DateFormat('d').format(from)}–${d.format(to)}';
    }
    return 'vs ${d.format(from)} – ${d.format(to)}';
  }

  void _selectPreset(String preset) async {
    if (preset == 'Custom') {
      final picked = await showDateRangePicker(
        context: context,
        firstDate: DateTime(2020),
        lastDate: DateTime.now(),
        initialDateRange: _range,
        builder: (ctx, child) => Theme(data: Theme.of(ctx), child: child!),
      );
      if (picked != null && mounted) {
        setState(() {
          _preset = 'Custom';
          _range = picked;
        });
        _load();
      }
    } else {
      setState(() {
        _preset = preset;
        _range = _rangeForPreset(preset);
      });
      _load();
    }
  }

  Widget _buildShiftCard(Map<String, dynamic> s, ThemeData theme) {
    final isOpen = s['status'] == 'open';
    DateTime? openedAt;
    try {
      openedAt = DateTime.parse(s['opened_at'] as String? ?? '');
    } catch (_) {}
    final dateLabel = openedAt != null
        ? DateFormat('d MMM yyyy, h:mm a').format(openedAt)
        : '—';
    final txnCount = s['transaction_count'];
    return Card(
      color: theme.colorScheme.surfaceContainerHighest,
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: isOpen
              ? Colors.orange.withAlpha(40)
              : theme.colorScheme.outline.withAlpha(30),
          child: Icon(
            isOpen ? Icons.lock_open : Icons.lock_outline,
            color: isOpen ? Colors.orange : theme.colorScheme.outline,
            size: 20,
          ),
        ),
        title: Text(s['warehouse_name'] as String? ?? ''),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(dateLabel, style: theme.textTheme.bodySmall),
            if (txnCount != null)
              Text(
                '$txnCount txns',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.outline,
                ),
              ),
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              'RM ${_currency.format(s['net_sales'] ?? 0)}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: isOpen
                    ? Colors.orange.withAlpha(40)
                    : theme.colorScheme.outline.withAlpha(40),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                isOpen ? 'OPEN' : 'CLOSED',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: isOpen ? Colors.orange : theme.colorScheme.outline,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final theme = Theme.of(context);
    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth >= 600;
    final hPad = isTablet ? 14.0 : 8.0;
    final gridGap = isTablet ? 8.0 : 6.0;
    final from = _dateFmt.format(_range.start);
    final to = _dateFmt.format(_range.end);

    return RefreshIndicator(
      onRefresh: _load,
      color: theme.colorScheme.primary,
      child: CustomScrollView(
        slivers: [
          // Date preset chips
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.only(top: 12, bottom: 4),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: EdgeInsets.symmetric(horizontal: hPad),
                child: Row(
                  children: _presets.map((p) {
                    final isSelected = _preset == p;
                    final label = p == 'Custom' && _preset == 'Custom'
                        ? '$from – $to'
                        : p;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: FilterChip(
                        label: Text(label),
                        selected: isSelected,
                        onSelected: (_) => _selectPreset(p),
                        showCheckmark: false,
                        visualDensity: VisualDensity.compact,
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
          ),

          if (_loading && _summary == null)
            const SliverFillRemaining(
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_error != null)
            SliverFillRemaining(
              child: _EmptyState(
                icon: Icons.error_outline,
                title: 'Failed to load',
                description: _error!,
                action:
                    TextButton(onPressed: _load, child: const Text('Retry')),
              ),
            )
          else if (_summary != null) ...[
            // KPI cards — 2 columns on phone, 3 on tablet
            SliverPadding(
              padding: EdgeInsets.symmetric(horizontal: hPad),
              sliver: SliverGrid.count(
                crossAxisCount: isTablet ? 3 : 2,
                mainAxisSpacing: gridGap,
                crossAxisSpacing: gridGap,
                childAspectRatio: isTablet ? 1.6 : 1.3,
                children: () {
                  final changes = _summary!['changes'] as Map<String, dynamic>? ?? {};
                  final prevPeriod = _summary!['previous_period'] as Map<String, dynamic>?;
                  final periodLabel = _formatPeriodLabel(prevPeriod);

                  double? pct(String key) {
                    final c = changes[key] as Map<String, dynamic>?;
                    return (c?['percent'] as num?)?.toDouble();
                  }

                  String? absCurrency(String key) {
                    final c = changes[key] as Map<String, dynamic>?;
                    final abs = (c?['absolute'] as num?)?.toDouble();
                    if (abs == null) return null;
                    final sign = abs >= 0 ? '+' : '-';
                    return '${sign}RM ${_currency.format(abs.abs())}';
                  }

                  String? absCount(String key) {
                    final c = changes[key] as Map<String, dynamic>?;
                    final abs = (c?['absolute'] as num?)?.toDouble();
                    if (abs == null) return null;
                    final sign = abs >= 0 ? '+' : '';
                    return '$sign${abs.toInt()}';
                  }

                  return [
                    _KpiCard(
                      label: 'Net Sales',
                      value: 'RM ${_currency.format(_summary!['net_sales'] ?? 0)}',
                      color: theme.colorScheme.primary,
                      changePercent: pct('net_sales'),
                      changeAbsolute: absCurrency('net_sales'),
                      periodLabel: periodLabel,
                    ),
                    _KpiCard(
                      label: 'Transactions',
                      value: '${_summary!['transaction_count'] ?? 0}',
                      color: theme.colorScheme.primary,
                      changePercent: pct('transaction_count'),
                      changeAbsolute: absCount('transaction_count'),
                      periodLabel: periodLabel,
                    ),
                    _KpiCard(
                      label: 'Total Refunds',
                      value: 'RM ${_currency.format(_summary!['total_refunds'] ?? 0)}',
                      color: Colors.redAccent,
                      changePercent: pct('total_refunds'),
                      changeAbsolute: absCurrency('total_refunds'),
                      periodLabel: periodLabel,
                      isPositiveGood: false,
                    ),
                    _KpiCard(
                      label: 'Avg. Transaction',
                      value: 'RM ${_currency.format(_summary!['average_transaction_value'] ?? 0)}',
                      color: theme.colorScheme.primary,
                      changePercent: pct('average_transaction_value'),
                      changeAbsolute: absCurrency('average_transaction_value'),
                      periodLabel: periodLabel,
                    ),
                    _KpiCard(
                      label: 'Discounts',
                      value: 'RM ${_currency.format(_summary!['total_discounts'] ?? 0)}',
                      color: Colors.orangeAccent,
                      changePercent: pct('total_discounts'),
                      changeAbsolute: absCurrency('total_discounts'),
                      periodLabel: periodLabel,
                      isPositiveGood: false,
                    ),
                    _KpiCard(
                      label: 'Tax Collected',
                      value: 'RM ${_currency.format(_summary!['total_tax'] ?? 0)}',
                      color: Colors.orangeAccent,
                      changePercent: pct('total_tax'),
                      changeAbsolute: absCurrency('total_tax'),
                      periodLabel: periodLabel,
                    ),
                  ];
                }(),
              ),
            ),

            if (isTablet && (_dailyTrend.isNotEmpty || _paymentBreakdown.isNotEmpty)) ...[
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(hPad, 4, hPad, 0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_dailyTrend.isNotEmpty)
                        Expanded(
                          flex: 3,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: Text('Daily Revenue',
                                    style: theme.textTheme.titleSmall),
                              ),
                              SizedBox(
                                height: 220,
                                child: _DailyTrendChart(
                                    trend: _dailyTrend, hPad: 0),
                              ),
                            ],
                          ),
                        ),
                      if (_dailyTrend.isNotEmpty && _paymentBreakdown.isNotEmpty)
                        const SizedBox(width: 12),
                      if (_paymentBreakdown.isNotEmpty)
                        Expanded(
                          flex: 2,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: Text('Payment Breakdown',
                                    style: theme.textTheme.titleSmall),
                              ),
                              _PaymentBreakdownCard(
                                breakdown: _paymentBreakdown,
                                isTablet: true,
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ] else ...[
              if (_dailyTrend.isNotEmpty) ...[
                _SectionHeader(title: 'Daily Revenue', hPad: hPad),
                SliverToBoxAdapter(
                  child: SizedBox(
                    height: 174,
                    child: _DailyTrendChart(trend: _dailyTrend, hPad: hPad),
                  ),
                ),
              ],
              if (_paymentBreakdown.isNotEmpty) ...[
                _SectionHeader(title: 'Payment Breakdown', hPad: hPad),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: hPad),
                    child: _PaymentBreakdownCard(
                      breakdown: _paymentBreakdown,
                      isTablet: false,
                    ),
                  ),
                ),
              ],
            ],

            // Recent shifts
            if (_recentShifts.isNotEmpty) ...[
              _SectionHeader(title: 'Recent Shifts', hPad: hPad),
              if (isTablet)
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(hPad, 0, hPad, 24),
                  sliver: SliverGrid.count(
                    crossAxisCount: 2,
                    childAspectRatio: 3.8,
                    mainAxisSpacing: gridGap,
                    crossAxisSpacing: gridGap,
                    children: _recentShifts
                        .map((s) => _buildShiftCard(s, theme))
                        .toList(),
                  ),
                )
              else
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(hPad, 0, hPad, 24),
                  sliver: SliverList.builder(
                    itemCount: _recentShifts.length,
                    itemBuilder: (_, i) =>
                        _buildShiftCard(_recentShifts[i], theme),
                  ),
                ),
            ],
          ],
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final double hPad;
  const _SectionHeader({required this.title, this.hPad = 16});

  @override
  Widget build(BuildContext context) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: EdgeInsets.fromLTRB(hPad, 4, hPad, 8),
        child:
            Text(title, style: Theme.of(context).textTheme.titleSmall),
      ),
    );
  }
}

class _KpiCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final double? changePercent;
  final String? changeAbsolute;
  final String? periodLabel;
  final bool isPositiveGood;

  const _KpiCard({
    required this.label,
    required this.value,
    required this.color,
    this.changePercent,
    this.changeAbsolute,
    this.periodLabel,
    this.isPositiveGood = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    Color? changeColor;
    IconData? changeIcon;
    String? changeLabel;
    if (changePercent != null) {
      final pct = changePercent!;
      final isGood = isPositiveGood ? pct >= 0 : pct <= 0;
      changeColor = isGood ? Colors.greenAccent : Colors.redAccent;
      changeIcon = pct >= 0 ? Icons.arrow_upward : Icons.arrow_downward;
      final sign = pct >= 0 ? '+' : '';
      changeLabel = '$sign${pct.toStringAsFixed(1)}%';
    }

    return Card(
      color: theme.colorScheme.surfaceContainerHighest,
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurface.withAlpha(178),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              value,
              style: theme.textTheme.titleLarge?.copyWith(
                color: color,
                fontWeight: FontWeight.w700,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            if (changeLabel != null)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(changeIcon, size: 11, color: changeColor),
                      const SizedBox(width: 2),
                      Text(
                        changeLabel,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: changeColor,
                          fontWeight: FontWeight.w600,
                          fontSize: 10,
                        ),
                      ),
                      if (changeAbsolute != null) ...[
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            changeAbsolute!,
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: changeColor?.withAlpha(200),
                              fontSize: 10,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (periodLabel != null)
                    Text(
                      periodLabel!,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurface.withAlpha(120),
                        fontSize: 9,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _DailyTrendChart extends StatefulWidget {
  final List<Map<String, dynamic>> trend;
  final double hPad;
  const _DailyTrendChart({required this.trend, this.hPad = 16});

  @override
  State<_DailyTrendChart> createState() => _DailyTrendChartState();
}

class _DailyTrendChartState extends State<_DailyTrendChart> {
  int? _activeIndex;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (widget.trend.isEmpty) return const SizedBox.shrink();

    final maxRevenue = widget.trend
        .map((d) => (d['revenue'] as num?)?.toDouble() ?? 0)
        .reduce((a, b) => a > b ? a : b);

    return Padding(
      padding: EdgeInsets.fromLTRB(widget.hPad, 4, widget.hPad, 8),
      child: Column(
        children: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 150),
            child: _activeIndex != null
                ? _TrendTooltip(
                    key: ValueKey(_activeIndex),
                    data: widget.trend[_activeIndex!],
                  )
                : const SizedBox(
                    key: ValueKey<String>('trend-empty'),
                    height: 32,
                  ),
          ),
          const SizedBox(height: 6),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final n = widget.trend.length;
                final barW = (constraints.maxWidth / n).clamp(0.0, 56.0);
                return Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: List.generate(n, (i) {
                    final d = widget.trend[i];
                    final rev = (d['revenue'] as num?)?.toDouble() ?? 0;
                    final pct = (maxRevenue > 0 ? rev / maxRevenue : 0)
                        .toDouble()
                        .clamp(0.02, 1.0);
                    final date = d['date'] as String? ?? '';
                    final label = date.length >= 10
                        ? DateFormat('d/M').format(DateTime.parse(date))
                        : date;
                    final isActive = _activeIndex == i;

                    return SizedBox(
                      width: barW,
                      child: GestureDetector(
                        onTap: () => setState(
                            () => _activeIndex = isActive ? null : i),
                        child: MouseRegion(
                          cursor: SystemMouseCursors.click,
                          onEnter: (_) => setState(() => _activeIndex = i),
                          onExit: (_) =>
                              setState(() => _activeIndex = null),
                          child: Padding(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 2),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                Expanded(
                                  child: Align(
                                    alignment: Alignment.bottomCenter,
                                    child: FractionallySizedBox(
                                      heightFactor: pct,
                                      child: AnimatedContainer(
                                        duration: const Duration(
                                            milliseconds: 150),
                                        decoration: BoxDecoration(
                                          color: isActive
                                              ? theme.colorScheme.primary
                                              : theme.colorScheme.primary
                                                  .withAlpha(140),
                                          borderRadius:
                                              const BorderRadius.vertical(
                                                  top: Radius.circular(3)),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  label,
                                  style:
                                      theme.textTheme.labelSmall?.copyWith(
                                    fontSize: 9,
                                    color: isActive
                                        ? theme.colorScheme.primary
                                        : theme.colorScheme.onSurface
                                            .withAlpha(150),
                                    fontWeight: isActive
                                        ? FontWeight.w700
                                        : FontWeight.normal,
                                  ),
                                  maxLines: 1,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _TrendTooltip extends StatelessWidget {
  final Map<String, dynamic> data;
  const _TrendTooltip({super.key, required this.data});

  static final _currency = NumberFormat('#,##0.00');

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final date = data['date'] as String? ?? '';
    final rev = (data['revenue'] as num?)?.toDouble() ?? 0;
    final rawTxn = data['transactions'] ??
        data['transaction_count'] ??
        data['order_count'];
    final txn = rawTxn is int ? rawTxn : (rawTxn as num?)?.toInt();
    final dateLabel = date.length >= 10
        ? DateFormat('EEE, d MMM').format(DateTime.parse(date))
        : date;

    return SizedBox(
      height: 32,
      child: Center(
        child: Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          decoration: BoxDecoration(
            color: theme.colorScheme.inverseSurface,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                dateLabel,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onInverseSurface.withAlpha(200),
                ),
              ),
              _divider(theme),
              Text(
                'RM ${_currency.format(rev)}',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.inversePrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (txn != null) ...[
                _divider(theme),
                Text(
                  '$txn txn${txn == 1 ? '' : 's'}',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onInverseSurface
                        .withAlpha(180),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _divider(ThemeData theme) => Container(
        width: 1,
        height: 10,
        margin: const EdgeInsets.symmetric(horizontal: 8),
        color: theme.colorScheme.onInverseSurface.withAlpha(60),
      );
}

class _PaymentBreakdownCard extends StatefulWidget {
  final List<Map<String, dynamic>> breakdown;
  final bool isTablet;
  const _PaymentBreakdownCard(
      {required this.breakdown, this.isTablet = false});

  @override
  State<_PaymentBreakdownCard> createState() =>
      _PaymentBreakdownCardState();
}

class _PaymentBreakdownCardState extends State<_PaymentBreakdownCard> {
  int? _touchedIndex;
  int _touchVersion = 0;

  static final _currency = NumberFormat('#,##0.00');

  static const _palette = [
    Color(0xFF6C8EBF),
    Color(0xFF82B366),
    Color(0xFFD6A55A),
    Color(0xFFAA6CB5),
    Color(0xFF6BB5C3),
    Color(0xFFD4776A),
  ];

  Widget _buildPieChart(
    ThemeData theme,
    List<PieChartSectionData> sections,
    double centerRadius,
    Map<String, dynamic>? touched,
    double touchedPct,
    int? txn,
  ) {
    return Stack(
      alignment: Alignment.center,
      children: [
        PieChart(
          PieChartData(
            sections: sections,
            centerSpaceRadius: centerRadius,
            sectionsSpace: 2,
            pieTouchData: PieTouchData(
              touchCallback: (event, response) {
                if (event is! FlTapUpEvent) return;
                setState(() {
                  final idx =
                      response?.touchedSection?.touchedSectionIndex;
                  if (idx == null || idx < 0) {
                    _touchedIndex = null;
                  } else {
                    _touchedIndex = _touchedIndex == idx ? null : idx;
                  }
                  _touchVersion++;
                });
              },
            ),
          ),
        ),
        IgnorePointer(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 150),
            child: touched != null
                ? Column(
                    key: ValueKey<int>(_touchVersion),
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${touchedPct.toStringAsFixed(1)}%',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: _palette[
                              _touchedIndex! % _palette.length],
                        ),
                      ),
                      if (txn != null)
                        Text(
                          '$txn txn${txn == 1 ? '' : 's'}',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.onSurface
                                .withAlpha(160),
                          ),
                        ),
                    ],
                  )
                : SizedBox.shrink(
                    key: ValueKey<int>(_touchVersion),
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildLegendItem(
      ThemeData theme, Map<String, dynamic> p, Color color, int i) {
    final isActive = _touchedIndex == i;
    return GestureDetector(
      onTap: () => setState(() {
        _touchedIndex = isActive ? null : i;
        _touchVersion++;
      }),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  p['payment_method'] as String? ?? '',
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontWeight: isActive
                        ? FontWeight.w700
                        : FontWeight.normal,
                    color: isActive
                        ? color
                        : theme.colorScheme.onSurface,
                  ),
                ),
                Text(
                  'RM ${_currency.format(p['amount'] ?? 0)}',
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontSize: 10,
                    color:
                        theme.colorScheme.onSurface.withAlpha(150),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final items = widget.breakdown;
    final centerRadius = widget.isTablet ? 60.0 : 52.0;
    final normalRadius = widget.isTablet ? 66.0 : 56.0;
    final touchedRadius = widget.isTablet ? 76.0 : 66.0;

    final sections = List.generate(items.length, (i) {
      final p = items[i];
      final pct = (p['percentage'] as num?)?.toDouble() ?? 0;
      final isTouched = _touchedIndex == i;
      return PieChartSectionData(
        value: pct,
        color: _palette[i % _palette.length],
        radius: isTouched ? touchedRadius : normalRadius,
        showTitle: false,
      );
    });

    final touched =
        (_touchedIndex != null &&
                _touchedIndex! >= 0 &&
                _touchedIndex! < items.length)
            ? items[_touchedIndex!]
            : null;
    final touchedPct = (touched?['percentage'] as num?)?.toDouble() ?? 0;
    final rawTxn = touched?['transactions'] ??
        touched?['transaction_count'] ??
        touched?['count'];
    final txn = rawTxn is int ? rawTxn : (rawTxn as num?)?.toInt();

    if (widget.isTablet) {
      return Card(
        color: theme.colorScheme.surfaceContainerHighest,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: SizedBox(
            height: 240,
            child: Row(
              children: [
                Expanded(
                  child: _buildPieChart(
                      theme, sections, centerRadius, touched, touchedPct, txn),
                ),
                const SizedBox(width: 16),
                SizedBox(
                  width: 160,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: List.generate(
                      items.length,
                      (i) => _buildLegendItem(
                          theme, items[i], _palette[i % _palette.length], i),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Mobile: pie chart above, legend below to avoid overlap
    return Card(
      color: theme.colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: 200,
              child: _buildPieChart(
                  theme, sections, centerRadius, touched, touchedPct, txn),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 16,
              runSpacing: 4,
              alignment: WrapAlignment.center,
              children: List.generate(
                items.length,
                (i) => _buildLegendItem(
                    theme, items[i], _palette[i % _palette.length], i),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final Widget? action;

  const _EmptyState({
    required this.icon,
    required this.title,
    required this.description,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 72, color: theme.colorScheme.primary),
            const SizedBox(height: 16),
            Text(title, style: theme.textTheme.headlineSmall),
            const SizedBox(height: 8),
            Text(
              description,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withAlpha(178),
              ),
              textAlign: TextAlign.center,
            ),
            if (action != null) ...[const SizedBox(height: 16), action!],
          ],
        ),
      ),
    );
  }
}
