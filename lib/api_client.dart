import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'models.dart';

class ApiException implements Exception {
  final int statusCode;
  final String message;

  ApiException(this.statusCode, this.message);

  @override
  String toString() => message;
}

/// Client HTTP de l'API pizzeria : authentification JWT avec refresh
/// automatique, catalogue et commandes.
class ApiClient {
  static const baseUrl = String.fromEnvironment(
    'API_BASE',
    defaultValue: 'https://goodpizza.duckdns.org/api',
  );

  String? _token;
  String? _refreshToken;

  bool get isLoggedIn => _token != null;

  Future<void> loadTokens() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString('token');
    _refreshToken = prefs.getString('refresh_token');
  }

  Future<void> _storeTokens(String token, String refreshToken) async {
    _token = token;
    _refreshToken = refreshToken;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('token', token);
    await prefs.setString('refresh_token', refreshToken);
  }

  Future<void> logout() async {
    _token = null;
    _refreshToken = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('token');
    await prefs.remove('refresh_token');
  }

  // ---- Requêtes bas niveau -------------------------------------------------

  Future<http.Response> _send(
    String method,
    String path, {
    Object? jsonBody,
    bool auth = false,
    String contentType = 'application/json',
    bool retrying = false,
  }) async {
    final headers = <String, String>{
      'Accept': 'application/json',
      if (jsonBody != null) 'Content-Type': contentType,
      if (auth && _token != null) 'Authorization': 'Bearer $_token',
    };
    final uri = Uri.parse('$baseUrl$path');
    final request = http.Request(method, uri)..headers.addAll(headers);
    if (jsonBody != null) {
      request.body = json.encode(jsonBody);
    }
    final response = await http.Response.fromStream(await request.send());

    // JWT expiré : on tente une fois le refresh puis on rejoue la requête.
    if (response.statusCode == 401 && auth && !retrying && _refreshToken != null) {
      if (await _tryRefresh()) {
        return _send(method, path,
            jsonBody: jsonBody, auth: auth, contentType: contentType, retrying: true);
      }
      await logout();
    }
    return response;
  }

  Future<bool> _tryRefresh() async {
    final response = await http.post(
      Uri.parse('$baseUrl/token/refresh'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'refresh_token': _refreshToken}),
    );
    if (response.statusCode != 200) {
      return false;
    }
    final data = json.decode(response.body) as Map<String, dynamic>;
    await _storeTokens(data['token'] as String, data['refresh_token'] as String);
    return true;
  }

  Never _fail(http.Response response) {
    String message = 'Erreur ${response.statusCode}';
    try {
      final data = json.decode(response.body) as Map<String, dynamic>;
      message = (data['message'] ?? data['detail'] ?? message).toString();
      if (data['errors'] is Map) {
        message = (data['errors'] as Map).values.join('\n');
      }
    } catch (_) {}
    throw ApiException(response.statusCode, message);
  }

  dynamic _decode(http.Response response, {int expected = 200}) {
    if (response.statusCode != expected) {
      _fail(response);
    }
    return json.decode(utf8.decode(response.bodyBytes));
  }

  // ---- Authentification ----------------------------------------------------

  Future<void> login(String email, String password) async {
    final response = await _send('POST', '/login',
        jsonBody: {'email': email, 'password': password});
    if (response.statusCode != 200) {
      _fail(response);
    }
    final data = json.decode(response.body) as Map<String, dynamic>;
    await _storeTokens(data['token'] as String, data['refresh_token'] as String);
  }

  Future<void> register(String email, String password, String name, String? phone) async {
    final response = await _send('POST', '/register', jsonBody: {
      'email': email,
      'password': password,
      'name': name,
      if (phone != null && phone.isNotEmpty) 'phone': phone,
    });
    if (response.statusCode != 201) {
      _fail(response);
    }
    await login(email, password);
  }

  // ---- Catalogue (public) --------------------------------------------------

  Future<List<Category>> fetchCategories() async {
    final data = _decode(await _send('GET', '/categories')) as List;
    return data.map((c) => Category.fromJson(c as Map<String, dynamic>)).toList();
  }

  Future<List<Product>> fetchProducts() async {
    final data =
        _decode(await _send('GET', '/products?available=true&itemsPerPage=100')) as List;
    return data.map((p) => Product.fromJson(p as Map<String, dynamic>)).toList();
  }

  Future<List<Ingredient>> fetchIngredients() async {
    final data = _decode(await _send('GET', '/ingredients?itemsPerPage=100')) as List;
    return data
        .map((i) => Ingredient.fromJson(i as Map<String, dynamic>))
        .where((i) => i.available)
        .toList();
  }

  // ---- Commandes -----------------------------------------------------------

  Future<Order> createOrder({
    required String type,
    String? comment,
    required List<Map<String, dynamic>> items,
  }) async {
    final response = await _send('POST', '/orders', auth: true, jsonBody: {
      'type': type,
      if (comment != null && comment.isNotEmpty) 'comment': comment,
      'items': items,
    });
    return Order.fromJson(_decode(response, expected: 201) as Map<String, dynamic>);
  }

  Future<List<Order>> fetchOrders() async {
    final data = _decode(await _send('GET', '/orders', auth: true)) as List;
    return data.map((o) => Order.fromJson(o as Map<String, dynamic>)).toList();
  }

  Future<Order> fetchOrder(int id) async {
    final data = _decode(await _send('GET', '/orders/$id', auth: true));
    return Order.fromJson(data as Map<String, dynamic>);
  }

  Future<Order> cancelOrder(int id) async {
    final response = await _send('PATCH', '/orders/$id/transition',
        auth: true,
        jsonBody: {'transition': 'cancel'},
        contentType: 'application/merge-patch+json');
    return Order.fromJson(_decode(response) as Map<String, dynamic>);
  }
}
