import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models.dart';
import '../state.dart';

/// Personnalisation d'un produit : taille, ingrédients retirés,
/// suppléments, quantité et commentaire.
class ProductScreen extends StatefulWidget {
  final Product product;
  final List<Ingredient> allIngredients;

  const ProductScreen({super.key, required this.product, required this.allIngredients});

  @override
  State<ProductScreen> createState() => _ProductScreenState();
}

class _ProductScreenState extends State<ProductScreen> {
  late ProductVariant _variant = widget.product.variants.first;
  final Set<int> _removedIds = {};
  final Set<int> _extraIds = {};
  int _quantity = 1;
  final _commentController = TextEditingController();

  List<Ingredient> get _extrasChoices => widget.allIngredients
      .where((i) => !widget.product.ingredients.any((c) => c.id == i.id))
      .toList();

  int get _unitPriceCents =>
      _variant.priceCents +
      _extrasChoices
          .where((i) => _extraIds.contains(i.id))
          .fold(0, (sum, i) => sum + i.extraPriceCents);

  void _addToCart() {
    context.read<CartModel>().add(CartLine(
          product: widget.product,
          variant: _variant,
          extras: _extrasChoices.where((i) => _extraIds.contains(i.id)).toList(),
          removed: widget.product.ingredients
              .where((i) => _removedIds.contains(i.id))
              .toList(),
          quantity: _quantity,
          comment: _commentController.text.trim().isEmpty
              ? null
              : _commentController.text.trim(),
        ));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${widget.product.name} ajoutée au panier')),
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final product = widget.product;

    return Scaffold(
      appBar: AppBar(title: Text(product.name)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (product.description != null) ...[
            Text(product.description!,
                style: Theme.of(context).textTheme.bodyLarge),
            const SizedBox(height: 16),
          ],
          if (product.variants.length > 1) ...[
            Text('Taille', style: Theme.of(context).textTheme.titleMedium),
            RadioGroup<ProductVariant>(
              groupValue: _variant,
              onChanged: (v) => setState(() => _variant = v!),
              child: Column(
                children: [
                  for (final variant in product.variants)
                    RadioListTile<ProductVariant>(
                      title: Text(variant.name),
                      secondary: Text(formatCents(variant.priceCents)),
                      value: variant,
                    ),
                ],
              ),
            ),
            const Divider(),
          ],
          if (product.ingredients.isNotEmpty) ...[
            Text('Composition', style: Theme.of(context).textTheme.titleMedium),
            Text('Décochez ce que vous ne voulez pas',
                style: Theme.of(context).textTheme.bodySmall),
            for (final ingredient in product.ingredients)
              CheckboxListTile(
                title: Text(ingredient.name),
                value: !_removedIds.contains(ingredient.id),
                onChanged: (kept) => setState(() => kept!
                    ? _removedIds.remove(ingredient.id)
                    : _removedIds.add(ingredient.id)),
              ),
            const Divider(),
          ],
          if (_extrasChoices.isNotEmpty) ...[
            Text('Suppléments', style: Theme.of(context).textTheme.titleMedium),
            for (final ingredient in _extrasChoices)
              CheckboxListTile(
                title: Text(ingredient.name),
                subtitle: ingredient.extraPriceCents > 0
                    ? Text('+ ${formatCents(ingredient.extraPriceCents)}')
                    : null,
                value: _extraIds.contains(ingredient.id),
                onChanged: (checked) => setState(() => checked!
                    ? _extraIds.add(ingredient.id)
                    : _extraIds.remove(ingredient.id)),
              ),
            const Divider(),
          ],
          TextField(
            controller: _commentController,
            decoration: const InputDecoration(
              labelText: 'Commentaire (ex. : bien cuite)',
              border: OutlineInputBorder(),
            ),
            maxLength: 500,
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton.outlined(
                onPressed: _quantity > 1
                    ? () => setState(() => _quantity--)
                    : null,
                icon: const Icon(Icons.remove),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text('$_quantity',
                    style: Theme.of(context).textTheme.headlineSmall),
              ),
              IconButton.outlined(
                onPressed: _quantity < 20
                    ? () => setState(() => _quantity++)
                    : null,
                icon: const Icon(Icons.add),
              ),
            ],
          ),
          const SizedBox(height: 80),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: FilledButton.icon(
            onPressed: _addToCart,
            icon: const Icon(Icons.add_shopping_cart),
            label: Text(
                'Ajouter — ${formatCents(_unitPriceCents * _quantity)}'),
            style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16)),
          ),
        ),
      ),
    );
  }
}
