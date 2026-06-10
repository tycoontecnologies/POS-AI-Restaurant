import 'package:flutter/material.dart';
import 'package:pos/components/premium/premium_restaurant_ui.dart';
import 'package:pos/utils/app_colors.dart';
import 'package:pos/utils/app_spacing.dart';

class PremiumModuleScreen extends StatelessWidget {
  final String eyebrow;
  final String title;
  final String subtitle;
  final IconData icon;
  final Color accent;
  final List<PremiumModuleSignal> signals;
  final List<PremiumModuleCapability> capabilities;
  final List<String> workflows;

  const PremiumModuleScreen({
    super.key,
    required this.eyebrow,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accent,
    required this.signals,
    required this.capabilities,
    required this.workflows,
  });

  @override
  Widget build(BuildContext context) {
    return PremiumRestaurantScaffold(
      eyebrow: eyebrow,
      title: title,
      subtitle: subtitle,
      actions: [
        PremiumActionButton(
          label: 'Live view',
          icon: Icons.auto_awesome_outlined,
          onPressed: () {},
          color: accent,
        ),
      ],
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 980;
          final hero = _ModuleHero(
            title: title,
            subtitle: subtitle,
            icon: icon,
            accent: accent,
          );
          final signalGrid = _SignalGrid(signals: signals);
          final capabilityPanel = _CapabilityPanel(
            accent: accent,
            capabilities: capabilities,
          );
          final workflowPanel = _WorkflowPanel(
            accent: accent,
            workflows: workflows,
          );

          if (compact) {
            return SingleChildScrollView(
              child: Column(
                children: [
                  SizedBox(height: 360, child: hero),
                  const SizedBox(height: AppSpacing.lg),
                  SizedBox(height: 360, child: signalGrid),
                  const SizedBox(height: AppSpacing.lg),
                  SizedBox(height: 460, child: capabilityPanel),
                  const SizedBox(height: AppSpacing.lg),
                  SizedBox(height: 380, child: workflowPanel),
                ],
              ),
            );
          }

          return Column(
            children: [
              Expanded(
                flex: 4,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(flex: 5, child: hero),
                    const SizedBox(width: AppSpacing.lg),
                    Expanded(flex: 4, child: signalGrid),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Expanded(
                flex: 5,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(flex: 5, child: capabilityPanel),
                    const SizedBox(width: AppSpacing.lg),
                    Expanded(flex: 4, child: workflowPanel),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class PremiumModuleSignal {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const PremiumModuleSignal({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });
}

class PremiumModuleCapability {
  final String title;
  final String description;
  final IconData icon;

  const PremiumModuleCapability({
    required this.title,
    required this.description,
    required this.icon,
  });
}

class _ModuleHero extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color accent;

  const _ModuleHero({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return PremiumGlassPanel(
      child: Stack(
        children: [
          Positioned(
            right: -34,
            top: -38,
            child: Icon(
              icon,
              size: 190,
              color: accent.withOpacity(0.08),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 66,
                height: 66,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
                  color: accent.withOpacity(0.16),
                  border: Border.all(color: accent.withOpacity(0.32)),
                  boxShadow: [
                    BoxShadow(
                      color: accent.withOpacity(0.22),
                      blurRadius: 32,
                    ),
                  ],
                ),
                child: Icon(icon, color: accent, size: 30),
              ),
              const Spacer(),
              Text(
                title,
                style: const TextStyle(
                  color: AppColors.restaurantInk,
                  fontSize: 34,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -1,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                subtitle,
                style: const TextStyle(
                  color: AppColors.restaurantMuted,
                  fontSize: 15,
                  height: 1.55,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: [
                  PremiumStatusPill(
                    label: 'Premium surface',
                    color: accent,
                    icon: Icons.workspace_premium_outlined,
                  ),
                  const PremiumStatusPill(
                    label: 'Hospitality first',
                    color: AppColors.restaurantEmerald,
                    icon: Icons.room_service_outlined,
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SignalGrid extends StatelessWidget {
  final List<PremiumModuleSignal> signals;

  const _SignalGrid({required this.signals});

  @override
  Widget build(BuildContext context) {
    return PremiumGlassPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const PremiumSectionTitle(
            title: 'Live signals',
            subtitle: 'Operational awareness without spreadsheet noise.',
          ),
          const SizedBox(height: AppSpacing.lg),
          Expanded(
            child: GridView.builder(
              physics: const NeverScrollableScrollPhysics(),
              itemCount: signals.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: AppSpacing.md,
                crossAxisSpacing: AppSpacing.md,
                childAspectRatio: 1.55,
              ),
              itemBuilder: (context, index) {
                final signal = signals[index];
                return Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.055),
                    borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
                    border: Border.all(color: signal.color.withOpacity(0.24)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(signal.icon, color: signal.color, size: 22),
                      const Spacer(),
                      Text(
                        signal.value,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.restaurantInk,
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        signal.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.restaurantMuted,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _CapabilityPanel extends StatelessWidget {
  final Color accent;
  final List<PremiumModuleCapability> capabilities;

  const _CapabilityPanel({
    required this.accent,
    required this.capabilities,
  });

  @override
  Widget build(BuildContext context) {
    return PremiumGlassPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const PremiumSectionTitle(
            title: 'Hospitality workflows',
            subtitle: 'Designed around service moments, not admin forms.',
          ),
          const SizedBox(height: AppSpacing.lg),
          Expanded(
            child: ListView.separated(
              itemCount: capabilities.length,
              separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.md),
              itemBuilder: (context, index) {
                final capability = capabilities[index];
                return Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.055),
                    borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
                    border: Border.all(color: Colors.white.withOpacity(0.08)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: accent.withOpacity(0.14),
                          borderRadius:
                              BorderRadius.circular(AppSpacing.radiusMd),
                        ),
                        child: Icon(capability.icon, color: accent, size: 21),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              capability.title,
                              style: const TextStyle(
                                color: AppColors.restaurantInk,
                                fontWeight: FontWeight.w900,
                                fontSize: 15,
                              ),
                            ),
                            const SizedBox(height: AppSpacing.xs),
                            Text(
                              capability.description,
                              style: const TextStyle(
                                color: AppColors.restaurantMuted,
                                height: 1.45,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _WorkflowPanel extends StatelessWidget {
  final Color accent;
  final List<String> workflows;

  const _WorkflowPanel({
    required this.accent,
    required this.workflows,
  });

  @override
  Widget build(BuildContext context) {
    return PremiumGlassPanel(
      backgroundColor: AppColors.restaurantPanelStrong,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const PremiumSectionTitle(
            title: 'Concierge queue',
            subtitle: 'A calm, prioritized view for managers.',
          ),
          const SizedBox(height: AppSpacing.lg),
          Expanded(
            child: ListView.separated(
              itemCount: workflows.length,
              separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
              itemBuilder: (context, index) {
                return Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
                    border: Border.all(color: Colors.white.withOpacity(0.07)),
                  ),
                  child: Row(
                    children: [
                      Text(
                        '${index + 1}'.padLeft(2, '0'),
                        style: TextStyle(
                          color: accent,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Text(
                          workflows[index],
                          style: const TextStyle(
                            color: AppColors.restaurantInk,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const Icon(
                        Icons.arrow_forward_ios_rounded,
                        color: AppColors.restaurantMuted,
                        size: 14,
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
