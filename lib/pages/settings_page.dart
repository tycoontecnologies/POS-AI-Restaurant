import 'package:flutter/material.dart';
import 'package:pos/l10n/app_localizations.dart';
import 'package:provider/provider.dart';
import '../components/ui/custom_card.dart';
import '../providers/theme_provider.dart';
import '../providers/locale_provider.dart';
import '../utils/responsive.dart';
import '../utils/app_spacing.dart';
import '../utils/app_colors.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    Provider.of<ThemeProvider>(context);
    final localeProvider = Provider.of<LocaleProvider>(context);

    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: Responsive.getPagePadding(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n.settings,
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: Theme.of(context).colorScheme.onBackground,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Configure your application preferences',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(
                context,
              ).textTheme.bodyMedium?.color?.withOpacity(0.8),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),

          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  CustomCard(
                    color: const Color.fromARGB(255, 248, 248, 250),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(AppSpacing.sm),
                              decoration: BoxDecoration(
                                color: AppColors.secondary.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(
                                  AppSpacing.radiusSm,
                                ),
                              ),
                              child: Icon(
                                Icons.language,
                                color: colorScheme.secondary,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            Text(
                              'Language & Region',
                              style: Theme.of(context).textTheme.titleLarge
                                  ?.copyWith(fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.md),
                        Text(
                          l10n.language,
                          style: Theme.of(context).textTheme.labelLarge
                              ?.copyWith(
                                color: Theme.of(
                                  context,
                                ).textTheme.labelLarge?.color?.withOpacity(0.9),
                              ),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Column(
                          children: [
                            _LanguageOption(
                              title: 'English',
                              subtitle: 'English',
                              flag: '🇺🇸',
                              selected:
                                  localeProvider.locale.languageCode == 'en',
                              onTap: () =>
                                  localeProvider.setLocale(const Locale('en')),
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            _LanguageOption(
                              title: 'اردو',
                              subtitle: 'Urdu',
                              flag: '🇵🇰',
                              selected:
                                  localeProvider.locale.languageCode == 'ur',
                              onTap: () =>
                                  localeProvider.setLocale(const Locale('ur')),
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            _LanguageOption(
                              title: 'العربية',
                              subtitle: 'Arabic',
                              flag: '🇸🇦',
                              selected:
                                  localeProvider.locale.languageCode == 'ar',
                              onTap: () =>
                                  localeProvider.setLocale(const Locale('ar')),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: AppSpacing.md),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LanguageOption extends StatelessWidget {
  final String title;
  final String subtitle;
  final String flag;
  final bool selected;
  final VoidCallback onTap;

  const _LanguageOption({
    required this.title,
    required this.subtitle,
    required this.flag,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: selected
              ? Theme.of(context).colorScheme.secondary.withOpacity(0.1)
              : Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.4),
          borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
          border: Border.all(
            color: selected
                ? Theme.of(context).colorScheme.secondary
                : Theme.of(context).dividerColor,
            width: selected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Text(flag, style: const TextStyle(fontSize: 24)),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: selected
                          ? Theme.of(context).colorScheme.secondary
                          : Theme.of(context).textTheme.titleMedium?.color,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(
                        context,
                      ).textTheme.bodySmall?.color?.withOpacity(0.8),
                    ),
                  ),
                ],
              ),
            ),
            if (selected)
              Icon(
                Icons.check_circle,
                color: Theme.of(context).colorScheme.secondary,
                size: 20,
              ),
          ],
        ),
      ),
    );
  }
}
