import 'package:hive/hive.dart';
part 'hive_models.g.dart';

@HiveType(typeId: 0)
class ScheduleItem extends HiveObject {
  @HiveField(0)
  String dateKey;

  @HiveField(1)
  String time;

  @HiveField(2)
  String title;

  @HiveField(3)
  String note;

  @HiveField(4)
  bool isDone;

  ScheduleItem({
    required this.dateKey,
    required this.time,
    required this.title,
    this.note = "",
    this.isDone = false,
  });
}

@HiveType(typeId: 1)
class DiaryRecord extends HiveObject {
  @HiveField(0)
  String dateStr;

  @HiveField(1)
  bool hasRecord;

  @HiveField(2)
  String aiSummary;

  DiaryRecord({
    required this.dateStr,
    this.hasRecord = false,
    this.aiSummary = "",
  });
}

@HiveType(typeId: 2)
class GardenData extends HiveObject {
  @HiveField(0)
  String seedName;

  @HiveField(1)
  int growthDay;

  @HiveField(2)
  bool hasPlanted;

  GardenData({
    this.seedName = "向日葵",
    this.growthDay = 0,
    this.hasPlanted = true,
  });
}

@HiveType(typeId: 3)
class AppSetting extends HiveObject {
  @HiveField(0)
  int themeIndex;

  @HiveField(1)
  String userId;

  AppSetting({
    this.themeIndex = 0,
    this.userId = "USER887766",
  });
}