import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../api_client.dart';
import '../models.dart';
import '../state.dart';
import 'order_detail_screen.dart';

class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key});

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  late Future<List<Order>> _future;

  @override
  void initState() {
    super.initState();
    _future = context.read<ApiClient>().fetchOrders();
  }

  Future<void> _refresh() async {
    setState(() => _future = context.read<ApiClient>().fetchOrders());
    await _future;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mes commandes'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Se déconnecter',
            onPressed: () async {
              await context.read<AuthModel>().logout();
              if (context.mounted) Navigator.of(context).pop();
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: FutureBuilder<List<Order>>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Center(child: Text('Erreur : ${snapshot.error}'));
            }
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final orders = snapshot.data!;
            if (orders.isEmpty) {
              return const Center(child: Text('Aucune commande pour l\'instant'));
            }
            return ListView.separated(
              padding: const EdgeInsets.all(12),
              itemCount: orders.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final order = orders[index];
                return Card(
                  child: ListTile(
                    title: Text(order.reference,
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text(
                        '${order.items.length} article(s) · ${formatCents(order.totalCents)}'),
                    trailing: Chip(
                      label: Text(orderStatusLabels[order.status] ?? order.status),
                      backgroundColor: order.status == 'ready'
                          ? Colors.green.shade100
                          : order.status == 'cancelled'
                              ? Colors.red.shade100
                              : null,
                    ),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                          builder: (_) => OrderDetailScreen(orderId: order.id)),
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
