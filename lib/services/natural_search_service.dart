import 'dart:convert';
import 'package:flutter/services.dart';
import '../models/ad.dart';
import 'package:logger/logger.dart';
import 'ai_search_service.dart';

final logger = Logger();

class NaturalSearchService {
  // Cache pour les résultats de recherche
  static final Map<String, List<Ad>> _searchCache = {};
  
  /// Effectue une recherche naturelle simple et efficace
  static Future<List<Ad>> naturalSearch(
    String query,
    List<Ad> allAds,
    Map<String, Map<String, dynamic>> categoryLabels,
  ) async {
    logger.d('🔍 Début de la recherche naturelle: "$query"');
    logger.d('📊 Nombre d\'annonces disponibles: ${allAds.length}');
    
    // Vérifier le cache
    final cacheKey = query.toLowerCase().trim();
    if (_searchCache.containsKey(cacheKey)) {
      logger.d('✅ Résultats trouvés en cache');
      return _searchCache[cacheKey]!;
    }
    
    // Parser la requête de manière simple
    final params = _parseSimpleQuery(query);
    logger.d('🔍 Paramètres extraits: $params');
    
    // Recherche simple mais efficace
    final results = _simpleSearch(allAds, params);
    logger.d('🔍 Résultats trouvés: ${results.length}');
    
    // Mettre en cache
    _searchCache[cacheKey] = results;
    
    logger.d('✅ Recherche naturelle terminée: ${results.length} résultats');
    return results;
  }

  /// Parse la requête de manière simple
  static Map<String, dynamic> _parseSimpleQuery(String query) {
    final queryLower = query.toLowerCase();
    final Map<String, dynamic> params = {
      'keywords': [],
      'location': null,
      'priceRange': null,
      'condition': null,
      'size': null,
      'color': null,
      'category': null,
    };

    // Extraire les mots-clés principaux
    final words = queryLower.split(' ')
        .where((word) => word.length > 2 && !_isStopWord(word))
        .toList();
    params['keywords'] = words;
    
    // Extraire la localisation
    if (queryLower.contains('lille')) params['location'] = 'lille';
    if (queryLower.contains('paris')) params['location'] = 'paris';
    if (queryLower.contains('lyon')) params['location'] = 'lyon';
    if (queryLower.contains('marseille')) params['location'] = 'marseille';
    
    // Extraire le prix
    final numbers = RegExp(r'\d+').allMatches(queryLower);
    if (numbers.isNotEmpty) {
      final price = double.parse(numbers.first.group(0)!);
      if (queryLower.contains('moins de') || queryLower.contains('max')) {
        params['priceRange'] = {'max': price};
      } else {
        params['priceRange'] = {'max': price};
      }
    }
    
    // Extraire la condition
    if (queryLower.contains('bon état')) params['condition'] = 'bon état';
    if (queryLower.contains('neuf')) params['condition'] = 'neuf';
    if (queryLower.contains('occasion')) params['condition'] = 'occasion';
    
    // Extraire la taille
    if (queryLower.contains('taille m') || queryLower.contains('m ')) params['size'] = 'M';
    if (queryLower.contains('taille l') || queryLower.contains('l ')) params['size'] = 'L';
    if (queryLower.contains('taille s') || queryLower.contains('s ')) params['size'] = 'S';
    
    // Extraire la couleur
    final colors = ['gris', 'noir', 'blanc', 'rouge', 'bleu', 'vert', 'jaune', 'orange'];
    for (final color in colors) {
      if (queryLower.contains(color)) {
        params['color'] = color;
        break;
      }
    }
    
    // Déduire la catégorie
    if (queryLower.contains('velo') || queryLower.contains('vélo')) {
      params['category'] = 'vélo';
    } else if (queryLower.contains('iphone') || queryLower.contains('smartphone')) {
      params['category'] = 'smartphone';
    } else if (queryLower.contains('meuble')) {
      params['category'] = 'meubles';
    } else if (queryLower.contains('voiture') || queryLower.contains('auto')) {
      params['category'] = 'véhicules';
    }
    
    return params;
  }

  /// Mots à ignorer
  static bool _isStopWord(String word) {
    final stopWords = [
      'je', 'recherche', 'cherche', 'veux', 'souhaite', 'donnez', 'moi',
      'un', 'une', 'des', 'sur', 'dans', 'avec', 'pour', 'de', 'du', 'la', 'le'
    ];
    return stopWords.contains(word);
  }

  /// Recherche simple mais efficace
  static List<Ad> _simpleSearch(List<Ad> ads, Map<String, dynamic> params) {
    final List<MapEntry<Ad, double>> scoredAds = [];
    
    for (final ad in ads) {
      double score = 0.0;
      final keywords = params['keywords'] as List<String>;
      
      // Score par mots-clés dans le titre (poids élevé)
      for (final keyword in keywords) {
        if (ad.title.toLowerCase().contains(keyword)) {
          score += 3.0;
          logger.d('✅ Mot-clé "$keyword" trouvé dans le titre: "${ad.title}"');
        }
      }
      
      // Score par mots-clés dans la description
      for (final keyword in keywords) {
        if (ad.description.toLowerCase().contains(keyword)) {
          score += 1.0;
        }
      }
      
      // Score par localisation
      if (params['location'] != null) {
        final location = params['location'] as String;
        if (ad.location.toLowerCase().contains(location)) {
          score += 2.0;
          logger.d('✅ Localisation "$location" trouvée: "${ad.location}"');
        }
      }
      
      // Score par prix
      if (params['priceRange'] != null) {
        final priceRange = params['priceRange'] as Map<String, dynamic>;
        if (priceRange.containsKey('max') && ad.price <= priceRange['max']) {
          score += 1.5;
          logger.d('✅ Prix dans la fourchette: ${ad.price}€ <= ${priceRange['max']}€');
        }
      }
      
      // Score par condition
      if (params['condition'] != null) {
        final condition = params['condition'] as String;
        if (ad.description.toLowerCase().contains(condition)) {
          score += 2.0;
          logger.d('✅ Condition "$condition" trouvée dans la description');
        }
      }
      
      // Score par taille
      if (params['size'] != null) {
        final size = params['size'] as String;
        if (ad.title.toLowerCase().contains(size) || 
            ad.description.toLowerCase().contains(size)) {
          score += 1.5;
          logger.d('✅ Taille "$size" trouvée');
        }
      }
      
      // Score par couleur
      if (params['color'] != null) {
        final color = params['color'] as String;
        if (ad.title.toLowerCase().contains(color) || 
            ad.description.toLowerCase().contains(color)) {
          score += 1.5;
          logger.d('✅ Couleur "$color" trouvée');
        }
      }
      
      // Score par catégorie
      if (params['category'] != null) {
        final category = params['category'] as String;
        if (ad.title.toLowerCase().contains(category) || 
            ad.description.toLowerCase().contains(category)) {
          score += 2.0;
          logger.d('✅ Catégorie "$category" trouvée');
        }
      }
      
      // Ajouter seulement si score > 0
      if (score > 0) {
        scoredAds.add(MapEntry(ad, score));
        logger.d('📊 Score pour "${ad.title}": $score');
      }
    }
    
    // Trier par score décroissant
    scoredAds.sort((a, b) => b.value.compareTo(a.value));
    
    // Retourner les annonces (pas les scores)
    return scoredAds.map((entry) => entry.key).toList();
  }

  /// Génère des suggestions de recherche naturelle
  static List<String> getSearchSuggestions() {
    return [
      'Je recherche un vélo cadre gris taille M sur Lille',
      'Cherche iPhone 13 en bon état moins de 500€',
      'Donnez-moi des meubles d\'occasion à Paris',
      'Je veux une voiture pas cher dans le Nord',
      'Recherche livres de science-fiction',
      'Trouve-moi un smartphone Android récent',
      'Cherche appartement 2 pièces à Lyon',
      'Je souhaite acheter une moto 125cc',
    ];
  }
} 