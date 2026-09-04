import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../api_client.dart';
import '../models.dart';
import '../state.dart';

/// Suivi d'une commande : statut rafraîchi automatiquement toutes les 15 s
/// jusqu'à la fin du cycle (prête/récupérée/annulée).
class OrderDetailScreen extends StatefulWidget {
  final int orderId;

  const OrderDetailScreen({super.key, required this.orderId});

  @override
  State<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends State<OrderDetailScreen> {
  Order? _order;
  String? _error;
  Timer? _timer;
  bool _cancelling = false;

  @override
  void initState() {
    super.initState();
    _load();
    _timer = Timer.periodic(const Duration(seconds: 15), (_) => _load());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final order = await context.read<ApiClient>().fetchOrder(widget.orderId);
      if (!mounted) return;
      setState(() {
        _order = order;
        _error = null;
      });
      if (order.status == 'delivered' || order.status == 'cancelled') {
        _timer?.cancel();
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  Future<void> _cancel() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Annuler la commande ?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Non')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Oui, annuler')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _cancelling = true);
    try {
      final order =
          await context.read<ApiClient>().cancelOrder(widget.orderId);
      if (mounted) setState(() => _order = order);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {
      if (mounted) setState(() => _cancelling = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final order = _order;

    return Scaffold(
      appBar: AppBar(title: Text(order?.reference ?? 'Commande')),
      body: order == null
          ? Center(
              child: _error != null
                  ? Text('Erreur : $_error')
                  : const CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (order.status == 'cancelled')
                  Card(
                    color: Colors.red.shade50,
                    child: const Padding(
                      padding: EdgeInsets.all(16),
                      child: Text('Commande annulée',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  )
                else
                  _StatusStepper(status: order.status),
                const SizedBox(height: 16),
                Text('Détail', style: Theme.of(context).textTheme.titleMedium),
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
                        if (item.comment != null) Text('« ${item.comment} »'),
                      ],
                    ),
                    trailing: Text(formatCents(item.totalCents)),
                  ),
                const Divider(),
                ListTile(
                  title: const Text('Total',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  trailing: Text(formatCents(order.totalCents),
                      style: Theme.of(context).textTheme.titleLarge),
                ),
                if (order.comment != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text('Commentaire : ${order.comment}'),
                  ),
                const SizedBox(height: 16),
                if (order.isCancellable)
                  OutlinedButton.icon(
                    onPressed: _cancelling ? null : _cancel,
                    icon: const Icon(Icons.cancel_outlined),
                    label: const Text('Annuler la commande'),
                  ),
              ],
            ),
    );
  }
}

class _StatusStepper extends StatelessWidget {
  final String status;

  const _StatusStepper({required this.status});

  @override
  Widget build(BuildContext context) {
    final currentIndex = orderStatusFlow.indexOf(status);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            for (var i = 0; i < orderStatusFlow.length; i++)
              Row(
                children: [
                  Icon(
                    i < currentIndex
                        ? Icons.check_circle
                        : i == currentIndex
                            ? Icons.radio_button_checked
                            : Icons.radio_button_unchecked,
                    color: i <= currentIndex
                        ? Theme.of(context).colorScheme.primary
                        : Colors.grey,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    orderStatusLabels[orderStatusFlow[i]]!,
                    style: TextStyle(
                      fontWeight:
                          i == currentIndex ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
