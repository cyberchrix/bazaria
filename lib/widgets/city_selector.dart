import 'package:flutter/material.dart';
import '../services/location_service.dart';

class CitySelector extends StatefulWidget {
  final Function(CityResult) onCitySelected;
  final String? initialValue;

  const CitySelector({
    super.key,
    required this.onCitySelected,
    this.initialValue,
  });

  @override
  State<CitySelector> createState() => _CitySelectorState();
}

class _CitySelectorState extends State<CitySelector> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  
  List<CityResult> _searchResults = [];
  bool _isSearching = false;
  bool _showResults = false;
  CityResult? _selectedCity;

  @override
  void initState() {
    super.initState();
    if (widget.initialValue != null) {
      _controller.text = widget.initialValue!;
    }
    
    _controller.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    final query = _controller.text.trim();
    
    if (query.length < 2) {
      setState(() {
        _searchResults = [];
        _showResults = false;
      });
      return;
    }

    _performSearch(query);
  }

  Future<void> _performSearch(String query) async {
    setState(() {
      _isSearching = true;
      _showResults = true;
    });

    try {
      final results = await LocationService.searchCities(query);
      setState(() {
        _searchResults = results;
        _isSearching = false;
      });
    } catch (e) {
      print('Erreur dans CitySelector: $e');
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
    }
  }

  void _selectCity(CityResult city) {
    setState(() {
      _selectedCity = city;
      _controller.text = city.fullAddress;
      _showResults = false;
    });
    
    widget.onCitySelected(city);
  }



  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Champ de recherche
        TextField(
          controller: _controller,
          focusNode: _focusNode,
          decoration: InputDecoration(
            hintText: 'Tapez une ville ou une adresse...',
            prefixIcon: const Icon(Icons.location_on),
            suffixIcon: _isSearching
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: Padding(
                      padding: EdgeInsets.all(8.0),
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : _controller.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _controller.clear();
                          setState(() {
                            _selectedCity = null;
                            _showResults = false;
                          });
                        },
                      )
                    : null,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          onTap: () {
            if (_searchResults.isNotEmpty) {
              setState(() {
                _showResults = true;
              });
            }
          },
        ),
        
        const SizedBox(height: 8),
        
        // Résultats de recherche
        if (_showResults && _searchResults.isNotEmpty)
          Container(
            constraints: const BoxConstraints(maxHeight: 200),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: _searchResults.length,
              itemBuilder: (context, index) {
                final city = _searchResults[index];
                return ListTile(
                  leading: Icon(
                    city.street.isNotEmpty ? Icons.home : Icons.location_city,
                    color: const Color(0xFFF15A22),
                  ),
                  title: Text(
                    city.name,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    city.street.isNotEmpty 
                        ? '${city.street}, ${city.city} ${city.postalCode}'
                        : city.postalCode,
                  ),

                  onTap: () => _selectCity(city),
                );
              },
            ),
          ),
        
        // Message si aucun résultat
        if (_showResults && _searchResults.isEmpty && !_isSearching && _controller.text.length >= 2)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Row(
              children: [
                Icon(Icons.search_off, color: Colors.grey),
                SizedBox(width: 8),
                Text(
                  'Aucune ville trouvée',
                  style: TextStyle(color: Colors.grey),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

 