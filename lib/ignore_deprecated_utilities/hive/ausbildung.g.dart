// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'ausbildung.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class AusbildungAdapter extends TypeAdapter<Ausbildung> {
  @override
  final typeId = 3;

  @override
  Ausbildung read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Ausbildung()
      ..id = (fields[0] as num).toInt()
      ..datum = fields[1] as DateTime
      ..veranstalter = fields[2] as String
      ..name = fields[3] as String
      ..baustein = fields[4] as String;
  }

  @override
  void write(BinaryWriter writer, Ausbildung obj) {
    writer
      ..writeByte(5)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.datum)
      ..writeByte(2)
      ..write(obj.veranstalter)
      ..writeByte(3)
      ..write(obj.name)
      ..writeByte(4)
      ..write(obj.baustein);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AusbildungAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
