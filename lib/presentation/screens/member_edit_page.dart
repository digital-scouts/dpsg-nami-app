import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../domain/member/mitglied.dart';
import '../model/auth_session_model.dart';
import '../model/member_edit_model.dart';

class MemberEditPage extends StatefulWidget {
  const MemberEditPage({super.key, required this.mitglied});

  final Mitglied mitglied;

  @override
  State<MemberEditPage> createState() => _MemberEditPageState();
}

class _MemberEditPageState extends State<MemberEditPage> {
  static final DateFormat _dateFormat = DateFormat('dd.MM.yyyy');
  static const List<String> _defaultGenderValues = <String>[
    'w',
    'm',
    'divers',
    'keine_angabe',
  ];
  static const Map<String, String> _genderLabels = <String, String>{
    'w': 'Weiblich',
    'm': 'Männlich',
    'divers': 'Divers',
    'keine_angabe': 'Keine Angabe',
  };

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _vornameController;
  late final TextEditingController _nachnameController;
  late final TextEditingController _fahrtennameController;
  late final TextEditingController _primaryEmailController;
  late DateTime _geburtsdatum;
  late String? _gender;
  late final _AddressDraft _primaryAddressDraft;
  late final List<_PhoneDraft> _phoneDrafts;
  late final List<_EmailDraft> _additionalEmailDrafts;
  late final List<_AddressDraft> _additionalAddressDrafts;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    final primaryEmail = _resolvePrimaryEmail(widget.mitglied.emailAdressen);
    final primaryAddress = _resolvePrimaryAddress(widget.mitglied.adressen);
    _vornameController = TextEditingController(text: widget.mitglied.vorname);
    _nachnameController = TextEditingController(text: widget.mitglied.nachname);
    _fahrtennameController = TextEditingController(
      text: widget.mitglied.fahrtenname ?? '',
    );
    _primaryEmailController = TextEditingController(
      text: primaryEmail?.wert ?? '',
    );
    _geburtsdatum = widget.mitglied.geburtsdatum;
    _gender = _normalizeGenderValue(widget.mitglied.gender);
    _primaryAddressDraft = _AddressDraft.fromAdresse(
      primaryAddress ?? const MitgliedKontaktAdresse(additionalAddressId: 0),
    );
    _phoneDrafts = widget.mitglied.telefonnummern
        .map(_PhoneDraft.fromTelefon)
        .toList(growable: true);
    _additionalEmailDrafts = widget.mitglied.emailAdressen
        .where((email) => !email.istPrimaer)
        .map(_EmailDraft.fromEmail)
        .toList(growable: true);
    _additionalAddressDrafts = widget.mitglied.adressen
        .where((adresse) => (adresse.additionalAddressId ?? 0) != 0)
        .map(_AddressDraft.fromAdresse)
        .toList(growable: true);
  }

  @override
  void dispose() {
    _vornameController.dispose();
    _nachnameController.dispose();
    _fahrtennameController.dispose();
    _primaryEmailController.dispose();
    _primaryAddressDraft.dispose();
    for (final draft in _phoneDrafts) {
      draft.dispose();
    }
    for (final draft in _additionalEmailDrafts) {
      draft.dispose();
    }
    for (final draft in _additionalAddressDrafts) {
      draft.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Person bearbeiten')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _SectionCard(
              title: 'Allgemein',
              child: Column(
                children: [
                  _buildTextField(
                    _vornameController,
                    'Vorname',
                    required: true,
                  ),
                  const SizedBox(height: 12),
                  _buildTextField(
                    _nachnameController,
                    'Nachname',
                    required: true,
                  ),
                  const SizedBox(height: 12),
                  _buildTextField(_fahrtennameController, 'Fahrtenname'),
                  const SizedBox(height: 12),
                  _buildGenderField(),
                  const SizedBox(height: 12),
                  _buildDateField(
                    label: 'Geburtsdatum',
                    value: _geburtsdatum,
                    onChanged: (value) {
                      if (value == null) {
                        return;
                      }
                      setState(() => _geburtsdatum = value);
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _SectionCard(
              title: 'Kontakt',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _ContactGroup(
                    title: 'E-Mail',
                    child: Column(
                      children: [
                        _buildTextField(
                          _primaryEmailController,
                          'Primäre E-Mail',
                          keyboardType: TextInputType.emailAddress,
                        ),
                        const SizedBox(height: 16),
                        _buildAdditionalEmailSection(),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  _ContactGroup(title: 'Telefon', child: _buildPhoneSection()),
                  const SizedBox(height: 16),
                  _ContactGroup(
                    title: 'Adressen',
                    child: Column(
                      children: [
                        _buildAddressSection(
                          title: 'Primäradresse',
                          drafts: <_AddressDraft>[_primaryAddressDraft],
                          removable: false,
                        ),
                        const SizedBox(height: 16),
                        _buildAddressSection(
                          title: 'Zusatzadressen',
                          drafts: _additionalAddressDrafts,
                          removable: true,
                          onAdd: () {
                            setState(() {
                              _additionalAddressDrafts.add(
                                _AddressDraft.empty(),
                              );
                            });
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _isSubmitting ? null : _save,
              icon: _isSubmitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save_outlined),
              label: Text(_isSubmitting ? 'Speichert...' : 'Speichern'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPhoneSection() {
    return _RepeatingSection(
      title: 'Telefonnummern',
      addLabel: 'Telefon hinzufügen',
      onAdd: () {
        setState(() {
          _phoneDrafts.add(_PhoneDraft.empty());
        });
      },
      children: [
        for (var index = 0; index < _phoneDrafts.length; index++)
          _buildPhoneDraft(index, _phoneDrafts[index]),
      ],
    );
  }

  Widget _buildAdditionalEmailSection() {
    return _RepeatingSection(
      title: 'Zusatzmails',
      addLabel: 'Zusatzmail hinzufügen',
      onAdd: () {
        setState(() {
          _additionalEmailDrafts.add(_EmailDraft.empty());
        });
      },
      children: [
        for (var index = 0; index < _additionalEmailDrafts.length; index++)
          _buildAdditionalEmailDraft(index, _additionalEmailDrafts[index]),
      ],
    );
  }

  Widget _buildAddressSection({
    required String title,
    required List<_AddressDraft> drafts,
    required bool removable,
    VoidCallback? onAdd,
  }) {
    return _RepeatingSection(
      title: title,
      addLabel: onAdd == null ? null : 'Adresse hinzufügen',
      onAdd: onAdd,
      children: [
        for (var index = 0; index < drafts.length; index++)
          _buildAddressDraft(index, drafts[index], removable: removable),
      ],
    );
  }

  Widget _buildPhoneDraft(int index, _PhoneDraft draft) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            _buildTextField(
              draft.wertController,
              'Nummer',
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 12),
            _buildTextField(draft.labelController, 'Label'),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () {
                  setState(() {
                    final removed = _phoneDrafts.removeAt(index);
                    removed.dispose();
                  });
                },
                icon: const Icon(Icons.delete_outline),
                label: const Text('Entfernen'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAdditionalEmailDraft(int index, _EmailDraft draft) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            _buildTextField(
              draft.wertController,
              'E-Mail',
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 12),
            _buildTextField(draft.labelController, 'Label'),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () {
                  setState(() {
                    final removed = _additionalEmailDrafts.removeAt(index);
                    removed.dispose();
                  });
                },
                icon: const Icon(Icons.delete_outline),
                label: const Text('Entfernen'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAddressDraft(
    int index,
    _AddressDraft draft, {
    required bool removable,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            _buildTextField(draft.labelController, 'Label'),
            const SizedBox(height: 12),
            _buildTextField(draft.addressCareOfController, 'Adresszusatz'),
            const SizedBox(height: 12),
            _buildTextField(draft.streetController, 'Straße'),
            const SizedBox(height: 12),
            _buildTextField(draft.housenumberController, 'Hausnummer'),
            const SizedBox(height: 12),
            _buildTextField(draft.postboxController, 'Postfach'),
            const SizedBox(height: 12),
            _buildTextField(draft.zipCodeController, 'PLZ'),
            const SizedBox(height: 12),
            _buildTextField(draft.townController, 'Ort'),
            const SizedBox(height: 12),
            _buildTextField(draft.countryController, 'Land'),
            if (removable)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: () {
                    setState(() {
                      final removed = _additionalAddressDrafts.removeAt(index);
                      removed.dispose();
                    });
                  },
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('Entfernen'),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(
    TextEditingController controller,
    String label, {
    bool required = false,
    TextInputType? keyboardType,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
      validator: required
          ? (value) {
              final trimmed = value?.trim() ?? '';
              if (trimmed.isEmpty) {
                return '$label darf nicht leer sein.';
              }
              return null;
            }
          : null,
    );
  }

  Widget _buildGenderField() {
    final items = _buildGenderItems();
    return DropdownButtonFormField<String>(
      initialValue: _gender,
      decoration: const InputDecoration(
        labelText: 'Geschlecht',
        border: OutlineInputBorder(),
      ),
      items: items
          .map(
            (value) => DropdownMenuItem<String>(
              value: value,
              child: Text(_labelForGender(value)),
            ),
          )
          .toList(growable: false),
      onChanged: (value) {
        setState(() {
          _gender = _normalizeGenderValue(value);
        });
      },
    );
  }

  Widget _buildDateField({
    required String label,
    required DateTime? value,
    required ValueChanged<DateTime?> onChanged,
    bool allowClear = false,
  }) {
    return InkWell(
      onTap: () async {
        final selected = await showDatePicker(
          context: context,
          initialDate: value ?? DateTime.now(),
          firstDate: DateTime(1900),
          lastDate: DateTime(2100),
          locale: const Locale('de'),
        );
        if (selected != null) {
          onChanged(selected);
        }
      },
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          suffixIcon: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (allowClear && value != null)
                IconButton(
                  onPressed: () => onChanged(null),
                  icon: const Icon(Icons.clear),
                ),
              const Padding(
                padding: EdgeInsets.only(right: 12),
                child: Icon(Icons.calendar_today_outlined),
              ),
            ],
          ),
        ),
        child: Text(
          value == null ? 'Nicht gesetzt' : _dateFormat.format(value),
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final authModel = context.read<AuthSessionModel?>();
    final memberEditModel = context.read<MemberEditModel?>();
    final accessToken = authModel?.session?.accessToken;
    if (memberEditModel == null || accessToken == null || accessToken.isEmpty) {
      _showMessage(
        'Aktuell ist keine gueltige Sitzung zum Speichern verfuegbar.',
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final targetMember = _buildTargetMember();
      final result = await memberEditModel.submitUpdate(
        accessToken: accessToken,
        basisMitglied: widget.mitglied,
        zielMitglied: targetMember,
        trigger: 'manual_edit',
      );
      if (!mounted) {
        return;
      }
      if (result.success || result.wasQueued) {
        Navigator.of(context).pop(result);
        return;
      }
      _showMessage(result.message ?? 'Speichern fehlgeschlagen.');
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  Mitglied _buildTargetMember() {
    final primaryEmail = _trimToNull(_primaryEmailController.text);
    final emails = <MitgliedKontaktEmail>[
      if (primaryEmail != null)
        MitgliedKontaktEmail(
          wert: primaryEmail,
          label: Mitglied.primaryEmailLabel,
          istPrimaer: true,
        ),
      ..._additionalEmailDrafts
          .map((draft) => draft.toEmail())
          .where((email) => email != null)
          .cast<MitgliedKontaktEmail>(),
    ];
    final phones = _phoneDrafts
        .map((draft) => draft.toTelefon())
        .where((telefon) => telefon != null)
        .cast<MitgliedKontaktTelefon>()
        .toList(growable: false);
    final primaryAddress = _primaryAddressDraft.toAdresse().copyWith(
      additionalAddressId: 0,
    );
    final additionalAddresses = _additionalAddressDrafts
        .map((draft) => draft.toAdresse())
        .where((adresse) => !adresse.istLeer)
        .toList(growable: false);

    return widget.mitglied.copyWith(
      vorname: _vornameController.text.trim(),
      nachname: _nachnameController.text.trim(),
      fahrtenname: _trimToNull(_fahrtennameController.text),
      fahrtennameLoeschen: _trimToNull(_fahrtennameController.text) == null,
      geburtsdatum: _geburtsdatum,
      gender: _gender,
      genderLoeschen: _gender == null,
      telefonnummern: phones,
      emailAdressen: emails,
      adressen: <MitgliedKontaktAdresse>[
        primaryAddress,
        ...additionalAddresses,
      ],
    );
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  MitgliedKontaktEmail? _resolvePrimaryEmail(
    List<MitgliedKontaktEmail> emails,
  ) {
    for (final email in emails) {
      if (email.istPrimaer) {
        return email;
      }
    }
    return emails.isEmpty ? null : emails.first;
  }

  MitgliedKontaktAdresse? _resolvePrimaryAddress(
    List<MitgliedKontaktAdresse> adressen,
  ) {
    for (final adresse in adressen) {
      if ((adresse.additionalAddressId ?? 0) == 0) {
        return adresse;
      }
    }
    return adressen.isEmpty ? null : adressen.first;
  }

  List<String> _buildGenderItems() {
    final items = <String>[..._defaultGenderValues];
    final currentGender = _gender;
    if (currentGender != null && !items.contains(currentGender)) {
      items.add(currentGender);
    }
    return items;
  }

  String? _normalizeGenderValue(String? value) {
    return _trimToNull(value ?? '');
  }

  String _labelForGender(String value) {
    return _genderLabels[value] ?? value;
  }
}

String? _trimToNull(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) {
    return null;
  }
  return trimmed;
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }
}

class _ContactGroup extends StatelessWidget {
  const _ContactGroup({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _RepeatingSection extends StatelessWidget {
  const _RepeatingSection({
    required this.title,
    required this.children,
    this.addLabel,
    this.onAdd,
  });

  final String title;
  final List<Widget> children;
  final String? addLabel;
  final VoidCallback? onAdd;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(title, style: Theme.of(context).textTheme.titleSmall),
            ),
            if (addLabel != null && onAdd != null)
              TextButton.icon(
                onPressed: onAdd,
                icon: const Icon(Icons.add),
                label: Text(addLabel!),
              ),
          ],
        ),
        if (children.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text('Keine Einträge.'),
          ),
        ...children,
      ],
    );
  }
}

class _PhoneDraft {
  _PhoneDraft({required this.phoneNumberId, String? wert, String? label})
    : wertController = TextEditingController(text: wert ?? ''),
      labelController = TextEditingController(text: label ?? '');

  factory _PhoneDraft.fromTelefon(MitgliedKontaktTelefon telefon) {
    return _PhoneDraft(
      phoneNumberId: telefon.phoneNumberId,
      wert: telefon.wert,
      label: telefon.label,
    );
  }

  factory _PhoneDraft.empty() => _PhoneDraft(phoneNumberId: null);

  final int? phoneNumberId;
  final TextEditingController wertController;
  final TextEditingController labelController;

  MitgliedKontaktTelefon? toTelefon() {
    final wert = _trimToNull(wertController.text);
    if (wert == null) {
      return null;
    }
    return MitgliedKontaktTelefon(
      phoneNumberId: phoneNumberId,
      wert: wert,
      label: _trimToNull(labelController.text),
    );
  }

  void dispose() {
    wertController.dispose();
    labelController.dispose();
  }
}

class _EmailDraft {
  _EmailDraft({required this.additionalEmailId, String? wert, String? label})
    : wertController = TextEditingController(text: wert ?? ''),
      labelController = TextEditingController(text: label ?? '');

  factory _EmailDraft.fromEmail(MitgliedKontaktEmail email) {
    return _EmailDraft(
      additionalEmailId: email.additionalEmailId,
      wert: email.wert,
      label: email.label,
    );
  }

  factory _EmailDraft.empty() => _EmailDraft(additionalEmailId: null);

  final int? additionalEmailId;
  final TextEditingController wertController;
  final TextEditingController labelController;

  MitgliedKontaktEmail? toEmail() {
    final wert = _trimToNull(wertController.text);
    if (wert == null) {
      return null;
    }
    return MitgliedKontaktEmail(
      additionalEmailId: additionalEmailId,
      wert: wert,
      label: _trimToNull(labelController.text),
    );
  }

  void dispose() {
    wertController.dispose();
    labelController.dispose();
  }
}

class _AddressDraft {
  _AddressDraft({
    required this.additionalAddressId,
    String? label,
    String? addressCareOf,
    String? street,
    String? housenumber,
    String? postbox,
    String? zipCode,
    String? town,
    String? country,
  }) : labelController = TextEditingController(text: label ?? ''),
       addressCareOfController = TextEditingController(
         text: addressCareOf ?? '',
       ),
       streetController = TextEditingController(text: street ?? ''),
       housenumberController = TextEditingController(text: housenumber ?? ''),
       postboxController = TextEditingController(text: postbox ?? ''),
       zipCodeController = TextEditingController(text: zipCode ?? ''),
       townController = TextEditingController(text: town ?? ''),
       countryController = TextEditingController(text: country ?? '');

  factory _AddressDraft.fromAdresse(MitgliedKontaktAdresse adresse) {
    return _AddressDraft(
      additionalAddressId: adresse.additionalAddressId,
      label: adresse.label,
      addressCareOf: adresse.addressCareOf,
      street: adresse.street,
      housenumber: adresse.housenumber,
      postbox: adresse.postbox,
      zipCode: adresse.zipCode,
      town: adresse.town,
      country: adresse.country,
    );
  }

  factory _AddressDraft.empty() => _AddressDraft(additionalAddressId: null);

  final int? additionalAddressId;
  final TextEditingController labelController;
  final TextEditingController addressCareOfController;
  final TextEditingController streetController;
  final TextEditingController housenumberController;
  final TextEditingController postboxController;
  final TextEditingController zipCodeController;
  final TextEditingController townController;
  final TextEditingController countryController;

  MitgliedKontaktAdresse toAdresse() {
    return MitgliedKontaktAdresse(
      additionalAddressId: additionalAddressId,
      label: _trimToNull(labelController.text),
      addressCareOf: _trimToNull(addressCareOfController.text),
      street: _trimToNull(streetController.text),
      housenumber: _trimToNull(housenumberController.text),
      postbox: _trimToNull(postboxController.text),
      zipCode: _trimToNull(zipCodeController.text),
      town: _trimToNull(townController.text),
      country: _trimToNull(countryController.text),
    );
  }

  void dispose() {
    labelController.dispose();
    addressCareOfController.dispose();
    streetController.dispose();
    housenumberController.dispose();
    postboxController.dispose();
    zipCodeController.dispose();
    townController.dispose();
    countryController.dispose();
  }
}
