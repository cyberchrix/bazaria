import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Configuration pour les services d'IA
class AIConfig {
  // Configuration OpenAI
  // Pour obtenir votre clé API :
  // 1. Allez sur https://platform.openai.com/api-keys
  // 2. Créez une nouvelle clé secrète
  // 3. Remplacez 'YOUR_OPENAI_API_KEY' par votre vraie clé
  // 4. Ou utilisez un fichier .env (recommandé)
  static String get openaiApiKey {
    // Essayer de charger depuis .env d'abord
    final envKey = dotenv.env['OPENAI_API_KEY'];
    if (envKey != null && envKey.isNotEmpty) {
      return envKey;
    }
    // Fallback vers la clé hardcodée (non recommandé pour la production)
    return 'YOUR_OPENAI_API_KEY';
  }
  
  /// Debug: Affiche l'état de la configuration
  static void debugConfig() {
    final envKey = dotenv.env['OPENAI_API_KEY'];
    print('🔧 Debug AIConfig:');
    print('  - envKey: ${envKey?.substring(0, 10)}...');
    print('  - openaiApiKey: ${openaiApiKey.substring(0, 10)}...');
    print('  - isAIConfigured: $isAIConfigured');
  }
  
  static const String openaiModel = 'gpt-3.5-turbo';
  static const String embeddingModel = 'text-embedding-3-small';
  
  // Configuration Faiss (pour futures intégrations)
  static const String faissEndpoint = 'YOUR_FAISS_ENDPOINT';
  static const int faissDimension = 1536; // Dimension des embeddings OpenAI
  static const String faissIndexName = 'bazaria_ads';
  
  // Configuration Langchain (pour futures intégrations)
  static const String langchainEndpoint = 'YOUR_LANGCHAIN_ENDPOINT';
  static const String langchainApiKey = 'YOUR_LANGCHAIN_API_KEY';
  
  // Configuration de recherche
  static const int maxSearchResults = 50;
  static const double similarityThreshold = 0.3;
  static const double semanticWeight = 0.7;
  static const double textWeight = 0.3;
  
  // Cache configuration
  static const int maxCacheSize = 1000;
  static const Duration cacheExpiration = Duration(hours: 24);
  
  // Scoring weights
  static const double titleWeight = 3.0;
  static const double descriptionWeight = 2.0;
  static const double categoryWeight = 1.5;
  static const double locationWeight = 0.5;
  static const double exactMatchBonus = 2.0;
  static const double categoryMatchBonus = 1.5;
  static const double priceMatchBonus = 1.0;
  
  /// Vérifie si les services d'IA sont configurés
  static bool get isAIConfigured {
    return openaiApiKey != 'YOUR_OPENAI_API_KEY';
  }
  
  /// Vérifie si les services d'IA sont activés (mode simulation)
  static bool get isAIServicesEnabled {
    // Pour l'instant, on active les services en mode simulation
    return true;
  }
  
  /// Obtient la configuration pour l'environnement
  static Map<String, dynamic> getEnvironmentConfig() {
    return {
      'openai': {
        'apiKey': openaiApiKey,
        'model': openaiModel,
        'embeddingModel': embeddingModel,
        'enabled': isAIServicesEnabled,
      },
      'faiss': {
        'endpoint': faissEndpoint,
        'dimension': faissDimension,
        'indexName': faissIndexName,
        'enabled': isAIServicesEnabled,
      },
      'langchain': {
        'endpoint': langchainEndpoint,
        'apiKey': langchainApiKey,
        'enabled': isAIServicesEnabled,
      },
      'search': {
        'maxResults': maxSearchResults,
        'similarityThreshold': similarityThreshold,
        'semanticWeight': semanticWeight,
        'textWeight': textWeight,
      },
      'cache': {
        'maxSize': maxCacheSize,
        'expiration': cacheExpiration.inSeconds,
      },
    };
  }
}

/// Types de recherche disponibles
enum SearchType {
  basic,      // Recherche textuelle simple
  advanced,   // Recherche avec synonymes et scoring
  semantic,   // Recherche sémantique (futur)
  hybrid,     // Recherche hybride (futur)
}

/// Configuration pour différents types de recherche
class SearchConfig {
  static const Map<SearchType, Map<String, dynamic>> configs = {
    SearchType.basic: {
      'maxResults': 20,
      'useCache': false,
      'useSynonyms': false,
    },
    SearchType.advanced: {
      'maxResults': 50,
      'useCache': true,
      'useSynonyms': true,
    },
    SearchType.semantic: {
      'maxResults': 30,
      'useCache': true,
      'useSynonyms': true,
      'useEmbeddings': true,
    },
    SearchType.hybrid: {
      'maxResults': 40,
      'useCache': true,
      'useSynonyms': true,
      'useEmbeddings': true,
      'combineResults': true,
    },
  };
} 