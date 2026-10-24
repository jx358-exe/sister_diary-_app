import 'package:hive/hive.dart';
part 'hive_models.g.dart'; // 这个是自动生成的

// 1. 日程 My Schedule
@HiveType(typeId: 0)
class ScheduleItem extends HiveObject {
  @HiveField(0)
  String dateKey; // 格式：2026-10-24，用来按天分组

  @HiveField(1)
  String timeRange; // 18:00~20:00

  @HiveField(2)
  String taskContent;

  @HiveField(3)
  String? voicePath; // 录音本地路径，没有录音就是null

  @HiveField(4)
  DateTime createAt;

  ScheduleItem({
    required this.dateKey,
    required this.timeRange,
    required this.taskContent,
    this.voicePath,
    required this.createAt,
  });
}

// 2. 日记 Diary
@HiveType(typeId: 1)
class DiaryItem extends HiveObject {
  @HiveField(0)
  String dateKey;

  @HiveField(1)
  String content;

  @HiveField(2)
  String? voicePath;

  @HiveField(3)
  DateTime createAt;

  DiaryItem({
    required this.dateKey,
    required this.content,
    this.voicePath,
    required this.createAt,
  });
}

// 3. AI聊天记录 Chat
@HiveType(typeId: 2)
class ChatMessage extends HiveObject {
  @HiveField(0)
  bool isUser; // true=用户发的，false=AI回复

  @HiveField(1)
  String text;

  @HiveField(2)
  DateTime createAt;

  ChatMessage({
    required this.isUser,
    required this.text,
    required this.createAt,
  });
}

// 4. 健康管理 Health
@HiveType(typeId: 3)
class HealthRecord extends HiveObject {
  @HiveField(0)
  String dateKey;

  @HiveField(1)
  String mood; // 心情

  @HiveField(2)
  String sleep; // 睡眠时长

  @HiveField(3)
  int water; // 喝水杯数

  @HiveField(4)
  String exercise; // 运动记录

  @HiveField(5)
  DateTime createAt;

  HealthRecord({
    required this.dateKey,
    required this.mood,
    required this.sleep,
    required this.water,
    required this.exercise,
    required this.createAt,
  });
}

// 5. 长期计划 MyPlan
@HiveType(typeId: 4)
class PlanItem extends HiveObject {
  @HiveField(0)
  String title;

  @HiveField(1)
  String detail;

  @HiveField(2)
  bool isFinished;

  @HiveField(3)
  DateTime createAt;

  PlanItem({
    required this.title,
    required this.detail,
    this.isFinished = false,
    required this.createAt,
  });
}

// 6. App设置（主题、录音偏好等）
@HiveType(typeId: 5)
class AppSetting extends HiveObject {
  @HiveField(0)
  bool autoClearVoice; // 是否开启录音自动清理

  @HiveField(1)
  int voiceKeepDays; // 如果开启，保留多少天

  @HiveField(2)
  String themeMode;

  AppSetting({
    required this.autoClearVoice,
    required this.voiceKeepDays,
    required this.themeMode,
  });
}