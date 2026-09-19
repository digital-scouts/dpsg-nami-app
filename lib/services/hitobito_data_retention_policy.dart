class HitobitoDataRetentionPolicy {
  HitobitoDataRetentionPolicy({
    required this.maxDataAge,
    required this.refreshInterval,
    DateTime Function()? nowProvider,
  }) : now = nowProvider ?? DateTime.now;

  final Duration maxDataAge;
  final Duration refreshInterval;
  final DateTime Function() now;

  bool isReloginRequired(DateTime? lastVerifiedAt) {
    if (lastVerifiedAt == null) {
      return false;
    }
    return now().difference(lastVerifiedAt) >= maxDataAge;
  }

  bool isRefreshDue(DateTime? lastVerifiedAt) {
    if (lastVerifiedAt == null) {
      return true;
    }
    return now().difference(lastVerifiedAt) >= refreshInterval;
  }

  Duration? remainingUntilRelogin(DateTime? lastVerifiedAt) {
    if (lastVerifiedAt == null) {
      return null;
    }

    final remaining = maxDataAge - now().difference(lastVerifiedAt);
    if (remaining.isNegative) {
      return Duration.zero;
    }
    return remaining;
  }
}
