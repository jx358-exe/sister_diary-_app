// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'hive_models.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class ScheduleItemAdapter extends TypeAdapter<ScheduleItem> {
  @override
  final int typeId = 0;

  @override
  ScheduleItem read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ScheduleItem(
      dateKey: fields[0] as String,
      time: fields[1] as String,
      title: fields[2] as String,
      note: fields[3] as String,
      isDone: fields[4] as bool,
    );
  }

  @override
  void write(BinaryWriter writer, ScheduleItem obj) {
    writer
      ..writeByte(5)
      ..writeByte(0)
      ..write(obj.dateKey)
      ..writeByte(1)
      ..write(obj.time)
      ..writeByte(2)
      ..write(obj.title)
      ..writeByte(3)
      ..write(obj.note)
      ..writeByte(4)
      ..write(obj.isDone);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ScheduleItemAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class DiaryRecordAdapter extends TypeAdapter<DiaryRecord> {
  @override
  final int typeId = 1;

  @override
  DiaryRecord read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return DiaryRecord(
      dateStr: fields[0] as String,
      hasRecord: fields[1] as bool,
      aiSummary: fields[2] as String,
    );
  }

  @override
  void write(BinaryWriter writer, DiaryRecord obj) {
    writer
      ..writeByte(3)
      ..writeByte(0)
      ..write(obj.dateStr)
      ..writeByte(1)
      ..write(obj.hasRecord)
      ..writeByte(2)
      ..write(obj.aiSummary);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DiaryRecordAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class GardenDataAdapter extends TypeAdapter<GardenData> {
  @override
  final int typeId = 2;

  @override
  GardenData read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return GardenData(
      seedName: fields[0] as String,
      growthDay: fields[1] as int,
      hasPlanted: fields[2] as bool,
    );
  }

  @override
  void write(BinaryWriter writer, GardenData obj) {
    writer
      ..writeByte(3)
      ..writeByte(0)
      ..write(obj.seedName)
      ..writeByte(1)
      ..write(obj.growthDay)
      ..writeByte(2)
      ..write(obj.hasPlanted);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GardenDataAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class AppSettingAdapter extends TypeAdapter<AppSetting> {
  @override
  final int typeId = 3;

  @override
  AppSetting read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return AppSetting(
      themeIndex: fields[0] as int,
      userId: fields[1] as String,
    );
  }

  @override
  void write(BinaryWriter writer, AppSetting obj) {
    writer
      ..writeByte(2)
      ..writeByte(0)
      ..write(obj.themeIndex)
      ..writeByte(1)
      ..write(obj.userId);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AppSettingAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
