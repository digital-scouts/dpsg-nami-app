// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'dataChanges.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class DataChangeAdapter extends TypeAdapter<DataChange> {
  @override
  final int typeId = 0;

  @override
  DataChange read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return DataChange(
      id: (fields[0] as num).toInt(),
      changeDate: fields[1] as DateTime,
      gruppierung: (fields[2] as num).toInt(),
      action: (fields[3] as num).toInt(),
      changedFields: (fields[4] as List).cast<String>(),
    );
  }

  @override
  void write(BinaryWriter writer, DataChange obj) {
    writer
      ..writeByte(5)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.changeDate)
      ..writeByte(2)
      ..write(obj.gruppierung)
      ..writeByte(3)
      ..write(obj.action)
      ..writeByte(4)
      ..write(obj.changedFields);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DataChangeAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
