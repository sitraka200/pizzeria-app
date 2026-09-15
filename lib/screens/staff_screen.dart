import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../api_client.dart';
import '../models.dart';
import '../state.dart';

/// Écran caisse (ROLE_STAFF) : file des commandes filtrée par statut,
/// rafraîchie toutes les 10 s, avec les actions du cycle de vie.
class StaffScreen extends StatefulWidget {
  const StaffScreen({super.key});

  @override
  State<StaffScreen> createState() => _StaffScreenState();
}

/// Onglets de la caisse : libellé → statut API (null = toutes).
const _filters = <(String, String?)>[
  ('Nouvelles', 'placed'),
  ('À encaisser', 'confirmed'),
  ('À lancer', 'paid'),
  ('En cuisine', 'preparing'),
  ('Prêtes', 'ready'),
  ('Toutes', null),
];

/// Actions possibles par statut : transition API → (libellé, icône, destructif).
const _actions = <String, List<(String, String, IconData, bool)>>{
  'placed': [
    ('confirm', 'Confirmer', Icons.check, false),
    ('cancel', 'Refuser', Icons.close, true),
  ],
  'confirmed': [
    ('pay', 'Encaisser (espèces)', Icons.euro, false),
    ('cancel', 'Refuser', Icons.close, true),
  ],
  'paid': [('prepare', 'Envoyer en cuisine', Icons.soup_kitchen, false)],
  'preparing': [('mark_ready', 'Prête !', Icons.notifications_active, false)],
  'ready': [('deliver', 'Remise au client', Icons.handshake, false)],
};

class _StaffScreenState extends State<StaffScreen> {
  int _filterIndex = 0;
  List<Order>? _orders;
  String? _error;
  Timer? _timer;
  final Set<int> _busyOrders = {};

  @override
  void initState() {
    super.initState();
    _load();
    _timer = Timer.periodic(const Duration(seconds: 10), (_) => _load());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final orders = await context
          .read<ApiClient>()
          .fetchOrders(status: _filters[_filterIndex].$2);
      if (!mounted) return;
      setState(() {
        _orders = orders;
        _error = null;
      });
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  Future<void> _apply(Order order, String transition) async {
    setState(() => _busyOrders.add(order.id));
    try {
      await context.read<ApiClient>().applyTransition(order.id, transition);
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {
      if (mounted) setState(() => _busyOrders.remove(order.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final orders = _orders;

    return Scaffold(
      appBar: AppBar(title: const Text('🧾 Caisse')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (var i = 0; i < _filters.length; i++)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: FilterChip(
                        label: Text(_filters[i].$1),
                        selected: _filterIndex == i,
                        onSelected: (_) {
                          setState(() {
                            _filterIndex = i;
                            _orders = null;
                          });
                          _load();
                        },
                      ),
                    ),
                ],
              ),
            ),
          ),
          Expanded(
            child: orders == null
                ? Center(
                    child: _error != null
                        ? Text('Erreur : $_error')
                        : const CircularProgressIndicator())
                : orders.isEmpty
                    ? const Center(child: Text('Aucune commande ici 👍'))
                    : RefreshIndicator(
                        onRefresh: _load,
                        child: ListView.separated(
                          padding: const EdgeInsets.all(12),
                          itemCount: orders.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 8),
                          itemBuilder: (context, index) => _OrderCard(
                            order: orders[index],
                            busy: _busyOrders.contains(orders[index].id),
                            onAction: _apply,
                          ),
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}

class _OrderCard extends StatelessWidget {
  final Order order;
  final bool busy;
  final Future<void> Function(Order, String) onAction;

  const _OrderCard({required this.order, required this.busy, required this.onAction});

  @override
  Widget build(BuildContext context) {
    final actions = _actions[order.status] ?? const [];
    final time = DateFormat.Hm('fr_FR').format(order.createdAt.toLocal());

    return Card(
      child: ExpansionTile(
        title: Row(
          children: [
            Text(order.reference,
                style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(order.customerName ?? '',
                  overflow: TextOverflow.ellipsis),
            ),
            Chip(
              visualDensity: VisualDensity.compact,
              label: Text(orderStatusLabels[order.status] ?? order.status),
              backgroundColor: order.status == 'ready'
                  ? Colors.green.shade100
                  : order.status == 'cancelled'
                      ? Colors.red.shade100
                      : null,
            ),
          ],
        ),
        subtitle: Text(
            '$time · ${order.type == 'pickup' ? 'à emporter' : 'sur place'}'
            ' · ${formatCents(order.totalCents)}'),
        children: [
          for (final item in order.items)
            ListTile(
              dense: true,
              title: Text(
                  '${item.quantity} × ${item.productName} (${item.variantName})'),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final extra in item.extraIngredients)
                    Text('+ ${extra.name}'),
                  for (final removed in item.removedIngredients)
                    Text('sans ${removed.name}'),
                  if (item.comment != null)
                    Text('« ${item.comment} »',
                        style: const TextStyle(fontStyle: FontStyle.italic)),
                ],
              ),
              trailing: Text(formatCents(item.totalCents)),
            ),
          if (order.comment != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('Commentaire client : ${order.comment}',
                    style: const TextStyle(fontStyle: FontStyle.italic)),
              ),
            ),
          if (order.customerPhone != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('📞 ${order.customerPhone}'),
              ),
            ),
          if (actions.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final (transition, label, icon, destructive) in actions)
                    destructive
                        ? OutlinedButton.icon(
                            onPressed:
                                busy ? null : () => onAction(order, transition),
                            icon: Icon(icon),
                            label: Text(label),
                            style: OutlinedButton.styleFrom(
                                foregroundColor:
                                    Theme.of(context).colorScheme.error),
                          )
                        : FilledButton.icon(
                            onPressed:
                                busy ? null : () => onAction(order, transition),
                            icon: Icon(icon),
                            label: Text(label),
                          ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
