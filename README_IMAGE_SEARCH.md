# Guide d'implémentation : Recherche par image

## Vue d'ensemble

Ce guide vous explique comment implémenter une fonctionnalité de recherche par image dans votre application Bazaria. La recherche par image permet aux utilisateurs de prendre une photo ou sélectionner une image pour trouver des annonces similaires.

## Approches disponibles

### 1. Google Cloud Vision API (Recommandé)

**Avantages :**
- Très précise et fiable
- Reconnaissance d'objets, de texte, de visages
- API REST simple à utiliser
- Pas besoin de modèle local

**Inconvénients :**
- Coût par requête
- Nécessite une connexion internet
- Limite de requêtes

### 2. TensorFlow Lite (Local)

**Avantages :**
- Fonctionne hors ligne
- Pas de coût par requête
- Contrôle total sur le modèle

**Inconvénients :**
- Modèle moins précis
- Taille de l'application plus importante
- Nécessite un modèle pré-entraîné

## Implémentation avec Google Cloud Vision API

### Étape 1 : Configuration Google Cloud

1. Créez un projet Google Cloud
2. Activez l'API Vision
3. Créez une clé API
4. Remplacez `YOUR_GOOGLE_CLOUD_API_KEY` dans `image_search_service.dart`

### Étape 2 : Ajout du bouton de recherche par image

Dans votre écran de recherche (`search_screen.dart`), ajoutez un bouton :

```dart
IconButton(
  icon: const Icon(Icons.camera_alt),
  onPressed: () {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const ImageSearchScreen(),
      ),
    );
  },
),
```

### Étape 3 : Intégration avec votre base de données

Modifiez la fonction `_searchSimilarAds` dans `image_search_screen.dart` :

```dart
Future<void> _searchSimilarAds(List<String> labels) async {
  try {
    // Récupérer toutes les annonces depuis Appwrite
    final databases = AppwriteService().databases;
    final result = await databases.listDocuments(
      databaseId: '687ccdcf0000676911f1',
      collectionId: '687ccdde0031f8eda985',
      queries: [
        appw.Query.equal('isActive', true),
        appw.Query.limit(100), // Limiter pour les performances
      ],
    );
    
    final allAds = result.documents.map((doc) => {
      'title': doc.data['title'] ?? '',
      'description': doc.data['description'] ?? '',
      'category': doc.data['mainCategoryId'] ?? '',
      'price': doc.data['price'] ?? 0.0,
      'imageUrl': doc.data['imageUrl'] ?? '',
      'id': doc.$id,
    }).toList();

    final similarAds = await ImageSearchService.searchSimilarAds(labels, allAds);
    
    setState(() {
      _searchResults = similarAds;
    });
    
  } catch (e) {
    logger.e('Erreur lors de la recherche: $e');
  }
}
```

## Amélioration de l'algorithme de recherche

### Score de similarité avancé

Modifiez la fonction `searchSimilarAds` dans `image_search_service.dart` :

```dart
static Future<List<Map<String, dynamic>>> searchSimilarAds(
  List<String> imageLabels,
  List<Map<String, dynamic>> allAds,
) async {
  final similarAds = <Map<String, dynamic>>[];
  
  for (final ad in allAds) {
    double score = 0.0;
    final adTitle = (ad['title'] as String).toLowerCase();
    final adDescription = (ad['description'] as String).toLowerCase();
    final adCategory = (ad['category'] as String).toLowerCase();

    // Score pondéré par type de correspondance
    for (final label in imageLabels) {
      // Correspondance exacte
      if (adTitle == label) score += 10.0;
      if (adDescription == label) score += 8.0;
      
      // Correspondance partielle
      if (adTitle.contains(label)) score += 5.0;
      if (adDescription.contains(label)) score += 3.0;
      if (adCategory.contains(label)) score += 2.0;
      
      // Correspondance avec synonymes (optionnel)
      // score += _calculateSynonymScore(label, adTitle, adDescription);
    }

    if (score > 0) {
      similarAds.add({
        ...ad,
        'similarityScore': score,
      });
    }
  }

  // Trier par score décroissant
  similarAds.sort((a, b) => (b['similarityScore'] as double).compareTo(a['similarityScore'] as double));
  
  return similarAds.take(10).toList();
}
```

## Optimisations

### 1. Cache des résultats

```dart
class ImageSearchCache {
  static final Map<String, List<Map<String, dynamic>>> _cache = {};
  
  static void cacheResults(String imageHash, List<Map<String, dynamic>> results) {
    _cache[imageHash] = results;
  }
  
  static List<Map<String, dynamic>>? getCachedResults(String imageHash) {
    return _cache[imageHash];
  }
}
```

### 2. Recherche asynchrone

```dart
Future<void> _searchSimilarAdsAsync(List<String> labels) async {
  // Afficher un indicateur de chargement
  setState(() {
    _isSearching = true;
  });

  // Recherche en arrière-plan
  final results = await compute(ImageSearchService.searchSimilarAds, labels, allAds);
  
  setState(() {
    _searchResults = results;
    _isSearching = false;
  });
}
```

### 3. Filtres de recherche

Ajoutez des filtres pour affiner les résultats :

```dart
// Filtres de prix
final minPrice = _priceRange.start;
final maxPrice = _priceRange.end;

// Filtres de catégorie
final selectedCategories = _selectedCategories;

// Appliquer les filtres aux résultats
final filteredResults = _searchResults.where((ad) {
  final price = ad['price'] as double;
  final category = ad['category'] as String;
  
  return price >= minPrice && 
         price <= maxPrice && 
         selectedCategories.contains(category);
}).toList();
```

## Gestion des erreurs

```dart
Future<void> _analyzeImage() async {
  if (_selectedImage == null) return;

  setState(() {
    _isAnalyzing = true;
    _errorMessage = null;
  });

  try {
    final labels = await ImageSearchService.analyzeImage(_selectedImage!);
    
    if (labels.isEmpty) {
      setState(() {
        _errorMessage = 'Aucun élément détecté dans l\'image';
      });
      return;
    }
    
    setState(() {
      _detectedLabels = labels;
    });

    await _searchSimilarAds(labels);
    
  } catch (e) {
    setState(() {
      _errorMessage = 'Erreur lors de l\'analyse: $e';
    });
  } finally {
    setState(() {
      _isAnalyzing = false;
    });
  }
}
```

## Tests

### Test unitaire pour le service

```dart
void main() {
  group('ImageSearchService', () {
    test('should return similar ads based on labels', () async {
      final labels = ['iphone', 'smartphone'];
      final allAds = [
        {
          'title': 'iPhone 13 Pro',
          'description': 'Smartphone Apple',
          'category': 'Électronique',
          'price': 800.0,
        },
        {
          'title': 'Canapé cuir',
          'description': 'Meuble salon',
          'category': 'Meubles',
          'price': 500.0,
        },
      ];

      final results = await ImageSearchService.searchSimilarAds(labels, allAds);
      
      expect(results.length, 1);
      expect(results[0]['title'], 'iPhone 13 Pro');
      expect(results[0]['similarityScore'], greaterThan(0));
    });
  });
}
```

## Déploiement

### Variables d'environnement

Créez un fichier `.env` :

```
GOOGLE_CLOUD_API_KEY=your_api_key_here
```

### Sécurité

- Ne jamais exposer la clé API dans le code source
- Utilisez des variables d'environnement
- Limitez les permissions de l'API
- Surveillez l'utilisation et les coûts

## Métriques et analytics

```dart
// Tracker les recherches par image
void _trackImageSearch(List<String> labels, int resultCount) {
  analytics.logEvent(
    name: 'image_search',
    parameters: {
      'labels_count': labels.length,
      'results_count': resultCount,
      'labels': labels.join(','),
    },
  );
}
```

## Conclusion

La recherche par image est une fonctionnalité puissante qui peut considérablement améliorer l'expérience utilisateur. Commencez par l'implémentation Google Cloud Vision API pour une solution rapide et fiable, puis optimisez selon vos besoins spécifiques. 