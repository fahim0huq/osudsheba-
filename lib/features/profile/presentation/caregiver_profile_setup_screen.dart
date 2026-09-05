import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/services/mock_data_service.dart';
import '../../../shared/widgets/app_primary_button.dart';
import '../../../shared/widgets/fade_slide_in.dart';

class CaregiverProfileSetupScreen extends ConsumerStatefulWidget {
  const CaregiverProfileSetupScreen({super.key});

  @override
  ConsumerState<CaregiverProfileSetupScreen> createState() => _CaregiverProfileSetupScreenState();
}

class _CaregiverProfileSetupScreenState extends ConsumerState<CaregiverProfileSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _patientNameController;
  late TextEditingController _patientAgeController;
  late TextEditingController _patientPhoneController;
  late TextEditingController _caregiverNameController;
  late TextEditingController _relationshipController;
  late TextEditingController _caregiverPhoneController;

  @override
  void initState() {
    super.initState();
    final patient = ref.read(patientProfileProvider);
    final caregiver = ref.read(caregiverProfileProvider);

    _patientNameController = TextEditingController(text: patient.name);
    _patientAgeController = TextEditingController(text: patient.age);
    _patientPhoneController = TextEditingController(text: patient.phone.isNotEmpty ? patient.phone : caregiver.patientPhone);
    _caregiverNameController = TextEditingController(text: caregiver.name);
    _relationshipController = TextEditingController(text: caregiver.relationship.isNotEmpty ? caregiver.relationship : 'Caregiver');
    _caregiverPhoneController = TextEditingController(text: caregiver.phone);
  }

  @override
  void dispose() {
    _patientNameController.dispose();
    _patientAgeController.dispose();
    _patientPhoneController.dispose();
    _caregiverNameController.dispose();
    _relationshipController.dispose();
    _caregiverPhoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(appSettingsProvider);
    final lang = settings.language;

    return Scaffold(
      appBar: AppBar(
        title: Text(lang == 'bn' ? 'রোগী তথ্য সেটআপ' : 'Patient Setup (Caregiver)'),
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
                    lang == 'bn' ? 'রোগীর তথ্য যুক্ত করুন' : 'Managed Patient Details',
                    style: Theme.of(context).textTheme.displaySmall?.copyWith(
                          color: AppColors.primaryDark,
                          fontWeight: FontWeight.bold,
                          fontSize: 22.0,
                        ),
                  ),
                ),
                const SizedBox(height: 6.0),
                FadeSlideIn(
                  delay: const Duration(milliseconds: 100),
                  child: Text(
                    lang == 'bn'
                        ? 'আপনি যে রোগীর ওষুধ পরিচালনা করবেন তার প্রাথমিক তথ্য দিন।'
                        : 'Enter the details of the family member or patient you will manage.',
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 14.0,
                    ),
                  ),
                ),
                const SizedBox(height: 24.0),

                // Patient Full Name
                FadeSlideIn(
                  delay: const Duration(milliseconds: 150),
                  child: TextFormField(
                    controller: _patientNameController,
                    decoration: InputDecoration(
                      labelText: lang == 'bn' ? 'রোগীর পূর্ণ নাম' : 'Patient\'s Full Name',
                      prefixIcon: const Icon(Icons.person_rounded, color: AppColors.primary),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return lang == 'bn' ? 'রোগীর নাম প্রয়োজন' : 'Patient name is required';
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(height: 16.0),

                // Patient Age
                FadeSlideIn(
                  delay: const Duration(milliseconds: 200),
                  child: TextFormField(
                    controller: _patientAgeController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: lang == 'bn' ? 'রোগীর বয়স' : 'Patient\'s Age',
                      prefixIcon: const Icon(Icons.cake_rounded, color: AppColors.primary),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return lang == 'bn' ? 'বয়স প্রয়োজন' : 'Age is required';
                      }
                      final ageVal = int.tryParse(value.trim());
                      if (ageVal == null || ageVal <= 0 || ageVal > 120) {
                        return lang == 'bn' ? 'সঠিক বয়স দিন' : 'Enter a valid age';
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(height: 16.0),

                // Patient Phone Number
                FadeSlideIn(
                  delay: const Duration(milliseconds: 250),
                  child: TextFormField(
                    controller: _patientPhoneController,
                    keyboardType: TextInputType.phone,
                    decoration: InputDecoration(
                      labelText: lang == 'bn' ? 'রোগীর ফোন নাম্বার' : 'Patient\'s Phone Number',
                      prefixIcon: const Icon(Icons.phone_iphone_rounded, color: AppColors.primary),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return lang == 'bn' ? 'রোগীর ফোন নাম্বার প্রয়োজন' : 'Patient phone number is required';
                      }
                      final regExp = RegExp(r'^(?:\+88)?01[3-9]\d{8}$');
                      if (!regExp.hasMatch(value.trim())) {
                        return lang == 'bn' ? 'সঠিক বাংলাদেশি ফোন নাম্বার দিন' : 'Enter a valid Bangladesh phone number';
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(height: 24.0),

                // Caregiver details divider header
                FadeSlideIn(
                  delay: const Duration(milliseconds: 300),
                  child: Text(
                    lang == 'bn' ? 'আপনার (তত্ত্বাবধায়কের) তথ্য' : 'Your Information (Caregiver)',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15.0,
                      color: AppColors.primaryDark,
                    ),
                  ),
                ),
                const SizedBox(height: 12.0),

                // Caregiver Name
                FadeSlideIn(
                  delay: const Duration(milliseconds: 350),
                  child: TextFormField(
                    controller: _caregiverNameController,
                    decoration: InputDecoration(
                      labelText: lang == 'bn' ? 'আপনার নাম' : 'Your Name',
                      prefixIcon: const Icon(Icons.badge_rounded, color: AppColors.primary),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return lang == 'bn' ? 'আপনার নাম প্রয়োজন' : 'Caregiver name is required';
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(height: 16.0),

                // Relationship to patient
                FadeSlideIn(
                  delay: const Duration(milliseconds: 400),
                  child: TextFormField(
                    controller: _relationshipController,
                    decoration: InputDecoration(
                      labelText: lang == 'bn' ? 'রোগীর সাথে আপনার সম্পর্ক (যেমন: বাবা, মা)' : 'Relationship to Patient (e.g. Father, Mother)',
                      prefixIcon: const Icon(Icons.family_restroom_rounded, color: AppColors.primary),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return lang == 'bn' ? 'সম্পর্ক উল্লেখ করুন' : 'Relationship is required';
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(height: 16.0),

                // Caregiver Phone
                FadeSlideIn(
                  delay: const Duration(milliseconds: 450),
                  child: TextFormField(
                    controller: _caregiverPhoneController,
                    keyboardType: TextInputType.phone,
                    decoration: InputDecoration(
                      labelText: lang == 'bn' ? 'আপনার মোবাইল নম্বর (জরুরী সতর্কবার্তার জন্য)' : 'Your Phone Number (For alerts)',
                      prefixIcon: const Icon(Icons.contact_phone_rounded, color: AppColors.primary),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return lang == 'bn' ? 'ফোন নাম্বার প্রয়োজন' : 'Phone number is required';
                      }
                      final regExp = RegExp(r'^(?:\+88)?01[3-9]\d{8}$');
                      if (!regExp.hasMatch(value.trim())) {
                        return lang == 'bn' ? 'সঠিক বাংলাদেশি ফোন নাম্বার দিন' : 'Enter a valid Bangladesh phone number';
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(height: 32.0),

                FadeSlideIn(
                  delay: const Duration(milliseconds: 500),
                  child: AppPrimaryButton(
                    text: AppStrings.get('complete_setup', lang),
                    icon: Icons.check_circle_outline_rounded,
                    onPressed: () {
                      if (_formKey.currentState!.validate()) {
                        final patientPhone = _patientPhoneController.text.trim();
                        final caregiverPhone = _caregiverPhoneController.text.trim();
                        final patientName = _patientNameController.text.trim();
                        final patientAge = _patientAgeController.text.trim();
                        final caregiverName = _caregiverNameController.text.trim();
                        final relationship = _relationshipController.text.trim();

                        // Save patient profile for the managed patient
                        ref.read(patientProfileProvider.notifier).updateProfile(
                              PatientProfile(
                                name: patientName,
                                age: patientAge,
                                phone: patientPhone,
                                emergencyContact: caregiverPhone,
                              ),
                            );

                        // Save caregiver profile
                        ref.read(caregiverProfileProvider.notifier).updateProfile(
                              CaregiverProfile(
                                name: caregiverName,
                                relationship: relationship,
                                phone: caregiverPhone,
                                patientPhone: patientPhone,
                              ),
                            );

                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(lang == 'bn'
                                ? 'রোগী ও কেয়ারগিভার প্রোফাইল সফলভাবে তৈরি হয়েছে!'
                                : 'Patient and caregiver profiles saved successfully!'),
                            backgroundColor: AppColors.success,
                          ),
                        );
                        context.go('/caregiver');
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
