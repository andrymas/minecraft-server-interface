import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'dart:async';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Minecraft Server Manager',
      theme: ThemeData(
        brightness: Brightness.dark,
        primarySwatch: Colors.blue,
      ),
      home: MinecraftServerPage(),
    );
  }
}

class MinecraftServerPage extends StatefulWidget {
  @override
  _MinecraftServerPageState createState() => _MinecraftServerPageState();
}

class _MinecraftServerPageState extends State<MinecraftServerPage> {
  late FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin;
  late Process? _serverProcess;
  bool _isServerRunning = false;
  final List<String> _consoleLines = [];
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _ramSizeController =
      TextEditingController(text: '1024M');
  final TextEditingController _consoleInputController = TextEditingController();
  late StreamSubscription<List<int>> _stdoutSubscription;
  late StreamSubscription<List<int>> _stderrSubscription;

  @override
  void initState() {
    super.initState();
    flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
    _initializeNotifications();
  }

  void _initializeNotifications() async {
    const initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    final initializationSettings =
        InitializationSettings(android: initializationSettingsAndroid);
    await flutterLocalNotificationsPlugin.initialize(initializationSettings);
  }

  void _startServer() async {
    final directory = Directory(Platform.resolvedExecutable).parent;
    final minecraftServerDir = Directory('${directory.path}/minecraft_server');
    final serverFile = File('${minecraftServerDir.path}/server.jar');

    if (!serverFile.existsSync()) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('server.jar non trovato nella cartella minecraft_server!')),
      );
      return;
    }

    try {
      final javaOptions = [
        '-Xmx${_ramSizeController.text}',
        '-Xms${_ramSizeController.text}',
        '-jar',
        serverFile.path,
        'nogui',
      ];

      _serverProcess = await Process.start(
        'java',
        javaOptions,
        workingDirectory: minecraftServerDir.path,
      );

      setState(() {
        _isServerRunning = true;
        _consoleLines.clear();
      });

      _stdoutSubscription = _serverProcess!.stdout.transform(utf8.decoder).listen((data) {
        setState(() {
          _consoleLines.addAll(data.split('\n'));
          _scrollToBottom();
        });
      }) as StreamSubscription<List<int>>;

      _stderrSubscription = _serverProcess!.stderr.transform(utf8.decoder).listen((data) {
        setState(() {
          _consoleLines.addAll(data.split('\n'));
          _scrollToBottom();
        });
      }) as StreamSubscription<List<int>>;

      _showNotification('Server Minecraft Avviato!');
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Errore nell\'avviare il server!'),
      ));
    }
  }

  void _stopServer() async {
    if (_serverProcess != null) {
      _serverProcess!.kill();
      setState(() {
        _isServerRunning = false;
      });
      _stdoutSubscription.cancel();
      _stderrSubscription.cancel();
      _showNotification('Server Minecraft Fermato!');
    }
  }

  void _sendCommand() {
    if (_serverProcess != null && _consoleInputController.text.isNotEmpty) {
      _serverProcess!.stdin.writeln(_consoleInputController.text);
      setState(() {
        _consoleLines.add("> ${_consoleInputController.text}");
        _consoleInputController.clear();
        _scrollToBottom();
      });
    }
  }

  void _showNotification(String message) async {
    const androidDetails = AndroidNotificationDetails(
      'minecraft_server_channel',
      'Minecraft Server Notifications',
      channelDescription: 'Notifiche sullo stato del server Minecraft',
      importance: Importance.high,
      priority: Priority.high,
    );
    const notificationDetails = NotificationDetails(android: androidDetails);
    await flutterLocalNotificationsPlugin.show(0, 'Minecraft Server', message, notificationDetails);
  }

  void _scrollToBottom() {
    Future.delayed(Duration(milliseconds: 100), () {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text('Minecraft Server Manager'),
        backgroundColor: Colors.blueGrey.shade900,
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0),
              child: Container(color: Colors.black.withOpacity(0.3)),
            ),
          ),
          Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ElevatedButton(
                      onPressed: _isServerRunning ? null : _startServer,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: EdgeInsets.symmetric(vertical: 16, horizontal: 24),
                      ),
                      child: Text('Avvia Server', style: TextStyle(fontSize: 16)),
                    ),
                    SizedBox(width: 20),
                    ElevatedButton(
                      onPressed: !_isServerRunning ? null : _stopServer,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.redAccent,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: EdgeInsets.symmetric(vertical: 16, horizontal: 24),
                      ),
                      child: Text('Ferma Server', style: TextStyle(fontSize: 16)),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Container(
                  margin: EdgeInsets.all(16),
                  padding: EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.blueGrey.shade800.withOpacity(0.7),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ListView.builder(
                    controller: _scrollController,
                    itemCount: _consoleLines.length,
                    itemBuilder: (context, index) {
                      return Text(
                        _consoleLines[index],
                        style: TextStyle(color: Colors.white, fontSize: 14),
                      );
                    },
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(12.0),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _consoleInputController,
                        style: TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          hintText: 'Invia comando...',
                          hintStyle: TextStyle(color: Colors.white54),
                          filled: true,
                          fillColor: Colors.blueGrey.shade900,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ),
                    SizedBox(width: 10),
                    IconButton(
                      icon: Icon(Icons.send, color: Colors.white),
                      onPressed: _sendCommand,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
