import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:intl/intl.dart';
import '../app/app_state.dart';
import '../app/app_state_scope.dart';
import '../firebase_options.dart';
import '../services/auth_service.dart';
import '../services/auth_expiration_handler.dart';
import '../services/push_notification_service.dart';
import '../services/session_manager.dart';
import '../widgets/app_logo.dart';
import 'tabs/dashboard_tab.dart';
import 'tabs/sales_tab.dart';
import 'tabs/shifts_tab.dart';
import 'tabs/reports_tab.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  static const _tabs = [
    (icon: Icons.dashboard_outlined, activeIcon: Icons.dashboard, label: 'Dashboard'),
    (icon: Icons.receipt_long_outlined, activeIcon: Icons.receipt_long, label: 'Sales'),
    (icon: Icons.schedule_outlined, activeIcon: Icons.schedule, label: 'Shifts'),
    (icon: Icons.bar_chart_outlined, activeIcon: Icons.bar_chart, label: 'Reports'),
  ];

  int _currentTab = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this)
      ..addListener(() {
        setState(() => _currentTab = _tabController.index);
      });
    WidgetsBinding.instance.addPostFrameCallback((_) => _setupPush());
  }

  Future<void> _setupPush() async {
    if (!mounted) return;
    final token = AppStateScope.read(context).token;
    if (token == null) return;
    await PushNotificationService().setup(
      authToken: token,
      vapidKey: DefaultFirebaseOptions.vapidKey,
      onMessage: _onForegroundMessage,
    );
  }

  static final _currency = NumberFormat('#,##0.00');
  static final _dtFmt = DateFormat('d MMM y, h:mm a');

  void _onForegroundMessage(RemoteMessage message) {
    if (!mounted) return;
    final data = message.data;
    final type = data['type'] ?? '';

    String title;
    List<String> lines;
    IconData icon;

    if (type == 'shift_opened') {
      final warehouse = data['warehouse_name'] as String? ?? '';
      title = 'Shift Opened${warehouse.isNotEmpty ? ' — $warehouse' : ''}';
      lines = [];
      final openedAt = data['opened_at'];
      if (openedAt != null) {
        try {
          lines.add(_dtFmt.format(DateTime.parse(openedAt).toLocal()));
        } catch (_) {}
      }
      final cash = double.tryParse(data['opening_cash']?.toString() ?? '');
      if (cash != null) lines.add('Opening: RM ${_currency.format(cash)}');
      icon = Icons.lock_open;
    } else if (type == 'shift_closed') {
      final warehouse = data['warehouse_name'] as String? ?? '';
      title = 'Shift Closed${warehouse.isNotEmpty ? ' — $warehouse' : ''}';
      lines = [];
      final closing = double.tryParse(data['closing_cash']?.toString() ?? '');
      if (closing != null) lines.add('Closing: RM ${_currency.format(closing)}');
      final diff = double.tryParse(data['cash_difference']?.toString() ?? '');
      if (diff != null) {
        final sign = diff >= 0 ? '+' : '';
        lines.add('Difference: $sign RM ${_currency.format(diff.abs())}');
      }
      icon = Icons.lock_outline;
    } else {
      title = message.notification?.title ?? 'Shift Update';
      lines = [if ((message.notification?.body ?? '').isNotEmpty) message.notification!.body!];
      icon = Icons.notifications;
    }

    ScaffoldMessenger.of(context).showMaterialBanner(
      MaterialBanner(
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
        leading: Icon(icon, color: Colors.orange),
        backgroundColor: const Color(0xFF2C2C2E),
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(title,
                style: const TextStyle(
                    fontWeight: FontWeight.w600, color: Color(0xFFE5E5EA))),
            ...lines.map((l) => Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(l,
                      style: const TextStyle(
                          fontSize: 13, color: Color(0xFFAAAAAA))),
                )),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () =>
                ScaffoldMessenger.of(context).hideCurrentMaterialBanner(),
            child:
                const Text('Dismiss', style: TextStyle(color: Colors.orange)),
          ),
        ],
      ),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _ensureWarehouseSelected();
  }

  void _ensureWarehouseSelected() {
    final state = AppStateScope.read(context);
    if (!state.isAdministrator &&
        state.warehouses.length > 1 &&
        state.selectedWarehouse == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _showWarehousePicker(state);
      });
    }
  }

  Future<void> _showWarehousePicker(AppState state) async {
    await showModalBottomSheet<void>(
      context: context,
      isDismissible: state.selectedWarehouse != null,
      enableDrag: state.selectedWarehouse != null,
      builder: (_) => _WarehousePickerSheet(
        warehouses: state.warehouses,
        isAdmin: state.isAdministrator,
        selected: state.selectedWarehouse,
        onSelect: (w) {
          state.setSelectedWarehouse(w);
          Navigator.pop(context);
        },
      ),
    );
  }

  Future<void> _logout() async {
    final state = AppStateScope.read(context);
    final token = state.token;
    if (token != null) {
      await PushNotificationService().deregister(token);
      await const AuthService().logout(token);
    }
    await SessionManager().clear();
    await AuthExpirationHandler().handleExpired();
  }

  void _showActionsSheet(BuildContext context, AppState state) {
    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.store_outlined),
              title: Text(
                state.selectedWarehouse?.name ??
                    (state.isAdministrator ? 'All Outlets' : 'Select Outlet'),
              ),
              subtitle: const Text('Switch outlet'),
              onTap: () {
                Navigator.pop(context);
                _showWarehousePicker(state);
              },
            ),
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.redAccent),
              title: const Text('Logout',
                  style: TextStyle(color: Colors.redAccent)),
              onTap: () {
                Navigator.pop(context);
                _logout();
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);
    final theme = Theme.of(context);
    final isWide = MediaQuery.of(context).size.width >= 600;

    final warehouseLabel = state.selectedWarehouse?.name ??
        (state.isAdministrator ? 'All Outlets' : '');

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: theme.colorScheme.surface,
        appBar: AppBar(
          backgroundColor: theme.colorScheme.surface,
          surfaceTintColor: Colors.transparent,
          titleSpacing: 12,
          title: Row(
            children: [
              const AppLogo(size: 28),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _tabs[_currentTab].label,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (warehouseLabel.isNotEmpty)
                      Text(
                        warehouseLabel,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.primary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
            ],
          ),
          actions: isWide
              ? [
                  IconButton(
                    icon: const Icon(Icons.store_outlined),
                    tooltip: 'Switch Outlet',
                    onPressed: () => _showWarehousePicker(state),
                  ),
                  IconButton(
                    icon: const Icon(Icons.logout),
                    tooltip: 'Logout',
                    onPressed: _logout,
                  ),
                ]
              : [
                  IconButton(
                    icon: const Icon(Icons.more_vert),
                    onPressed: () => _showActionsSheet(context, state),
                  ),
                ],
        ),
        bottomNavigationBar: Container(
          decoration: BoxDecoration(
            border: Border(
              top: BorderSide(
                color: theme.colorScheme.outline.withAlpha(80),
                width: 0.5,
              ),
            ),
          ),
          child: SafeArea(
            top: false,
            child: TabBar(
              controller: _tabController,
              indicatorColor: theme.colorScheme.primary,
              indicatorSize: TabBarIndicatorSize.tab,
              labelColor: theme.colorScheme.primary,
              unselectedLabelColor:
                  theme.colorScheme.onSurface.withAlpha(179),
              dividerHeight: 0,
              tabs: _tabs.map((t) {
                final active = _tabs.indexOf(t) == _currentTab;
                return SizedBox(
                  height: 60,
                  child: Icon(
                    active ? t.activeIcon : t.icon,
                    size: 26,
                  ),
                );
              }).toList(),
            ),
          ),
        ),
        body: TabBarView(
          controller: _tabController,
          children: [
            DashboardTab(state: state),
            SalesTab(state: state),
            ShiftsTab(state: state),
            ReportsTab(state: state),
          ],
        ),
      ),
    );
  }
}

class _WarehousePickerSheet extends StatelessWidget {
  final List<Warehouse> warehouses;
  final bool isAdmin;
  final Warehouse? selected;
  final void Function(Warehouse?) onSelect;

  const _WarehousePickerSheet({
    required this.warehouses,
    required this.isAdmin,
    required this.selected,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
            child: Text('Select Outlet', style: theme.textTheme.titleMedium),
          ),
          if (isAdmin)
            ListTile(
              leading: Icon(Icons.store,
                  color: selected == null
                      ? theme.colorScheme.primary
                      : null),
              title: const Text('All Outlets'),
              trailing: selected == null
                  ? Icon(Icons.check, color: theme.colorScheme.primary)
                  : null,
              onTap: () => onSelect(null),
            ),
          ...warehouses.map((w) {
            final isSelected = selected?.id == w.id;
            return ListTile(
              leading: Icon(Icons.store_outlined,
                  color: isSelected ? theme.colorScheme.primary : null),
              title: Text(w.name),
              subtitle: Text(w.code),
              trailing: isSelected
                  ? Icon(Icons.check, color: theme.colorScheme.primary)
                  : null,
              onTap: () => onSelect(w),
            );
          }),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
