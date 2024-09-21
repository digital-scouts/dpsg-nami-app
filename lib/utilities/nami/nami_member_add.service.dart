import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:nami/utilities/hive/settings.dart';
import 'package:nami/utilities/logger.dart';
import 'package:nami/utilities/nami/model/nami_member_details.model.dart';
import 'package:nami/utilities/types.dart';

String url = getNamiLUrl();
String path = getNamiPath();
int? gruppierungId = getGruppierungId();
String? gruppierungName = getGruppierungName();
String cookie = getNamiApiCookie();

Future<int> createMember(NamiMemberDetailsModel mitglied) async {
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
  final headers = {'Cookie': cookie, 'Content-Type': 'application/json'};
  final http.Response response;

  try {
    response =
        await http.post(Uri.parse(fullUrl), headers: headers, body: body);
  } catch (e, st) {
    sensLog.e('Failed to create member', error: e, stackTrace: st);
    throw MemberCreationException('Failed to create member: $e');
  }
  final source = json.decode(const Utf8Decoder().convert(response.bodyBytes));

  if (response.statusCode == 200 && source['success']) {
    sensLog.t('Response: Member with id ${sensId(source['data'])} created');
    return source['data']; // should be the id
  } else {
    sensLog.e(
        'Failed to create member: Status: ${response.statusCode}, success: ${source['success']}, data: ${source['data']}');
    throw MemberCreationException('',
        fieldInfo: (source['data']['fieldInfo'] as List)
            .map((item) => FieldInfo.fromJson(item))
            .toList());
  }
}
