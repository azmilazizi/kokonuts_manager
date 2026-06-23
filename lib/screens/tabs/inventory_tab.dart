import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../app/app_state.dart';
import '../../services/auth_service.dart';
import '../../services/auth_expiration_handler.dart';

class InventoryTab extends StatefulWidget {
  final AppState state;

  const InventoryTab({super.key, required this.state});

  @override
  State<InventoryTab> createState() => _InventoryTabState();
}

class _InventoryTabState extends State<InventoryTab>
    with AutomaticKeepAliveClientMixin {
  final List<Map<String, dynamic>> _items = [];
  bool _loading = false;
  bool _hasMore = true;
  int _page = 1;
  String? _error;
  String _search = '';
  bool _lowStockOnly = false;

  final _searchCtrl = TextEditingController();

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _load(reset: true);
  }

  @override
  void didUpdateWidget(InventoryTab old) {
    super.didUpdateWidget(old);
    if (old.state.selectedWarehouse?.id != widget.state.selectedWarehouse?.id) {
      _load(reset: true);
    }
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
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
        'per_page': '30',
        if (wid != null) 'warehouse_id': '$wid',
        if (_search.isNotEmpty) 'search': _search,
        if (_lowStockOnly) 'low_stock_only': '1',
      };

      final uri = Uri.parse('$kManagerApiBase/inventory')
          .replace(queryParameters: params);
      final resp =
          await http.get(uri, headers: {'Authorization': 'Bearer $token'});

      if (resp.statusCode == 401) {
        AuthExpirationHandler().handleExpired();
        return;
      }

      final body = jsonDecode(resp.body) as Map<String, dynamic>;
      if (resp.statusCode != 200) {
        throw Exception(body['error'] ?? 'Failed to load inventory');
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

  void _onSearchChanged(String value) {
    _search = value;
    _load(reset: true);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final theme = Theme.of(context);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchCtrl,
                  decoration: InputDecoration(
                    hintText: 'Search products…',
                    prefixIcon: const Icon(Icons.search, size: 20),
                    isDense: true,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    suffixIcon: _search.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            onPressed: () {
                              _searchCtrl.clear();
                              _onSearchChanged('');
                            },
                          )
                        : null,
                  ),
                  onChanged: _onSearchChanged,
                ),
              ),
              const SizedBox(width: 8),
              FilterChip(
                label: const Text('Low stock'),
                selected: _lowStockOnly,
                onSelected: (v) {
                  setState(() => _lowStockOnly = v);
                  _load(reset: true);
                },
                selectedColor: Colors.redAccent.withAlpha(40),
                checkmarkColor: Colors.redAccent,
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
                                textAlign: TextAlign.center,
                                style: theme.textTheme.bodyMedium),
                            const SizedBox(height: 16),
                            TextButton(
                                onPressed: () => _load(reset: true),
                                child: const Text('Retry')),
                          ],
                        )
                      : Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.inventory_2,
                                size: 72, color: theme.colorScheme.primary),
                            const SizedBox(height: 16),
                            Text('No products found',
                                style: theme.textTheme.headlineSmall),
                            const SizedBox(height: 8),
                            Text(
                              _lowStockOnly
                                  ? 'No low-stock items.'
                                  : 'Adjust your search or outlet filter.',
                              style: theme.textTheme.bodyMedium,
                            ),
                          ],
                        ),
                )
              : NotificationListener<ScrollNotification>(
                  onNotification: (n) {
                    if (n is ScrollEndNotification &&
                        n.metrics.extentAfter < 300) {
                      _load();
                    }
                    return false;
                  },
                  child: RefreshIndicator(
                    onRefresh: () => _load(reset: true),
                    color: theme.colorScheme.primary,
                    child: ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                      itemCount: _items.length + (_hasMore ? 1 : 0),
                      itemBuilder: (_, i) {
                        if (i == _items.length) {
                          return const Padding(
                            padding: EdgeInsets.all(16),
                            child:
                                Center(child: CircularProgressIndicator()),
                          );
                        }
                        final p = _items[i];
                        final isLow = p['is_low_stock'] == true ||
                            p['is_low_stock'] == 1;
                        final qty =
                            (p['quantity_on_hand'] as num?)?.toDouble() ?? 0;
                        final reorder =
                            (p['reorder_level'] as num?)?.toDouble();

                        return Card(
                          color: theme.colorScheme.surfaceContainerHighest,
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: isLow
                                  ? Colors.redAccent.withAlpha(40)
                                  : theme.colorScheme.primary.withAlpha(30),
                              child: Icon(
                                isLow
                                    ? Icons.warning_amber_rounded
                                    : Icons.inventory_2_outlined,
                                color: isLow
                                    ? Colors.redAccent
                                    : theme.colorScheme.primary,
                                size: 20,
                              ),
                            ),
                            title: Text(p['product_name'] as String? ?? ''),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if ((p['category'] as String?)?.isNotEmpty ==
                                    true)
                                  Text(
                                    p['category'] as String,
                                    style: theme.textTheme.bodySmall?.copyWith(
                                        color: theme.colorScheme.outline),
                                  ),
                                if ((p['sku'] as String?)?.isNotEmpty == true)
                                  Text(
                                    'SKU: ${p['sku']}',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                        color: theme.colorScheme.outline),
                                  ),
                              ],
                            ),
                            trailing: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  '${qty % 1 == 0 ? qty.toInt() : qty} ${p['unit'] ?? ''}',
                                  style: theme.textTheme.titleSmall?.copyWith(
                                    color: isLow
                                        ? Colors.redAccent
                                        : theme.colorScheme.primary,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                if (reorder != null)
                                  Text(
                                    'Min: ${reorder % 1 == 0 ? reorder.toInt() : reorder}',
                                    style: theme.textTheme.labelSmall?.copyWith(
                                      color: theme.colorScheme.outline,
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
