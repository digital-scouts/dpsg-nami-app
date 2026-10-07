package de.jlange.nami.app;

import androidx.annotation.NonNull;

import io.flutter.embedding.android.FlutterFragmentActivity;
import io.flutter.embedding.engine.FlutterEngine;

public class MainActivity extends FlutterFragmentActivity {
  @Override
  public void configureFlutterEngine(@NonNull FlutterEngine flutterEngine) {
    super.configureFlutterEngine(flutterEngine);
    AppIconChannel.register(flutterEngine.getDartExecutor().getBinaryMessenger(), this);
    SichtschutzChannel.register(flutterEngine.getDartExecutor().getBinaryMessenger(), this);
  }
}
