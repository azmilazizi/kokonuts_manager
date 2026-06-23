import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import '../../app/app_state.dart';
import '../../services/auth_service.dart';
import '../../services/auth_expiration_handler.dart';

class ReportsTab extends StatefulWidget {
  final AppState state;

  const ReportsTab({super.key, required this.state});

  @override
  State<ReportsTab> createState() => _ReportsTabState();
}

class _ReportsTabState extends State<ReportsTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return _TopProductsView(state: widget.state);
  }
}

class _TopProductsView extends StatefulWidget {
  final AppState state;

  const _TopProductsView({required this.state});

  @override
  State<_TopProductsView> createState() => _TopProductsViewState();
}

class _TopProductsViewState extends State<_TopProductsView> {
  List<Map<String, dynamic>> _products = [];
  bool _loading = false;
  String? _error;

  String _itemType = 'products'; // 'products' or 'modifiers'
  String _searchQuery = '';
  String _displaySortBy = 'revenue'; // 'revenue', 'quantity', 'name'
  bool _displaySortAsc = false;
  final _searchController = TextEditingController();

  String _preset = 'Today';
  DateTimeRange _range = DateTimeRange(
    start: DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day),
    end: DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day),
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
          start: DateTime(lastOfLastMonth.year, lastOfLastMonth.month, 1),
          end: lastOfLastMonth,
        );
      default:
        return DateTimeRange(
            start: today.subtract(const Duration(days: 29)), end: today);
    }
  }

  static final _currency = NumberFormat('#,##0.00');
  static final _qty = NumberFormat('#,##0.##');
  static final _dateFmt = DateFormat('d MMM');

  List<Map<String, dynamic>> get _displayItems {
    var items = _searchQuery.isEmpty
        ? List<Map<String, dynamic>>.from(_products)
        : _products.where((p) {
            final name = (p['product_name'] as String? ?? '').toLowerCase();
            return name.contains(_searchQuery.toLowerCase());
          }).toList();

    items.sort((a, b) {
      int cmp;
      switch (_displaySortBy) {
        case 'name':
          cmp = (a['product_name'] as String? ?? '')
              .compareTo(b['product_name'] as String? ?? '');
          break;
        case 'quantity':
          cmp = ((a['quantity_sold'] as num?) ?? 0)
              .compareTo((b['quantity_sold'] as num?) ?? 0);
          break;
        default:
          cmp = ((a['revenue'] as num?) ?? 0)
              .compareTo((b['revenue'] as num?) ?? 0);
      }
      return _displaySortAsc ? cmp : -cmp;
    });

    return items;
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(_TopProductsView old) {
    super.didUpdateWidget(old);
    if (old.state.selectedWarehouse?.id != widget.state.selectedWarehouse?.id) {
      _load();
    }
  }

  Future<void> _load() async {
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
        'limit': '100',
        if (wid != null) 'warehouse_id': '$wid',
      };

      final uri = Uri.parse('$kManagerApiBase/reports/top-products')
          .replace(queryParameters: params);
      final resp =
          await http.get(uri, headers: {'Authorization': 'Bearer $token'});

      if (resp.statusCode == 401) {
        AuthExpirationHandler().handleExpired();
        return;
      }

      final body = jsonDecode(resp.body) as Map<String, dynamic>;
      if (resp.statusCode != 200) {
        throw Exception(body['error'] ?? 'Failed to load');
      }

      if (!mounted) return;
      setState(() {
        _products =
            (body['data'] as List? ?? []).cast<Map<String, dynamic>>();
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

  String get _sortLabel {
    final dir = _displaySortAsc ? '↑' : '↓';
    switch (_displaySortBy) {
      case 'name':
        return 'Name $dir';
      case 'quantity':
        return 'Qty $dir';
      default:
        return 'Revenue $dir';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final from = _dateFmt.format(_range.start);
    final to = _dateFmt.format(_range.end);
    final items = _displayItems;

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
        // Type toggle + sort
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 4),
          child: Row(
            children: [
              SegmentedButton<String>(
                showSelectedIcon: false,
                style: SegmentedButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                segments: const [
                  ButtonSegment(value: 'products', label: Text('Products')),
                  ButtonSegment(
                      value: 'modifiers', label: Text('Modifiers')),
                ],
                selected: {_itemType},
                onSelectionChanged: (s) {
                  setState(() => _itemType = s.first);
                  _load();
                },
              ),
              const Spacer(),
              PopupMenuButton<String>(
                tooltip: 'Sort',
                onSelected: (value) {
                  if (value == _displaySortBy) {
                    setState(() => _displaySortAsc = !_displaySortAsc);
                  } else {
                    setState(() {
                      _displaySortBy = value;
                      _displaySortAsc = false;
                    });
                  }
                },
                itemBuilder: (_) => [
                  PopupMenuItem(
                    value: 'revenue',
                    child: Row(children: [
                      const Text('Revenue'),
                      if (_displaySortBy == 'revenue') ...[
                        const Spacer(),
                        Icon(
                          _displaySortAsc
                              ? Icons.arrow_upward
                              : Icons.arrow_downward,
                          size: 16,
                        ),
                      ],
                    ]),
                  ),
                  PopupMenuItem(
                    value: 'quantity',
                    child: Row(children: [
                      const Text('Qty Sold'),
                      if (_displaySortBy == 'quantity') ...[
                        const Spacer(),
                        Icon(
                          _displaySortAsc
                              ? Icons.arrow_upward
                              : Icons.arrow_downward,
                          size: 16,
                        ),
                      ],
                    ]),
                  ),
                  PopupMenuItem(
                    value: 'name',
                    child: Row(children: [
                      const Text('Name'),
                      if (_displaySortBy == 'name') ...[
                        const Spacer(),
                        Icon(
                          _displaySortAsc
                              ? Icons.arrow_upward
                              : Icons.arrow_downward,
                          size: 16,
                        ),
                      ],
                    ]),
                  ),
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
        // Search bar
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
          child: TextField(
            controller: _searchController,
            onChanged: (v) => setState(() => _searchQuery = v),
            decoration: InputDecoration(
              hintText: 'Search by item name…',
              prefixIcon: const Icon(Icons.search, size: 20),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 18),
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _searchQuery = '');
                      },
                    )
                  : null,
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(vertical: 10),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24)),
            ),
          ),
        ),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.error_outline,
                              size: 72, color: theme.colorScheme.primary),
                          const SizedBox(height: 16),
                          Text(_error!, textAlign: TextAlign.center),
                          const SizedBox(height: 16),
                          TextButton(
                              onPressed: _load,
                              child: const Text('Retry')),
                        ],
                      ),
                    )
                  : items.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.bar_chart,
                                  size: 72,
                                  color: theme.colorScheme.primary),
                              const SizedBox(height: 16),
                              Text(
                                _searchQuery.isEmpty
                                    ? 'No products found'
                                    : 'No results for "$_searchQuery"',
                                style: theme.textTheme.headlineSmall,
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        )
                      : RefreshIndicator(
                          onRefresh: _load,
                          color: theme.colorScheme.primary,
                          child: ListView.builder(
                            padding:
                                const EdgeInsets.fromLTRB(12, 4, 12, 24),
                            itemCount: items.length,
                            itemBuilder: (_, i) {
                              final p = items[i];
                              return Card(
                                color: theme.colorScheme
                                    .surfaceContainerHighest,
                                margin: const EdgeInsets.only(bottom: 8),
                                child: ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor:
                                        theme.colorScheme.primary.withAlpha(30),
                                    child: Text(
                                      '${i + 1}',
                                      style: TextStyle(
                                        color: theme.colorScheme.primary,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  title: Text(
                                      p['product_name'] as String? ?? ''),
                                  subtitle: Text(
                                    p['category'] as String? ?? '',
                                    style: theme.textTheme.bodySmall,
                                  ),
                                  trailing: Column(
                                    mainAxisAlignment:
                                        MainAxisAlignment.center,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        'RM ${_currency.format(p['revenue'] ?? 0)}',
                                        style: theme.textTheme.bodySmall
                                            ?.copyWith(
                                          color: theme.colorScheme.primary,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      Text(
                                        '${_qty.format(p['quantity_sold'] ?? 0)} sold',
                                        style: theme.textTheme.labelSmall,
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
        ),
      ],
    );
  }
}
