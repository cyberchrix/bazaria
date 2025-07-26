import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';

class LocationService {
  // Cache pour les résultats de recherche
  static final Map<String, List<CityResult>> _searchCache = {};

  /// Test de l'API Google Geocoding
  static Future<bool> testGoogleAPI() async {
    try {
      print('🧪 Test de l\'API Google Geocoding...');
      List<Location> locations = await locationFromAddress('Paris');
      print('✅ API Google fonctionne ! ${locations.length} résultats trouvés');
      return true;
    } catch (e) {
      print('❌ Erreur API Google: $e');
      return false;
    }
  }

  /// Recherche Google Maps pour villes et adresses
  static Future<List<CityResult>> searchTest(String query) async {
    print('🔍 Recherche Google pour: "$query"');
    try {
      // Recherche normale avec Google
      List<Location> locations = await locationFromAddress(query);
      print('📍 ${locations.length} résultats Google trouvés');
      
      List<CityResult> results = [];
      Set<String> addedCities = {}; // Pour éviter les doublons de villes
      
      for (Location location in locations.take(10)) {
        try {
          List<Placemark> placemarks = await placemarkFromCoordinates(
            location.latitude,
            location.longitude,
          );
          
          if (placemarks.isNotEmpty) {
            Placemark placemark = placemarks.first;
            
            String street = placemark.street ?? '';
            String cityName = placemark.locality ?? placemark.subAdministrativeArea ?? '';
            String postalCode = placemark.postalCode ?? '';
            String country = placemark.country ?? '';
            
            // Prioriser les villes (sans rue spécifique)
            if (cityName.isNotEmpty && street.isEmpty) {
              String cityKey = '${cityName}_$postalCode';
              if (!addedCities.contains(cityKey)) {
                addedCities.add(cityKey);
                
                results.add(CityResult(
                  name: cityName,
                  postalCode: postalCode,
                  latitude: location.latitude,
                  longitude: location.longitude,
                  fullAddress: '$cityName $postalCode',
                  street: '',
                  city: cityName,
                  country: country,
                ));
              }
            }
            // Ajouter aussi les adresses pour les traiter plus tard
            else if (street.isNotEmpty && cityName.isNotEmpty) {
              String fullAddress = '$street, $cityName $postalCode'.trim();
              
              results.add(CityResult(
                name: street,
                postalCode: postalCode,
                latitude: location.latitude,
                longitude: location.longitude,
                fullAddress: fullAddress,
                street: street,
                city: cityName,
                country: country,
              ));
            }
          }
        } catch (e) {
          print('Erreur placemark: $e');
        }
      }
      
      // Si on n'a pas trouvé de villes, essayer une recherche plus spécifique
      if (results.where((r) => r.street.isEmpty).isEmpty) {
        print('🔄 Aucune ville trouvée, recherche alternative...');
        try {
          // Recherche avec "ville" pour forcer les résultats de ville
          List<Location> cityLocations = await locationFromAddress('$query, France');
          
          // Si c'est Paris, essayer une recherche encore plus spécifique
          if (query.toLowerCase() == 'paris' && cityLocations.isEmpty) {
            print('🗼 Recherche spéciale pour Paris...');
            cityLocations = await locationFromAddress('Paris, Île-de-France, France');
          }
          
          for (Location location in cityLocations.take(5)) {
            List<Placemark> placemarks = await placemarkFromCoordinates(
              location.latitude,
              location.longitude,
            );
            
            if (placemarks.isNotEmpty) {
              Placemark placemark = placemarks.first;
              String cityName = placemark.locality ?? placemark.subAdministrativeArea ?? '';
              String postalCode = placemark.postalCode ?? '';
              String country = placemark.country ?? '';
              
              if (cityName.isNotEmpty) {
                String cityKey = '${cityName}_$postalCode';
                if (!addedCities.contains(cityKey)) {
                  addedCities.add(cityKey);
                  
                  results.add(CityResult(
                    name: cityName,
                    postalCode: postalCode,
                    latitude: location.latitude,
                    longitude: location.longitude,
                    fullAddress: '$cityName $postalCode',
                    street: '',
                    city: cityName,
                    country: country,
                  ));
                }
              }
            }
          }
        } catch (e) {
          print('Erreur recherche alternative: $e');
        }
      }
      
      // Si toujours pas de villes, alors seulement ajouter des adresses
      if (results.where((r) => r.street.isEmpty).isEmpty) {
        print('⚠️ Aucune ville trouvée, ajout d\'adresses...');
        for (Location location in locations.take(5)) {
          try {
            List<Placemark> placemarks = await placemarkFromCoordinates(
              location.latitude,
              location.longitude,
            );
            
            if (placemarks.isNotEmpty) {
              Placemark placemark = placemarks.first;
              String street = placemark.street ?? '';
              String cityName = placemark.locality ?? placemark.subAdministrativeArea ?? '';
              String postalCode = placemark.postalCode ?? '';
              String country = placemark.country ?? '';
              
              if (street.isNotEmpty && cityName.isNotEmpty) {
                String fullAddress = '$street, $cityName $postalCode'.trim();
                
                results.add(CityResult(
                  name: street,
                  postalCode: postalCode,
                  latitude: location.latitude,
                  longitude: location.longitude,
                  fullAddress: fullAddress,
                  street: street,
                  city: cityName,
                  country: country,
                ));
              }
            }
          } catch (e) {
            print('Erreur placemark pour adresse: $e');
          }
        }
      }
      
      // Trier les résultats : villes d'abord, puis adresses
      List<CityResult> finalResults = [];
      
      // Ajouter d'abord les villes (sans rue)
      finalResults.addAll(results.where((r) => r.street.isEmpty).take(5));
      
      // Si on a moins de 3 résultats, ajouter quelques adresses
      if (finalResults.length < 3) {
        finalResults.addAll(results.where((r) => r.street.isNotEmpty).take(3 - finalResults.length));
      }
      
      print('🏙️ ${results.where((r) => r.street.isEmpty).length} villes trouvées');
      print('📍 ${results.where((r) => r.street.isNotEmpty).length} adresses trouvées');
      print('📋 ${finalResults.length} résultats finaux');
      
      return finalResults;
    } catch (e) {
      print('❌ Erreur recherche Google: $e');
      return [];
    }
  }

  /// Recherche de villes et adresses avec autocomplétion
  static Future<List<CityResult>> searchCities(String query) async {
    if (query.length < 2) return [];

    // Vérifier le cache
    if (_searchCache.containsKey(query)) {
      print('📦 Résultats depuis le cache pour: "$query"');
      return _searchCache[query]!;
    }

    print('🔍 Recherche Google pour: "$query"');
    
    try {
      List<CityResult> results = await searchTest(query);
      
      if (results.isNotEmpty) {
        print('✅ ${results.length} résultats Google trouvés');
        _searchCache[query] = results;
        return results;
      } else {
        print('⚠️ Aucun résultat trouvé pour: "$query"');
        return [];
      }
    } catch (e) {
      print('❌ Erreur lors de la recherche Google: $e');
      return [];
    }
  }



  /// Obtenir les coordonnées GPS d'une ville
  static Future<Location?> getCityCoordinates(String cityName, String postalCode) async {
    try {
      String address = '$cityName $postalCode';
      List<Location> locations = await locationFromAddress(address);
      
      if (locations.isNotEmpty) {
        return locations.first;
      }
      return null;
    } catch (e) {
      print('Erreur lors de la récupération des coordonnées: $e');
      return null;
    }
  }

  /// Obtenir la position actuelle de l'utilisateur
  static Future<Position?> getCurrentLocation() async {
    try {
      // Vérifier les permissions
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          return null;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        return null;
      }

      return await Geolocator.getCurrentPosition();
    } catch (e) {
      print('Erreur lors de la récupération de la position: $e');
      return null;
    }
  }

  /// Vider le cache
  static void clearCache() {
    _searchCache.clear();
  }
}

class CityResult {
  final String name;
  final String postalCode;
  final double latitude;
  final double longitude;
  final String fullAddress;
  final String street;
  final String city;
  final String country;

  CityResult({
    required this.name,
    required this.postalCode,
    required this.latitude,
    required this.longitude,
    required this.fullAddress,
    this.street = '',
    this.city = '',
    this.country = '',
  });

  @override
  String toString() {
    return fullAddress;
  }
} 