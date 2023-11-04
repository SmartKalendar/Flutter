import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:intl/intl.dart';

import 'package:flutter/material.dart';
import 'package:record/record.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:http/http.dart' as http;

  Future<String> sendHttpPostRequest(List<int> requestBody) async {
    //   API 엔드포인트 URL
  String apiUrl = 'https://naveropenapi.apigw.ntruss.com/recog/v1/stt?lang=Kor';

  // 클라이언트 ID와 시크릿 키
  String clientID = 'p9dbk5ndln';
  String clientSecret = 'cwjf4QHMSSqixvh4Kmde8agjQAVUiGITeaBd5akX';

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
    "Authorization": "Bearer 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",
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

Future<void> createGoogleCalendarEvent(Map<String, dynamic> eventDetails) async {
  final String apiUrl = 'https://www.googleapis.com/calendar/v3/calendars/primary/events';
  final String accessToken = '{"web":{"client_id":"1060715981383-2jrjklqbl538m2nqr1u7glecbt4r7hna.apps.googleusercontent.com","project_id":"smartkalendar-404017","auth_uri":"https://accounts.google.com/o/oauth2/auth","token_uri":"https://oauth2.googleapis.com/token","auth_provider_x509_cert_url":"https://www.googleapis.com/oauth2/v1/certs","client_secret":"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"}}'; // 사용자의 OAuth 2.0 액세스 토큰

  final Map<String, String> headers = {
    'Authorization': 'Bearer $accessToken',
    'Content-Type': 'application/json',
  };

  final String requestBody = jsonEncode(eventDetails);

  final http.Response response = await http.post(
    Uri.parse(apiUrl),
    headers: headers,
    body: requestBody,
  );

  if (response.statusCode == 200) {
    // 이벤트가 성공적으로 생성됨
    print('Event created successfully');
  } else {
    // 오류 응답 처리
    print('Error creating event: ${response.statusCode} - ${response.body}');
  }
}

Future<void> main() async {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(

        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const MyHomePage(title: 'Flutter Demo Home Page'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});


  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
    late Record audioRecord;
    late AudioPlayer audioPlayer;
    bool isRecording = false;
    String audioPath='';
    //String audioPath='/path/to/recorded/audio.wav';
    //String audioPath='https://example.com/my-audio.wav';
    //String audioPath='aFullPath/myFile.m4a';

    @override
  void initState() {
    audioPlayer=AudioPlayer();
    audioRecord=Record();
    super.initState();
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

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      appBar: AppBar(

        title: const Text('Audio Recorder'),
      ),
      body: Center(

        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            if(isRecording)
              const Text(
                'Recording in Progress',
                style: TextStyle(
                  fontSize: 20,
                ),
              ),
            ElevatedButton(
              onPressed: isRecording ? stopRecording : startRecording,
              child: isRecording? const Text('Stop Recording') : const Text('Start Recording'),
            ),
            const SizedBox(
              height:25,
            ),
            if(!isRecording && audioPath !=null)
            ElevatedButton(
              onPressed: playRecording,
              child: const Text('Play Recording'),
            ),

          ],
        ),
      ),
    );
  }
}
