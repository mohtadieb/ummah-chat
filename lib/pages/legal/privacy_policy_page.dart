import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

class PrivacyPolicyPage extends StatelessWidget {
  const PrivacyPolicyPage({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text('privacy.title'.tr()),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: SelectableText(
            _privacyText(),
            style: TextStyle(
              color: colorScheme.onSurface.withOpacity(0.9),
              height: 1.4,
              fontSize: 14,
            ),
          ),
        ),
      ),
    );
  }

  String _privacyText() {
    return '''
${'privacy.title'.tr()}
${'privacy.effective_date'.tr()}

${'privacy.intro'.tr()}

${'privacy.section_1.title'.tr()}
${'privacy.section_1.a.title'.tr()}
- ${'privacy.section_1.a.body'.tr()}

${'privacy.section_1.b.title'.tr()}
- ${'privacy.section_1.b.body'.tr()}

${'privacy.section_1.c.title'.tr()}
- ${'privacy.section_1.c.body'.tr()}

${'privacy.section_1.d.title'.tr()}
- ${'privacy.section_1.d.body'.tr()}

${'privacy.section_2.title'.tr()}
- ${'privacy.section_2.bullets.1'.tr()}
- ${'privacy.section_2.bullets.2'.tr()}
- ${'privacy.section_2.bullets.3'.tr()}
- ${'privacy.section_2.bullets.4'.tr()}
- ${'privacy.section_2.bullets.5'.tr()}
- ${'privacy.section_2.bullets.6'.tr()}

${'privacy.section_3.title'.tr()}
- ${'privacy.section_3.bullets.1'.tr()}
- ${'privacy.section_3.bullets.2'.tr()}
- ${'privacy.section_3.bullets.3'.tr()}
- ${'privacy.section_3.bullets.4'.tr()}

${'privacy.section_4.title'.tr()}
${'privacy.section_4.body'.tr()}

${'privacy.section_5.title'.tr()}
${'privacy.section_5.body'.tr()}

${'privacy.section_6.title'.tr()}
${'privacy.section_6.body'.tr()}

${'privacy.section_7.title'.tr()}
${'privacy.section_7.body'.tr()}

${'privacy.section_8.title'.tr()}
${'privacy.section_8.body'.tr()}

${'privacy.section_9.title'.tr()}
${'privacy.section_9.body'.tr()}

${'privacy.section_10.title'.tr()}
${'privacy.section_10.body'.tr()}
''';
  }
}
