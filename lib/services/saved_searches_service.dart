import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:logger/logger.dart';

final logger = Logger();

class SavedSearchesService {
  static const String _storageKey = 'saved_searches';

  /// Récupérer toutes les recherches sauvegardées
  static Future<List<Map<String, dynamic>>> getSavedSearches() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? searchesJson = prefs.getString(_storageKey);
      
      if (searchesJson != null) {
        final List<dynamic> searchesList = json.decode(searchesJson);
        return searchesList.cast<Map<String, dynamic>>();
      }
      
      return [];
    } catch (e) {
      logger.e('Erreur lors de la récupération des recherches sauvegardées: $e');
      return [];
    }
  }

  /// Sauvegarder une nouvelle recherche
  static Future<bool> saveSearch({
    required String name,
    required String query,
    Map<String, dynamic>? filters,
  }) async {
    try {
      final searches = await getSavedSearches();
      
      // Vérifier si une recherche avec le même nom existe déjà
      final existingIndex = searches.indexWhere((search) => search['name'] == name);
      
      final newSearch = {
        'id': DateTime.now().millisecondsSinceEpoch.toString(),
        'name': name,
        'query': query,
        'filters': filters ?? {},
        'date': DateTime.now().toIso8601String(),
      };
      
      if (existingIndex != -1) {
        // Mettre à jour la recherche existante
        searches[existingIndex] = newSearch;
      } else {
        // Ajouter une nouvelle recherche
        searches.add(newSearch);
      }
      
      // Limiter à 10 recherches sauvegardées
      if (searches.length > 10) {
        searches.removeRange(0, searches.length - 10);
      }
      
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_storageKey, json.encode(searches));
      
      logger.d('Recherche sauvegardée: $name');
      return true;
    } catch (e) {
      logger.e('Erreur lors de la sauvegarde de la recherche: $e');
      return false;
    }
  }

  /// Supprimer une recherche sauvegardée
  static Future<bool> deleteSearch(String searchId) async {
    try {
      final searches = await getSavedSearches();
      searches.removeWhere((search) => search['id'] == searchId);
      
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_storageKey, json.encode(searches));
      
      logger.d('Recherche supprimée: $searchId');
      return true;
    } catch (e) {
      logger.e('Erreur lors de la suppression de la recherche: $e');
      return false;
    }
  }

  /// Vérifier si une recherche existe déjà
  static Future<bool> searchExists(String name) async {
    final searches = await getSavedSearches();
    return searches.any((search) => search['name'] == name);
  }
} 