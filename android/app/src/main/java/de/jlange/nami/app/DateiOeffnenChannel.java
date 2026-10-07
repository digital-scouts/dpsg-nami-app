package de.jlange.nami.app;

import android.app.Activity;
import android.content.ActivityNotFoundException;
import android.content.Intent;
import android.net.Uri;

import androidx.annotation.NonNull;
import androidx.core.content.FileProvider;

import java.io.File;

import io.flutter.plugin.common.BinaryMessenger;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;

/**
 * Öffnet eine PDF aus dem Teilen-Ordner mit ACTION_VIEW. Lesezugriff
 * erhält nur die App, die die Anfrage annimmt, und nur für diese Datei;
 * kein Schreibrecht und keine Freigabe an alle PDF-Apps (A-74).
 */
final class DateiOeffnenChannel implements MethodChannel.MethodCallHandler {
  static final String CHANNEL = "com.namiapp/datei_oeffnen";

  private final Activity activity;

  private DateiOeffnenChannel(Activity activity) {
    this.activity = activity;
  }

  static void register(@NonNull BinaryMessenger messenger, @NonNull Activity activity) {
    new MethodChannel(messenger, CHANNEL).setMethodCallHandler(new DateiOeffnenChannel(activity));
  }

  @Override
  public void onMethodCall(@NonNull MethodCall call, @NonNull MethodChannel.Result result) {
    if (!"pdfOeffnen".equals(call.method)) {
      result.notImplemented();
      return;
    }
    String pfad = call.argument("pfad");
    if (pfad == null) {
      result.error("pfad_fehlt", "Kein Dateipfad angegeben", null);
      return;
    }
    try {
      Uri uri = FileProvider.getUriForFile(
          activity, activity.getPackageName() + ".teilen", new File(pfad));
      Intent intent = new Intent(Intent.ACTION_VIEW)
          .setDataAndType(uri, "application/pdf")
          .addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION);
      activity.startActivity(intent);
      result.success(true);
    } catch (ActivityNotFoundException | IllegalArgumentException e) {
      result.success(false);
    }
  }
}
