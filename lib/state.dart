import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';

import 'api_client.dart';
import 'models.dart';

final _euros = NumberFormat.currency(locale: 'fr_FR', symbol: '€');

String formatCents(int cents) => _euros.format(cents / 100);

/// État d'authentification partagé dans l'app.
class AuthModel extends ChangeNotifier {
  final ApiClient api;

  AuthModel(this.api);

  bool get isLoggedIn => api.isLoggedIn;

  bool get isStaff => api.isStaff;

  Future<void> login(String email, String password) async {
    await api.login(email, password);
    notifyListeners();
  }

  Future<void> register(String email, String password, String name, String? phone) async {
    await api.register(email, password, name, phone);
    notifyListeners();
  }

  Future<void> logout() async {
    await api.logout();
    notifyListeners();
  }
}

/// Une ligne du panier : une pizza (ou autre) personnalisée.
class CartLine {
  final Product product;
  final ProductVariant variant;
  final List<Ingredient> extras;
  final List<Ingredient> removed;
  int quantity;
  final String? comment;

  CartLine({
    required this.product,
    required this.variant,
    this.extras = const [],
    this.removed = const [],
    this.quantity = 1,
    this.comment,
  });

  int get unitPriceCents =>
      variant.priceCents + extras.fold(0, (sum, i) => sum + i.extraPriceCents);

  int get totalCents => unitPriceCents * quantity;

  /// Résumé de la personnalisation ("+ chorizo · sans basilic").
  String get customization {
    final parts = <String>[
      ...extras.map((i) => '+ ${i.name}'),
      ...removed.map((i) => 'sans ${i.name}'),
    ];
    return parts.join(' · ');
  }

  Map<String, dynamic> toPayload() => {
        'variantId': variant.id,
        'quantity': quantity,
        if (extras.isNotEmpty) 'extraIngredientIds': extras.map((i) => i.id).toList(),
        if (removed.isNotEmpty) 'removedIngredientIds': removed.map((i) => i.id).toList(),
        if (comment != null && comment!.isNotEmpty) 'comment': comment,
      };
}

class CartModel extends ChangeNotifier {
  final List<CartLine> lines = [];

  int get itemCount => lines.fold(0, (sum, l) => sum + l.quantity);

  int get totalCents => lines.fold(0, (sum, l) => sum + l.totalCents);

  bool get isEmpty => lines.isEmpty;

  void add(CartLine line) {
    lines.add(line);
    notifyListeners();
  }

  void removeAt(int index) {
    lines.removeAt(index);
    notifyListeners();
  }

  void changeQuantity(int index, int delta) {
    final line = lines[index];
    line.quantity = (line.quantity + delta).clamp(1, 20);
    notifyListeners();
  }

  void clear() {
    lines.clear();
    notifyListeners();
  }
}
