import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/services/mock_data_service.dart';
import '../../../shared/widgets/app_primary_button.dart';
import '../../../shared/widgets/fade_slide_in.dart';

class PatientProfileSetupScreen extends ConsumerStatefulWidget {
  const PatientProfileSetupScreen({super.key});

  @override
  ConsumerState<PatientProfileSetupScreen> createState() => _PatientProfileSetupScreenState();
}

class _PatientProfileSetupScreenState extends ConsumerState<PatientProfileSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _ageController;
  late TextEditingController _phoneController;
  late TextEditingController _conditionsController;
  late TextEditingController _allergiesController;
  late TextEditingController _emergencyController;

  @override
  void initState() {
    super.initState();
    final profile = ref.read(patientProfileProvider);
    _nameController = TextEditingController(text: profile.name);
    _ageController = TextEditingController(text: profile.age);
    _phoneController = TextEditingController(text: profile.phone);
    _conditionsController = TextEditingController(text: profile.chronicConditions);
    _allergiesController = TextEditingController(text: profile.allergies);
    _emergencyController = TextEditingController(text: profile.emergencyContact);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _ageController.dispose();
    _phoneController.dispose();
    _conditionsController.dispose();
    _allergiesController.dispose();
    _emergencyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(appSettingsProvider);
    final lang = settings.language;

    return Scaffold(
      appBar: AppBar(
        title: Text(AppStrings.get('patient_setup_title', lang)),
        backgroundColor: Colors.transparent,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 10.0),
                FadeSlideIn(
                  child: Text(
                    AppStrings.get('patient_setup_title', lang),
                    style: Theme.of(context).textTheme.displaySmall?.copyWith(
                          color: AppColors.primaryDark,
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ),
                const SizedBox(height: 6.0),
                FadeSlideIn(
                  delay: const Duration(milliseconds: 100),
                  child: Text(
                    AppStrings.get('patient_setup_subtitle', lang),
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 14.5,
                    ),
                  ),
                ),
                const SizedBox(height: 28.0),
                
                // Full name
                FadeSlideIn(
                  delay: const Duration(milliseconds: 200),
                  child: TextFormField(
                    controller: _nameController,
                    decoration: InputDecoration(
                      labelText: AppStrings.get('full_name', lang),
                      prefixIcon: const Icon(Icons.person_rounded, color: AppColors.primary),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return lang == 'bn' ? 'নাম প্রয়োজন' : 'Name is required';
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(height: 16.0),
                
                // Age
                FadeSlideIn(
                  delay: const Duration(milliseconds: 300),
                  child: TextFormField(
                    controller: _ageController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: AppStrings.get('age', lang),
                      prefixIcon: const Icon(Icons.cake_rounded, color: AppColors.primary),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return lang == 'bn' ? 'বয়স প্রয়োজন' : 'Age is required';
                      }
                      final ageVal = int.tryParse(value);
                      if (ageVal == null || ageVal <= 0 || ageVal > 120) {
                        return lang == 'bn' ? 'সঠিক বয়স দিন' : 'Enter a valid age';
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(height: 16.0),
                
                // Phone
                FadeSlideIn(
                  delay: const Duration(milliseconds: 400),
                  child: TextFormField(
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    decoration: InputDecoration(
                      labelText: lang == 'bn' ? 'রোগীর ফোন নাম্বার' : 'Patient\'s Phone Number',
                      prefixIcon: const Icon(Icons.phone_iphone_rounded, color: AppColors.primary),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return lang == 'bn' ? 'ফোন নাম্বার প্রয়োজন' : 'Phone number is required';
                      }
                      final regExp = RegExp(r'^(?:\+88)?01[3-9]\d{8}$');
                      if (!regExp.hasMatch(value)) {
                        return lang == 'bn' ? 'সঠিক বাংলাদেশি ফোন নাম্বার দিন' : 'Enter a valid Bangladesh phone number';
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(height: 16.0),
                
                // Chronic conditions
                FadeSlideIn(
                  delay: const Duration(milliseconds: 500),
                  child: TextFormField(
                    controller: _conditionsController,
                    decoration: InputDecoration(
                      labelText: AppStrings.get('chronic_conditions', lang),
                      prefixIcon: const Icon(Icons.medical_services_rounded, color: AppColors.primary),
                    ),
                  ),
                ),
                const SizedBox(height: 16.0),
                
                // Allergies
                FadeSlideIn(
                  delay: const Duration(milliseconds: 600),
                  child: TextFormField(
                    controller: _allergiesController,
                    decoration: InputDecoration(
                      labelText: AppStrings.get('allergies', lang),
                      prefixIcon: const Icon(Icons.warning_amber_rounded, color: AppColors.primary),
                    ),
                  ),
                ),
                const SizedBox(height: 16.0),
                
                // Emergency contact
                FadeSlideIn(
                  delay: const Duration(milliseconds: 700),
                  child: TextFormField(
                    controller: _emergencyController,
                    keyboardType: TextInputType.phone,
                    decoration: InputDecoration(
                      labelText: AppStrings.get('emergency_contact', lang),
                      prefixIcon: const Icon(Icons.contact_phone_rounded, color: AppColors.primary),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return lang == 'bn' ? 'জরুরী যোগাযোগ নম্বর প্রয়োজন' : 'Emergency contact is required';
                      }
                      final regExp = RegExp(r'^(?:\+88)?01[3-9]\d{8}$');
                      if (!regExp.hasMatch(value)) {
                        return lang == 'bn' ? 'সঠিক বাংলাদেশি ফোন নাম্বার দিন' : 'Enter a valid Bangladesh phone number';
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(height: 36.0),
                
                FadeSlideIn(
                  delay: const Duration(milliseconds: 800),
                  child: AppPrimaryButton(
                    text: AppStrings.get('complete_setup', lang),
                    icon: Icons.check_circle_outline_rounded,
                    onPressed: () {
                      if (_formKey.currentState!.validate()) {
                        ref.read(patientProfileProvider.notifier).updateProfile(
                              PatientProfile(
                                name: _nameController.text,
                                age: _ageController.text,
                                phone: _phoneController.text,
                                chronicConditions: _conditionsController.text,
                                allergies: _allergiesController.text,
                                emergencyContact: _emergencyController.text,
                              ),
                            );
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(lang == 'bn' ? 'প্রোফাইল সংরক্ষণ করা হয়েছে' : 'Profile saved successfully!'),
                            backgroundColor: AppColors.success,
                          ),
                        );
                        context.go('/home');
                      }
                    },
                  ),
                ),
                const SizedBox(height: 20.0),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
