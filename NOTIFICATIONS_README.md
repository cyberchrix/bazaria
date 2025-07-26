# Système de Notifications - Bazaria

Ce document explique comment configurer et utiliser le système de notifications push dans l'application Bazaria.

## 🚀 Configuration

### 1. Dépendances Flutter

Les dépendances suivantes ont été ajoutées au `pubspec.yaml` :

```yaml
dependencies:
  firebase_messaging: ^14.7.10
  flutter_local_notifications: ^16.3.2
```

### 2. Configuration Firebase

1. **Télécharger le fichier de configuration Firebase** :
   - Va sur [Firebase Console](https://console.firebase.google.com/)
   - Sélectionne ton projet
   - Va dans Project Settings > Service Accounts
   - Clique sur "Generate new private key"
   - Télécharge le fichier JSON

2. **Placer le fichier** :
   - Place le fichier `firebase-service-account.json` dans le dossier `scripts/`

### 3. Configuration Appwrite

1. **Créer les collections nécessaires** :

   **Collection `users`** :
   - `fcmToken` (String) - Token Firebase Cloud Messaging
   - `lastTokenUpdate` (String) - Date de dernière mise à jour du token

   **Collection `subscriptions`** :
   - `userId` (String) - ID de l'utilisateur
   - `categoryId` (String) - ID de la catégorie
   - `createdAt` (String) - Date de création de l'abonnement

2. **Obtenir une clé API Appwrite** :
   - Va dans ton projet Appwrite
   - Settings > API Keys
   - Crée une nouvelle clé avec les permissions nécessaires
   - Remplace `YOUR_APPWRITE_API_KEY` dans `scripts/send_notifications.js`

## 📱 Utilisation dans l'App

### Initialisation

Le service de notifications est automatiquement initialisé au démarrage de l'app dans `main.dart` :

```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await initializeDateFormatting('fr_FR', null);
  await NotificationService().initialize(); // ← Initialisation ici
  runApp(const BazariaRoot());
}
```

### Abonnement aux notifications

Les utilisateurs peuvent s'abonner aux notifications d'une catégorie en cliquant sur l'icône de notification dans l'écran des catégories.

### Méthodes disponibles

```dart
// S'abonner à une catégorie
await NotificationService().subscribeToCategory('categoryId');

// Se désabonner d'une catégorie
await NotificationService().unsubscribeFromCategory('categoryId');

// Vérifier si abonné
bool isSubscribed = await NotificationService().isSubscribedToCategory('categoryId');

// Envoyer une notification de test
await NotificationService().sendTestNotification();
```

## 🔧 Scripts Backend

### Installation des dépendances Node.js

```bash
cd scripts
npm init -y
npm install node-appwrite firebase-admin
```

### Utilisation des scripts

```javascript
const { sendNotificationToCategory, sendNotificationToUser, sendNotificationToAll } = require('./send_notifications.js');

// Envoyer une notification à tous les utilisateurs abonnés à une catégorie
await sendNotificationToCategory(
  'electronique',
  'Nouvelle annonce !',
  'Un nouvel iPhone vient d\'être ajouté',
  { adId: '123' }
);

// Envoyer une notification à un utilisateur spécifique
await sendNotificationToUser(
  'userId',
  'Bienvenue !',
  'Merci de vous être inscrit'
);

// Envoyer une notification à tous les utilisateurs
await sendNotificationToAll(
  'Maintenance',
  'Le site sera en maintenance demain'
);
```

## 🔄 Intégration avec les annonces

Pour envoyer automatiquement des notifications quand une nouvelle annonce est créée, tu peux :

1. **Utiliser les webhooks Appwrite** :
   - Créer un webhook qui se déclenche à la création d'une annonce
   - Le webhook appelle ton script Node.js

2. **Utiliser les fonctions Appwrite** :
   - Créer une fonction Appwrite qui s'exécute à la création d'une annonce
   - La fonction envoie la notification

### Exemple de webhook

```javascript
// webhook.js
const { sendNotificationToCategory } = require('./send_notifications.js');

exports.handler = async (req, res) => {
  const { event, data } = req.body;
  
  if (event === 'databases.687ccdcf0000676911f1.collections.687ccdde0031f8eda985.documents.*.create') {
    const ad = data;
    
    // Envoyer une notification aux utilisateurs abonnés à cette catégorie
    await sendNotificationToCategory(
      ad.subCategoryId,
      'Nouvelle annonce !',
      `${ad.title} - ${ad.price}€`,
      { 
        adId: ad.$id,
        categoryId: ad.subCategoryId 
      }
    );
  }
  
  res.status(200).json({ success: true });
};
```

## 🧪 Test

### Test des notifications locales

```dart
// Dans ton app Flutter
await NotificationService().sendTestNotification();
```

### Test des notifications push

```bash
# Dans le dossier scripts
node send_notifications.js
```

## 📋 Checklist de déploiement

- [ ] Firebase configuré avec le fichier de service
- [ ] Collections Appwrite créées (`users`, `subscriptions`)
- [ ] Clé API Appwrite configurée dans le script
- [ ] Permissions de notification demandées dans l'app
- [ ] Webhooks ou fonctions configurés pour l'envoi automatique
- [ ] Tests effectués sur les notifications locales et push

## 🐛 Dépannage

### Problèmes courants

1. **Notifications non reçues** :
   - Vérifier que les permissions sont accordées
   - Vérifier que le token FCM est bien sauvegardé
   - Vérifier la configuration Firebase

2. **Erreurs de token** :
   - Les tokens FCM peuvent expirer
   - L'app gère automatiquement le renouvellement

3. **Erreurs Appwrite** :
   - Vérifier les permissions de la clé API
   - Vérifier que les collections existent

### Logs utiles

```dart
// Activer les logs détaillés
final logger = Logger();
logger.d('Token FCM: $token');
logger.e('Erreur: $error');
```

## 📚 Ressources

- [Firebase Cloud Messaging](https://firebase.google.com/docs/cloud-messaging)
- [Flutter Local Notifications](https://pub.dev/packages/flutter_local_notifications)
- [Appwrite Webhooks](https://appwrite.io/docs/webhooks)
- [Node Appwrite SDK](https://github.com/appwrite/sdk-for-node) 