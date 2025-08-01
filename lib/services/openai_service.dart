import 'package:dart_openai/dart_openai.dart';
import 'package:logger/logger.dart';
import 'ai_config.dart';

final logger = Logger();

class OpenAIService {
  static bool _isInitialized = false;
  
  /// Initialise le service OpenAI
  static Future<void> initialize() async {
    if (_isInitialized) return;
    
    try {
      logger.d('🔧 Initialisation OpenAI...');
      logger.d('  - Clé API: ${AIConfig.openaiApiKey.substring(0, 10)}...');
      logger.d('  - Base URL: https://api.openai.com/v1');
      
      OpenAI.apiKey = AIConfig.openaiApiKey;
      OpenAI.baseUrl = 'https://api.openai.com/v1';
      
      _isInitialized = true;
      logger.d('✅ Service OpenAI initialisé avec succès');
    } catch (e) {
      logger.e('❌ Erreur initialisation OpenAI: $e');
      rethrow;
    }
  }
  
  /// Améliore une requête utilisateur avec l'IA
  static Future<String> enhanceQuery(String userQuery) async {
    try {
      await initialize();
      
      // Debug de la configuration
      AIConfig.debugConfig();
      
      // Vérifier que la clé API est valide
      if (AIConfig.openaiApiKey == 'YOUR_OPENAI_API_KEY' || AIConfig.openaiApiKey.isEmpty) {
        logger.w('⚠️ Clé API OpenAI non configurée, utilisation du fallback local');
        return _enhanceQueryLocally(userQuery);
      }
      
      // Vérifier le format de la clé API
      if (!AIConfig.openaiApiKey.startsWith('sk-')) {
        logger.w('⚠️ Format de clé API invalide, utilisation du fallback local');
        return _enhanceQueryLocally(userQuery);
      }
      
      final completion = await OpenAI.instance.chat.create(
        model: AIConfig.openaiModel,
        messages: [
          OpenAIChatCompletionChoiceMessageModel(
            role: OpenAIChatMessageRole.system,
            content: '''
Tu es un assistant spécialisé dans l'amélioration de requêtes de recherche pour un marketplace d'objets d'occasion.
Ta mission est d'améliorer les requêtes utilisateur pour qu'elles soient plus précises et pertinentes.

Règles:
1. Garde le sens original de la requête
2. Ajoute des synonymes pertinents
3. Précise les catégories si ambiguë
4. Ajoute des détails techniques si nécessaire
5. Retourne UNIQUEMENT la requête améliorée, sans explication

Exemples:
- "velo" → "vélo bicyclette cycle VTT"
- "iphone pas cher" → "iPhone smartphone Apple pas cher bon prix"
- "meuble salon" → "meuble mobilier salon canapé fauteuil table"
''',
          ),
          OpenAIChatCompletionChoiceMessageModel(
            role: OpenAIChatMessageRole.user,
            content: userQuery,
          ),
        ],
        maxTokens: 100,
        temperature: 0.3,
      );
      
      final enhancedQuery = completion.choices.first.message.content.trim();
      logger.d('🔍 Requête améliorée: "$userQuery" → "$enhancedQuery"');
      
      return enhancedQuery;
    } catch (e) {
      logger.e('❌ Erreur amélioration requête: $e');
      // En cas d'erreur, retourner la requête originale avec des améliorations basiques
      return _enhanceQueryLocally(userQuery);
    }
  }
  
  /// Amélioration locale de la requête (fallback)
  static String _enhanceQueryLocally(String query) {
    final queryLower = query.toLowerCase();
    final enhancements = <String>[];
    
    // Ajouter la requête originale
    enhancements.add(query);
    
    // Améliorations basiques selon les mots-clés
    if (queryLower.contains('iphone') || queryLower.contains('apple')) {
      enhancements.addAll(['smartphone', 'Apple', 'iOS']);
    }
    if (queryLower.contains('velo') || queryLower.contains('vélo') || queryLower.contains('bicyclette')) {
      enhancements.addAll(['vélo', 'bicyclette', 'cycle', 'VTT']);
    }
    if (queryLower.contains('meuble') || queryLower.contains('mobilier')) {
      enhancements.addAll(['meuble', 'mobilier', 'furniture']);
    }
    if (queryLower.contains('voiture') || queryLower.contains('auto')) {
      enhancements.addAll(['voiture', 'automobile', 'auto']);
    }
    if (queryLower.contains('telephone') || queryLower.contains('téléphone') || queryLower.contains('phone')) {
      enhancements.addAll(['téléphone', 'smartphone', 'mobile']);
    }
    if (queryLower.contains('ordinateur') || queryLower.contains('pc') || queryLower.contains('laptop')) {
      enhancements.addAll(['ordinateur', 'PC', 'laptop', 'computer']);
    }
    if (queryLower.contains('livre') || queryLower.contains('book')) {
      enhancements.addAll(['livre', 'book', 'roman', 'essai']);
    }
    if (queryLower.contains('vetement') || queryLower.contains('vêtement') || queryLower.contains('habit')) {
      enhancements.addAll(['vêtement', 'habit', 'vetement', 'clothing']);
    }
    
    logger.d('🔍 Amélioration locale: "$query" → "${enhancements.join(' ')}"');
    return enhancements.join(' ');
  }
  
  /// Extrait des entités nommées d'une requête
  static Future<Map<String, dynamic>> extractEntities(String query) async {
    try {
      await initialize();
      
      final completion = await OpenAI.instance.chat.create(
        model: AIConfig.openaiModel,
        messages: [
          OpenAIChatCompletionChoiceMessageModel(
            role: OpenAIChatMessageRole.system,
            content: '''
Extrais les entités nommées de cette requête de recherche pour un marketplace.
Retourne UNIQUEMENT un JSON avec ces champs:
{
  "category": "catégorie principale",
  "brand": "marque si présente",
  "model": "modèle si présent", 
  "condition": "état (neuf, bon état, etc.)",
  "price_range": "gamme de prix",
  "location": "localisation",
  "features": ["caractéristiques spécifiques"]
}
''',
          ),
          OpenAIChatCompletionChoiceMessageModel(
            role: OpenAIChatMessageRole.user,
            content: query,
          ),
        ],
        maxTokens: 200,
        temperature: 0.1,
      );
      
      final response = completion.choices.first.message.content.trim();
      final entities = Map<String, dynamic>.from(
        _parseJsonResponse(response),
      );
      
      logger.d('🔍 Entités extraites: $entities');
      return entities;
    } catch (e) {
      logger.e('❌ Erreur extraction entités: $e');
      return {};
    }
  }
  
  /// Parse une réponse JSON simple
  static Map<String, dynamic> _parseJsonResponse(String response) {
    try {
      // Nettoyer la réponse
      final cleanResponse = response
          .replaceAll('```json', '')
          .replaceAll('```', '')
          .trim();
      
      // Parse basique - en production, utilisez dart:convert
      return {'raw_response': cleanResponse};
    } catch (e) {
      logger.e('❌ Erreur parsing JSON: $e');
      return {};
    }
  }

  /// Obtient les statistiques du service OpenAI
  static Future<Map<String, dynamic>> getServiceStats() async {
    try {
      await initialize();
      return {
        'isInitialized': _isInitialized,
        'apiKey': AIConfig.openaiApiKey.isNotEmpty ? '***${AIConfig.openaiApiKey.substring(AIConfig.openaiApiKey.length - 4)}' : 'Non configuré',
        'model': AIConfig.openaiModel,
        'embeddingModel': AIConfig.embeddingModel,
        'enabled': AIConfig.isAIServicesEnabled,
      };
    } catch (e) {
      logger.e('❌ Erreur stats OpenAI: $e');
      return {
        'isInitialized': false,
        'error': e.toString(),
      };
    }
  }
  
  /// Test de connexion à l'API OpenAI
  static Future<bool> testConnection() async {
    try {
      await initialize();
      
      logger.d('🔧 Test de connexion OpenAI...');
      logger.d('  - Clé API: ${AIConfig.openaiApiKey.substring(0, 10)}...');
      logger.d('  - Longueur clé: ${AIConfig.openaiApiKey.length}');
      logger.d('  - Modèle: ${AIConfig.openaiModel}');
      logger.d('  - Clé valide: ${AIConfig.openaiApiKey.startsWith('sk-')}');
      
      // Vérification préalable
      if (AIConfig.openaiApiKey == 'YOUR_OPENAI_API_KEY' || AIConfig.openaiApiKey.isEmpty) {
        logger.e('❌ Clé API non configurée');
        return false;
      }
      
      if (!AIConfig.openaiApiKey.startsWith('sk-')) {
        logger.e('❌ Format de clé API invalide');
        return false;
      }
      
      logger.d('🔧 Tentative d\'appel API...');
      
      final completion = await OpenAI.instance.chat.create(
        model: AIConfig.openaiModel,
        messages: [
          OpenAIChatCompletionChoiceMessageModel(
            role: OpenAIChatMessageRole.user,
            content: 'Test de connexion - réponds juste "OK"',
          ),
        ],
        maxTokens: 10,
        temperature: 0.1,
      );
      
      final response = completion.choices.first.message.content.trim();
      logger.d('✅ Connexion OpenAI réussie: "$response"');
      return true;
    } catch (e) {
      logger.e('❌ Erreur test connexion OpenAI: $e');
      logger.e('❌ Type d\'erreur: ${e.runtimeType}');
      if (e.toString().contains('html')) {
        logger.e('❌ L\'API retourne du HTML au lieu de JSON');
      }
      return false;
    }
  }
} 