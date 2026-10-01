/// Hitobito-Berechtigungen (`permissions` einer Rolle aus `/oauth/profile`),
/// gruppiert nach ihrer Reichweite.
class HitobitoBerechtigungen {
  const HitobitoBerechtigungen._();

  /// Lesen des ganzen Layers der Rolle.
  static const Set<String> layerLesen = <String>{'layer_read', 'layer_full'};

  /// Lesen des Layers der Rolle und aller Layer darunter.
  static const Set<String> layerUndDarunterLesen = <String>{
    'layer_and_below_read',
    'layer_and_below_full',
  };

  /// Lesen nur der Gruppe der Rolle.
  static const Set<String> gruppeLesen = <String>{'group_read', 'group_full'};

  /// Lesen der Gruppe der Rolle und ihrer Untergruppen.
  static const Set<String> gruppeUndDarunterLesen = <String>{
    'group_and_below_read',
    'group_and_below_full',
  };

  static const Set<String> layerSchreiben = <String>{'layer_full'};
  static const Set<String> layerUndDarunterSchreiben = <String>{
    'layer_and_below_full',
  };
  static const Set<String> gruppeSchreiben = <String>{'group_full'};
  static const Set<String> gruppeUndDarunterSchreiben = <String>{
    'group_and_below_full',
  };

  static Set<String> normalisiere(Iterable<String> permissions) =>
      permissions.map((permission) => permission.trim().toLowerCase()).toSet();
}
