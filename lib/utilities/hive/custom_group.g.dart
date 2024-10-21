// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'custom_group.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class CustomGroupAdapter extends TypeAdapter<CustomGroup> {
  @override
  final int typeId = 0;

  @override
  CustomGroup read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return CustomGroup(
      active: fields[0] == null ? false : fields[0] as bool,
      static: fields[5] == null ? false : fields[5] as bool,
      taetigkeiten: (fields[1] as List?)?.cast<String>(),
      iconCodePoint: (fields[2] as num?)?.toInt(),
      showNonMembers: fields[3] == null ? false : fields[3] as bool,
      showInactive: fields[4] == null ? false : fields[4] as bool,
      stufeIndex: (fields[6] as num?)?.toInt(),
    );
  }

  @override
  void write(BinaryWriter writer, CustomGroup obj) {
    writer
      ..writeByte(7)
      ..writeByte(0)
      ..write(obj.active)
      ..writeByte(1)
      ..write(obj.taetigkeiten)
      ..writeByte(2)
      ..write(obj.iconCodePoint)
      ..writeByte(3)
      ..write(obj.showNonMembers)
      ..writeByte(4)
      ..write(obj.showInactive)
      ..writeByte(5)
      ..write(obj.static)
      ..writeByte(6)
      ..write(obj.stufeIndex);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CustomGroupAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
