// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'mitglied.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class MitgliedAdapter extends TypeAdapter<Mitglied> {
  @override
  final int typeId = 0;

  @override
  Mitglied read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Mitglied()
      ..vorname = fields[0] as String
      ..nachname = fields[1] as String;
  }

  @override
  void write(BinaryWriter writer, Mitglied obj) {
    writer
      ..writeByte(2)
      ..writeByte(0)
      ..write(obj.vorname)
      ..writeByte(1)
      ..write(obj.nachname);
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
