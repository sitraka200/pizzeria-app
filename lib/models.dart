/// Modèles calqués sur les réponses JSON de l'API pizzeria.
library;

class Category {
  final int id;
  final String name;
  final int position;

  Category({required this.id, required this.name, required this.position});

  factory Category.fromJson(Map<String, dynamic> json) => Category(
        id: json['id'] as int,
        name: json['name'] as String,
        position: (json['position'] ?? 0) as int,
      );
}

class Ingredient {
  final int id;
  final String name;
  final int extraPriceCents;
  final bool available;

  Ingredient({
    required this.id,
    required this.name,
    required this.extraPriceCents,
    this.available = true,
  });

  factory Ingredient.fromJson(Map<String, dynamic> json) => Ingredient(
        id: json['id'] as int,
        name: json['name'] as String,
        extraPriceCents: (json['extraPriceCents'] ?? 0) as int,
        available: (json['available'] ?? true) as bool,
      );
}

class ProductVariant {
  final int id;
  final String name;
  final int priceCents;

  ProductVariant({required this.id, required this.name, required this.priceCents});

  factory ProductVariant.fromJson(Map<String, dynamic> json) => ProductVariant(
        id: json['id'] as int,
        name: json['name'] as String,
        priceCents: (json['priceCents'] ?? 0) as int,
      );
}

class Product {
  final int id;
  final String name;
  final String? description;
  final int categoryId;
  final List<Ingredient> ingredients;
  final List<ProductVariant> variants;
  final bool available;
  final String? imageUrl;

  Product({
    required this.id,
    required this.name,
    this.description,
    required this.categoryId,
    required this.ingredients,
    required this.variants,
    this.available = true,
    this.imageUrl,
  });

  factory Product.fromJson(Map<String, dynamic> json) => Product(
        id: json['id'] as int,
        name: json['name'] as String,
        description: json['description'] as String?,
        categoryId: (json['category'] as Map<String, dynamic>)['id'] as int,
        ingredients: ((json['ingredients'] ?? []) as List)
            .map((i) => Ingredient.fromJson(i as Map<String, dynamic>))
            .toList(),
        variants: ((json['variants'] ?? []) as List)
            .map((v) => ProductVariant.fromJson(v as Map<String, dynamic>))
            .toList(),
        available: (json['available'] ?? true) as bool,
        imageUrl: json['imageUrl'] as String?,
      );

  int get minPriceCents => variants.isEmpty
      ? 0
      : variants.map((v) => v.priceCents).reduce((a, b) => a < b ? a : b);
}

class OrderItem {
  final String productName;
  final String variantName;
  final int quantity;
  final int unitPriceCents;
  final int totalCents;
  final List<Ingredient> extraIngredients;
  final List<Ingredient> removedIngredients;
  final String? comment;

  OrderItem({
    required this.productName,
    required this.variantName,
    required this.quantity,
    required this.unitPriceCents,
    required this.totalCents,
    required this.extraIngredients,
    required this.removedIngredients,
    this.comment,
  });

  factory OrderItem.fromJson(Map<String, dynamic> json) => OrderItem(
        productName: json['productName'] as String,
        variantName: json['variantName'] as String,
        quantity: json['quantity'] as int,
        unitPriceCents: json['unitPriceCents'] as int,
        totalCents: json['totalCents'] as int,
        extraIngredients: ((json['extraIngredients'] ?? []) as List)
            .map((i) => Ingredient.fromJson(i as Map<String, dynamic>))
            .toList(),
        removedIngredients: ((json['removedIngredients'] ?? []) as List)
            .map((i) => Ingredient.fromJson(i as Map<String, dynamic>))
            .toList(),
        comment: json['comment'] as String?,
      );
}

class Order {
  final int id;
  final String reference;
  final String type;
  final String status;
  final String? comment;
  final int totalCents;
  final List<OrderItem> items;
  final DateTime createdAt;

  Order({
    required this.id,
    required this.reference,
    required this.type,
    required this.status,
    this.comment,
    required this.totalCents,
    required this.items,
    required this.createdAt,
  });

  factory Order.fromJson(Map<String, dynamic> json) => Order(
        id: json['id'] as int,
        reference: json['reference'] as String,
        type: json['type'] as String,
        status: json['status'] as String,
        comment: json['comment'] as String?,
        totalCents: json['totalCents'] as int,
        items: ((json['items'] ?? []) as List)
            .map((i) => OrderItem.fromJson(i as Map<String, dynamic>))
            .toList(),
        createdAt: DateTime.parse(json['createdAt'] as String),
      );

  bool get isCancellable => status == 'placed' || status == 'confirmed';
}

/// Libellés français des statuts, dans l'ordre du cycle de vie.
const orderStatusFlow = ['placed', 'confirmed', 'paid', 'preparing', 'ready', 'delivered'];

const orderStatusLabels = {
  'placed': 'Envoyée',
  'confirmed': 'Confirmée',
  'paid': 'Payée',
  'preparing': 'En préparation',
  'ready': 'Prête !',
  'delivered': 'Récupérée',
  'cancelled': 'Annulée',
};
