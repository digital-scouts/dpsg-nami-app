// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'taetigkeit.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class TaetigkeitAdapter extends TypeAdapter<Taetigkeit> {
  @override
  final int typeId = 2;

  @override
  Taetigkeit read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Taetigkeit()
      ..id = fields[0] as int
      ..taetigkeit = fields[1] as String
      ..aktivVon = fields[2] as DateTime
      ..aktivBis = fields[3] as DateTime?
      ..anlagedatum = fields[4] as DateTime
      ..untergliederung = fields[5] as String?
      ..gruppierung = fields[6] as String
      ..berechtigteGruppe = fields[7] as String?
      ..berechtigteUntergruppen = fields[8] as String?;
  }

  @override
  void write(BinaryWriter writer, Taetigkeit obj) {
    writer
      ..writeByte(9)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.taetigkeit)
      ..writeByte(2)
      ..write(obj.aktivVon)
      ..writeByte(3)
      ..write(obj.aktivBis)
      ..writeByte(4)
      ..write(obj.anlagedatum)
      ..writeByte(5)
      ..write(obj.untergliederung)
      ..writeByte(6)
      ..write(obj.gruppierung)
      ..writeByte(7)
      ..write(obj.berechtigteGruppe)
      ..writeByte(8)
      ..write(obj.berechtigteUntergruppen);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TaetigkeitAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
