import 'package:appwrite/models.dart' as appwrite_models;

class Ad {
  final String id;
  final String title;
  final double price;
  final String mainCategoryId;
  final String subCategoryId;
  final String location;
  final String postalCode;
  final DateTime publicationDate;
  final String imageUrl; // Gardé pour compatibilité
  final List<String> imageUrls; // Nouveau champ pour plusieurs images
  final String description;
  final String userId;
  final bool isActive;
  final dynamic criterias;
  // Coordonnées GPS
  final double? latitude;
  final double? longitude;

  Ad({
    required this.id,
    required this.title,
    required this.price,
    required this.mainCategoryId,
    required this.subCategoryId,
    required this.location,
    required this.postalCode,
    required this.publicationDate,
    required this.imageUrl,
    this.imageUrls = const [],
    required this.description,
    required this.userId,
    this.isActive = false,
    this.criterias,
    this.latitude,
    this.longitude,
  });

  factory Ad.fromAppwrite(appwrite_models.Document doc) {
    final data = doc.data;
    
    // Gestion des images multiples
    List<String> imageUrls = [];
    if (data['imageUrls'] != null) {
      if (data['imageUrls'] is List) {
        imageUrls = List<String>.from(data['imageUrls']);
      }
    }
    
    // Si pas d'images multiples, utiliser l'image unique
    final singleImageUrl = data['imageUrl'] ?? '';
    if (imageUrls.isEmpty && singleImageUrl.isNotEmpty) {
      imageUrls = [singleImageUrl];
    }
    
    return Ad(
      id: doc.$id,
      title: data['title'] ?? '',
      price: (data['price'] is int) ? (data['price'] as int).toDouble() : (data['price'] ?? 0.0),
      mainCategoryId: data['mainCategoryId'] ?? '',
      subCategoryId: data['subCategoryId'] ?? '',
      location: data['location'] ?? '',
      postalCode: data['postalCode'] ?? '',
      publicationDate: data['publicationDate'] != null
          ? DateTime.parse(data['publicationDate'])
          : DateTime.now(),
      imageUrl: singleImageUrl,
      imageUrls: imageUrls,
      description: data['description'] ?? '',
      userId: data['userId'] ?? '',
      isActive: data['isActive'] ?? false,
      criterias: data['criterias'],
      latitude: data['latitude'] != null ? (data['latitude'] is int ? (data['latitude'] as int).toDouble() : data['latitude'] as double) : null,
      longitude: data['longitude'] != null ? (data['longitude'] is int ? (data['longitude'] as int).toDouble() : data['longitude'] as double) : null,
    );
  }
}
