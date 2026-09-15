import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../api_client.dart';
import '../models.dart';
import '../state.dart';
import 'cart_screen.dart';
import 'login_screen.dart';
import 'orders_screen.dart';
import 'product_screen.dart';
import 'staff_screen.dart';

class MenuScreen extends StatefulWidget {
  const MenuScreen({super.key});

  @override
  State<MenuScreen> createState() => _MenuScreenState();
}

class _MenuScreenState extends State<MenuScreen> {
  late Future<(List<Category>, List<Product>, List<Ingredient>)> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<(List<Category>, List<Product>, List<Ingredient>)> _load() async {
    final api = context.read<ApiClient>();
    final results = await Future.wait([
      api.fetchCategories(),
      api.fetchProducts(),
      api.fetchIngredients(),
    ]);
    return (
      results[0] as List<Category>,
      results[1] as List<Product>,
      results[2] as List<Ingredient>,
    );
  }

  Future<void> _openOrders() async {
    final auth = context.read<AuthModel>();
    if (!auth.isLoggedIn) {
      final ok = await Navigator.of(context).push<bool>(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
      if (ok != true || !mounted) return;
    }
    if (!mounted) return;
    // Un membre du staff arrive directement sur la caisse.
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => context.read<AuthModel>().isStaff
            ? const StaffScreen()
            : const OrdersScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartModel>();

    return FutureBuilder(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Scaffold(
            appBar: AppBar(title: const Text('Good Pizza')),
            body: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Impossible de charger le menu.\n${snapshot.error}',
                      textAlign: TextAlign.center),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: () => setState(() => _future = _load()),
                    child: const Text('Réessayer'),
                  ),
                ],
              ),
            ),
          );
        }
        if (!snapshot.hasData) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        final (categories, products, ingredients) = snapshot.data!;
        final tabs = categories
            .where((c) => products.any((p) => p.categoryId == c.id))
            .toList();

        return DefaultTabController(
          length: tabs.length,
          child: Scaffold(
            appBar: AppBar(
              title: const Text('🍕 Good Pizza'),
              actions: [
                if (context.watch<AuthModel>().isStaff)
                  IconButton(
                    icon: const Icon(Icons.point_of_sale),
                    tooltip: 'Caisse',
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const StaffScreen()),
                    ),
                  ),
                IconButton(
                  icon: const Icon(Icons.receipt_long),
                  tooltip: 'Mes commandes',
                  onPressed: _openOrders,
                ),
                IconButton(
                  icon: Badge(
                    isLabelVisible: cart.itemCount > 0,
                    label: Text('${cart.itemCount}'),
                    child: const Icon(Icons.shopping_cart),
                  ),
                  tooltip: 'Panier',
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const CartScreen()),
                  ),
                ),
              ],
              bottom: TabBar(
                isScrollable: true,
                tabs: [for (final c in tabs) Tab(text: c.name)],
              ),
            ),
            body: TabBarView(
              children: [
                for (final category in tabs)
                  _ProductList(
                    products:
                        products.where((p) => p.categoryId == category.id).toList(),
                    allIngredients: ingredients,
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ProductList extends StatelessWidget {
  final List<Product> products;
  final List<Ingredient> allIngredients;

  const _ProductList({required this.products, required this.allIngredients});

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: products.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final product = products[index];
        final composition = product.ingredients.map((i) => i.name).join(', ');
        return Card(
          child: ListTile(
            title: Text(product.name,
                style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text(
              composition.isNotEmpty ? composition : (product.description ?? ''),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: Text('dès ${formatCents(product.minPriceCents)}',
                style: Theme.of(context).textTheme.titleMedium),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => ProductScreen(
                  product: product,
                  allIngredients: allIngredients,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
