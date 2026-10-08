package de.jlange.nami.app;

import android.content.ComponentName;
import android.content.Context;
import android.content.pm.PackageManager;

import androidx.annotation.NonNull;

import io.flutter.plugin.common.BinaryMessenger;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;

/**
 * Wechselt das Launcher-Icon, indem genau ein activity-alias aus dem Manifest
 * aktiviert wird. Namen entsprechen AppIconChoice.key auf der Dart-Seite,
 * z. B. "NachthimmelMorgen" -> ".IconNachthimmelMorgen"; null -> ".IconDefault".
 */
final class AppIconChannel implements MethodChannel.MethodCallHandler {
  static final String CHANNEL = "com.namiapp/app_icon";

  private static final String DEFAULT_ALIAS = "Default";
  private static final String[] ALIASES = {
    DEFAULT_ALIAS,
    "NachthimmelMorgen", "NachthimmelAbend", "NachthimmelNacht",
    "LagerfeuerMorgen", "LagerfeuerAbend", "LagerfeuerNacht",
    "WaldseeMorgen", "WaldseeAbend", "WaldseeNacht",
  };

  private final Context context;

  private AppIconChannel(Context context) {
    this.context = context.getApplicationContext();
  }

  static void register(@NonNull BinaryMessenger messenger, @NonNull Context context) {
    new MethodChannel(messenger, CHANNEL).setMethodCallHandler(new AppIconChannel(context));
  }

  @Override
  public void onMethodCall(@NonNull MethodCall call, @NonNull MethodChannel.Result result) {
    switch (call.method) {
      case "isSupported":
        result.success(true);
        break;
      case "setIcon":
        String requested = call.argument("name");
        String target = requested == null ? DEFAULT_ALIAS : requested;
        if (!isKnown(target)) {
          result.error("unknown_icon", "Unbekanntes App-Icon: " + target, null);
          return;
        }
        applyAlias(target);
        result.success(null);
        break;
      default:
        result.notImplemented();
    }
  }

  private static boolean isKnown(String name) {
    for (String alias : ALIASES) {
      if (alias.equals(name)) {
        return true;
      }
    }
    return false;
  }

  // Erst das Ziel aktivieren, dann die anderen deaktivieren, damit nie kein
  // Launcher-Eintrag existiert. DONT_KILL_APP verhindert einen Neustart.
  private void applyAlias(String target) {
    PackageManager pm = context.getPackageManager();
    setEnabled(pm, target, true);
    for (String alias : ALIASES) {
      if (!alias.equals(target)) {
        setEnabled(pm, alias, false);
      }
    }
  }

  private void setEnabled(PackageManager pm, String alias, boolean enabled) {
    ComponentName component =
        new ComponentName(context.getPackageName(), "de.jlange.nami.app.Icon" + alias);
    int state =
        enabled
            ? PackageManager.COMPONENT_ENABLED_STATE_ENABLED
            : PackageManager.COMPONENT_ENABLED_STATE_DISABLED;
    if (pm.getComponentEnabledSetting(component) != state) {
      pm.setComponentEnabledSetting(component, state, PackageManager.DONT_KILL_APP);
    }
  }
}
