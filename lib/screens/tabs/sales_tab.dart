import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import '../../app/app_state.dart';
import '../../services/auth_service.dart';
import '../../services/auth_expiration_handler.dart';

class SalesTab extends StatefulWidget {
  final AppState state;

  const SalesTab({super.key, required this.state});

  @override
  State<SalesTab> createState() => _SalesTabState();
}

class _SalesTabState extends State<SalesTab>
    with AutomaticKeepAliveClientMixin {
  final List<Map<String, dynamic>> _items = [];
  bool _loading = false;
  bool _hasMore = true;
  int _page = 1;
  String? _error;

  String _preset = 'Today';
  DateTimeRange _range = DateTimeRange(
    start: DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day),
    end: DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day),
  );

  String? _paymentFilter;
  String _sortBy = 'created_at';
  String _sortOrder = 'desc';
  final List<String> _paymentMethods = [];

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
          start: DateTime(lastOfLastMonth.year, lastOfLastMonth.month, 1),
          end: lastOfLastMonth,
        );
      default:
        return DateTimeRange(
            start: today.subtract(const Duration(days: 6)), end: today);
    }
  }

  static final _currency = NumberFormat('#,##0.00');
  static final _dtFmt = DateFormat('d MMM y, h:mm a');
  static final _dateFmt = DateFormat('d MMM');

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _load(reset: true);
  }

  @override
  void didUpdateWidget(SalesTab old) {
    super.didUpdateWidget(old);
    if (old.state.selectedWarehouse?.id != widget.state.selectedWarehouse?.id) {
      _load(reset: true);
    }
  }

  Future<void> _load({bool reset = false}) async {
    if (_loading) return;
    if (reset) {
      _items.clear();
      _page = 1;
      _hasMore = true;
    }
    if (!_hasMore) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final token = widget.state.token!;
      final wid = widget.state.selectedWarehouse?.id;
      final from = DateFormat('yyyy-MM-dd').format(_range.start);
      final to = DateFormat('yyyy-MM-dd').format(_range.end);

      final params = <String, String>{
        'date_from': from,
        'date_to': to,
        'page': '$_page',
        'per_page': '20',
        'sort_by': _sortBy,
        'sort_order': _sortOrder,
        if (wid != null) 'warehouse_id': '$wid',
        if (_paymentFilter != null) 'payment_method': _paymentFilter!,
      };
      final uri = Uri.parse('$kManagerApiBase/sales')
          .replace(queryParameters: params);
      final resp =
          await http.get(uri, headers: {'Authorization': 'Bearer $token'});

      if (resp.statusCode == 401) {
        AuthExpirationHandler().handleExpired();
        return;
      }

      final body = jsonDecode(resp.body) as Map<String, dynamic>;
      if (resp.statusCode != 200) {
        throw Exception(body['error'] ?? 'Failed to load sales');
      }

      final data =
          (body['data'] as List? ?? []).cast<Map<String, dynamic>>();
      final meta = body['meta'] as Map<String, dynamic>? ?? {};
      final totalPages = meta['total_pages'] as int? ?? 1;

      if (!mounted) return;
      setState(() {
        _items.addAll(data);
        _hasMore = _page < totalPages;
        _page++;
        for (final item in data) {
          final m = item['payment_method'] as String?;
          if (m != null && m.isNotEmpty && !_paymentMethods.contains(m)) {
            _paymentMethods.add(m);
            _paymentMethods.sort();
          }
        }
      });
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
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
        _load(reset: true);
      }
    } else {
      setState(() {
        _preset = preset;
        _range = _rangeForPreset(preset);
      });
      _load(reset: true);
    }
  }

  void _showDetail(Map<String, dynamic> receipt) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => ReceiptDetailSheet(
        receiptNumber: receipt['receipt_number'] as String,
        token: widget.state.token!,
      ),
    );
  }

  String get _sortLabel {
    switch ('${_sortBy}_$_sortOrder') {
      case 'created_at_desc':
        return 'Newest';
      case 'created_at_asc':
        return 'Oldest';
      case 'total_money_desc':
        return 'Highest';
      case 'total_money_asc':
        return 'Lowest';
      default:
        return 'Sort';
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final theme = Theme.of(context);
    final from = _dateFmt.format(_range.start);
    final to = _dateFmt.format(_range.end);

    if (_error != null && _items.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 72, color: theme.colorScheme.primary),
            const SizedBox(height: 16),
            Text('Failed to load', style: theme.textTheme.headlineSmall),
            const SizedBox(height: 8),
            Text(_error!, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            TextButton(
                onPressed: () => _load(reset: true), child: const Text('Retry')),
          ],
        ),
      );
    }

    return Column(
      children: [
        // Date preset chips
        Padding(
          padding: const EdgeInsets.only(top: 12, bottom: 4),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
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
        // Filter and sort row
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (_paymentMethods.isNotEmpty) ...[
                PopupMenuButton<String?>(
                  tooltip: 'Payment mode',
                  onSelected: (value) {
                    setState(() => _paymentFilter = value);
                    _load(reset: true);
                  },
                  itemBuilder: (_) => [
                    const PopupMenuItem(value: null, child: Text('All')),
                    ..._paymentMethods.map((m) =>
                        PopupMenuItem(value: m, child: Text(m))),
                  ],
                  child: Chip(
                    avatar: const Icon(Icons.payment, size: 14),
                    label: Text(
                      _paymentFilter ?? 'Payment',
                      style: theme.textTheme.labelSmall,
                    ),
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                  ),
                ),
                const SizedBox(width: 6),
              ],
              PopupMenuButton<String>(
                tooltip: 'Sort',
                onSelected: (value) {
                  final idx = value.lastIndexOf('_');
                  setState(() {
                    _sortBy = value.substring(0, idx);
                    _sortOrder = value.substring(idx + 1);
                  });
                  _load(reset: true);
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(
                      value: 'created_at_desc', child: Text('Newest First')),
                  PopupMenuItem(
                      value: 'created_at_asc', child: Text('Oldest First')),
                  PopupMenuItem(
                      value: 'total_money_desc',
                      child: Text('Amount: High → Low')),
                  PopupMenuItem(
                      value: 'total_money_asc',
                      child: Text('Amount: Low → High')),
                ],
                child: Chip(
                  avatar: const Icon(Icons.sort, size: 14),
                  label: Text(_sortLabel,
                      style: theme.textTheme.labelSmall),
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: _items.isEmpty && !_loading
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.receipt_long,
                          size: 72, color: theme.colorScheme.primary),
                      const SizedBox(height: 16),
                      Text('No sales found',
                          style: theme.textTheme.headlineSmall),
                      const SizedBox(height: 8),
                      Text('Try changing the date range.',
                          style: theme.textTheme.bodyMedium),
                    ],
                  ),
                )
              : NotificationListener<ScrollNotification>(
                  onNotification: (n) {
                    if (n is ScrollEndNotification &&
                        n.metrics.extentAfter < 200) {
                      _load();
                    }
                    return false;
                  },
                  child: RefreshIndicator(
                    onRefresh: () => _load(reset: true),
                    color: theme.colorScheme.primary,
                    child: ListView.builder(
                      padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
                      itemCount: _items.length + (_hasMore ? 1 : 0),
                      itemBuilder: (_, i) {
                        if (i == _items.length) {
                          return const Padding(
                            padding: EdgeInsets.all(16),
                            child: Center(child: CircularProgressIndicator()),
                          );
                        }
                        final r = _items[i];
                        final isRefund = r['receipt_type'] == 'REFUND';
                        final amount =
                            (r['total_money'] as num?)?.toDouble() ?? 0;
                        DateTime? dt;
                        try {
                          dt = DateTime.parse(
                              r['created_at'] as String? ?? '');
                        } catch (_) {}

                        return Card(
                          color: theme.colorScheme.surfaceContainerHighest,
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            onTap: () => _showDetail(r),
                            leading: CircleAvatar(
                              backgroundColor: isRefund
                                  ? Colors.redAccent.withAlpha(40)
                                  : theme.colorScheme.primary.withAlpha(40),
                              child: Icon(
                                isRefund
                                    ? Icons.keyboard_return
                                    : Icons.receipt_outlined,
                                color: isRefund
                                    ? Colors.redAccent
                                    : theme.colorScheme.primary,
                                size: 20,
                              ),
                            ),
                            title: Text(
                                r['receipt_number'] as String? ?? ''),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (dt != null)
                                  Text(_dtFmt.format(dt),
                                      style: theme.textTheme.bodySmall),
                                Text(
                                  r['payment_method'] as String? ?? '',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                            trailing: Text(
                              'RM ${_currency.format(amount)}',
                              style: theme.textTheme.titleSmall?.copyWith(
                                color: isRefund
                                    ? Colors.redAccent
                                    : theme.colorScheme.primary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
        ),
      ],
    );
  }
}

class ReceiptDetailSheet extends StatefulWidget {
  final String receiptNumber;
  final String token;

  const ReceiptDetailSheet({
    super.key,
    required this.receiptNumber,
    required this.token,
  });

  @override
  State<ReceiptDetailSheet> createState() => _ReceiptDetailSheetState();
}

class _ReceiptDetailSheetState extends State<ReceiptDetailSheet> {
  Map<String, dynamic>? _receipt;
  bool _loading = true;
  String? _error;

  static final _currency = NumberFormat('#,##0.00');

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final uri =
          Uri.parse('$kManagerApiBase/sales/${widget.receiptNumber}');
      final resp = await http.get(uri,
          headers: {'Authorization': 'Bearer ${widget.token}'});
      final body = jsonDecode(resp.body) as Map<String, dynamic>;
      if (resp.statusCode == 200) {
        setState(() {
          _receipt = body['data'] as Map<String, dynamic>?;
          _loading = false;
        });
      } else {
        setState(() {
          _error = body['error'] as String? ?? 'Failed to load';
          _loading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Connection error';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      maxChildSize: 0.95,
      minChildSize: 0.4,
      expand: false,
      builder: (_, ctrl) {
        if (_loading) {
          return const Center(child: CircularProgressIndicator());
        }
        if (_error != null) {
          return Center(child: Text(_error!));
        }
        final r = _receipt!;
        final items =
            (r['items'] as List? ?? []).cast<Map<String, dynamic>>();

        return ListView(
          controller: ctrl,
          padding: const EdgeInsets.all(20),
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: theme.colorScheme.outline.withAlpha(100),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Text(r['receipt_number'] as String? ?? '',
                style: theme.textTheme.titleLarge),
            const SizedBox(height: 4),
            Text(r['receipt_type'] as String? ?? '',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                )),
            const Divider(height: 24),
            ...items.map((item) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(item['product_name'] as String? ?? ''),
                            Text(
                              '× ${item['quantity']}  @  RM ${_currency.format(item['unit_price'] ?? 0)}',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        'RM ${_currency.format(item['total_money'] ?? 0)}',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                )),
            const Divider(height: 24),
            _TotalsRow(
                label: 'Subtotal',
                value: 'RM ${_currency.format(r['subtotal'] ?? 0)}'),
            if ((r['total_discount'] as num? ?? 0) > 0)
              _TotalsRow(
                  label: 'Discount',
                  value:
                      '- RM ${_currency.format(r['total_discount'] ?? 0)}',
                  color: Colors.redAccent),
            if ((r['total_tax'] as num? ?? 0) > 0)
              _TotalsRow(
                  label: 'Tax',
                  value: 'RM ${_currency.format(r['total_tax'] ?? 0)}'),
            _TotalsRow(
              label: 'Total',
              value: 'RM ${_currency.format(r['total_money'] ?? 0)}',
              bold: true,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(height: 12),
            Row(children: [
              const Icon(Icons.payment, size: 16),
              const SizedBox(width: 8),
              Text(r['payment_method'] as String? ?? '',
                  style: theme.textTheme.bodyMedium),
            ]),
            if (r['cashier_name'] != null) ...[
              const SizedBox(height: 4),
              Row(children: [
                const Icon(Icons.person_outline, size: 16),
                const SizedBox(width: 8),
                Text(r['cashier_name'] as String,
                    style: theme.textTheme.bodyMedium),
              ]),
            ],
            const SizedBox(height: 24),
          ],
        );
      },
    );
  }
}

class _TotalsRow extends StatelessWidget {
  final String label;
  final String value;
  final bool bold;
  final Color? color;

  const _TotalsRow({
    required this.label,
    required this.value,
    this.bold = false,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final style = bold
        ? Theme.of(context).textTheme.titleMedium?.copyWith(color: color)
        : Theme.of(context).textTheme.bodyMedium?.copyWith(color: color);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [Text(label), Text(value, style: style)],
      ),
    );
  }
}
