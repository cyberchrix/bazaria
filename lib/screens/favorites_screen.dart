import 'package:flutter/material.dart';
import 'package:appwrite/appwrite.dart' as appw;
import '../models/ad.dart';
import '../services/appwrite_service.dart';
import '../services/favorites_service.dart';
import '../services/saved_searches_service.dart';
import '../widgets/ad_card.dart';
import 'search_screen.dart';
import 'dart:io' show Platform;
import 'package:flutter/cupertino.dart';
import 'home_screen.dart' as home;

class FavoritesScreen extends StatefulWidget {
  final VoidCallback? onFavoritesChanged;
  
  const FavoritesScreen({super.key, this.onFavoritesChanged});

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  
  List<String> _favoriteIds = [];
  List<Ad> _favoriteAds = [];
  List<Map<String, dynamic>> _savedSearches = [];
  Map<String, Map<String, dynamic>> _categoryLabels = {};
  bool _isLoading = true;
  


  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadFavorites();
    _loadCategoryLabels();
    _loadSavedSearches();
  }

  Future<void> _loadCategoryLabels() async {
    try {
      final databases = AppwriteService().databases;
      final result = await databases.listDocuments(
        databaseId: '687ccdcf0000676911f1',
        collectionId: '687ce22e003b2c89f5b8',
        queries: [
          appw.Query.limit(100),
        ],
      );
      
      Map<String, Map<String, dynamic>> categories = {};
      for (var doc in result.documents) {
        categories[doc.$id] = {
          'name': doc.data['name'],
          'icon': doc.data['icon'],
        };
      }
      
      setState(() {
        _categoryLabels = categories;
      });
    } catch (e) {
      print('Erreur lors du chargement des catégories: $e');
    }
  }

  Future<void> _loadFavorites() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Récupérer les IDs des favoris
      final favoriteIds = await FavoritesService.getFavorites();
      
      if (favoriteIds.isEmpty) {
        setState(() {
          _favoriteIds = [];
          _favoriteAds = [];
          _isLoading = false;
        });
        return;
      }

      // Récupérer les annonces depuis Appwrite
      final databases = AppwriteService().databases;
      final result = await databases.listDocuments(
        databaseId: '687ccdcf0000676911f1',
        collectionId: '687ccdde0031f8eda985',
        queries: [
          appw.Query.equal('isActive', true),
          appw.Query.orderDesc('publicationDate'),
        ],
      );

      // Filtrer les annonces favorites
      final allAds = result.documents.map((doc) => Ad.fromAppwrite(doc)).toList();
      final favoriteAds = allAds.where((ad) => favoriteIds.contains(ad.id)).toList();

      setState(() {
        _favoriteIds = favoriteIds;
        _favoriteAds = favoriteAds;
        _isLoading = false;
      });
    } catch (e) {
      print('Erreur lors du chargement des favoris: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadSavedSearches() async {
    try {
      final savedSearches = await SavedSearchesService.getSavedSearches();
      setState(() {
        _savedSearches = savedSearches;
      });
    } catch (e) {
      print('Erreur lors du chargement des recherches sauvegardées: $e');
    }
  }

  Future<void> _removeFromFavorites(String adId) async {
    final success = await FavoritesService.removeFromFavorites(adId);
    if (success) {
      setState(() {
        _favoriteIds.remove(adId);
        _favoriteAds.removeWhere((ad) => ad.id == adId);
      });
      
      // Notifier le parent pour mettre à jour le badge
      widget.onFavoritesChanged?.call();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Annonce retirée des favoris'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }

  Future<void> _clearAllFavorites() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Vider les favoris'),
        content: const Text('Êtes-vous sûr de vouloir supprimer tous vos favoris ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final success = await FavoritesService.clearAllFavorites();
      if (success) {
        setState(() {
          _favoriteIds.clear();
          _favoriteAds.clear();
        });
        
        // Notifier le parent pour mettre à jour le badge
        widget.onFavoritesChanged?.call();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Tous les favoris ont été supprimés'),
              duration: Duration(seconds: 2),
            ),
          );
        }
      }
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        centerTitle: true,
        title: const Text(
          'Mes Favoris',
          style: TextStyle(
            fontSize: 18,
            color: Colors.black,
            fontWeight: FontWeight.normal,
          ),
        ),
        actions: [
          if (_tabController.index == 0 && _favoriteAds.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep),
              onPressed: _clearAllFavorites,
              tooltip: 'Vider tous les favoris',
            ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: Color(0xFFF15A22),
          unselectedLabelColor: Colors.grey,
          indicatorColor: Color(0xFFF15A22),
          tabs: [
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.favorite, size: 16),
                  const SizedBox(width: 4),
                  const Text('Annonces'),
                ],
              ),
            ),
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.search, size: 16),
                  const SizedBox(width: 4),
                  const Text('Recherches'),
                ],
              ),
            ),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                // Onglet Annonces
                _favoriteAds.isEmpty
                    ? _buildEmptyState()
                    : _buildFavoritesList(),
                // Onglet Recherches
                _buildSavedSearches(),
              ],
            ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.favorite_border,
            size: 80,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            'Aucun favori',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Ajoutez des annonces à vos favoris\npour les retrouver facilement',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade500,
            ),
            textAlign: TextAlign.center,
          ),

        ],
      ),
    );
  }

  Widget _buildFavoritesList() {
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: MediaQuery.of(context).size.width > 600 ? 3 : 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: MediaQuery.of(context).size.width > 600 ? 1.0 : 0.7,
      ),
      itemCount: _favoriteAds.length,
      itemBuilder: (context, index) {
        final ad = _favoriteAds[index];
        return AdCard(
          ad: ad,
          index: index,
          categoryLabels: _categoryLabels,
          onFavoriteChanged: () {
            // Mettre à jour la liste locale et notifier le parent
            setState(() {
              _favoriteIds.remove(ad.id);
              _favoriteAds.removeWhere((a) => a.id == ad.id);
            });
            widget.onFavoritesChanged?.call();
          },
          onTap: () {
            if (Platform.isIOS) {
              Navigator.of(context).push(
                CupertinoPageRoute(
                  builder: (context) => home.ProductDetailPage(
                    ad: ad,
                    categoryLabels: _categoryLabels,
                  ),
                  fullscreenDialog: true,
                ),
              );
            } else {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => home.ProductDetailPage(
                    ad: ad,
                    categoryLabels: _categoryLabels,
                  ),
                  fullscreenDialog: true,
                ),
              );
            }
          },
        );
      },
    );
  }

  Widget _buildSavedSearches() {
    if (_savedSearches.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off,
              size: 80,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              'Aucune recherche sauvegardée',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Sauvegardez vos recherches préférées\npour les retrouver facilement',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade500,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _savedSearches.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final search = _savedSearches[index];
        return Card(
          elevation: 1,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: ListTile(
            leading: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Color(0xFFF15A22).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.search,
                color: Color(0xFFF15A22),
                size: 20,
              ),
            ),
            title: Text(
              search['name'] as String,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 16,
              ),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Text(
                  'Recherche: "${search['query']}"',
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 2),
                // Afficher les filtres appliqués
                if (_hasActiveFilters(search['filters'] as Map))
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      _formatFiltersText(search['filters'] as Map),
                      style: TextStyle(
                        color: const Color(0xFFF15A22),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                const SizedBox(height: 2),
                Text(
                  _formatSearchDate(search['date']),
                  style: TextStyle(
                    color: Colors.grey.shade500,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            trailing: PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert),
              onSelected: (value) {
                if (value == 'delete') {
                  deleteSavedSearch(search['id'] as String);
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(Icons.delete, color: Colors.red),
                      SizedBox(width: 8),
                      Text('Supprimer'),
                    ],
                  ),
                ),
              ],
            ),
            onTap: () {
              // Naviguer vers la recherche avec les filtres
              executeSavedSearch(search);
            },
          ),
        );
      },
    );
  }

  String _formatSearchDate(dynamic date) {
    DateTime dateTime;
    
    if (date is String) {
      dateTime = DateTime.parse(date);
    } else if (date is DateTime) {
      dateTime = date;
    } else {
      return 'Date inconnue';
    }
    
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays == 0) {
      return 'Aujourd\'hui';
    } else if (difference.inDays == 1) {
      return 'Hier';
    } else {
      return 'Il y a ${difference.inDays} jours';
    }
  }

  void deleteSavedSearch(String searchId) async {
    final success = await SavedSearchesService.deleteSearch(searchId);
    
    if (success) {
      setState(() {
        _savedSearches.removeWhere((search) => search['id'] == searchId);
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Recherche supprimée'),
          duration: Duration(seconds: 2),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Erreur lors de la suppression'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void executeSavedSearch(Map<String, dynamic> search) {
    // Naviguer vers l'écran de recherche avec les paramètres sauvegardés
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => SearchScreen(
          initialQuery: search['query'] as String,
          initialFilters: Map<String, dynamic>.from(search['filters'] as Map),
        ),
      ),
    );
  }

  /// Vérifie si des filtres sont actifs
  bool _hasActiveFilters(Map filters) {
    return filters.containsKey('category') && filters['category'] != null ||
           filters.containsKey('minPrice') && filters['minPrice'] != null ||
           filters.containsKey('maxPrice') && filters['maxPrice'] != null ||
           filters.containsKey('sortBy') && filters['sortBy'] != null;
  }

  /// Formate le texte des filtres pour l'affichage
  String _formatFiltersText(Map filters) {
    List<String> activeFilters = [];
    
    if (filters.containsKey('category') && filters['category'] != null) {
      // Essayer de trouver le nom de la catégorie
      String categoryDisplay = filters['category'] as String;
      if (_categoryLabels.containsKey(filters['category'])) {
        categoryDisplay = _categoryLabels[filters['category']]!['name'] as String;
      }
      activeFilters.add('Catégorie: $categoryDisplay');
    }
    
    if (filters.containsKey('minPrice') && filters['minPrice'] != null ||
        filters.containsKey('maxPrice') && filters['maxPrice'] != null) {
      if (filters.containsKey('minPrice') && filters['minPrice'] != null &&
          filters.containsKey('maxPrice') && filters['maxPrice'] != null) {
        activeFilters.add('Prix: ${filters['minPrice']}€ - ${filters['maxPrice']}€');
      } else if (filters.containsKey('minPrice') && filters['minPrice'] != null) {
        activeFilters.add('Prix: ≥ ${filters['minPrice']}€');
      } else {
        activeFilters.add('Prix: ≤ ${filters['maxPrice']}€');
      }
    }
    
    if (filters.containsKey('sortBy') && filters['sortBy'] != null) {
      String sortText = '';
      switch (filters['sortBy']) {
        case 'price_asc':
          sortText = 'Prix croissant';
          break;
        case 'price_desc':
          sortText = 'Prix décroissant';
          break;
        case 'date':
          sortText = 'Plus récent';
          break;
        default:
          sortText = filters['sortBy'];
      }
      activeFilters.add('Tri: $sortText');
    }
    
    return activeFilters.join(', ');
  }
} 