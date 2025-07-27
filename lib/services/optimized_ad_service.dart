import 'package:appwrite/appwrite.dart';
import '../models/ad.dart';
import 'appwrite_service.dart';

class OptimizedAdService {
  static const String _databaseId = '687ccdcf0000676911f1';
  static const String _collectionId = '687ccdde0031f8eda985';

  static Databases get _databases => AppwriteService().databases;

  /// Récupère les annonces récentes avec index sur publicationDate
  static Future<List<Ad>> getRecentAds({int limit = 20}) async {
    try {
      final response = await _databases.listDocuments(
        databaseId: _databaseId,
        collectionId: _collectionId,
        queries: [
          Query.equal('isActive', true),
          Query.orderDesc('publicationDate'), // Utilise l'index publicationDate
          Query.limit(limit),
          Query.select(['title', 'price', 'imageUrl', 'mainCategoryId', 'publicationDate']), // Sélection optimisée
        ],
      );
      
      return response.documents.map((doc) => Ad.fromAppwrite(doc)).toList();
    } catch (e) {
      print('❌ Erreur lors du chargement des annonces récentes: $e');
      return [];
    }
  }

  /// Récupère les annonces par catégorie avec index sur mainCategoryId
  static Future<List<Ad>> getAdsByCategory(String categoryId, {int limit = 20}) async {
    try {
      final response = await _databases.listDocuments(
        databaseId: _databaseId,
        collectionId: _collectionId,
        queries: [
          Query.equal('mainCategoryId', categoryId), // Utilise l'index mainCategoryId
          Query.equal('isActive', true),
          Query.orderDesc('publicationDate'),
          Query.limit(limit),
        ],
      );
      
      return response.documents.map((doc) => Ad.fromAppwrite(doc)).toList();
    } catch (e) {
      print('❌ Erreur lors du chargement des annonces par catégorie: $e');
      return [];
    }
  }

  /// Recherche textuelle optimisée avec index fulltext
  static Future<List<Ad>> searchAds(String query, {int limit = 20}) async {
    try {
      final response = await _databases.listDocuments(
        databaseId: _databaseId,
        collectionId: _collectionId,
        queries: [
          Query.search('title', query), // Utilise l'index fulltext sur title
          Query.equal('isActive', true),
          Query.orderDesc('publicationDate'),
          Query.limit(limit),
        ],
      );
      
      return response.documents.map((doc) => Ad.fromAppwrite(doc)).toList();
    } catch (e) {
      print('❌ Erreur lors de la recherche: $e');
      return [];
    }
  }

  /// Recherche avancée avec filtres multiples
  static Future<List<Ad>> searchAdsAdvanced({
    String? categoryId,
    String? location,
    double? minPrice,
    double? maxPrice,
    String? searchQuery,
    int limit = 20,
  }) async {
    try {
      List<String> queries = [
        Query.equal('isActive', true),
        Query.orderDesc('publicationDate'),
        Query.limit(limit),
      ];

      // Ajouter les filtres conditionnels
      if (categoryId != null) {
        queries.add(Query.equal('mainCategoryId', categoryId));
      }
      
      if (location != null) {
        queries.add(Query.equal('location', location));
      }
      
      if (minPrice != null) {
        queries.add(Query.greaterThanEqual('price', minPrice));
      }
      
      if (maxPrice != null) {
        queries.add(Query.lessThanEqual('price', maxPrice));
      }
      
      if (searchQuery != null && searchQuery.isNotEmpty) {
        queries.add(Query.search('title', searchQuery));
      }

      final response = await _databases.listDocuments(
        databaseId: _databaseId,
        collectionId: _collectionId,
        queries: queries,
      );
      
      return response.documents.map((doc) => Ad.fromAppwrite(doc)).toList();
    } catch (e) {
      print('❌ Erreur lors de la recherche avancée: $e');
      return [];
    }
  }

  /// Récupère les annonces par localisation avec index sur location
  static Future<List<Ad>> getAdsByLocation(String location, {int limit = 20}) async {
    try {
      final response = await _databases.listDocuments(
        databaseId: _databaseId,
        collectionId: _collectionId,
        queries: [
          Query.equal('location', location), // Utilise l'index location
          Query.equal('isActive', true),
          Query.orderDesc('publicationDate'),
          Query.limit(limit),
        ],
      );
      
      return response.documents.map((doc) => Ad.fromAppwrite(doc)).toList();
    } catch (e) {
      print('❌ Erreur lors du chargement par localisation: $e');
      return [];
    }
  }

  /// Récupère les annonces par code postal avec index sur postalCode
  static Future<List<Ad>> getAdsByPostalCode(String postalCode, {int limit = 20}) async {
    try {
      final response = await _databases.listDocuments(
        databaseId: _databaseId,
        collectionId: _collectionId,
        queries: [
          Query.equal('postalCode', postalCode), // Utilise l'index postalCode
          Query.equal('isActive', true),
          Query.orderDesc('publicationDate'),
          Query.limit(limit),
        ],
      );
      
      return response.documents.map((doc) => Ad.fromAppwrite(doc)).toList();
    } catch (e) {
      print('❌ Erreur lors du chargement par code postal: $e');
      return [];
    }
  }

  /// Pagination optimisée
  static Future<List<Ad>> getAdsWithPagination({
    String? cursor,
    int limit = 20,
    String? categoryId,
  }) async {
    try {
      List<String> queries = [
        Query.equal('isActive', true),
        Query.orderDesc('publicationDate'),
        Query.limit(limit),
      ];

      if (categoryId != null) {
        queries.add(Query.equal('mainCategoryId', categoryId));
      }

      if (cursor != null) {
        queries.add(Query.cursorAfter(cursor));
      }

      final response = await _databases.listDocuments(
        databaseId: _databaseId,
        collectionId: _collectionId,
        queries: queries,
      );
      
      return response.documents.map((doc) => Ad.fromAppwrite(doc)).toList();
    } catch (e) {
      print('❌ Erreur lors de la pagination: $e');
      return [];
    }
  }
} 