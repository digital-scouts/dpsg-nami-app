import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:nami/utilities/hive/settings.dart';
import 'package:nami/utilities/logger.dart';
import 'package:nami/utilities/nami/model/nami_member_details.model.dart';
import 'package:nami/utilities/nami/nami.service.dart';
import 'package:nami/utilities/types.dart';

String get url => getNamiLUrl();
String get path => getNamiPath();

// Getter statt Top-Level-Variablen: Cookie und Gruppierung ändern sich nach
// einem Relogin bzw. Gruppierungswechsel und dürfen nicht eingefroren werden.
int? get gruppierungId => getGruppierungId();
String? get gruppierungName => getGruppierungName();
String get cookie => getNamiApiCookie();

/// Sends a create/edit request and retries it once after a silent relogin if
/// the session expired. Throws [SessionExpiredException] if relogin failed.
Future<Map<String, dynamic>> _sendMemberRequest(
  Future<http.Response> Function(Map<String, String> headers) send,
  String action,
) async {
  final http.Response response;
  try {
    response = await sendWithRelogin(
      () => send({'Cookie': cookie, 'Content-Type': 'application/json'}),
    );
  } on SessionExpiredException {
    rethrow;
  } catch (e, st) {
    sensLog.e('Failed to $action member', error: e, stackTrace: st);
    throw MemberCreationException('Failed to $action member: $e');
  }

  final source = tryDecodeNamiBody(response);
  if (response.statusCode == 200 && source?['success'] == true) {
    return source!;
  }
  sensLog.e(
    'Failed to $action member: Status: ${response.statusCode}, success: ${source?['success']}, data: ${source?['data']}',
  );
  final data = source?['data'];
  final rawFieldInfo = data is Map ? data['fieldInfo'] : null;
  throw MemberCreationException(
    source?['message']?.toString() ??
        'NaMi hat mit Status ${response.statusCode} geantwortet',
    fieldInfo: rawFieldInfo is List
        ? rawFieldInfo.map((item) => FieldInfo.fromJson(item)).toList()
        : const [],
  );
}

Future<int> namiCreateMember(NamiMemberDetailsModel mitglied) async {
  if (!getNamiChangesEnabled()) {
    throw MemberCreationException('Changes are disabled');
  }
  if (cookie == 'testLoginCookie') {
    return 765343;
  }
  String fullUrl =
      '$url$path/mitglied/filtered-for-navigation/gruppierung/gruppierung/$gruppierungId';
  sensLog.i('Request: create Member');
  final body = jsonEncode(mitglied.toJson());
  final source = await _sendMemberRequest(
    (headers) => http.post(Uri.parse(fullUrl), headers: headers, body: body),
    'create',
  );
  sensLog.t('Response: Member with id ${sensId(source['data'])} created');
  return source['data']; // should be the id
}

Future<int> namiEditMember(NamiMemberDetailsModel mitglied) async {
  if (!getNamiChangesEnabled()) {
    throw MemberCreationException('Changes are disabled');
  }
  if (cookie == 'testLoginCookie') {
    return 765343;
  }
  String fullUrl =
      '$url$path/mitglied/filtered-for-navigation/gruppierung/gruppierung/$gruppierungId/${mitglied.id}';
  sensLog.i('Request: edit Member');
  final body = jsonEncode(mitglied.toJson());
  final source = await _sendMemberRequest(
    (headers) => http.put(Uri.parse(fullUrl), headers: headers, body: body),
    'edit',
  );
  sensLog.t('Response: Member with id ${sensId(source['data']['id'])} edited');
  return source['data']['id']; // should be the id
}
