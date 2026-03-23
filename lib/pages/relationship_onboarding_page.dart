import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class RelationshipOnboardingPage extends StatefulWidget {
  final VoidCallback onFinished;

  const RelationshipOnboardingPage({
    super.key,
    required this.onFinished,
  });

  @override
  State<RelationshipOnboardingPage> createState() =>
      _RelationshipOnboardingPageState();
}

class _RelationshipOnboardingPageState
    extends State<RelationshipOnboardingPage> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  bool _isSaving = false;

  static const String _seenKey = 'seen_relationship_onboarding';

  final List<_OnboardingItem> _pages = const [
    _OnboardingItem(
      icon: Icons.groups_rounded,
      titleKey: 'relationship_onboarding.page1.title',
      bodyKey: 'relationship_onboarding.page1.body',
    ),
    _OnboardingItem(
      icon: Icons.favorite_border_rounded,
      titleKey: 'relationship_onboarding.page2.title',
      bodyKey: 'relationship_onboarding.page2.body',
    ),
    _OnboardingItem(
      icon: Icons.verified_user_outlined,
      titleKey: 'relationship_onboarding.page3.title',
      bodyKey: 'relationship_onboarding.page3.body',
    ),
  ];

  Future<void> _finish() async {
    if (_isSaving) return;

    setState(() => _isSaving = true);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_seenKey, true);

    if (!mounted) return;
    widget.onFinished();
  }

  void _nextPage() {
    if (_currentPage == _pages.length - 1) {
      _finish();
      return;
    }

    _pageController.nextPage(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isLastPage = _currentPage == _pages.length - 1;

    return Scaffold(
      backgroundColor: const Color(0xFFF6FAF7),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: Row(
                children: [
                  const SizedBox(width: 48),
                  Expanded(
                    child: Text(
                      'relationship_onboarding.header'.tr(),
                      textAlign: TextAlign.center,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF123C40),
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: _finish,
                    child: Text(
                      'relationship_onboarding.skip'.tr(),
                      style: const TextStyle(
                        color: Color(0xFF123C40),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: _pages.length,
                onPageChanged: (index) {
                  setState(() => _currentPage = index);
                },
                itemBuilder: (context, index) {
                  final item = _pages[index];
                  return _OnboardingSlide(item: item);
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 28),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      _pages.length,
                          (index) => AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        height: 8,
                        width: _currentPage == index ? 24 : 8,
                        decoration: BoxDecoration(
                          color: _currentPage == index
                              ? const Color(0xFF123C40)
                              : const Color(0xFF123C40).withValues(alpha: 0.22),
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isSaving ? null : _nextPage,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF123C40),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: Text(
                        isLastPage
                            ? 'relationship_onboarding.start'.tr()
                            : 'relationship_onboarding.next'.tr(),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
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

class _OnboardingSlide extends StatelessWidget {
  final _OnboardingItem item;

  const _OnboardingSlide({required this.item});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 108,
            height: 108,
            decoration: BoxDecoration(
              color: const Color(0xFF123C40).withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: Icon(
              item.icon,
              size: 48,
              color: const Color(0xFF123C40),
            ),
          ),
          const SizedBox(height: 28),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: const Color(0xFF123C40).withValues(alpha: 0.08),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 14,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              children: [
                Text(
                  item.titleKey.tr(),
                  textAlign: TextAlign.center,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF123C40),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  item.bodyKey.tr(),
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    height: 1.55,
                    color: const Color(0xFF4A5D60),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _OnboardingItem {
  final IconData icon;
  final String titleKey;
  final String bodyKey;

  const _OnboardingItem({
    required this.icon,
    required this.titleKey,
    required this.bodyKey,
  });
}