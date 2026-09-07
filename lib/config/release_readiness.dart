import 'app_config.dart';

/// A single unmet requirement that must be resolved before shipping a
/// production build to end users.
class ReleaseBlocker {
  const ReleaseBlocker(this.id, this.summary, this.fix);

  /// Stable identifier, handy for tests and CI assertions.
  final String id;

  /// What is missing, in plain language.
  final String summary;

  /// How the operator resolves it.
  final String fix;
}

/// Compile-time / runtime gate for legal and business configuration.
///
/// Journey360 is intentionally shippable in an "offline" demo mode with none of
/// this set, but a real public release must name a contactable operator and a
/// privacy contact. [blockers] is surfaced in Settings and asserted in debug
/// builds so the gap cannot silently reach production.
class ReleaseReadiness {
  const ReleaseReadiness._();

  static List<ReleaseBlocker> get blockers {
    final out = <ReleaseBlocker>[];

    if (AppConfig.businessName.isEmpty) {
      out.add(const ReleaseBlocker(
        'business_name',
        'Registered business / operator name is not set.',
        'Pass --dart-define=BUSINESS_NAME="<registered name>" at build time.',
      ));
    }
    if (AppConfig.businessAddress.isEmpty) {
      out.add(const ReleaseBlocker(
        'business_address',
        'Business address is not set.',
        'Pass --dart-define=BUSINESS_ADDRESS="<principal place of business>".',
      ));
    }
    if (AppConfig.privacyEmail.isEmpty) {
      out.add(const ReleaseBlocker(
        'privacy_email',
        'Privacy / data-protection contact is not set.',
        'Pass --dart-define=PRIVACY_EMAIL="<monitored inbox>". Required by the '
            'Philippine Data Privacy Act for data-subject requests.',
      ));
    }
    if (AppConfig.supportEmail.isEmpty) {
      out.add(const ReleaseBlocker(
        'support_email',
        'User support contact is not set.',
        'Pass --dart-define=SUPPORT_EMAIL="<monitored inbox>".',
      ));
    }
    if (!AppConfig.hasSupabase) {
      out.add(const ReleaseBlocker(
        'backend',
        'No Supabase backend configured; accounts and circles are disabled.',
        'Set SUPABASE_URL and SUPABASE_PUBLISHABLE_KEY, or ship deliberately as '
            'an offline-only build.',
      ));
    }

    return out;
  }

  static bool get isProductionReady => blockers.isEmpty;
}
