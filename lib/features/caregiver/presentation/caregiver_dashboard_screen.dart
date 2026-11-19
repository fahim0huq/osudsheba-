import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/utils/alert_text.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/models/mock_models.dart';
import '../../../core/services/mock_data_service.dart';
import '../../../core/services/phone_actions.dart';
import '../../../shared/widgets/fade_slide_in.dart';
import '../../../shared/widgets/tap_area.dart';
import '../../family/presentation/family_sections.dart';

/// The Family tab: my day, family sharing (people I look after, and who can see me), missed-
/// dose alerts and the family contact. Every account is both a patient and a caregiver.
class CaregiverDashboardScreen extends ConsumerWidget {
  const CaregiverDashboardScreen({super.key});

  static const double _gap = 14.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bn = ref.watch(appSettingsProvider).language == 'bn';
    String t(String bnText, String en) => bn ? bnText : en;

    final alerts = ref.watch(caregiverAlertsProvider);
    final patient = ref.watch(patientProfileProvider);
    final missedAlert = alerts.where((a) => a.severity == 'High').firstOrNull;

    // Today's outcome, by the day each dose was due.
    final today = dateKey(DateTime.now());
    final todayLogs = ref.watch(doseLogsProvider).where((l) => l.effectiveScheduledDate == today).toList();
    final taken = todayLogs.where((l) => l.status == 'taken' || l.status == 'late').length;
    final decided = todayLogs.where((l) => l.status != 'snoozed').length; // snoozed = still open
    final missed = todayLogs.where((l) => l.status == 'missed').length;
    final percent = decided > 0 ? (taken / decided * 100).round() : null;

    return Scaffold(
      appBar: AppBar(
        title: Text(t('পরিবার', 'Family')),
        backgroundColor: Colors.transparent,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        actions: [
          IconButton(
            tooltip: t('সেটিংস', 'Settings'),
            icon: const Icon(Icons.settings_rounded, color: AppColors.textPrimary),
            onPressed: () => context.push('/settings'),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20.0, 4.0, 20.0, 16.0),
          child: FadeSlideIn(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _TodayCard(
                  name: patient.name.isNotEmpty ? patient.name : t('আমি', 'Me'),
                  title: t('আজ', 'Today'),
                  takenLabel: t('খেয়েছি', 'Taken'),
                  missedLabel: t('মিস', 'Missed'),
                  percentLabel: t('আজ', 'Today'),
                  taken: taken,
                  total: decided,
                  missed: missed,
                  percent: percent,
                  bn: bn,
                  onTap: () => context.push('/caregiver-patient-detail'),
                ),
                if (missedAlert != null) ...[
                  const SizedBox(height: _gap),
                  _MissedBanner(
                    alert: missedAlert,
                    lang: bn ? 'bn' : 'en',
                    callLabel: t('পরিবারকে কল', 'Call family'),
                    // Calls the saved family contact; hidden until one is saved.
                    onCall: patient.emergencyContact.isEmpty
                        ? null
                        : () => PhoneActions.call(context, patient.emergencyContact, lang: bn ? 'bn' : 'en'),
                  ),
                ],
                const SizedBox(height: _gap),
                // Family sharing: people I look after, and who can see my medicines.
                const FamilySections(),
                const SizedBox(height: _gap),
                _ActionGrid(
                  // Two per row normally; one per row (each as tall as its text) at large text.
                  large: MediaQuery.textScalerOf(context).scale(1.0) > 1.3,
                  children: [
                    _Action(
                      icon: Icons.person_add_alt_rounded,
                      color: AppColors.primary,
                      label: t('পরিবারের নম্বর', 'Family contact'),
                      sub: patient.emergencyContact.isEmpty ? t('যোগ করুন', 'Add a number') : patient.emergencyContact,
                      onTap: () => context.push('/caregiver-invite'),
                    ),
                    _Action(
                      icon: Icons.notifications_active_rounded,
                      color: AppColors.error,
                      label: t('অ্যালার্ট', 'Alerts'),
                      sub: alerts.isEmpty ? t('কোনো অ্যালার্ট নেই', 'None') : t('${alerts.length}টি', '${alerts.length} new'),
                      onTap: () => context.push('/caregiver-alerts'),
                    ),
                    _Action(
                      icon: Icons.analytics_rounded,
                      color: AppColors.accent,
                      label: t('বিস্তারিত', 'Details'),
                      sub: t('ইতিহাস ও তথ্য', 'History & info'),
                      onTap: () => context.push('/caregiver-patient-detail'),
                    ),
                    _Action(
                      icon: Icons.badge_rounded,
                      color: Colors.indigo,
                      label: t('প্রোফাইল', 'Profile'),
                      sub: t('নাম, বয়স, রোগ', 'Name, age, conditions'),
                      onTap: () => context.push('/patient-profile-setup'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TodayCard extends StatelessWidget {
  const _TodayCard({
    required this.name,
    required this.title,
    required this.takenLabel,
    required this.missedLabel,
    required this.percentLabel,
    required this.taken,
    required this.total,
    required this.missed,
    required this.percent,
    required this.bn,
    required this.onTap,
  });

  final String name, title, takenLabel, missedLabel, percentLabel;
  final int taken, total, missed;
  final int? percent;
  final bool bn;
  final VoidCallback onTap;

  String _n(String s) => bn ? s.split('').map((c) => '0123456789'.contains(c) ? '০১২৩৪৫৬৭৮৯'['0123456789'.indexOf(c)] : c).join() : s;

  @override
  Widget build(BuildContext context) {
    Widget stat(String value, String label, Color color) => Expanded(
          child: Column(
            children: [
              Text(_n(value), style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: color)),
              Text(label, maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
            ],
          ),
        );

    return Material(
      color: Colors.white,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16.0),
        side: const BorderSide(color: AppColors.border),
      ),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14.0, 12.0, 8.0, 12.0),
          child: Column(
            children: [
              Row(
                children: [
                  const CircleAvatar(
                    radius: 18,
                    backgroundColor: AppColors.primaryLight,
                    child: Icon(Icons.person_rounded, color: AppColors.primary, size: 22),
                  ),
                  const SizedBox(width: 10.0),
                  Expanded(
                    child: Text('$name · $title',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.textPrimary)),
                  ),
                  const Icon(Icons.chevron_right_rounded, color: Colors.grey),
                ],
              ),
              const SizedBox(height: 10.0),
              Row(
                children: [
                  stat('$taken/$total', takenLabel, AppColors.success),
                  stat('$missed', missedLabel, missed > 0 ? AppColors.error : AppColors.textSecondary),
                  stat(percent == null ? '–' : '$percent%', percentLabel, AppColors.primary),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MissedBanner extends StatelessWidget {
  const _MissedBanner({required this.alert, required this.lang, required this.callLabel, required this.onCall});
  final CaregiverAlert alert;
  final String lang;
  final String callLabel;
  final VoidCallback? onCall;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12.0, 10.0, 10.0, 10.0),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14.0),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded, color: AppColors.error, size: 26),
          const SizedBox(width: 10.0),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(alertTitleText(alert, lang),
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.error)),
                Text(alertMessageText(alert, lang),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13, color: AppColors.textPrimary)),
              ],
            ),
          ),
          if (onCall != null) ...[
            const SizedBox(width: 8.0),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.error,
                foregroundColor: Colors.white,
                elevation: 0,
                minimumSize: const Size(0, 44.0),
                padding: const EdgeInsets.symmetric(horizontal: 12.0),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.0)),
              ),
              icon: const Icon(Icons.call_rounded, size: 18),
              label: Text(callLabel, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
              onPressed: onCall,
            ),
          ],
        ],
      ),
    );
  }
}

class _Action extends StatelessWidget {
  const _Action({required this.icon, required this.color, required this.label, required this.sub, required this.onTap});
  final IconData icon;
  final Color color;
  final String label;
  final String sub;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '$label, $sub',
      excludeSemantics: true,
      child: TapArea(
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 56.0),
          padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 8.0),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14.0),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: color.withValues(alpha: 0.1), shape: BoxShape.circle),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 8.0),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.textPrimary)),
                    Text(sub,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActionGrid extends StatelessWidget {
  const _ActionGrid({required this.large, required this.children});
  final bool large;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    if (large) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final c in children) Padding(padding: const EdgeInsets.only(bottom: 10.0), child: c),
        ],
      );
    }
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      crossAxisSpacing: 10.0,
      mainAxisSpacing: 10.0,
      childAspectRatio: 2.3,
      children: children,
    );
  }
}
