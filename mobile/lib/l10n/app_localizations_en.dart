// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'TX Manager';

  @override
  String get loginConnect => 'Connect with X';

  @override
  String get loginSubtitle => 'Supercharge your strategy';

  @override
  String get onboardingStep1Title => 'What is your main goal?';

  @override
  String get onboardingStep1Subtitle =>
      'We will tailor suggestions based on this.';

  @override
  String get goalAuthority => 'Build Authority';

  @override
  String get goalEngagement => 'Spark Conversation';

  @override
  String get goalCommunity => 'Build Community';

  @override
  String get goalSales => 'Drive Sales';
}
