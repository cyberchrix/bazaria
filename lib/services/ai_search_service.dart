import '../models/ad.dart';
import 'dart:convert';
import 'package:flutter/services.dart';

class AISearchService {
  // Cache pour les résultats de recherche
  static final Map<String, List<Ad>> _searchCache = {};
  
  // Dictionnaire de synonymes chargé depuis le fichier JSON
  static Map<String, List<String>> _synonyms = {};
  
  // Flag pour vérifier si les synonymes ont été chargés
  static bool _synonymsLoaded = false;
  
  /// Charge les synonymes depuis le fichier JSON
  static Future<void> loadSynonyms() async {
    if (_synonymsLoaded) return;
    
    try {
      final String jsonString = await rootBundle.loadString('assets/synonyms.json');
      final Map<String, dynamic> jsonData = json.decode(jsonString);
      _synonyms = Map<String, List<String>>.from(
        jsonData['synonyms'].map(
          (key, value) => MapEntry(key, List<String>.from(value)),
        ),
      );
      _synonymsLoaded = true;
      print('✅ Synonymes chargés avec succès: ${_synonyms.length} entrées');
    } catch (e) {
      print('❌ Erreur lors du chargement des synonymes: $e');
      // Fallback avec quelques synonymes de base
      _synonyms = {
        'iphone': ['smartphone', 'apple', 'mobile', 'téléphone'],
        'velo': ['vélo', 'bicyclette', 'cycle', 'vtt'],
        'meuble': ['mobilier', 'canapé', 'fauteuil', 'table'],
      };
      _synonymsLoaded = true;
    }
  }

  /// Recherche avancée avec synonymes et scoring intelligent
  static Future<List<Ad>> advancedSearch(
    String query,
    List<Ad> allAds,
    Map<String, Map<String, dynamic>> categoryLabels, {
    int maxResults = 20,
  }) async {
    // S'assurer que les synonymes sont chargés
    await loadSynonyms();
    final queryLower = query.toLowerCase().trim();
    
    // Vérifier le cache
    if (_searchCache.containsKey(queryLower)) {
      return _searchCache[queryLower]!.take(maxResults).toList();
    }

    // Obtenir les synonymes de la requête
    final synonyms = _getSynonyms(queryLower);
    
    // Calculer les scores pour chaque annonce
    final List<MapEntry<Ad, double>> scoredResults = [];
    
    for (final ad in allAds) {
      final score = _calculateSearchScore(
        queryLower,
        synonyms,
        ad,
        categoryLabels,
      );
      
      if (score > 0) {
        scoredResults.add(MapEntry(ad, score));
      }
    }

    // Trier par score décroissant
    scoredResults.sort((a, b) => b.value.compareTo(a.value));

    // Créer la liste des résultats
    final results = scoredResults
        .take(maxResults)
        .map((entry) => entry.key)
        .toList();

    // Mettre en cache
    _searchCache[queryLower] = results;

    return results;
  }

  /// Calcule un score de pertinence pour une annonce
  static double _calculateSearchScore(
    String query,
    List<String> synonyms,
    Ad ad,
    Map<String, Map<String, dynamic>> categoryLabels,
  ) {
    double score = 0.0;
    final categoryName = categoryLabels[ad.subCategoryId]?['name'] ?? '';
    
    // Score pour le titre (poids élevé)
    score += _calculateTextScore(query, synonyms, ad.title) * 3.0;
    
    // Score pour la description
    score += _calculateTextScore(query, synonyms, ad.description) * 2.0;
      
    // Score pour la catégorie
    score += _calculateTextScore(query, synonyms, categoryName) * 1.5;
    
    // Score pour la localisation
    score += _calculateTextScore(query, synonyms, ad.location) * 0.5;
    
    // Bonus pour les correspondances exactes
    if (ad.title.toLowerCase().contains(query)) {
      score += 2.0;
    }
    
    if (categoryName.toLowerCase().contains(query)) {
      score += 1.5;
    }
    
    // Bonus pour les correspondances de prix (si la requête contient des chiffres)
    final priceMatch = _extractPriceFromQuery(query);
    if (priceMatch > 0) {
      final priceDiff = (ad.price - priceMatch).abs();
      if (priceDiff < 50) {
        score += 1.0;
      } else if (priceDiff < 100) {
        score += 0.5;
      }
    }
    
    return score;
  }

  /// Calcule un score pour un texte donné
  static double _calculateTextScore(String query, List<String> synonyms, String text) {
    final textLower = text.toLowerCase();
    double score = 0.0;
    
    // Score pour la requête exacte
    if (textLower.contains(query)) {
      score += 1.0;
    }
    
    // Score pour les synonymes
    for (final synonym in synonyms) {
      if (textLower.contains(synonym)) {
        score += 0.7;
      }
    }
    
    // Score pour les mots partiels
    final queryWords = query.split(' ');
    for (final word in queryWords) {
      if (word.length > 2 && textLower.contains(word)) {
        score += 0.3;
      }
    }
    
    return score;
  }

  /// Extrait un prix de la requête
  static double _extractPriceFromQuery(String query) {
    final regex = RegExp(r'(\d+)\s*(?:€|euros?|euro)');
    final match = regex.firstMatch(query);
    if (match != null) {
      return double.tryParse(match.group(1) ?? '0') ?? 0.0;
    }
    return 0.0;
  }

  /// Obtient les synonymes d'un mot
  static List<String> _getSynonyms(String word) {
    return _synonyms[word] ?? [];
  }

  /// Recherche avec suggestions intelligentes
  static Future<List<String>> getSearchSuggestions(String partialQuery) async {
    await loadSynonyms();
    final queryLower = partialQuery.toLowerCase();
    final suggestions = <String>[];
    
    // Ajouter des suggestions basées sur les synonymes
    for (final entry in _synonyms.entries) {
      if (entry.key.startsWith(queryLower) || 
          entry.value.any((synonym) => synonym.startsWith(queryLower))) {
        suggestions.add(entry.key);
      }
    }
    
    // Ajouter des suggestions de prix
    if (queryLower.contains('€') || queryLower.contains('euro')) {
      suggestions.addAll(['moins de 50€', 'moins de 100€', 'moins de 200€']);
    }
    
    // Ajouter des suggestions de localisation
    if (queryLower.contains('paris') || queryLower.contains('lyon')) {
      suggestions.addAll(['Paris', 'Lyon', 'Marseille', 'Toulouse']);
    }
    
    return suggestions.take(5).toList();
  }

  /// Améliore la requête utilisateur
  static Future<String> enhanceQuery(String userQuery) async {
    await loadSynonyms();
    final queryLower = userQuery.toLowerCase();
    
    // Chercher des synonymes pour améliorer la requête
    for (final entry in _synonyms.entries) {
      if (entry.key == queryLower) {
        return '${entry.key} ${entry.value.take(2).join(' ')}';
      }
    }
    
    // Améliorer les requêtes de prix
    if (queryLower.contains('pas cher') || queryLower.contains('bon prix')) {
      return '$userQuery moins de 100€';
    }
    
    return userQuery;
  }

  /// Recherche par similarité de catégorie
  static List<Ad> searchByCategorySimilarity(
    String categoryId,
    List<Ad> allAds,
    Map<String, Map<String, dynamic>> categoryLabels,
  ) {
    final categoryName = categoryLabels[categoryId]?['name'] ?? '';
    
    return allAds.where((ad) {
      final adCategoryName = categoryLabels[ad.subCategoryId]?['name'] ?? '';
      return adCategoryName.toLowerCase().contains(categoryName.toLowerCase()) ||
             categoryName.toLowerCase().contains(adCategoryName.toLowerCase());
    }).toList();
  }

  /// Recherche par gamme de prix
  static List<Ad> searchByPriceRange(
    double minPrice,
    double maxPrice,
    List<Ad> allAds,
  ) {
    return allAds.where((ad) => 
      ad.price >= minPrice && ad.price <= maxPrice
    ).toList();
  }

  /// Nettoie le cache
  static void clearCache() {
    _searchCache.clear();
  }

  /// Obtient des statistiques de recherche
  static Map<String, dynamic> getSearchStats() {
    return {
      'cacheSize': _searchCache.length,
      'synonymsCount': _synonyms.length,
    };
  }
} 