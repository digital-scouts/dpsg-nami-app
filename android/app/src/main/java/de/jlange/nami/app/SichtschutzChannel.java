package de.jlange.nami.app;

import android.app.Activity;
import android.os.Build;

import androidx.annotation.NonNull;

import io.flutter.plugin.common.BinaryMessenger;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;

/**
 * Sichtschutz im App-Umschalter bei aktiver App-Sperre: Ab Android 13 nimmt
 * das System dann keine Vorschau des letzten Bildschirms mehr auf.
 * Screenshots bleiben bewusst erlaubt (kein FLAG_SECURE).
 */
final class SichtschutzChannel implements MethodChannel.MethodCallHandler {
  static final String CHANNEL = "com.namiapp/sichtschutz";

  private final Activity activity;

  private SichtschutzChannel(Activity activity) {
    this.activity = activity;
  }

  static void register(@NonNull BinaryMessenger messenger, @NonNull Activity activity) {
    new MethodChannel(messenger, CHANNEL).setMethodCallHandler(new SichtschutzChannel(activity));
  }

  @Override
  public void onMethodCall(@NonNull MethodCall call, @NonNull MethodChannel.Result result) {
    if (!"setzen".equals(call.method)) {
      result.notImplemented();
      return;
    }
    Boolean aktiv = call.argument("aktiv");
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
      activity.setRecentsScreenshotEnabled(!Boolean.TRUE.equals(aktiv));
    }
    result.success(null);
  }
}
