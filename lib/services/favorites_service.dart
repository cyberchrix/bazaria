import 'package:shared_preferences/shared_preferences.dart';
import '../models/ad.dart';
import 'package:logger/logger.dart';

final logger = Logger();

class FavoritesService {
  static const String _favoritesKey = 'user_favorites';
  
  // Récupérer tous les favoris
  static Future<List<String>> getFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    final favoritesJson = prefs.getStringList(_favoritesKey) ?? [];
    return favoritesJson;
  }
  
  // Vérifier si une annonce est en favori
  static Future<bool> isFavorite(String adId) async {
    final favorites = await getFavorites();
    return favorites.contains(adId);
  }
  
  // Ajouter une annonce aux favoris
  static Future<bool> addToFavorites(String adId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final favorites = await getFavorites();
      
      if (!favorites.contains(adId)) {
        favorites.add(adId);
        await prefs.setStringList(_favoritesKey, favorites);
        return true;
      }
      return false;
    } catch (e) {
      logger.e('Erreur lors de l\'ajout aux favoris: $e');
      return false;
    }
  }
  
  // Retirer une annonce des favoris
  static Future<bool> removeFromFavorites(String adId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final favorites = await getFavorites();
      
      if (favorites.contains(adId)) {
        favorites.remove(adId);
        await prefs.setStringList(_favoritesKey, favorites);
        return true;
      }
      return false;
    } catch (e) {
      logger.e('Erreur lors de la suppression des favoris: $e');
      return false;
    }
  }
  
  // Basculer l'état favori (ajouter/retirer)
  static Future<bool> toggleFavorite(String adId) async {
    final isCurrentlyFavorite = await isFavorite(adId);
    
    if (isCurrentlyFavorite) {
      return await removeFromFavorites(adId);
    } else {
      return await addToFavorites(adId);
    }
  }
  
  // Récupérer les annonces favorites complètes
  static Future<List<Ad>> getFavoriteAds() async {
    try {
      final favoriteIds = await getFavorites();
      if (favoriteIds.isEmpty) return [];
      
      // Ici vous pourriez récupérer les annonces depuis Appwrite
      // Pour l'instant, on retourne une liste vide
      // TODO: Implémenter la récupération depuis Appwrite
      return [];
    } catch (e) {
      logger.e('Erreur lors de la récupération des favoris: $e');
      return [];
    }
  }
  
  // Vider tous les favoris
  static Future<bool> clearAllFavorites() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_favoritesKey);
      return true;
    } catch (e) {
      logger.e('Erreur lors de la suppression de tous les favoris: $e');
      return false;
    }
  }
} 