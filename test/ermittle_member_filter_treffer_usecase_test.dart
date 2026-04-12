import 'package:flutter_test/flutter_test.dart';
import 'package:nami/domain/arbeitskontext/arbeitskontext.dart';
import 'package:nami/domain/arbeitskontext/arbeitskontext_read_model.dart';
import 'package:nami/domain/member/mitglied.dart';
import 'package:nami/domain/member_filters/member_custom_filter.dart';
import 'package:nami/domain/member_filters/usecases/ermittle_member_filter_treffer_usecase.dart';

void main() {
  group('ErmittleMemberFilterTrefferUseCase', () {
    test('stage rule with hatNicht matches members without derived stage', () {
      const useCase = ErmittleMemberFilterTrefferUseCase();
      final readModel = ArbeitskontextReadModel(
        arbeitskontext: Arbeitskontext(
          aktiverLayer: const ArbeitskontextLayer(id: 11, name: 'Stamm'),
        ),
        mitglieder: <Mitglied>[
          Mitglied.peopleListItem(
            mitgliedsnummer: '1',
            vorname: 'Julia',
            nachname: 'Keller',
          ),
          Mitglied.peopleListItem(
            mitgliedsnummer: '2',
            vorname: 'Mara',
            nachname: 'Schmidt',
          ),
        ],
        gruppen: const <ArbeitskontextGruppe>[
          ArbeitskontextGruppe(
            id: 21,
            name: 'Woelflinge',
            layerId: 11,
            gruppenTyp: 'Group::Meute',
          ),
        ],
        mitgliedsZuordnungen: const <ArbeitskontextMitgliedsZuordnung>[
          ArbeitskontextMitgliedsZuordnung(mitgliedsnummer: '1', gruppenId: 21),
        ],
      );

      const group = MemberCustomFilterGroup(
        id: 'rest',
        shortLabel: 'Rest',
        isActive: true,
        logic: MemberCustomFilterLogic.oder,
        rules: <MemberCustomFilterRule>[
          MemberCustomFilterRule(
            operator: MemberCustomFilterRuleOperator.hatNicht,
            criterion: MemberCustomFilterCriterion.stufe(),
          ),
        ],
      );

      final result = useCase(
        readModel,
        customGroups: <MemberCustomFilterGroup>[group],
      );

      expect(result['2'], contains(group.filterKey));
      expect(result['1'] ?? const <String>{}, isNot(contains(group.filterKey)));
    });

    test(
      'group rule with all roles matches any role in the selected group',
      () {
        const useCase = ErmittleMemberFilterTrefferUseCase();
        final readModel = ArbeitskontextReadModel(
          arbeitskontext: Arbeitskontext(
            aktiverLayer: const ArbeitskontextLayer(id: 11, name: 'Stamm'),
          ),
          mitglieder: <Mitglied>[
            Mitglied.peopleListItem(
              mitgliedsnummer: '1',
              vorname: 'Julia',
              nachname: 'Keller',
            ),
            Mitglied.peopleListItem(
              mitgliedsnummer: '2',
              vorname: 'Mara',
              nachname: 'Schmidt',
            ),
          ],
          gruppen: const <ArbeitskontextGruppe>[
            ArbeitskontextGruppe(id: 21, name: 'Roverrunde', layerId: 11),
            ArbeitskontextGruppe(id: 22, name: 'Sippe', layerId: 11),
          ],
          mitgliedsZuordnungen: const <ArbeitskontextMitgliedsZuordnung>[
            ArbeitskontextMitgliedsZuordnung(
              mitgliedsnummer: '1',
              gruppenId: 21,
              rollenTyp: 'Role::Rover',
              rollenLabel: 'Mitglied',
            ),
            ArbeitskontextMitgliedsZuordnung(
              mitgliedsnummer: '2',
              gruppenId: 22,
              rollenTyp: 'Role::Pfadi',
              rollenLabel: 'Leitung',
            ),
          ],
        );

        const group = MemberCustomFilterGroup(
          id: 'rover',
          shortLabel: 'Rover',
          isActive: true,
          logic: MemberCustomFilterLogic.oder,
          rules: <MemberCustomFilterRule>[
            MemberCustomFilterRule(
              operator: MemberCustomFilterRuleOperator.hat,
              criterion: MemberCustomFilterCriterion.groupRole(
                groupId: 21,
                groupName: 'Roverrunde',
              ),
            ),
          ],
        );

        final result = useCase(
          readModel,
          customGroups: <MemberCustomFilterGroup>[group],
        );

        expect(result['1'], contains(group.filterKey));
        expect(
          result['2'] ?? const <String>{},
          isNot(contains(group.filterKey)),
        );
      },
    );
  });
}
