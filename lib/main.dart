import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:intl/intl.dart';
import 'package:record/record.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:http/http.dart' as http;
import 'package:table_calendar/table_calendar.dart';

import 'event.dart';

Future<String> sendHttpPostRequest(List<int> requestBody) async {
  //   API 엔드포인트 URL
  String apiUrl = '';

  // 클라이언트 ID와 시크릿 키
  String clientID = '';
  String clientSecret = '';

  // 요청 헤더 설정
  Map<String, String> headers = {
    "X-NCP-APIGW-API-KEY-ID": clientID,
    "X-NCP-APIGW-API-KEY": clientSecret,
    "Content-Type": "application/octet-stream",
  };

  // HTTP POST 요청 보내기
  final response = await http.post(
    Uri.parse(apiUrl),
    headers: headers,
    body: Uint8List.fromList(requestBody),
  );

  // 응답 처리
  if (response.statusCode == 200) {
    // 성공적인 응답 처리
    print('성공적으로 요청을 보냈습니다.');
    print('응답 데이터: ${response.body}');
    return response.body;
  } else {
    // 오류 응답 처리
    print('요청을 보내는 중 오류가 발생했습니다.');
    print('오류 코드: ${response.statusCode}');
    print('오류 응답 데이터: ${response.body}');
    return '';
  }
}

Future<void> sendChatCompletionRequest(String ReadCsrResult) async {
  final url = Uri.parse("https://api.openai.com/v1/chat/completions");
  DateTime now = DateTime.now();
  final DateFormat formatter = DateFormat('yyyy-MM-ddTHH:mm:ss');
  final String formattedDateTime = formatter.format(now);
  print(formattedDateTime);
  final data = {
    "model": "gpt-3.5-turbo",
    "temperature": 0.8,
    "max_tokens": 2048,
    "messages": [
      {"role": "system", "content": "너는 문장을 아래 json 형태로 요약해야한다. 또한 필요한 정보가 없는 경우 -으로 채운다."},
      {"role": "system", "content": "summary, location, description, start, end에 대한 정보를 입력해야한다.\n start와 end는 dateTime과 timeZone으로 구성되어있다.\n timeZone은 Asia/Seoul로 고정한다.\n dateTime은 YYYY-MM-DDTHH:MM:SS+09:00 형태로 입력한다.\n - 요약한 json 형태만 반환한다."},
      {"role": "system", "content": "오늘 날짜는 $formattedDateTime+09:00 라고 한다."},
      {"role": "user", "content": ReadCsrResult},
    ],
  };

  final headers = {
    "Authorization": "Bearer ",
    "Content-Type": 'application/json; charset=UTF-8',
  };

  final response = await http.post(url, body: jsonEncode(data), headers: headers);

  if (response.statusCode == 200) {
    final decodeData = utf8.decode(response.bodyBytes);
    final data = jsonDecode(decodeData);
    print(data);
  } else {
    print("Error: ${response.body}");
  }
}

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TableCalendar',
      theme: ThemeData(
        primarySwatch: Colors.pink,
      ),
      home: TableEventsExample(),
    );
  }
}

class TableEventsExample extends StatefulWidget {
  @override
  _TableEventsExampleState createState() => _TableEventsExampleState();
}

class _TableEventsExampleState extends State<TableEventsExample> {
  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  late Record audioRecord;
  late AudioPlayer audioPlayer;
  bool isRecording = false;
  String audioPath='';

  //이벤트 만든거 저장
  Map<DateTime, List<Event>> events ={};
  TextEditingController _eventController = TextEditingController();
  late final ValueNotifier<List<Event>> _selectedEvents;

  @override
  void initState() {
    audioPlayer=AudioPlayer();
    audioRecord=Record();
    super.initState();
    _selectedDay = _focusedDay;
    _selectedEvents = ValueNotifier(_getEventsForDay(_selectedDay!));
  }

  @override
  void dispose() {
    audioRecord.dispose();
    audioPlayer.dispose();
    super.dispose();
  }

  Future<void> startRecording() async {
    try {
      if(await audioRecord.hasPermission()){
        await audioRecord.start();
        setState((){
          isRecording=true;
        });
      }
    }
    catch (e) {
      print('Error Start Recording: $e');
    }
  }

  Future<void> stopRecording() async{
    try{
      String? path = await audioRecord.stop();
      setState(() {
        isRecording=false;
        audioPath=path!;
      });
    }
    catch(e){
      print('Error Stopping record : $e');
    }
  }

  Future<void> playRecording() async{
    //if (audioPath.isNotEmpty) {
    try {
      List<int> audioData = File(audioPath).readAsBytesSync();
      String csr = await sendHttpPostRequest(audioData);
      sendChatCompletionRequest(csr);
      /*createGoogleCalendarEvent({
            'summary': 'AI 설계 및 실습',  // 이벤트 제목
            'location': '동아대학교',  // 장소
            'description': 'AI 설계 및 실습 발표 준비',  // 설명
            'start': {
              'dateTime': '2023-10-24T15:00:00+09:00',  // 시작 일시
              'timeZone': 'Asia/Seoul',
            },
            'end': {
              'dateTime': '2023-10-24T18:00:00+09:00',  // 종료 일시
              'timeZone': 'Asia/Seoul',
            },
          });*/
      await audioPlayer.play(audioPath as Source, mode: PlayerMode.mediaPlayer,);
      //Source urlSource = UrlSource(audioPath);
      //await audioPlayer.play(urlSource);
    }
    catch (e) {
      print('Error Playing Recording : $e');
    }
    //}
  }

  void _onDaySelected(DateTime selectedDay, DateTime focusedDay) {
    if (!isSameDay(_selectedDay, selectedDay)) {
      setState(() {
        _selectedDay = selectedDay;
        _focusedDay = focusedDay;
      });
      _selectedEvents.value = _getEventsForDay(selectedDay);
    }
  }

  List<Event> _getEventsForDay(DateTime day) {
    return events[day] ?? [];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Smart Kalendar'),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          showDialog(
              context: context,
              builder: (context) {
                return AlertDialog(
                  scrollable: true,
                  title: Text("event name"),
                  content: Padding(
                    padding: EdgeInsets.all(8),
                    child: TextField(
                      controller: _eventController,
                    ),
                  ),
                  actions: [
                    ElevatedButton(
                        onPressed: () {
                          //map에 이벤트 네임 저장
                          events.addAll({
                            _selectedDay!: [Event(_eventController.text)]
                          });
                          Navigator.of(context).pop();
                          _selectedEvents.value=_getEventsForDay(_selectedDay!);
                        },
                        child: Text("submit"))
                  ],
                );
              });
        },
        child: Icon(Icons.add),
      ),
      body: Column(
        children: [
          // 첫 번째 Column: 테이블 캘린더
          TableCalendar<Event>(
            firstDay: DateTime.utc(2010, 3, 14),
            lastDay: DateTime.utc(2030, 3, 14),
            focusedDay: _focusedDay,
            selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
            calendarFormat: _calendarFormat,
            startingDayOfWeek: StartingDayOfWeek.sunday,
            onDaySelected: _onDaySelected,
            eventLoader: _getEventsForDay,
            calendarStyle: CalendarStyle(
              outsideDaysVisible: false,
            ),
            onFormatChanged: (format) {
              if (_calendarFormat != format) {
                setState(() {
                  _calendarFormat = format;
                });
              }
            },
            onPageChanged: (focusedDay) {
              _focusedDay = focusedDay;
            },
          ),
          SizedBox(height: 8.0,),
          Expanded(
            child: ValueListenableBuilder<List<Event>>(
              valueListenable: _selectedEvents,
              builder: (context, value, _) {
                return ListView.builder(
                  itemCount: value.length,
                  itemBuilder: (context, index) {
                    return Container(
                      margin: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 4
                      ),
                      decoration: BoxDecoration(
                        border: Border.all(),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: ListTile(
                        onTap: () => print('${value[index]}'),
                        title: Text('${value[index]}'),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          // 두 번째 Column: 녹음 버튼
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                if (isRecording)
                  const Text(
                    'Recording in Progress',
                    style: TextStyle(
                      fontSize: 20,
                    ),
                  ),
                ElevatedButton(
                  onPressed: isRecording ? stopRecording : startRecording,
                  child: isRecording ? const Text('Stop Recording') : const Text('Start Recording'),
                ),
                const SizedBox(
                  height: 25,
                ),
                if (!isRecording && audioPath != null)
                  ElevatedButton(
                    onPressed: playRecording,
                    child: const Text('Play Recording'),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
