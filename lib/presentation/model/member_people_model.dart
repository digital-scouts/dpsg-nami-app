import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../domain/member/member_people_repository.dart';
import '../../domain/member/mitglied.dart';
import '../../services/logger_service.dart';

class MemberPeopleModel extends ChangeNotifier {
  MemberPeopleModel({
    required MemberPeopleRepository repository,
    required LoggerService logger,
  }) : _repository = repository,
       _logger = logger;

  final MemberPeopleRepository _repository;
  final LoggerService _logger;

  List<Mitglied> _members = const <Mitglied>[];
  bool _isLoading = false;
  bool _isRefreshing = false;
  bool _hasLoaded = false;
  String? _errorMessage;
  bool _lastRemoteRefreshSucceeded = false;
  int _refreshFailureCount = 0;

  List<Mitglied> get members => _members;
  bool get isLoading => _isLoading;
  bool get isRefreshing => _isRefreshing;
  String? get errorMessage => _errorMessage;
  bool get lastRemoteRefreshSucceeded => _lastRemoteRefreshSucceeded;
  int get refreshFailureCount => _refreshFailureCount;

  Future<void> load({
    required String? accessToken,
    bool force = false,
    bool refreshRemotely = true,
  }) async {
    if (_isLoading || _isRefreshing) {
      return;
    }
    if (_hasLoaded && !force) {
      return;
    }

    _hasLoaded = true;
    _isLoading = true;
    _errorMessage = null;
    _lastRemoteRefreshSucceeded = false;
    notifyListeners();

    try {
      _members = await _repository.loadCached();
    } catch (error, stack) {
      await _logger.log(
        'people',
        'Lokaler Mitglieder-Cache konnte nicht geladen werden: $error\n$stack',
      );
    } finally {
      _isLoading = false;
      notifyListeners();
    }

    if (accessToken == null || accessToken.isEmpty) {
      if (_members.isEmpty) {
        _errorMessage = 'login_required';
        notifyListeners();
      }
      return;
    }

    if (!refreshRemotely && _members.isNotEmpty) {
      return;
    }

    _isRefreshing = true;
    notifyListeners();

    try {
      _members = await _repository.refresh(accessToken);
      _errorMessage = null;
      _lastRemoteRefreshSucceeded = true;
    } catch (error, stack) {
      await _logger.log(
        'people',
        'Mitglieder konnten nicht aktualisiert werden: $error\n$stack',
      );
      _errorMessage = error.toString();
      _refreshFailureCount += 1;
    } finally {
      _isRefreshing = false;
      notifyListeners();
    }
  }
}
