import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../api_client.dart';
import '../state.dart';
import 'login_screen.dart';
import 'order_detail_screen.dart';

class CartScreen extends StatefulWidget {
  const CartScreen({super.key});

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  String _type = 'pickup';
  final _commentController = TextEditingController();
  bool _busy = false;

  Future<void> _submit() async {
    final auth = context.read<AuthModel>();
    if (!auth.isLoggedIn) {
      final ok = await Navigator.of(context).push<bool>(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
      if (ok != true || !mounted) return;
    }

    setState(() => _busy = true);
    final cart = context.read<CartModel>();
    final api = context.read<ApiClient>();
    try {
      final order = await api.createOrder(
        type: _type,
        comment: _commentController.text.trim(),
        items: cart.lines.map((l) => l.toPayload()).toList(),
      );
      cart.clear();
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => OrderDetailScreen(orderId: order.id)),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartModel>();

    return Scaffold(
      appBar: AppBar(title: const Text('Mon panier')),
      body: cart.isEmpty
          ? const Center(child: Text('Votre panier est vide'))
          : ListView(
              padding: const EdgeInsets.all(12),
              children: [
                for (var i = 0; i < cart.lines.length; i++)
                  Card(
                    child: ListTile(
                      title: Text(
                          '${cart.lines[i].product.name} — ${cart.lines[i].variant.name}'),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (cart.lines[i].customization.isNotEmpty)
                            Text(cart.lines[i].customization),
                          if (cart.lines[i].comment != null)
                            Text('« ${cart.lines[i].comment} »',
                                style: const TextStyle(
                                    fontStyle: FontStyle.italic)),
                          Text(formatCents(cart.lines[i].totalCents),
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold)),
                        ],
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.remove),
                            onPressed: () => context
                                .read<CartModel>()
                                .changeQuantity(i, -1),
                          ),
                          Text('${cart.lines[i].quantity}'),
                          IconButton(
                            icon: const Icon(Icons.add),
                            onPressed: () =>
                                context.read<CartModel>().changeQuantity(i, 1),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline),
                            onPressed: () =>
                                context.read<CartModel>().removeAt(i),
                          ),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(height: 12),
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(
                        value: 'pickup',
                        label: Text('À emporter'),
                        icon: Icon(Icons.shopping_bag)),
                    ButtonSegment(
                        value: 'dine_in',
                        label: Text('Sur place'),
                        icon: Icon(Icons.restaurant)),
                  ],
                  selected: {_type},
                  onSelectionChanged: (s) => setState(() => _type = s.first),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _commentController,
                  decoration: const InputDecoration(
                    labelText: 'Commentaire pour la pizzeria (facultatif)',
                    border: OutlineInputBorder(),
                  ),
                  maxLength: 500,
                ),
                const SizedBox(height: 80),
              ],
            ),
      bottomNavigationBar: cart.isEmpty
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: FilledButton.icon(
                  onPressed: _busy ? null : _submit,
                  icon: _busy
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.check),
                  label:
                      Text('Commander — ${formatCents(cart.totalCents)}'),
                  style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16)),
                ),
              ),
            ),
    );
  }
}
