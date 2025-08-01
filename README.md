# Bazaria 🏪

**Bazaria** est une application mobile de marketplace développée en Flutter, permettant aux utilisateurs de publier, rechercher et échanger des biens et services de manière intelligente et intuitive.

## 🚀 Fonctionnalités principales

### 📱 Interface utilisateur
- **Design moderne** avec thème personnalisé aux couleurs de la marque
- **Navigation intuitive** avec barre de navigation en bas
- **Écran d'onboarding** pour guider les nouveaux utilisateurs
- **Interface responsive** adaptée à tous les écrans

### 🔍 Recherche intelligente
- **Recherche traditionnelle améliorée** avec IA
- **Amélioration automatique des requêtes** via OpenAI
- **Système de synonymes** pour des résultats plus pertinents
- **Filtres avancés** par catégorie, prix et localisation
- **Tri intelligent** par pertinence, prix ou date

### 🏷️ Gestion des annonces
- **Publication d'annonces** avec photos, descriptions et prix
- **Système de catégories** hiérarchique et dynamique
- **Gestion des favoris** avec synchronisation
- **Recherche par localisation** avec sélecteur de ville

### 💬 Communication
- **Système de messagerie** intégré
- **Conversations en temps réel** entre utilisateurs
- **Notifications statiques** pour les interactions

### 🔧 Fonctionnalités techniques
- **Authentification** via Appwrite
- **Stockage cloud** pour les images et données
- **Synchronisation temps réel** des données
- **Cache intelligent** pour les performances
- **Gestion hors ligne** avec fallback

## 🛠️ Technologies utilisées

### Frontend
- **Flutter** - Framework de développement cross-platform
- **Dart** - Langage de programmation
- **Material Design** - Composants UI modernes

### Backend & Services
- **Appwrite** - Backend-as-a-Service pour l'authentification et la base de données
- **OpenAI API** - Amélioration des requêtes de recherche
- **Google Maps** - Intégration cartographique

### Intelligence Artificielle
- **LangChain** - Framework pour les applications IA
- **FAISS** - Recherche vectorielle pour la similarité
- **Système de synonymes** - Amélioration de la pertinence des résultats

## 📱 Écrans principaux

### 🏠 Accueil
- **Carrousel d'annonces** avec publicités
- **Catégories populaires** avec navigation
- **Annonces récentes** par catégorie
- **Barre de recherche** rapide

### 🔍 Recherche
- **Recherche intelligente** avec amélioration IA
- **Filtres avancés** (catégorie, prix, localisation)
- **Suggestions de recherche** contextuelles
- **Résultats triés** par pertinence

### ➕ Publier
- **Formulaire d'annonce** complet
- **Upload d'images** avec prévisualisation
- **Sélection de catégorie** hiérarchique
- **Validation des données** en temps réel

### ❤️ Favoris
- **Liste des favoris** synchronisée
- **Recherches sauvegardées** pour réutilisation
- **Gestion des collections** personnalisées

### 💬 Messages
- **Conversations** avec autres utilisateurs
- **Interface de chat** intuitive
- **Notifications** de nouveaux messages

### 👤 Profil
- **Informations utilisateur** personnalisées
- **Gestion des annonces** publiées
- **Paramètres** de l'application

## 🚀 Installation et démarrage

### Prérequis
- Flutter SDK (version 3.0+)
- Dart SDK
- Android Studio / Xcode pour le développement mobile
- Compte Appwrite configuré

### Installation
```bash
# Cloner le repository
git clone https://github.com/cyberchrix/bazaria.git
cd bazaria

# Installer les dépendances
flutter pub get

# Configurer les variables d'environnement
cp .env.example .env
# Éditer .env avec vos clés API

# Lancer l'application
flutter run
```

### Configuration
1. **Appwrite** : Configurer votre projet Appwrite avec les collections nécessaires
2. **OpenAI** : Ajouter votre clé API OpenAI dans le fichier `.env`

## 📊 Architecture

### Structure du projet
```
lib/
├── models/          # Modèles de données
├── screens/         # Écrans de l'application
├── services/        # Services métier et API
├── widgets/         # Composants réutilisables
├── theme/           # Configuration du thème
└── utils/           # Utilitaires et constantes
```

### Services principaux
- **AppwriteService** : Gestion de l'authentification et des données
- **AISearchService** : Recherche intelligente avec IA
- **OpenAIService** : Amélioration des requêtes
- **LangChainService** : Intégration IA avancée
- **LocationService** : Gestion des localisations

## 🔒 Sécurité

- **Authentification** sécurisée via Appwrite
- **Validation des données** côté client et serveur
- **Gestion des permissions** utilisateur
- **Chiffrement** des communications sensibles

## 📈 Performance

- **Cache intelligent** pour les requêtes fréquentes
- **Optimisation des images** avec compression
- **Lazy loading** pour les listes longues
- **Gestion mémoire** optimisée

## 🤝 Contribution

Les contributions sont les bienvenues ! Pour contribuer :

1. Fork le projet
2. Créer une branche feature (`git checkout -b feature/AmazingFeature`)
3. Commit vos changements (`git commit -m 'Add some AmazingFeature'`)
4. Push vers la branche (`git push origin feature/AmazingFeature`)
5. Ouvrir une Pull Request

## 📄 Licence

Ce projet est sous licence MIT. Voir le fichier `LICENSE` pour plus de détails.

## 📞 Support

Pour toute question ou support :
- Ouvrir une issue sur GitHub
- Contacter l'équipe de développement

---

**Bazaria** - Votre marketplace intelligent et moderne ! 🚀
