import 'package:flutter/material.dart';

class OnboardingPage extends StatefulWidget {
  final VoidCallback onFinished;

  const OnboardingPage({
    super.key,
    required this.onFinished,
  });

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  final PageController _controller = PageController();
  int _currentIndex = 0;

  final List<_OnboardingData> _pages = [
    _OnboardingData(
      title: 'Welcome to Ummah Chat',
      subtitle:
      'A calm, faith-centered space to connect with Muslims around the world.',
      assetPath: 'assets/onboarding_ummah_chat_1.png',
    ),
    _OnboardingData(
      title: 'Share duas & say Ameen',
      subtitle:
      'Write your duas on the Dua Wall and support others by saying Ameen 🤲.',
      assetPath: 'assets/onboarding_dua_wall.png',
    ),
    _OnboardingData(
      title: 'Stories, friends & communities',
      subtitle:
      'Read stories of the prophets, follow friends, and join communities that feel like home.',
      assetPath: 'assets/onboarding_stories_communities.png',
    ),
  ];

  void _goNext() {
    if (_currentIndex < _pages.length - 1) {
      _controller.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      widget.onFinished();
    }
  }

  void _skip() {
    widget.onFinished();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool get _isLastPage => _currentIndex == _pages.length - 1;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: SafeArea(
        child: Column(
          children: [
            // Skip button top-right
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: _skip,
                child: Text(
                  'Skip',
                  style: TextStyle(
                    color: colorScheme.primary.withValues(alpha: 0.8),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),

            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount: _pages.length,
                onPageChanged: (index) {
                  setState(() => _currentIndex = index);
                },
                itemBuilder: (context, index) {
                  final page = _pages[index];
                  return Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 26,
                      vertical: 10,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // IMAGE
                        SizedBox(
                          height: 260,
                          child: Image.asset(
                            page.assetPath,
                            fit: BoxFit.contain,
                          ),
                        ),
                        const SizedBox(height: 32),

                        // TITLE
                        Text(
                          page.title,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            color: colorScheme.primary,
                          ),
                        ),
                        const SizedBox(height: 12),

                        // SUBTITLE
                        Text(
                          page.subtitle,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14,
                            height: 1.4,
                            color: colorScheme.primary
                                .withValues(alpha: 0.80),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),

            const SizedBox(height: 16),

            // Dots + Next / Get started button
            Padding(
              padding:
              const EdgeInsets.symmetric(horizontal: 26, vertical: 18),
              child: Row(
                children: [
                  // Dots
                  Row(
                    children: List.generate(
                      _pages.length,
                          (index) {
                        final isActive = index == _currentIndex;
                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          margin: const EdgeInsets.only(right: 6),
                          height: 8,
                          width: isActive ? 18 : 8,
                          decoration: BoxDecoration(
                            color: isActive
                                ? colorScheme.primary
                                : colorScheme.primary
                                .withValues(alpha: 0.25),
                            borderRadius: BorderRadius.circular(999),
                          ),
                        );
                      },
                    ),
                  ),
                  const Spacer(),

                  // Next / Get started button
                  ElevatedButton(
                    onPressed: _goNext,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0F8254),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 22,
                        vertical: 10,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                    child: Text(
                      _isLastPage ? 'Get started' : 'Next',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
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

class _OnboardingData {
  final String title;
  final String subtitle;
  final String assetPath;

  _OnboardingData({
    required this.title,
    required this.subtitle,
    required this.assetPath,
  });
}
