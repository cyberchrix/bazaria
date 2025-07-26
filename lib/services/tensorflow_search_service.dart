// import 'dart:io';
// import 'package:tflite_flutter/tflite_flutter.dart';
// import 'package:image/image.dart' as img;
// import 'package:logger/logger.dart';

// final logger = Logger();

// class TensorFlowSearchService {
//   static Interpreter? _interpreter;
//   static List<String>? _labels;

//   /// Initialiser le modèle TensorFlow Lite
//   static Future<void> initializeModel() async {
//     try {
//       // Charger le modèle (vous devez ajouter votre modèle .tflite)
//       _interpreter = await Interpreter.fromAsset('assets/models/object_detection.tflite');
      
//       // Charger les labels (vous devez ajouter votre fichier labels.txt)
//       final labelData = await rootBundle.loadString('assets/models/labels.txt');
//       _labels = labelData.split('\n');
      
//       logger.d('Modèle TensorFlow Lite initialisé avec succès');
//     } catch (e) {
//       logger.e('Erreur lors de l\'initialisation du modèle: $e');
//     }
//   }

//   /// Analyser une image avec TensorFlow Lite
//   static Future<List<String>> analyzeImageWithTensorFlow(File imageFile) async {
//     if (_interpreter == null || _labels == null) {
//       await initializeModel();
//     }

//     try {
//       // Charger et redimensionner l'image
//       final imageBytes = await imageFile.readAsBytes();
//       final image = img.decodeImage(imageBytes);
      
//       if (image == null) return [];

//       // Redimensionner à 224x224 (taille d'entrée du modèle)
//       final resizedImage = img.copyResize(image, width: 224, height: 224);
      
//       // Convertir en tensor
//       final input = List.generate(1, (index) => List.generate(224, (y) => 
//         List.generate(224, (x) => List.generate(3, (c) {
//           final pixel = resizedImage.getPixel(x, y);
//           return c == 0 ? img.getRed(pixel) / 255.0 :
//                  c == 1 ? img.getGreen(pixel) / 255.0 :
//                          img.getBlue(pixel) / 255.0;
//         }))
//       ));

//       // Préparer le tensor de sortie
//       final output = List.filled(1 * 1001, 0.0).reshape([1, 1001]);

//       // Exécuter l'inférence
//       _interpreter!.run(input, output);

//       // Extraire les résultats
//       final results = output[0] as List<double>;
//       final sortedResults = List<MapEntry<int, double>>.generate(
//         results.length,
//         (index) => MapEntry(index, results[index]),
//       )..sort((a, b) => b.value.compareTo(a.value));

//       // Retourner les 5 labels les plus probables
//       final detectedLabels = <String>[];
//       for (int i = 0; i < 5 && i < sortedResults.length; i++) {
//         final labelIndex = sortedResults[i].key;
//         final confidence = sortedResults[i].value;
        
//         if (confidence > 0.5 && labelIndex < _labels!.length) {
//           detectedLabels.add(_labels![labelIndex]);
//         }
//       }

//       logger.d('Labels détectés par TensorFlow: $detectedLabels');
//       return detectedLabels;
//     } catch (e) {
//       logger.e('Erreur lors de l\'analyse TensorFlow: $e');
//       return [];
//     }
//   }

//   /// Libérer les ressources
//   static void dispose() {
//     _interpreter?.close();
//   }
// } 