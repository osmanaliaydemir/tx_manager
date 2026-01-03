// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Turkish (`tr`).
class AppLocalizationsTr extends AppLocalizations {
  AppLocalizationsTr([String locale = 'tr']) : super(locale);

  @override
  String get appTitle => 'TX Asistan';

  @override
  String get loginConnect => 'X ile Bağlan';

  @override
  String get loginSubtitle => 'İçerik Stratejini Güçlendir';

  @override
  String get onboardingStep1Title => 'Ana hedefin ne?';

  @override
  String get onboardingStep1Subtitle => 'Önerilerimiz buna göre şekillenecek.';

  @override
  String get goalAuthority => 'Otorite Kurmak';

  @override
  String get goalEngagement => 'Etkileşim Artırmak';

  @override
  String get goalCommunity => 'Topluluk Oluşturmak';

  @override
  String get goalSales => 'Satış Yapmak';
}
