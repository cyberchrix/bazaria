import 'package:flutter/material.dart';
import '../widgets/criteria_form.dart';
import '../models/criterion.dart';
import '../services/criteria_service.dart';
import 'package:logger/logger.dart';

final logger = Logger();

class CriteriaScreen extends StatefulWidget {
  final String categoryId;
  final String categoryName;
  final Map<String, dynamic> initialValues;
  final Function(Map<String, dynamic>) onCriteriaSaved;

  const CriteriaScreen({
    super.key,
    required this.categoryId,
    required this.categoryName,
    required this.initialValues,
    required this.onCriteriaSaved,
  });

  @override
  State<CriteriaScreen> createState() => _CriteriaScreenState();
}

class _CriteriaScreenState extends State<CriteriaScreen> {
  Map<String, dynamic> _criteriaValues = {};
  List<String> _criteriaErrors = [];
  bool _loading = true;
  List<Criterion> _criteria = [];

  @override
  void initState() {
    super.initState();
    _criteriaValues = Map.from(widget.initialValues);
    _loadCriteria();
  }

  Future<void> _loadCriteria() async {
    try {
      logger.d('🔍 Chargement des critères pour: ${widget.categoryName} (${widget.categoryId})');
      final criteria = await CriteriaService.getCriteriaForCategory(widget.categoryId);
      
      setState(() {
        _criteria = criteria;
        _loading = false;
      });
      
      logger.d('✅ ${criteria.length} critères chargés');
    } catch (e) {
      logger.e('❌ Erreur chargement critères: $e');
      setState(() {
        _loading = false;
      });
    }
  }

  void _onCriteriaValuesChanged(Map<String, dynamic> values) {
    setState(() {
      _criteriaValues = values;
    });
  }

  void _saveAndContinue() {
    // Validation basique
    final errors = <String>[];
    
    for (final criterion in _criteria) {
      if (criterion.required && (_criteriaValues[criterion.id] == null || 
          _criteriaValues[criterion.id].toString().isEmpty)) {
        errors.add('${criterion.label} est requis');
      }
    }

    if (errors.isNotEmpty) {
      setState(() {
        _criteriaErrors = errors;
      });
      return;
    }

    // Sauvegarder et retourner
    widget.onCriteriaSaved(_criteriaValues);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Caractéristiques - ${widget.categoryName}',
          style: const TextStyle(
            fontSize: 18,
            color: Colors.black,
            fontWeight: FontWeight.normal,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new),
          onPressed: () => Navigator.of(context).pop(),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(
                color: Color(0xFFF15A22),
              ),
            )
          : Column(
              children: [
                // En-tête
                Container(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Caractéristiques spécifiques',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 20,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Ajoutez des détails pour mieux décrire votre annonce dans la catégorie "${widget.categoryName}".',
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),

                // Formulaire de critères
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: _criteria.isEmpty
                        ? const Center(
                            child: Padding(
                              padding: EdgeInsets.all(32),
                              child: Text(
                                'Aucun critère spécifique pour cette catégorie',
                                style: TextStyle(
                                  color: Colors.grey,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ),
                          )
                        : Column(
                            children: [
                              // Affichage des erreurs
                              if (_criteriaErrors.isNotEmpty) ...[
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(12),
                                  margin: const EdgeInsets.only(bottom: 16),
                                  decoration: BoxDecoration(
                                    color: Colors.red.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: Colors.red.withOpacity(0.3)),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Veuillez corriger les erreurs suivantes :',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: Colors.red,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      ..._criteriaErrors.map((error) => Padding(
                                        padding: const EdgeInsets.only(bottom: 4),
                                        child: Text(
                                          '• $error',
                                          style: const TextStyle(color: Colors.red),
                                        ),
                                      )),
                                    ],
                                  ),
                                ),
                              ],

                              // Formulaire
                              CriteriaForm(
                                categoryId: widget.categoryId,
                                initialValues: _criteriaValues,
                                onValuesChanged: _onCriteriaValuesChanged,
                                errors: _criteriaErrors.isNotEmpty ? _criteriaErrors : null,
                              ),
                            ],
                          ),
                  ),
                ),

                // Bouton de validation
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        offset: const Offset(0, -2),
                      ),
                    ],
                  ),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFF15A22),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: _saveAndContinue,
                      child: const Text(
                        'Continuer',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
} 