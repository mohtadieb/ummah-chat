import 'package:easy_localization/easy_localization.dart';
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

  // ✅ IMPORTANT:
  // Don't call `.tr()` here (field initializer), because:
  // - it runs before build()
  // - it won't react nicely if the user changes language during runtime
  //
  // Instead store translation KEYS and translate inside build().
  final List<_OnboardingData> _pages = const [
    _OnboardingData(
      titleKey: 'onboarding_welcome_title',
      subtitleKey: 'onboarding_welcome_subtitle',
      assetPath: 'assets/images/onboarding_ummah_chat_1.png',
    ),
    _OnboardingData(
      titleKey: 'onboarding_dua_title',
      subtitleKey: 'onboarding_dua_subtitle',
      assetPath: 'assets/images/onboarding_dua_wall.png',
    ),
    _OnboardingData(
      titleKey: 'onboarding_stories_title',
      subtitleKey: 'onboarding_stories_subtitle',
      assetPath: 'assets/images/onboarding_stories_communities.png',
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
                  'Skip'.tr(),
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

                  // ✅ Translate here so it always uses the CURRENT locale
                  final title = page.titleKey.tr();
                  final subtitle = page.subtitleKey.tr();

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
                          title,
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
                          subtitle,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14,
                            height: 1.4,
                            color: colorScheme.primary.withValues(alpha: 0.80),
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
              padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 18),
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
                                : colorScheme.primary.withValues(alpha: 0.25),
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
                      _isLastPage ? 'Get started'.tr() : 'Next'.tr(),
                      style: const TextStyle(
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
  // ✅ Store translation keys, not translated strings
  final String titleKey;
  final String subtitleKey;
  final String assetPath;

  const _OnboardingData({
    required this.titleKey,
    required this.subtitleKey,
    required this.assetPath,
  });
}
