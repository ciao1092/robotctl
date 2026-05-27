import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_joystick/flutter_joystick.dart';
import 'package:robotctl/battery.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Robot Control',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: .fromSeed(
          seedColor: Colors.blue,
          brightness: Brightness.light,
        ),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorScheme: .fromSeed(
          seedColor: Colors.blue,
          brightness: Brightness.dark,
        ),
      ),
      themeMode: ThemeMode.system,
      home: const IPSelectorPage(),
    );
  }
}

class IPSelectorPage extends StatefulWidget {
  const IPSelectorPage({super.key});

  @override
  State<IPSelectorPage> createState() => _IPSelectorPageState();
}

class _IPSelectorPageState extends State<IPSelectorPage> {
  String currentInput = "";
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  final TextEditingController _textEditingController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Connection"),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Padding(
        padding: const EdgeInsets.all(10.0),
        child: Form(
          key: _formKey,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 20.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _textEditingController,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(),
                      hintText: "Address",
                    ),
                  ),
                ),
                SizedBox(width: 10),
                ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            MyHomePage(ipAddress: _textEditingController.text),
                      ),
                    );
                  },
                  child: const Padding(
                    padding: EdgeInsets.symmetric(
                      vertical: 15.0,
                      horizontal: 5.0,
                    ),
                    child: Text("Connect"),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.ipAddress});

  // This widget is the home page of your application. It is stateful, meaning
  // that it has a State object (defined below) that contains fields that affect
  // how it looks.

  // This class is the configuration for the state. It holds the values (in this
  // case the title) provided by the parent (in this case the App widget) and
  // used by the build method of the State. Fields in a Widget subclass are
  // always marked "final".

  final String ipAddress;
  final String title = "Robot Control";

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  double smoothedX = 0;
  double smoothedY = 0;
  double alpha = 0.18;

  double battery = 0.0;

  static const double deadZone = 0.12;
  static const double curve = 1.8;

  WebSocketChannel? channel;
  String lastMessage = "Not connected";

  DateTime lastSend = DateTime.now();

  void onJoystick(double x, double y) {
    x = processAxis(x);
    y = processAxis(y);

    smoothedX = smooth(smoothedX, x, alpha);
    smoothedY = smooth(smoothedY, y, alpha);

    sendJoystick(smoothedX, smoothedY);
  }

  double processAxis(double value) {
    value = applyDeadzone(value, deadZone);
    value = applyCurve(value, curve);
    return value;
  }

  void sendJoystick(double x, double y) {
    if (channel == null) return;

    final now = DateTime.now();

    if (now.difference(lastSend).inMilliseconds < 50) return;
    lastSend = now;

    final msg = "${(x * 100).toInt()},${(y * 100).toInt()}";
    channel!.sink.add(msg);
  }

  double smooth(double current, double target, double alpha) {
    return current + alpha * (target - current);
  }

  double applyDeadzone(double value, double deadzone) {
    if (value.abs() < deadzone) return 0;

    // re-scale so movement is smooth after deadzone
    return value > 0
        ? (value - deadzone) / (1 - deadzone)
        : (value + deadzone) / (1 - deadzone);
  }

  double applyCurve(double value, double exponent) {
    return value.sign * (pow(value.abs(), exponent));
  }

  @override
  void initState() {
    super.initState();
    channel = WebSocketChannel.connect(Uri.parse("ws://${widget.ipAddress}"));
  }

  @override
  void dispose() {
    channel?.sink.close();
    super.dispose();
  }

  double? getBatteryFromRawData(String raw) {
    final Map<String, dynamic> data = jsonDecode(raw);

    var x = data['battery']?.toString();
    if (x == null) return null;

    final double? battery = double.tryParse(x);

    return battery;
  }

  @override
  Widget build(BuildContext context) {
    if (channel == null) return const Text("Loading...");
    return StreamBuilder(
      stream: channel!.stream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Scaffold(
            appBar: AppBar(title: const Text("Error")),
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.wifi_off, color: Colors.red, size: 48),
                  Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Text('Error: ${snapshot.error}'),
                  ),
                  ElevatedButton(
                    child: Padding(
                      padding: const EdgeInsets.all(10.0),
                      child: const Text('Retry'),
                    ),
                    onPressed: () {
                      setState(() {
                        channel = WebSocketChannel.connect(
                          Uri.parse("ws://${widget.ipAddress}"),
                        );
                      });
                    },
                  ),
                ],
              ),
            ),
          );
        }

        switch (snapshot.connectionState) {
          case ConnectionState.none:
          case ConnectionState.waiting:
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          case ConnectionState.done:
            return Scaffold(
              appBar: AppBar(title: const Text("Disconnected")),
              body: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.wifi_off, color: Colors.orange, size: 48),
                    Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: const Text('Disconnected'),
                    ),
                    ElevatedButton(
                      onPressed: () {
                        setState(() {
                          channel = WebSocketChannel.connect(
                            Uri.parse("ws://${widget.ipAddress}"),
                          );
                        });
                      },
                      child: Padding(
                        padding: const EdgeInsets.all(10.0),
                        child: const Text('Reconnect'),
                      ),
                    ),
                  ],
                ),
              ),
            );
          case ConnectionState.active:
            if (snapshot.hasData) {
              lastMessage = snapshot.data.toString();
              final bat = getBatteryFromRawData(snapshot.data.toString());
              if (bat != null) battery = bat;
            }
        }

        return Scaffold(
          appBar: AppBar(
            backgroundColor: Theme.of(context).colorScheme.inversePrimary,
            title: Row(
              children: [
                Text(widget.title),
                Spacer(),
                BatteryIcon(level: battery),
              ],
            ),
          ),
          body: Center(
            child: Column(
              mainAxisAlignment: .center,
              children: [
                Text("Connected to: ${widget.ipAddress}"),
                const SizedBox(height: 40),
                Joystick(
                  base: JoystickBase(
                    decoration: JoystickBaseDecoration(
                      color: Colors.black,
                      drawOuterCircle: false,
                    ),
                    arrowsDecoration: JoystickArrowsDecoration(
                      color: Colors.blue,
                    ),
                  ),
                  listener: (details) {
                    onJoystick(details.x, details.y);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
