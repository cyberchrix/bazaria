import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:logger/logger.dart';
import 'package:appwrite/appwrite.dart';
import 'appwrite_service.dart';

final logger = Logger();

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  final AppwriteService _appwriteService = AppwriteService();

  Future<void> initialize() async {
    await _firebaseMessaging.requestPermission();
    // Optionnel : gérer les callbacks ici
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      // Gérer la réception d'une notification en premier plan
    });
  }

  Future<String?> getToken() async {
    return await _firebaseMessaging.getToken();
  }

  Future<void> debugAPNSToken() async {
    final apnsToken = await _firebaseMessaging.getAPNSToken();
    print('🔑 APNS Token: ${apnsToken ?? 'Aucun token'}');
  }

  // Sauvegarder le token FCM dans Appwrite
  Future<void> _saveFCMToken(String token) async {
    try {
      final user = await _appwriteService.getCurrentUser();
      if (user != null) {
        await _appwriteService.databases.updateDocument(
          databaseId: '687ccdcf0000676911f1',
          collectionId: '68825f21003d809ed8b2', // Remplace par ton vrai ID
          documentId: user.$id,
          data: {
            'fcmToken': token,
            'lastTokenUpdate': DateTime.now().toIso8601String(),
          },
        );
        logger.d('Token FCM sauvegardé pour l\'utilisateur ${user.$id}');
      }
    } catch (e) {
      logger.e('Erreur lors de la sauvegarde du token FCM: $e');
    }
  }

  // Gérer les messages en premier plan
  void _handleForegroundMessage(dynamic message) {
    logger.d('Message reçu en premier plan (désactivé)');
  }

  // Gérer les messages en arrière-plan
  void _handleBackgroundMessage(dynamic message) {
    logger.d('Message reçu en arrière-plan (désactivé)');
  }

  // S'abonner aux notifications d'une catégorie
  Future<void> subscribeToCategory(String categoryId) async {
    try {
      final user = await _appwriteService.getCurrentUser();
      if (user != null) {
        await _appwriteService.databases.createDocument(
          databaseId: '687ccdcf0000676911f1',
          collectionId: '68825f76001a8ed8619e', // Remplace par ton vrai ID
          documentId: ID.unique(),
          data: {
            'userId': user.$id,
            'categoryId': categoryId,
            'createdAt': DateTime.now().toIso8601String(),
          },
        );
        logger.d('Abonnement à la catégorie $categoryId créé');
      }
    } catch (e) {
      logger.e('Erreur lors de l\'abonnement: $e');
    }
  }

  // Se désabonner d'une catégorie
  Future<void> unsubscribeFromCategory(String categoryId) async {
    try {
      final user = await _appwriteService.getCurrentUser();
      if (user != null) {
        final result = await _appwriteService.databases.listDocuments(
          databaseId: '687ccdcf0000676911f1',
          collectionId: '68825f76001a8ed8619e', // Remplace par ton vrai ID
          queries: [
            Query.equal('userId', user.$id),
            Query.equal('categoryId', categoryId),
          ],
        );
        
        for (final doc in result.documents) {
          await _appwriteService.databases.deleteDocument(
            databaseId: '687ccdcf0000676911f1',
            collectionId: '68825f76001a8ed8619e', // Remplace par ton vrai ID
            documentId: doc.$id,
          );
        }
        logger.d('Désabonnement de la catégorie $categoryId effectué');
      }
    } catch (e) {
      logger.e('Erreur lors du désabonnement: $e');
    }
  }

  // Afficher une notification locale
  Future<void> showLocalNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
    // Temporairement désactivé
    logger.d('Notification locale (désactivée): $title - $body');
    print('🔔 Notification locale: $title - $body');
  }

  // Récupérer les abonnements d'un utilisateur
  Future<List<String>> getUserSubscriptions() async {
    try {
      final user = await _appwriteService.getCurrentUser();
      if (user != null) {
        final result = await _appwriteService.databases.listDocuments(
          databaseId: '687ccdcf0000676911f1',
          collectionId: '68825f76001a8ed8619e', // Remplace par ton vrai ID
          queries: [
            Query.equal('userId', user.$id),
          ],
        );
        
        return result.documents.map((doc) => doc.data['categoryId'] as String).toList();
      }
      return [];
    } catch (e) {
      logger.e('Erreur lors de la récupération des abonnements: $e');
      return [];
    }
  }

  // Vérifier si l'utilisateur est abonné à une catégorie
  Future<bool> isSubscribedToCategory(String categoryId) async {
    final subscriptions = await getUserSubscriptions();
    return subscriptions.contains(categoryId);
  }

  // Envoyer une notification de test
  Future<void> sendTestNotification() async {
    await showLocalNotification(
      title: 'Test de notification',
      body: 'Cette notification fonctionne correctement !',
    );
  }

  // Test simplifié sans notifications locales
  Future<void> sendTestNotificationSimple() async {
    try {
      logger.d('Test de notification simple');
      print('🔔 Test de notification simple');
      
      // Test Appwrite seulement
      final user = await _appwriteService.getCurrentUser();
      logger.d('Utilisateur connecté: ${user?.$id}');
      
      print('✅ Test terminé avec succès');
    } catch (e) {
      logger.e('Erreur lors du test simple: $e');
      print('❌ Erreur: $e');
    }
  }
} 