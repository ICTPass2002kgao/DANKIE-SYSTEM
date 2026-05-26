import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:http/http.dart' as http;
import 'package:ttact/Components/API.dart';

class ProductsService {
  final String baseUrl = Api().BACKEND_BASE_URL_DEBUG;

  // 1. GET GLOBAL CATALOG (For adding new items to sell)
  Future<List<dynamic>> searchGlobalCatalog(String query) async {
    final response = await http.get(
      Uri.parse('$baseUrl/catalog/?search=$query'),
    );
    if (response.statusCode == 200) {
      return json.decode(response.body);
    }
    return [];
  }

  // 2. GET MY INVENTORY (The items I am actually selling)
  Future<List<dynamic>> getMyInventory(String sellerUid) async {
    final response = await http.get(
      Uri.parse('$baseUrl/seller-inventory/?seller_uid=$sellerUid'),
    );
    if (response.statusCode == 200) {
      return json.decode(response.body);
    }
    return [];
  }

  // 3. PUBLISH LISTING (Link a global product to my store)
  Future<bool> publishListing({
    required String sellerUid,
    required String productId,
    required double price,
    required String location,
    required List<String> colors,
    required List<String> sizes,
  }) async {
    String? token =  FirebaseAuth.instance.currentUser != null
        ? await FirebaseAuth.instance.currentUser!.getIdToken()
        : '';
    final response = await http.post(
      Uri.parse('$baseUrl/seller-inventory/'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',  
      },
      body: json.encode({
        'seller_uid': sellerUid,
        'productId': productId,
        'price': price,
        'location': location,
        'seller_colors': colors,
        'seller_sizes': sizes,
      }),
    );
    return response.statusCode == 201;
  }

  // 4. GET ORDERS
  Future<List<dynamic>> getSellerOrders(String sellerUid) async {
    final response = await http.get(
      Uri.parse('$baseUrl/orders/?role=Seller&uid=$sellerUid',
      
      ),
     headers: { 
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ${await FirebaseAuth.instance.currentUser?.getIdToken()}' },

    );
    if (response.statusCode == 200) {
      return json.decode(response.body);
    }
    return [];
  }
}