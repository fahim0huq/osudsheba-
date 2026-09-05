import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/mock_data_service.dart';
import '../../../shared/widgets/app_primary_button.dart';
import '../../../shared/widgets/fade_slide_in.dart';

class CaregiverInviteScreen extends ConsumerStatefulWidget {
  const CaregiverInviteScreen({super.key});

  @override
  ConsumerState<CaregiverInviteScreen> createState() => _CaregiverInviteScreenState();
}

class _CaregiverInviteScreenState extends ConsumerState<CaregiverInviteScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _relationshipController = TextEditingController(text: 'Daughter');
  String _permissionLevel = 'Alerts Only'; // View Only, Alerts Only, Edit Schedule

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _relationshipController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(appSettingsProvider);
    final lang = settings.language;

    final title = lang == 'bn' ? 'কেয়ারগিভার আমন্ত্রণ' : 'Invite Caregiver';

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        backgroundColor: Colors.transparent,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              physics: const ClampingScrollPhysics(),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight,
                ),
                child: IntrinsicHeight(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
                    child: Form(
                      key: _formKey,
                      child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 8.0),
                FadeSlideIn(
                  delay: const Duration(milliseconds: 100),
                  child: Text(
                    lang == 'bn'
                        ? 'যিনি আপনার ওষুধ গ্রহণের অগ্রগতি মনিটর করবেন তার তথ্য দিন।'
                        : 'Add a family member to monitor medication adherence and get instant alerts.',
                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 14.0, height: 1.3),
                  ),
                ),
                const SizedBox(height: 16.0),

                // Name
                FadeSlideIn(
                  delay: const Duration(milliseconds: 150),
                  child: TextFormField(
                    controller: _nameController,
                    decoration: InputDecoration(
                      labelText: lang == 'bn' ? 'সদস্যের নাম' : 'Caregiver Name',
                      prefixIcon: const Icon(Icons.person_rounded, color: AppColors.primary, size: 20),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
                    ),
                    validator: (value) => value == null || value.isEmpty ? 'Required' : null,
                  ),
                ),
                const SizedBox(height: 12.0),

                // Phone
                FadeSlideIn(
                  delay: const Duration(milliseconds: 200),
                  child: TextFormField(
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    decoration: InputDecoration(
                      labelText: lang == 'bn' ? 'মোবাইল নাম্বার' : 'Phone Number',
                      prefixIcon: const Icon(Icons.phone_rounded, color: AppColors.primary, size: 20),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
                    ),
                    validator: (value) => value == null || value.isEmpty ? 'Required' : null,
                  ),
                ),
                const SizedBox(height: 12.0),

                // Relationship
                FadeSlideIn(
                  delay: const Duration(milliseconds: 250),
                  child: TextFormField(
                    controller: _relationshipController,
                    decoration: InputDecoration(
                      labelText: lang == 'bn' ? 'সম্পর্ক' : 'Relationship to Patient',
                      prefixIcon: const Icon(Icons.family_restroom_rounded, color: AppColors.primary, size: 20),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
                    ),
                  ),
                ),
                const SizedBox(height: 16.0),

                // Permission Level
                FadeSlideIn(
                  delay: const Duration(milliseconds: 300),
                  child: Text(
                    lang == 'bn' ? 'অনুমতি লেভেল' : 'Access Permissions',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5, color: AppColors.textPrimary),
                  ),
                ),
                const SizedBox(height: 6.0),
                FadeSlideIn(
                  delay: const Duration(milliseconds: 350),
                  child: DropdownButtonFormField<String>(
                    initialValue: _permissionLevel,
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.security_rounded, color: AppColors.primary),
                    ),
                    items: ['View Only', 'Alerts Only', 'Edit Schedule']
                        .map((perm) => DropdownMenuItem(value: perm, child: Text(perm)))
                        .toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setState(() {
                          _permissionLevel = val;
                        });
                      }
                    },
                  ),
                ),
                const Expanded(child: SizedBox(height: 24.0)),

                FadeSlideIn(
                  delay: const Duration(milliseconds: 400),
                  child: AppPrimaryButton(
                    text: lang == 'bn' ? 'আমন্ত্রণ পাঠান' : 'Send Invite',
                    icon: Icons.send_rounded,
                    onPressed: () {
                      if (_formKey.currentState!.validate()) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(lang == 'bn'
                                ? 'আমন্ত্রণ লিংক এসএমএস করা হয়েছে!'
                                : 'Invitation link sent successfully via SMS!'),
                            backgroundColor: AppColors.success,
                          ),
                        );
                        context.pop();
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
),
),
);
  }
}
