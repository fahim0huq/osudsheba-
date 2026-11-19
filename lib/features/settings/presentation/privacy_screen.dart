import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/services/mock_data_service.dart';
import '../../../shared/widgets/app_info_card.dart';
import '../../../shared/widgets/fade_slide_in.dart';

class PrivacyScreen extends ConsumerWidget {
  const PrivacyScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(appSettingsProvider);
    final lang = settings.language;

    final title = lang == 'bn' ? 'গোপনীয়তা নীতিমালা' : 'Privacy Policy';

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        backgroundColor: Colors.transparent,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FadeSlideIn(
                child: Text(
                  lang == 'bn' ? 'আপনার তথ্যের নিরাপত্তা' : 'Your Data Security',
                  style: Theme.of(context).textTheme.displaySmall?.copyWith(
                        fontSize: 22.0,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primaryDark,
                      ),
                ),
              ),
              const SizedBox(height: 12.0),
              FadeSlideIn(
                delay: const Duration(milliseconds: 100),
                child: Text(
                  lang == 'bn'
                      ? 'ওষুধসেবা আপনার ব্যক্তিগত স্বাস্থ্য সংক্রান্ত তথ্যের সুরক্ষায় প্রতিশ্রুতিবদ্ধ।'
                      : 'OsudSheba is committed to safeguarding your personal health information.',
                  style: const TextStyle(color: AppColors.textPrimary, fontSize: 15.0, fontWeight: FontWeight.w500, height: 1.4),
                ),
              ),
              const SizedBox(height: 28.0),

              // Privacy Items
              FadeSlideIn(
                delay: const Duration(milliseconds: 150),
                child: _buildPrivacySection(
                  context,
                  title: lang == 'bn' ? 'আপনার তথ্য ও ব্যাকআপ' : '1. Your Data and Backup',
                  description: lang == 'bn'
                      ? 'আপনার ওষুধের তালিকা, ডোজের ইতিহাস ও প্রোফাইল এই ফোনে থাকে। সেটিংসে "অ্যাকাউন্টে ব্যাকআপ" চালু করলে (আপনি চালু না করা পর্যন্ত এটি বন্ধ থাকে) ওষুধের তালিকা ও ডোজের ইতিহাস আপনার অ্যাকাউন্টে Google Firebase-এও রাখা হয়, যাতে নতুন ফোনে সব ফিরে পান। এই ব্যাকআপ শুধু আপনি আর আপনার অনুমতি পাওয়া পরিবারের সদস্যরা দেখতে পারেন। যেকোনো সময় ব্যাকআপ বন্ধ করে মুছে দিতে পারেন। লগইনের জন্য আপনার ইমেইল বা ফোন নম্বর Google Firebase-এ থাকে। সাবস্ক্রিপশনের জন্য আপনার মোবাইল নম্বর বিল-প্রদানকারী (AppsPro/BDApps ও আপনার অপারেটর)-এর কাছে যায়। আমরা আপনার তথ্য বিক্রি করি না।'
                      : 'Your medicine list, dose history and profile are kept on this phone. If you turn on Account Backup in Settings (it stays off until you turn it on), your medicine list and dose history are also saved in your account on Google Firebase, so you can get them back on a new phone. Only you and family members you approve can see this backup. You can turn backup off and delete it at any time. To sign in, your email or phone number is kept by Google Firebase. For the subscription, your mobile number is shared with the billing provider (AppsPro/BDApps) and your mobile operator. We do not sell your data.',
                ),
              ),
              FadeSlideIn(
                delay: const Duration(milliseconds: 200),
                child: _buildPrivacySection(
                  context,
                  title: lang == 'bn' ? 'প্রেসক্রিপশন স্ক্যান' : '2. Prescription Scanning',
                  description: lang == 'bn'
                      ? 'প্রেসক্রিপশন বা ওষুধের প্যাকেটের ছবি আপনার ফোনেই পড়া হয়, অ্যাপের সাথে থাকা বাংলাদেশের ওষুধের তালিকার সাথে মিলিয়ে। ছবিটি কোনো সার্ভার বা বাইরের এআই সেবায় পাঠানো হয় না। আপনি যে ওষুধগুলো সংরক্ষণ করেন শুধু সেগুলোই রাখা হয়, ছবি নয়।'
                      : 'Prescription and medicine packet photos are read on your phone and matched against a list of Bangladeshi medicines that comes with the app. The photo is not sent to any server or outside AI service. Only the medicines you save are kept, not the photo.',
                ),
              ),
              FadeSlideIn(
                delay: const Duration(milliseconds: 250),
                child: _buildPrivacySection(
                  context,
                  title: lang == 'bn' ? 'পরিবারের সাথে শেয়ার' : '3. Sharing with Family',
                  description: lang == 'bn'
                      ? 'আপনি কাউকে আমন্ত্রণ না জানালে কিছুই শেয়ার হয় না। পরিবারের সদস্যকে একবার ব্যবহারের একটি আমন্ত্রণ কোড দিতে পারেন; আপনি অনুমতি দেওয়ার পরেই তিনি আপনার তথ্য দেখতে পারবেন। অনুমতি পাওয়া সদস্য আপনার নাম, ওষুধের তালিকা এবং কোন ডোজ খেয়েছেন, বাদ দিয়েছেন বা মিস করেছেন তা দেখতে পারেন (এজন্য অ্যাকাউন্টে ব্যাকআপ চালু হয়), আর আপনাকে রিমাইন্ডার পাঠাতে পারেন। তিনি আপনার ওষুধ বদলাতে পারেন না। "পরিবার" অংশ থেকে যেকোনো সময় কাউকে সরিয়ে দিতে পারেন।'
                      : 'Nothing is shared unless you invite someone. You can give a family member a one-time invite code; they can see your information only after you approve them. An approved family member can see your name, your medicine list and which doses you took, skipped or missed (this needs Account Backup, which is turned on), and can send you reminders. They cannot change your medicines. You can remove anyone at any time from the Family tab.',
                ),
              ),
              FadeSlideIn(
                delay: const Duration(milliseconds: 300),
                child: _buildPrivacySection(
                  context,
                  title: lang == 'bn' ? 'তথ্য মুছে ফেলা' : '4. Deleting Your Data',
                  description: lang == 'bn'
                      ? 'সেটিংস > "সব লোকাল ডেটা মুছুন" দিয়ে এই ফোনের সব তথ্য মুছতে পারেন। সেটিংস > "আমার অ্যাকাউন্ট মুছে ফেলুন" দিলে সাবস্ক্রিপশন বন্ধ হয় এবং আপনার লগইন অ্যাকাউন্ট, ব্যাকআপ, পরিবারের সংযোগ ও সাবস্ক্রিপশনের রেকর্ডও মুছে যায়।'
                      : 'Settings > "Delete All Local Data" removes everything stored on this phone. Settings > "Delete my account" stops the subscription and also deletes your sign-in account, your backup, your family links and your subscription record.',
                ),
              ),
              const SizedBox(height: 20.0),

              // Disclaimer Info Card
              FadeSlideIn(
                delay: const Duration(milliseconds: 350),
                child: AppInfoCard(
                  title: lang == 'bn' ? 'মেডিকেল ডিক্লেমার' : 'Medical Disclaimer',
                  description: AppStrings.get('medical_disclaimer', lang),
                  icon: Icons.warning_amber_rounded,
                  iconColor: AppColors.warning,
                  backgroundColor: AppColors.warning.withValues(alpha: 0.06),
                ),
              ),
              const SizedBox(height: 20.0),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPrivacySection(BuildContext context, {required String title, required String description}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15.5, color: AppColors.primary),
          ),
          const SizedBox(height: 6.0),
          Text(
            description,
            style: const TextStyle(
                  height: 1.45,
                  fontSize: 14.0,
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
          ),
        ],
      ),
    );
  }
}
