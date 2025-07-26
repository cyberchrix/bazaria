import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:logger/logger.dart';

final logger = Logger();

class ImageSearchService {
  static const String _apiKey = 'YOUR_GOOGLE_CLOUD_API_KEY';
  static const String _visionApiUrl = 'https://vision.googleapis.com/v1/images:annotate?key=$_apiKey';

  /// Analyse une image et retourne les labels/tags détectés
  static Future<List<String>> analyzeImage(File imageFile) async {
    try {
      // Convertir l'image en base64
      final bytes = await imageFile.readAsBytes();
      final base64Image = base64Encode(bytes);

      final requestBody = {
        'requests': [
          {
            'image': {
              'content': base64Image,
            },
            'features': [
              {
                'type': 'LABEL_DETECTION',
                'maxResults': 10,
              },
              {
                'type': 'OBJECT_LOCALIZATION',
                'maxResults': 10,
              },
            ],
          },
        ],
      };

      final response = await http.post(
        Uri.parse(_visionApiUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(requestBody),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final labels = <String>[];

        // Extraire les labels
        if (data['responses'][0]['labelAnnotations'] != null) {
          for (final label in data['responses'][0]['labelAnnotations']) {
            labels.add(label['description'].toString().toLowerCase());
          }
        }

        // Extraire les objets détectés
        if (data['responses'][0]['localizedObjectAnnotations'] != null) {
          for (final object in data['responses'][0]['localizedObjectAnnotations']) {
            labels.add(object['name'].toString().toLowerCase());
          }
        }

        logger.d('Labels détectés: $labels');
        return labels;
      } else {
        logger.e('Erreur API Vision: ${response.statusCode} - ${response.body}');
        return [];
      }
    } catch (e) {
      logger.e('Erreur lors de l\'analyse d\'image: $e');
      return [];
    }
  }

  /// Recherche des annonces similaires basées sur les labels d'image
  static Future<List<Map<String, dynamic>>> searchSimilarAds(
    List<String> imageLabels,
    List<Map<String, dynamic>> allAds,
  ) async {
    final similarAds = <Map<String, dynamic>>[];
    
    for (final ad in allAds) {
      int score = 0;
      final adTitle = (ad['title'] as String).toLowerCase();
      final adDescription = (ad['description'] as String).toLowerCase();
      final adCategory = (ad['category'] as String).toLowerCase();

      // Calculer un score de similarité
      for (final label in imageLabels) {
        if (adTitle.contains(label)) score += 3;
        if (adDescription.contains(label)) score += 2;
        if (adCategory.contains(label)) score += 1;
      }

      if (score > 0) {
        similarAds.add({
          ...ad,
          'similarityScore': score,
        });
      }
    }

    // Trier par score de similarité décroissant
    similarAds.sort((a, b) => (b['similarityScore'] as int).compareTo(a['similarityScore'] as int));
    
    return similarAds.take(10).toList(); // Retourner les 10 plus similaires
  }
} 