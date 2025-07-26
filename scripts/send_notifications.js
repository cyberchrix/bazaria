const { Client, Databases, Query } = require('node-appwrite');
const admin = require('firebase-admin');

// Configuration Appwrite
const client = new Client()
  .setEndpoint('https://cloud.appwrite.io/v1')
  .setProject('686ac0840038d075de43')
  .setKey('standard_a2eb768275a71f85380f0320589366fc4ee20672740e9eeca75b2ed937dd5e8dbbffd6279cbc69f2e3ec57ae1fea323f0d1f3ceba590e88ff15a2838690363c6bdef07119f33dea08b231b5445b1b1e8b0ae882788b96d74bb08086a22d090e1a7a8ab64a9432c020b9edb911821e6e616b02fec0bb7730376fba0c794987281'); // Remplace par ta clé API

// IDs Appwrite
const DATABASE_ID = '687ccdcf0000676911f1';
const USERS_COLLECTION_ID = '68825f21003d809ed8b2'; // Remplace par l'ID de ta collection users
const SUBSCRIPTIONS_COLLECTION_ID = '68825f76001a8ed8619e'; // Remplace par l'ID de ta collection subscriptions

const databases = new Databases(client);

// Configuration Firebase Admin
const serviceAccount = require('./firebase-service-account.json'); // Télécharge depuis Firebase Console

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
});

const messaging = admin.messaging();

// Fonction pour envoyer une notification à tous les utilisateurs abonnés à une catégorie
async function sendNotificationToCategory(categoryId, title, body, data = {}) {
  try {
    // 1. Récupérer tous les utilisateurs abonnés à cette catégorie
    const subscriptions = await databases.listDocuments(
      DATABASE_ID,
      SUBSCRIPTIONS_COLLECTION_ID,
      [Query.equal('categoryId', categoryId)]
    );

    if (subscriptions.documents.length === 0) {
      console.log('Aucun abonné trouvé pour cette catégorie');
      return;
    }

    // 2. Récupérer les tokens FCM de ces utilisateurs
    const userIds = subscriptions.documents.map(sub => sub.userId);
    const users = await databases.listDocuments(
      DATABASE_ID,
      USERS_COLLECTION_ID,
      [Query.equal('$id', userIds)]
    );

    const tokens = users.documents
      .map(user => user.fcmToken)
      .filter(token => token); // Filtrer les tokens null/undefined

    if (tokens.length === 0) {
      console.log('Aucun token FCM trouvé pour les utilisateurs abonnés');
      return;
    }

    // 3. Envoyer la notification via Firebase
    const message = {
      notification: {
        title: title,
        body: body,
      },
      data: {
        ...data,
        categoryId: categoryId,
        click_action: 'FLUTTER_NOTIFICATION_CLICK',
      },
      tokens: tokens,
    };

    const response = await messaging.sendMulticast(message);
    
    console.log(`Notification envoyée à ${response.successCount}/${tokens.length} utilisateurs`);
    
    if (response.failureCount > 0) {
      console.log('Échecs:', response.responses);
    }

  } catch (error) {
    console.error('Erreur lors de l\'envoi de la notification:', error);
  }
}

// Fonction pour envoyer une notification à un utilisateur spécifique
async function sendNotificationToUser(userId, title, body, data = {}) {
  try {
    // Récupérer le token FCM de l'utilisateur
    const user = await databases.getDocument(
      DATABASE_ID,
      USERS_COLLECTION_ID,
      userId
    );

    if (!user.fcmToken) {
      console.log('Aucun token FCM trouvé pour cet utilisateur');
      return;
    }

    // Envoyer la notification
    const message = {
      notification: {
        title: title,
        body: body,
      },
      data: {
        ...data,
        userId: userId,
        click_action: 'FLUTTER_NOTIFICATION_CLICK',
      },
      token: user.fcmToken,
    };

    const response = await messaging.send(message);
    console.log('Notification envoyée avec succès:', response);

  } catch (error) {
    console.error('Erreur lors de l\'envoi de la notification:', error);
  }
}

// Fonction pour envoyer une notification à tous les utilisateurs
async function sendNotificationToAll(title, body, data = {}) {
  try {
    // Récupérer tous les utilisateurs avec des tokens FCM
    const users = await databases.listDocuments(
      DATABASE_ID,
      USERS_COLLECTION_ID,
      [Query.isNotNull('fcmToken')]
    );

    const tokens = users.documents
      .map(user => user.fcmToken)
      .filter(token => token);

    if (tokens.length === 0) {
      console.log('Aucun token FCM trouvé');
      return;
    }

    // Envoyer la notification
    const message = {
      notification: {
        title: title,
        body: body,
      },
      data: {
        ...data,
        click_action: 'FLUTTER_NOTIFICATION_CLICK',
      },
      tokens: tokens,
    };

    const response = await messaging.sendMulticast(message);
    
    console.log(`Notification envoyée à ${response.successCount}/${tokens.length} utilisateurs`);

  } catch (error) {
    console.error('Erreur lors de l\'envoi de la notification:', error);
  }
}

// Exemples d'utilisation
async function examples() {
  // Envoyer une notification à tous les utilisateurs abonnés à la catégorie "electronique"
  await sendNotificationToCategory(
    'electronique',
    'Nouvelle annonce électronique !',
    'Un nouvel iPhone vient d\'être ajouté dans la catégorie Électronique',
    { adId: '123', categoryName: 'Électronique' }
  );

  // Envoyer une notification à un utilisateur spécifique
  await sendNotificationToUser(
    'user123',
    'Bienvenue sur Bazaria !',
    'Merci de vous être inscrit sur notre plateforme',
    { type: 'welcome' }
  );

  // Envoyer une notification à tous les utilisateurs
  await sendNotificationToAll(
    'Maintenance prévue',
    'Le site sera en maintenance demain de 2h à 4h du matin',
    { type: 'maintenance' }
  );
}

// Exporter les fonctions pour utilisation dans d'autres scripts
module.exports = {
  sendNotificationToCategory,
  sendNotificationToUser,
  sendNotificationToAll,
};

// Exécuter les exemples si le script est appelé directement
if (require.main === module) {
  examples().then(() => {
    console.log('Exemples terminés');
    process.exit(0);
  }).catch(error => {
    console.error('Erreur:', error);
    process.exit(1);
  });
} 