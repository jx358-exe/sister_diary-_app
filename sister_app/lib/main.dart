import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'hive_models.dart';

// -------------------------- 入口与Hive初始化 --------------------------
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  Hive.registerAdapter(ScheduleItemAdapter());
  Hive.registerAdapter(DiaryRecordAdapter());
  Hive.registerAdapter(GardenDataAdapter());
  Hive.registerAdapter(AppSettingAdapter());

  await Hive.openBox<ScheduleItem>("scheduleBox");
  await Hive.openBox<ScheduleItem>("planBox");
  await Hive.openBox<DiaryRecord>("diaryBox");
  await Hive.openBox<GardenData>("gardenBox");
  await Hive.openBox<AppSetting>("settingBox");

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  int themeIndex = 0;

  @override
  void initState() {
    super.initState();
    final settingBox = Hive.box<AppSetting>("settingBox");
    if (settingBox.isNotEmpty) {
      final setting = settingBox.values.first;
      themeIndex = setting.themeIndex;
    }
  }

  ThemeData get currentTheme {
    switch (themeIndex) {
      case 1:
        return ThemeData(
          scaffoldBackgroundColor: const Color(0xFFE6F9EF),
          colorScheme: ColorScheme.light(primary: const Color(0xFF42B98B)),
        );
      case 2:
        return ThemeData(
          scaffoldBackgroundColor: const Color(0xFF1A2332),
          colorScheme: ColorScheme.dark(primary: const Color(0xFF3B82F6)),
          textTheme: const TextTheme(bodyLarge: TextStyle(color: Colors.white70)),
          inputDecorationTheme: const InputDecorationTheme(
            labelStyle: TextStyle(color: Colors.white60),
          ),
        );
      default:
        return ThemeData(
          scaffoldBackgroundColor: const Color(0xFFFFF0F6),
          colorScheme: ColorScheme.light(primary: const Color(0xFFF28FB0)),
        );
    }
  }

  void setTheme(int idx) {
    setState(() {
      themeIndex = idx;
    });
    final box = Hive.box<AppSetting>("settingBox");
    if (box.isEmpty) {
      box.add(AppSetting(themeIndex: idx));
    } else {
      final s = box.values.first;
      s.themeIndex = idx;
      s.save();
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: "My Schedule",
      debugShowCheckedModeBanner: false,
      theme: currentTheme,
      initialRoute: '/schedule',
      routes: {
        '/myPlan': (context) => const MyPlanPage(),
        '/schedule': (context) => const MySchedulePage(),
        '/diary': (context) => const DiaryPage(),
        '/chatTime': (context) => const ChatTimePage(),
        '/health': (context) => const HealthManagementPage(),
        '/moment': (context) => const SharingMomentPage(),
        '/setting': (context) => SettingPage(
              selectTheme: setTheme,
            ),
        '/searchFriend': (context) => const SearchFriendPage(),
        '/friendList': (context) => const FriendListPage(),
      },
    );
  }
}

// ===================== My Schedule Page =====================
class MySchedulePage extends StatefulWidget {
  const MySchedulePage({super.key});
  @override
  State<MySchedulePage> createState() => _MySchedulePageState();
}

class _MySchedulePageState extends State<MySchedulePage> {
  DateTime selectedDate = DateTime.now();
  final int maxCount = 20;
  late Box<ScheduleItem> scheduleBox;

  String get selectedDateStr =>
      "${selectedDate.year}-${selectedDate.month.toString().padLeft(2, '0')}-${selectedDate.day.toString().padLeft(2, '0')}";

  @override
  void initState() {
    super.initState();
    scheduleBox = Hive.box<ScheduleItem>("scheduleBox");
  }

  List<ScheduleItem> get scheduleList => scheduleBox.values
      .where((item) => item.dateKey == selectedDateStr)
      .toList();

  void openNote(int index) {
    final item = scheduleList[index];
    final noteCtrl = TextEditingController(text: item.note);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("日程总结（文字）"),
        content: TextField(
          controller: noteCtrl,
          maxLines: 4,
          decoration: const InputDecoration(hintText: "打字记录"),
        ),
        actions: [
          TextButton(
            onPressed: () {
              item.note = noteCtrl.text;
              item.save();
              setState(() {});
              Navigator.pop(ctx);
            },
            child: const Text("保存"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("My Schedule"),
        centerTitle: true,
        actions: [
          IconButton(
              onPressed: () => Navigator.pushNamed(context, "/setting"),
              icon: const Icon(Icons.settings)),
        ],
      ),
      body: GestureDetector(
        onHorizontalDragEnd: (details) {
          if (details.primaryVelocity! > 250) {
            Navigator.pushNamed(context, "/myPlan");
          } else if (details.primaryVelocity! < -250) {
            Navigator.pushNamed(context, "/diary");
          }
        },
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              TextField(
                readOnly: true,
                controller: TextEditingController(text: selectedDateStr),
                decoration: const InputDecoration(
                    labelText: "选择日期", border: OutlineInputBorder()),
                onTap: () async {
                  final pick = await showDatePicker(
                    context: context,
                    initialDate: selectedDate,
                    firstDate: DateTime(2024),
                    lastDate: DateTime(2030),
                  );
                  if (pick != null) setState(() => selectedDate = pick);
                },
              ),
              const SizedBox(height: 16),
              Expanded(
                child: ListView.builder(
                  itemCount: scheduleList.length,
                  itemBuilder: (ctx, index) {
                    final item = scheduleList[index];
                    return GestureDetector(
                      onLongPress: () {
                        item.isDone = !item.isDone;
                        item.save();
                        setState(() {});
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Row(
                          children: [
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                    border: Border.all(color: Colors.black87),
                                    borderRadius: BorderRadius.circular(12)),
                                child: TextField(
                                  controller:
                                      TextEditingController(text: item.time),
                                  style: TextStyle(
                                    decoration: item.isDone
                                        ? TextDecoration.lineThrough
                                        : null,
                                    color: item.isDone ? Colors.grey : null,
                                  ),
                                  decoration: const InputDecoration(
                                      border: InputBorder.none, isDense: true),
                                  onChanged: (val) {
                                    item.time = val;
                                    item.save();
                                  },
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              flex: 2,
                              child: Container(
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                    border: Border.all(color: Colors.black87),
                                    borderRadius: BorderRadius.circular(12)),
                                child: TextField(
                                  controller:
                                      TextEditingController(text: item.title),
                                  style: TextStyle(
                                    decoration: item.isDone
                                        ? TextDecoration.lineThrough
                                        : null,
                                    color: item.isDone ? Colors.grey : null,
                                  ),
                                  decoration: const InputDecoration(
                                      border: InputBorder.none, isDense: true),
                                  onChanged: (val) {
                                    item.title = val;
                                    item.save();
                                  },
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              onPressed: () => openNote(index),
                              icon: Icon(Icons.local_florist,
                                  color: Theme.of(context).colorScheme.primary),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () {
                  if (scheduleList.length >= maxCount) return;
                  scheduleBox.add(ScheduleItem(
                      dateKey: selectedDateStr, time: "", title: "", note: ""));
                  setState(() {});
                },
                child: const Text("Add schedule"),
              ),
              const SizedBox(height: 12),
              BottomNavigationBar(
                currentIndex: 1,
                type: BottomNavigationBarType.fixed,
                items: const [
                  BottomNavigationBarItem(
                      icon: Icon(Icons.book), label: "My Plan"),
                  BottomNavigationBarItem(
                      icon: Icon(Icons.event), label: "My Schedule"),
                  BottomNavigationBarItem(
                      icon: Icon(Icons.note), label: "Diary"),
                  BottomNavigationBarItem(
                      icon: Icon(Icons.chat), label: "Chat Time"),
                  BottomNavigationBarItem(
                      icon: Icon(Icons.favorite), label: "Health Management"),
                  BottomNavigationBarItem(
                      icon: Icon(Icons.share), label: "Sharing Moment"),
                  BottomNavigationBarItem(
                      icon: Icon(Icons.settings), label: "Setting"),
                ],
                onTap: (idx) {
                  switch (idx) {
                    case 0:
                      Navigator.pushNamed(context, "/myPlan");
                      break;
                    case 1:
                      Navigator.pushNamed(context, "/schedule");
                      break;
                    case 2:
                      Navigator.pushNamed(context, "/diary");
                      break;
                    case 3:
                      Navigator.pushNamed(context, "/chatTime");
                      break;
                    case 4:
                      Navigator.pushNamed(context, "/health");
                      break;
                    case 5:
                      Navigator.pushNamed(context, "/moment");
                      break;
                    case 6:
                      Navigator.pushNamed(context, "/setting");
                      break;
                  }
                },
              )
            ],
          ),
        ),
      ),
    );
  }
}

// ===================== My Plan Page =====================
class MyPlanPage extends StatefulWidget {
  const MyPlanPage({super.key});
  @override
  State<MyPlanPage> createState() => _MyPlanPageState();
}

class _MyPlanPageState extends State<MyPlanPage> {
  DateTime selectedDate = DateTime.now();
  final int maxCount = 20;
  late Box<ScheduleItem> planBox;

  String get selectedDateStr =>
      "${selectedDate.year}-${selectedDate.month.toString().padLeft(2, '0')}-${selectedDate.day.toString().padLeft(2, '0')}";

  @override
  void initState() {
    super.initState();
    planBox = Hive.box<ScheduleItem>("planBox");
  }

  List<ScheduleItem> get planList => planBox.values
      .where((item) => item.dateKey == selectedDateStr)
      .toList();

  void openNote(int index) {
    final item = planList[index];
    final noteCtrl = TextEditingController(text: item.note);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("计划总结（文字）"),
        content: TextField(
          controller: noteCtrl,
          maxLines: 4,
          decoration: const InputDecoration(hintText: "打字记录"),
        ),
        actions: [
          TextButton(
            onPressed: () {
              item.note = noteCtrl.text;
              item.save();
              setState(() {});
              Navigator.pop(ctx);
            },
            child: const Text("保存"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
          title: const Text("My Plan"),
          leading: IconButton(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.arrow_back))),
      body: GestureDetector(
        onHorizontalDragEnd: (details) {
          if (details.primaryVelocity! > 250) {
            Navigator.pushNamed(context, "/schedule");
          }
        },
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              TextField(
                readOnly: true,
                controller: TextEditingController(text: selectedDateStr),
                decoration: const InputDecoration(
                    labelText: "选择日期", border: OutlineInputBorder()),
                onTap: () async {
                  final pick = await showDatePicker(
                    context: context,
                    initialDate: selectedDate,
                    firstDate: DateTime(2024),
                    lastDate: DateTime(2030),
                  );
                  if (pick != null) setState(() => selectedDate = pick);
                },
              ),
              const SizedBox(height: 16),
              Expanded(
                child: ListView.builder(
                  itemCount: planList.length,
                  itemBuilder: (ctx, index) {
                    final item = planList[index];
                    return GestureDetector(
                      onLongPress: () {
                        item.isDone = !item.isDone;
                        item.save();
                        setState(() {});
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Row(children: [
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                  border: Border.all(color: Colors.black87),
                                  borderRadius: BorderRadius.circular(12)),
                              child: TextField(
                                controller:
                                    TextEditingController(text: item.time),
                                style: TextStyle(
                                    decoration: item.isDone
                                        ? TextDecoration.lineThrough
                                        : null,
                                    color: item.isDone ? Colors.grey : null),
                                decoration: const InputDecoration(
                                    border: InputBorder.none, isDense: true),
                                onChanged: (val) {
                                  item.time = val;
                                  item.save();
                                },
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            flex: 2,
                            child: Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                  border: Border.all(color: Colors.black87),
                                  borderRadius: BorderRadius.circular(12)),
                              child: TextField(
                                controller:
                                    TextEditingController(text: item.title),
                                style: TextStyle(
                                    decoration: item.isDone
                                        ? TextDecoration.lineThrough
                                        : null,
                                    color: item.isDone ? Colors.grey : null),
                                decoration: const InputDecoration(
                                    border: InputBorder.none, isDense: true),
                                onChanged: (val) {
                                  item.title = val;
                                  item.save();
                                },
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                              onPressed: () => openNote(index),
                              icon: Icon(Icons.local_florist,
                                  color: Theme.of(context).colorScheme.primary))
                        ]),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                  onPressed: () {
                    if (planList.length >= maxCount) return;
                    planBox.add(ScheduleItem(
                        dateKey: selectedDateStr, time: "", title: "", note: ""));
                    setState(() {});
                  },
                  child: const Text("Add schedule")),
              const SizedBox(height: 12),
              BottomNavigationBar(
                currentIndex: 0,
                type: BottomNavigationBarType.fixed,
                items: const [
                  BottomNavigationBarItem(
                      icon: Icon(Icons.book), label: "My Plan"),
                  BottomNavigationBarItem(
                      icon: Icon(Icons.event), label: "My Schedule"),
                  BottomNavigationBarItem(
                      icon: Icon(Icons.note), label: "Diary"),
                  BottomNavigationBarItem(
                      icon: Icon(Icons.chat), label: "Chat Time"),
                  BottomNavigationBarItem(
                      icon: Icon(Icons.favorite), label: "Health Management"),
                  BottomNavigationBarItem(
                      icon: Icon(Icons.share), label: "Sharing Moment"),
                  BottomNavigationBarItem(
                      icon: Icon(Icons.settings), label: "Setting"),
                ],
                onTap: (idx) {
                  switch (idx) {
                    case 0:
                      Navigator.pushNamed(context, "/myPlan");
                      break;
                    case 1:
                      Navigator.pushNamed(context, "/schedule");
                      break;
                    case 2:
                      Navigator.pushNamed(context, "/diary");
                      break;
                    case 3:
                      Navigator.pushNamed(context, "/chatTime");
                      break;
                    case 4:
                      Navigator.pushNamed(context, "/health");
                      break;
                    case 5:
                      Navigator.pushNamed(context, "/moment");
                      break;
                    case 6:
                      Navigator.pushNamed(context, "/setting");
                      break;
                  }
                },
              )
            ],
          ),
        ),
      ),
    );
  }
}

// ===================== Diary Page（已接入speech_to_text + 权限） =====================
class DiaryPage extends StatefulWidget {
  const DiaryPage({super.key});
  @override
  State<DiaryPage> createState() => _DiaryPageState();
}

class _DiaryPageState extends State<DiaryPage> {
  bool isRecording = false;
  late Box<DiaryRecord> diaryBox;
  String todayKey = "";
  DiaryRecord? todayRecord;
  final SpeechToText _speech = SpeechToText();
  bool _speechReady = false;
  String _tempText = "";

  @override
  void initState() {
    super.initState();
    diaryBox = Hive.box<DiaryRecord>("diaryBox");
    refreshToday();
    initSpeech();
  }

  Future<void> initSpeech() async {
    _speechReady = await _speech.initialize();
    setState(() {});
  }

  Future<bool> requestMicPermission() async {
    final status = await Permission.microphone.request();
    return status.isGranted;
  }

  void refreshToday() {
    final now = DateTime.now();
    todayKey = "${now.year}-${now.month}-${now.day}";
    final find = diaryBox.values.where((e) => e.dateStr == todayKey);
    if (find.isNotEmpty) {
      todayRecord = find.first;
    } else {
      todayRecord = DiaryRecord(dateStr: todayKey);
      diaryBox.add(todayRecord!);
    }
    setState(() {});
  }

  Future<void> toggleRecord() async {
    if (!_speechReady) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("语音识别初始化失败，此设备不支持")),
      );
      return;
    }
    final hasMic = await requestMicPermission();
    if (!hasMic) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("麦克风权限被拒绝，请在设置开启")),
      );
      return;
    }

    if (!isRecording) {
      setState(() {
        isRecording = true;
        _tempText = "";
      });
      await _speech.listen(
        onResult: (result) {
          setState(() {
            _tempText = result.recognizedWords;
          });
        },
      );
    } else {
      await _speech.stop();
      setState(() {
        isRecording = false;
        todayRecord!.hasRecord = true;
        todayRecord!.diaryText = _tempText;
        todayRecord!.aiSummary = "AI总结：" + _tempText;
        todayRecord!.save();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
          title: const Text("Diary"),
          leading: IconButton(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.arrow_back))),
      body: GestureDetector(
        onHorizontalDragEnd: (details) {
          if (details.primaryVelocity! > 250) {
            Navigator.pushNamed(context, "/chatTime");
          } else if (details.primaryVelocity! < -250) {
            Navigator.pushNamed(context, "/schedule");
          }
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(padding: const EdgeInsets.all(16)),
                  onPressed: toggleRecord,
                  child: Text(isRecording ? "录音中...点击结束" : "点击开始录音"),
                ),
              ),
              const SizedBox(height: 12),
              if (isRecording)
                Text("正在识别：$_tempText"),
              const SizedBox(height: 20),
              Expanded(
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                      border: Border.all(),
                      borderRadius: BorderRadius.circular(12)),
                  child: SingleChildScrollView(
                    child: Text(todayRecord!.aiSummary.isEmpty
                        ? "录音完成后AI总结会显示在这里"
                        : todayRecord!.aiSummary),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              BottomNavigationBar(
                currentIndex: 2,
                type: BottomNavigationBarType.fixed,
                items: const [
                  BottomNavigationBarItem(
                      icon: Icon(Icons.book), label: "My Plan"),
                  BottomNavigationBarItem(
                      icon: Icon(Icons.event), label: "My Schedule"),
                  BottomNavigationBarItem(
                      icon: Icon(Icons.note), label: "Diary"),
                  BottomNavigationBarItem(
                      icon: Icon(Icons.chat), label: "Chat Time"),
                  BottomNavigationBarItem(
                      icon: Icon(Icons.favorite), label: "Health Management"),
                  BottomNavigationBarItem(
                      icon: Icon(Icons.share), label: "Sharing Moment"),
                  BottomNavigationBarItem(
                      icon: Icon(Icons.settings), label: "Setting"),
                ],
                onTap: (idx) {
                  switch (idx) {
                    case 0:
                      Navigator.pushNamed(context, "/myPlan");
                      break;
                    case 1:
                      Navigator.pushNamed(context, "/schedule");
                      break;
                    case 2:
                      Navigator.pushNamed(context, "/diary");
                      break;
                    case 3:
                      Navigator.pushNamed(context, "/chatTime");
                      break;
                    case 4:
                      Navigator.pushNamed(context, "/health");
                      break;
                    case 5:
                      Navigator.pushNamed(context, "/moment");
                      break;
                    case 6:
                      Navigator.pushNamed(context, "/setting");
                      break;
                  }
                },
              )
            ],
          ),
        ),
      ),
    );
  }
}

// ===================== Chat Time Page（接入speech_to_text + 权限） =====================
class ChatTimePage extends StatefulWidget {
  const ChatTimePage({super.key});
  @override
  State<ChatTimePage> createState() => _ChatTimePageState();
}

class _ChatTimePageState extends State<ChatTimePage> {
  bool aiSpeaking = false;
  bool userRecording = false;
  final SpeechToText _speech = SpeechToText();
  bool _speechReady = false;
  String _userInput = "";

  @override
  void initState() {
    super.initState();
    initSpeech();
  }

  Future<void> initSpeech() async {
    _speechReady = await _speech.initialize();
    setState(() {});
  }

  Future<bool> requestMicPermission() async {
    final status = await Permission.microphone.request();
    return status.isGranted;
  }

  Future<void> toggleRecord() async {
    if (!_speechReady) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("语音识别初始化失败，设备不支持")),
      );
      return;
    }
    final hasMic = await requestMicPermission();
    if (!hasMic) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("麦克风权限被拒绝，请在设置开启")),
      );
      return;
    }

    if (!userRecording) {
      setState(() {
        userRecording = true;
        _userInput = "";
      });
      await _speech.listen(
        onResult: (result) {
          setState(() {
            _userInput = result.recognizedWords;
          });
        },
      );
    } else {
      await _speech.stop();
      setState(() {
        userRecording = false;
        aiSpeaking = true;
      });
      // 模拟AI回复
      Future.delayed(const Duration(seconds: 3), () {
        setState(() {
          aiSpeaking = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("AI收到你的话：$_userInput")),
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
          title: const Text("Hi Mean / Hi Bro～"),
          leading: IconButton(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.arrow_back))),
      body: GestureDetector(
        onHorizontalDragEnd: (details) {
          if (details.primaryVelocity! > 250) {
            Navigator.pushNamed(context, "/health");
          } else if (details.primaryVelocity! < -250) {
            Navigator.pushNamed(context, "/diary");
          }
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                    border: Border.all(),
                    borderRadius: BorderRadius.circular(12)),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text("AI朋友语音条 "),
                    if (aiSpeaking)
                      Row(children: const [
                        SizedBox(width: 4, height: 10, child: ColoredBox(color: Colors.blueAccent)),
                        SizedBox(width: 4, height: 16, child: ColoredBox(color: Colors.blueAccent)),
                        SizedBox(width: 4, height: 6, child: ColoredBox(color: Colors.blueAccent)),
                        SizedBox(width: 4, height: 14, child: ColoredBox(color: Colors.blueAccent)),
                        SizedBox(width: 4, height: 8, child: ColoredBox(color: Colors.blueAccent)),
                        SizedBox(width: 4, height: 12, child: ColoredBox(color: Colors.blueAccent)),
                      ]),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              if (userRecording) Text("识别到你的话：$_userInput"),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: toggleRecord,
                  child: Text(userRecording ? "正在录音，结束对话" : "点击录音，开始聊天"),
                ),
              ),
              const Spacer(),
              BottomNavigationBar(
                currentIndex: 3,
                type: BottomNavigationBarType.fixed,
                items: const [
                  BottomNavigationBarItem(
                      icon: Icon(Icons.book), label: "My Plan"),
                  BottomNavigationBarItem(
                      icon: Icon(Icons.event), label: "My Schedule"),
                  BottomNavigationBarItem(
                      icon: Icon(Icons.note), label: "Diary"),
                  BottomNavigationBarItem(
                      icon: Icon(Icons.chat), label: "Chat Time"),
                  BottomNavigationBarItem(
                      icon: Icon(Icons.favorite), label: "Health Management"),
                  BottomNavigationBarItem(
                      icon: Icon(Icons.share), label: "Sharing Moment"),
                  BottomNavigationBarItem(
                      icon: Icon(Icons.settings), label: "Setting"),
                ],
                onTap: (idx) {
                  switch (idx) {
                    case 0:
                      Navigator.pushNamed(context, "/myPlan");
                      break;
                    case 1:
                      Navigator.pushNamed(context, "/schedule");
                      break;
                    case 2:
                      Navigator.pushNamed(context, "/diary");
                      break;
                    case 3:
                      Navigator.pushNamed(context, "/chatTime");
                      break;
                    case 4:
                      Navigator.pushNamed(context, "/health");
                      break;
                    case 5:
                      Navigator.pushNamed(context, "/moment");
                      break;
                    case 6:
                      Navigator.pushNamed(context, "/setting");
                      break;
                  }
                },
              )
            ],
          ),
        ),
      ),
    );
  }
}

// ===================== Health Page =====================
class HealthManagementPage extends StatelessWidget {
  const HealthManagementPage({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
          title: const Text("Health Management"),
          leading: IconButton(
              onPressed: () => Navigator.pushNamed(context, "/schedule"),
              icon: const Icon(Icons.arrow_back))),
      body: GestureDetector(
        onHorizontalDragEnd: (details) {
          if (details.primaryVelocity! > 250) {
            Navigator.pushNamed(context, "/moment");
          } else if (details.primaryVelocity! < -250) {
            Navigator.pushNamed(context, "/chatTime");
          }
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Expanded(
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                      border: Border.all(),
                      borderRadius: BorderRadius.circular(12)),
                  child: const SingleChildScrollView(
                    child: Text(
                        "**AI健康分析：**结合你的日程和日记，今天23点还在写代码属于熬夜，长期伤肝；今天有运动，这点很好，建议尽量23点前入睡，规律作息。"),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                      border: Border.all(),
                      borderRadius: BorderRadius.circular(12)),
                  child: const SingleChildScrollView(
                    child: Text(
                        "**健康监督建议：**养成早睡早起习惯，每天保证7小时睡眠；连续久坐1小时起身拉伸；每天固定运动时间。"),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              BottomNavigationBar(
                currentIndex: 4,
                type: BottomNavigationBarType.fixed,
                items: const [
                  BottomNavigationBarItem(
                      icon: Icon(Icons.book), label: "My Plan"),
                  BottomNavigationBarItem(
                      icon: Icon(Icons.event), label: "My Schedule"),
                  BottomNavigationBarItem(
                      icon: Icon(Icons.note), label: "Diary"),
                  BottomNavigationBarItem(
                      icon: Icon(Icons.chat), label: "Chat Time"),
                  BottomNavigationBarItem(
                      icon: Icon(Icons.favorite), label: "Health Management"),
                  BottomNavigationBarItem(
                      icon: Icon(Icons.share), label: "Sharing Moment"),
                  BottomNavigationBarItem(
                      icon: Icon(Icons.settings), label: "Setting"),
                ],
                onTap: (idx) {
                  switch (idx) {
                    case 0:
                      Navigator.pushNamed(context, "/myPlan");
                      break;
                    case 1:
                      Navigator.pushNamed(context, "/schedule");
                      break;
                    case 2:
                      Navigator.pushNamed(context, "/diary");
                      break;
                    case 3:
                      Navigator.pushNamed(context, "/chatTime");
                      break;
                    case 4:
                      Navigator.pushNamed(context, "/health");
                      break;
                    case 5:
                      Navigator.pushNamed(context, "/moment");
                      break;
                    case 6:
                      Navigator.pushNamed(context, "/setting");
                      break;
                  }
                },
              )
            ],
          ),
        ),
      ),
    );
  }
}

// ===================== Sharing Moment =====================
class SharingMomentPage extends StatefulWidget {
  const SharingMomentPage({super.key});
  @override
  State<SharingMomentPage> createState() => _SharingMomentPageState();
}

class _SharingMomentPageState extends State<SharingMomentPage> {
  late Box<GardenData> gardenBox;
  GardenData? garden;
  bool canPick = false;
  bool canSend = false;
  List<String> imageList = [];
  String shareText = "";
  String selectFriend = "全选";
  final List<String> friendList = ["好友A", "好友B", "好友C"];
  final List<Map<String, dynamic>> friendShares = [
    {"name": "好友A", "imgs": ["img1"], "text": "今天很开心！"}
  ];
  String friendGiftFlower = "向日葵";

  String flowerStatus = "种子";
  void updateFlower() {
    if (garden == null) return;
    if (garden!.growthDay == 1) {
      flowerStatus = "发芽";
      canPick = false;
    } else if (garden!.growthDay >= 2) {
      flowerStatus = "开花，可以采摘送给好友";
      canPick = true;
    } else {
      flowerStatus = "种子";
      canPick = false;
    }
  }

  @override
  void initState() {
    super.initState();
    gardenBox = Hive.box<GardenData>("gardenBox");
    if (gardenBox.isEmpty) {
      garden = GardenData();
      gardenBox.add(garden!);
    } else {
      garden = gardenBox.values.first;
    }
    updateFlower();
  }

  @override
  Widget build(BuildContext context) {
    updateFlower();
    return Scaffold(
      appBar: AppBar(
        title: const Text("Sharing Moment"),
        leading: IconButton(
            onPressed: () => Navigator.pushNamed(context, "/schedule"),
            icon: const Icon(Icons.arrow_back)),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Row(
              children: [
                const Text("好友送我的花："),
                Text(friendGiftFlower),
              ],
            ),
          )
        ],
      ),
      body: GestureDetector(
        onHorizontalDragEnd: (details) {
          if (details.primaryVelocity! > 250) {
            Navigator.pushNamed(context, "/setting");
          } else if (details.primaryVelocity! < -250) {
            Navigator.pushNamed(context, "/health");
          }
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: selectFriend,
                    items: [
                      const DropdownMenuItem(value: "全选", child: Text("全选")),
                      ...friendList
                          .map((f) => DropdownMenuItem(value: f, child: Text(f)))
                          .toList()
                    ],
                    onChanged: (v) => setState(() => selectFriend = v!),
                    decoration: const InputDecoration(
                        labelText: "分享给", border: OutlineInputBorder()),
                  ),
                ),
                const SizedBox(width: 10),
                ElevatedButton(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text("分享发送成功（模拟）")));
                    },
                    child: const Text("发送"))
              ]),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                height: 120,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                    border: Border.all(),
                    borderRadius: BorderRadius.circular(12)),
                child: Wrap(
                  spacing: 6,
                  children: [
                    ...imageList
                        .map((e) => Container(
                            width: 80,
                            height: 80,
                            color: Colors.grey[300]))
                        .toList(),
                    if (imageList.length < 9)
                      InkWell(
                        onTap: () => setState(() {
                          if (imageList.length < 9) imageList.add("img");
                        }),
                        child: const SizedBox(
                            width: 80, height: 80, child: Icon(Icons.add)),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                decoration: const InputDecoration(
                    border: OutlineInputBorder(), labelText: "想对朋友说的话"),
                onChanged: (v) => shareText = v,
              ),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                height: 140,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                    border: Border.all(),
                    borderRadius: BorderRadius.circular(12)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "浏览好友分享内容",
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    Expanded(
                      child: ListView.builder(
                        itemCount: friendShares.length,
                        itemBuilder: (ctx, idx) {
                          final fs = friendShares[idx];
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Text("${fs['name']}：${fs['text']}"),
                          );
                        },
                      ),
                    )
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                    border: Border.all(),
                    borderRadius: BorderRadius.circular(12)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("Garden",
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Text("种子：${garden!.seedName}"),
                    Text("成长状态：$flowerStatus"),
                    Row(children: [
                      ElevatedButton(
                        onPressed: garden!.hasPlanted
                            ? null
                            : () {
                                showDialog(
                                  context: context,
                                  builder: (ctx) => AlertDialog(
                                    title: const Text("选择种子"),
                                    content: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        TextButton(
                                          onPressed: () {
                                            garden!.seedName = "向日葵";
                                            garden!.growthDay = 0;
                                            garden!.hasPlanted = true;
                                            garden!.save();
                                            setState(() {});
                                            Navigator.pop(ctx);
                                          },
                                          child: const Text("向日葵"),
                                        ),
                                        TextButton(
                                          onPressed: () {
                                            garden!.seedName = "玫瑰";
                                            garden!.growthDay = 0;
                                            garden!.hasPlanted = true;
                                            garden!.save();
                                            setState(() {});
                                            Navigator.pop(ctx);
                                          },
                                          child: const Text("玫瑰"),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                        child: const Text("选择种子"),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: () {
                          garden!.growthDay += 1;
                          garden!.save();
                          setState(() {});
                        },
                        child: const Text("每日打卡，植物成长"),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: canPick
                            ? () => setState(() {
                                  canSend = true;
                                })
                            : null,
                        child: const Text("采摘花朵"),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: canSend
                            ? () {
                                garden!.hasPlanted = false;
                                garden!.growthDay = 0;
                                garden!.save();
                                setState(() {
                                  canSend = false;
                                });
                                ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text("送给好友成功！")));
                              }
                            : null,
                        child: const Text("送给好友"),
                      )
                    ])
                  ],
                ),
              ),
              const Spacer(),
              BottomNavigationBar(
                currentIndex: 5,
                type: BottomNavigationBarType.fixed,
                items: const [
                  BottomNavigationBarItem(
                      icon: Icon(Icons.book), label: "My Plan"),
                  BottomNavigationBarItem(
                      icon: Icon(Icons.event), label: "My Schedule"),
                  BottomNavigationBarItem(
                      icon: Icon(Icons.note), label: "Diary"),
                  BottomNavigationBarItem(
                      icon: Icon(Icons.chat), label: "Chat Time"),
                  BottomNavigationBarItem(
                      icon: Icon(Icons.favorite), label: "Health Management"),
                  BottomNavigationBarItem(
                      icon: Icon(Icons.share), label: "Sharing Moment"),
                  BottomNavigationBarItem(
                      icon: Icon(Icons.settings), label: "Setting"),
                ],
                onTap: (idx) {
                  switch (idx) {
                    case 0:
                      Navigator.pushNamed(context, "/myPlan");
                      break;
                    case 1:
                      Navigator.pushNamed(context, "/schedule");
                      break;
                    case 2:
                      Navigator.pushNamed(context, "/diary");
                      break;
                    case 3:
                      Navigator.pushNamed(context, "/chatTime");
                      break;
                    case 4:
                      Navigator.pushNamed(context, "/health");
                      break;
                    case 5:
                      Navigator.pushNamed(context, "/moment");
                      break;
                    case 6:
                      Navigator.pushNamed(context, "/setting");
                      break;
                  }
                },
              )
            ],
          ),
        ),
      ),
    );
  }
}

// ===================== Setting页面 =====================
class SettingPage extends StatefulWidget {
  final Function(int) selectTheme;
  const SettingPage({super.key, required this.selectTheme});

  @override
  State<SettingPage> createState() => _SettingPageState();
}

class _SettingPageState extends State<SettingPage> {
  final String uid = "USER887766";

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Setting"),
        leading: IconButton(
          onPressed: () => Navigator.pushNamed(context, "/schedule"),
          icon: const Icon(Icons.arrow_back),
        ),
      ),
      body: GestureDetector(
        onHorizontalDragEnd: (details) {
          if (details.primaryVelocity! < -250) {
            Navigator.pushNamed(context, "/moment");
          }
        },
        child: ListView(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: Row(
                children: [
                  const CircleAvatar(
                    child: Icon(Icons.person),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "用户名称：Sister",
                          style: TextStyle(fontSize: 16),
                        ),
                        SizedBox(height: 4),
                        Row(
                          children: [
                            Text("ID：$uid"),
                            const SizedBox(width: 12),
                            TextButton(
                              onPressed: () {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text("已复制ID")),
                                );
                              },
                              child: const Text("复制"),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Divider(),
            ListTile(
              title: const Text("添加好友"),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () => Navigator.pushNamed(context, "/searchFriend"),
            ),
            ListTile(
              title: const Text("已添加好友 & 好友申请"),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () => Navigator.pushNamed(context, "/friendList"),
            ),
            ListTile(
              title: const Text("主题"),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () {
                showDialog(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text("选择主题"),
                    content: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ListTile(
                          title: const Text("粉色女生主题"),
                          onTap: () {
                            widget.selectTheme(0);
                            Navigator.pop(ctx);
                          },
                        ),
                        ListTile(
                          title: const Text("加深薄荷绿主题"),
                          onTap: () {
                            widget.selectTheme(1);
                            Navigator.pop(ctx);
                          },
                        ),
                        ListTile(
                          title: const Text("深蓝男生主题"),
                          onTap: () {
                            widget.selectTheme(2);
                            Navigator.pop(ctx);
                          },
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
            ListTile(
              title: const Text("隐私权限"),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () {},
            ),
            ListTile(
              title: const Text("存储"),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () {
                showDialog(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text("存储管理"),
                    content: const Text("数据60天自动删除；可手动清空日程、日记记录"),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text("取消"),
                      ),
                      TextButton(
                        onPressed: () async {
                          await Hive.box<ScheduleItem>("scheduleBox").clear();
                          await Hive.box<ScheduleItem>("planBox").clear();
                          await Hive.box<DiaryRecord>("diaryBox").clear();
                          await Hive.box<GardenData>("gardenBox").clear();
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text("已清空全部本地记录")),
                            );
                          }
                          Navigator.pop(ctx);
                        },
                        child: const Text("手动删除全部记录"),
                      ),
                    ],
                  ),
                );
              },
            ),
            ListTile(
              title: const Text("其它"),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () {},
            ),
          ],
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: 6,
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.book), label: "My Plan"),
          BottomNavigationBarItem(icon: Icon(Icons.event), label: "My Schedule"),
          BottomNavigationBarItem(icon: Icon(Icons.note), label: "Diary"),
          BottomNavigationBarItem(icon: Icon(Icons.chat), label: "Chat Time"),
          BottomNavigationBarItem(icon: Icon(Icons.favorite), label: "Health Management"),
          BottomNavigationBarItem(icon: Icon(Icons.share), label: "Sharing Moment"),
          BottomNavigationBarItem(icon: Icon(Icons.settings), label: "Setting"),
        ],
        onTap: (idx) {
          switch (idx) {
            case 0:
              Navigator.pushNamed(context, "/myPlan");
              break;
            case 1:
              Navigator.pushNamed(context, "/schedule");
              break;
            case 2:
              Navigator.pushNamed(context, "/diary");
              break;
            case 3:
              Navigator.pushNamed(context, "/chatTime");
              break;
            case 4:
              Navigator.pushNamed(context, "/health");
              break;
            case 5:
              Navigator.pushNamed(context, "/moment");
              break;
            case 6:
              Navigator.pushNamed(context, "/setting");
              break;
          }
        },
      ),
    );
  }
}

// 搜索好友页面
class SearchFriendPage extends StatelessWidget {
  const SearchFriendPage({super.key});
  @override
  Widget build(BuildContext context) {
    final ctrl = TextEditingController