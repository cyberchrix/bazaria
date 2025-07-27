import 'package:flutter/material.dart';
import 'package:appwrite/appwrite.dart' as appw;
import '../services/appwrite_service.dart';
import 'dart:async';

class PerformanceTestWidget extends StatefulWidget {
  const PerformanceTestWidget({super.key});

  @override
  State<PerformanceTestWidget> createState() => _PerformanceTestWidgetState();
}

class _PerformanceTestWidgetState extends State<PerformanceTestWidget> {
  final List<TestResult> _results = [];
  bool _isRunning = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tests de Performance'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Bouton pour lancer les tests
            ElevatedButton.icon(
              onPressed: _isRunning ? null : _runAllTests,
              icon: _isRunning 
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.play_arrow),
              label: Text(_isRunning ? 'Tests en cours...' : 'Lancer les tests'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              ),
            ),
            
            const SizedBox(height: 20),
            
            // Titre des résultats
            const Text(
              'Résultats des Tests',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            
            const SizedBox(height: 10),
            
            // Liste des résultats
            Expanded(
              child: _results.isEmpty
                ? const Center(
                    child: Text(
                      'Aucun test exécuté',
                      style: TextStyle(
                        color: Colors.grey,
                        fontSize: 16,
                      ),
                    ),
                  )
                : ListView.builder(
                    itemCount: _results.length,
                    itemBuilder: (context, index) {
                      final result = _results[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: Icon(
                            result.success ? Icons.check_circle : Icons.error,
                            color: result.success ? Colors.green : Colors.red,
                          ),
                          title: Text(
                            result.testName,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Durée: ${result.duration}ms'),
                              if (result.details.isNotEmpty)
                                Text(
                                  result.details,
                                  style: const TextStyle(fontSize: 12),
                                ),
                            ],
                          ),
                          trailing: _getPerformanceIndicator(result.duration),
                        ),
                      );
                    },
                  ),
            ),
            
            // Résumé
            if (_results.isNotEmpty) ...[
              const Divider(),
              _buildSummary(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _getPerformanceIndicator(int duration) {
    Color color;
    String label;
    
    if (duration < 200) {
      color = Colors.green;
      label = 'Excellent';
    } else if (duration < 500) {
      color = Colors.orange;
      label = 'Bon';
    } else if (duration < 1000) {
      color = Colors.red;
      label = 'Lent';
    } else {
      color = Colors.red[900]!;
      label = 'Très lent';
    }
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildSummary() {
    if (_results.isEmpty) return const SizedBox.shrink();
    
    final successfulTests = _results.where((r) => r.success).length;
    final totalTests = _results.length;
    final avgDuration = _results.map((r) => r.duration).reduce((a, b) => a + b) / totalTests;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Résumé',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.grey[700],
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _buildSummaryCard(
                'Tests réussis',
                '$successfulTests/$totalTests',
                Colors.green,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildSummaryCard(
                'Durée moyenne',
                '${avgDuration.round()}ms',
                Colors.blue,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSummaryCard(String title, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _runAllTests() async {
    setState(() {
      _isRunning = true;
      _results.clear();
    });

    try {
      // Test 1: Connexion Appwrite
      await _runTest('Connexion Appwrite', _testAppwriteConnection);
      
      // Test 2: Récupération des catégories
      await _runTest('Récupération catégories', _testCategoriesFetch);
      
      // Test 3: Récupération des annonces récentes
      await _runTest('Annonces récentes (10)', _testRecentAds);
      
      // Test 4: Récupération de plus d'annonces
      await _runTest('Annonces récentes (50)', _testMoreAds);
      
      // Test 5: Recherche textuelle
      await _runTest('Recherche textuelle', _testTextSearch);
      
      // Test 6: Filtrage par prix
      await _runTest('Filtrage par prix', _testPriceFilter);
      
    } catch (e) {
      _addResult(TestResult(
        testName: 'Erreur générale',
        duration: 0,
        success: false,
        details: e.toString(),
      ));
    } finally {
      setState(() {
        _isRunning = false;
      });
    }
  }

  Future<void> _runTest(String testName, Future<String> Function() testFunction) async {
    final stopwatch = Stopwatch()..start();
    
    try {
      final details = await testFunction();
      stopwatch.stop();
      
      _addResult(TestResult(
        testName: testName,
        duration: stopwatch.elapsedMilliseconds,
        success: true,
        details: details,
      ));
    } catch (e) {
      stopwatch.stop();
      _addResult(TestResult(
        testName: testName,
        duration: stopwatch.elapsedMilliseconds,
        success: false,
        details: e.toString(),
      ));
    }
  }

  void _addResult(TestResult result) {
    setState(() {
      _results.add(result);
    });
  }

  // Tests spécifiques
  Future<String> _testAppwriteConnection() async {
    try {
      final databases = AppwriteService().databases;
      // Test simple de connexion en récupérant un document
      await databases.listDocuments(
        databaseId: '687ccdcf0000676911f1',
        collectionId: '687ce22e003b2c89f5b8',
        queries: [appw.Query.limit(1)],
      );
      return 'Connexion réussie';
    } catch (e) {
      throw Exception('Erreur de connexion: $e');
    }
  }

  Future<String> _testCategoriesFetch() async {
    try {
      final databases = AppwriteService().databases;
      final result = await databases.listDocuments(
        databaseId: '687ccdcf0000676911f1',
        collectionId: '687ce22e003b2c89f5b8',
        queries: [
          appw.Query.orderAsc('order'),
        ],
      );
      return '${result.documents.length} catégories récupérées';
    } catch (e) {
      throw Exception('Erreur lors de la récupération des catégories: $e');
    }
  }

  Future<String> _testRecentAds() async {
    try {
      final databases = AppwriteService().databases;
      final result = await databases.listDocuments(
        databaseId: '687ccdcf0000676911f1',
        collectionId: '687ccdde0031f8eda985',
        queries: [
          appw.Query.equal('isActive', true),
          appw.Query.orderDesc('publicationDate'),
          appw.Query.limit(10),
        ],
      );
      return '${result.documents.length} annonces récupérées';
    } catch (e) {
      throw Exception('Erreur lors de la récupération des annonces: $e');
    }
  }

  Future<String> _testMoreAds() async {
    try {
      final databases = AppwriteService().databases;
      final result = await databases.listDocuments(
        databaseId: '687ccdcf0000676911f1',
        collectionId: '687ccdde0031f8eda985',
        queries: [
          appw.Query.equal('isActive', true),
          appw.Query.orderDesc('publicationDate'),
          appw.Query.limit(50),
        ],
      );
      return '${result.documents.length} annonces récupérées';
    } catch (e) {
      throw Exception('Erreur lors de la récupération des annonces: $e');
    }
  }

  Future<String> _testTextSearch() async {
    try {
      final databases = AppwriteService().databases;
      final result = await databases.listDocuments(
        databaseId: '687ccdcf0000676911f1',
        collectionId: '687ccdde0031f8eda985',
        queries: [
          appw.Query.search('title', 'Samsung'),
          appw.Query.equal('isActive', true),
          appw.Query.limit(10),
        ],
      );
      return '${result.documents.length} résultats pour "Samsung"';
    } catch (e) {
      throw Exception('Erreur lors de la recherche: $e');
    }
  }

  Future<String> _testPriceFilter() async {
    try {
      final databases = AppwriteService().databases;
      final result = await databases.listDocuments(
        databaseId: '687ccdcf0000676911f1',
        collectionId: '687ccdde0031f8eda985',
        queries: [
          appw.Query.greaterThanEqual('price', 100),
          appw.Query.lessThanEqual('price', 1000),
          appw.Query.equal('isActive', true),
          appw.Query.limit(10),
        ],
      );
      return '${result.documents.length} annonces entre 100€ et 1000€';
    } catch (e) {
      throw Exception('Erreur lors du filtrage: $e');
    }
  }
}

class TestResult {
  final String testName;
  final int duration;
  final bool success;
  final String details;

  TestResult({
    required this.testName,
    required this.duration,
    required this.success,
    required this.details,
  });
} 