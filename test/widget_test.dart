import 'package:flutter_test/flutter_test.dart';
import 'package:pizzeria_app/models.dart';
import 'package:pizzeria_app/state.dart';

void main() {
  final margherita = Product(
    id: 1,
    name: 'Margherita',
    categoryId: 1,
    ingredients: [Ingredient(id: 14, name: 'basilic', extraPriceCents: 0)],
    variants: [ProductVariant(id: 3, name: 'Grande', priceCents: 1300)],
  );
  final chorizo = Ingredient(id: 8, name: 'chorizo', extraPriceCents: 200);

  test('le total du panier inclut les suppléments et la quantité', () {
    final cart = CartModel();
    cart.add(CartLine(
      product: margherita,
      variant: margherita.variants.first,
      extras: [chorizo],
      quantity: 2,
    ));

    expect(cart.itemCount, 2);
    expect(cart.totalCents, (1300 + 200) * 2); // 30,00 €
  });

  test('le payload envoyé à l\'API contient la personnalisation', () {
    final line = CartLine(
      product: margherita,
      variant: margherita.variants.first,
      extras: [chorizo],
      removed: margherita.ingredients,
      comment: 'bien cuite',
    );

    expect(line.toPayload(), {
      'variantId': 3,
      'quantity': 1,
      'extraIngredientIds': [8],
      'removedIngredientIds': [14],
      'comment': 'bien cuite',
    });
  });
}
