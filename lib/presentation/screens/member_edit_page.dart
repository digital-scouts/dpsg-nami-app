import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../domain/member/contact_category.dart';
import '../../domain/member/member_resolution.dart';
import '../../domain/member/mitglied.dart';
import '../../domain/member/pending_person_update.dart';
import '../../l10n/app_localizations.dart';
import '../../services/hitobito_contact_category_env.dart';
import '../model/auth_session_model.dart';
import '../model/member_bank_input.dart';
import '../model/member_edit_model.dart';
import '../model/member_phone_input.dart';
import '../notifications/app_snackbar.dart';

class MemberEditPage extends StatefulWidget {
  const MemberEditPage({
    super.key,
    required this.mitglied,
    this.pendingEntry,
    this.initialNoticeMessage,
    this.resolutionEntryPoint,
    this.contactCategories,
  });

  final Mitglied mitglied;
  final PendingPersonUpdate? pendingEntry;
  final String? initialNoticeMessage;
  final String? resolutionEntryPoint;

  /// Kategorien fuer Kontakteintraege; ohne Angabe aus der Konfiguration.
  final ContactCategoryCatalog? contactCategories;

  @override
  State<MemberEditPage> createState() => _MemberEditPageState();
}

class _MemberEditPageState extends State<MemberEditPage> {
  static final DateFormat _dateFormat = DateFormat('dd.MM.yyyy');
  static const double _pagePadding = 10;
  static const double _cardRadius = 16;

  /// Personenattribute, deren Serverfehler direkt am Feld erscheinen.
  static const Set<String> _fieldAttributes = <String>{
    'first_name',
    'last_name',
    'nickname',
    'pronoun',
    'email',
    'bank_account_owner',
    'iban',
    'bic',
    'bank_name',
    'payment_method',
  };
  static const List<String> _defaultGenderValues = <String>['w', 'm', 'd', ''];

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final GlobalKey _generalSectionKey = GlobalKey();
  final GlobalKey _emailSectionKey = GlobalKey();
  final GlobalKey _phoneSectionKey = GlobalKey();
  final GlobalKey _addressSectionKey = GlobalKey();
  final GlobalKey _bankSectionKey = GlobalKey();
  final GlobalKey _pronounFieldKey = GlobalKey();
  final GlobalKey _ibanFieldKey = GlobalKey();
  final GlobalKey _vornameFieldKey = GlobalKey();
  final GlobalKey _nachnameFieldKey = GlobalKey();
  final GlobalKey _fahrtennameFieldKey = GlobalKey();
  final GlobalKey _primaryEmailFieldKey = GlobalKey();
  final GlobalKey _genderFieldTargetKey = GlobalKey();
  final GlobalKey _birthdayFieldTargetKey = GlobalKey();
  final FocusNode _vornameFocusNode = FocusNode();
  final FocusNode _nachnameFocusNode = FocusNode();
  final FocusNode _fahrtennameFocusNode = FocusNode();
  final FocusNode _primaryEmailFocusNode = FocusNode();
  final FocusNode _genderFocusNode = FocusNode();
  final FocusNode _birthdayFocusNode = FocusNode();
  final FocusNode _pronounFocusNode = FocusNode();
  final FocusNode _ibanFocusNode = FocusNode();
  late final TextEditingController _vornameController;
  late final TextEditingController _nachnameController;
  late final TextEditingController _fahrtennameController;
  late final TextEditingController _primaryEmailController;
  late final TextEditingController _pronounController;
  late final TextEditingController _bankAccountOwnerController;
  late final TextEditingController _ibanController;
  late final TextEditingController _bicController;
  late final TextEditingController _bankNameController;
  late String? _paymentMethod;
  late DateTime? _geburtsdatum;
  late String? _gender;
  late final _AddressDraft _primaryAddressDraft;
  late final List<_PhoneDraft> _phoneDrafts;
  late final List<_EmailDraft> _additionalEmailDrafts;
  late final List<_AddressDraft> _additionalAddressDrafts;
  late final ContactCategoryCatalog _categories;
  final Map<int, String> _serverPhoneErrorsById = <int, String>{};
  final Map<String, String> _serverAttributeErrors = <String, String>{};
  final Set<String> _dismissedResolutionItemIds = <String>{};
  late bool _editSectionExpanded;
  bool _isSubmitting = false;

  MemberResolutionCase? get _resolutionCase =>
      widget.pendingEntry?.resolutionCase;
  bool get _isResolutionMode => _resolutionCase != null;

  /// Ohne `show_details` liefert Hitobito Geschlecht und Geburtsdatum nicht;
  /// leere Felder duerfen dann nicht als bearbeitbar erscheinen.
  bool get _detailsGesperrt => widget.mitglied.detailsLesbar == false;
  bool get _zeigtBankdaten => widget.mitglied.bankdatenLesbar;
  AppLocalizations get _t => AppLocalizations.of(context);
  String get _resolutionDisplayName {
    final pendingName = widget.pendingEntry?.displayName.trim();
    if (pendingName != null && pendingName.isNotEmpty) {
      return pendingName;
    }
    final fullName = widget.mitglied.fullName.trim();
    if (fullName.isNotEmpty) {
      return fullName;
    }
    return widget.mitglied.mitgliedsnummer;
  }

  bool get _cannotSendNow {
    final authModel = _maybeWatch<AuthSessionModel>(context);
    if (authModel == null) {
      return false;
    }
    return authModel.requiresInteractiveLogin ||
        authModel.remoteAccessBlockedReason != null;
  }

  @override
  void initState() {
    super.initState();
    _categories =
        widget.contactCategories ?? HitobitoContactCategoryEnv.catalog;
    final primaryEmail = _resolvePrimaryEmail(widget.mitglied.emailAdressen);
    final primaryAddress = widget.mitglied.primaryAddress;
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
    _pronounController = TextEditingController(
      text: widget.mitglied.pronoun ?? '',
    );
    _bankAccountOwnerController = TextEditingController();
    _ibanController = TextEditingController();
    _bicController = TextEditingController();
    _bankNameController = TextEditingController();
    _applyBankValues(widget.mitglied);
    _editSectionExpanded = !_isResolutionMode;
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
    _additionalAddressDrafts = widget.mitglied.additionalAddresses
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
    if (_isResolutionMode && widget.pendingEntry != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) {
          return;
        }
        await context.read<MemberEditModel?>()?.logResolutionOpened(
          entry: widget.pendingEntry!,
          entryPoint: widget.resolutionEntryPoint ?? 'unknown',
        );
      });
    }
  }

  @override
  void dispose() {
    _vornameFocusNode.dispose();
    _nachnameFocusNode.dispose();
    _fahrtennameFocusNode.dispose();
    _primaryEmailFocusNode.dispose();
    _genderFocusNode.dispose();
    _birthdayFocusNode.dispose();
    _pronounFocusNode.dispose();
    _ibanFocusNode.dispose();
    _pronounController.dispose();
    _bankAccountOwnerController.dispose();
    _ibanController.dispose();
    _bicController.dispose();
    _bankNameController.dispose();
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
      appBar: AppBar(
        title: Text(
          _isResolutionMode
              ? _t.t('member_edit_title_resolution_named', {
                  'name': _resolutionDisplayName,
                })
              : _t.t('member_edit_title_edit'),
        ),
      ),
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
                              if (_isResolutionMode) ...[
                                _buildResolutionSection(),
                                const SizedBox(height: 10),
                                _buildEditableMemberSection(),
                              ] else
                                _buildEditSectionsContent(),
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

  Widget _buildEditSectionsContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SectionCard(
          key: _generalSectionKey,
          title: _t.t('member_edit_section_general'),
          child: _buildGeneralSection(),
        ),
        const SizedBox(height: 10),
        _SectionCard(
          key: _emailSectionKey,
          title: _t.t('member_edit_section_email'),
          child: _buildEmailSection(),
        ),
        const SizedBox(height: 10),
        _SectionCard(
          key: _phoneSectionKey,
          title: _t.t('member_edit_section_phone'),
          child: _buildPhoneSection(),
        ),
        const SizedBox(height: 10),
        _SectionCard(
          key: _addressSectionKey,
          title: _t.t('member_edit_section_address'),
          child: _buildAddressSection(),
        ),
        if (_zeigtBankdaten) ...[
          const SizedBox(height: 10),
          _SectionCard(
            key: _bankSectionKey,
            title: _t.t('member_edit_section_bank'),
            child: _buildBankSection(),
          ),
        ],
      ],
    );
  }

  Widget _buildEditableMemberSection() {
    return _ExpandableSectionCard(
      key: const Key('member-edit-resolution-edit-section'),
      title: _t.t('member_edit_edit_section_title'),
      expanded: _editSectionExpanded,
      onToggle: () {
        setState(() {
          _editSectionExpanded = !_editSectionExpanded;
        });
      },
      child: _buildEditSectionsContent(),
    );
  }

  Widget _buildStickySaveBar(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final cannotSendNow = _cannotSendNow;
    final label = _isSubmitting
        ? _t.t(
            cannotSendNow ? 'member_edit_saving_later' : 'member_edit_saving',
          )
        : _t.t(cannotSendNow ? 'member_edit_save_later' : 'save');
    final icon = _isSubmitting
        ? const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        : Icon(cannotSendNow ? Icons.schedule_outlined : Icons.save_outlined);
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
                backgroundColor: cannotSendNow
                    ? colorScheme.tertiaryContainer
                    : null,
                foregroundColor: cannotSendNow
                    ? colorScheme.onTertiaryContainer
                    : null,
              ),
              icon: icon,
              label: Text(label),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildResolutionSection() {
    final resolutionCase = _resolutionCase;
    if (resolutionCase == null) {
      return const SizedBox.shrink();
    }

    final visibleItems = resolutionCase.items
        .where((item) => !_dismissedResolutionItemIds.contains(item.itemId))
        .toList(growable: false);
    return _SectionCard(
      title: _t.t('member_edit_resolution_title'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(_t.t('member_edit_resolution_intro')),
          if (visibleItems.isNotEmpty) const SizedBox(height: 12),
          if (visibleItems.isEmpty)
            _EmptyState(message: _t.t('member_edit_resolution_empty')),
          for (var index = 0; index < visibleItems.length; index++) ...[
            if (index > 0) const SizedBox(height: 10),
            _buildResolutionItemCard(visibleItems[index]),
          ],
        ],
      ),
    );
  }

  Widget _buildResolutionItemCard(MemberResolutionItem item) {
    final isConflict = item.problemType == MemberResolutionProblemType.conflict;
    final leftTitle = isConflict
        ? _t.t('member_edit_resolution_local_title')
        : _t.t('member_edit_resolution_current_title');
    final rightTitle = isConflict
        ? _t.t('member_edit_resolution_remote_title')
        : _t.t('member_edit_resolution_previous_title');
    final leftLines = _buildResolutionLinesFromCurrent(item.target);
    final rightLines = _buildResolutionLinesFromMember(
      isConflict
          ? _resolutionCase?.remoteMitglied
          : widget.pendingEntry?.basisMitglied,
      item.target,
    );

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _labelForResolutionTarget(item.target),
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: 4),
                    Text(item.message),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              TextButton.icon(
                key: Key('member-edit-resolution-edit-${item.itemId}'),
                onPressed: () => _openEditorForTarget(item.target),
                icon: const Icon(Icons.edit_outlined),
                label: Text(_t.t('member_edit_resolution_edit')),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildResolutionComparison(
            leftTitle: leftTitle,
            rightTitle: rightTitle,
            leftLines: leftLines,
            rightLines: rightLines,
          ),
          const SizedBox(height: 12),
          if (isConflict)
            _buildConflictActionRow(item)
          else
            _buildValidationActionRow(item),
        ],
      ),
    );
  }

  Widget _buildResolutionComparison({
    required String leftTitle,
    required String rightTitle,
    required List<_ResolutionValueLine> leftLines,
    required List<_ResolutionValueLine> rightLines,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final comparisonChildren = [
          Expanded(
            child: _ResolutionValuePanel(title: leftTitle, lines: leftLines),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _ResolutionValuePanel(title: rightTitle, lines: rightLines),
          ),
        ];

        if (constraints.maxWidth < 420) {
          return Column(
            children: [
              _ResolutionValuePanel(title: leftTitle, lines: leftLines),
              const SizedBox(height: 10),
              _ResolutionValuePanel(title: rightTitle, lines: rightLines),
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: comparisonChildren,
        );
      },
    );
  }

  Widget _buildConflictActionRow(MemberResolutionItem item) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final leftButton = OutlinedButton.icon(
          onPressed: () {
            _recordResolutionChoice(item, 'keep_local');
            setState(() {
              _dismissedResolutionItemIds.add(item.itemId);
            });
          },
          icon: const Icon(Icons.edit_outlined),
          label: Text(_t.t('member_edit_resolution_keep_local')),
        );
        final rightButton = FilledButton.tonalIcon(
          onPressed: () => _applyServerChoice(item),
          icon: const Icon(Icons.sync_alt_outlined),
          label: Text(_t.t('member_edit_resolution_use_server')),
        );
        if (constraints.maxWidth < 420) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [leftButton, const SizedBox(height: 8), rightButton],
          );
        }
        return Row(
          children: [
            Expanded(child: leftButton),
            const SizedBox(width: 10),
            Expanded(child: rightButton),
          ],
        );
      },
    );
  }

  Widget _buildValidationActionRow(MemberResolutionItem item) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final editButton = FilledButton.tonalIcon(
          onPressed: () => _openEditorForTarget(item.target),
          icon: const Icon(Icons.edit_outlined),
          label: Text(_t.t('member_edit_resolution_edit')),
        );
        final discardButton = OutlinedButton.icon(
          onPressed: () => _discardValidationChange(item),
          icon: const Icon(Icons.undo_outlined),
          label: Text(_t.t('member_edit_resolution_discard_local')),
        );
        if (constraints.maxWidth < 420) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [editButton, const SizedBox(height: 8), discardButton],
          );
        }
        return Row(
          children: [
            Expanded(child: editButton),
            const SizedBox(width: 10),
            Expanded(child: discardButton),
          ],
        );
      },
    );
  }

  Widget _buildGeneralSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildTwoColumnFields(
          first: SizedBox(
            key: _vornameFieldKey,
            child: _buildTextField(
              _vornameController,
              _t.t('member_edit_field_first_name'),
              fieldKey: const Key('member-edit-first-name-field'),
              serverErrorAttribute: 'first_name',
              focusNode: _vornameFocusNode,
            ),
          ),
          second: SizedBox(
            key: _fahrtennameFieldKey,
            child: _buildTextField(
              _fahrtennameController,
              _t.t('member_edit_field_nickname'),
              fieldKey: const Key('member-edit-nickname-field'),
              serverErrorAttribute: 'nickname',
              focusNode: _fahrtennameFocusNode,
            ),
          ),
        ),
        const SizedBox(height: 12),
        _buildTwoColumnFields(
          first: SizedBox(
            key: _nachnameFieldKey,
            child: _buildTextField(
              _nachnameController,
              _t.t('member_edit_field_last_name'),
              fieldKey: const Key('member-edit-last-name-field'),
              serverErrorAttribute: 'last_name',
              focusNode: _nachnameFocusNode,
            ),
          ),
          second: SizedBox(
            key: _pronounFieldKey,
            child: _buildTextField(
              _pronounController,
              _t.t('member_edit_field_pronoun'),
              fieldKey: const Key('member-edit-pronoun-field'),
              focusNode: _pronounFocusNode,
              serverErrorAttribute: 'pronoun',
            ),
          ),
        ),
        FormField<void>(
          validator: (_) =>
              _hasAtLeastOneName() ? null : _t.t('member_edit_name_required'),
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
        if (_detailsGesperrt)
          Text(
            _t.t('member_edit_details_not_visible'),
            key: const Key('member-edit-details-locked'),
            style: Theme.of(context).textTheme.bodySmall,
          )
        else
          _ResponsiveWrap(
            minChildWidth: 240,
            spacing: 12,
            runSpacing: 12,
            children: [
              SizedBox(key: _genderFieldTargetKey, child: _buildGenderField()),
              SizedBox(
                key: _birthdayFieldTargetKey,
                child: _buildDateField(
                  label: _t.t('member_edit_field_birthday'),
                  fieldKey: const Key('member-edit-birthdate-field'),
                  focusNode: _birthdayFocusNode,
                  allowClear: true,
                  value: _geburtsdatum,
                  onChanged: (value) {
                    setState(() => _geburtsdatum = value);
                  },
                  validator: _validateBirthDate,
                ),
              ),
            ],
          ),
      ],
    );
  }

  Widget _buildBankSection() {
    final paymentMethods = <String>[
      ...MemberBankInput.paymentMethods,
      if (_paymentMethod != null &&
          !MemberBankInput.paymentMethods.contains(_paymentMethod))
        _paymentMethod!,
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DropdownButtonFormField<String>(
          key: const Key('member-edit-payment-method-field'),
          initialValue: _paymentMethod,
          isExpanded: true,
          decoration: InputDecoration(
            labelText: _t.t('member_edit_field_payment_method'),
            isDense: true,
            border: const OutlineInputBorder(),
            errorText: _serverAttributeErrors['payment_method'],
          ),
          items: paymentMethods
              .map(
                (value) => DropdownMenuItem<String>(
                  value: value,
                  child: Text(_labelForPaymentMethod(value)),
                ),
              )
              .toList(growable: false),
          validator: (value) => value == null
              ? _t.t('member_edit_required_field', {
                  'field': _t.t('member_edit_field_payment_method'),
                })
              : null,
          onChanged: (value) {
            setState(() {
              _paymentMethod = value;
              _serverAttributeErrors.remove('payment_method');
            });
          },
        ),
        const SizedBox(height: 12),
        _buildTextField(
          _bankAccountOwnerController,
          _t.t('member_edit_field_bank_account_owner'),
          fieldKey: const Key('member-edit-bank-account-owner-field'),
          serverErrorAttribute: 'bank_account_owner',
        ),
        const SizedBox(height: 12),
        SizedBox(
          key: _ibanFieldKey,
          child: _buildTextField(
            _ibanController,
            _t.t('member_edit_field_iban'),
            fieldKey: const Key('member-edit-iban-field'),
            focusNode: _ibanFocusNode,
            serverErrorAttribute: 'iban',
            validator: (value) => MemberBankInput.isValidIban(value)
                ? null
                : _t.t('member_edit_iban_invalid'),
          ),
        ),
        const SizedBox(height: 12),
        _buildTwoColumnFields(
          first: _buildTextField(
            _bicController,
            _t.t('member_edit_field_bic'),
            fieldKey: const Key('member-edit-bic-field'),
            serverErrorAttribute: 'bic',
            validator: (value) => MemberBankInput.isValidBic(value)
                ? null
                : _t.t('member_edit_bic_invalid'),
          ),
          second: _buildTextField(
            _bankNameController,
            _t.t('member_edit_field_bank_name'),
            fieldKey: const Key('member-edit-bank-name-field'),
            serverErrorAttribute: 'bank_name',
          ),
        ),
      ],
    );
  }

  String _labelForPaymentMethod(String value) {
    switch (value) {
      case MemberBankInput.paymentMethodInvoice:
        return _t.t('member_edit_payment_method_invoice');
      case MemberBankInput.paymentMethodDebit:
        return _t.t('member_edit_payment_method_debit');
      default:
        return value;
    }
  }

  void _applyBankValues(Mitglied source) {
    _bankAccountOwnerController.text = source.bankAccountOwner ?? '';
    _ibanController.text = source.iban ?? '';
    _bicController.text = source.bic ?? '';
    _bankNameController.text = source.bankName ?? '';
    _paymentMethod = source.paymentMethod;
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
      addLabel: _t.t('member_edit_add_email'),
      disabledHint: _t.t('member_edit_categories_missing'),
      onAdd: _categories.supports(ContactAccountType.additionalEmail)
          ? () {
              setState(() {
                _additionalEmailDrafts.add(_EmailDraft.empty());
              });
            }
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _DetailPanel(
            child: SizedBox(
              key: _primaryEmailFieldKey,
              child: _buildTextField(
                _primaryEmailController,
                _t.t('member_edit_section_email'),
                fieldKey: const Key('member-edit-primary-email-field'),
                serverErrorAttribute: 'email',
                focusNode: _primaryEmailFocusNode,
                keyboardType: TextInputType.emailAddress,
                validator: _validateEmail,
              ),
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
      addLabel: _t.t('member_edit_add_phone'),
      disabledHint: _t.t('member_edit_categories_missing'),
      onAdd: _categories.supports(ContactAccountType.phoneNumber)
          ? () {
              setState(() {
                _phoneDrafts.add(_PhoneDraft.empty());
              });
            }
          : null,
      child: _phoneDrafts.isEmpty
          ? _EmptyState(message: _t.t('member_edit_phone_empty'))
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
      addLabel: _t.t('member_edit_add_address'),
      disabledHint: _t.t('member_edit_categories_missing'),
      onAdd: _categories.supports(ContactAccountType.additionalAddress)
          ? () {
              setState(() {
                _additionalAddressDrafts.add(
                  _AddressDraft.forNewEntry(widget.mitglied),
                );
              });
            }
          : null,
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
          _buildCategoryRow(
            type: ContactAccountType.phoneNumber,
            fieldKey: Key('member-edit-phone-category-$index'),
            categoryId: draft.categoryId,
            isNewEntry: draft.phoneNumberId == null,
            freeLabel: draft.labelController.text,
            takenCategoryIds: _takenCategoryIds(
              _phoneDrafts.map((other) => other.categoryId),
            ),
            onChanged: (value) => setState(() => draft.categoryId = value),
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
                  decoration: InputDecoration(
                    labelText: _t.t('member_edit_field_prefix'),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 14,
                    ),
                    border: const OutlineInputBorder(),
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
                  draft.isOtherCountry
                      ? _t.t('member_edit_field_phone_with_country')
                      : _t.t('member_edit_field_phone_number'),
                  fieldKey: Key('member-edit-phone-number-$index'),
                  focusNode: draft.wertFocusNode,
                  keyboardType: TextInputType.phone,
                  onChanged: (_) => _clearPhoneServerError(draft),
                  validator: (value) =>
                      _validatePhoneDraft(draft, value, required: true),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_t.t('member_edit_field_phone_public')),
                    Text(
                      _t.t('member_edit_field_phone_public_hint'),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              Switch(
                key: Key('member-edit-phone-public-$index'),
                value: draft.istOeffentlich,
                onChanged: (value) {
                  setState(() => draft.istOeffentlich = value);
                },
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
          _buildCategoryRow(
            type: ContactAccountType.additionalEmail,
            fieldKey: Key('member-edit-email-category-$index'),
            categoryId: draft.categoryId,
            isNewEntry: draft.additionalEmailId == null,
            freeLabel: draft.labelController.text,
            takenCategoryIds: _takenCategoryIds(
              _additionalEmailDrafts.map((other) => other.categoryId),
            ),
            onChanged: (value) => setState(() => draft.categoryId = value),
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
            _t.t('member_edit_section_email'),
            fieldKey: draft.wertFieldKey,
            focusNode: draft.wertFocusNode,
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
            _buildCategoryRow(
              type: ContactAccountType.additionalAddress,
              fieldKey: Key('member-edit-address-category-$index'),
              categoryId: draft.categoryId,
              isNewEntry: draft.additionalAddressId == null,
              freeLabel: draft.labelController.text,
              takenCategoryIds: _takenCategoryIds(
                _additionalAddressDrafts.map((other) => other.categoryId),
              ),
              onChanged: (value) => setState(() => draft.categoryId = value),
              onRemove: () {
                setState(() {
                  final removed = _additionalAddressDrafts.removeAt(index);
                  removed.dispose();
                });
              },
            ),
            const SizedBox(height: 10),
            _buildTwoColumnFields(
              first: _buildTextField(
                draft.firstNameController,
                _t.t('member_edit_field_first_name'),
                fieldKey: Key('member-edit-address-first-name-$index'),
              ),
              second: _buildTextField(
                draft.lastNameController,
                _t.t('member_edit_field_last_name'),
                fieldKey: Key('member-edit-address-last-name-$index'),
              ),
            ),
            const SizedBox(height: 10),
            _buildTwoColumnFields(
              first: _buildTextField(
                draft.organizationNameController,
                _t.t('member_edit_field_organization'),
                fieldKey: Key('member-edit-address-organization-$index'),
              ),
              second: _buildTextField(
                draft.addressCareOfController,
                _t.t('member_edit_field_care_of'),
              ),
            ),
          ] else
            // Hitobito kennt fuer die eigene Adresse der Person keine
            // Bezeichnung, deshalb gibt es hier nur c/o.
            _buildTextField(
              draft.addressCareOfController,
              _t.t('member_edit_field_care_of'),
              fieldKey: draft.addressCareOfFieldKey,
            ),
          const SizedBox(height: 10),
          _ResponsiveWrap(
            minChildWidth: 180,
            spacing: 10,
            runSpacing: 10,
            children: [
              _buildTextField(
                draft.streetController,
                _t.t('member_edit_field_street'),
                fieldKey: draft.streetFieldKey,
                focusNode: draft.streetFocusNode,
              ),
              _buildTextField(
                draft.housenumberController,
                _t.t('member_edit_field_house_number'),
                fieldKey: draft.housenumberFieldKey,
              ),
            ],
          ),
          const SizedBox(height: 10),
          _ResponsiveWrap(
            minChildWidth: 150,
            spacing: 10,
            runSpacing: 10,
            children: [
              _buildTextField(
                draft.postboxController,
                _t.t('member_edit_field_postbox'),
                fieldKey: draft.postboxFieldKey,
              ),
              _buildTextField(
                draft.zipCodeController,
                _t.t('member_edit_field_zip_code'),
                fieldKey: draft.zipCodeFieldKey,
              ),
              _buildTextField(
                draft.townController,
                _t.t('member_edit_field_town'),
                fieldKey: draft.townFieldKey,
              ),
              _buildTextField(
                draft.countryController,
                _t.t('member_edit_field_country'),
                fieldKey: draft.countryFieldKey,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Set<int> _takenCategoryIds(Iterable<int?> categoryIds) {
    final seen = <int>{};
    final taken = <int>{};
    for (final id in categoryIds) {
      if (id != null && !seen.add(id)) {
        taken.add(id);
      }
    }
    return taken;
  }

  /// Bezeichnung eines Kontakteintrags: Kategorie und optionaler Zusatz.
  String? _contactLabel(
    ContactAccountType type,
    int? categoryId,
    String? freeLabel,
  ) {
    final categoryName = categoryId == null
        ? null
        : _categories.byId(type, categoryId)?.name ??
              _t.t('member_edit_category_unknown');
    final parts = <String>[?categoryName, ?_trimToNull(freeLabel ?? '')];
    return parts.isEmpty ? null : parts.join(', ');
  }

  Widget _buildCategoryRow({
    required ContactAccountType type,
    required Key fieldKey,
    required int? categoryId,
    required bool isNewEntry,
    required String freeLabel,
    required Set<int> takenCategoryIds,
    required ValueChanged<int?> onChanged,
    required VoidCallback onRemove,
  }) {
    final categories = _categories.forType(type);
    final hasUnknownCategory =
        categoryId != null && _categories.byId(type, categoryId) == null;
    final label = _trimToNull(freeLabel);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: DropdownButtonFormField<int>(
            key: fieldKey,
            initialValue: categoryId,
            isExpanded: true,
            decoration: InputDecoration(
              labelText: _t.t('member_edit_field_label'),
              helperText: label == null
                  ? null
                  : _t.t('member_edit_category_free_label', {'label': label}),
              isDense: true,
              border: const OutlineInputBorder(),
            ),
            hint: Text(_t.t('member_edit_select_hint')),
            items: <DropdownMenuItem<int>>[
              for (final category in categories)
                DropdownMenuItem<int>(
                  value: category.id,
                  child: Text(category.name, overflow: TextOverflow.ellipsis),
                ),
              if (hasUnknownCategory)
                DropdownMenuItem<int>(
                  value: categoryId,
                  child: Text(_t.t('member_edit_category_unknown')),
                ),
            ],
            validator: (value) {
              // Bestehende Eintraege haben ihre Kategorie in Hitobito; nur fuer
              // neue Eintraege muss die App sie mitsenden.
              if (value == null) {
                return isNewEntry
                    ? _t.t('member_edit_category_required')
                    : null;
              }
              final category = _categories.byId(type, value);
              if (category != null &&
                  category.uniquePerContactable &&
                  takenCategoryIds.contains(value)) {
                return _t.t('member_edit_category_taken', {
                  'category': category.name,
                });
              }
              return null;
            },
            onChanged: onChanged,
          ),
        ),
        const SizedBox(width: 8),
        IconButton(
          tooltip: _t.t('common_remove'),
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
    FocusNode? focusNode,
    bool required = false,
    TextInputType? keyboardType,
    ValueChanged<String>? onChanged,
    String? Function(String?)? validator,
    String? serverErrorAttribute,
  }) {
    if (serverErrorAttribute != null) {
      final localValidator = validator;
      final localOnChanged = onChanged;
      validator = (value) =>
          _serverAttributeErrors[serverErrorAttribute] ??
          localValidator?.call(value);
      onChanged = (value) {
        // Wie bei Telefonnummern: Der Hinweis bleibt bis zum naechsten
        // Speichern sichtbar, blockiert es aber nicht mehr.
        _serverAttributeErrors.remove(serverErrorAttribute);
        localOnChanged?.call(value);
      };
    }
    return TextFormField(
      key: fieldKey,
      controller: controller,
      focusNode: focusNode,
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
                return _t.t('member_edit_required_field', {'field': label});
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
      focusNode: _genderFocusNode,
      initialValue: _gender,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: _t.t('member_edit_field_gender'),
        isDense: true,
        border: const OutlineInputBorder(),
      ),
      hint: Text(_t.t('member_edit_select_hint')),
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
    FocusNode? focusNode,
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
        return Focus(
          focusNode: focusNode,
          child: InkWell(
            onTap: () async {
              final selected = await showDatePicker(
                context: context,
                initialDate: value ?? DateTime.now(),
                firstDate: DateTime(1900),
                lastDate: DateTime(2100),
                locale: Localizations.localeOf(context),
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
                value == null
                    ? _t.t('member_edit_value_not_set')
                    : _dateFormat.format(value),
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _save() async {
    final mustExpand = !_editSectionExpanded;
    setState(() {
      _serverPhoneErrorsById.clear();
      _serverAttributeErrors.clear();
      // Die Validatoren greifen nur fuer aufgebaute Felder; im
      // Problemloesungsmodus ist der Bereich anfangs eingeklappt.
      _editSectionExpanded = true;
    });
    if (mustExpand) {
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted) {
        return;
      }
    }
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final authModel = context.read<AuthSessionModel?>();
    final memberEditModel = context.read<MemberEditModel?>();
    final accessToken = authModel?.session?.accessToken;
    if (memberEditModel == null || accessToken == null || accessToken.isEmpty) {
      _showMessage(
        _t.t('member_edit_session_missing'),
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
        basisMitglied: _resolutionCase?.remoteMitglied ?? widget.mitglied,
        zielMitglied: targetMember,
        trigger: _isResolutionMode ? 'manual_resolution' : 'manual_edit',
        existingResolutionCase: _resolutionCase,
      );
      if (!mounted) {
        return;
      }
      if (result.requiresResolution && result.pendingEntry != null) {
        // Kein pushReplacement: Dann erhielte der Aufrufer sofort null statt
        // des Ergebnisses der naechsten Problemloesung.
        final nextResult = await Navigator.of(context)
            .push<MemberEditSubmitResult>(
              MaterialPageRoute<MemberEditSubmitResult>(
                builder: (_) => MemberEditPage(
                  mitglied: result.pendingEntry!.zielMitglied,
                  pendingEntry: result.pendingEntry,
                  initialNoticeMessage: result.resolveMessage(_t),
                  resolutionEntryPoint: 'submit_result',
                ),
              ),
            );
        if (mounted) {
          Navigator.of(context).pop(nextResult);
        }
        return;
      }
      if (result.success || result.wasQueued) {
        Navigator.of(context).pop(result);
        return;
      }
      final hasMappedValidationErrors = _applyValidationErrors(result);
      if (!hasMappedValidationErrors) {
        _showMessage(
          result.resolveMessage(_t) ?? _t.t('member_edit_save_failed'),
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

  T? _maybeWatch<T>(BuildContext context) {
    try {
      return context.watch<T>();
    } catch (_) {
      return null;
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

    final target = widget.mitglied.copyWith(
      vorname: _vornameController.text.trim(),
      nachname: _nachnameController.text.trim(),
      fahrtenname: _trimToNull(_fahrtennameController.text),
      fahrtennameLoeschen: _trimToNull(_fahrtennameController.text) == null,
      geburtsdatum: _detailsGesperrt
          ? widget.mitglied.geburtsdatum
          : _geburtsdatum ?? Mitglied.peoplePlaceholderDate,
      gender: _detailsGesperrt ? widget.mitglied.gender : _gender,
      genderLoeschen: !_detailsGesperrt && (_gender ?? '').isEmpty,
      pronoun: _trimToNull(_pronounController.text),
      pronounLoeschen: _trimToNull(_pronounController.text) == null,
      telefonnummern: phones,
      emailAdressen: emails,
      adressen: <MitgliedKontaktAdresse>[
        primaryAddress,
        ...additionalAddresses,
      ],
    );
    if (!_zeigtBankdaten) {
      return target;
    }
    final bankAccountOwner = _trimToNull(_bankAccountOwnerController.text);
    final iban = MemberBankInput.normalizeIban(_ibanController.text);
    final bic = MemberBankInput.normalizeBic(_bicController.text);
    final bankName = _trimToNull(_bankNameController.text);
    return target.copyWith(
      bankAccountOwner: bankAccountOwner,
      bankAccountOwnerLoeschen: bankAccountOwner == null,
      iban: iban,
      ibanLoeschen: iban == null,
      bic: bic,
      bicLoeschen: bic == null,
      bankName: bankName,
      bankNameLoeschen: bankName == null,
      paymentMethod: _paymentMethod,
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
      case 'd':
      case 'divers':
        return 'd';
      default:
        return '';
    }
  }

  String _labelForGender(String value) {
    switch (value) {
      case 'w':
        return _t.t('member_edit_gender_female');
      case 'm':
        return _t.t('member_edit_gender_male');
      case 'd':
        return _t.t('member_edit_gender_diverse');
      case '':
        return _t.t('member_edit_gender_unknown');
      default:
        return value;
    }
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
      return _t.t('member_edit_birthdate_future');
    }
    if (selectedDay.isBefore(oldestAllowed)) {
      return _t.t('member_edit_birthdate_past');
    }
    return null;
  }

  String? _validateEmail(String? value, {bool required = false}) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) {
      return required ? _t.t('member_edit_email_required') : null;
    }
    final pattern = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');
    if (!pattern.hasMatch(trimmed)) {
      return _t.t('member_edit_email_invalid');
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
    final adresse = draft.toAdresse();
    if (adresse.istLeer) {
      return _t.t('member_edit_additional_address_empty');
    }
    // Unveraenderte bestehende Adressen werden nicht gesendet; Hitobito
    // prueft den Namen erst, wenn eine Adresse geschrieben wird.
    if (draft.additionalAddressId == null && !adresse.hatName) {
      return _t.t('member_edit_additional_address_name_required');
    }
    return null;
  }

  void _applyServerChoice(MemberResolutionItem item) {
    final remoteMember = _resolutionCase?.remoteMitglied;
    if (remoteMember == null) {
      return;
    }
    _recordResolutionChoice(item, 'use_server');
    setState(() {
      _applyMemberValue(item.target, remoteMember);
      _dismissedResolutionItemIds.add(item.itemId);
    });
  }

  void _discardValidationChange(MemberResolutionItem item) {
    final fallbackMember = widget.pendingEntry?.basisMitglied;
    if (fallbackMember == null) {
      return;
    }
    _recordResolutionChoice(item, 'discard_local');
    setState(() {
      _applyMemberValue(item.target, fallbackMember);
      _dismissedResolutionItemIds.add(item.itemId);
    });
  }

  void _recordResolutionChoice(MemberResolutionItem item, String choice) {
    final pendingEntry = widget.pendingEntry;
    final memberEditModel = context.read<MemberEditModel?>();
    if (pendingEntry == null || memberEditModel == null) {
      return;
    }
    memberEditModel.logResolutionChoice(
      entry: pendingEntry,
      item: item,
      choice: choice,
    );
  }

  Future<void> _openEditorForTarget(MemberResolutionTarget target) async {
    if (!_editSectionExpanded) {
      setState(() {
        _editSectionExpanded = true;
      });
      await WidgetsBinding.instance.endOfFrame;
    }

    switch (target.type) {
      case MemberResolutionTargetType.firstName:
        await _ensureVisibleAndFocus(
          _generalSectionKey,
          _vornameFieldKey,
          _vornameFocusNode,
        );
        return;
      case MemberResolutionTargetType.lastName:
        await _ensureVisibleAndFocus(
          _generalSectionKey,
          _nachnameFieldKey,
          _nachnameFocusNode,
        );
        return;
      case MemberResolutionTargetType.nickname:
        await _ensureVisibleAndFocus(
          _generalSectionKey,
          _fahrtennameFieldKey,
          _fahrtennameFocusNode,
        );
        return;
      case MemberResolutionTargetType.gender:
        await _ensureVisibleAndFocus(
          _generalSectionKey,
          _genderFieldTargetKey,
          _genderFocusNode,
        );
        return;
      case MemberResolutionTargetType.birthday:
        await _ensureVisibleAndFocus(
          _generalSectionKey,
          _birthdayFieldTargetKey,
          _birthdayFocusNode,
        );
        return;
      case MemberResolutionTargetType.pronoun:
        await _ensureVisibleAndFocus(
          _generalSectionKey,
          _pronounFieldKey,
          _pronounFocusNode,
        );
        return;
      case MemberResolutionTargetType.bankAccount:
        await _ensureVisibleAndFocus(
          _bankSectionKey,
          _ibanFieldKey,
          _ibanFocusNode,
        );
        return;
      case MemberResolutionTargetType.primaryEmail:
        await _ensureVisibleAndFocus(
          _emailSectionKey,
          _primaryEmailFieldKey,
          _primaryEmailFocusNode,
        );
        return;
      case MemberResolutionTargetType.phone:
        final draft = _findPhoneDraft(target.relationshipId);
        await _ensureVisibleAndFocus(
          _phoneSectionKey,
          draft?.wertFieldKey,
          draft?.wertFocusNode,
        );
        return;
      case MemberResolutionTargetType.additionalEmail:
        final draft = _findAdditionalEmailDraft(target.relationshipId);
        await _ensureVisibleAndFocus(
          _emailSectionKey,
          draft?.wertFieldKey,
          draft?.wertFocusNode,
        );
        return;
      case MemberResolutionTargetType.primaryAddress:
        await _ensureVisibleAndFocus(
          _addressSectionKey,
          _primaryAddressDraft.streetFieldKey,
          _primaryAddressDraft.streetFocusNode,
        );
        return;
      case MemberResolutionTargetType.additionalAddress:
        final draft = _findAdditionalAddressDraft(target.relationshipId);
        await _ensureVisibleAndFocus(
          _addressSectionKey,
          draft?.streetFieldKey,
          draft?.streetFocusNode,
        );
        return;
    }
  }

  Future<void> _ensureVisibleAndFocus(
    GlobalKey sectionKey,
    GlobalKey? fieldKey,
    FocusNode? focusNode,
  ) async {
    final targetContext = fieldKey?.currentContext ?? sectionKey.currentContext;
    if (targetContext != null) {
      await Scrollable.ensureVisible(
        targetContext,
        duration: const Duration(milliseconds: 250),
        alignment: 0.12,
      );
    }
    focusNode?.requestFocus();
  }

  _PhoneDraft? _findPhoneDraft(int? relationshipId) {
    if (relationshipId == null) {
      return null;
    }
    for (final draft in _phoneDrafts) {
      if (draft.phoneNumberId == relationshipId) {
        return draft;
      }
    }
    return null;
  }

  _EmailDraft? _findAdditionalEmailDraft(int? relationshipId) {
    if (relationshipId == null) {
      return null;
    }
    for (final draft in _additionalEmailDrafts) {
      if (draft.additionalEmailId == relationshipId) {
        return draft;
      }
    }
    return null;
  }

  _AddressDraft? _findAdditionalAddressDraft(int? relationshipId) {
    if (relationshipId == null) {
      return null;
    }
    for (final draft in _additionalAddressDrafts) {
      if (draft.additionalAddressId == relationshipId) {
        return draft;
      }
    }
    return null;
  }

  void _applyMemberValue(MemberResolutionTarget target, Mitglied source) {
    switch (target.type) {
      case MemberResolutionTargetType.firstName:
        _vornameController.text = source.vorname;
        return;
      case MemberResolutionTargetType.lastName:
        _nachnameController.text = source.nachname;
        return;
      case MemberResolutionTargetType.nickname:
        _fahrtennameController.text = source.fahrtenname ?? '';
        return;
      case MemberResolutionTargetType.gender:
        _gender = _normalizeGenderValue(source.gender);
        return;
      case MemberResolutionTargetType.birthday:
        _geburtsdatum = source.geburtsdatum == Mitglied.peoplePlaceholderDate
            ? null
            : source.geburtsdatum;
        return;
      case MemberResolutionTargetType.pronoun:
        _pronounController.text = source.pronoun ?? '';
        return;
      case MemberResolutionTargetType.bankAccount:
        _applyBankValues(source);
        return;
      case MemberResolutionTargetType.primaryEmail:
        _primaryEmailController.text =
            _resolvePrimaryEmail(source.emailAdressen)?.wert ?? '';
        return;
      case MemberResolutionTargetType.phone:
        _replacePhoneDraft(target.relationshipId, source);
        return;
      case MemberResolutionTargetType.additionalEmail:
        _replaceAdditionalEmailDraft(target.relationshipId, source);
        return;
      case MemberResolutionTargetType.primaryAddress:
        _primaryAddressDraft.replaceWith(
          source.primaryAddress ??
              const MitgliedKontaktAdresse(additionalAddressId: 0),
        );
        return;
      case MemberResolutionTargetType.additionalAddress:
        _replaceAdditionalAddressDraft(target.relationshipId, source);
        return;
    }
  }

  void _replacePhoneDraft(int? relationshipId, Mitglied source) {
    if (relationshipId == null) {
      return;
    }
    final index = _phoneDrafts.indexWhere(
      (draft) => draft.phoneNumberId == relationshipId,
    );
    final replacement = source.telefonnummern.where(
      (phone) => phone.phoneNumberId == relationshipId,
    );
    if (replacement.isEmpty) {
      if (index >= 0) {
        final removed = _phoneDrafts.removeAt(index);
        removed.dispose();
      }
      return;
    }
    final nextDraft = _PhoneDraft.fromTelefon(replacement.first);
    if (index >= 0) {
      final removed = _phoneDrafts.removeAt(index);
      removed.dispose();
      _phoneDrafts.insert(index, nextDraft);
      return;
    }
    _phoneDrafts.add(nextDraft);
  }

  void _replaceAdditionalEmailDraft(int? relationshipId, Mitglied source) {
    if (relationshipId == null) {
      return;
    }
    final index = _additionalEmailDrafts.indexWhere(
      (draft) => draft.additionalEmailId == relationshipId,
    );
    final replacement = source.emailAdressen.where(
      (email) => !email.istPrimaer && email.additionalEmailId == relationshipId,
    );
    if (replacement.isEmpty) {
      if (index >= 0) {
        final removed = _additionalEmailDrafts.removeAt(index);
        removed.dispose();
      }
      return;
    }
    final nextDraft = _EmailDraft.fromEmail(replacement.first);
    if (index >= 0) {
      final removed = _additionalEmailDrafts.removeAt(index);
      removed.dispose();
      _additionalEmailDrafts.insert(index, nextDraft);
      return;
    }
    _additionalEmailDrafts.add(nextDraft);
  }

  void _replaceAdditionalAddressDraft(int? relationshipId, Mitglied source) {
    if (relationshipId == null) {
      return;
    }
    final index = _additionalAddressDrafts.indexWhere(
      (draft) => draft.additionalAddressId == relationshipId,
    );
    final replacement = source.adressen.where(
      (address) => address.additionalAddressId == relationshipId,
    );
    if (replacement.isEmpty) {
      if (index >= 0) {
        final removed = _additionalAddressDrafts.removeAt(index);
        removed.dispose();
      }
      return;
    }
    final nextDraft = _AddressDraft.fromAdresse(replacement.first);
    if (index >= 0) {
      final removed = _additionalAddressDrafts.removeAt(index);
      removed.dispose();
      _additionalAddressDrafts.insert(index, nextDraft);
      return;
    }
    _additionalAddressDrafts.add(nextDraft);
  }

  String _labelForResolutionTarget(MemberResolutionTarget target) {
    switch (target.type) {
      case MemberResolutionTargetType.firstName:
        return _t.t('member_edit_field_first_name');
      case MemberResolutionTargetType.lastName:
        return _t.t('member_edit_field_last_name');
      case MemberResolutionTargetType.nickname:
        return _t.t('member_edit_field_nickname');
      case MemberResolutionTargetType.gender:
        return _t.t('member_edit_field_gender');
      case MemberResolutionTargetType.birthday:
        return _t.t('member_edit_field_birthday');
      case MemberResolutionTargetType.pronoun:
        return _t.t('member_edit_field_pronoun');
      case MemberResolutionTargetType.bankAccount:
        return _t.t('member_edit_section_bank');
      case MemberResolutionTargetType.primaryEmail:
        return _t.t('member_edit_field_primary_email');
      case MemberResolutionTargetType.phone:
        return _t.t('member_edit_field_phone');
      case MemberResolutionTargetType.additionalEmail:
        return _t.t('member_edit_field_additional_email');
      case MemberResolutionTargetType.primaryAddress:
        return _t.t('member_edit_field_primary_address');
      case MemberResolutionTargetType.additionalAddress:
        return _t.t('member_edit_field_additional_address');
    }
  }

  List<_ResolutionValueLine> _buildResolutionLinesFromCurrent(
    MemberResolutionTarget target,
  ) {
    switch (target.type) {
      case MemberResolutionTargetType.firstName:
        return _singleResolutionValueLine(_vornameController.text);
      case MemberResolutionTargetType.lastName:
        return _singleResolutionValueLine(_nachnameController.text);
      case MemberResolutionTargetType.nickname:
        return _singleResolutionValueLine(_fahrtennameController.text);
      case MemberResolutionTargetType.gender:
        return _singleResolutionValueLine(_labelForGender(_gender ?? ''));
      case MemberResolutionTargetType.birthday:
        return _singleResolutionValueLine(
          _geburtsdatum == null ? null : _dateFormat.format(_geburtsdatum!),
        );
      case MemberResolutionTargetType.pronoun:
        return _singleResolutionValueLine(_pronounController.text);
      case MemberResolutionTargetType.bankAccount:
        return _buildBankResolutionLines(
          accountOwner: _bankAccountOwnerController.text,
          iban: _ibanController.text,
          bic: _bicController.text,
          bankName: _bankNameController.text,
          paymentMethod: _paymentMethod,
        );
      case MemberResolutionTargetType.primaryEmail:
        return _singleResolutionValueLine(_primaryEmailController.text);
      case MemberResolutionTargetType.phone:
        final draft = _findPhoneDraft(target.relationshipId);
        return _buildPhoneResolutionLines(
          label: _contactLabel(
            ContactAccountType.phoneNumber,
            draft?.categoryId,
            draft?.labelController.text,
          ),
          value: draft?.toTelefon()?.wert ?? draft?.wertController.text,
          istOeffentlich: draft?.istOeffentlich,
        );
      case MemberResolutionTargetType.additionalEmail:
        final draft = _findAdditionalEmailDraft(target.relationshipId);
        return _buildEmailResolutionLines(
          label: _contactLabel(
            ContactAccountType.additionalEmail,
            draft?.categoryId,
            draft?.labelController.text,
          ),
          value: draft?.wertController.text,
        );
      case MemberResolutionTargetType.primaryAddress:
        return _buildAddressResolutionLines(_primaryAddressDraft.toAdresse());
      case MemberResolutionTargetType.additionalAddress:
        final draft = _findAdditionalAddressDraft(target.relationshipId);
        return _buildAddressResolutionLines(draft?.toAdresse());
    }
  }

  List<_ResolutionValueLine> _buildResolutionLinesFromMember(
    Mitglied? member,
    MemberResolutionTarget target,
  ) {
    if (member == null) {
      return <_ResolutionValueLine>[
        _ResolutionValueLine(
          label: _t.t('member_edit_resolution_value_label'),
          value: _t.t('member_edit_value_not_available'),
        ),
      ];
    }
    switch (target.type) {
      case MemberResolutionTargetType.firstName:
        return _singleResolutionValueLine(member.vorname);
      case MemberResolutionTargetType.lastName:
        return _singleResolutionValueLine(member.nachname);
      case MemberResolutionTargetType.nickname:
        return _singleResolutionValueLine(member.fahrtenname);
      case MemberResolutionTargetType.gender:
        return _singleResolutionValueLine(
          _labelForGender(_normalizeGenderValue(member.gender) ?? ''),
        );
      case MemberResolutionTargetType.birthday:
        return _singleResolutionValueLine(
          member.geburtsdatum == Mitglied.peoplePlaceholderDate
              ? null
              : _dateFormat.format(member.geburtsdatum),
        );
      case MemberResolutionTargetType.pronoun:
        return _singleResolutionValueLine(member.pronoun);
      case MemberResolutionTargetType.bankAccount:
        return _buildBankResolutionLines(
          accountOwner: member.bankAccountOwner,
          iban: member.iban,
          bic: member.bic,
          bankName: member.bankName,
          paymentMethod: member.paymentMethod,
        );
      case MemberResolutionTargetType.primaryEmail:
        return _singleResolutionValueLine(
          _resolvePrimaryEmail(member.emailAdressen)?.wert,
        );
      case MemberResolutionTargetType.phone:
        for (final phone in member.telefonnummern) {
          if (phone.phoneNumberId == target.relationshipId) {
            return _buildPhoneResolutionLines(
              label: _contactLabel(
                ContactAccountType.phoneNumber,
                phone.categoryId,
                phone.label,
              ),
              value: phone.wert,
              istOeffentlich: phone.istOeffentlich,
            );
          }
        }
        return _buildPhoneResolutionLines(label: null, value: null);
      case MemberResolutionTargetType.additionalEmail:
        for (final email in member.emailAdressen) {
          if (!email.istPrimaer &&
              email.additionalEmailId == target.relationshipId) {
            return _buildEmailResolutionLines(
              label: _contactLabel(
                ContactAccountType.additionalEmail,
                email.categoryId,
                email.label,
              ),
              value: email.wert,
            );
          }
        }
        return _buildEmailResolutionLines(label: null, value: null);
      case MemberResolutionTargetType.primaryAddress:
        return _buildAddressResolutionLines(member.primaryAddress);
      case MemberResolutionTargetType.additionalAddress:
        for (final address in member.adressen) {
          if (address.additionalAddressId == target.relationshipId) {
            return _buildAddressResolutionLines(address);
          }
        }
        return _buildAddressResolutionLines(null);
    }
  }

  List<_ResolutionValueLine> _singleResolutionValueLine(String? value) {
    return <_ResolutionValueLine>[
      _ResolutionValueLine(
        label: _t.t('member_edit_resolution_value_label'),
        value: _normalizeResolutionLineValue(value),
      ),
    ];
  }

  List<_ResolutionValueLine> _buildBankResolutionLines({
    String? accountOwner,
    String? iban,
    String? bic,
    String? bankName,
    String? paymentMethod,
  }) {
    return <_ResolutionValueLine>[
      _ResolutionValueLine(
        label: _t.t('member_edit_field_payment_method'),
        value: _normalizeResolutionLineValue(
          paymentMethod == null ? null : _labelForPaymentMethod(paymentMethod),
        ),
      ),
      _ResolutionValueLine(
        label: _t.t('member_edit_field_bank_account_owner'),
        value: _normalizeResolutionLineValue(accountOwner),
      ),
      _ResolutionValueLine(
        label: _t.t('member_edit_field_iban'),
        value: _normalizeResolutionLineValue(iban),
      ),
      _ResolutionValueLine(
        label: _t.t('member_edit_field_bic'),
        value: _normalizeResolutionLineValue(bic),
      ),
      _ResolutionValueLine(
        label: _t.t('member_edit_field_bank_name'),
        value: _normalizeResolutionLineValue(bankName),
      ),
    ];
  }

  List<_ResolutionValueLine> _buildPhoneResolutionLines({
    String? label,
    String? value,
    bool? istOeffentlich,
  }) {
    return <_ResolutionValueLine>[
      _ResolutionValueLine(
        label: _t.t('member_edit_field_label'),
        value: _normalizeResolutionLineValue(label),
      ),
      _ResolutionValueLine(
        label: _t.t('member_edit_field_phone_number'),
        value: _normalizeResolutionLineValue(value),
      ),
      if (istOeffentlich != null)
        _ResolutionValueLine(
          label: _t.t('member_edit_field_phone_public'),
          value: _t.t(
            istOeffentlich ? 'member_edit_value_yes' : 'member_edit_value_no',
          ),
        ),
    ];
  }

  List<_ResolutionValueLine> _buildEmailResolutionLines({
    String? label,
    String? value,
  }) {
    return <_ResolutionValueLine>[
      _ResolutionValueLine(
        label: _t.t('member_edit_field_label'),
        value: _normalizeResolutionLineValue(label),
      ),
      _ResolutionValueLine(
        label: _t.t('member_edit_section_email'),
        value: _normalizeResolutionLineValue(value),
      ),
    ];
  }

  List<_ResolutionValueLine> _buildAddressResolutionLines(
    MitgliedKontaktAdresse? adresse,
  ) {
    final isAdditional = adresse != null && adresse.additionalAddressId != 0;
    final name = [
      adresse?.firstName,
      adresse?.lastName,
      adresse?.organizationName,
    ].map((part) => _trimToNull(part ?? '')).whereType<String>().join(' ');
    return <_ResolutionValueLine>[
      if (isAdditional) ...[
        _ResolutionValueLine(
          label: _t.t('member_edit_field_label'),
          value: _normalizeResolutionLineValue(
            _contactLabel(
              ContactAccountType.additionalAddress,
              adresse.categoryId,
              adresse.label,
            ),
          ),
        ),
        _ResolutionValueLine(
          label: _t.t('member_edit_field_address_name'),
          value: _normalizeResolutionLineValue(name),
        ),
      ],
      _ResolutionValueLine(
        label: _t.t('member_edit_field_care_of'),
        value: _normalizeResolutionLineValue(adresse?.addressCareOf),
      ),
      _ResolutionValueLine(
        label: _t.t('member_edit_field_street'),
        value: _normalizeResolutionLineValue(adresse?.street),
      ),
      _ResolutionValueLine(
        label: _t.t('member_edit_field_house_number'),
        value: _normalizeResolutionLineValue(adresse?.housenumber),
      ),
      _ResolutionValueLine(
        label: _t.t('member_edit_field_postbox'),
        value: _normalizeResolutionLineValue(adresse?.postbox),
      ),
      _ResolutionValueLine(
        label: _t.t('member_edit_field_zip_code'),
        value: _normalizeResolutionLineValue(adresse?.zipCode),
      ),
      _ResolutionValueLine(
        label: _t.t('member_edit_field_town'),
        value: _normalizeResolutionLineValue(adresse?.town),
      ),
      _ResolutionValueLine(
        label: _t.t('member_edit_field_country'),
        value: _normalizeResolutionLineValue(adresse?.country),
      ),
    ];
  }

  String _normalizeResolutionLineValue(String? value) {
    final trimmed = _trimOptionalToNull(value);
    return trimmed ?? _t.t('member_edit_value_not_set');
  }

  String? _trimOptionalToNull(String? value) {
    if (value == null) {
      return null;
    }
    return _trimToNull(value);
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

    final nextAttributeErrors = <String, String>{};
    for (final error in result.validationErrors) {
      final attribute = error.attribute;
      if (error.relationshipName == null &&
          attribute != null &&
          _fieldAttributes.contains(attribute)) {
        nextAttributeErrors.putIfAbsent(attribute, () => error.message);
      }
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

    if (nextPhoneErrors.isEmpty && nextAttributeErrors.isEmpty) {
      return false;
    }

    setState(() {
      _serverPhoneErrorsById
        ..clear()
        ..addAll(nextPhoneErrors);
      _serverAttributeErrors
        ..clear()
        ..addAll(nextAttributeErrors);
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
  const _SectionCard({super.key, required this.title, required this.child});

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

class _ExpandableSectionCard extends StatelessWidget {
  const _ExpandableSectionCard({
    super.key,
    required this.title,
    required this.expanded,
    required this.onToggle,
    required this.child,
  });

  final String title;
  final bool expanded;
  final VoidCallback onToggle;
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
            InkWell(
              key: const Key('member-edit-resolution-edit-section-toggle'),
              onTap: onToggle,
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    Icon(
                      expanded
                          ? Icons.expand_less_outlined
                          : Icons.expand_more_outlined,
                    ),
                  ],
                ),
              ),
            ),
            if (expanded) ...[const SizedBox(height: 14), child],
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
    this.disabledHint,
  });

  final Widget child;
  final String addLabel;
  final VoidCallback? onAdd;

  /// Hinweis, warum ohne [onAdd] nichts hinzugefuegt werden kann.
  final String? disabledHint;

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
        ] else if (disabledHint != null) ...[
          const SizedBox(height: 8),
          Text(disabledHint!, style: Theme.of(context).textTheme.bodySmall),
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

class _ResolutionValueLine {
  const _ResolutionValueLine({required this.label, required this.value});

  final String label;
  final String value;
}

class _ResolutionValuePanel extends StatelessWidget {
  const _ResolutionValuePanel({required this.title, required this.lines});

  final String title;
  final List<_ResolutionValueLine> lines;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          Table(
            columnWidths: const <int, TableColumnWidth>{
              0: IntrinsicColumnWidth(),
              1: FlexColumnWidth(),
            },
            defaultVerticalAlignment: TableCellVerticalAlignment.top,
            children: lines
                .map(
                  (line) => TableRow(
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(right: 12, bottom: 8),
                        child: Text(
                          line.label,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text(line.value),
                      ),
                    ],
                  ),
                )
                .toList(growable: false),
          ),
        ],
      ),
    );
  }
}

class _PhoneDraft {
  _PhoneDraft({
    required this.phoneNumberId,
    required this.countryId,
    String? wert,
    String? label,
    this.categoryId,
    this.istOeffentlich = false,
  }) : wertController = TextEditingController(text: wert ?? ''),
       labelController = TextEditingController(text: label ?? '');

  factory _PhoneDraft.fromTelefon(MitgliedKontaktTelefon telefon) {
    final split = MemberPhoneInput.split(telefon.wert);
    return _PhoneDraft(
      phoneNumberId: telefon.phoneNumberId,
      countryId: split.countryId,
      wert: split.localNumber,
      label: telefon.label,
      categoryId: telefon.categoryId,
      istOeffentlich: telefon.istOeffentlich,
    );
  }

  factory _PhoneDraft.empty() => _PhoneDraft(
    phoneNumberId: null,
    countryId: MemberPhoneInput.defaultCountryId,
  );

  final int? phoneNumberId;
  String countryId;
  int? categoryId;
  bool istOeffentlich;
  final TextEditingController wertController;
  final TextEditingController labelController;
  final GlobalKey wertFieldKey = GlobalKey();
  final FocusNode wertFocusNode = FocusNode();

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
      categoryId: categoryId,
      istOeffentlich: istOeffentlich,
    );
  }

  void dispose() {
    wertController.dispose();
    labelController.dispose();
    wertFocusNode.dispose();
  }
}

class _EmailDraft {
  _EmailDraft({
    required this.additionalEmailId,
    String? wert,
    String? label,
    this.categoryId,
  }) : wertController = TextEditingController(text: wert ?? ''),
       labelController = TextEditingController(text: label ?? '');

  factory _EmailDraft.fromEmail(MitgliedKontaktEmail email) {
    return _EmailDraft(
      additionalEmailId: email.additionalEmailId,
      wert: email.wert,
      label: email.label,
      categoryId: email.categoryId,
    );
  }

  factory _EmailDraft.empty() => _EmailDraft(additionalEmailId: null);

  final int? additionalEmailId;
  int? categoryId;
  final TextEditingController wertController;
  final TextEditingController labelController;
  final GlobalKey wertFieldKey = GlobalKey();
  final FocusNode wertFocusNode = FocusNode();

  MitgliedKontaktEmail? toEmail() {
    final wert = _trimToNull(wertController.text);
    if (wert == null) {
      return null;
    }
    return MitgliedKontaktEmail(
      additionalEmailId: additionalEmailId,
      wert: wert,
      label: _trimToNull(labelController.text),
      categoryId: categoryId,
    );
  }

  void dispose() {
    wertController.dispose();
    labelController.dispose();
    wertFocusNode.dispose();
  }
}

class _AddressDraft {
  _AddressDraft({
    required this.additionalAddressId,
    String? label,
    this.categoryId,
    String? firstName,
    String? lastName,
    String? organizationName,
    String? addressCareOf,
    String? street,
    String? housenumber,
    String? postbox,
    String? zipCode,
    String? town,
    String? country,
  }) : labelController = TextEditingController(text: label ?? ''),
       firstNameController = TextEditingController(text: firstName ?? ''),
       lastNameController = TextEditingController(text: lastName ?? ''),
       organizationNameController = TextEditingController(
         text: organizationName ?? '',
       ),
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
      categoryId: adresse.categoryId,
      firstName: adresse.firstName,
      lastName: adresse.lastName,
      organizationName: adresse.organizationName,
      addressCareOf: adresse.addressCareOf,
      street: adresse.street,
      housenumber: adresse.housenumber,
      postbox: adresse.postbox,
      zipCode: adresse.zipCode,
      town: adresse.town,
      country: adresse.country,
    );
  }

  /// Neue Zusatzadresse; Hitobito verlangt einen Namen, deshalb ist der
  /// Name der Person vorbelegt.
  factory _AddressDraft.forNewEntry(Mitglied mitglied) => _AddressDraft(
    additionalAddressId: null,
    firstName: mitglied.vorname,
    lastName: mitglied.nachname,
  );

  final int? additionalAddressId;
  int? categoryId;
  final TextEditingController labelController;
  final TextEditingController firstNameController;
  final TextEditingController lastNameController;
  final TextEditingController organizationNameController;
  final TextEditingController addressCareOfController;
  final TextEditingController streetController;
  final TextEditingController housenumberController;
  final TextEditingController postboxController;
  final TextEditingController zipCodeController;
  final TextEditingController townController;
  final TextEditingController countryController;
  final GlobalKey labelFieldKey = GlobalKey();
  final GlobalKey addressCareOfFieldKey = GlobalKey();
  final GlobalKey streetFieldKey = GlobalKey();
  final GlobalKey housenumberFieldKey = GlobalKey();
  final GlobalKey postboxFieldKey = GlobalKey();
  final GlobalKey zipCodeFieldKey = GlobalKey();
  final GlobalKey townFieldKey = GlobalKey();
  final GlobalKey countryFieldKey = GlobalKey();
  final FocusNode streetFocusNode = FocusNode();

  MitgliedKontaktAdresse toAdresse() {
    return MitgliedKontaktAdresse(
      additionalAddressId: additionalAddressId,
      label: _trimToNull(labelController.text),
      categoryId: categoryId,
      firstName: _trimToNull(firstNameController.text),
      lastName: _trimToNull(lastNameController.text),
      organizationName: _trimToNull(organizationNameController.text),
      addressCareOf: _trimToNull(addressCareOfController.text),
      street: _trimToNull(streetController.text),
      housenumber: _trimToNull(housenumberController.text),
      postbox: _trimToNull(postboxController.text),
      zipCode: _trimToNull(zipCodeController.text),
      town: _trimToNull(townController.text),
      country: _trimToNull(countryController.text),
    );
  }

  void replaceWith(MitgliedKontaktAdresse adresse) {
    labelController.text = adresse.label ?? '';
    categoryId = adresse.categoryId;
    firstNameController.text = adresse.firstName ?? '';
    lastNameController.text = adresse.lastName ?? '';
    organizationNameController.text = adresse.organizationName ?? '';
    addressCareOfController.text = adresse.addressCareOf ?? '';
    streetController.text = adresse.street ?? '';
    housenumberController.text = adresse.housenumber ?? '';
    postboxController.text = adresse.postbox ?? '';
    zipCodeController.text = adresse.zipCode ?? '';
    townController.text = adresse.town ?? '';
    countryController.text = adresse.country ?? '';
  }

  void dispose() {
    labelController.dispose();
    firstNameController.dispose();
    lastNameController.dispose();
    organizationNameController.dispose();
    addressCareOfController.dispose();
    streetController.dispose();
    housenumberController.dispose();
    postboxController.dispose();
    zipCodeController.dispose();
    townController.dispose();
    countryController.dispose();
    streetFocusNode.dispose();
  }
}
