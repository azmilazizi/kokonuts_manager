import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import '../../app/app_state.dart';
import '../../services/auth_service.dart';
import '../../services/auth_expiration_handler.dart';

class ShiftsTab extends StatefulWidget {
  final AppState state;

  const ShiftsTab({super.key, required this.state});

  @override
  State<ShiftsTab> createState() => _ShiftsTabState();
}

class _ShiftsTabState extends State<ShiftsTab>
    with AutomaticKeepAliveClientMixin {
  final List<Map<String, dynamic>> _items = [];
  bool _loading = false;
  bool _hasMore = true;
  int _page = 1;
  String? _error;
  String? _statusFilter; // null = all, 'open', 'closed'

  static final _currency = NumberFormat('#,##0.00');
  static final _dtFmt = DateFormat('d MMM y, h:mm a');

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _load(reset: true);
  }

  @override
  void didUpdateWidget(ShiftsTab old) {
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
      final params = <String, String>{
        'page': '$_page',
        'per_page': '20',
        if (wid != null) 'warehouse_id': '$wid',
        if (_statusFilter != null) 'status': _statusFilter!,
      };

      final uri = Uri.parse('$kManagerApiBase/shifts')
          .replace(queryParameters: params);
      final resp =
          await http.get(uri, headers: {'Authorization': 'Bearer $token'});

      if (resp.statusCode == 401) {
        AuthExpirationHandler().handleExpired();
        return;
      }

      final body = jsonDecode(resp.body) as Map<String, dynamic>;
      if (resp.statusCode != 200) {
        throw Exception(body['error'] ?? 'Failed to load shifts');
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
      });
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _openDetail(int shiftId) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => _ShiftDetailSheet(
        shiftId: shiftId,
        token: widget.state.token!,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final theme = Theme.of(context);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
          child: Row(
            children: [
              Expanded(
                child: Text('Shifts',
                    style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurface.withAlpha(178))),
              ),
              SegmentedButton<String?>(
                showSelectedIcon: false,
                style: SegmentedButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                segments: const [
                  ButtonSegment(value: null, label: Text('All')),
                  ButtonSegment(value: 'open', label: Text('Open')),
                  ButtonSegment(value: 'closed', label: Text('Closed')),
                ],
                selected: {_statusFilter},
                onSelectionChanged: (s) {
                  setState(() => _statusFilter = s.first);
                  _load(reset: true);
                },
              ),
            ],
          ),
        ),
        Expanded(
          child: _items.isEmpty && !_loading
              ? Center(
                  child: _error != null
                      ? Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.error_outline,
                                size: 72, color: theme.colorScheme.primary),
                            const SizedBox(height: 16),
                            Text('Failed to load',
                                style: theme.textTheme.headlineSmall),
                            const SizedBox(height: 8),
                            Text(_error!,
                                style: theme.textTheme.bodyMedium,
                                textAlign: TextAlign.center),
                            const SizedBox(height: 16),
                            TextButton(
                                onPressed: () => _load(reset: true),
                                child: const Text('Retry')),
                          ],
                        )
                      : Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.schedule,
                                size: 72, color: theme.colorScheme.primary),
                            const SizedBox(height: 16),
                            Text('No shifts found',
                                style: theme.textTheme.headlineSmall),
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
                            child:
                                Center(child: CircularProgressIndicator()),
                          );
                        }
                        final s = _items[i];
                        final isOpen = s['status'] == 'open';
                        DateTime? dt;
                        try {
                          dt = DateTime.parse(
                              s['opened_at'] as String? ?? '');
                        } catch (_) {}

                        return Card(
                          color: theme.colorScheme.surfaceContainerHighest,
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            onTap: () =>
                                _openDetail((s['id'] as num).toInt()),
                            leading: CircleAvatar(
                              backgroundColor: isOpen
                                  ? Colors.orange.withAlpha(40)
                                  : theme.colorScheme.outline.withAlpha(30),
                              child: Icon(
                                isOpen
                                    ? Icons.lock_open
                                    : Icons.lock_outline,
                                color: isOpen
                                    ? Colors.orange
                                    : theme.colorScheme.outline,
                                size: 20,
                              ),
                            ),
                            title: Text(
                                s['warehouse_name'] as String? ?? ''),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (dt != null)
                                  Text(_dtFmt.format(dt),
                                      style: theme.textTheme.bodySmall),
                                Text(
                                  '${s['transaction_count'] ?? 0} txns',
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
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                if ((s['cash_difference'] as num?) != null)
                                  Text(
                                    'Diff: RM ${_currency.format(s['cash_difference'])}',
                                    style:
                                        theme.textTheme.labelSmall?.copyWith(
                                      color: (s['cash_difference'] as num)
                                                  .toDouble() <
                                              0
                                          ? Colors.redAccent
                                          : Colors.greenAccent,
                                    ),
                                  ),
                              ],
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

class _ShiftDetailSheet extends StatefulWidget {
  final int shiftId;
  final String token;

  const _ShiftDetailSheet({required this.shiftId, required this.token});

  @override
  State<_ShiftDetailSheet> createState() => _ShiftDetailSheetState();
}

class _ShiftDetailSheetState extends State<_ShiftDetailSheet> {
  Map<String, dynamic>? _shift;
  bool _loading = true;
  String? _error;

  static final _currency = NumberFormat('#,##0.00');
  static final _dtFmt = DateFormat('d MMM y, h:mm a');

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final uri =
          Uri.parse('$kManagerApiBase/shifts/${widget.shiftId}');
      final resp = await http.get(uri,
          headers: {'Authorization': 'Bearer ${widget.token}'});
      final body = jsonDecode(resp.body) as Map<String, dynamic>;
      if (resp.statusCode == 200) {
        setState(() {
          _shift = body['data'] as Map<String, dynamic>?;
          _loading = false;
        });
      } else {
        setState(() {
          _error = body['error'] as String? ?? 'Failed to load';
          _loading = false;
        });
      }
    } catch (_) {
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
      initialChildSize: 0.75,
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
        final s = _shift!;
        final breakdown = (s['payment_breakdown'] as List? ?? [])
            .cast<Map<String, dynamic>>();
        final movements = (s['cash_movements'] as List? ?? [])
            .cast<Map<String, dynamic>>();
        DateTime? openedAt;
        DateTime? closedAt;
        try {
          openedAt = DateTime.parse(s['opened_at'] as String? ?? '');
        } catch (_) {}
        try {
          final ca = s['closed_at'];
          if (ca != null) closedAt = DateTime.parse(ca as String);
        } catch (_) {}

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
            Row(children: [
              Expanded(
                child: Text(s['warehouse_name'] as String? ?? '',
                    style: theme.textTheme.titleLarge),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: s['status'] == 'open'
                      ? Colors.orange.withAlpha(40)
                      : theme.colorScheme.outline.withAlpha(40),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  (s['status'] as String? ?? '').toUpperCase(),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: s['status'] == 'open'
                        ? Colors.orange
                        : theme.colorScheme.outline,
                  ),
                ),
              ),
            ]),
            const SizedBox(height: 4),
            if (openedAt != null)
              Text('Opened: ${_dtFmt.format(openedAt)}',
                  style: theme.textTheme.bodySmall),
            if (closedAt != null)
              Text('Closed: ${_dtFmt.format(closedAt)}',
                  style: theme.textTheme.bodySmall),
            const Divider(height: 24),
            _ShiftRow('Opened By', s['opened_by'] as String? ?? '—'),
            _ShiftRow('Closed By', s['closed_by'] as String? ?? '—'),
            _ShiftRow('Transactions', '${s['transaction_count'] ?? 0}'),
            _ShiftRow('Total Sales',
                'RM ${_currency.format(s['total_sales'] ?? 0)}'),
            _ShiftRow('Refunds',
                'RM ${_currency.format(s['total_refunds'] ?? 0)}',
                color: Colors.redAccent),
            _ShiftRow('Net Sales',
                'RM ${_currency.format(s['net_sales'] ?? 0)}',
                color: theme.colorScheme.primary,
                bold: true),
            _ShiftRow('Opening Cash',
                'RM ${_currency.format(s['opening_cash'] ?? 0)}'),
            if (s['closing_cash'] != null)
              _ShiftRow('Closing Cash',
                  'RM ${_currency.format(s['closing_cash'])}'),
            if (s['cash_difference'] != null)
              _ShiftRow(
                  'Cash Difference',
                  'RM ${_currency.format(s['cash_difference'])}',
                  color: (s['cash_difference'] as num).toDouble() < 0
                      ? Colors.redAccent
                      : Colors.greenAccent),
            if (breakdown.isNotEmpty) ...[
              const Divider(height: 24),
              Text('Payment Breakdown',
                  style: theme.textTheme.titleSmall),
              const SizedBox(height: 8),
              ...breakdown.map((p) => _ShiftRow(
                    p['payment_method'] as String? ?? '',
                    'RM ${_currency.format(p['amount'] ?? 0)}  (${p['count'] ?? 0})',
                  )),
            ],
            if (movements.isNotEmpty) ...[
              const Divider(height: 24),
              Text('Cash Movements', style: theme.textTheme.titleSmall),
              const SizedBox(height: 8),
              ...movements.map((m) {
                final isIn = m['type'] == 'in';
                return ListTile(
                  dense: true,
                  leading: Icon(
                    isIn ? Icons.add_circle_outline : Icons.remove_circle_outline,
                    color: isIn ? Colors.greenAccent : Colors.redAccent,
                    size: 20,
                  ),
                  title: Text(
                      'RM ${_currency.format(m['amount'] ?? 0)}'),
                  subtitle: m['note'] != null
                      ? Text(m['note'] as String)
                      : null,
                  contentPadding: EdgeInsets.zero,
                );
              }),
            ],
            const SizedBox(height: 24),
          ],
        );
      },
    );
  }
}

class _ShiftRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? color;
  final bool bold;

  const _ShiftRow(this.label, this.value, {this.color, this.bold = false});

  @override
  Widget build(BuildContext context) {
    final style = bold
        ? Theme.of(context)
            .textTheme
            .titleSmall
            ?.copyWith(color: color)
        : Theme.of(context)
            .textTheme
            .bodyMedium
            ?.copyWith(color: color);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [Text(label), Text(value, style: style)],
      ),
    );
  }
}
