import 'package:logger/logger.dart';
import 'ai_config.dart';
import '../models/ad.dart';
import 'openai_service.dart';
import 'faiss_service.dart';
import 'ai_search_service.dart';

final logger = Logger();

/// Service LangChain simulé pour orchestrer les recherches IA
/// En production, utilisez le vrai LangChain ou une solution similaire
class LangChainService {
  static bool _isInitialized = false;
  
  /// Initialise le service LangChain
  static Future<void> initialize() async {
    if (_isInitialized) return;
    
    try {
      // Initialiser les services dépendants
      await OpenAIService.initialize();
      await FAISSService.initialize();
      
      _isInitialized = true;
      logger.d('✅ Service LangChain initialisé avec succès');
    } catch (e) {
      logger.e('❌ Erreur initialisation LangChain: $e');
      rethrow;
    }
  }
  
  /// Recherche hybride combinant IA et recherche traditionnelle
  static Future<List<Ad>> hybridSearch(
    String query,
    List<Ad> allAds,
    Map<String, Map<String, dynamic>> categoryLabels, {
    int maxResults = 30,
  }) async {
    try {
      await initialize();
      
      logger.d('🔍 Début recherche hybride: "$query"');
      
      // 1. Améliorer la requête avec OpenAI
      final enhancedQuery = await OpenAIService.enhanceQuery(query);
      logger.d('🔍 Requête améliorée: "$enhancedQuery"');
      
      // 2. Recherche sémantique (IA)
      final semanticResults = await semanticSearch(
        enhancedQuery,
        allAds,
        categoryLabels,
        maxResults: maxResults,
      );
      
      // 3. Recherche textuelle traditionnelle
      final textResults = _fallbackTextSearch(
        enhancedQuery,
        allAds,
        maxResults,
      );
      
      // 4. Combiner et scorer les résultats
      final combinedResults = _combineSearchResults(
        semanticResults,
        textResults,
        query,
        enhancedQuery,
        categoryLabels,
      );
      
      logger.d('🔍 Recherche hybride terminée: ${combinedResults.length} résultats');
      return combinedResults;
    } catch (e) {
      logger.e('❌ Erreur recherche hybride: $e');
      // Fallback vers recherche textuelle simple
      return _fallbackTextSearch(query, allAds, maxResults);
    }
  }
  
  /// Combine les résultats de recherche sémantique et textuelle
  static List<Ad> _combineSearchResults(
    List<Ad> semanticResults,
    List<Ad> textResults,
    String originalQuery,
    String enhancedQuery,
    Map<String, Map<String, dynamic>> categoryLabels,
  ) {
    final Map<String, double> adScores = {};
    
    // Scorer les résultats sémantiques (IA) - priorité plus élevée
    for (int i = 0; i < semanticResults.length; i++) {
      final ad = semanticResults[i];
      final score = (semanticResults.length - i) * AIConfig.semanticWeight;
      adScores[ad.id] = (adScores[ad.id] ?? 0.0) + score;
    }
    
    // Scorer les résultats textuels
    for (int i = 0; i < textResults.length; i++) {
      final ad = textResults[i];
      final score = (textResults.length - i) * AIConfig.textWeight;
      adScores[ad.id] = (adScores[ad.id] ?? 0.0) + score;
    }
    
    // Créer la liste finale triée par score
    final List<MapEntry<Ad, double>> scoredResults = [];
    
    // Récupérer tous les annonces uniques
    final allUniqueAds = <String, Ad>{};
    for (final ad in semanticResults) allUniqueAds[ad.id] = ad;
    for (final ad in textResults) allUniqueAds[ad.id] = ad;
    
    for (final ad in allUniqueAds.values) {
      final score = adScores[ad.id] ?? 0.0;
      if (score > 0) {
        scoredResults.add(MapEntry(ad, score));
      }
    }
    
    // Trier par score décroissant
    scoredResults.sort((a, b) => b.value.compareTo(a.value));
    
    logger.d('🔍 Combinaison: ${semanticResults.length} sémantiques + ${textResults.length} textuels = ${scoredResults.length} résultats');
    return scoredResults.map((e) => e.key).toList();
  }
  
  /// Recherche conversationnelle avec mémoire
  static Future<List<Ad>> conversationalSearch(
    String query,
    List<String> conversationHistory,
    List<Ad> allAds,
    Map<String, Map<String, dynamic>> categoryLabels, {
    int maxResults = 20,
  }) async {
    try {
      await initialize();
      
      logger.d('🔍 Recherche conversationnelle: "$query"');
      
      // Construire le contexte de conversation
      final context = _buildConversationContext(query, conversationHistory);
      
      // Améliorer la requête avec le contexte
      final enhancedQuery = await _enhanceQueryWithContext(context, query);
      
      // Effectuer la recherche hybride
      final results = await hybridSearch(
        enhancedQuery,
        allAds,
        categoryLabels,
        maxResults: maxResults,
      );
      
      logger.d('🔍 Recherche conversationnelle terminée: ${results.length} résultats');
      return results;
    } catch (e) {
      logger.e('❌ Erreur recherche conversationnelle: $e');
      return [];
    }
  }
  
  /// Construit le contexte de conversation
  static String _buildConversationContext(String currentQuery, List<String> history) {
    if (history.isEmpty) return currentQuery;
    
    final recentHistory = history.take(3).join(' ');
    return '$recentHistory $currentQuery';
  }
  
  /// Améliore la requête avec le contexte de conversation
  static Future<String> _enhanceQueryWithContext(String context, String query) async {
    try {
      await initialize();
      
      final completion = await OpenAIService.enhanceQuery(context);
      return completion;
    } catch (e) {
      logger.e('❌ Erreur amélioration avec contexte: $e');
      return query;
    }
  }
  
  /// Recherche par similarité sémantique
  static Future<List<Ad>> semanticSearch(
    String query,
    List<Ad> allAds,
    Map<String, Map<String, dynamic>> categoryLabels, {
    int maxResults = 20,
  }) async {
    try {
      await initialize();
      
      logger.d('🔍 Début recherche sémantique: "$query"');
      
      // Améliorer la requête avec OpenAI
      final enhancedQuery = await OpenAIService.enhanceQuery(query);
      logger.d('🔍 Requête améliorée: "$enhancedQuery"');
      
      // Recherche basée sur le contenu avec scoring intelligent
      final scoredAds = <Ad, double>{};
      
      for (final ad in allAds) {
        double score = 0.0;
        final originalQueryLower = query.toLowerCase();
        final enhancedQueryLower = enhancedQuery.toLowerCase();
        final titleLower = ad.title.toLowerCase();
        final descriptionLower = ad.description.toLowerCase();
        
        // Score pour correspondance exacte dans le titre (requête originale)
        if (titleLower.contains(originalQueryLower)) {
          score += AIConfig.titleWeight * AIConfig.exactMatchBonus;
        }
        
        // Score pour correspondance exacte dans le titre (requête améliorée)
        if (titleLower.contains(enhancedQueryLower)) {
          score += AIConfig.titleWeight * AIConfig.exactMatchBonus;
        }
        
        // Score pour correspondance partielle dans le titre (requête originale)
        final originalQueryWords = originalQueryLower.split(' ');
        for (final word in originalQueryWords) {
          if (word.length > 2 && titleLower.contains(word)) {
            score += AIConfig.titleWeight;
          }
        }
        
        // Score pour correspondance partielle dans le titre (requête améliorée)
        final enhancedQueryWords = enhancedQueryLower.split(' ');
        for (final word in enhancedQueryWords) {
          if (word.length > 2 && titleLower.contains(word)) {
            score += AIConfig.titleWeight;
          }
        }
        
        // Score pour correspondance dans la description (requête originale)
        if (descriptionLower.contains(originalQueryLower)) {
          score += AIConfig.descriptionWeight * AIConfig.exactMatchBonus;
        }
        
        // Score pour correspondance dans la description (requête améliorée)
        if (descriptionLower.contains(enhancedQueryLower)) {
          score += AIConfig.descriptionWeight * AIConfig.exactMatchBonus;
        }
        
        // Score pour correspondance partielle dans la description (requête originale)
        for (final word in originalQueryWords) {
          if (word.length > 2 && descriptionLower.contains(word)) {
            score += AIConfig.descriptionWeight;
          }
        }
        
        // Score pour correspondance partielle dans la description (requête améliorée)
        for (final word in enhancedQueryWords) {
          if (word.length > 2 && descriptionLower.contains(word)) {
            score += AIConfig.descriptionWeight;
          }
        }
        
        // Score pour correspondance de catégorie (requête originale)
        final categoryName = _getCategoryName(ad.subCategoryId, categoryLabels);
        if (categoryName.toLowerCase().contains(originalQueryLower)) {
          score += AIConfig.categoryWeight * AIConfig.categoryMatchBonus;
        }
        
        // Score pour correspondance de catégorie (requête améliorée)
        if (categoryName.toLowerCase().contains(enhancedQueryLower)) {
          score += AIConfig.categoryWeight * AIConfig.categoryMatchBonus;
        }
        
        // Score pour correspondance de localisation (requête originale)
        if (ad.location.toLowerCase().contains(originalQueryLower)) {
          score += AIConfig.locationWeight;
        }
        
        // Score pour correspondance de localisation (requête améliorée)
        if (ad.location.toLowerCase().contains(enhancedQueryLower)) {
          score += AIConfig.locationWeight;
        }
        
        // Score pour correspondance de prix (si la requête contient des chiffres)
        final priceMatch = _extractPriceFromQuery(query);
        if (priceMatch != null) {
          final priceDiff = (ad.price - priceMatch).abs();
          if (priceDiff < 100) {
            score += AIConfig.priceMatchBonus;
          }
        }
        
        // Appliquer le score seulement s'il est significatif
        if (score > 0.1) {
          scoredAds[ad] = score;
        }
      }
      
      // Trier par score décroissant
      final sortedAds = scoredAds.entries
          .toList()
          ..sort((a, b) => b.value.compareTo(a.value));
      
      final results = sortedAds
          .take(maxResults)
          .map((e) => e.key)
          .toList();
      
      logger.d('🔍 Recherche sémantique terminée: ${results.length} résultats');
      logger.d('🔍 Scores: ${scoredAds.values.take(5).toList()}');
      logger.d('🔍 Requête originale: "$query"');
      logger.d('🔍 Requête améliorée: "$enhancedQuery"');
      logger.d('🔍 Total annonces analysées: ${allAds.length}');
      logger.d('🔍 Annonces avec score > 0.1: ${scoredAds.length}');
      
      return results;
    } catch (e) {
      logger.e('❌ Erreur recherche sémantique: $e');
      // Fallback vers recherche textuelle simple
      return _fallbackTextSearch(query, allAds, maxResults);
    }
  }
  
  /// Recherche de fallback basée sur le texte
  static List<Ad> _fallbackTextSearch(String query, List<Ad> allAds, int maxResults) {
    final queryLower = query.toLowerCase();
    final results = allAds.where((ad) {
      final titleLower = ad.title.toLowerCase();
      final descriptionLower = ad.description.toLowerCase();
      
      // Correspondance exacte
      if (titleLower.contains(queryLower) || descriptionLower.contains(queryLower)) {
        return true;
      }
      
      // Correspondance partielle par mots
      final queryWords = queryLower.split(' ');
      for (final word in queryWords) {
        if (word.length > 2 && (titleLower.contains(word) || descriptionLower.contains(word))) {
          return true;
        }
      }
      
      return false;
    }).toList();
    
    logger.d('🔍 Fallback textuel: "$query" → ${results.length} résultats');
    return results.take(maxResults).toList();
  }
  
  /// Extrait un prix de la requête
  static double? _extractPriceFromQuery(String query) {
    final priceRegex = RegExp(r'(\d+)\s*(?:€|euros?|euro)');
    final match = priceRegex.firstMatch(query.toLowerCase());
    if (match != null) {
      return double.tryParse(match.group(1) ?? '');
    }
    return null;
  }
  
  /// Obtient le nom de la catégorie
  static String _getCategoryName(String? categoryId, Map<String, Map<String, dynamic>> categoryLabels) {
    if (categoryId == null) return '';
    
    final category = categoryLabels[categoryId];
    return category?['name'] ?? '';
  }
  
  /// Génère des suggestions intelligentes
  static Future<List<String>> generateSmartSuggestions(
    String partialQuery,
    List<Ad> allAds,
  ) async {
    try {
      await initialize();
      
      final suggestions = <String>[];
      
      // Suggestions basées sur les titres populaires
      final popularTitles = allAds
          .map((ad) => ad.title.toLowerCase())
          .where((title) => title.contains(partialQuery.toLowerCase()))
          .take(3)
          .toList();
      
      suggestions.addAll(popularTitles);
      
      // Suggestions basées sur les catégories
      final categories = allAds
          .map((ad) => ad.subCategoryId)
          .toSet()
          .take(2)
          .toList();
      
      suggestions.addAll(categories);
      
      logger.d('🔍 Suggestions générées: $suggestions');
      return suggestions;
    } catch (e) {
      logger.e('❌ Erreur génération suggestions: $e');
      return [];
    }
  }
  
  /// Obtient des statistiques du service
  static Map<String, dynamic> getServiceStats() {
    return {
      'isInitialized': _isInitialized,
      'faissStats': FAISSService.getIndexStats(),
    };
  }
} 