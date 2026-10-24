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
      timeRange: fields[1] as String,
      taskContent: fields[2] as String,
      voicePath: fields[3] as String?,
      createAt: fields[4] as DateTime,
    );
  }

  @override
  void write(BinaryWriter writer, ScheduleItem obj) {
    writer
      ..writeByte(5)
      ..writeByte(0)
      ..write(obj.dateKey)
      ..writeByte(1)
      ..write(obj.timeRange)
      ..writeByte(2)
      ..write(obj.taskContent)
      ..writeByte(3)
      ..write(obj.voicePath)
      ..writeByte(4)
      ..write(obj.createAt);
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

class DiaryItemAdapter extends TypeAdapter<DiaryItem> {
  @override
  final int typeId = 1;

  @override
  DiaryItem read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return DiaryItem(
      dateKey: fields[0] as String,
      content: fields[1] as String,
      voicePath: fields[2] as String?,
      createAt: fields[3] as DateTime,
    );
  }

  @override
  void write(BinaryWriter writer, DiaryItem obj) {
    writer
      ..writeByte(4)
      ..writeByte(0)
      ..write(obj.dateKey)
      ..writeByte(1)
      ..write(obj.content)
      ..writeByte(2)
      ..write(obj.voicePath)
      ..writeByte(3)
      ..write(obj.createAt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DiaryItemAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class ChatMessageAdapter extends TypeAdapter<ChatMessage> {
  @override
  final int typeId = 2;

  @override
  ChatMessage read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ChatMessage(
      isUser: fields[0] as bool,
      text: fields[1] as String,
      createAt: fields[2] as DateTime,
    );
  }

  @override
  void write(BinaryWriter writer, ChatMessage obj) {
    writer
      ..writeByte(3)
      ..writeByte(0)
      ..write(obj.isUser)
      ..writeByte(1)
      ..write(obj.text)
      ..writeByte(2)
      ..write(obj.createAt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ChatMessageAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class HealthRecordAdapter extends TypeAdapter<HealthRecord> {
  @override
  final int typeId = 3;

  @override
  HealthRecord read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return HealthRecord(
      dateKey: fields[0] as String,
      mood: fields[1] as String,
      sleep: fields[2] as String,
      water: fields[3] as int,
      exercise: fields[4] as String,
      createAt: fields[5] as DateTime,
    );
  }

  @override
  void write(BinaryWriter writer, HealthRecord obj) {
    writer
      ..writeByte(6)
      ..writeByte(0)
      ..write(obj.dateKey)
      ..writeByte(1)
      ..write(obj.mood)
      ..writeByte(2)
      ..write(obj.sleep)
      ..writeByte(3)
      ..write(obj.water)
      ..writeByte(4)
      ..write(obj.exercise)
      ..writeByte(5)
      ..write(obj.createAt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HealthRecordAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class PlanItemAdapter extends TypeAdapter<PlanItem> {
  @override
  final int typeId = 4;

  @override
  PlanItem read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return PlanItem(
      title: fields[0] as String,
      detail: fields[1] as String,
      isFinished: fields[2] as bool,
      createAt: fields[3] as DateTime,
    );
  }

  @override
  void write(BinaryWriter writer, PlanItem obj) {
    writer
      ..writeByte(4)
      ..writeByte(0)
      ..write(obj.title)
      ..writeByte(1)
      ..write(obj.detail)
      ..writeByte(2)
      ..write(obj.isFinished)
      ..writeByte(3)
      ..write(obj.createAt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PlanItemAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class AppSettingAdapter extends TypeAdapter<AppSetting> {
  @override
  final int typeId = 5;

  @override
  AppSetting read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return AppSetting(
      autoClearVoice: fields[0] as bool,
      voiceKeepDays: fields[1] as int,
      themeMode: fields[2] as String,
    );
  }

  @override
  void write(BinaryWriter writer, AppSetting obj) {
    writer
      ..writeByte(3)
      ..writeByte(0)
      ..write(obj.autoClearVoice)
      ..writeByte(1)
      ..write(obj.voiceKeepDays)
      ..writeByte(2)
      ..write(obj.themeMode);
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
