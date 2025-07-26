import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../services/category_service.dart';
import 'dart:io';
import 'package:logger/logger.dart';
import 'package:appwrite/appwrite.dart';
import '../services/appwrite_service.dart';
import '../widgets/city_selector.dart';
import '../services/location_service.dart';
final logger = Logger();

class AddAdScreen extends StatefulWidget {
  const AddAdScreen({super.key});

  @override
  State<AddAdScreen> createState() => _AddAdScreenState();
}

class _AddAdScreenState extends State<AddAdScreen> {
  int _step = 0;
  String? _productName;
  String? _mainCategoryId;
  String? _subCategoryId;
  Map<String, Map<String, dynamic>> _categoryLabels = {};
  final List<XFile> _photos = [];
  bool _loadingCategories = true;
  String? _description;
  String? _location;
  String? _postalCode;
  double? _price;
  // Coordonnées GPS
  double? _latitude;
  double? _longitude;
  
  // Controllers pour les champs de texte
  final TextEditingController _productNameController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();
  final TextEditingController _postalCodeController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();

  bool _isPublishing = false;

  Future<bool?> _showExitConfirmation() async {
    return showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Quitter la création d\'annonce ?'),
          content: const Text('Toutes les informations saisies seront perdues.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Annuler'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: TextButton.styleFrom(
                foregroundColor: Colors.red,
              ),
              child: const Text('Quitter'),
            ),
          ],
        );
      },
    );
  }

  @override
  void initState() {
    super.initState();
    fetchCategoryLabels().then((labels) {
      setState(() {
        _categoryLabels = labels;
        _loadingCategories = false;
      });
    });
  }

  @override
  void dispose() {
    _productNameController.dispose();
    _descriptionController.dispose();
    _locationController.dispose();
    _postalCodeController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  void _goToNextStep() {
    setState(() {
      _step++;
    });
  }

  void _goToPreviousStep() {
    setState(() {
      if (_step > 0) _step--;
    });
  }

  Future<void> _showImageSourceDialog() async {
    return showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Choisir une photo'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.photo_library, color: Color(0xFFF15A22)),
                title: const Text('Bibliothèque'),
                subtitle: const Text('Choisir depuis la galerie'),
                onTap: () async {
                  Navigator.of(context).pop();
                  await _pickImage(ImageSource.gallery);
                },
              ),
              ListTile(
                leading: const Icon(Icons.camera_alt, color: Color(0xFFF15A22)),
                title: const Text('Appareil photo'),
                subtitle: const Text('Prendre une nouvelle photo'),
                onTap: () async {
                  Navigator.of(context).pop();
                  await _pickImage(ImageSource.camera);
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

  Future<void> _pickImage(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: source,
        imageQuality: 80, // Compresser l'image pour optimiser les performances
      );
      
      if (picked != null) {
        setState(() => _photos.add(picked));
      }
    } catch (e) {
      print('Erreur lors de la sélection de l\'image: $e');
      
      String errorMessage = 'Erreur lors de la sélection de l\'image';
      
      // Messages d'erreur plus spécifiques
      if (e.toString().contains('permission')) {
        errorMessage = 'Permission refusée. Veuillez autoriser l\'accès à l\'appareil photo ou à la galerie dans les paramètres.';
      } else if (e.toString().contains('camera')) {
        errorMessage = 'Impossible d\'accéder à l\'appareil photo. Vérifiez les permissions.';
      } else if (e.toString().contains('gallery')) {
        errorMessage = 'Impossible d\'accéder à la galerie. Vérifiez les permissions.';
      }
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMessage),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 4),
          action: SnackBarAction(
            label: 'OK',
            textColor: Colors.white,
            onPressed: () {},
          ),
        ),
      );
    }
  }

  Widget _buildStep1() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Ajoutez un titre',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
        ),
        const SizedBox(height: 4),
        const Text(
          'Un titre clair et précis attire plus d’acheteurs.',
          style: TextStyle(fontSize: 14, color: Colors.grey),
        ),
        const SizedBox(height: 16),
        const Text('Titre de l\'annonce', style: TextStyle(fontWeight: FontWeight.w500, fontSize: 15)),
        const SizedBox(height: 6),
        TextField(
          controller: _productNameController,
          autofocus: true,
          decoration: InputDecoration(
            border: OutlineInputBorder(
              borderRadius: BorderRadius.all(Radius.circular(12)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.all(Radius.circular(12)),
              borderSide: BorderSide(color: Color(0xFFE0E0E0)),
            ),
          ),
          onChanged: (val) => setState(() => _productName = val.trim()),
        ),
        const SizedBox(height: 24),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: (_productName != null && _productName!.isNotEmpty)
                ? const Color(0xFFF15A22)
                : null,
            foregroundColor: Colors.white,
          ),
          onPressed: (_productName != null && _productName!.isNotEmpty)
              ? _goToNextStep
              : null,
          child: const Text('Continuer'),
        ),
      ],
    );
  }

  Widget _buildStep2() {
    // Catégories mères (parentId == null)
    final mainCategories = _categoryLabels.entries.where((e) => e.value['parentId'] == null).toList();
    logger.d('mainCategoryId: $_mainCategoryId');
    final subCategories = _categoryLabels.entries
        .where((e) {
          logger.d('cat: ${e.value['name']} | parentId: ${e.value['parentId']} | mainCategoryId: $_mainCategoryId');
          return (e.value['parentId']?.toString() ?? '') == (_mainCategoryId ?? '');
        })
        .toList();
    logger.d('Sous-catégories candidates: $subCategories');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Choisissez une catégorie',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
        ),
        const SizedBox(height: 4),
        const Text(
          'Sélectionnez la catégorie la plus adaptée pour que votre annonce soit bien référencée.',
          style: TextStyle(fontSize: 14, color: Colors.grey),
        ),
        const SizedBox(height: 16),
        const Text('Catégorie principale', style: TextStyle(fontWeight: FontWeight.w500, fontSize: 15)),
        const SizedBox(height: 6),
        DropdownButtonFormField<String>(
          value: mainCategories.any((e) => e.value['\$id'] == _mainCategoryId) ? _mainCategoryId : null,
          hint: const Text('Sélectionner une catégorie'),
          decoration: InputDecoration(
            border: OutlineInputBorder(
              borderRadius: BorderRadius.all(Radius.circular(12)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.all(Radius.circular(12)),
              borderSide: BorderSide(color: Color(0xFFE0E0E0)),
            ),
          ),
          // Pour la catégorie principale
          items: mainCategories
              .where((e) => e.value['\$id'] != null)
              .map((e) {
                logger.d(e.value); // log la structure
                return DropdownMenuItem<String>(
                  value: e.value['\$id'] as String,
                  child: Text(e.value['name']),
                );
              })
              .toList(),
          onChanged: (val) {
            setState(() {
              _mainCategoryId = val;
              _subCategoryId = null;
            });
          },
        ),
        const SizedBox(height: 16),
        const Text('Sous-catégorie', style: TextStyle(fontWeight: FontWeight.w500, fontSize: 15)),
        const SizedBox(height: 6),
        DropdownButtonFormField<String>(
          value: subCategories.any((e) => e.value['\$id'] == _subCategoryId) ? _subCategoryId : null,
          hint: const Text('Sélectionner une sous-catégorie'),
          decoration: InputDecoration(
            border: OutlineInputBorder(
              borderRadius: BorderRadius.all(Radius.circular(12)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.all(Radius.circular(12)),
              borderSide: BorderSide(color: Color(0xFFE0E0E0)),
            ),
          ),
          // Pour la sous-catégorie
          items: subCategories
              .where((e) => e.value['\$id'] != null)
              .map((e) {
                logger.d(e.value); // log la structure
                return DropdownMenuItem<String>(
                  value: e.value['\$id'] as String,
                  child: Text(e.value['name']),
                );
              })
              .toList(),
          onChanged: (val) => setState(() => _subCategoryId = val),
        ),
        const SizedBox(height: 24),
        Row(
          children: [
            const Spacer(),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: (_mainCategoryId != null && _subCategoryId != null)
                    ? const Color(0xFFF15A22)
                    : null,
                foregroundColor: Colors.white,
              ),
              onPressed: (_mainCategoryId != null && _subCategoryId != null)
                  ? _goToNextStep
                  : null,
              child: const Text('Continuer'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStep3() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Ajoutez des photos',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
        ),
        const SizedBox(height: 4),
        const Text(
          'Les photos de qualité attirent plus d\'acheteurs. Ajoutez jusqu\'à 10 photos.',
          style: TextStyle(fontSize: 14, color: Colors.grey),
        ),
        const SizedBox(height: 8),
        // Indicateur du nombre de photos
        if (_photos.isNotEmpty)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                         decoration: BoxDecoration(
               color: Color(0xFFF15A22).withValues(alpha: 0.1),
               borderRadius: BorderRadius.circular(8),
             ),
            child: Text(
              '${_photos.length} photo${_photos.length > 1 ? 's' : ''} sélectionnée${_photos.length > 1 ? 's' : ''}',
              style: TextStyle(
                color: Color(0xFFF15A22),
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, constraints) {
            final double spacing = 12;
            final double totalWidth = constraints.maxWidth;
            final double itemWidth = (totalWidth - spacing) / 2;
            return GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: 10,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: spacing,
                mainAxisSpacing: spacing,
                childAspectRatio: 1,
              ),
              itemBuilder: (context, i) {
                final hasPhoto = i < _photos.length;
                return GestureDetector(
                  onTap: () async {
                    if (!hasPhoto && _photos.length < 10) {
                      await _showImageSourceDialog();
                    }
                  },
                  child: Container(
                    width: itemWidth,
                    height: itemWidth,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Color(0xFFE0E0E0), width: 1.2),
                      boxShadow: [
                        BoxShadow(
                          color: Color.fromRGBO(0, 0, 0, 0.04),
                          blurRadius: 8,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: hasPhoto
                        ? Stack(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(14),
                                child: Image.file(
                                  File(_photos[i].path),
                                  fit: BoxFit.cover,
                                  width: double.infinity,
                                  height: double.infinity,
                                ),
                              ),
                              // Bouton de suppression
                              Positioned(
                                top: 8,
                                right: 8,
                                child: GestureDetector(
                                  onTap: () {
                                    setState(() {
                                      _photos.removeAt(i);
                                    });
                                  },
                                  child: Container(
                                    width: 24,
                                    height: 24,
                                    decoration: BoxDecoration(
                                      color: Colors.black.withValues(alpha: 0.7),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.close,
                                      size: 16,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                              // Badge "Photo de couverture" pour la première image
                              if (i == 0)
                                Positioned(
                                  top: 8,
                                  left: 8,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Color(0xFFF15A22),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Text(
                                      'Couverture',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          )
                        : Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.camera_alt_outlined, size: 38, color: Colors.black),
                              const SizedBox(height: 8),
                              Text(
                                'Photo ${i + 1}',
                                style: TextStyle(
                                  fontSize: 15,
                                  color: Colors.black87,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              if (_photos.length < 10)
                                const Text(
                                  'Ajouter',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey,
                                  ),
                                ),
                            ],
                          ),
                  ),
                );
              },
            );
          },
        ),
        const SizedBox(height: 24),
        Row(
          children: [
            const Spacer(),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: _photos.isNotEmpty ? const Color(0xFFF15A22) : null,
                foregroundColor: Colors.white,
              ),
              onPressed: _photos.isNotEmpty ? _goToNextStep : null,
              child: const Text('Continuer'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStep4() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Décrivez votre annonce',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
        ),
        const SizedBox(height: 4),
        const Text(
          'Plus la description est complète, plus vous attirez d’acheteurs.',
          style: TextStyle(fontSize: 14, color: Colors.grey),
        ),
        const SizedBox(height: 16),
        const Text('Description', style: TextStyle(fontWeight: FontWeight.w500, fontSize: 15)),
        const SizedBox(height: 6),
        TextField(
          controller: _descriptionController,
          minLines: 4,
          maxLines: 8,
          maxLength: 2000,
          decoration: InputDecoration(
            border: OutlineInputBorder(
              borderRadius: BorderRadius.all(Radius.circular(12)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.all(Radius.circular(12)),
              borderSide: BorderSide(color: Color(0xFFE0E0E0)),
            ),
            counterText: '${_descriptionController.text.length}/2000 caractères',
            counterStyle: TextStyle(
              color: _descriptionController.text.length > 1800 
                  ? Colors.orange 
                  : _descriptionController.text.length > 1900 
                      ? Colors.red 
                      : Colors.grey,
              fontSize: 12,
            ),
          ),
          onChanged: (val) {
            setState(() {
              _description = val.trim();
            });
          },
        ),
        const SizedBox(height: 24),
        Row(
          children: [
            const Spacer(),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: (_description != null && _description!.isNotEmpty)
                    ? const Color(0xFFF15A22)
                    : null,
                foregroundColor: Colors.white,
              ),
              onPressed: (_description != null && _description!.isNotEmpty)
                  ? _goToNextStep
                  : null,
              child: const Text('Continuer'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStep5() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Où se trouve votre bien ?',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
        ),
        const SizedBox(height: 4),
        const Text(
          'Indiquez la ville et le code postal pour faciliter la recherche des acheteurs.',
          style: TextStyle(fontSize: 14, color: Colors.grey),
        ),
        const SizedBox(height: 16),
        const Text('Localisation', style: TextStyle(fontWeight: FontWeight.w500, fontSize: 15)),
        const SizedBox(height: 6),
        CitySelector(
          initialValue: _location != null && _postalCode != null ? '$_location $_postalCode' : null,
                        onCitySelected: (city) {
                setState(() {
                  // Si c'est une adresse complète, utiliser la ville
                  _location = city.city.isNotEmpty ? city.city : city.name;
                  _postalCode = city.postalCode;
                  _latitude = city.latitude;
                  _longitude = city.longitude;
                });
              },
        ),

        const SizedBox(height: 24),
        Row(
          children: [
            const Spacer(),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: (_location != null && _location!.isNotEmpty && _postalCode != null && _postalCode!.isNotEmpty && _latitude != null && _longitude != null)
                    ? const Color(0xFFF15A22)
                    : null,
                foregroundColor: Colors.white,
              ),
              onPressed: (_location != null && _location!.isNotEmpty && _postalCode != null && _postalCode!.isNotEmpty && _latitude != null && _longitude != null)
                  ? _goToNextStep
                  : null,
              child: const Text('Continuer'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStep6() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Indiquez un prix',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
        ),
        const SizedBox(height: 4),
        const Text(
          'Un prix juste augmente vos chances de vendre rapidement.',
          style: TextStyle(fontSize: 14, color: Colors.grey),
        ),
        const SizedBox(height: 16),
        const Text('Prix en €', style: TextStyle(fontWeight: FontWeight.w500, fontSize: 15)),
        const SizedBox(height: 6),
        TextField(
          controller: _priceController,
          keyboardType: TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            border: OutlineInputBorder(
              borderRadius: BorderRadius.all(Radius.circular(12)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.all(Radius.circular(12)),
              borderSide: BorderSide(color: Color(0xFFE0E0E0)),
            ),
          ),
          onChanged: (val) => setState(() => _price = double.tryParse(val)),
        ),
        const SizedBox(height: 16),
        const SizedBox(height: 24),
        Row(
          children: [
            const Spacer(),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: (_price != null && _price! > 0)
                    ? const Color(0xFFF15A22)
                    : null,
                foregroundColor: Colors.white,
              ),
              onPressed: (_price != null && _price! > 0)
                  ? _saveAdToAppwrite
                  : null,
              child: const Text('Publier'),
            ),
          ],
        ),
      ],
    );
  }



  Future<List<String>> _uploadAllPhotosToAppwrite() async {
    List<String> imageUrls = [];
    
    for (int i = 0; i < _photos.length; i++) {
      try {
        final storage = AppwriteService().storage;
        final file = InputFile.fromPath(
          path: _photos[i].path,
          filename: 'photo_${DateTime.now().millisecondsSinceEpoch}_$i.jpg',
        );
        
        final result = await storage.createFile(
          bucketId: '686b8d76000a6b2b5c00',
          fileId: ID.unique(),
          file: file,
        );
        
        final url = '${AppwriteService().client.endPoint}/storage/buckets/686b8d76000a6b2b5c00/files/${result.$id}/view?project=686ac0840038d075de43';
        logger.d('URL image Appwrite $i : $url');
        imageUrls.add(url);
      } catch (e) {
        logger.e('Erreur upload image Appwrite $i: $e');
        // Continue avec les autres images même si une échoue
      }
    }
    
    return imageUrls;
  }

  Future<void> _saveAdToAppwrite() async {
    setState(() => _isPublishing = true);
    try {
      final databases = AppwriteService().databases;
      List<String> imageUrls = [];
      if (_photos.isNotEmpty) {
        imageUrls = await _uploadAllPhotosToAppwrite();
      }
      final adData = {
        'title': _productName ?? '',
        'price': _price ?? 0.0,
        'mainCategoryId': _mainCategoryId ?? '',
        'subCategoryId': _subCategoryId ?? '',
        'location': _location ?? '',
        'postalCode': _postalCode ?? '',
        'publicationDate': DateTime.now().toUtc().toIso8601String(),
        'imageUrl': imageUrls.isNotEmpty ? imageUrls[0] : 'https://picsum.photos/seed/demo/400/300', // Image principale pour compatibilité
        'imageUrls': imageUrls, // Liste de toutes les images
        'description': _description ?? '',
        'userId': 'demoUser', // à remplacer par l'id utilisateur réel si besoin
        'isActive': true,
        // Coordonnées GPS (optionnelles pour compatibilité)
        if (_latitude != null) 'latitude': _latitude,
        if (_longitude != null) 'longitude': _longitude,
      };

      await databases.createDocument(
        databaseId: '687ccdcf0000676911f1', // Remplace par ton databaseId
        collectionId: '687ccdde0031f8eda985', // Remplace par ta collectionId d'annonces
        documentId: ID.unique(),
        data: adData,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Annonce publiée !')),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur lors de la publication : $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isPublishing = false);
    }
  }

  Widget _buildProgressIndicator() {
    const totalSteps = 6;
    final progress = (_step + 0.2) / totalSteps; // Commence avec un petit pourcentage pour la première étape
    
    return Column(
      children: [
        // Barre de progression animée
        Container(
          width: double.infinity,
          height: 4,
          decoration: BoxDecoration(
            color: Colors.grey.shade200,
            borderRadius: BorderRadius.circular(2),
          ),
          child: AnimatedFractionallySizedBox(
            duration: const Duration(milliseconds: 800),
            curve: Curves.easeInOut,
            alignment: Alignment.centerLeft,
            widthFactor: progress,
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFFF15A22),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text(
          'Déposer une annonce',
          style: TextStyle(
            fontSize: 18,
            color: Colors.black,
            fontWeight: FontWeight.normal,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new),
          onPressed: () {
            if (_step > 0) {
              _goToPreviousStep();
            } else {
              Navigator.of(context).pop();
            }
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () async {
              final shouldExit = await _showExitConfirmation();
              if (shouldExit == true && mounted) {
                Navigator.of(context).pop();
              }
            },
          ),
        ],
      ),
      body: _loadingCategories
          ? const Center(child: CircularProgressIndicator())
          : GestureDetector(
              onHorizontalDragEnd: (details) {
                if (details.primaryVelocity != null && details.primaryVelocity! > 0) {
                  // Swipe vers la droite (retour)
                  if (_step > 0) {
                    _goToPreviousStep();
                  } else {
                    Navigator.of(context).pop();
                  }
                }
              },
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 16, 24, 12),
                    child: _buildProgressIndicator(),
                  ),
                  if (_isPublishing)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                  if (!_isPublishing)
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.symmetric(horizontal: 24.0),
                        child: _step == 0
                            ? _buildStep1()
                            : _step == 1
                                ? _buildStep2()
                                : _step == 2
                                    ? _buildStep3()
                                    : _step == 3
                                        ? _buildStep4()
                                        : _step == 4
                                            ? _buildStep5()
                                            : _buildStep6(),
                      ),
                    ),
                ],
              ),
            ),
    );
  }
}
