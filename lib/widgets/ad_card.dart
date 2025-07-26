import 'package:flutter/material.dart';
import 'package:logger/logger.dart';
import '../models/ad.dart';
import '../theme/app_theme.dart';
import '../screens/home_screen.dart';
import '../services/favorites_service.dart';

final logger = Logger();

class AdCard extends StatefulWidget {
  final Ad ad;
  final int index;
  final VoidCallback onTap;
  final Map<String, Map<String, dynamic>> categoryLabels;
  final VoidCallback? onFavoriteChanged;
  
  const AdCard({
    super.key,
    required this.ad,
    required this.index,
    required this.onTap,
    required this.categoryLabels,
    this.onFavoriteChanged,
  });

  @override
  State<AdCard> createState() => _AdCardState();
}

class _AdCardState extends State<AdCard> {
  bool isFavorite = false;

  @override
  void initState() {
    super.initState();
    _checkFavoriteStatus();
  }

  Future<void> _checkFavoriteStatus() async {
    final favorite = await FavoritesService.isFavorite(widget.ad.id);
    if (mounted) {
      setState(() {
        isFavorite = favorite;
      });
    }
  }

  Widget _imagePlaceholder() {
    return Container(
      height: 120,
      width: double.infinity,
      color: Colors.grey.shade200,
      child: const Icon(Icons.image, size: 40, color: Colors.black),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ad = widget.ad;
    final labels = widget.categoryLabels;
    logger.d('Annonce ${ad.id}: subCategoryId = ${ad.subCategoryId}, labels disponibles = ${labels.keys.toList()}');
    logger.d('Label trouvé pour ${ad.subCategoryId}: ${labels[ad.subCategoryId]}');
    
    return GestureDetector(
      onTap: widget.onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Color.fromRGBO(128, 128, 128, 0.08),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Product image with favorite icon
            Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    ad.imageUrl,
                    height: 120,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return Container(
                        height: 120,
                        width: double.infinity,
                        color: Colors.grey.shade200,
                        child: const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              SizedBox(
                                width: 32,
                                height: 32,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                    errorBuilder: (context, error, stackTrace) => _imagePlaceholder(),
                  ),
                ),
                Positioned(
                  top: 4,
                  right: 4,
                  child: GestureDetector(
                    onTap: () async {
                      final success = await FavoritesService.toggleFavorite(widget.ad.id);
                      if (success && mounted) {
                        setState(() {
                          isFavorite = !isFavorite;
                        });
                        
                        // Notifier le parent du changement de favoris
                        widget.onFavoriteChanged?.call();
                      }
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Color.fromRGBO(0, 0, 0, 0.12),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.all(4),
                      child: Icon(
                        isFavorite ? Icons.favorite : Icons.favorite_border,
                        size: 20,
                        color: Color(0xFFF15A22),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    ad.title,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 1),
                  Text(
                    '${ad.price.toStringAsFixed(0)} €',
                    style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primaryColor, fontSize: 12),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    labels[ad.subCategoryId]?['name'] ?? 'Catégorie: ${ad.subCategoryId}',
                    style: TextStyle(fontSize: 10, color: AppTheme.primaryColor, fontWeight: FontWeight.w600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 1),
                  Text(
                    '${ad.location} (${ad.postalCode})',
                    style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 1),
                  Text(
                    formatDate(ad.publicationDate),
                    style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
