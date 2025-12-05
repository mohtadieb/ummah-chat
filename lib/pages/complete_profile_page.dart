// lib/pages/complete_profile_page.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../components/my_button.dart';
import '../components/my_text_field.dart';
import '../services/database/database_provider.dart';

class CompleteProfilePage extends StatefulWidget {
  final VoidCallback? onCompleted; // 👈 NEW

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

  String? _selectedCountry;
  String? _selectedGender; // 'male' | 'female'

  bool _saving = false;

  // Simple country list – you can extend / reorder as you like
  static const List<String> _countries = [
    'Netherlands',
    'Belgium',
    'Germany',
    'France',
    'United Kingdom',
    'Spain',
    'Italy',
    'Sweden',
    'Norway',
    'Denmark',
    'Finland',
    'Turkey',
    'Morocco',
    'Algeria',
    'Tunisia',
    'Egypt',
    'Saudi Arabia',
    'United Arab Emirates',
    'Qatar',
    'Kuwait',
    'Jordan',
    'Lebanon',
    'Pakistan',
    'India',
    'Bangladesh',
    'Indonesia',
    'Malaysia',
    'United States',
    'Canada',
    'Australia',
    'Other',
  ];

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    super.dispose();
  }

  Future<void> _saveProfile() async {
    FocusScope.of(context).unfocus();

    final firstName = _firstNameController.text.trim();
    final lastName = _lastNameController.text.trim();
    final country = _selectedCountry?.trim() ?? '';
    final gender = _selectedGender; // 'male' / 'female'

    if (firstName.isEmpty ||
        lastName.isEmpty ||
        country.isEmpty ||
        gender == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill in all required fields.'),
        ),
      );
      return;
    }

    final fullName = '$firstName $lastName'.trim();

    setState(() => _saving = true);

    try {
      final dbProvider =
      Provider.of<DatabaseProvider>(context, listen: false);

      // 🔹 Save via DatabaseProvider → DatabaseService
      await dbProvider.updateCoreProfile(
        name: fullName,
        country: country,
        gender: gender,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile completed!')),
      );

      // ✅ Let AuthGate / _ProfileGate handle switching to MainLayout
      widget.onCompleted?.call();
    } catch (e) {
      debugPrint('Error saving profile: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not save profile: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
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

                      // Logo
                      Image.asset(
                        'assets/login_page_image_green.png',
                        width: 220,
                        height: 220,
                        fit: BoxFit.contain,
                      ),

                      const SizedBox(height: 8),

                      Text(
                        "Complete your Ummah Chat profile",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: colorScheme.primary,
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        "We use this info to personalise your experience\nand keep interactions respectful.",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: colorScheme.primary.withValues(alpha: 0.75),
                          fontSize: 13,
                          height: 1.4,
                        ),
                      ),

                      const SizedBox(height: 24),

                      // First name
                      MyTextField(
                        controller: _firstNameController,
                        hintText: "First name",
                        obscureText: false,
                      ),
                      const SizedBox(height: 8),

                      // Last name
                      MyTextField(
                        controller: _lastNameController,
                        hintText: "Last name",
                        obscureText: false,
                      ),
                      const SizedBox(height: 16),

                      // Country dropdown
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          "Country *",
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
                              "Select your country",
                              style: TextStyle(
                                color: colorScheme.primary.withValues(
                                  alpha: 0.7,
                                ),
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

                      // Gender
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          "Gender *",
                          style: TextStyle(
                            color: colorScheme.primary,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        children: [
                          ChoiceChip(
                            label: const Text("Male"),
                            selected: _selectedGender == 'male',
                            onSelected: (_) {
                              setState(() => _selectedGender = 'male');
                            },
                          ),
                          ChoiceChip(
                            label: const Text("Female"),
                            selected: _selectedGender == 'female',
                            onSelected: (_) {
                              setState(() => _selectedGender = 'female');
                            },
                          ),
                        ],
                      ),

                      const SizedBox(height: 28),

                      MyButton(
                        text: "Save and continue",
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

        // Loading overlay
        if (_saving)
          Container(
            color: const Color.fromRGBO(0, 0, 0, 0.25),
            child: Center(
              child: Material(
                borderRadius: BorderRadius.circular(16),
                color: colorScheme.surface.withValues(alpha: 0.95),
                elevation: 8,
                child: const Padding(
                  padding:
                  EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 16),
                      Text(
                        "Saving profile...",
                        style: TextStyle(
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
