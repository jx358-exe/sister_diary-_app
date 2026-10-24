import 'package:flutter/material.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: "Sister Diary",
      theme: ThemeData(
        primarySwatch: Colors.pink,
        scaffoldBackgroundColor: const Color(0xFFFFF0F6),
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => const MySchedulePage(),
        '/voiceNote': (context) => const VoiceSummaryPage(),
        '/myPlan': (context) => const MyPlanPage(),
        '/diary': (context) => const DiaryPage(),
        '/chatTime': (context) => const ChatTimePage(),
        '/health': (context) => const HealthManagementPage(),
        '/sharing': (context) => const SharingMomentPage(),
      },
    );
  }
}

class ScheduleItem {
  String time;
  String task;
  bool isDone;
  ScheduleItem({required this.time, required this.task, this.isDone = false});
}

class MySchedulePage extends StatefulWidget {
  const MySchedulePage({super.key});

  @override
  State<MySchedulePage> createState() => _MySchedulePageState();
}

class _MySchedulePageState extends State<MySchedulePage> {
  final TextEditingController _dateCtrl = TextEditingController(text: "2026-10-24");
  final List<ScheduleItem> scheduleList = [
    ScheduleItem(time: "18:00~20:00", task: "Open Project"),
    ScheduleItem(time: "09:00~10:30", task: "Study"),
    ScheduleItem(time: "14:00~15:00", task: "Meeting"),
    ScheduleItem(time: "16:00~17:00", task: "Reading"),
    ScheduleItem(time: "20:30~21:30", task: "Exercise"),
  ];
  final int maxCount = 30;

  void addNewSchedule() {
    setState(() {
      if (scheduleList.length < maxCount) {
        scheduleList.add(ScheduleItem(time: "", task: ""));
      }
    });
  }

  void toggleDone(int index) {
    setState(() {
      scheduleList[index].isDone = !scheduleList[index].isDone;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF0F6),
      appBar: AppBar(
        title: const Text("My Schedule"),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Column(
        children: [
          // 顶部日期输入框（你之前漏掉的）
          Padding(
            padding: const EdgeInsets.symmetric(horizontal:16, vertical:8),
            child: TextField(
              controller: _dateCtrl,
              decoration: const InputDecoration(
                labelText: "选择日期 (yyyy-MM-dd)",
                border: OutlineInputBorder(),
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: scheduleList.length,
              itemBuilder: (ctx, idx) {
                return ScheduleRow(
                  item: scheduleList[idx],
                  onTimeChanged: (val) => setState(() {
                    final text = val.length > 25 ? val.substring(0, 25) : val;
                    scheduleList[idx].time = text;
                  }),
                  onTaskChanged: (val) => setState(() {
                    final text = val.length > 50 ? val.substring(0, 50) : val;
                    scheduleList[idx].task = text;
                  }),
                  onLongPress: () => toggleDone(idx),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: ElevatedButton(
              onPressed: scheduleList.length >= maxCount ? null : addNewSchedule,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFF28FB0),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
              ),
              child: Text(
                scheduleList.length >= maxCount ? "最多30条" : "+ 添加日程",
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: Color(0xFFF2B8D0))),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: const [
                NavIcon(Icons.list_alt, "My Plan", "/myPlan"),
                NavIcon(Icons.bookmark, "Diary", "/diary"),
                NavIcon(Icons.cloud_rounded, "Chat Time", "/chatTime"),
                NavIcon(Icons.favorite_rounded, "Health Management", "/health"),
                NavIcon(Icons.share_rounded, "Sharing Moment", "/sharing"),
              ],
            ),
          )
        ],
      ),
    );
  }
}

class MyPlanPage extends StatefulWidget {
  const MyPlanPage({super.key});

  @override
  State<MyPlanPage> createState() => _MyPlanPageState();
}

class _MyPlanPageState extends State<MyPlanPage> {
  final List<ScheduleItem> planList = [
    ScheduleItem(time: "18:00~20:00", task: "Open Project"),
    ScheduleItem(time: "09:00~10:30", task: "Study"),
  ];
  final int maxCount = 30;

  void addNewPlan() {
    setState(() {
      if (planList.length < maxCount) {
        planList.add(ScheduleItem(time: "", task: ""));
      }
    });
  }

  void toggleDone(int index) {
    setState(() {
      planList[index].isDone = !planList[index].isDone;
    });
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onHorizontalDragUpdate: (details) {
        if (details.delta.dx > 15) {
          Navigator.pop(context);
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFFFF0F6),
        appBar: AppBar(
          title: const Text("My Plan"),
          centerTitle: true,
          backgroundColor: Colors.transparent,
          elevation: 0,
          automaticallyImplyLeading: true,
        ),
        body: Column(
          children: [
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: planList.length,
                itemBuilder: (ctx, idx) {
                  return ScheduleRow(
                    item: planList[idx],
                    onTimeChanged: (val) => setState(() {
                      final text = val.length > 25 ? val.substring(0, 25) : val;
                      planList[idx].time = text;
                    }),
                    onTaskChanged: (val) => setState(() {
                      final text = val.length > 50 ? val.substring(0, 50) : val;
                      planList[idx].task = text;
                    }),
                    onLongPress: () => toggleDone(idx),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: ElevatedButton(
                onPressed: planList.length >= maxCount ? null : addNewPlan,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFF28FB0),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                ),
                child: Text(
                  planList.length >= maxCount ? "最多30条" : "+ 添加计划",
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            ),
            const SizedBox(height: 20)
          ],
        ),
      ),
    );
  }
}

class DiaryPage extends StatefulWidget {
  const DiaryPage({super.key});

  @override
  State<DiaryPage> createState() => _DiaryPageState();
}

class _DiaryPageState extends State<DiaryPage> {
  bool isRecording = false;
  bool hasAudio = false;
  String aiSummary = "";

  void toggleRecord() {
    setState(() {
      if (isRecording) {
        isRecording = false;
        hasAudio = true;
        aiSummary = "AI日记总结：今天认真完成学习任务，状态平稳，继续保持～";
      } else {
        isRecording = true;
      }
    });
  }

  void playAudio() {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("正在播放你的日记录音")));
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onHorizontalDragUpdate: (details) {
        if (details.delta.dx > 15) {
          Navigator.pop(context);
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFFFF0F6),
        appBar: AppBar(
          title: const Text("Diary"),
          centerTitle: true,
          backgroundColor: Colors.transparent,
          elevation: 0,
          automaticallyImplyLeading: true,
        ),
        body: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isRecording ? Colors.pinkAccent : const Color(0xFFF28FB0),
                    padding: const EdgeInsets.symmetric(vertical:14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  onPressed: isRecording ? toggleRecord : (hasAudio ? playAudio : toggleRecord),
                  child: Text(
                    isRecording ? "🛑 停止录音" : (hasAudio ? "▶ 播放日记录音" : "🎤 点击录音，记录日记"),
                    style: const TextStyle(fontSize:16, color: Colors.white),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Expanded(
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFF2B8D0)),
                  ),
                  child: SingleChildScrollView(
                    child: Text(
                      aiSummary.isNotEmpty ? aiSummary : "录音完成后，AI会在这里为你总结日记内容",
                      style: const TextStyle(fontSize:15, color: Colors.black54),
                    ),
                  ),
                ),
              ),
              const SizedBox(height:20)
            ],
          ),
        ),
      ),
    );
  }
}

class ChatTimePage extends StatefulWidget {
  const ChatTimePage({super.key});

  @override
  State<ChatTimePage> createState() => _ChatTimePageState();
}

class _ChatTimePageState extends State<ChatTimePage> {
  bool userRecording = false;
  bool aiThinking = false;

  void toggleUserRecord() {
    if (userRecording) {
      setState(() {
        userRecording = false;
        aiThinking = true;
      });
      Future.delayed(const Duration(seconds: 2), () {
        setState(() {
          aiThinking = false;
        });
      });
    } else {
      setState(() {
        userRecording = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onHorizontalDragUpdate: (details) {
        if (details.delta.dx > 15) {
          Navigator.pop(context);
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFFFF0F6),
        appBar: AppBar(
          title: const Text("Chat Time"),
          centerTitle: true,
          backgroundColor: Colors.transparent,
          elevation: 0,
          automaticallyImplyLeading: true,
        ),
        body: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical:16, horizontal:20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFF2B8D0)),
                ),
                child: aiThinking
                    ? const Text("AI正在思考中...", style: TextStyle(color: Colors.grey, fontSize:15))
                    : const Text("等待你说话～", style: TextStyle(color: Colors.grey, fontSize:15)),
              ),
              const SizedBox(height: 36),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: userRecording ? Colors.pinkAccent : const Color(0xFFF28FB0),
                    padding: const EdgeInsets.symmetric(vertical:16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  onPressed: toggleUserRecord,
                  child: Text(
                    userRecording ? "🛑 结束录音，等待朋友回复" : "🎤 点击开始和朋友聊天",
                    style: const TextStyle(fontSize:16, color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class HealthManagementPage extends StatefulWidget {
  const HealthManagementPage({super.key});

  @override
  State<HealthManagementPage> createState() => _HealthManagementPageState();
}

class _HealthManagementPageState extends State<HealthManagementPage> {
  String aiAnalyseResult = "📊 今日健康分析：\n检测到你今天日程安排比较紧凑，晚间还有学习开发任务，需要留意休息时间。";
  String aiAdvice = "💡 健康监督&养生建议：\n尽量不要超过23:00睡觉，连续写代码1小时起身活动5分钟，记得多喝水。";

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onHorizontalDragUpdate: (details) {
        if (details.delta.dx > 15) {
          Navigator.pop(context);
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFFFF0F6),
        appBar: AppBar(
          title: const Text("Health Management"),
          centerTitle: true,
          backgroundColor: Colors.transparent,
          elevation: 0,
          automaticallyImplyLeading: true,
        ),
        body: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Expanded(
                flex: 1,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFF2B8D0)),
                  ),
                  child: SingleChildScrollView(
                    child: Text(
                      aiAnalyseResult,
                      style: const TextStyle(fontSize: 15, height: 1.6),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Expanded(
                flex: 2,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFF2B8D0)),
                  ),
                  child: SingleChildScrollView(
                    child: Text(
                      aiAdvice,
                      style: const TextStyle(fontSize: 15, height: 1.6),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }
}

// ========== Sharing Moment 分享页面 + 花园养成 ==========
class SharingMomentPage extends StatefulWidget {
  const SharingMomentPage({super.key});
  @override
  State<SharingMomentPage> createState() => _SharingMomentPageState();
}

class _SharingMomentPageState extends State<SharingMomentPage> {
  final List<String> previewImages = [];
  final TextEditingController shareTextCtrl = TextEditingController();
  int growDay = 0; // 成长天数：0种子，1发芽，2长大，3花苞，4开花，5可采摘
  String selectedSeed = "向日葵";
  final List<String> seedList = ["向日葵", "小雏菊", "玫瑰", "郁金香"];
  bool hasFriendSunflower = true; // 好友赠送向日葵

  String getPlantStageText() {
    if(growDay == 0) return "🌱 种子";
    if(growDay == 1) return "🌿 发芽";
    if(growDay == 2) return "🌱 长大";
    if(growDay == 3) return "🌷 花苞";
    if(growDay == 4) return "🌻 开花";
    return "💐 可以采摘送给朋友！";
  }

  Widget getPlantIcon() {
    if(growDay == 0) return const Text("🫘", style: TextStyle(fontSize:42));
    if(growDay == 1) return const Text("🌱", style: TextStyle(fontSize:42));
    if(growDay == 2) return const Text("🌿", style: TextStyle(fontSize:42));
    if(growDay == 3) return const Text("🌷", style: TextStyle(fontSize:42));
    if(growDay == 4) return const Text("🌻", style: TextStyle(fontSize:42));
    return const Text("💐", style: TextStyle(fontSize:42));
  }

  void addImage() {
    if(previewImages.length <5) {
      setState(() {
        previewImages.add("demo");
      });
    }
  }

  void removeImage(int idx) {
    setState(() {
      previewImages.removeAt(idx);
    });
  }

  void harvestFlower() {
    if(growDay >=5) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("✅ 采摘成功！送给你的好朋友啦")));
      setState(() {
        growDay = 0;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onHorizontalDragUpdate: (details) {
        if (details.delta.dx > 15) {
          Navigator.pop(context);
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFFFF0F6),
        appBar: AppBar(
          title: const Text("Sharing Moment"),
          centerTitle: true,
          backgroundColor: Colors.transparent,
          elevation: 0,
          automaticallyImplyLeading: true,
          actions: [
            if(hasFriendSunflower)
              const Padding(padding: EdgeInsets.only(right:12), child: Text("🌻", style: TextStyle(fontSize:26))),
          ],
        ),
        body: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            children: [
              // 上方：图片分享框
              Expanded(
                flex:2,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFF2B8D0)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("📷 分享图片（最多5张）", style: TextStyle(fontSize:14)),
                      const SizedBox(height:8),
                      Expanded(
                        child: previewImages.isEmpty
                            ? const Center(child: Text("点击加号添加图片", style: TextStyle(color:Colors.grey)))
                            : GridView.builder(
                                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount:3, crossAxisSpacing:6, mainAxisSpacing:6),
                                itemCount: previewImages.length,
                                itemBuilder: (ctx,idx) {
                                  return Stack(
                                    children: [
                                      Container(color:Color(0xFFFFD6E4), child: const Center(child: Text("图"))),
                                      Positioned(right:0,top:0, child: InkWell(onTap:()=>removeImage(idx), child: const Icon(Icons.close,size:16,color:Colors.red)))
                                    ],
                                  );
                                },
                              ),
                      ),
                      if(previewImages.length <5)
                        Align(alignment: Alignment.centerRight, child: ElevatedButton(onPressed:addImage, style:ElevatedButton.styleFrom(backgroundColor:Color(0xFFF28FB0)), child: const Text("+ 添加图片",style:TextStyle(color:Colors.white))))
                    ],
                  ),
                ),
              ),
              const SizedBox(height:14),
              // 文字输入框
              Expanded(
                flex:1,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFF2B8D0)),
                  ),
                  child: TextField(
                    controller: shareTextCtrl,
                    maxLines: null,
                    expands: true,
                    decoration: const InputDecoration(border:InputBorder.none, hintText:"写下想对朋友说的话..."),
                  ),
                ),
              ),
              const SizedBox(height:14),
              // Garden花园区域
              Expanded(
                flex:2,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFF2B8D0)),
                  ),
                  child: Column(
                    children: [
                      const Text("🌿 Garden", style: TextStyle(fontSize:16,fontWeight: FontWeight.w500)),
                      const SizedBox(height:10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text("选择种子："),
                          DropdownButton<String>(
                            value: selectedSeed,
                            items: seedList.map((s)=>DropdownMenuItem(value:s,child:Text(s))).toList(),
                            onChanged: (val)=>setState(()=>selectedSeed=val!),
                          )
                        ],
                      ),
                      const SizedBox(height:8),
                      getPlantIcon(),
                      const SizedBox(height:6),
                      Text(getPlantStageText(), style: const TextStyle(fontSize:15)),
                      const SizedBox(height:8),
                      Text("今日使用App，成长值+1", style: TextStyle(fontSize:13,color:Colors.grey[600])),
                      const Spacer(),
                      if(growDay >=5)
                        ElevatedButton(onPressed: harvestFlower, style:ElevatedButton.styleFrom(backgroundColor:Color(0xFFF28FB0)), child: const Text("💐采摘送给朋友",style:TextStyle(color:Colors.white)))
                    ],
                  ),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}

class ScheduleRow extends StatefulWidget {
  final ScheduleItem item;
  final Function(String) onTimeChanged;
  final Function(String) onTaskChanged;
  final VoidCallback onLongPress;
  const ScheduleRow({
    super.key,
    required this.item,
    required this.onTimeChanged,
    required this.onTaskChanged,
    required this.onLongPress,
  });

  @override
  State<ScheduleRow> createState() => _ScheduleRowState();
}

class _ScheduleRowState extends State<ScheduleRow> {
  late final TextEditingController _timeCtrl;
  late final TextEditingController _taskCtrl;

  @override
  void initState() {
    super.initState();
    _timeCtrl = TextEditingController(text: widget.item.time);
    _taskCtrl = TextEditingController(text: widget.item.task);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onLongPress: widget.onLongPress,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Expanded(
              flex: 2,
              child: TextField(
                controller: _timeCtrl,
                maxLength: 25,
                style: TextStyle(
                  color: widget.item.isDone ? Colors.grey : Colors.black,
                  decoration: widget.item.isDone ? TextDecoration.lineThrough : null,
                ),
                decoration: InputDecoration(
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Color(0xFFF2B8D0)),
                  ),
                  filled: true,
                  fillColor: widget.item.isDone ? Colors.grey[200] : Colors.white,
                  counterText: "",
                ),
                onChanged: widget.onTimeChanged,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 5,
              child: TextField(
                controller: _taskCtrl,
                maxLength: 50,
                style: TextStyle(
                  color: widget.item.isDone ? Colors.grey : Colors.black,
                  decoration: widget.item.isDone ? TextDecoration.lineThrough : null,
                ),
                decoration: InputDecoration(
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Color(0xFFF2B8D0)),
                  ),
                  filled: true,
                  fillColor: widget.item.isDone ? Colors.grey[200] : Colors.white,
                  counterText: "",
                ),
                onChanged: widget.onTaskChanged,
              ),
            ),
            IconButton(
              icon: const Icon(Icons.local_florist, size: 24, color: Color(0xFFF28FB0)),
              onPressed: () => Navigator.pushNamed(context, "/voiceNote"),
            )
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _timeCtrl.dispose();
    _taskCtrl.dispose();
    super.dispose();
  }
}

class NavIcon extends StatelessWidget {
  final IconData icon;
  final String label;
  final String route;
  const NavIcon(this.icon, this.label, this.route, {super.key});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => Navigator.pushNamed(context, route),
      child: Column(
        children: [
          Icon(icon, size: 26, color: const Color(0xFFD8789E)),
          Text(label, style: const TextStyle(fontSize: 10, color: Color(0xFFD8789E))),
        ],
      ),
    );
  }
}

class VoiceSummaryPage extends StatelessWidget {
  const VoiceSummaryPage({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF0F6),
      appBar: AppBar(title: const Text("Voice Summary"), backgroundColor: Colors.transparent, elevation: 0),
      body: const Center(child: Text("Your voice recorded summary here")),
    );
  }
}