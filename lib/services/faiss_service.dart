import 'package:logger/logger.dart';
import 'ai_config.dart';
import '../models/ad.dart';
import 'dart:math' show sqrt;

final logger = Logger();

/// Service FAISS simulé pour la recherche vectorielle
/// En production, utilisez un vrai serveur FAISS ou Pinecone/Weaviate
class FAISSService {
  static final Map<String, List<double>> _embeddings = {};
  static final Map<String, Ad> _adsMap = {};
  static bool _isInitialized = false;
  
  /// Initialise le service FAISS
  static Future<void> initialize() async {
    if (_isInitialized) return;
    
    try {
      // Simulation d'initialisation
      await Future.delayed(const Duration(milliseconds: 100));
      _isInitialized = true;
      logger.d('✅ Service FAISS initialisé avec succès');
    } catch (e) {
      logger.e('❌ Erreur initialisation FAISS: $e');
      rethrow;
    }
  }
  
  /// Ajoute un embedding pour une annonce
  static Future<void> addEmbedding(String adId, List<double> embedding, Ad ad) async {
    try {
      await initialize();
      
      _embeddings[adId] = embedding;
      _adsMap[adId] = ad;
      
      logger.d('🔍 Embedding ajouté pour annonce: $adId');
    } catch (e) {
      logger.e('❌ Erreur ajout embedding: $e');
    }
  }
  
  /// Recherche par similarité vectorielle
  static Future<List<MapEntry<Ad, double>>> searchBySimilarity(
    List<double> queryEmbedding, {
    int maxResults = 20,
    double threshold = 0.3,
  }) async {
    try {
      await initialize();
      
      final List<MapEntry<Ad, double>> results = [];
      
      for (final entry in _embeddings.entries) {
        final adId = entry.key;
        final adEmbedding = entry.value;
        final ad = _adsMap[adId];
        
        if (ad != null) {
          final similarity = _calculateCosineSimilarity(queryEmbedding, adEmbedding);
          
          if (similarity >= threshold) {
            results.add(MapEntry(ad, similarity));
          }
        }
      }
      
      // Trier par similarité décroissante
      results.sort((a, b) => b.value.compareTo(a.value));
      
      logger.d('🔍 Recherche vectorielle: ${results.length} résultats');
      return results.take(maxResults).toList();
    } catch (e) {
      logger.e('❌ Erreur recherche vectorielle: $e');
      return [];
    }
  }
  
  /// Calcule la similarité cosinus entre deux vecteurs
  static double _calculateCosineSimilarity(List<double> a, List<double> b) {
    if (a.length != b.length) return 0.0;
    
    double dotProduct = 0.0;
    double normA = 0.0;
    double normB = 0.0;
    
    for (int i = 0; i < a.length; i++) {
      dotProduct += a[i] * b[i];
      normA += a[i] * a[i];
      normB += b[i] * b[i];
    }
    
    if (normA == 0.0 || normB == 0.0) return 0.0;
    
    return dotProduct / (sqrt(normA) * sqrt(normB));
  }
  
  /// Génère un embedding simulé pour un texte
  static List<double> generateSimulatedEmbedding(String text) {
    // Simulation d'embedding basée sur les caractères du texte
    final List<double> embedding = [];
    final textLower = text.toLowerCase();
    
    // Créer un vecteur de 1536 dimensions (comme OpenAI)
    for (int i = 0; i < 1536; i++) {
      double value = 0.0;
      
      // Utiliser les caractères du texte pour générer des valeurs
      for (int j = 0; j < textLower.length; j++) {
        final charCode = textLower.codeUnitAt(j);
        value += (charCode * (i + 1)) % 1000 / 1000.0;
      }
      
      // Normaliser entre -1 et 1
      embedding.add((value - 0.5) * 2);
    }
    
    return embedding;
  }
  
  /// Indexe toutes les annonces avec des embeddings simulés
  static Future<void> indexAds(List<Ad> ads) async {
    try {
      await initialize();
      
      for (final ad in ads) {
        final text = '${ad.title} ${ad.description}';
        final embedding = generateSimulatedEmbedding(text);
        await addEmbedding(ad.id, embedding, ad);
      }
      
      logger.d('🔍 ${ads.length} annonces indexées avec succès');
    } catch (e) {
      logger.e('❌ Erreur indexation annonces: $e');
    }
  }
  
  /// Nettoie l'index
  static void clearIndex() {
    _embeddings.clear();
    _adsMap.clear();
    logger.d('🔍 Index FAISS nettoyé');
  }
  
  /// Obtient des statistiques de l'index
  static Map<String, dynamic> getIndexStats() {
    return {
      'totalEmbeddings': _embeddings.length,
      'totalAds': _adsMap.length,
      'isInitialized': _isInitialized,
    };
  }
} 