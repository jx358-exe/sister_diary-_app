import 'package:hive_flutter/hive_flutter.dart';
import 'models/schedule_item.dart';

void main() async {
  await Hive.initFlutter();
  Hive.registerAdapter(ScheduleItemAdapter());
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  int themeIndex = 0;
  // 0粉色原版 1加深薄荷绿 2深蓝男生
  ThemeData get currentTheme {
    switch (themeIndex) {
      case 1:
        return ThemeData(
          scaffoldBackgroundColor: const Color(0xFFE6F9EF),
          colorScheme: ColorScheme.light(primary: const Color(0xFF58BC98)),
        );
      case 2:
        return ThemeData(
          scaffoldBackgroundColor: const Color(0xFF1A2332),
          colorScheme: ColorScheme.dark(primary: const Color(0xFF4285F4)),
        );
      default:
        return ThemeData(
          scaffoldBackgroundColor: const Color(0xFFFFF0F6),
          colorScheme: ColorScheme.light(primary: Color(0xFFF28FB0)),
        );
    }
  }

  @override
  void initState() {
    super.initState();
    final box = Hive.box('settingBox');
    themeIndex = box.get("themeIndex", defaultValue: 0);
  }

  void changeTheme(int idx) {
    setState(() {
      themeIndex = idx;
    });
    Hive.box('settingBox').put("themeIndex", idx);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: "My Schedule",
      debugShowCheckedModeBanner: false,
      theme: currentTheme,
      initialRoute: '/',
      routes: {
        '/': (context) => MySchedulePage(changeTheme: changeTheme),
        '/voiceNote': (context) => const VoiceSummaryPage(),
        '/myPlan': (context) => const MyPlanPage(),
        '/diary': (context) => const DiaryPage(),
        '/aiChat': (context) => const AiChatPage(),
        '/health': (context) => const HealthManagementPage(),
        '/sharing': (context) => const SharingMomentPage(),
      },
    );
  }
}

// ---------------- 日程模型 ----------------
@HiveType(typeId: 0)
class ScheduleItem extends HiveObject {
  @HiveField(0)
  String title;
  @HiveField(1)
  String time;
  @HiveField(2)
  bool isCompleted;
  @HiveField(3)
  String date;

  ScheduleItem({
    required this.title,
    required this.time,
    required this.isCompleted,
    required this.date,
  });
}

// ---------------- 日程主页 ----------------
class MySchedulePage extends StatefulWidget {
  final void Function(int) changeTheme;
  const MySchedulePage({super.key, required this.changeTheme});

  @override
  State<MySchedulePage> createState() => _MySchedulePageState();
}

class _MySchedulePageState extends State<MySchedulePage> {
  late Box scheduleBox;
  DateTime selectedDate = DateTime.now();
  final int maxCount = 20;

  @override
  void initState() {
    super.initState();
    scheduleBox = Hive.box('scheduleBox');
  }

  List<ScheduleItem> get todayList {
    final all = scheduleBox.values.cast<ScheduleItem>().toList();
    final target = "${selectedDate.year}-${selectedDate.month}-${selectedDate.day}";
    return all.where((e) => e.date == target).toList();
  }

  void addSchedule() {
    if (todayList.length >= maxCount) return;
    showDialog(
      context: context,
      builder: (ctx) {
        TextEditingController tCtrl = TextEditingController();
        TextEditingController timeCtrl = TextEditingController();
        return AlertDialog(
          title: const Text("Add schedule"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: tCtrl, decoration: const InputDecoration(labelText: "日程内容")),
              TextField(controller: timeCtrl, decoration: const InputDecoration(labelText: "时间")),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("取消")),
            TextButton(onPressed: () {
              final item = ScheduleItem(
                title: tCtrl.text,
                time: timeCtrl.text,
                isCompleted: false,
                date: "${selectedDate.year}-${selectedDate.month}-${selectedDate.day}",
              );
              scheduleBox.add(item);
              setState(() {});
              Navigator.pop(ctx);
            }, child: const Text("保存")),
          ],
        );
      },
    );
  }

  void toggleComplete(int index) {
    final item = todayList[index];
    item.isCompleted = !item.isCompleted;
    item.save();
    setState(() {});
  }

  Future pickDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );
    if (d != null) {
      setState(() {
        selectedDate = d;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("${selectedDate.year}/${selectedDate.month}/${selectedDate.day}"),
        actions: [
          IconButton(onPressed: pickDate, icon: const Icon(Icons.calendar_today)),
          PopupMenuButton<int>(
            onSelected: widget.changeTheme,
            itemBuilder: (c) => const [
              PopupMenuItem(value: 0, child: Text("粉色")),
              PopupMenuItem(value: 1, child: Text("薄荷绿")),
              PopupMenuItem(value: 2, child: Text("深蓝")),
            ],
          )
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              itemCount: todayList.length,
              itemBuilder: (c, i) {
                final it = todayList[i];
                return GestureDetector(
                  onLongPress: () => toggleComplete(i),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.symmetric(horizontal:12, vertical:4),
                    decoration: BoxDecoration(
                      color: it.isCompleted ? Colors.grey[300] : null,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Text(it.time, style: TextStyle(
                            decoration: it.isCompleted ? TextDecoration.lineThrough : null,
                            color: it.isCompleted ? Colors.grey : null
                        )),
                        const SizedBox(width:16),
                        Expanded(child: Text(it.title, style: TextStyle(
                            decoration: it.isCompleted ? TextDecoration.lineThrough : null,
                            color: it.isCompleted ? Colors.grey : null
                        ))),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(onPressed: addSchedule, child: const Text("Add schedule")),
          )
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.schedule), label: "Schedule"),
          BottomNavigationBarItem(icon: Icon(Icons.assignment), label: "My Plan"),
          BottomNavigationBarItem(icon: Icon(Icons.edit), label: "Diary"),
          BottomNavigationBarItem(icon: Icon(Icons.chat), label: "AI Chat"),
          BottomNavigationBarItem(icon: Icon(Icons.favorite), label: "Health"),
          BottomNavigationBarItem(icon: Icon(Icons.image), label: "Sharing"),
        ],
        onTap: (idx) {
          switch(idx){
            case 1: Navigator.pushNamed(context, "/myPlan"); break;
            case 2: Navigator.pushNamed(context, "/diary"); break;
            case 3: Navigator.pushNamed(context, "/aiChat"); break;
            case 4: Navigator.pushNamed(context, "/health"); break;
            case 5: Navigator.pushNamed(context, "/sharing"); break;
          }
        },
      ),
    );
  }
}

// ---------------- 占位页面（你后面再补逻辑） ----------------
class MyPlanPage extends StatelessWidget {
  const MyPlanPage({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("My plan"), leading: IconButton(onPressed: ()=>Navigator.pop(context), icon: const Icon(Icons.arrow_back))),
      body: const Center(child: Text("My Plan 页面")),
    );
  }
}

class DiaryPage extends StatelessWidget {
  const DiaryPage({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(appBar: AppBar(title: const Text("Diary")), body: const Center(child: Text("Diary页面")));
  }
}

class VoiceSummaryPage extends StatelessWidget {
  const VoiceSummaryPage({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(appBar: AppBar(title: const Text("Voice Note")), body: const Center(child: Text("Voice Note")));
  }
}

class AiChatPage extends StatelessWidget {
  const AiChatPage({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(appBar: AppBar(title: const Text("Hi Mean / Hi Bro～")), body: const Center(child: Text("AI聊天页面")));
  }
}

class HealthManagementPage extends StatelessWidget {
  const HealthManagementPage({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(appBar: AppBar(title: const Text("Health Management")), body: const Center(child: Text("健康管理页面")));
  }
}

class SharingMomentPage extends StatelessWidget {
  const SharingMomentPage({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(appBar: AppBar(title: const Text("Sharing Moment")), body: const Center(child: Text("分享花园页面")));
  }
}