// import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:logger/logger.dart';
import 'package:appwrite/appwrite.dart' as appw;
import '../services/appwrite_service.dart';

final logger = Logger();



Future<Map<String, Map<String, dynamic>>> fetchCategoryLabels() async {
  final databases = AppwriteService().databases;
  final result = await databases.listDocuments(
    databaseId: '687ccdcf0000676911f1', // Remplace par ton databaseId
    collectionId: '687ce22e003b2c89f5b8', // Remplace par ta collectionId de catégories
    queries: [
      appw.Query.limit(100),
    ],
  );
  // On retourne un map $id -> data (et on ajoute $id dans la map si besoin)
  return {
    for (final doc in result.documents)
      doc.$id: {...doc.data, '4id': doc.$id}
  };
} 