import 'package:in_app_review/in_app_review.dart';

/// App-Store-ID der App, fuer den Link zur Bewertungsseite.
const String appStoreId = '6468066816';

/// Duenne Huelle um in_app_review, damit Tests ohne Plattformkanaele
/// auskommen.
abstract interface class StoreReviewClient {
  /// Ob der System-Bewertungsdialog auf diesem Geraet verfuegbar ist.
  Future<bool> isAvailable();

  /// Fragt den System-Bewertungsdialog an (iOS: SKStoreReviewController,
  /// Android: Google-Play-In-App-Review). Ob er erscheint, entscheidet das
  /// System.
  Future<void> requestReview();

  /// Oeffnet den Store-Eintrag der App; auf iOS direkt die Bewertungsseite.
  Future<void> openStoreListing();
}

class InAppReviewStoreReviewClient implements StoreReviewClient {
  InAppReviewStoreReviewClient({InAppReview? inAppReview})
    : _inAppReview = inAppReview ?? InAppReview.instance;

  final InAppReview _inAppReview;

  @override
  Future<bool> isAvailable() => _inAppReview.isAvailable();

  @override
  Future<void> requestReview() => _inAppReview.requestReview();

  @override
  Future<void> openStoreListing() =>
      _inAppReview.openStoreListing(appStoreId: appStoreId);
}
