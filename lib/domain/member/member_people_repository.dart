import 'mitglied.dart';

abstract class MemberPeopleRepository {
  Future<List<Mitglied>> loadCached();

  Future<List<Mitglied>> refresh(String accessToken);
}
