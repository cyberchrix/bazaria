import 'package:flutter/material.dart';
import '../models/criterion.dart';
import '../services/criteria_service.dart';
import 'package:logger/logger.dart';

final logger = Logger();

class CriteriaForm extends StatefulWidget {
  final String categoryId;
  final Map<String, dynamic> initialValues;
  final Function(Map<String, dynamic>) onValuesChanged;
  final List<String>? errors;

  const CriteriaForm({
    super.key,
    required this.categoryId,
    required this.initialValues,
    required this.onValuesChanged,
    this.errors,
  });

  @override
  State<CriteriaForm> createState() => _CriteriaFormState();
}

class _CriteriaFormState extends State<CriteriaForm> {
  List<Criterion> _allCriteria = [];
  List<Criterion> _visibleCriteria = [];
  Map<String, dynamic> _values = {};
  final Map<String, TextEditingController> _controllers = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _values = Map.from(widget.initialValues);
    _loadCriteria();
  }

  @override
  void dispose() {
    // Nettoyer les contrôleurs
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    _controllers.clear();
    super.dispose();
  }

  Future<void> _loadCriteria() async {
    try {
      logger.d('🔍 Chargement des critères pour la catégorie: ${widget.categoryId}');
      final criteria = await CriteriaService.getCriteriaForCategory(widget.categoryId);
      logger.d('📋 ${criteria.length} critères trouvés pour ${widget.categoryId}');
      
      // Nettoyer les anciens contrôleurs
      for (final controller in _controllers.values) {
        controller.dispose();
      }
      _controllers.clear();
      
      setState(() {
        _allCriteria = criteria;
        _visibleCriteria = CriteriaService.getVisibleCriteria(criteria, _values);
        _loading = false;
      });
      
      logger.d('✅ Critères chargés avec succès. Visibles: ${_visibleCriteria.length}');
    } catch (e) {
      logger.e('❌ Erreur lors du chargement des critères: $e');
      setState(() {
        _loading = false;
      });
    }
  }

  void _updateValue(String criterionId, dynamic value) {
    setState(() {
      _values[criterionId] = value;
      
      // Recalculer les critères visibles
      _visibleCriteria = CriteriaService.getVisibleCriteria(_allCriteria, _values);
      
      // Nettoyer les valeurs des critères qui ne sont plus visibles
      final visibleIds = _visibleCriteria.map((c) => c.id).toSet();
      _values.removeWhere((key, value) => !visibleIds.contains(key));
    });

    widget.onValuesChanged(_values);
  }

  Widget _buildCriterionField(Criterion criterion) {
    final currentValue = _values[criterion.id];
    final hasError = widget.errors?.any((error) => error.contains(criterion.label)) ?? false;

    switch (criterion.type) {
      case CriterionType.string:
        return _buildTextField(criterion, currentValue, hasError);
        
      case CriterionType.number:
        return _buildNumberField(criterion, currentValue, hasError);
        
      case CriterionType.range:
        return _buildRangeField(criterion, currentValue, hasError);
        
      case CriterionType.select:
        return _buildSelectField(criterion, currentValue, hasError);
        
      case CriterionType.boolean:
        return _buildBooleanField(criterion, currentValue, hasError);
        
      default:
        return _buildTextField(criterion, currentValue, hasError);
    }
  }

  Widget _buildTextField(Criterion criterion, dynamic currentValue, bool hasError) {
    // Créer ou récupérer le contrôleur pour ce critère
    if (!_controllers.containsKey(criterion.id)) {
      _controllers[criterion.id] = TextEditingController(text: currentValue?.toString() ?? '');
    } else {
      // Mettre à jour le texte si la valeur a changé
      final controller = _controllers[criterion.id]!;
      if (controller.text != (currentValue?.toString() ?? '')) {
        controller.text = currentValue?.toString() ?? '';
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          criterion.label,
          style: TextStyle(
            fontWeight: FontWeight.w500,
            color: hasError ? Colors.red : null,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _controllers[criterion.id]!,
          decoration: InputDecoration(
            hintText: criterion.placeholder ?? 'Saisissez ${criterion.label.toLowerCase()}',
            suffixText: criterion.unit,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            errorBorder: hasError ? OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Colors.red),
            ) : null,
          ),
          onChanged: (value) => _updateValue(criterion.id, value.isEmpty ? null : value),
        ),
        if (hasError) ...[
          const SizedBox(height: 4),
          Text(
            widget.errors!.firstWhere((error) => error.contains(criterion.label)),
            style: const TextStyle(color: Colors.red, fontSize: 12),
          ),
        ],
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildNumberField(Criterion criterion, dynamic currentValue, bool hasError) {
    // Créer ou récupérer le contrôleur pour ce critère
    if (!_controllers.containsKey(criterion.id)) {
      _controllers[criterion.id] = TextEditingController(text: currentValue?.toString() ?? '');
    } else {
      // Mettre à jour le texte si la valeur a changé
      final controller = _controllers[criterion.id]!;
      if (controller.text != (currentValue?.toString() ?? '')) {
        controller.text = currentValue?.toString() ?? '';
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          criterion.label,
          style: TextStyle(
            fontWeight: FontWeight.w500,
            color: hasError ? Colors.red : null,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _controllers[criterion.id]!,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            hintText: criterion.placeholder ?? 'Saisissez ${criterion.label.toLowerCase()}',
            suffixText: criterion.unit,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            errorBorder: hasError ? OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Colors.red),
            ) : null,
          ),
          onChanged: (value) {
            if (value.isEmpty) {
              _updateValue(criterion.id, null);
              return;
            }
            
            final numValue = double.tryParse(value);
            if (numValue != null) {
              // On accepte la valeur même si elle dépasse les limites pendant la saisie
              // La validation finale se fera lors de la soumission du formulaire
              _updateValue(criterion.id, numValue);
            } else {
              logger.w('⚠️ Valeur non numérique: $value');
            }
          },
        ),
        if (criterion.minValue != null || criterion.maxValue != null) ...[
          const SizedBox(height: 4),
          Text(
            '${criterion.minValue != null ? 'Min: ${criterion.minValue}' : ''}${criterion.minValue != null && criterion.maxValue != null ? ' - ' : ''}${criterion.maxValue != null ? 'Max: ${criterion.maxValue}' : ''}${criterion.unit != null ? ' ${criterion.unit}' : ''}',
            style: const TextStyle(
              color: Colors.grey,
              fontSize: 12,
            ),
          ),
        ],
        if (hasError) ...[
          const SizedBox(height: 4),
          Text(
            widget.errors!.firstWhere((error) => error.contains(criterion.label)),
            style: const TextStyle(color: Colors.red, fontSize: 12),
          ),
        ],
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildRangeField(Criterion criterion, dynamic currentValue, bool hasError) {
    double minValue = criterion.minValue ?? 0.0;
    double maxValue = criterion.maxValue ?? 100.0;
    double currentRangeValue = currentValue?.toDouble() ?? minValue;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              criterion.label,
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: hasError ? Colors.red : null,
              ),
            ),
            Text(
              '${currentRangeValue.toInt()}${criterion.unit ?? ''}',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Color(0xFFF15A22),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Slider(
          value: currentRangeValue,
          min: minValue,
          max: maxValue,
          divisions: (maxValue - minValue).toInt(),
          activeColor: const Color(0xFFF15A22),
          onChanged: (value) {
            setState(() {
              _updateValue(criterion.id, value);
            });
          },
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('${minValue.toInt()}${criterion.unit ?? ''}'),
            Text('${maxValue.toInt()}${criterion.unit ?? ''}'),
          ],
        ),
        if (hasError) ...[
          const SizedBox(height: 4),
          Text(
            widget.errors!.firstWhere((error) => error.contains(criterion.label)),
            style: const TextStyle(color: Colors.red, fontSize: 12),
          ),
        ],
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildSelectField(Criterion criterion, dynamic currentValue, bool hasError) {
    // Obtenir les options en fonction des valeurs parentes
    final options = criterion.getOptionsForParentValue(
      criterion.dependsOn != null ? _values[criterion.dependsOn]?.toString() : null
    ) ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          criterion.label,
          style: TextStyle(
            fontWeight: FontWeight.w500,
            color: hasError ? Colors.red : null,
          ),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: currentValue?.toString(),
          decoration: InputDecoration(
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            errorBorder: hasError ? OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Colors.red),
            ) : null,
          ),
          items: [
            const DropdownMenuItem<String>(
              value: null,
              child: Text('Sélectionnez une option'),
            ),
            ...options.map((option) => DropdownMenuItem<String>(
              value: option,
              child: Text(option),
            )),
          ],
          onChanged: (value) => _updateValue(criterion.id, value),
        ),
        if (hasError) ...[
          const SizedBox(height: 4),
          Text(
            widget.errors!.firstWhere((error) => error.contains(criterion.label)),
            style: const TextStyle(color: Colors.red, fontSize: 12),
          ),
        ],
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildBooleanField(Criterion criterion, dynamic currentValue, bool hasError) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Checkbox(
              value: currentValue ?? false,
              activeColor: const Color(0xFFF15A22),
              onChanged: (value) => _updateValue(criterion.id, value),
            ),
            Expanded(
              child: Text(
                criterion.label,
                style: TextStyle(
                  fontWeight: FontWeight.w500,
                  color: hasError ? Colors.red : null,
                ),
              ),
            ),
          ],
        ),
        if (hasError) ...[
          const SizedBox(height: 4),
          Text(
            widget.errors!.firstWhere((error) => error.contains(criterion.label)),
            style: const TextStyle(color: Colors.red, fontSize: 12),
          ),
        ],
        const SizedBox(height: 16),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(
          color: Color(0xFFF15A22),
        ),
      );
    }

    if (_visibleCriteria.isEmpty) {
      return const Center(
        child: Text(
          'Aucun critère spécifique pour cette catégorie',
          style: TextStyle(
            color: Colors.grey,
            fontStyle: FontStyle.italic,
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Caractéristiques',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        ..._visibleCriteria.map(_buildCriterionField),
      ],
    );
  }
} 