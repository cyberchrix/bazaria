import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class OnboardingScreen extends StatefulWidget {
  final VoidCallback? onFinish;
  const OnboardingScreen({super.key, this.onFinish});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _controller = PageController();
  int _currentPage = 0;

  final List<_OnboardingPage> _pages = [
    _OnboardingPage(
      image: 'assets/onboarding/onboarding_step_1.png',
      title: 'Trouvez et publiez des annonces',
      description: 'Recherchez, consultez et publiez des annonces en quelques clics sur Bazaria.',
    ),
    _OnboardingPage(
      image: 'assets/onboarding/onboarding_step_2.png',
      title: 'Discutez en toute sécurité',
      description: 'Contactez les vendeurs et acheteurs via la messagerie intégrée.',
    ),
    _OnboardingPage(
      image: 'assets/onboarding/onboarding_step_3.png',
      title: 'Ajoutez vos annonces facilement',
      description: 'Déposez une annonce avec photos, description et prix en quelques étapes.',
    ),
    _OnboardingPage(
      image: 'assets/onboarding/onboarding_step_4.png',
      title: 'Trouvez rapidement',
      description: 'Recherchez et trouvez ce que vous cherchez en quelques clics.',
    ),
  ];

  void _finish() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_seen', true);
    if (widget.onFinish != null) {
      widget.onFinish!();
    } else if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLast = _currentPage == _pages.length - 1;
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.topRight,
              child: TextButton(
                onPressed: _finish,
                child: const Text('Passer', style: TextStyle(color: Color(0xFFF15A22), fontWeight: FontWeight.bold)),
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount: _pages.length,
                onPageChanged: (i) => setState(() => _currentPage = i),
                itemBuilder: (context, i) => _pages[i],
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(_pages.length, (i) => AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 16),
                width: _currentPage == i ? 20 : 8,
                height: 8,
                decoration: BoxDecoration(
                  color: _currentPage == i ? const Color(0xFFF15A22) : Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(4),
                ),
              )),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFF15A22),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  onPressed: isLast
                      ? _finish
                      : () => _controller.nextPage(duration: const Duration(milliseconds: 400), curve: Curves.easeInOut),
                  child: Text(isLast ? 'Terminer' : 'Suivant', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OnboardingPage extends StatelessWidget {
  final String image;
  final String title;
  final String description;
  const _OnboardingPage({required this.image, required this.title, required this.description});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Expanded(
            child: Image.asset(image, fit: BoxFit.contain, height: 220),
          ),
          const SizedBox(height: 32),
          Text(
            title,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFFF15A22)),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(description, style: const TextStyle(fontSize: 16, color: Colors.black87), textAlign: TextAlign.center),
        ],
      ),
    );
  }
} 