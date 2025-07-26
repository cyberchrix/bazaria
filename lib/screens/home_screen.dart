import 'package:flutter/material.dart';
import '../screens/add_ad_screen.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:async';
import '../theme/app_theme.dart';
import '../models/ad.dart';
import 'package:intl/intl.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../screens/search_screen.dart';
import 'package:badges/badges.dart' as badges;
import '../services/category_service.dart';
import '../screens/profile_screen.dart';
import '../screens/messages_screen.dart';
import '../screens/favorites_screen.dart';
import 'package:shimmer/shimmer.dart';
import 'package:logger/logger.dart';
import 'package:appwrite/appwrite.dart' as appw;
import '../services/appwrite_service.dart';
import '../screens/login_screen.dart';
import 'dart:convert';
import 'dart:io' show Platform;
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import '../services/notification_service.dart';
import '../services/favorites_service.dart';
import '../widgets/ad_card.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:http/http.dart' as http;

final logger = Logger();

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  int _selectedIndex = 0;
  List<Ad> _ads = [];
  Map<String, Map<String, dynamic>> _categoryLabels = {};
  bool _loadingAds = true;
  int favoritesCount = 0;
  int unreadNotifications = 3;
  StreamSubscription? _realtimeSub;
  
  // Carrousel des publicités
  final PageController _adPageController = PageController(viewportFraction: 1.0);
  Timer? _adAutoScrollTimer;
  final int _currentAdIndex = 0;
  
  // Connectivité
  bool _isConnected = true;
  bool _isCheckingConnection = false;
  int newMessagesCount = 2; // Nombre de messages non lus

  @override
  void initState() {
    super.initState();
    _checkConnectivity();
    fetchCategoryLabels().then((labels) {
      logger.d('Catégories chargées: ${labels.length}');
      logger.d('Catégories chargées: ${labels.values.toList()}');
      logger.d('IDs des catégories: ${labels.keys.toList()}');
      setState(() {
        _categoryLabels = labels;
      });
    });
    _listenToAdsRealtime();
    _loadFavoritesCount();
    
    // Forcer un rafraîchissement du compteur de favoris après un délai
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        _loadFavoritesCount();
      }
    });
  }

  Future<bool> _hasInternetAccess() async {
    // Sur simulateur iOS, on considère toujours qu'il y a une connexion
    if (Platform.isIOS && !kReleaseMode) {
      logger.d('📱 Simulateur iOS détecté - connexion supposée OK');
      return true;
    }
    
    // Désactiver complètement sur simulateur pour debug
    if (!kReleaseMode) {
      logger.d('🔧 Mode debug - connexion supposée OK');
      return true;
    }
    
    try {
      final connectivityResult = await Connectivity().checkConnectivity();
      logger.d('🔍 État de connectivité: $connectivityResult');
      final hasConnection = connectivityResult != ConnectivityResult.none;
      logger.d('📡 Connexion détectée: $hasConnection');
      return hasConnection;
    } catch (e) {
      logger.e('❌ Erreur détection connectivité: $e');
      return false;
    }
  }

  Future<void> _checkConnectivity() async {
    // Sur simulateur, on considère toujours qu'il y a une connexion
    if (!kReleaseMode) {
      logger.d('🔧 Mode debug - connexion supposée OK');
      setState(() {
        _isConnected = true;
        _isCheckingConnection = false;
      });
      return;
    }
    
    try {
      setState(() { _isCheckingConnection = true; });
      final connectivityResult = await Connectivity().checkConnectivity();
      bool hasNetwork = connectivityResult != ConnectivityResult.none;
      bool hasInternet = false;
      if (hasNetwork) {
        hasInternet = await _hasInternetAccess();
      }
      setState(() {
        _isConnected = hasNetwork && hasInternet;
        _isCheckingConnection = false;
      });
      // Écouter les changements de connectivité
      Connectivity().onConnectivityChanged.listen((ConnectivityResult result) async {
        bool hasNetwork = result != ConnectivityResult.none;
        bool hasInternet = false;
        if (hasNetwork) {
          hasInternet = await _hasInternetAccess();
        }
        setState(() {
          _isConnected = hasNetwork && hasInternet;
        });
      });
    } catch (e) {
      print('Erreur lors de la vérification de connectivité: $e');
      setState(() {
        _isConnected = false;
        _isCheckingConnection = false;
      });
    }
  }

  void _listenToAdsRealtime() {
    final realtime = appw.Realtime(AppwriteService().client);
    _realtimeSub = realtime.subscribe([
      'databases.687ccdcf0000676911f1.collections.687ccdde0031f8eda985.documents'
    ]).stream.listen((event) {
      fetchAdsFromAppwrite().then((ads) {
        setState(() {
          _ads = ads;
          _loadingAds = false;
        });
      });
    });
    // Charge initialement les annonces
    fetchAdsFromAppwrite().then((ads) {
      setState(() {
        _ads = ads;
        _loadingAds = false;
      });
    });
  }

  Future<void> _loadFavoritesCount() async {
    try {
      final favorites = await FavoritesService.getFavorites();
      logger.d('Favoris chargés: ${favorites.length} - IDs: $favorites');
      setState(() {
        favoritesCount = favorites.length;
      });
      logger.d('Compteur de favoris mis à jour: $favoritesCount');
    } catch (e) {
      logger.e('Erreur lors du chargement du nombre de favoris: $e');
      setState(() {
        favoritesCount = 0;
      });
    }
  }

  Widget _buildNoConnectionView() {
    return Center(
      child: Container(
        margin: const EdgeInsets.all(32),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _isCheckingConnection ? Icons.wifi_find : Icons.wifi_off,
              size: 64,
              color: _isCheckingConnection ? Colors.orange : Colors.red,
            ),
            const SizedBox(height: 16),
            Text(
              _isCheckingConnection 
                  ? 'Vérification de la connexion...'
                  : 'Aucune connexion Internet',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              _isCheckingConnection
                  ? 'Veuillez patienter pendant que nous vérifions votre connexion.'
                  : 'Vérifiez votre connexion Internet et réessayez.',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade600,
              ),
              textAlign: TextAlign.center,
            ),
            if (!_isCheckingConnection) ...[
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () => _checkConnectivity(),
                icon: const Icon(Icons.refresh),
                label: const Text('Réessayer'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // Grouper les annonces par catégorie
  Map<String, List<Ad>> _groupAdsByCategory() {
    Map<String, List<Ad>> groupedAds = {};
    
    for (Ad ad in _ads) {
      String categoryId = ad.mainCategoryId;
      if (!groupedAds.containsKey(categoryId)) {
        groupedAds[categoryId] = [];
      }
      groupedAds[categoryId]!.add(ad);
    }
    
    return groupedAds;
  }

  // Obtenir les annonces récentes par catégorie (max 5 par catégorie)
  Map<String, List<Ad>> _getRecentAdsByCategory() {
    Map<String, List<Ad>> groupedAds = _groupAdsByCategory();
    Map<String, List<Ad>> recentAds = {};
    
    groupedAds.forEach((categoryId, ads) {
      // Trier par date de publication (plus récent en premier) et prendre max 5
      ads.sort((a, b) => b.publicationDate.compareTo(a.publicationDate));
      recentAds[categoryId] = ads.take(5).toList();
    });
    
    return recentAds;
  }

  // Obtenir le nombre total d'annonces par catégorie
  Map<String, int> _getTotalAdsCountByCategory() {
    Map<String, List<Ad>> groupedAds = _groupAdsByCategory();
    Map<String, int> totalCounts = {};
    
    groupedAds.forEach((categoryId, ads) {
      totalCounts[categoryId] = ads.length;
    });
    
    return totalCounts;
  }

  // Construire les sliders par catégorie
  Widget _buildCategorySliders() {
    if (_loadingAds || _ads.isEmpty) {
      return const SizedBox.shrink();
    }

    final recentAdsByCategory = _getRecentAdsByCategory();
    final totalAdsByCategory = _getTotalAdsCountByCategory();
    final rootCategories = _categoryLabels.values
        .where((cat) => cat['parentId'] == null)
        .toList()
      ..sort((a, b) => (a['order'] ?? 0).compareTo(b['order'] ?? 0));

    return Column(
      children: rootCategories.map((category) {
        final categoryId = category['\$id'] as String;
        final categoryAds = recentAdsByCategory[categoryId];
        final totalAdsInCategory = totalAdsByCategory[categoryId] ?? 0;
        
        // Ne pas afficher les catégories sans annonces
        if (categoryAds == null || categoryAds.isEmpty) {
          return const SizedBox.shrink();
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => CategoryScreen(
                      categoryId: categoryId,
                      categoryName: category['name'],
                      categoryLabels: _categoryLabels,
                    ),
                  ),
                );
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(
                          getCategoryIcon(category['icon'] as String?),
                          size: 24,
                          color: AppTheme.primaryColor,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          category['name'],
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                      ],
                    ),
                    const Icon(
                      Icons.chevron_right,
                      color: Colors.black,
                      size: 24,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 247, // Hauteur augmentée pour compenser l'overflow jusqu'à 27px
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: EdgeInsets.zero, // Supprimer le padding car il y a déjà un padding dans le Container parent
                itemCount: categoryAds.length + (totalAdsInCategory > 5 ? 1 : 0), // +1 pour le bouton "+" seulement si plus de 5 annonces
                itemBuilder: (context, index) {
                  if (index == categoryAds.length && totalAdsInCategory > 5) {
                    // Bouton "+" à la fin seulement si plus de 5 annonces
                    return Container(
                      width: 120,
                      height: 220, // Hauteur cohérente avec les cartes
                      margin: const EdgeInsets.only(right: 12),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: InkWell(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => CategoryScreen(
                                categoryId: categoryId,
                                categoryName: category['name'],
                                categoryLabels: _categoryLabels,
                              ),
                            ),
                          );
                        },
                        borderRadius: BorderRadius.circular(12),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: const Color(0xFFF15A22),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: const Icon(
                                Icons.add,
                                color: Colors.white,
                                size: 24,
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Voir plus',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  final ad = categoryAds[index];
                  final screenWidth = MediaQuery.of(context).size.width;
                  final cardWidth = (screenWidth - 32 - 12) / 2; // Même calcul que la grille
                  return Container(
                    width: cardWidth,
                    height: 220, // Hauteur augmentée pour éviter l'overflow
                    margin: const EdgeInsets.only(right: 12),
                    child: AdCard(
                      ad: ad,
                      index: index,
                      categoryLabels: _categoryLabels,
                      onFavoriteChanged: _loadFavoritesCount,
                      onTap: () {
                        if (Platform.isIOS) {
                          Navigator.of(context).push(
                            CupertinoPageRoute(
                              builder: (context) => ProductDetailPage(ad: ad, categoryLabels: _categoryLabels),
                              fullscreenDialog: true,
                            ),
                          );
                        } else {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) => ProductDetailPage(ad: ad, categoryLabels: _categoryLabels),
                              fullscreenDialog: true,
                            ),
                          );
                        }
                      },
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 24),
          ],
        );
      }).toList(),
    );
  }

  // --- Appwrite: récupération des catégories ---
  Future<Map<String, Map<String, dynamic>>> fetchCategoryLabels() async {
    final databases = AppwriteService().databases;
    final result = await databases.listDocuments(
      databaseId: '687ccdcf0000676911f1', // Remplace par ton databaseId
      collectionId: '687ce22e003b2c89f5b8', // Remplace par ta collectionId de catégories
      queries: [
        appw.Query.limit(100),
      ],
    );
    for (final doc in result.documents) {
      logger.d(doc.data);
    }
    // On retourne un map id -> data
    return {
      for (final doc in result.documents)
        doc.$id: doc.data
    };
  }

  void _onItemTapped(int index) async {
    // Vérifie l'authentification pour Publier (2) et Profil (4)
    if (index == 2 || index == 4) {
      final user = await AppwriteService().getCurrentUser();
      if (!mounted) return;
      if (user == null) {
        final loggedIn = await Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const LoginScreen()),
        );
        if (!mounted) return;
        if (loggedIn != true) return; // L'utilisateur n'a pas complété l'auth
      }
      if (index == 2) {
        if (!mounted) return;
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const AddAdScreen(),
          ),
        );
        if (!mounted) return;
        // Après retour, recharge la liste
        fetchAdsFromAppwrite().then((ads) {
          setState(() {
            _ads = ads;
          });
        });
        return;
      }
      if (index == 4) {
        setState(() {
          _selectedIndex = 4;
        });
        return;
      }
    }
    
    // Si on navigue vers les favoris, rafraîchir le compteur
    if (index == 1) {
      await _loadFavoritesCount();
    }
    
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  void dispose() {
    _realtimeSub?.cancel();
    _adAutoScrollTimer?.cancel();
    _adPageController.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Rafraîchir le compteur de favoris quand on revient sur l'écran
    if (_selectedIndex == 1) {
      _loadFavoritesCount();
    }
  }

  // --- Appwrite: récupération des annonces ---
  Future<List<Ad>> fetchAdsFromAppwrite() async {
    final databases = AppwriteService().databases;
    final result = await databases.listDocuments(
      databaseId: '687ccdcf0000676911f1', // Remplace par ton databaseId
      collectionId: '687ccdde0031f8eda985', // Remplace par ta collectionId
      queries: [
        appw.Query.equal('isActive', true),
        appw.Query.orderDesc('publicationDate'),
        appw.Query.limit(10),
      ],
    );
    return result.documents.map((doc) => Ad.fromAppwrite(doc)).toList();
  }

  @override
  Widget build(BuildContext context) {
    final accueilView = CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.all(16.0),
          sliver: SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Zone de recherche
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: TextField(
                  readOnly: true,
                  onTap: () {
                    Navigator.of(context).push(
                      PageRouteBuilder(
                        pageBuilder: (context, animation, secondaryAnimation) => const SearchScreen(),
                        transitionsBuilder: (context, animation, secondaryAnimation, child) {
                          return FadeTransition(
                            opacity: animation,
                            child: child,
                          );
                        },
                        transitionDuration: const Duration(milliseconds: 350),
                      ),
                    );
                  },
                  textAlignVertical: TextAlignVertical.center,
                  decoration: InputDecoration(
                    hintText: 'Rechercher un produit...',
                    prefixIcon: Icon(Icons.search),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.camera_alt),
                      onPressed: () {
                        // Action pour prendre une photo à implémenter
                      },
                    ),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                  ),
                ),
                ),
                const SizedBox(height: 24),
                // Menu horizontal des catégories avec pictos
                Builder(
                  builder: (context) {
                    final rootCategories = _categoryLabels.values
                        .where((cat) => cat['parentId'] == null)
                        .toList()
                      ..sort((a, b) => (a['order'] ?? 0).compareTo(b['order'] ?? 0));
                    return SizedBox(
                      height: 90,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: rootCategories.length,
                        separatorBuilder: (context, index) => const SizedBox(width: 16),
                        itemBuilder: (context, index) {
                          final category = rootCategories[index];
                          return GestureDetector(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => CategoryScreen(
                                    categoryId: category['\$id'],
                                    categoryName: category['name'],
                                    categoryLabels: _categoryLabels,
                                  ),
                                ),
                              );
                            },
                            child: Column(
                              children: [
                                CircleAvatar(
                                  radius: 28,
                                  backgroundColor: Color(0xFFFFFAF3),
                                  child: Icon(
                                    getCategoryIcon(category['icon'] as String?),
                                    size: 30,
                                    color: AppTheme.primaryColor,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  category['name'],
                                  style: TextStyle(fontSize: 13, color: AppTheme.primaryColor, fontWeight: FontWeight.w600),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    );
                  },
                ),
                const SizedBox(height: 24),
                // Carrousel d'images de publicités masqué
                const _AdCarousel(),
                const SizedBox(height: 24),
                // Sliders par catégorie
                _buildCategorySliders(),
                const SizedBox(height: 24),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: GestureDetector(
                    // onLongPress supprimé (seed Firestore)
                    child: const Text(
                      'Annonces récentes',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        ),
        // Sliver pour la grille d'annonces récentes
        _loadingAds
          ? SliverToBoxAdapter(child: Center(child: CircularProgressIndicator()))
          : _ads.isEmpty
              ? SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(32.0),
                    child: Column(
                      children: [
                        Icon(
                          Icons.inbox_outlined,
                          size: 64,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Aucune annonce',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w500,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Soyez le premier à publier une annonce !',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade500,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                )
                              : SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  sliver: SliverGrid(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final ad = _ads[index];
                        return AdCard(
                          ad: ad,
                          index: index,
                          categoryLabels: _categoryLabels,
                          onFavoriteChanged: _loadFavoritesCount,
                          onTap: () {
                            if (Platform.isIOS) {
                              Navigator.of(context).push(
                                CupertinoPageRoute(
                                  builder: (context) => ProductDetailPage(ad: ad, categoryLabels: _categoryLabels),
                                  fullscreenDialog: true,
                                ),
                              );
                            } else {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (context) => ProductDetailPage(ad: ad, categoryLabels: _categoryLabels),
                                  fullscreenDialog: true,
                                ),
                              );
                            }
                          },
                        );
                      },
                      childCount: _ads.length,
                    ),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: MediaQuery.of(context).size.width > 600 ? 3 : 2,
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      childAspectRatio: 0.6,
                    ),
                  ),
                ),
      ],
    );
    final views = <Widget>[
      accueilView,
      FavoritesScreen(onFavoritesChanged: _loadFavoritesCount),
      Center(
        child: ElevatedButton.icon(
          icon: const Icon(Icons.add),
          label: const Text('Déposer une annonce'),
          onPressed: null, // À activer selon la logique souhaitée
        ),
      ),
      const MessagesScreen(),
      const ProfileScreen(),
    ];
    return Scaffold(
      appBar: (_selectedIndex == 1 || _selectedIndex == 3 || _selectedIndex == 4)
        ? null // Pas d'AppBar pour l'écran des favoris, messages et profil (ils ont leur propre AppBar)
        : AppBar(
            title: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                SvgPicture.asset(
                  'assets/bazaria_logo.svg',
                  height: 45,
                  alignment: Alignment.center,
                ),
                const Text(
                  'Bazaria',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 22,
                    color: AppTheme.primaryColor,
                    letterSpacing: 0.5,
                    height: 1.0,
                  ),
                ),
              ],
            ),
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: IconButton(
                  icon: badges.Badge(
                    showBadge: unreadNotifications > 0,
                    badgeContent: Text(
                      '$unreadNotifications',
                      style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                    badgeStyle: badges.BadgeStyle(
                      badgeColor: Color(0xFFF15A22),
                      padding: const EdgeInsets.all(7),
                    ),
                    position: badges.BadgePosition.topEnd(top: -6, end: -6),
                    child: const Icon(Icons.notifications),
                  ),
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (context) => const NotificationsScreen()),
                    );
                  },
                ),
              ),
            ],
          ),
      body: (!_isConnected || _isCheckingConnection)
          ? _buildNoConnectionView()
          : views[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        items: <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.home, color: AppTheme.primaryColor),
            label: 'Accueil',
          ),
          BottomNavigationBarItem(
            icon: favoritesCount > 0 
              ? badges.Badge(
                  showBadge: true,
                  badgeContent: Text(
                    '$favoritesCount',
                    style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                  badgeStyle: badges.BadgeStyle(
                    badgeColor: Color(0xFFF15A22),
                    padding: const EdgeInsets.all(6),
                  ),
                  child: Icon(Icons.favorite, color: AppTheme.primaryColor),
                )
              : Icon(Icons.favorite, color: AppTheme.primaryColor),
            label: 'Favoris',
          ),
          BottomNavigationBarItem(
            icon: Padding(
              padding: EdgeInsets.only(top: 2),
              child: Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: Color(0xFFF15A22),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Color.fromRGBO(241, 90, 34, 0.18),
                      blurRadius: 6,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: Center(
                  child: Icon(Icons.add, color: Colors.white, size: 26),
                ),
              ),
            ),
            label: 'Publier',
          ),
          BottomNavigationBarItem(
            icon: badges.Badge(
              showBadge: newMessagesCount > 0,
              badgeContent: Text(
                '$newMessagesCount',
                style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
              ),
              badgeStyle: badges.BadgeStyle(
                badgeColor: Color(0xFFF15A22),
                padding: const EdgeInsets.all(6),
              ),
              child: Icon(Icons.message, color: AppTheme.primaryColor),
            ),
            label: 'Messages',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person, color: AppTheme.primaryColor),
            label: 'Profil',
          ),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: Colors.black,
        onTap: _onItemTapped,
      ),
    );
  }
}

// Déplace ProductDetailPage en dehors de HomeScreen pour la réutiliser
class ProductDetailPage extends StatefulWidget {
  final Ad ad;
  final Map<String, Map<String, dynamic>> categoryLabels;
  const ProductDetailPage({super.key, required this.ad, required this.categoryLabels});

  @override
  State<ProductDetailPage> createState() => _ProductDetailPageState();
}

class _ProductDetailPageState extends State<ProductDetailPage> {
  double _appBarOpacity = 0.0;
  int _currentImageIndex = 0;
  final PageController _imagePageController = PageController();

  @override
  Widget build(BuildContext context) {
                        return Scaffold(
        backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        title: AnimatedOpacity(
          opacity: _appBarOpacity,
          duration: const Duration(milliseconds: 200),
          child: Text(
            widget.ad.title,
            style: const TextStyle(
              color: Colors.black,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.share, color: Colors.black),
            onPressed: () {},
          ),
          _FavoriteButton(
            ad: widget.ad,
            onFavoriteChanged: () {
              // Notifier le parent pour mettre à jour le badge
              // On utilise un callback global pour informer HomeScreen
              if (context.mounted) {
                // On pourrait implémenter un système de notification global ici
              }
            },
          ),
        ],
      ),
      body: NotificationListener<ScrollNotification>(
        onNotification: (scroll) {
          if (scroll.metrics.axis == Axis.vertical) {
            final offset = scroll.metrics.pixels;
            // Le titre dans le body est à environ 340px du haut (320px image + 20px padding)
            // On calcule quand il sort de la vue (quand offset > 340)
            final newOpacity = ((offset - 340) / 50).clamp(0.0, 1.0);
            if (newOpacity != _appBarOpacity) {
              setState(() => _appBarOpacity = newOpacity);
            }
          }
          return false;
        },
        child: SingleChildScrollView(
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
              // Image du produit qui scrolle normalement
              Stack(
                children: [
                  // Slider d'images
                  SizedBox(
                    height: 320,
                    child: PageView.builder(
                      controller: _imagePageController,
                      itemCount: widget.ad.imageUrls.isNotEmpty ? widget.ad.imageUrls.length : 1,
                      onPageChanged: (index) {
                        setState(() {
                          _currentImageIndex = index;
                        });
                      },
                      itemBuilder: (context, index) {
                        final imageUrl = widget.ad.imageUrls.isNotEmpty 
                            ? widget.ad.imageUrls[index] 
                            : widget.ad.imageUrl;
                        return Image.network(
                          imageUrl,
                          width: double.infinity,
                          height: 320,
                          fit: BoxFit.cover,
                          loadingBuilder: (context, child, loadingProgress) {
                            if (loadingProgress == null) return child;
                            return Container(
                              height: 320,
                              color: Colors.grey.shade200,
                              child: Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    SizedBox(
                                      width: 32,
                                      height: 32,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        value: loadingProgress.expectedTotalBytes != null
                                            ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                                            : null,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'Chargement...',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                          errorBuilder: (context, error, stackTrace) => Container(
                            height: 320,
                            color: Colors.grey.shade200,
                            child: const Icon(Icons.image, size: 60, color: Colors.grey),
                          ),
                        );
                      },
                    ),
                  ),
                  // Indicateur d'images
                  if (widget.ad.imageUrls.length > 1)
                    Positioned(
                      bottom: 16, right: 16,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
                        decoration: BoxDecoration(
                          color: Color.fromRGBO(0, 0, 0, 0.5),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.photo_outlined,
                              color: Colors.white,
                              size: 16,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '${_currentImageIndex + 1}/${widget.ad.imageUrls.length}',
                              style: const TextStyle(color: Colors.white),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
              // Informations du produit
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.ad.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
                    const SizedBox(height: 4),
                    Text(
                      '${widget.ad.location} · ${widget.ad.publicationDate.year}',
                      style: const TextStyle(fontSize: 15, color: Colors.black54),
                    ),
                    const SizedBox(height: 8),
                    Text('${widget.ad.price.toStringAsFixed(0)} €', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black, fontSize: 22)),
                    const SizedBox(height: 8),
                    Builder(
                      builder: (context) {
                        final dateStr = formatDate(widget.ad.publicationDate);
                        return Text(
                          dateStr.startsWith("Aujourd'hui") || dateStr.startsWith("Hier") ? dateStr : 'Le $dateStr',
                          style: const TextStyle(fontSize: 13, color: Colors.black45),
                        );
                      },
                    ),
                    const SizedBox(height: 20),
                    // Critères et description
                    Builder(
                      builder: (context) {
                        Map<String, dynamic> criterias = {};
                        if (widget.ad.criterias != null && widget.ad.criterias.toString().isNotEmpty) {
                          try {
                            criterias = widget.ad.criterias is String
                                ? Map<String, dynamic>.from(jsonDecode(widget.ad.criterias))
                                : Map<String, dynamic>.from(widget.ad.criterias);
                          } catch (_) {}
                        }
                        if (criterias.isEmpty) return const SizedBox.shrink();
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Caractéristiques', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                            const SizedBox(height: 8),
                            ...criterias.entries.map((e) => Padding(
                                  padding: const EdgeInsets.only(bottom: 4),
                                  child: Row(
                                    children: [
                                      Text('${e.key} : ', style: const TextStyle(fontWeight: FontWeight.w600)),
                                      Flexible(child: Text('${e.value}', style: const TextStyle(fontWeight: FontWeight.normal))),
                                    ],
                                  ),
                                )),
                            const Divider(height: 32, thickness: 1, color: Color(0xFFE0E0E0)),
                          ],
                        );
                      },
                    ),
                    const Text('Description', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(widget.ad.description, style: const TextStyle(fontSize: 15)),
                    ),
                    const SizedBox(height: 20),
                    
                    // Carte de localisation
                    if (widget.ad.latitude != null && widget.ad.longitude != null)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Localisation', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          const SizedBox(height: 24),
                          Row(
                            children: [
                              const Icon(Icons.location_on, color: Color(0xFFF15A22), size: 18),
                              const SizedBox(width: 6),
                              Text(
                                '${widget.ad.location} (${widget.ad.postalCode})',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          GestureDetector(
                            onTap: () {
                              showDialog(
                                context: context,
                                builder: (context) => _InteractiveMapDialog(
                                  latitude: widget.ad.latitude!,
                                  longitude: widget.ad.longitude!,
                                  location: widget.ad.location,
                                  postalCode: widget.ad.postalCode,
                                ),
                              );
                            },
                            child: Container(
                              height: 200,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.grey.shade300),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Stack(
                                  children: [
                                    _LocationMap(
                                      latitude: widget.ad.latitude!,
                                      longitude: widget.ad.longitude!,
                                      location: widget.ad.location,
                                      postalCode: widget.ad.postalCode,
                                    ),
                                    // Overlay pour indiquer que c'est cliquable
                                    Positioned(
                                      top: 8,
                                      right: 8,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: Colors.black.withValues(alpha: 0.7),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: const Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(Icons.fullscreen, color: Colors.white, size: 16),
                                            SizedBox(width: 4),
                                            Text(
                                              'Agrandir',
                                              style: TextStyle(color: Colors.white, fontSize: 12),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
                        ],
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _imagePageController.dispose();
    super.dispose();
  }
}

String formatDate(DateTime date) {
  final now = DateTime.now();
  if (date.year == now.year && date.month == now.month && date.day == now.day) {
    return "Aujourd'hui ${DateFormat('HH:mm').format(date)}";
  } else if (date.year == now.year && date.month == now.month && date.day == now.day - 1) {
    return "Hier à ${DateFormat('HH:mm').format(date)}";
  } else {
    return '${DateFormat('d MMMM yyyy', 'fr_FR').format(date)} à ${DateFormat('HH:mm').format(date)}';
  }
}

// Modifie la classe CategoryScreen pour afficher les sous-catégories
class CategoryScreen extends StatefulWidget {
  final String categoryId;
  final String categoryName;
  final Map<String, Map<String, dynamic>> categoryLabels;
  const CategoryScreen({
    super.key,
    required this.categoryId,
    required this.categoryName,
    required this.categoryLabels,
  });

  @override
  State<CategoryScreen> createState() => _CategoryScreenState();
}

class _CategoryScreenState extends State<CategoryScreen> {
  List<Map<String, dynamic>> _subCategories = [];

  @override
  void initState() {
    super.initState();
    _loadSubCategories();
  }

  void _loadSubCategories() {
    final subCategories = widget.categoryLabels.values
        .where((cat) => cat['parentId'] == widget.categoryId)
        .toList()
      ..sort((a, b) => (a['order'] ?? 0).compareTo(b['order'] ?? 0));
    setState(() {
      _subCategories = subCategories;
    });
  }

  void _showNotificationDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Notifications'),
          content: const Text(
            'Voulez-vous recevoir des notifications pour les nouvelles annonces dans cette catégorie ?',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Annuler'),
            ),
            ElevatedButton(
              onPressed: () async {
                try {
                  await NotificationService().subscribeToCategory(widget.categoryId);
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Vous êtes maintenant abonné aux notifications de cette catégorie !'),
                      backgroundColor: Colors.green,
                    ),
                  );
                } catch (e) {
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Erreur lors de l\'abonnement: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
              child: const Text('S\'abonner'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.categoryName, style: const TextStyle(fontWeight: FontWeight.bold)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () => _showNotificationDialog(context),
          ),
        ],
      ),
      body: _subCategories.isEmpty
          ? const Center(child: Text('Aucune sous-catégorie disponible'))
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: _subCategories.length,
              separatorBuilder: (context, index) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final subCategory = _subCategories[index];
                return GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ProductListScreen(
                          subCategoryId: subCategory['\$id'],
                          subCategoryName: subCategory['name'],
                          categoryLabels: widget.categoryLabels,
                        ),
                      ),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Color(0xFFE0E0E0), width: 1),
                      boxShadow: [
                        BoxShadow(
                          color: Color.fromRGBO(0, 0, 0, 0.04),
                          blurRadius: 8,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            subCategory['name'],
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.black87,
                            ),
                          ),
                        ),
                        Icon(
                          Icons.arrow_forward_ios,
                          size: 16,
                          color: Colors.grey.shade400,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}

// Ajout du widget autonome pour le carrousel
class _AdCarousel extends StatefulWidget {
  const _AdCarousel();

  @override
  State<_AdCarousel> createState() => _AdCarouselState();
}

class _AdCarouselState extends State<_AdCarousel> {
  int _currentAdIndex = 0;
  final PageController _adPageController = PageController(viewportFraction: 1.0);
  Timer? _adAutoScrollTimer;
  Timer? _progressTimer;
  double _progress = 0.0; // Progression du temps (0.0 à 1.0)
  static const int _autoScrollDuration = 5; // Durée en secondes
  
  List<Map<String, dynamic>> _adsData = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAdsFromAppwrite();
  }

  Future<void> _loadAdsFromAppwrite() async {
    try {
      print('🔄 Chargement des publicités depuis Appwrite...');
      final databases = AppwriteService().databases;
      final result = await databases.listDocuments(
        databaseId: '687ccdcf0000676911f1',
        collectionId: '68848e400010f8aef32c', // Collection pour les publicités/bannières
        queries: [
          appw.Query.equal('isActive', true),
          appw.Query.orderDesc('createdAt'),
          appw.Query.limit(10), // Limiter à 10 publicités
        ],
      );
      
      print('📊 Publicités trouvées: ${result.documents.length}');
      
      setState(() {
        _adsData = result.documents.map((doc) => {
          'id': doc.$id,
          'image': doc.data['imageUrl'] ?? '',
          'url': doc.data['linkUrl'] ?? '',
          'title': doc.data['title'] ?? '',
        }).toList();
        _isLoading = false;
      });
      
      print('✅ Publicités chargées avec succès: ${_adsData.length}');
      
      // Précharger les images
      _preloadImages();
      
      // Démarrer l'auto-scroll seulement s'il y a des publicités
      if (_adsData.isNotEmpty) {
        _startAutoScroll();
        _startProgressTimer();
      } else {
        print('⚠️ Aucune publicité trouvée, utilisation du fallback local');
        _useLocalFallback();
      }
    } catch (e) {
      print('❌ Erreur lors du chargement des publicités: $e');
      _useLocalFallback();
    }
  }

  void _preloadImages() {
    for (var ad in _adsData) {
      if (ad['image'].startsWith('http')) {
        precacheImage(NetworkImage(ad['image']), context);
      } else {
        precacheImage(AssetImage(ad['image']), context);
      }
    }
  }

  void _useLocalFallback() {
    setState(() {
      _isLoading = false;
      // Fallback vers les données locales si erreur
      _adsData = [
        {'image': 'assets/ads/pub_bazaria_1.png', 'url': 'https://bazaria.fr'},
        {'image': 'assets/ads/pub_bazaria_2.png', 'url': 'https://bazaria.fr'},
        {'image': 'assets/ads/pub_bazaria_3.png', 'url': 'https://bazaria.fr'},
      ];
    });
    _startAutoScroll();
    _startProgressTimer();
  }

  void _startAutoScroll() {
    _adAutoScrollTimer = Timer.periodic(const Duration(seconds: _autoScrollDuration), (timer) {
      if (_adPageController.hasClients) {
        int nextPage = (_currentAdIndex + 1) % _adsData.length;
        _adPageController.animateToPage(
          nextPage,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  void _startProgressTimer() {
    _progressTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      if (mounted) {
        setState(() {
          _progress += 0.1 / _autoScrollDuration; // Incrémenter progressivement
          if (_progress >= 1.0) {
            _progress = 0.0; // Reset quand on atteint 100%
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _adAutoScrollTimer?.cancel();
    _progressTimer?.cancel();
    _adPageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const SizedBox(
        height: 120,
        child: Center(child: CircularProgressIndicator()),
      );
    }
    
    if (_adsData.isEmpty) {
      return const SizedBox.shrink(); // Ne rien afficher s'il n'y a pas de publicités
    }
    
    return Column(
      children: [
        SizedBox(
          height: 120,
          child: PageView.builder(
            controller: _adPageController,
            itemCount: _adsData.length,
            onPageChanged: (index) {
              setState(() {
                _currentAdIndex = index;
                _progress = 0.0; // Reset le progress quand on change de page
              });
            },
            itemBuilder: (context, index) {
              final ad = _adsData[index];
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4.0),
                child: GestureDetector(
                  onTap: () async {
                    final url = ad['url'];
                    if (url != null && url.isNotEmpty) {
                      try {
                        await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
                      } catch (e) {
                        print('Erreur lors de l\'ouverture du lien: $e');
                      }
                    }
                  },
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: AspectRatio(
                      aspectRatio: 3 / 2, // Ratio 3:2 plus carré
                      child: ad['image'].startsWith('http')
                        ? Container(
                            decoration: BoxDecoration(
                              color: Colors.grey.shade200,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Image.network(
                              ad['image'],
                              fit: BoxFit.cover,
                              width: double.infinity,
                              height: double.infinity,
                              loadingBuilder: (context, child, loadingProgress) {
                                if (loadingProgress == null) return child;
                                return Center(
                                  child: CircularProgressIndicator(
                                    value: loadingProgress.expectedTotalBytes != null
                                      ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                                      : null,
                                    strokeWidth: 2,
                                  ),
                                );
                              },
                              errorBuilder: (context, error, stackTrace) {
                                return const Center(
                                  child: Icon(Icons.image, color: Colors.grey),
                                );
                              },
                              cacheWidth: 400,
                              cacheHeight: 225, // 400 * 9/16
                            ),
                          )
                        : Container(
                            decoration: BoxDecoration(
                              color: Colors.grey.shade200,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Image.asset(
                              ad['image'],
                              fit: BoxFit.cover,
                              width: double.infinity,
                              height: double.infinity,
                            ),
                          ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(
            _adsData.length,
            (index) => Container(
              margin: const EdgeInsets.symmetric(horizontal: 4),
              width: _currentAdIndex == index ? 16 : 8,
              height: 8,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(4),
              ),
              child: _currentAdIndex == index
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: Stack(
                      children: [
                        // Fond gris (déjà défini dans decoration)
                        // Barre de progression orange qui se remplit
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 100),
                          width: 16 * _progress,
                          height: double.infinity,
                          decoration: BoxDecoration(
                            color: AppTheme.primaryColor,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ],
                    ),
                  )
                : null,
            ),
          ),
        ),
      ],
    );
  }
}



// Page de notifications
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final List<Map<String, dynamic>> _notifications = [
    {
      'id': '1',
      'title': 'Nouvelle annonce dans Vélos',
      'message': 'Un vélo de course a été ajouté dans votre catégorie préférée',
      'time': DateTime.now().subtract(const Duration(minutes: 5)),
      'isRead': false,
      'type': 'category',
      'icon': Icons.directions_bike,
    },
    {
      'id': '2',
      'title': 'Prix réduit sur votre favori',
      'message': 'Le prix de "iPhone 13 Pro" a été réduit de 50€',
      'time': DateTime.now().subtract(const Duration(hours: 2)),
      'isRead': false,
      'type': 'price_drop',
      'icon': Icons.local_offer,
    },
    {
      'id': '3',
      'title': 'Message reçu',
      'message': 'Vous avez reçu un message concernant votre annonce "Canapé cuir"',
      'time': DateTime.now().subtract(const Duration(hours: 4)),
      'isRead': true,
      'type': 'message',
      'icon': Icons.message,
    },
    {
      'id': '4',
      'title': 'Annonce vendue !',
      'message': 'Félicitations ! Votre annonce "MacBook Air" a été vendue',
      'time': DateTime.now().subtract(const Duration(days: 1)),
      'isRead': true,
      'type': 'sold',
      'icon': Icons.check_circle,
    },
    {
      'id': '5',
      'title': 'Nouvelle annonce dans Électronique',
      'message': 'Un ordinateur portable a été ajouté dans votre catégorie préférée',
      'time': DateTime.now().subtract(const Duration(days: 1, hours: 2)),
      'isRead': true,
      'type': 'category',
      'icon': Icons.laptop,
    },
    {
      'id': '6',
      'title': 'Promotion spéciale',
      'message': 'Profitez de -20% sur les frais de mise en avant cette semaine',
      'time': DateTime.now().subtract(const Duration(days: 2)),
      'isRead': true,
      'type': 'promotion',
      'icon': Icons.star,
    },
    {
      'id': '7',
      'title': 'Nouvelle annonce dans Meubles',
      'message': 'Un canapé moderne a été ajouté dans votre catégorie préférée',
      'time': DateTime.now().subtract(const Duration(days: 3)),
      'isRead': true,
      'type': 'category',
      'icon': Icons.weekend,
    },
  ];

  void _markAsRead(String notificationId) {
    setState(() {
      final notification = _notifications.firstWhere((n) => n['id'] == notificationId);
      notification['isRead'] = true;
    });
  }

  void _markAllAsRead() {
    setState(() {
      for (var notification in _notifications) {
        notification['isRead'] = true;
      }
    });
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final difference = now.difference(time);

    if (difference.inMinutes < 60) {
      return 'Il y a ${difference.inMinutes} min';
    } else if (difference.inHours < 24) {
      return 'Il y a ${difference.inHours}h';
    } else {
      return 'Il y a ${difference.inDays}j';
    }
  }

  Color _getNotificationColor(String type) {
    switch (type) {
      case 'category':
        return Colors.blue;
      case 'price_drop':
        return Colors.orange;
      case 'message':
        return Colors.green;
      case 'sold':
        return Colors.purple;
      case 'promotion':
        return Colors.amber;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final unreadCount = _notifications.where((n) => !n['isRead']).length;

    return Scaffold(
      appBar: AppBar(
        title: Text('Notifications${unreadCount > 0 ? ' ($unreadCount)' : ''}'),
        actions: [
          if (unreadCount > 0)
            TextButton(
              onPressed: _markAllAsRead,
              child: const Text(
                'Tout marquer comme lu',
                style: TextStyle(color: Colors.white),
              ),
            ),
        ],
      ),
      body: _notifications.isEmpty
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.notifications_none, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text(
                    'Aucune notification',
                    style: TextStyle(fontSize: 18, color: Colors.grey),
                  ),
                ],
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: _notifications.length,
              separatorBuilder: (context, index) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final notification = _notifications[index];
                final isRead = notification['isRead'] as bool;
                final type = notification['type'] as String;

                return ListTile(
                  leading: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: _getNotificationColor(type).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      notification['icon'] as IconData,
                      color: _getNotificationColor(type),
                      size: 20,
                    ),
                  ),
                  title: Text(
                    notification['title'] as String,
                    style: TextStyle(
                      fontWeight: isRead ? FontWeight.normal : FontWeight.bold,
                      color: isRead ? Colors.grey.shade600 : Colors.black,
                    ),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 4),
                      Text(
                        notification['message'] as String,
                        style: TextStyle(
                          color: isRead ? Colors.grey.shade500 : Colors.grey.shade700,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _formatTime(notification['time'] as DateTime),
                        style: TextStyle(
                          color: Colors.grey.shade400,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  trailing: !isRead
                      ? Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: Color(0xFFF15A22),
                            shape: BoxShape.circle,
                          ),
                        )
                      : null,
                  onTap: () {
                    if (!isRead) {
                      _markAsRead(notification['id'] as String);
                    }
                    // Ici vous pourriez naviguer vers la page correspondante
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Notification: ${notification['title']}'),
                        duration: const Duration(seconds: 1),
                      ),
                    );
                  },
                );
              },
            ),
    );
  }
}

// Ajout du widget shimmer loader pour les annonces
class AdShimmerLoader extends StatelessWidget {
  const AdShimmerLoader({super.key});

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: Colors.grey.shade300,
      highlightColor: Colors.grey.shade100,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.grey.shade200,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Color.fromRGBO(0, 0, 0, 0.04),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        padding: const EdgeInsets.all(10),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final cardWidth = constraints.maxWidth;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Image
                Container(
                  height: 110,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                const SizedBox(height: 12),
                // Nom produit (ligne 1)
                Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                    height: 15,
                    width: cardWidth * 0.8,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                // Nom produit (ligne 2)
                Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                    height: 15,
                    width: cardWidth * 0.5,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                // Prix
                Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                    height: 14,
                    width: cardWidth * 0.4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                // Catégorie
                Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                    height: 12,
                    width: cardWidth * 0.5,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                // Lieu
                Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                    height: 12,
                    width: cardWidth * 0.7,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                // Date de publication
                Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                    height: 12,
                    width: cardWidth * 0.3,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

// Widget pour afficher la carte de localisation
class _LocationMap extends StatefulWidget {
  final double latitude;
  final double longitude;
  final String location;
  final String postalCode;

  const _LocationMap({
    required this.latitude,
    required this.longitude,
    required this.location,
    required this.postalCode,
  });

  @override
  State<_LocationMap> createState() => _LocationMapState();
}

class _LocationMapState extends State<_LocationMap> {
  GoogleMapController? _mapController;
  Set<Circle> _circles = {};

  @override
  void initState() {
    super.initState();
    _createLocationData();
  }

  void _createLocationData() {
    // Cercle pour représenter la zone (rayon de 2km)
    _circles = {
      Circle(
        circleId: CircleId('${widget.location}_zone'),
        center: LatLng(widget.latitude, widget.longitude),
        radius: 2000, // 2km en mètres
        fillColor: const Color(0xFFF15A22).withValues(alpha: 0.2),
        strokeColor: const Color(0xFFF15A22),
        strokeWidth: 2,
      ),
    };
  }

  @override
  Widget build(BuildContext context) {
    return GoogleMap(
      initialCameraPosition: CameraPosition(
        target: LatLng(widget.latitude, widget.longitude),
        zoom: 12, // Zoom un peu plus éloigné pour voir le rayon
      ),
      circles: _circles,
      onMapCreated: (controller) {
        _mapController = controller;
      },
      myLocationEnabled: false,
      myLocationButtonEnabled: false,
      zoomControlsEnabled: false,
      mapToolbarEnabled: false,
      compassEnabled: false,
    );
  }
}

// Widget pour la popup de carte interactive
class _InteractiveMapDialog extends StatefulWidget {
  final double latitude;
  final double longitude;
  final String location;
  final String postalCode;

  const _InteractiveMapDialog({
    required this.latitude,
    required this.longitude,
    required this.location,
    required this.postalCode,
  });

  @override
  State<_InteractiveMapDialog> createState() => _InteractiveMapDialogState();
}

class _InteractiveMapDialogState extends State<_InteractiveMapDialog> {
  GoogleMapController? _mapController;
  Set<Circle> _circles = {};

  @override
  void initState() {
    super.initState();
    _createLocationData();
  }

  void _createLocationData() {
    // Cercle pour représenter la zone (rayon de 2km)
    _circles = {
      Circle(
        circleId: CircleId('${widget.location}_zone'),
        center: LatLng(widget.latitude, widget.longitude),
        radius: 2000, // 2km en mètres
        fillColor: const Color(0xFFF15A22).withValues(alpha: 0.2),
        strokeColor: const Color(0xFFF15A22),
        strokeWidth: 2,
      ),
    };
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        width: MediaQuery.of(context).size.width,
        height: MediaQuery.of(context).size.height,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            // En-tête
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: Color(0xFFF15A22),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(12),
                  topRight: Radius.circular(12),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.location_on, color: Colors.white),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${widget.location} (${widget.postalCode})',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            
            // Carte interactive
            Expanded(
              child: GoogleMap(
                initialCameraPosition: CameraPosition(
                  target: LatLng(widget.latitude, widget.longitude),
                  zoom: 13, // Zoom pour voir le rayon
                ),
                circles: _circles,
                onMapCreated: (controller) {
                  _mapController = controller;
                },
                myLocationEnabled: true,
                myLocationButtonEnabled: true,
                zoomControlsEnabled: true,
                mapToolbarEnabled: true,
                compassEnabled: true,
              ),
            ),
            

          ],
        ),
      ),
    );
  }
}

// Widget pour le bouton favori dans l'AppBar
class _FavoriteButton extends StatefulWidget {
  final Ad ad;
  final VoidCallback? onFavoriteChanged;
  
  const _FavoriteButton({required this.ad, this.onFavoriteChanged});

  @override
  State<_FavoriteButton> createState() => _FavoriteButtonState();
}

class _FavoriteButtonState extends State<_FavoriteButton> {
  bool isFavorite = false;

  @override
  void initState() {
    super.initState();
    _checkFavoriteStatus();
  }

  Future<void> _checkFavoriteStatus() async {
    final favorite = await FavoritesService.isFavorite(widget.ad.id);
    if (mounted) {
      setState(() {
        isFavorite = favorite;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(
        isFavorite ? Icons.favorite : Icons.favorite_border,
        color: isFavorite ? Color(0xFFF15A22) : Colors.black,
      ),
      onPressed: () async {
        final success = await FavoritesService.toggleFavorite(widget.ad.id);
        if (success && mounted) {
          setState(() {
            isFavorite = !isFavorite;
          });
          
          // Notifier le parent du changement
          widget.onFavoriteChanged?.call();
        }
      },
    );
  }
}

// Mapping du nom d'icône (String) vers IconData
IconData getCategoryIcon(String? iconName) {
  switch (iconName) {
    case 'weekend':
      return Icons.weekend;
    case 'chair':
      return Icons.chair;
    case 'kitchen':
      return Icons.kitchen;
    case 'bed':
      return Icons.bed;
    case 'tv':
      return Icons.tv;
    case 'toys':
      return Icons.toys;
    case 'directions_car':
      return Icons.directions_car;
    case 'phone_iphone':
      return Icons.phone_iphone;
    case 'laptop':
      return Icons.laptop;
    case 'home':
      return Icons.home;
    case 'devices':
      return Icons.devices;
    // Ajoute ici toutes les icônes nécessaires
    default:
      return Icons.category;
  }
}

// Ajoute la classe ProductListScreen pour afficher les produits d'une sous-catégorie
class ProductListScreen extends StatefulWidget {
  final String subCategoryId;
  final String subCategoryName;
  final Map<String, Map<String, dynamic>> categoryLabels;
  const ProductListScreen({
    super.key,
    required this.subCategoryId,
    required this.subCategoryName,
    required this.categoryLabels,
  });

  @override
  State<ProductListScreen> createState() => _ProductListScreenState();
}

class _ProductListScreenState extends State<ProductListScreen> {
  List<Ad> _products = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  Future<void> _loadProducts() async {
    try {
      final databases = AppwriteService().databases;
      final result = await databases.listDocuments(
        databaseId: '687ccdcf0000676911f1',
        collectionId: '687ccdde0031f8eda985',
        queries: [
          appw.Query.equal('isActive', true),
          appw.Query.equal('subCategoryId', widget.subCategoryId),
          appw.Query.orderDesc('publicationDate'),
        ],
      );
      setState(() {
        _products = result.documents.map((doc) => Ad.fromAppwrite(doc)).toList();
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.subCategoryName, style: const TextStyle(fontWeight: FontWeight.bold)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _products.isEmpty
              ? const Center(child: Text('Aucun produit dans cette catégorie'))
              : GridView.builder(
                  padding: const EdgeInsets.all(16),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: MediaQuery.of(context).size.width > 600 ? 3 : 2,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: MediaQuery.of(context).size.width > 600 ? 1.0 : 0.7,
                  ),
                  itemCount: _products.length,
                  itemBuilder: (context, index) {
                    final product = _products[index];
                    return AdCard(
                      ad: product,
                      index: index,
                      categoryLabels: widget.categoryLabels,
                      onFavoriteChanged: () {
                        // Optionnel : on pourrait ajouter une notification ici
                      },
                      onTap: () {
                        if (Platform.isIOS) {
                          Navigator.of(context).push(
                            CupertinoPageRoute(
                              builder: (context) => ProductDetailPage(ad: product, categoryLabels: widget.categoryLabels),
                              fullscreenDialog: true,
                            ),
                          );
                        } else {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) => ProductDetailPage(ad: product, categoryLabels: widget.categoryLabels),
                              fullscreenDialog: true,
                            ),
                          );
                        }
                      },
                    );
                  },
                ),
    );
  }
}
