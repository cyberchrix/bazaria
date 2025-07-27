# 📋 Guide des Critères Dynamiques - Bazaria

## 🎯 **Vue d'ensemble**

Les critères dynamiques permettent d'ajouter des **caractéristiques spécifiques** à chaque annonce selon sa catégorie. Ils s'adaptent automatiquement et peuvent être **interdépendants**.

## 🏗️ **Architecture**

### **1. Collection `criteria` (Appwrite)**
```
criteria/
├── id: string (unique)
├── categoryId: string (référence catégorie)
├── label: string (nom affiché)
├── type: string (string, number, range, select, boolean)
├── options: string[] (pour type select)
├── dependsOn: string? (critère parent)
├── conditionalOptions: object? (options selon parent)
├── required: boolean
├── unit: string? (kg, cm, etc.)
├── minValue: number? (pour range/number)
├── maxValue: number? (pour range/number)
├── placeholder: string?
└── order: number (ordre d'affichage)
```

### **2. Collection `ads` (existante)**
```
ads/
├── id: string
├── title: string
├── mainCategoryId: string
├── criterias: object[]
│   ├── id_criteria: string
│   └── value: any
└── ...autres champs
```

## 🚀 **Installation**

### **Étape 1 : Créer la collection criteria**
```bash
cd scripts
npm install node-appwrite
node setup_criteria_collection.js
```

### **Étape 2 : Ajouter des critères (optionnel)**
```bash
node add_dependent_criteria.js
```

## 📝 **Exemples de critères**

### **Exemple 1 : Critères simples (Meubles)**
```json
{
  "categoryId": "cat_meubles",
  "label": "Type de meuble",
  "type": "select",
  "options": ["Canapé", "Table", "Chaise", "Armoire"],
  "required": true,
  "order": 1
}
```

### **Exemple 2 : Critères avec unité (Véhicules)**
```json
{
  "categoryId": "cat_vehicules",
  "label": "Kilométrage",
  "type": "number",
  "unit": "km",
  "minValue": 0,
  "maxValue": 500000,
  "required": false,
  "order": 3
}
```

### **Exemple 3 : Critères interdépendants (Électronique)**
```json
{
  "categoryId": "cat_electronique",
  "label": "Marque",
  "type": "select",
  "options": ["Apple", "Samsung", "Xiaomi"],
  "required": true,
  "order": 1
},
{
  "categoryId": "cat_electronique",
  "label": "Modèle",
  "type": "select",
  "dependsOn": "marque",
  "conditionalOptions": {
    "Apple": ["iPhone 14", "iPhone 15"],
    "Samsung": ["Galaxy S23", "Galaxy S24"],
    "Xiaomi": ["Redmi Note 12", "Mi 13"]
  },
  "required": true,
  "order": 2
}
```

## 🔧 **Types de critères**

### **1. String (Texte)**
```json
{
  "type": "string",
  "placeholder": "Saisissez la marque"
}
```

### **2. Number (Nombre)**
```json
{
  "type": "number",
  "unit": "kg",
  "minValue": 0,
  "maxValue": 1000
}
```

### **3. Range (Slider)**
```json
{
  "type": "range",
  "unit": "cm",
  "minValue": 0,
  "maxValue": 200
}
```

### **4. Select (Sélection)**
```json
{
  "type": "select",
  "options": ["Option 1", "Option 2", "Option 3"]
}
```

### **5. Boolean (Vrai/Faux)**
```json
{
  "type": "boolean"
}
```

## 🔄 **Critères interdépendants**

### **Principe**
Un critère peut **dépendre** d'un autre critère. Ses options changent selon la valeur du critère parent.

### **Exemple : Smartphone**
1. **Marque** → Apple, Samsung, Xiaomi
2. **Modèle** (dépend de Marque)
   - Si Apple → iPhone 14, iPhone 15
   - Si Samsung → Galaxy S23, Galaxy S24
   - Si Xiaomi → Redmi Note 12, Mi 13
3. **Capacité** (dépend de Modèle)
   - Si iPhone 14 → 128 GB, 256 GB, 512 GB
   - Si Galaxy S23 → 128 GB, 256 GB, 512 GB

### **Configuration**
```json
{
  "dependsOn": "marque",
  "conditionalOptions": {
    "Apple": ["iPhone 14", "iPhone 15"],
    "Samsung": ["Galaxy S23", "Galaxy S24"]
  }
}
```

## 📱 **Utilisation dans l'app**

### **1. Ajout d'annonce**
- Les critères apparaissent automatiquement selon la catégorie
- Les dépendances se mettent à jour en temps réel
- Validation automatique des valeurs

### **2. Affichage des annonces**
- Les critères sont affichés dans les détails
- Format lisible avec labels et valeurs

### **3. Recherche**
- Possibilité de filtrer par critères
- Recherche avancée par caractéristiques

## 🛠️ **API et Services**

### **CriteriaService**
```dart
// Récupérer les critères d'une catégorie
List<Criterion> criteria = await CriteriaService.getCriteriaForCategory('cat_meubles');

// Valider les valeurs
List<String> errors = CriteriaService.validateCriteriaValues(values, criteria);

// Filtrer les critères visibles
List<Criterion> visible = CriteriaService.getVisibleCriteria(allCriteria, currentValues);
```

### **CriteriaForm Widget**
```dart
CriteriaForm(
  categoryId: 'cat_meubles',
  initialValues: {'type': 'Canapé'},
  onValuesChanged: (values) => print(values),
  errors: ['Type de meuble est requis'],
)
```

## 📊 **Exemples concrets par catégorie**

### **Meubles**
- Type de meuble (select)
- Matériau (select)
- État (select)
- Dimensions (string)
- Couleur (select)

### **Véhicules**
- Type de véhicule (select)
- Marque (string)
- Modèle (string)
- Année (number)
- Kilométrage (number)
- Carburant (select)

### **Électronique**
- Type d'appareil (select)
- Marque (select)
- Modèle (select, dépendant)
- Capacité (select, dépendant)
- État (select)
- Garantie (boolean)

### **Immobilier**
- Type de bien (select)
- Surface (number)
- Nombre de pièces (number)
- Étage (number)
- Ascenseur (boolean)
- Balcon (boolean)

## 🔍 **Recherche et filtres**

### **Filtrage par critères**
```dart
// Exemple : Rechercher des canapés en tissu
Map<String, dynamic> filters = {
  'mainCategoryId': 'cat_meubles',
  'criterias': [
    {'id_criteria': 'type', 'value': 'Canapé'},
    {'id_criteria': 'materiau', 'value': 'Tissu'}
  ]
};
```

### **Recherche avancée**
- Filtres par plage de valeurs
- Recherche par caractéristiques multiples
- Suggestions intelligentes

## 🎨 **Personnalisation**

### **Thème et style**
- Couleurs cohérentes avec l'app
- Animations fluides
- Responsive design

### **Validation**
- Messages d'erreur personnalisés
- Validation en temps réel
- Indicateurs visuels

## 🚀 **Prochaines étapes**

1. **Créer la collection** dans Appwrite
2. **Ajouter des critères** pour tes catégories
3. **Tester** le formulaire dynamique
4. **Implémenter** la recherche par critères
5. **Optimiser** les performances

## 📞 **Support**

Pour toute question ou problème :
- Vérifier les logs dans la console
- Contrôler la structure des données dans Appwrite
- Tester avec des critères simples d'abord 