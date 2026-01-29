import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

class TermsOfUsePage extends StatelessWidget {
  const TermsOfUsePage({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text('terms.title'.tr()),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: SelectableText(
            _termsText(),
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

  String _termsText() {
    return '''
${'terms.title'.tr()}
${'terms.effective_date'.tr()}

${'terms.intro'.tr()}

${'terms.section_1.title'.tr()}
${'terms.section_1.body'.tr()}

${'terms.section_2.title'.tr()}
${'terms.section_2.body'.tr()}

${'terms.section_3.title'.tr()}
${'terms.section_3.body'.tr()}
- ${'terms.section_3.bullets.1'.tr()}
- ${'terms.section_3.bullets.2'.tr()}
- ${'terms.section_3.bullets.3'.tr()}
- ${'terms.section_3.bullets.4'.tr()}

${'terms.section_4.title'.tr()}
${'terms.section_4.body'.tr()}

${'terms.section_5.title'.tr()}
${'terms.section_5.body'.tr()}

${'terms.section_6.title'.tr()}
${'terms.section_6.body'.tr()}

${'terms.section_7.title'.tr()}
${'terms.section_7.body'.tr()}

${'terms.section_8.title'.tr()}
${'terms.section_8.body'.tr()}

${'terms.section_9.title'.tr()}
${'terms.section_9.body'.tr()}

${'terms.section_10.title'.tr()}
${'terms.section_10.body'.tr()}

${'terms.section_11.title'.tr()}
${'terms.section_11.body'.tr()}
''';
  }
}
