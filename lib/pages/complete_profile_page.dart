// lib/pages/complete_profile_page.dart
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../components/my_button.dart';
import '../components/my_text_field.dart';
import '../services/database/database_provider.dart';

class CompleteProfilePage extends StatefulWidget {
  final VoidCallback? onCompleted;

  const CompleteProfilePage({
    super.key,
    this.onCompleted,
  });

  @override
  State<CompleteProfilePage> createState() => _CompleteProfilePageState();
}

class _CompleteProfilePageState extends State<CompleteProfilePage> {
  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  final TextEditingController _usernameController = TextEditingController();

  String? _selectedCountry;
  String? _selectedGender; // 'male' | 'female'

  bool _saving = false;

  static final List<String> _countries = [
    'Netherlands'.tr(),
    'Belgium'.tr(),
    'Germany'.tr(),
    'France'.tr(),
    'United Kingdom'.tr(),
    'Spain'.tr(),
    'Italy'.tr(),
    'Sweden'.tr(),
    'Norway'.tr(),
    'Denmark'.tr(),
    'Finland'.tr(),
    'Turkey'.tr(),
    'Morocco'.tr(),
    'Algeria'.tr(),
    'Tunisia'.tr(),
    'Egypt'.tr(),
    'Saudi Arabia'.tr(),
    'United Arab Emirates'.tr(),
    'Qatar'.tr(),
    'Kuwait'.tr(),
    'Jordan'.tr(),
    'Lebanon'.tr(),
    'Pakistan'.tr(),
    'India'.tr(),
    'Bangladesh'.tr(),
    'Indonesia'.tr(),
    'Malaysia'.tr(),
    'United States'.tr(),
    'Canada'.tr(),
    'Australia'.tr(),
    'Other'.tr(),
  ];

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _usernameController.dispose();
    super.dispose();
  }

  String _normalizeUsername(String input) {
    var value = input.trim().toLowerCase();

    if (value.startsWith('@')) {
      value = value.substring(1);
    }

    value = value.replaceAll(RegExp(r'\s+'), '');
    return value;
  }

  Future<void> _saveProfile() async {
    FocusScope.of(context).unfocus();

    final firstName = _firstNameController.text.trim();
    final lastName = _lastNameController.text.trim();
    final username = _normalizeUsername(_usernameController.text);
    final country = _selectedCountry?.trim() ?? '';
    final gender = _selectedGender;

    if (firstName.isEmpty ||
        lastName.isEmpty ||
        username.isEmpty ||
        country.isEmpty ||
        gender == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please fill in all required fields.'.tr()),
        ),
      );
      return;
    }

    if (username.length < 3) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Username must be at least 3 characters.'.tr()),
        ),
      );
      return;
    }

    if (!RegExp(r'^[a-z0-9._]+$').hasMatch(username)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Username may only contain lowercase letters, numbers, dots, and underscores.'
                .tr(),
          ),
        ),
      );
      return;
    }

    final fullName = '$firstName $lastName'.trim();

    setState(() => _saving = true);

    try {
      final dbProvider = Provider.of<DatabaseProvider>(context, listen: false);

      await dbProvider.updateCoreProfile(
        name: fullName,
        username: username,
        country: country,
        gender: gender,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Profile completed!'.tr())),
      );

      widget.onCompleted?.call();
    } catch (e) {
      debugPrint('Error saving profile: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${'Could not save profile:'.tr()} $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _buildGenderChip({
    required BuildContext context,
    required String value,
    required String label,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final isSelected = _selectedGender == value;

    return ChoiceChip(
      label: Text(
        label,
        style: TextStyle(
          color: isSelected
              ? colorScheme.onPrimary
              : colorScheme.primary,
          fontWeight: FontWeight.w700,
          fontSize: 14,
        ),
      ),
      selected: isSelected,
      onSelected: (_) {
        setState(() => _selectedGender = value);
      },
      showCheckmark: false,
      selectedColor: colorScheme.primary,
      backgroundColor: colorScheme.surface,
      surfaceTintColor: Colors.transparent,
      side: BorderSide(
        color: isSelected
            ? colorScheme.primary
            : colorScheme.primary.withValues(alpha: 0.30),
        width: 1.2,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      elevation: isSelected ? 0 : 0,
      pressElevation: 0,
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Stack(
      children: [
        Scaffold(
          backgroundColor: colorScheme.surface,
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Center(
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(height: 8),

                      Image.asset(
                        'assets/images/login_page_image_green.png',
                        width: 220,
                        height: 220,
                        fit: BoxFit.contain,
                      ),

                      const SizedBox(height: 8),

                      Text(
                        "Complete your Ummah Chat profile".tr(),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: colorScheme.primary,
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        "We use this info to personalise your experience\nand keep interactions respectful."
                            .tr(),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: colorScheme.primary.withValues(alpha: 0.75),
                          fontSize: 13,
                          height: 1.4,
                        ),
                      ),

                      const SizedBox(height: 24),

                      MyTextField(
                        controller: _firstNameController,
                        hintText: "First name".tr(),
                        obscureText: false,
                      ),
                      const SizedBox(height: 8),

                      MyTextField(
                        controller: _lastNameController,
                        hintText: "Last name".tr(),
                        obscureText: false,
                      ),
                      const SizedBox(height: 8),

                      MyTextField(
                        controller: _usernameController,
                        hintText: "Username".tr(),
                        obscureText: false,
                      ),
                      const SizedBox(height: 6),

                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          "@username • ${'Only lowercase letters, numbers, dots and underscores'.tr()}",
                          style: TextStyle(
                            color: colorScheme.primary.withValues(alpha: 0.65),
                            fontSize: 12,
                          ),
                        ),
                      ),

                      const SizedBox(height: 16),

                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          "Country *".tr(),
                          style: TextStyle(
                            color: colorScheme.primary,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: colorScheme.surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: colorScheme.primary.withValues(alpha: 0.3),
                            width: 1,
                          ),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            isExpanded: true,
                            value: _selectedCountry,
                            hint: Text(
                              "Select your country".tr(),
                              style: TextStyle(
                                color: colorScheme.primary.withValues(alpha: 0.7),
                                fontSize: 14,
                              ),
                            ),
                            items: _countries
                                .map(
                                  (c) => DropdownMenuItem<String>(
                                value: c,
                                child: Text(
                                  c,
                                  style: TextStyle(
                                    color: colorScheme.primary,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            )
                                .toList(),
                            onChanged: (value) {
                              setState(() {
                                _selectedCountry = value;
                              });
                            },
                          ),
                        ),
                      ),

                      const SizedBox(height: 20),

                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          "Gender *".tr(),
                          style: TextStyle(
                            color: colorScheme.primary,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),

                      Align(
                        alignment: Alignment.centerLeft,
                        child: Center(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              SizedBox(
                                width: 120,
                                child: _buildGenderChip(
                                  context: context,
                                  value: 'male',
                                  label: "Male".tr(),
                                ),
                              ),
                              const SizedBox(width: 12),
                              SizedBox(
                                width: 120,
                                child: _buildGenderChip(
                                  context: context,
                                  value: 'female',
                                  label: "Female".tr(),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 28),

                      MyButton(
                        text: "Save and continue".tr(),
                        onTap: _saveProfile,
                      ),

                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),

        if (_saving)
          Container(
            color: const Color.fromRGBO(0, 0, 0, 0.25),
            child: Center(
              child: Material(
                borderRadius: BorderRadius.circular(16),
                color: colorScheme.surface.withValues(alpha: 0.95),
                elevation: 8,
                child: Padding(
                  padding:
                  const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircularProgressIndicator(),
                      const SizedBox(height: 16),
                      Text(
                        "Saving profile...".tr(),
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}