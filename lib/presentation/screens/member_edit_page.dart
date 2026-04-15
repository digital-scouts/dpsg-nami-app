import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../domain/member/mitglied.dart';
import '../model/auth_session_model.dart';
import '../model/member_edit_model.dart';
import '../model/member_phone_input.dart';
import '../notifications/app_snackbar.dart';

class MemberEditPage extends StatefulWidget {
  const MemberEditPage({
    super.key,
    required this.mitglied,
    this.initialNoticeMessage,
  });

  final Mitglied mitglied;
  final String? initialNoticeMessage;

  @override
  State<MemberEditPage> createState() => _MemberEditPageState();
}

class _MemberEditPageState extends State<MemberEditPage> {
  static final DateFormat _dateFormat = DateFormat('dd.MM.yyyy');
  static const double _pagePadding = 10;
  static const double _cardRadius = 16;
  static const List<String> _defaultGenderValues = <String>['w', 'm', ''];
  static const Map<String, String> _genderLabels = <String, String>{
    'w': 'Weiblich',
    'm': 'Männlich',
    '': 'Unbekannt',
  };

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _vornameController;
  late final TextEditingController _nachnameController;
  late final TextEditingController _fahrtennameController;
  late final TextEditingController _primaryEmailController;
  late DateTime? _geburtsdatum;
  late String? _gender;
  late final _AddressDraft _primaryAddressDraft;
  late final List<_PhoneDraft> _phoneDrafts;
  late final List<_EmailDraft> _additionalEmailDrafts;
  late final List<_AddressDraft> _additionalAddressDrafts;
  final Map<int, String> _serverPhoneErrorsById = <int, String>{};
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
    _geburtsdatum =
        widget.mitglied.geburtsdatum == Mitglied.peoplePlaceholderDate
        ? null
        : widget.mitglied.geburtsdatum;
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

    final initialNoticeMessage = widget.initialNoticeMessage;
    if (initialNoticeMessage != null && initialNoticeMessage.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }
        _showMessage(initialNoticeMessage);
      });
    }
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
      body: Column(
        children: [
          Expanded(
            child: Form(
              key: _formKey,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final horizontalPadding = switch (constraints.maxWidth) {
                    >= 1100 => 24.0,
                    >= 700 => 16.0,
                    _ => _pagePadding,
                  };

                  return ListView(
                    padding: EdgeInsets.fromLTRB(
                      horizontalPadding,
                      _pagePadding,
                      horizontalPadding,
                      18,
                    ),
                    children: [
                      Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 1320),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _SectionCard(
                                title: 'Allgemein',
                                child: _buildGeneralSection(),
                              ),
                              const SizedBox(height: 10),
                              _SectionCard(
                                title: 'E-Mail',
                                child: _buildEmailSection(),
                              ),
                              const SizedBox(height: 10),
                              _SectionCard(
                                title: 'Telefon',
                                child: _buildPhoneSection(),
                              ),
                              const SizedBox(height: 10),
                              _SectionCard(
                                title: 'Adresse',
                                child: _buildAddressSection(),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
          _buildStickySaveBar(context),
        ],
      ),
    );
  }

  Widget _buildStickySaveBar(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return SafeArea(
      top: false,
      child: Container(
        decoration: BoxDecoration(
          color: colorScheme.surface,
          border: Border(top: BorderSide(color: colorScheme.outlineVariant)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 14,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1320),
            child: FilledButton.icon(
              key: const Key('member-edit-save-button'),
              onPressed: _isSubmitting ? null : _save,
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
              ),
              icon: _isSubmitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save_outlined),
              label: Text(_isSubmitting ? 'Speichert...' : 'Speichern'),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGeneralSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildTwoColumnFields(
          first: _buildTextField(_vornameController, 'Vorname'),
          second: _buildTextField(_fahrtennameController, 'Fahrtenname'),
        ),
        const SizedBox(height: 12),
        _buildTextField(_nachnameController, 'Nachname'),
        FormField<void>(
          validator: (_) => _hasAtLeastOneName()
              ? null
              : 'Mindestens Vorname, Nachname oder Fahrtenname angeben.',
          builder: (state) {
            if (!state.hasError) {
              return const SizedBox.shrink();
            }
            return Padding(
              padding: const EdgeInsets.only(top: 8, left: 12),
              child: Text(
                state.errorText!,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.error,
                  fontSize: 12,
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 12),
        _ResponsiveWrap(
          minChildWidth: 240,
          spacing: 12,
          runSpacing: 12,
          children: [
            _buildGenderField(),
            _buildDateField(
              label: 'Geburtsdatum',
              fieldKey: const Key('member-edit-birthdate-field'),
              allowClear: true,
              value: _geburtsdatum,
              onChanged: (value) {
                setState(() => _geburtsdatum = value);
              },
              validator: _validateBirthDate,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTwoColumnFields({
    required Widget first,
    required Widget second,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 320) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [first, const SizedBox(height: 12), second],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: first),
            const SizedBox(width: 12),
            Expanded(child: second),
          ],
        );
      },
    );
  }

  Widget _buildEmailSection() {
    return _SectionBodyWithAddAction(
      addLabel: 'E-Mail hinzufügen',
      onAdd: () {
        setState(() {
          _additionalEmailDrafts.add(_EmailDraft.empty());
        });
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _DetailPanel(
            child: _buildTextField(
              _primaryEmailController,
              'E-Mail',
              keyboardType: TextInputType.emailAddress,
              validator: _validateEmail,
            ),
          ),
          if (_additionalEmailDrafts.isNotEmpty) const SizedBox(height: 10),
          for (
            var index = 0;
            index < _additionalEmailDrafts.length;
            index++
          ) ...[
            if (index > 0) const SizedBox(height: 10),
            _buildAdditionalEmailDraft(index, _additionalEmailDrafts[index]),
          ],
        ],
      ),
    );
  }

  Widget _buildPhoneSection() {
    return _SectionBodyWithAddAction(
      addLabel: 'Telefon hinzufügen',
      onAdd: () {
        setState(() {
          _phoneDrafts.add(_PhoneDraft.empty());
        });
      },
      child: _phoneDrafts.isEmpty
          ? const _EmptyState(message: 'Noch keine Telefonnummer hinterlegt.')
          : Column(
              children: [
                for (var index = 0; index < _phoneDrafts.length; index++) ...[
                  if (index > 0) const SizedBox(height: 10),
                  _buildPhoneDraft(index, _phoneDrafts[index]),
                ],
              ],
            ),
    );
  }

  Widget _buildAddressSection() {
    return _SectionBodyWithAddAction(
      addLabel: 'Adresse hinzufügen',
      onAdd: () {
        setState(() {
          _additionalAddressDrafts.add(_AddressDraft.empty());
        });
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildAddressDraft(-1, _primaryAddressDraft, removable: false),
          if (_additionalAddressDrafts.isNotEmpty) const SizedBox(height: 10),
          for (
            var index = 0;
            index < _additionalAddressDrafts.length;
            index++
          ) ...[
            if (index > 0) const SizedBox(height: 10),
            _buildAddressDraft(
              index,
              _additionalAddressDrafts[index],
              removable: true,
            ),
            FormField<void>(
              validator: (_) =>
                  _validateAdditionalAddress(_additionalAddressDrafts[index]),
              builder: (state) {
                if (!state.hasError) {
                  return const SizedBox.shrink();
                }
                return Padding(
                  padding: const EdgeInsets.only(top: 8, left: 12),
                  child: Text(
                    state.errorText!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                      fontSize: 12,
                    ),
                  ),
                );
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPhoneDraft(int index, _PhoneDraft draft) {
    return _DetailPanel(
      child: Column(
        children: [
          _buildDetailLabelRow(
            controller: draft.labelController,
            label: 'Bezeichnung',
            onRemove: () {
              setState(() {
                final removed = _phoneDrafts.removeAt(index);
                final phoneNumberId = removed.phoneNumberId;
                if (phoneNumberId != null) {
                  _serverPhoneErrorsById.remove(phoneNumberId);
                }
                removed.dispose();
              });
            },
          ),
          const SizedBox(height: 10),
          Row(
            key: Key('member-edit-phone-row-$index'),
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 5,
                child: DropdownButtonFormField<String>(
                  key: Key('member-edit-phone-country-$index'),
                  initialValue: draft.countryId,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Vorwahl',
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 14,
                    ),
                    border: OutlineInputBorder(),
                  ),
                  items: MemberPhoneInput.options
                      .map(
                        (option) => DropdownMenuItem<String>(
                          value: option.id,
                          child: Text(option.displayLabel),
                        ),
                      )
                      .toList(growable: false),
                  onChanged: (value) {
                    setState(() {
                      draft.countryId =
                          value ?? MemberPhoneInput.defaultCountryId;
                      _clearPhoneServerError(draft);
                    });
                  },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 7,
                child: _buildTextField(
                  draft.wertController,
                  draft.isOtherCountry ? 'Telefon mit +XX' : 'Telefonnummer',
                  fieldKey: Key('member-edit-phone-number-$index'),
                  keyboardType: TextInputType.phone,
                  onChanged: (_) => _clearPhoneServerError(draft),
                  validator: (value) =>
                      _validatePhoneDraft(draft, value, required: true),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAdditionalEmailDraft(int index, _EmailDraft draft) {
    return _DetailPanel(
      child: Column(
        children: [
          _buildDetailLabelRow(
            controller: draft.labelController,
            label: 'Bezeichnung',
            onRemove: () {
              setState(() {
                final removed = _additionalEmailDrafts.removeAt(index);
                removed.dispose();
              });
            },
          ),
          const SizedBox(height: 10),
          _buildTextField(
            draft.wertController,
            'E-Mail',
            keyboardType: TextInputType.emailAddress,
            validator: (value) => _validateEmail(value, required: true),
          ),
        ],
      ),
    );
  }

  Widget _buildAddressDraft(
    int index,
    _AddressDraft draft, {
    required bool removable,
  }) {
    return _DetailPanel(
      child: Column(
        children: [
          if (removable) ...[
            _buildDetailLabelRow(
              controller: draft.labelController,
              label: 'Bezeichnung',
              onRemove: () {
                setState(() {
                  final removed = _additionalAddressDrafts.removeAt(index);
                  removed.dispose();
                });
              },
            ),
            const SizedBox(height: 10),
            _buildTextField(draft.addressCareOfController, 'c/o'),
          ] else
            _ResponsiveWrap(
              minChildWidth: 220,
              spacing: 10,
              runSpacing: 10,
              children: [
                _buildTextField(draft.labelController, 'Bezeichnung'),
                _buildTextField(draft.addressCareOfController, 'c/o'),
              ],
            ),
          const SizedBox(height: 10),
          _ResponsiveWrap(
            minChildWidth: 180,
            spacing: 10,
            runSpacing: 10,
            children: [
              _buildTextField(draft.streetController, 'Straße'),
              _buildTextField(draft.housenumberController, 'Hausnr.'),
            ],
          ),
          const SizedBox(height: 10),
          _ResponsiveWrap(
            minChildWidth: 150,
            spacing: 10,
            runSpacing: 10,
            children: [
              _buildTextField(draft.postboxController, 'Postfach'),
              _buildTextField(draft.zipCodeController, 'PLZ'),
              _buildTextField(draft.townController, 'Ort'),
              _buildTextField(draft.countryController, 'Land'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDetailLabelRow({
    required TextEditingController controller,
    required String label,
    required VoidCallback onRemove,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: _buildTextField(controller, label)),
        const SizedBox(width: 8),
        IconButton(
          tooltip: 'Entfernen',
          onPressed: onRemove,
          icon: const Icon(Icons.delete_outline),
        ),
      ],
    );
  }

  Widget _buildTextField(
    TextEditingController controller,
    String label, {
    Key? fieldKey,
    bool required = false,
    TextInputType? keyboardType,
    ValueChanged<String>? onChanged,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      key: fieldKey,
      controller: controller,
      keyboardType: keyboardType,
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: label,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 14,
        ),
        border: const OutlineInputBorder(),
      ),
      validator: required
          ? (value) {
              final trimmed = value?.trim() ?? '';
              if (trimmed.isEmpty) {
                return '$label darf nicht leer sein.';
              }
              return validator?.call(value);
            }
          : validator,
    );
  }

  Widget _buildGenderField() {
    final items = _buildGenderItems();
    return DropdownButtonFormField<String>(
      key: const Key('member-edit-gender-field'),
      initialValue: _gender,
      isExpanded: true,
      decoration: const InputDecoration(
        labelText: 'Geschlecht',
        isDense: true,
        border: OutlineInputBorder(),
      ),
      hint: const Text('Auswählen'),
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
    Key? fieldKey,
    required String label,
    required DateTime? value,
    required ValueChanged<DateTime?> onChanged,
    bool allowClear = false,
    String? Function(DateTime?)? validator,
  }) {
    return FormField<DateTime?>(
      initialValue: value,
      validator: (_) => validator?.call(value),
      builder: (state) {
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
              state.didChange(selected);
              onChanged(selected);
            }
          },
          child: InputDecorator(
            key: fieldKey,
            decoration: InputDecoration(
              labelText: label,
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 14,
              ),
              border: const OutlineInputBorder(),
              errorText: state.errorText,
              suffixIcon: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (allowClear && value != null)
                    IconButton(
                      onPressed: () {
                        state.didChange(null);
                        onChanged(null);
                      },
                      icon: const Icon(Icons.clear),
                    )
                  else
                    const SizedBox(width: 18),
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
      },
    );
  }

  Future<void> _save() async {
    setState(() {
      _serverPhoneErrorsById.clear();
    });
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final authModel = context.read<AuthSessionModel?>();
    final memberEditModel = context.read<MemberEditModel?>();
    final accessToken = authModel?.session?.accessToken;
    if (memberEditModel == null || accessToken == null || accessToken.isEmpty) {
      _showMessage(
        'Aktuell ist keine gueltige Sitzung zum Speichern verfuegbar.',
        type: AppSnackbarType.warning,
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
      final hasMappedValidationErrors = _applyValidationErrors(result);
      if (!hasMappedValidationErrors) {
        _showMessage(
          result.message ?? 'Speichern fehlgeschlagen.',
          type: AppSnackbarType.error,
        );
      }
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
      geburtsdatum: _geburtsdatum ?? Mitglied.peoplePlaceholderDate,
      gender: _gender ?? '',
      genderLoeschen: false,
      telefonnummern: phones,
      emailAdressen: emails,
      adressen: <MitgliedKontaktAdresse>[
        primaryAddress,
        ...additionalAddresses,
      ],
    );
  }

  void _showMessage(
    String message, {
    AppSnackbarType type = AppSnackbarType.info,
  }) {
    AppSnackbar.show(context, message: message, type: type);
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
    if (value == null) {
      return '';
    }

    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      return '';
    }

    switch (trimmed.toLowerCase()) {
      case 'w':
      case 'weiblich':
        return 'w';
      case 'm':
      case 'maennlich':
      case 'männlich':
        return 'm';
      default:
        return '';
    }
  }

  String _labelForGender(String value) {
    return _genderLabels[value] ?? value;
  }

  bool _hasAtLeastOneName() {
    return _trimToNull(_vornameController.text) != null ||
        _trimToNull(_nachnameController.text) != null ||
        _trimToNull(_fahrtennameController.text) != null;
  }

  String? _validateBirthDate(DateTime? value) {
    if (value == null) {
      return null;
    }
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final oldestAllowed = DateTime(today.year - 120, today.month, today.day);
    final selectedDay = DateTime(value.year, value.month, value.day);
    if (selectedDay.isAfter(today)) {
      return 'Geburtsdatum darf nicht in der Zukunft liegen.';
    }
    if (selectedDay.isBefore(oldestAllowed)) {
      return 'Geburtsdatum ist zu weit in der Vergangenheit.';
    }
    return null;
  }

  String? _validateEmail(String? value, {bool required = false}) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) {
      return required ? 'E-Mail darf nicht leer sein.' : null;
    }
    final pattern = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');
    if (!pattern.hasMatch(trimmed)) {
      return 'Bitte eine gültige E-Mail-Adresse eingeben.';
    }
    return null;
  }

  String? _validatePhoneDraft(
    _PhoneDraft draft,
    String? value, {
    bool required = false,
  }) {
    final localError = MemberPhoneInput.validate(
      countryId: draft.countryId,
      localNumber: value,
      required: required,
    );
    if (localError != null) {
      return localError;
    }

    final phoneNumberId = draft.phoneNumberId;
    if (phoneNumberId == null) {
      return null;
    }
    return _serverPhoneErrorsById[phoneNumberId];
  }

  String? _validateAdditionalAddress(_AddressDraft draft) {
    return draft.toAdresse().istLeer
        ? 'Leere Zusatzadresse bitte entfernen oder ausfüllen.'
        : null;
  }

  void _clearPhoneServerError(_PhoneDraft draft) {
    final phoneNumberId = draft.phoneNumberId;
    if (phoneNumberId == null) {
      return;
    }
    _serverPhoneErrorsById.remove(phoneNumberId);
  }

  bool _applyValidationErrors(MemberEditSubmitResult result) {
    if (result.validationErrors.isEmpty) {
      return false;
    }

    final nextPhoneErrors = <int, String>{};
    for (final error in result.validationErrors) {
      if (!error.isPhoneNumberField) {
        continue;
      }
      final relationshipId = error.relationshipId;
      if (relationshipId == null) {
        continue;
      }
      final hasDraft = _phoneDrafts.any(
        (draft) => draft.phoneNumberId == relationshipId,
      );
      if (!hasDraft) {
        continue;
      }
      nextPhoneErrors[relationshipId] = error.message;
    }

    if (nextPhoneErrors.isEmpty) {
      return false;
    }

    setState(() {
      _serverPhoneErrorsById
        ..clear()
        ..addAll(nextPhoneErrors);
    });
    _formKey.currentState?.validate();
    return true;
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
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      elevation: 0,
      margin: const EdgeInsets.symmetric(vertical: 5),
      color: colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(_MemberEditPageState._cardRadius),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 14),
            child,
          ],
        ),
      ),
    );
  }
}

class _SectionBodyWithAddAction extends StatelessWidget {
  const _SectionBodyWithAddAction({
    required this.child,
    required this.addLabel,
    this.onAdd,
  });

  final Widget child;
  final String addLabel;
  final VoidCallback? onAdd;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        child,
        if (onAdd != null) ...[
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: OutlinedButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add),
              label: Text(addLabel),
            ),
          ),
        ],
      ],
    );
  }
}

class _DetailPanel extends StatelessWidget {
  const _DetailPanel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Theme.of(
            context,
          ).colorScheme.outlineVariant.withValues(alpha: 0.8),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [child],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Text(message),
    );
  }
}

class _ResponsiveWrap extends StatelessWidget {
  const _ResponsiveWrap({
    required this.children,
    this.minChildWidth = 260,
    this.spacing = 12,
    this.runSpacing = 12,
  });

  final List<Widget> children;
  final double minChildWidth;
  final double spacing;
  final double runSpacing;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        if (!width.isFinite || width <= 0) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var index = 0; index < children.length; index++) ...[
                children[index],
                if (index < children.length - 1) SizedBox(height: runSpacing),
              ],
            ],
          );
        }

        final estimatedColumns = ((width + spacing) / (minChildWidth + spacing))
            .floor();
        final columns = math.max(1, estimatedColumns);
        final itemWidth = (width - (spacing * (columns - 1))) / columns;

        return Wrap(
          spacing: spacing,
          runSpacing: runSpacing,
          children: [
            for (final child in children)
              SizedBox(width: itemWidth, child: child),
          ],
        );
      },
    );
  }
}

class _PhoneDraft {
  _PhoneDraft({
    required this.phoneNumberId,
    required this.countryId,
    String? wert,
    String? label,
  }) : wertController = TextEditingController(text: wert ?? ''),
       labelController = TextEditingController(text: label ?? '');

  factory _PhoneDraft.fromTelefon(MitgliedKontaktTelefon telefon) {
    final split = MemberPhoneInput.split(telefon.wert);
    return _PhoneDraft(
      phoneNumberId: telefon.phoneNumberId,
      countryId: split.countryId,
      wert: split.localNumber,
      label: telefon.label,
    );
  }

  factory _PhoneDraft.empty() => _PhoneDraft(
    phoneNumberId: null,
    countryId: MemberPhoneInput.defaultCountryId,
  );

  final int? phoneNumberId;
  String countryId;
  final TextEditingController wertController;
  final TextEditingController labelController;

  bool get isOtherCountry => countryId == MemberPhoneInput.otherCountryId;

  MitgliedKontaktTelefon? toTelefon() {
    final wert = MemberPhoneInput.compose(
      countryId: countryId,
      localNumber: wertController.text,
    );
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
