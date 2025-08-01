import 'package:flutter/material.dart';
import 'package:appwrite/appwrite.dart' as appw;
import '../services/appwrite_service.dart';
import '../models/ad.dart';
import '../services/ai_search_service.dart';

import '../services/langchain_service.dart';
import '../services/openai_service.dart';
import '../services/backend_api_service.dart';
import '../services/saved_searches_service.dart';
import '../widgets/ad_card.dart';
import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter/cupertino.dart';
import 'home_screen.dart';
import 'package:logger/logger.dart';

final logger = Logger();

class SearchScreen extends StatefulWidget {
  final String? initialQuery;
  final Map<String, dynamic>? initialFilters;
  
  const SearchScreen({
    super.key,
    this.initialQuery,
    this.initialFilters,
  });

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  
  List<Ad> _searchResults = [];
  List<Ad> _allAds = [];
  bool _isLoading = false;
  bool _hasSearched = false;
  bool _isSearching = false;


  
  // Filtres
  String? _selectedCategory;
  double? _minPrice;
  double? _maxPrice;
  String _sortBy = 'relevance'; // 'relevance', 'price_asc', 'price_desc', 'date'
  
  Timer? _debounceTimer;
  Map<String, Map<String, dynamic>> _categoryLabels = {};
  bool _isInitializing = false;

  @override
  void initState() {
    super.initState();
    _isInitializing = true;
    _controller = AnimationController(
      duration: const Duration(milliseconds: 350),
      vsync: this,
    );
    _animation = CurvedAnimation(parent: _controller, curve: Curves.easeIn);
    _controller.forward();
    
    _loadCategoryLabels();
    _loadAllAds();
    
    // Initialiser avec les paramètres si fournis
    if (widget.initialQuery != null) {
      _searchController.text = widget.initialQuery!;
      _hasSearched = true;
      _isSearching = true; // Indiquer qu'une recherche est en cours
    }
    
    if (widget.initialFilters != null) {
      _applyInitialFilters(widget.initialFilters!);
    }
    
    // Écouter les changements de recherche seulement après l'initialisation
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _searchController.addListener(_onSearchChanged);
      _isInitializing = false;
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Rafraîchir les données seulement si pas de recherche initiale en cours
    if (widget.initialQuery == null) {
      _refreshData();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _searchController.dispose();
    _searchFocusNode.dispose();
    _debounceTimer?.cancel();
    super.dispose();
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
      logger.e('Erreur lors du chargement des catégories: $e');
    }
  }

  Future<void> _loadAllAds() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      final databases = AppwriteService().databases;
      final result = await databases.listDocuments(
        databaseId: '687ccdcf0000676911f1',
        collectionId: '687ccdde0031f8eda985',
        queries: [
          appw.Query.equal('isActive', true),
          appw.Query.orderDesc('publicationDate'),
          appw.Query.limit(1000), // Limiter à 1000 annonces pour les performances
        ],
      );
      
      setState(() {
        _allAds = result.documents.map((doc) => Ad.fromAppwrite(doc)).toList();
        _isLoading = false;
      });
      
      logger.d('📦 Annonces chargées: ${_allAds.length}');
      // Afficher quelques exemples d'annonces pour déboguer
      if (_allAds.isNotEmpty) {
        logger.d('📋 Exemples d\'annonces:');
        for (int i = 0; i < _allAds.length && i < 3; i++) {
          final ad = _allAds[i];
          logger.d('  - ${ad.title} (${ad.price}€) - ${ad.description.substring(0, ad.description.length > 50 ? 50 : ad.description.length)}...');
        }
      }
      
      // Exécuter la recherche initiale si des paramètres sont fournis
      if (widget.initialQuery != null && mounted) {
        // La recherche sera lancée après que les données soient chargées
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            _performSearch();
          }
        });
      }
    } catch (e) {
      logger.e('❌ Erreur lors du chargement des annonces: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _applyInitialFilters(Map<String, dynamic> filters) {
    logger.d('🔧 Application des filtres initiaux: $filters');
    setState(() {
      if (filters.containsKey('category') && filters['category'] != null) {
        _selectedCategory = filters['category'] as String;
        logger.d('🏷️ Catégorie sélectionnée: $_selectedCategory');
      }
      if (filters.containsKey('minPrice') && filters['minPrice'] != null) {
        _minPrice = (filters['minPrice'] as num).toDouble();
        logger.d('💰 Prix minimum: $_minPrice');
      }
      if (filters.containsKey('maxPrice') && filters['maxPrice'] != null) {
        _maxPrice = (filters['maxPrice'] as num).toDouble();
        logger.d('💰 Prix maximum: $_maxPrice');
      }
      if (filters.containsKey('sortBy') && filters['sortBy'] != null) {
        _sortBy = filters['sortBy'] as String;
        logger.d('📊 Tri: $_sortBy');
      }
    });
  }

  Future<void> _refreshData() async {
    // Ne pas rafraîchir si une recherche initiale est en cours
    if (widget.initialQuery != null && _isSearching) {
      return;
    }
    
    // Rafraîchir les annonces si une recherche est en cours
    if (_hasSearched && _searchController.text.isNotEmpty) {
      await _loadAllAds();
      // Relancer la recherche avec les nouvelles données
      _performSearch();
    } else {
      // Si pas de recherche en cours, juste rafraîchir les données
      await _loadAllAds();
    }
  }

  void _onSearchChanged() {
    // Ne pas déclencher de recherche si c'est une initialisation
    if (_isInitializing || (widget.initialQuery != null && _searchController.text == widget.initialQuery && _isSearching)) {
      return;
    }
    
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      // Réinitialiser les filtres quand l'utilisateur tape une nouvelle recherche
      bool hadFilters = _hasActiveFilters();
      if (hadFilters) {
        setState(() {
          _selectedCategory = null;
          _minPrice = null;
          _maxPrice = null;
          _sortBy = 'relevance';
        });
      }
      _performSearch();
    });
  }

  Future<void> _performSearch() async {
    if (_searchController.text.trim().isEmpty) {
      setState(() {
        _searchResults = [];
        _hasSearched = false;
      });
      return;
    }

    setState(() {
      _isSearching = true;
      _hasSearched = true;
    });

    try {
      final query = _searchController.text.trim();
      List<Ad> results = [];

            logger.d('🔍 Début recherche: "$query"');
      
      // Recherche traditionnelle avec amélioration IA (mode par défaut)
      final enhancedQuery = await OpenAIService.enhanceQuery(query);
      results = await AISearchService.advancedSearch(
        enhancedQuery,
        _allAds,
        _categoryLabels,
      );
      logger.d('🔍 Recherche traditionnelle améliorée: ${results.length} résultats');

      // Appliquer les filtres
      results = _applyFilters(results);

      setState(() {
        _searchResults = results;
        _isSearching = false;
      });

      logger.d('✅ Recherche terminée: ${results.length} résultats finaux');
    } catch (e) {
      logger.e('❌ Erreur lors de la recherche: $e');
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
    }
  }

  List<Ad> _applyFilters(List<Ad> results) {
    List<Ad> filteredResults = results;

    // Filtre par catégorie
    if (_selectedCategory != null) {
      logger.d('��️ Filtrage par catégorie - ID sélectionné: $_selectedCategory');
      logger.d('🏷️ Nombre de catégories disponibles: ${_categoryLabels.length}');
      logger.d('🏷️ Catégories disponibles: ${_categoryLabels.keys.toList()}');
      
      filteredResults = filteredResults.where((ad) {
        final matches = ad.subCategoryId == _selectedCategory;
        logger.d('  - "${ad.title}": catégorie ${ad.subCategoryId} (match: $matches)');
        return matches;
      }).toList();
      logger.d('🏷️ Après filtrage par catégorie: ${filteredResults.length}');
    }
    
    // Filtre par prix
    if (_minPrice != null || _maxPrice != null) {
      logger.d('💰 Filtrage par prix - Min: $_minPrice, Max: $_maxPrice');
      filteredResults = filteredResults.where((ad) {
        bool matchesMin = _minPrice == null || ad.price >= _minPrice!;
        bool matchesMax = _maxPrice == null || ad.price <= _maxPrice!;
        logger.d('  - "${ad.title}": ${ad.price}€ (Min: $matchesMin, Max: $matchesMax)');
        return matchesMin && matchesMax;
      }).toList();
      logger.d('�� Après filtrage par prix: ${filteredResults.length}');
    }

    // Trier les résultats
    _sortResults(filteredResults);
    return filteredResults;
  }

  void _sortResults(List<Ad> results) {
    switch (_sortBy) {
      case 'price_asc':
        results.sort((a, b) => a.price.compareTo(b.price));
        break;
      case 'price_desc':
        results.sort((a, b) => b.price.compareTo(a.price));
        break;
      case 'date':
        results.sort((a, b) => b.publicationDate.compareTo(a.publicationDate));
        break;
      case 'relevance':
      default:
        // Garder l'ordre original (pertinence basée sur la recherche)
        break;
    }
  }

  bool _hasActiveFilters() {
    return _selectedCategory != null || 
           _minPrice != null || 
           _maxPrice != null || 
           _sortBy != 'relevance';
  }

  void _resetFilters() {
    setState(() {
      _selectedCategory = null;
      _minPrice = null;
      _maxPrice = null;
      _sortBy = 'relevance';
    });
    _performSearch();
  }

  String _getActiveFiltersText() {
    List<String> activeFilters = [];
    
    if (_selectedCategory != null) {
      final categoryName = _categoryLabels[_selectedCategory]?['name'] ?? _selectedCategory;
      activeFilters.add('Catégorie: $categoryName');
    }
    
    if (_minPrice != null || _maxPrice != null) {
      if (_minPrice != null && _maxPrice != null) {
        activeFilters.add('Prix: ${_minPrice!.toInt()}€ - ${_maxPrice!.toInt()}€');
      } else if (_minPrice != null) {
        activeFilters.add('Prix: ≥ ${_minPrice!.toInt()}€');
      } else {
        activeFilters.add('Prix: ≤ ${_maxPrice!.toInt()}€');
      }
    }
    
    if (_sortBy != 'relevance') {
      String sortText = '';
      switch (_sortBy) {
        case 'price_asc':
          sortText = 'Prix croissant';
          break;
        case 'price_desc':
          sortText = 'Prix décroissant';
          break;
        case 'date':
          sortText = 'Plus récent';
          break;
      }
      activeFilters.add('Tri: $sortText');
    }
    
    return activeFilters.join(', ');
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

  /// Afficher le dialogue de sauvegarde de recherche
  void _showSaveSearchDialog() {
    final TextEditingController nameController = TextEditingController(
      text: _searchController.text.trim(),
    );
    
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Sauvegarder la recherche'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Donnez un nom à cette recherche :'),
              const SizedBox(height: 16),
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  hintText: 'Ex: iPhone pas cher',
                  border: OutlineInputBorder(),
                ),
                autofocus: true,
              ),
              const SizedBox(height: 16),
              // Afficher les filtres actifs
              if (_hasActiveFilters())
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Filtres actifs :',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Text(_getActiveFiltersText()),
                    ],
                  ),
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Annuler'),
            ),
            ElevatedButton(
              onPressed: () async {
                final name = nameController.text.trim();
                if (name.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Veuillez entrer un nom pour la recherche')),
                  );
                  return;
                }
                
                Navigator.of(context).pop();
                await _saveSearch(name);
              },
              child: const Text('Sauvegarder'),
            ),
          ],
        );
      },
    );
  }

  /// Sauvegarder la recherche actuelle
  Future<void> _saveSearch(String name) async {
    try {
      // Préparer les filtres actuels
      final Map<String, dynamic> currentFilters = {};
      
      if (_selectedCategory != null) {
        currentFilters['category'] = _selectedCategory;
      }
      if (_minPrice != null) {
        currentFilters['minPrice'] = _minPrice;
      }
      if (_maxPrice != null) {
        currentFilters['maxPrice'] = _maxPrice;
      }
      if (_sortBy != 'relevance') {
        currentFilters['sortBy'] = _sortBy;
      }
      
      final success = await SavedSearchesService.saveSearch(
        name: name,
        query: _searchController.text.trim(),
        filters: currentFilters.isNotEmpty ? currentFilters : null,
      );
      
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Recherche "$name" sauvegardée'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Erreur lors de la sauvegarde'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      logger.e('Erreur lors de la sauvegarde: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Erreur lors de la sauvegarde'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showFilters() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => _buildFiltersSheet(),
    );
  }

  Widget _buildFiltersSheet() {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Filtres',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              TextButton(
                onPressed: () {
                  setState(() {
                    _selectedCategory = null;
                    _minPrice = null;
                    _maxPrice = null;
                    _sortBy = 'relevance';
                  });
                  Navigator.pop(context);
                  _performSearch();
                },
                child: const Text('Réinitialiser'),
              ),
            ],
          ),
          const SizedBox(height: 20),
          
          // Catégorie
          const Text('Catégorie', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            value: _selectedCategory,
            decoration: InputDecoration(
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide.none,
              ),
              filled: true,
              fillColor: Colors.grey.shade50,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
            hint: const Text('Toutes les catégories'),
            items: [
              const DropdownMenuItem<String>(
                value: null,
                child: Text('Toutes les catégories'),
              ),
              ..._categoryLabels.entries.map((entry) => DropdownMenuItem<String>(
                value: entry.key,
                child: Text(entry.value['name'] ?? entry.key),
              )),
            ],
            onChanged: (value) {
              setState(() {
                _selectedCategory = value;
              });
            },
          ),
          const SizedBox(height: 20),
          
          // Prix
          const Text('Prix', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  decoration: InputDecoration(
                    labelText: 'Prix min',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    fillColor: Colors.grey.shade50,
                    prefixText: '€',
                  ),
                  keyboardType: TextInputType.number,
                  onChanged: (value) {
                    _minPrice = double.tryParse(value);
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  decoration: InputDecoration(
                    labelText: 'Prix max',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    fillColor: Colors.grey.shade50,
                    prefixText: '€',
                  ),
                  keyboardType: TextInputType.number,
                  onChanged: (value) {
                    _maxPrice = double.tryParse(value);
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          
          // Tri
          const Text('Trier par', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            value: _sortBy,
            decoration: InputDecoration(
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide.none,
              ),
              filled: true,
              fillColor: Colors.grey.shade50,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
            items: const [
              DropdownMenuItem(value: 'relevance', child: Text('Pertinence')),
              DropdownMenuItem(value: 'price_asc', child: Text('Prix croissant')),
              DropdownMenuItem(value: 'price_desc', child: Text('Prix décroissant')),
              DropdownMenuItem(value: 'date', child: Text('Plus récent')),
            ],
            onChanged: (value) {
              setState(() {
                _sortBy = value!;
              });
            },
          ),
          const SizedBox(height: 20),
          
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _performSearch();
              },
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('Appliquer les filtres'),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Recherche'),
        actions: [
          // Bouton de sauvegarde (visible seulement si une recherche a été effectuée)
          if (_hasSearched && _searchController.text.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.bookmark_border),
              onPressed: _showSaveSearchDialog,
            ),

          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () async {
              await _loadAllAds();
              if (_hasSearched && _searchController.text.isNotEmpty) {
                _performSearch();
              }
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Données rafraîchies'),
                  duration: Duration(seconds: 1),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.tune),
            onPressed: _showFilters,
          ),
        ],
      ),
      body: FadeTransition(
        opacity: _animation,
        child: Column(
          children: [
            // Barre de recherche
            Container(
              margin: const EdgeInsets.all(16.0),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                children: [

                  // Champ de recherche
                  TextField(
                    controller: _searchController,
                    focusNode: _searchFocusNode,
                    decoration: InputDecoration(
                      hintText: 'Rechercher des annonces...',
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
                      filled: true,
                      fillColor: Colors.white,
                      prefixIcon: const Icon(Icons.search, color: Colors.grey),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, color: Colors.grey),
                              onPressed: () {
                                _searchController.clear();
                                setState(() {
                                  _searchResults = [];
                                  _hasSearched = false;
                                });
                              },
                            )
                          : null,
                    ),
                    onSubmitted: (value) {
                      _performSearch();
                    },
                  ),
                ],
              ),
            ),
            
            // Résultats ou contenu
            Expanded(
              child: _buildContent(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    // Si on charge les données initiales
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    
    // Si on n'a pas encore cherché
    if (!_hasSearched) {
      return _buildSearchSuggestions();
    }
    
    // Si une recherche est en cours (même après chargement initial)
    if (_isSearching) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Recherche en cours...'),
          ],
        ),
      );
    }
    
    // Si on a cherché mais pas de résultats
    if (_searchResults.isEmpty) {
      return _buildNoResults();
    }
    
    // Si on a des résultats
    return _buildSearchResults();
  }



  Widget _buildSearchSuggestions() {
    // Suggestions par défaut (synchrone pour éviter le clignement)
    final suggestions = [
      'iPhone', 'Samsung', 'MacBook', 'PlayStation', 'Nike', 'Adidas',
      'Voiture', 'Appartement', 'Meuble', 'Livre'
    ];
    
    return _buildSuggestionsWidget(suggestions);
  }



  Widget _buildSuggestionsWidget(List<String> suggestions) {

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Suggestions de recherche',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: suggestions.map((suggestion) => ActionChip(
              label: Text(suggestion, style: const TextStyle(fontSize: 12)),
              onPressed: () {
                setState(() {
                  _searchController.text = suggestion;
                  _hasSearched = true;
                });
                _performSearch();
              },
            )).toList(),
          ),
          const SizedBox(height: 24),
          const Text(
            'Catégories populaires',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          ..._categoryLabels.entries.take(6).map((entry) => Card(
            elevation: 0,
            margin: const EdgeInsets.symmetric(vertical: 4),
            child: ListTile(
              title: Text(
                entry.value['name'] ?? entry.key,
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
              onTap: () {
                setState(() {
                  _selectedCategory = entry.key;
                  _searchController.text = entry.value['name'] ?? entry.key;
                  _hasSearched = true;
                });
                _performSearch();
              },
            ),
          )),
        ],
      ),
    );
  }

  Widget _buildNoResults() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.search_off,
            size: 64,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            'Aucun résultat trouvé',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Essayez avec d\'autres mots-clés ou modifiez vos filtres',
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

  Widget _buildSearchResults() {
    return Column(
      children: [
        // En-tête des résultats
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${_searchResults.length} résultat${_searchResults.length > 1 ? 's' : ''}',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  if (_allAds.length >= 1000)
                    Text(
                      '(Recherche limitée aux 1000 annonces les plus récentes)',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade500,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  if (_hasActiveFilters())
                    Text(
                      _getActiveFiltersText(),
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.orange.shade600,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                ],
              ),
              Row(
                children: [
                  if (_hasActiveFilters())
                    TextButton.icon(
                      onPressed: _resetFilters,
                      icon: const Icon(Icons.clear, size: 16),
                      label: const Text('Réinitialiser'),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.red,
                      ),
                    ),
                  if (_searchResults.isNotEmpty)
                    TextButton.icon(
                      onPressed: _showFilters,
                      icon: const Icon(Icons.tune, size: 16),
                      label: const Text('Filtres'),
                    ),
                ],
              ),
            ],
          ),
        ),
        
        // Grille des résultats
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: MediaQuery.of(context).size.width > 600 ? 3 : 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: MediaQuery.of(context).size.width > 600 ? 1.0 : 0.7,
            ),
            itemCount: _searchResults.length,
            itemBuilder: (context, index) {
              final ad = _searchResults[index];
              return AdCard(
                ad: ad,
                index: index,
                categoryLabels: _categoryLabels,
                onFavoriteChanged: () {
                  // Optionnel : on pourrait ajouter une notification ici
                },
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
          ),
        ),
      ],
    );
  }
} 