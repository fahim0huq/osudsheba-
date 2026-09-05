import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';

class AppInfoCard extends StatelessWidget {
   final String title;
   final String description;
   final IconData icon;
   final Color iconColor;
   final Color backgroundColor;

   const AppInfoCard({super.key,
     required this.title,
     required this.description,
     required this.icon,
     this.iconColor = AppColors.primary,
     this.backgroundColor = AppColors.primaryLight,
   });

   @override
   Widget build(BuildContext context) {
     return Container(
       padding: const EdgeInsets.all(20.0),
       decoration: BoxDecoration(
         color: AppColors.surface,
         borderRadius: BorderRadius.circular(22.0),
         border: Border.all(color: AppColors.border, width: 1.0),
         boxShadow: [
           BoxShadow(
             color: Colors.black.withValues(alpha: 0.02),
             blurRadius: 10,
             offset: const Offset(0, 4),
           )
         ],
       ),
       child: Row(
         crossAxisAlignment: CrossAxisAlignment.start,
         children: [
           // Icon bubble
           Container(
             padding: const EdgeInsets.all(12.0),
             decoration: BoxDecoration(
               color: backgroundColor,
               shape: BoxShape.circle,
             ),
             child: Icon(icon, color: iconColor, size: 24.0),
           ),
           const SizedBox(width: 16.0),
           Expanded(
             child: Column(
               crossAxisAlignment: CrossAxisAlignment.start,
               children: [
                 Text(
                   title,
                   style: Theme.of(context).textTheme.titleLarge?.copyWith(
                         color: AppColors.textPrimary,
                         fontWeight: FontWeight.bold,
                         fontSize: 16.0,
                       ),
                 ),
                 const SizedBox(height: 6.0),
                 Text(
                   description,
                   style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                         color: AppColors.textSecondary,
                         fontSize: 13.5,
                         height: 1.4,
                       ),
                 ),
               ],
             ),
           ),
         ],
       ),
     );
   }
}

