// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'workout_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class CustomWorkoutAdapter extends TypeAdapter<CustomWorkout> {
  @override
  final int typeId = 0;

  @override
  CustomWorkout read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return CustomWorkout(
      name: fields[0] as String,
      intervals: (fields[1] as List).cast<CustomInterval>(),
    );
  }

  @override
  void write(BinaryWriter writer, CustomWorkout obj) {
    writer
      ..writeByte(2)
      ..writeByte(0)
      ..write(obj.name)
      ..writeByte(1)
      ..write(obj.intervals);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CustomWorkoutAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class CustomIntervalAdapter extends TypeAdapter<CustomInterval> {
  @override
  final int typeId = 1;

  @override
  CustomInterval read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return CustomInterval(
      runDuration: fields[0] as int,
      walkDuration: fields[1] as int,
    );
  }

  @override
  void write(BinaryWriter writer, CustomInterval obj) {
    writer
      ..writeByte(2)
      ..writeByte(0)
      ..write(obj.runDuration)
      ..writeByte(1)
      ..write(obj.walkDuration);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CustomIntervalAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
