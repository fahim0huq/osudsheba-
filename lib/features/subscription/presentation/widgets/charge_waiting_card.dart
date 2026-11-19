import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../shared/widgets/app_primary_button.dart';

/// Shown after the OTP is accepted while the mobile operator is still charging.
///
/// "Pending" is not a failure: the charge usually lands within a minute and the screen
/// unlocks by itself. It only stays pending when the balance is too low.
class ChargeWaitingCard extends StatelessWidget {
  const ChargeWaitingCard({
    super.key,
    required this.bn,
    required this.timedOut,
    required this.onCheckAgain,
    required this.onUseOtherNumber,
  });

  final bool bn;
  final bool timedOut;
  final VoidCallback onCheckAgain;
  final VoidCallback onUseOtherNumber;

  String _t(String b, String e) => bn ? b : e;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            if (timedOut)
              const Icon(Icons.hourglass_bottom_rounded, color: AppColors.warning, size: 28)
            else
              const SizedBox(width: 26, height: 26, child: CircularProgressIndicator(strokeWidth: 3)),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                timedOut
                    ? _t('অপারেটর এখনো চার্জ নিশ্চিত করেনি', 'Your operator has not confirmed the charge yet')
                    : _t('ওটিপি ঠিক আছে। অপারেটর চার্জ নিশ্চিত করছে…', 'OTP accepted. Your operator is confirming the charge…'),
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          timedOut
              ? _t('সিমে যথেষ্ট ব্যালেন্স থাকলে কয়েক মিনিটের মধ্যে নিজে থেকেই চালু হবে, আবার ওটিপি লাগবে না। অ্যাপ বন্ধ করে পরে খুললেও হবে। ব্যালেন্স কম থাকলে রিচার্জ করুন।',
                  'With enough balance it starts by itself within a few minutes, with no new OTP. You can close the app and open it later. If your balance is low, please recharge.')
              : _t('সাধারণত এক মিনিটের কম লাগে। এই পাতা খোলা রাখুন, নিশ্চিত হলেই প্রিমিয়াম খুলে যাবে।',
                  'This usually takes under a minute. Keep this page open; premium unlocks as soon as it is confirmed.'),
          style: const TextStyle(fontSize: 14, height: 1.4, color: AppColors.textSecondary),
        ),
        if (timedOut) ...[
          const SizedBox(height: 14),
          AppPrimaryButton(text: _t('আবার দেখুন', 'Check again'), icon: Icons.refresh_rounded, onPressed: onCheckAgain),
        ],
        const SizedBox(height: 4),
        TextButton(
          onPressed: onUseOtherNumber,
          child: Text(_t('অন্য নম্বর দিয়ে চেষ্টা করুন', 'Use a different number'),
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 13.5)),
        ),
      ],
    );
  }
}
