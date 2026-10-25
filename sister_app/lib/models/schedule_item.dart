import 'package:hive/hive.dart';
part 'schedule_item.g.dart';

@HiveType(typeId: 0)
class ScheduleItem extends HiveObject {
  @HiveField(0)
  String time;

  @HiveField(1)
  String title;

  @HiveField(2)
  String note;

  @HiveField(3)
  bool isDone;

  ScheduleItem({
    required this.time,
    required this.title,
    required this.note,
    required this.isDone,
  });
}