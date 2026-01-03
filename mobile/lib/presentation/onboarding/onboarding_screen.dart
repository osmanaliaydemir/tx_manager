import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tx_manager_mobile/core/theme/app_theme.dart';
import 'package:tx_manager_mobile/data/repositories/strategy_repository.dart';
import 'package:tx_manager_mobile/domain/entities/strategy.dart';
import 'package:tx_manager_mobile/l10n/app_localizations.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  StrategyGoal? _selectedGoal;
  ToneVoice? _selectedTone;

  bool _isSaving = false;

  void _nextPage() {
    _pageController.nextPage(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  Future<void> _completeOnboarding() async {
    if (_selectedGoal == null || _selectedTone == null) return;

    setState(() => _isSaving = true);

    // Default Locale from System, or User choice. For now hardcode 'tr' if context is tr.
    // Ideally we ask user. Assuming 'tr' based on current locale.
    final locale = Localizations.localeOf(context).languageCode;

    final strategy = UserStrategy(
      primaryGoal: _selectedGoal!,
      tone: _selectedTone!,
      forbiddenTopics: "", // Optional for now
      language: locale,
      postsPerDay: 3,
    );

    try {
      await ref.read(strategyRepositoryProvider).saveStrategy(strategy);
      if (mounted) context.go('/home');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Error: $e")));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Progress Indicator
            LinearProgressIndicator(
              value: (_currentPage + 1) / 3,
              backgroundColor: AppTheme.surfaceColor,
              valueColor: const AlwaysStoppedAnimation(AppTheme.primaryColor),
            ),
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(), // Disable swipe
                onPageChanged: (i) => setState(() => _currentPage = i),
                children: [
                  // Step 1: Goal
                  _buildStep(
                    title: l10n.onboardingStep1Title,
                    subtitle: l10n.onboardingStep1Subtitle,
                    content: Column(
                      children: StrategyGoal.values.map((goal) {
                        final isSelected = _selectedGoal == goal;
                        return _buildOptionCard(
                          title: _getGoalTitle(goal, l10n),
                          isSelected: isSelected,
                          onTap: () => setState(() => _selectedGoal = goal),
                        );
                      }).toList(),
                    ),
                    canProceed: _selectedGoal != null,
                    onNext: _nextPage,
                  ),

                  // Step 2: Tone
                  _buildStep(
                    title: l10n.onboardingStep2Title,
                    subtitle: l10n.onboardingStep2Subtitle,
                    content: Column(
                      children: ToneVoice.values.map((tone) {
                        final isSelected = _selectedTone == tone;
                        return _buildOptionCard(
                          title: _getToneTitle(tone, l10n),
                          isSelected: isSelected,
                          onTap: () => setState(() => _selectedTone = tone),
                        );
                      }).toList(),
                    ),
                    canProceed: _selectedTone != null,
                    onNext: _completeOnboarding,
                    isLast: true,
                  ),

                  // Step 3 (Optional or Loading) - Skipping for simplicity -> 2 Steps
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ... (existing _buildStep and _buildOptionCard, no changes needed) ...
  Widget _buildStep({
    required String title,
    required String subtitle,
    required Widget content,
    required bool canProceed,
    required VoidCallback onNext,
    bool isLast = false,
  }) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.displayLarge?.copyWith(fontSize: 28),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(fontSize: 16),
          ),
          const SizedBox(height: 32),
          Expanded(child: SingleChildScrollView(child: content)),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: canProceed && !_isSaving ? onNext : null,
              child: _isSaving
                  ? const CircularProgressIndicator(color: Colors.white)
                  : Text(isLast ? "Tamamla" : "Devam Et"),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOptionCard({
    required String title,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.primaryColor.withValues(alpha: 0.2)
              : AppTheme.surfaceColor,
          border: Border.all(
            color: isSelected ? AppTheme.primaryColor : Colors.transparent,
            width: 2,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
            if (isSelected)
              const Icon(Icons.check_circle, color: AppTheme.primaryColor),
          ],
        ),
      ),
    );
  }

  String _getGoalTitle(StrategyGoal goal, AppLocalizations l10n) {
    switch (goal) {
      case StrategyGoal.authority:
        return l10n.goalAuthority;
      case StrategyGoal.engagement:
        return l10n.goalEngagement;
      case StrategyGoal.community:
        return l10n.goalCommunity;
      case StrategyGoal.sales:
        return l10n.goalSales;
    }
  }

  String _getToneTitle(ToneVoice tone, AppLocalizations l10n) {
    switch (tone) {
      case ToneVoice.professional:
        return l10n.toneProfessional;
      case ToneVoice.friendly:
        return l10n.toneFriendly;
      case ToneVoice.witty:
        return l10n.toneWitty;
      case ToneVoice.minimalist:
        return l10n.toneMinimalist;
      case ToneVoice.provocative:
        return l10n.toneProvocative;
    }
  }
}
