import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../services/image_search_service.dart';
import '../widgets/ad_card.dart';
import '../models/ad.dart';
import 'package:logger/logger.dart';

final logger = Logger();

class ImageSearchScreen extends StatefulWidget {
  const ImageSearchScreen({super.key});

  @override
  State<ImageSearchScreen> createState() => _ImageSearchScreenState();
}

class _ImageSearchScreenState extends State<ImageSearchScreen> {
  File? _selectedImage;
  List<Map<String, dynamic>> _searchResults = [];
  bool _isAnalyzing = false;
  List<String> _detectedLabels = [];

  Future<void> _pickImage(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: source,
        imageQuality: 80,
      );
      
      if (picked != null) {
        setState(() {
          _selectedImage = File(picked.path);
          _searchResults = [];
          _detectedLabels = [];
        });
        
        // Analyser l'image
        await _analyzeImage();
      }
    } catch (e) {
      logger.e('Erreur lors de la sélection d\'image: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur lors de la sélection d\'image: $e')),
      );
    }
  }

  Future<void> _analyzeImage() async {
    if (_selectedImage == null) return;

    setState(() {
      _isAnalyzing = true;
    });

    try {
      // Analyser l'image avec Google Cloud Vision
      final labels = await ImageSearchService.analyzeImage(_selectedImage!);
      
      setState(() {
        _detectedLabels = labels;
      });

      // Rechercher des annonces similaires
      await _searchSimilarAds(labels);
      
    } catch (e) {
      logger.e('Erreur lors de l\'analyse: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur lors de l\'analyse: $e')),
      );
    } finally {
      setState(() {
        _isAnalyzing = false;
      });
    }
  }

  Future<void> _searchSimilarAds(List<String> labels) async {
    try {
      // Récupérer toutes les annonces (à adapter selon votre structure)
      // final allAds = await AdService.getAllAds();
      
      // Pour l'exemple, on utilise des données fictives
      final allAds = [
        {
          'title': 'iPhone 13 Pro',
          'description': 'Smartphone Apple en excellent état',
          'category': 'Électronique',
          'price': 800.0,
          'imageUrl': 'https://example.com/iphone.jpg',
        },
        {
          'title': 'Canapé cuir',
          'description': 'Canapé en cuir marron',
          'category': 'Meubles',
          'price': 500.0,
          'imageUrl': 'https://example.com/sofa.jpg',
        },
      ];

      final similarAds = await ImageSearchService.searchSimilarAds(labels, allAds);
      
      setState(() {
        _searchResults = similarAds;
      });
      
    } catch (e) {
      logger.e('Erreur lors de la recherche: $e');
    }
  }

  Future<void> _showImageSourceDialog() async {
    return showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Choisir une image'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.photo_library, color: Color(0xFFF15A22)),
                title: const Text('Bibliothèque'),
                subtitle: const Text('Choisir depuis la galerie'),
                onTap: () {
                  Navigator.of(context).pop();
                  _pickImage(ImageSource.gallery);
                },
              ),
              ListTile(
                leading: const Icon(Icons.camera_alt, color: Color(0xFFF15A22)),
                title: const Text('Appareil photo'),
                subtitle: const Text('Prendre une nouvelle photo'),
                onTap: () {
                  Navigator.of(context).pop();
                  _pickImage(ImageSource.camera);
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Annuler'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Recherche par image'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: Column(
        children: [
          // Section de sélection d'image
          Container(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                if (_selectedImage == null)
                  GestureDetector(
                    onTap: _showImageSourceDialog,
                    child: Container(
                      width: double.infinity,
                      height: 200,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade300, style: BorderStyle.solid),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.camera_alt, size: 48, color: Colors.grey.shade600),
                          const SizedBox(height: 8),
                          Text(
                            'Touchez pour sélectionner une image',
                            style: TextStyle(color: Colors.grey.shade600),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  Stack(
                    children: [
                      Container(
                        width: double.infinity,
                        height: 200,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.file(
                            _selectedImage!,
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                      Positioned(
                        top: 8,
                        right: 8,
                        child: GestureDetector(
                          onTap: () {
                            setState(() {
                              _selectedImage = null;
                              _searchResults = [];
                              _detectedLabels = [];
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.7),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.close, color: Colors.white, size: 20),
                          ),
                        ),
                      ),
                    ],
                  ),
                
                const SizedBox(height: 16),
                
                // Bouton pour changer d'image
                if (_selectedImage != null)
                  ElevatedButton.icon(
                    onPressed: _showImageSourceDialog,
                    icon: const Icon(Icons.camera_alt),
                    label: const Text('Changer d\'image'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFF15A22),
                      foregroundColor: Colors.white,
                    ),
                  ),
              ],
            ),
          ),

          // Section d'analyse
          if (_isAnalyzing)
            Container(
              padding: const EdgeInsets.all(16),
              child: const Row(
                children: [
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  SizedBox(width: 12),
                  Text('Analyse de l\'image en cours...'),
                ],
              ),
            ),

          // Labels détectés
          if (_detectedLabels.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Éléments détectés:',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: _detectedLabels.map((label) => Chip(
                      label: Text(label),
                      backgroundColor: const Color(0xFFF15A22).withValues(alpha: 0.1),
                      labelStyle: const TextStyle(color: Color(0xFFF15A22)),
                    )).toList(),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),

          // Résultats de recherche
          if (_searchResults.isNotEmpty)
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      'Annonces similaires (${_searchResults.length})',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: _searchResults.length,
                      itemBuilder: (context, index) {
                        final ad = _searchResults[index];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundImage: NetworkImage(ad['imageUrl']),
                            ),
                            title: Text(ad['title']),
                            subtitle: Text('${ad['price']} €'),
                            trailing: Text(
                              'Score: ${ad['similarityScore']}',
                              style: TextStyle(
                                color: Colors.grey.shade600,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            )
          else if (_selectedImage != null && !_isAnalyzing && _detectedLabels.isEmpty)
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.search_off, size: 64, color: Colors.grey.shade400),
                    const SizedBox(height: 16),
                    Text(
                      'Aucun élément détecté',
                      style: TextStyle(
                        fontSize: 18,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Essayez avec une autre image',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
} 