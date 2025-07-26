import 'package:flutter/material.dart';
import '../models/ad.dart';

const List<String> productCategories = [
  'Immobilier',
  'Véhicule',
  'Mode',
  'Maison & Jardin',
  'Électronique',
];

const List<Map<String, dynamic>> productCategoriesWithIcons = [
  {
    'label': 'Immobilier',
    'icon': Icons.home,
  },
  {
    'label': 'Véhicule',
    'icon': Icons.directions_car,
  },
  {
    'label': 'Mode',
    'icon': Icons.checkroom,
  },
  {
    'label': 'Maison & Jardin',
    'icon': Icons.chair,
  },
  {
    'label': 'Électronique',
    'icon': Icons.devices,
  },
];

const List<String> adsImages = [
  'assets/ads/pub1.png',
  'assets/ads/pub2.png',
  'assets/ads/pub3.png',
];

const List<Map<String, String>> adsData = [
  {
    'image': 'assets/ads/pub1.png',
    'url': 'https://www.example.com/pub1',
  },
  {
    'image': 'assets/ads/pub2.png',
    'url': 'https://www.example.com/pub2',
  },
  {
    'image': 'assets/ads/pub3.png',
    'url': 'https://www.example.com/pub3',
  },
];

final List<Ad> recentAds = [
  Ad(
    id: '1',
    title: 'Appartement T2 centre-ville',
    price: 85000,
    mainCategoryId: 'immobilier',
    subCategoryId: 'appartement',
    location: 'Lyon',
    postalCode: '69001',
    publicationDate: DateTime.now().subtract(const Duration(days: 1)),
    imageUrl: 'https://picsum.photos/seed/1/400/300',
    description: 'Appartement lumineux, proche de toutes commodités.',
    userId: 'user1',
  ),
  Ad(
    id: '2',
    title: 'Vélo électrique neuf',
    price: 1200,
    mainCategoryId: 'electronique',
    subCategoryId: 'telephones',
    location: 'Paris',
    postalCode: '75011',
    publicationDate: DateTime.now().subtract(const Duration(hours: 5)),
    imageUrl: 'https://picsum.photos/seed/2/400/300',
    description: 'Vélo jamais servi, batterie garantie 2 ans.',
    userId: 'user2',
  ),
  Ad(
    id: '3',
    title: 'Robe été Zara',
    price: 35,
    mainCategoryId: 'mode',
    subCategoryId: 'vetements',
    location: 'Marseille',
    postalCode: '13006',
    publicationDate: DateTime.now().subtract(const Duration(days: 2)),
    imageUrl: 'https://picsum.photos/seed/3/400/300',
    description: 'Robe d\'été en parfait état.',
    userId: 'user3',
  ),
  Ad(
    id: '4',
    title: 'Canapé convertible',
    price: 250,
    mainCategoryId: 'maison_jardin',
    subCategoryId: 'meubles',
    location: 'Bordeaux',
    postalCode: '33000',
    publicationDate: DateTime.now().subtract(const Duration(hours: 10)),
    imageUrl: 'https://picsum.photos/seed/4/400/300',
    description: 'Canapé convertible en bon état.',
    userId: 'user4',
  ),
  Ad(
    id: '5',
    title: 'iPhone 13 Pro',
    price: 900,
    mainCategoryId: 'electronique',
    subCategoryId: 'telephones',
    location: 'Toulouse',
    postalCode: '31000',
    publicationDate: DateTime.now().subtract(const Duration(days: 3)),
    imageUrl: 'https://picsum.photos/seed/5/400/300',
    description: 'iPhone 13 Pro en excellent état.',
    userId: 'user5',
  ),
  Ad(
    id: '6',
    title: 'Table basse scandinave',
    price: 80,
    mainCategoryId: 'maison_jardin',
    subCategoryId: 'meubles',
    location: 'Nantes',
    postalCode: '44000',
    publicationDate: DateTime.now().subtract(const Duration(hours: 20)),
    imageUrl: 'https://picsum.photos/seed/6/400/300',
    description: 'Table basse style scandinave.',
    userId: 'user6',
  ),
];
