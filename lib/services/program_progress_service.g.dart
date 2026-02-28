// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'program_progress_service.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class ProgramProgressAdapter extends TypeAdapter<ProgramProgress> {
  @override
  final int typeId = 10;

  @override
  ProgramProgress read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ProgramProgress(
      programId: fields[0] as String,
      lastCompletedDayIndex: fields[1] as int,
      selectedWeekIndex: fields[2] as int,
      selectedDayIndex: fields[3] as int,
      isCompleted: fields[4] as bool,
      completedAt: fields[5] as DateTime?,
    );
  }

  @override
  void write(BinaryWriter writer, ProgramProgress obj) {
    writer
      ..writeByte(6)
      ..writeByte(0)
      ..write(obj.programId)
      ..writeByte(1)
      ..write(obj.lastCompletedDayIndex)
      ..writeByte(2)
      ..write(obj.selectedWeekIndex)
      ..writeByte(3)
      ..write(obj.selectedDayIndex)
      ..writeByte(4)
      ..write(obj.isCompleted)
      ..writeByte(5)
      ..write(obj.completedAt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ProgramProgressAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
