import 'package:appwrite/appwrite.dart';
import '../models/criterion.dart';
import 'appwrite_service.dart';
import 'package:logger/logger.dart';

final logger = Logger();

class CriteriaService {
  static final Databases _databases = Databases(AppwriteService().client);
  
  // Cache pour les critères par catégorie
  static final Map<String, List<Criterion>> _criteriaCache = {};
  
  // Cache pour tous les critères
  static List<Criterion>? _allCriteriaCache;
  
  // Collection pour les critères
  static const String _criteriaCollectionId = '68850b060013a170d573';
  static const String _databaseId = '687ccdcf0000676911f1';

  /// Récupère les critères pour une catégorie donnée
  static Future<List<Criterion>> getCriteriaForCategory(String categoryId) async {
    try {
      logger.d('🔍 Recherche de critères pour la catégorie: $categoryId');
      
      // Vérifier le cache d'abord
      if (_criteriaCache.containsKey(categoryId)) {
        logger.d('📋 Critères récupérés depuis le cache pour la catégorie: $categoryId');
        final cachedCriteria = _criteriaCache[categoryId]!;
        logger.d('📊 Cache contient ${cachedCriteria.length} critères');
        return cachedCriteria;
      }

      // Récupérer depuis Appwrite
      logger.d('📡 Requête Appwrite pour categoryId: $categoryId');
      logger.d('📡 Database ID: $_databaseId, Collection ID: $_criteriaCollectionId');
      
      final response = await _databases.listDocuments(
        databaseId: _databaseId,
        collectionId: _criteriaCollectionId,
        queries: [
          Query.equal('categoryId', categoryId),
          Query.orderAsc('order'), // Ordre d'affichage
        ],
      );

      logger.d('📊 Réponse Appwrite: ${response.documents.length} documents trouvés');
      
      if (response.documents.isEmpty) {
        logger.w('⚠️ Aucun document trouvé pour categoryId: $categoryId');
        // Afficher tous les documents pour debug
        final allResponse = await _databases.listDocuments(
          databaseId: _databaseId,
          collectionId: _criteriaCollectionId,
          queries: [],
        );
        logger.d('📊 Total documents dans la collection: ${allResponse.documents.length}');
        for (final doc in allResponse.documents) {
          final data = doc.toMap();
          logger.d('📋 Document: categoryId=${data['categoryId']}, label=${data['label']}');
        }
      }
      
      final criteria = <Criterion>[];
      final seenIds = <String>{}; // Pour détecter les doublons par ID
      final seenLabels = <String>{}; // Pour détecter les doublons par label
      
      logger.d('🔍 Vérification de ${response.documents.length} documents pour doublons...');
      
      for (final doc in response.documents) {
        final Map<String, dynamic> attributes = doc.data; // Use doc.data for attributes
        attributes['\$id'] = doc.$id; // Add the document ID
        
        // Vérifier si on a déjà vu cet ID
        if (seenIds.contains(doc.$id)) {
          logger.w('⚠️ DOUBLON DÉTECTÉ ET IGNORÉ: ID ${doc.$id} déjà vu !');
          continue;
        }
        
        // Vérifier si on a déjà vu ce label pour cette catégorie
        final label = attributes['label']?.toString() ?? '';
        final labelKey = '${attributes['categoryId']}-$label';
        if (seenLabels.contains(labelKey)) {
          logger.w('⚠️ DOUBLON PAR LABEL DÉTECTÉ ET IGNORÉ: "$label" déjà vu pour cette catégorie !');
          continue;
        }
        
        seenIds.add(doc.$id);
        seenLabels.add(labelKey);
        
        logger.d('📋 Critère trouvé: ${attributes['label']} (${attributes['type']}) - ID: ${doc.$id}');
        logger.d('📋 Dépend de: ${attributes['dependsOn']}');
        try {
          final criterion = Criterion.fromJson(attributes);
          criteria.add(criterion);
          logger.d('✅ Critère ajouté: ${criterion.label}');
        } catch (e) {
          logger.e('❌ Erreur parsing critère ${attributes['label']}: $e');
          logger.e('❌ Données du critère: $attributes');
          // Continuer avec les autres critères au lieu de tout arrêter
          continue;
        }
      }
      
      logger.d('📊 Résultat final: ${criteria.length} critères uniques sur ${response.documents.length} documents');

      // Mettre en cache
      _criteriaCache[categoryId] = criteria;
      
      logger.d('📋 ${criteria.length} critères chargés pour la catégorie: $categoryId');
      return criteria;
      
    } catch (e) {
      logger.e('❌ Erreur lors du chargement des critères pour la catégorie $categoryId: $e');
      return [];
    }
  }

  /// Récupère tous les critères (pour l'administration)
  static Future<List<Criterion>> getAllCriteria() async {
    try {
      logger.d('🔍 getAllCriteria() appelé');
      
      // Vérifier le cache d'abord
      if (_allCriteriaCache != null) {
        logger.d('📋 Tous les critères récupérés depuis le cache: ${_allCriteriaCache!.length}');
        return _allCriteriaCache!;
      }
      
      logger.d('📡 Requête Appwrite pour tous les critères');
      logger.d('📡 Database ID: $_databaseId, Collection ID: $_criteriaCollectionId');
      
      logger.d('🔍 Tentative de récupération des critères...');
      logger.d('🔍 Database ID: $_databaseId');
      logger.d('🔍 Collection ID: $_criteriaCollectionId');
      
      final response = await _databases.listDocuments(
        databaseId: _databaseId,
        collectionId: _criteriaCollectionId,
      );
      
      logger.d('🔍 Réponse reçue d\'Appwrite');
      logger.d('🔍 Nombre de documents: ${response.documents.length}');

      logger.d('📊 Réponse Appwrite: ${response.documents.length} documents trouvés');
      
      // Debug: afficher les IDs des documents récupérés
      final retrievedIds = response.documents.map((doc) => doc.$id).toList();
      logger.d('📋 IDs des critères récupérés: $retrievedIds');
      
      if (response.documents.isEmpty) {
        logger.w('⚠️ Aucun critère trouvé dans Appwrite !');
        return [];
      }
      
      // Debug: afficher les premiers documents
      for (int i = 0; i < response.documents.length && i < 3; i++) {
        final doc = response.documents[i];
        final attributes = doc.data;
        logger.d('📋 Document $i: ID=${doc.$id}, Label=${attributes['label']}, CategoryId=${attributes['categoryId']}');
      }
      
      final criteria = response.documents.map((doc) {
        final Map<String, dynamic> attributes = doc.data; // Use doc.data for attributes
        attributes['\$id'] = doc.$id; // Add the document ID
        logger.d('DEBUG getAllCriteria: Document ID: ${doc.$id}, Attributes: $attributes');
        return Criterion.fromJson(attributes);
      }).toList();
      
      // Mettre en cache
      _allCriteriaCache = criteria;
      logger.d('📋 ${criteria.length} critères mis en cache');
      
      return criteria;
    } catch (e) {
      logger.e('❌ Erreur lors du chargement de tous les critères: $e');
      return [];
    }
  }

  /// Crée un nouveau critère
  static Future<bool> createCriterion(Criterion criterion, String categoryId) async {
    try {
      await _databases.createDocument(
        databaseId: _databaseId,
        collectionId: _criteriaCollectionId,
        documentId: ID.unique(),
        data: {
          ...criterion.toJson(),
          'categoryId': categoryId,
          'order': await _getNextOrder(categoryId),
        },
      );

      // Vider le cache pour cette catégorie
      _criteriaCache.remove(categoryId);
      
      logger.d('✅ Critère créé avec succès: ${criterion.id}');
      return true;
      
    } catch (e) {
      logger.e('❌ Erreur lors de la création du critère: $e');
      return false;
    }
  }

  /// Met à jour un critère existant
  static Future<bool> updateCriterion(String criterionId, Criterion criterion) async {
    try {
      await _databases.updateDocument(
        databaseId: _databaseId,
        collectionId: _criteriaCollectionId,
        documentId: criterionId,
        data: criterion.toJson(),
      );

      // Vider tous les caches
      _criteriaCache.clear();
      
      logger.d('✅ Critère mis à jour avec succès: $criterionId');
      return true;
      
    } catch (e) {
      logger.e('❌ Erreur lors de la mise à jour du critère: $e');
      return false;
    }
  }

  /// Supprime un critère
  static Future<bool> deleteCriterion(String criterionId) async {
    try {
      await _databases.deleteDocument(
        databaseId: _databaseId,
        collectionId: _criteriaCollectionId,
        documentId: criterionId,
      );

      // Vider tous les caches
      _criteriaCache.clear();
      
      logger.d('✅ Critère supprimé avec succès: $criterionId');
      return true;
      
    } catch (e) {
      logger.e('❌ Erreur lors de la suppression du critère: $e');
      return false;
    }
  }

  /// Valide les valeurs des critères
  static List<String> validateCriteriaValues(
    Map<String, dynamic> values,
    List<Criterion> criteria,
  ) {
    final errors = <String>[];

    for (final criterion in criteria) {
      final value = values[criterion.id];
      
      // Vérifier si le critère est requis
      if (criterion.required && (value == null || value.toString().isEmpty)) {
        errors.add('${criterion.label} est requis');
        continue;
      }

      // Si pas de valeur, passer au suivant
      if (value == null || value.toString().isEmpty) {
        continue;
      }

      // Validation selon le type
      switch (criterion.type) {
        case CriterionType.number:
        case CriterionType.range:
          final numValue = double.tryParse(value.toString());
          if (numValue == null) {
            errors.add('${criterion.label} doit être un nombre');
          } else {
            if (criterion.minValue != null && numValue < criterion.minValue!) {
              errors.add('${criterion.label} doit être au moins ${criterion.minValue}');
            }
            if (criterion.maxValue != null && numValue > criterion.maxValue!) {
              errors.add('${criterion.label} doit être au maximum ${criterion.maxValue}');
            }
          }
          break;
          
        case CriterionType.select:
          if (criterion.options != null && !criterion.options!.contains(value)) {
            errors.add('${criterion.label} doit être une des options proposées');
          }
          break;
          
        case CriterionType.boolean:
          if (value != true && value != false) {
            errors.add('${criterion.label} doit être vrai ou faux');
          }
          break;
          
        default:
          // Pas de validation spéciale pour les autres types
          break;
      }
    }

    return errors;
  }

  /// Filtre les critères visibles selon les dépendances
  static List<Criterion> getVisibleCriteria(
    List<Criterion> allCriteria,
    Map<String, dynamic> currentValues,
  ) {
    logger.d('🔍 Filtrage des critères visibles');
    logger.d('📋 Valeurs actuelles: $currentValues');
    logger.d('📋 Total critères: ${allCriteria.length}');
    
    // Éliminer les doublons par ID
    final uniqueCriteria = <String, Criterion>{};
    for (final criterion in allCriteria) {
      if (!uniqueCriteria.containsKey(criterion.id)) {
        uniqueCriteria[criterion.id] = criterion;
      } else {
        logger.w('⚠️ DOUBLON ÉLIMINÉ: ${criterion.label} (ID: ${criterion.id})');
      }
    }
    
    final filteredCriteria = uniqueCriteria.values.toList();
    logger.d('📋 Critères uniques après déduplication: ${filteredCriteria.length}');
    
    return filteredCriteria.where((criterion) {
      logger.d('🔍 Vérification critère: ${criterion.label}');
      
      // Si le critère ne dépend de rien, il est toujours visible
      if (criterion.dependsOn == null) {
        logger.d('✅ ${criterion.label}: Pas de dépendance, visible');
        return true;
      }

      logger.d('🔍 ${criterion.label}: Dépend de ${criterion.dependsOn}');
      
      // Vérifier si le critère parent a une valeur
      final parentValue = currentValues[criterion.dependsOn];
      logger.d('🔍 ${criterion.label}: Valeur parent = $parentValue');
      
      if (parentValue == null || parentValue.toString().isEmpty) {
        logger.d('❌ ${criterion.label}: Pas de valeur parent, caché');
        return false;
      }

      // Si le critère a des options conditionnelles, vérifier que la valeur parent correspond
      if (criterion.conditionalOptions != null) {
        final parentValueStr = parentValue.toString();
        logger.d('🔍 ${criterion.label}: Options conditionnelles = ${criterion.conditionalOptions}');
        logger.d('🔍 ${criterion.label}: Valeur parent = "$parentValueStr"');
        final isVisible = criterion.conditionalOptions!.containsKey(parentValueStr);
        logger.d('${isVisible ? "✅" : "❌"} ${criterion.label}: ${isVisible ? "Visible" : "Caché"} (clé trouvée: ${criterion.conditionalOptions!.containsKey(parentValueStr)})');
        return isVisible;
      }

      // Sinon, le critère est visible si le parent a une valeur
      logger.d('✅ ${criterion.label}: Visible (pas d\'options conditionnelles)');
      return true;
    }).toList();
  }

  /// Obtient le prochain ordre pour une catégorie
  static Future<int> _getNextOrder(String categoryId) async {
    try {
      final response = await _databases.listDocuments(
        databaseId: _databaseId,
        collectionId: _criteriaCollectionId,
        queries: [
          Query.equal('categoryId', categoryId),
          Query.orderDesc('order'),
          Query.limit(1),
        ],
      );

      if (response.documents.isNotEmpty) {
        final lastOrder = response.documents.first.data['order'] ?? 0;
        return lastOrder + 1;
      }
      
      return 0;
    } catch (e) {
      logger.e('❌ Erreur lors du calcul de l\'ordre: $e');
      return 0;
    }
  }

  /// Vide le cache
  static void clearCache() {
    _criteriaCache.clear();
    _allCriteriaCache = null;
    logger.d('🗑️ Cache des critères vidé');
  }

  /// Récupère les labels des critères par ID
  static Future<Map<String, String>> getCriteriaLabels(List<String> criteriaIds, {bool forceRefresh = false}) async {
    final Map<String, String> labels = {};
    try {
      logger.d('🔍 Récupération des labels pour ${criteriaIds.length} critères (forceRefresh: $forceRefresh)');
      logger.d('🔍 IDs demandés: $criteriaIds');
      
      // Forcer le rafraîchissement si demandé
      if (forceRefresh) {
        logger.d('🔄 Force refresh du cache des critères');
        clearCache();
      }
      
      final allCriteria = await getAllCriteria();
      logger.d('📋 ${allCriteria.length} critères récupérés au total');
      
      // Debug: afficher tous les critères
      for (final criterion in allCriteria) {
        logger.d('📋 Critère disponible: ID=${criterion.id}, Label=${criterion.label}');
      }

      // Créer un map des labels par ID
      logger.d('🔍 IDs disponibles: ${allCriteria.map((c) => c.id).toList()}');
      
      // Première passe : correspondance exacte par ID
      for (final criterion in allCriteria) {
        if (criteriaIds.contains(criterion.id)) {
          labels[criterion.id] = criterion.label;
          logger.d('✅ Label trouvé par ID: ${criterion.id} -> ${criterion.label}');
        }
      }
      
      logger.d('📋 ${labels.length} labels trouvés sur ${criteriaIds.length} demandés');
      logger.d('📋 Labels finaux: $labels');
      return labels;
    } catch (e) {
      logger.e('❌ Erreur lors de la récupération des labels de critères: $e');
      logger.e('❌ Stack trace: ${e.toString()}');
      return {};
    }
  }


} 