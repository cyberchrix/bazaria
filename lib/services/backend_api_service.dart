import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:logger/logger.dart';
import '../models/ad.dart';

final logger = Logger();

/// Service pour l'API backend Bazaria
class BackendAPIService {
  static const String baseUrl = 'https://bazaria-backend.onrender.com';
  
  /// Test de connexion à l'API backend
  static Future<bool> testConnection() async {
    try {
      logger.d('🔧 Test de connexion Backend API...');
      
      final response = await http.get(
        Uri.parse('$baseUrl/health'),
        headers: {'Content-Type': 'application/json'},
      );
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        logger.d('✅ Backend API connecté: ${data['message']}');
        return true;
      } else {
        logger.e('❌ Erreur connexion Backend API: ${response.statusCode}');
        return false;
      }
    } catch (e) {
      logger.e('❌ Erreur test connexion Backend API: $e');
      return false;
    }
  }
  
  /// Recherche d'annonces via l'API backend
  static Future<List<Ad>> searchAds(String query, {int limit = 20}) async {
    try {
      logger.d('🔍 Recherche backend: "$query" (limit: $limit)');
      
      final response = await http.post(
        Uri.parse('$baseUrl/search'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'query': query,
          'limit': limit,
        }),
      );
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final results = data['results'] as List;
        
        logger.d('✅ Recherche backend réussie: ${data['total_results']} résultats');
        logger.d('  - Text results: ${data['text_results']}');
        logger.d('  - Semantic results: ${data['semantic_results']}');
        
        return results.map((result) => _convertToAd(result)).toList();
      } else {
        logger.e('❌ Erreur recherche backend: ${response.statusCode}');
        logger.e('❌ Réponse: ${response.body}');
        return [];
      }
    } catch (e) {
      logger.e('❌ Erreur recherche backend: $e');
      return [];
    }
  }
  
  /// Recherche rapide d'annonces via l'API backend
  static Future<List<Ad>> searchAdsFast(String query, {int limit = 10}) async {
    try {
      logger.d('⚡ Recherche rapide backend: "$query" (limit: $limit)');
      
      final response = await http.post(
        Uri.parse('$baseUrl/search/fast'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'query': query,
          'limit': limit,
        }),
      );
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final results = data['results'] as List;
        
        logger.d('⚡ Recherche rapide backend réussie: ${data['total_results']} résultats');
        logger.d('  - Text results: ${data['text_results']}');
        logger.d('  - Semantic results: ${data['semantic_results']}');
        
        return results.map((result) => _convertToAd(result)).toList();
      } else {
        logger.e('❌ Erreur recherche rapide backend: ${response.statusCode}');
        logger.e('❌ Réponse: ${response.body}');
        return [];
      }
    } catch (e) {
      logger.e('❌ Erreur recherche rapide backend: $e');
      return [];
    }
  }
  
  /// Recherche rapide via GET (pour tests)
  static Future<List<Ad>> searchAdsGet(String query, {int limit = 20}) async {
    try {
      logger.d('🔍 Recherche GET backend: "$query" (limit: $limit)');
      
      final response = await http.get(
        Uri.parse('$baseUrl/search/$query?limit=$limit'),
        headers: {'Content-Type': 'application/json'},
      );
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final results = data['results'] as List;
        
        logger.d('✅ Recherche GET backend réussie: ${data['total_results']} résultats');
        
        return results.map((result) => _convertToAd(result)).toList();
      } else {
        logger.e('❌ Erreur recherche GET backend: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      logger.e('❌ Erreur recherche GET backend: $e');
      return [];
    }
  }
  
  /// Obtient les statistiques de l'API
  static Future<Map<String, dynamic>> getStats() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/stats'),
        headers: {'Content-Type': 'application/json'},
      );
      
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        logger.e('❌ Erreur stats backend: ${response.statusCode}');
        return {};
      }
    } catch (e) {
      logger.e('❌ Erreur stats backend: $e');
      return {};
    }
  }
  
  /// Convertit un résultat de l'API en objet Ad
  static Ad _convertToAd(Map<String, dynamic> result) {
    return Ad(
      id: result['id'] ?? '',
      title: result['title'] ?? '',
      description: result['description'] ?? '',
      price: result['price']?.toDouble() ?? 0.0,
      location: result['location'] ?? '',
      imageUrl: 'https://picsum.photos/seed/${result['id']}/400/300', // Placeholder
      publicationDate: DateTime.now(), // L'API ne fournit pas cette info
      userId: 'backend', // Marqueur pour identifier la source
      isActive: true,
      mainCategoryId: 'backend', // Valeur par défaut
      subCategoryId: 'backend', // Valeur par défaut
      postalCode: '00000', // Valeur par défaut
      // Stocker les infos supplémentaires dans criterias
      criterias: {
        'match_type': result['match_type'] ?? 'unknown',
        'score': result['score']?.toDouble() ?? 0.0,
      },
    );
  }
  
  /// Obtient les informations du service
  static Future<Map<String, dynamic>> getServiceInfo() async {
    final isConnected = await testConnection();
    final stats = await getStats();
    
    return {
      'service': 'Backend API',
      'baseUrl': baseUrl,
      'connected': isConnected,
      'stats': stats,
      'endpoints': [
        'POST /search',
        'GET /search/{query}',
        'GET /health',
        'GET /stats',
      ],
    };
  }
} 