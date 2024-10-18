// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'mitglied.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class MitgliedAdapter extends TypeAdapter<Mitglied> {
  @override
  final int typeId = 1;

  @override
  Mitglied read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Mitglied()
      ..vorname = fields[0] as String
      ..nachname = fields[1] as String
      ..geschlechtId = (fields[3] as num).toInt()
      ..geburtsDatum = fields[4] as DateTime
      ..id = (fields[6] as num?)?.toInt()
      ..mitgliedsNummer = (fields[7] as num).toInt()
      ..eintrittsdatum = fields[8] as DateTime
      ..austrittsDatum = fields[9] as DateTime?
      ..ort = fields[10] as String
      ..plz = fields[11] as String
      ..strasse = fields[12] as String
      ..landId = (fields[13] as num).toInt()
      ..email = fields[14] as String?
      ..emailVertretungsberechtigter = fields[15] as String?
      ..telefon1 = fields[16] as String?
      ..telefon2 = fields[17] as String?
      ..telefon3 = fields[18] as String?
      ..lastUpdated = fields[19] as DateTime
      ..version = (fields[20] as num).toInt()
      ..mglTypeId = fields[21] as String
      ..beitragsartId = (fields[22] as num).toInt()
      ..status = fields[23] as String
      ..taetigkeiten = (fields[24] as List).cast<Taetigkeit>()
      ..ausbildungen =
          fields[25] == null ? [] : (fields[25] as List).cast<Ausbildung>()
      ..staatssangehaerigkeitId = (fields[26] as num).toInt()
      ..konfessionId = fields[27] as String?
      ..mitgliedszeitschrift = fields[28] as bool
      ..datenweiterverwendung = fields[29] as bool;
  }

  @override
  void write(BinaryWriter writer, Mitglied obj) {
    writer
      ..writeByte(28)
      ..writeByte(0)
      ..write(obj.vorname)
      ..writeByte(1)
      ..write(obj.nachname)
      ..writeByte(3)
      ..write(obj.geschlechtId)
      ..writeByte(4)
      ..write(obj.geburtsDatum)
      ..writeByte(6)
      ..write(obj.id)
      ..writeByte(7)
      ..write(obj.mitgliedsNummer)
      ..writeByte(8)
      ..write(obj.eintrittsdatum)
      ..writeByte(9)
      ..write(obj.austrittsDatum)
      ..writeByte(10)
      ..write(obj.ort)
      ..writeByte(11)
      ..write(obj.plz)
      ..writeByte(12)
      ..write(obj.strasse)
      ..writeByte(13)
      ..write(obj.landId)
      ..writeByte(14)
      ..write(obj.email)
      ..writeByte(15)
      ..write(obj.emailVertretungsberechtigter)
      ..writeByte(16)
      ..write(obj.telefon1)
      ..writeByte(17)
      ..write(obj.telefon2)
      ..writeByte(18)
      ..write(obj.telefon3)
      ..writeByte(19)
      ..write(obj.lastUpdated)
      ..writeByte(20)
      ..write(obj.version)
      ..writeByte(21)
      ..write(obj.mglTypeId)
      ..writeByte(22)
      ..write(obj.beitragsartId)
      ..writeByte(23)
      ..write(obj.status)
      ..writeByte(24)
      ..write(obj.taetigkeiten)
      ..writeByte(25)
      ..write(obj.ausbildungen)
      ..writeByte(26)
      ..write(obj.staatssangehaerigkeitId)
      ..writeByte(27)
      ..write(obj.konfessionId)
      ..writeByte(28)
      ..write(obj.mitgliedszeitschrift)
      ..writeByte(29)
      ..write(obj.datenweiterverwendung);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MitgliedAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
