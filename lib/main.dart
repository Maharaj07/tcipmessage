import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';

void main() {
  runApp(const MyApp());
}

class ChatMessage {
  final String text;
  final bool isSent;
  final DateTime time;
  ChatMessage(this.text, this.isSent) : time = DateTime.now();
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TCP Chat',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const TcpChatPage(),
    );
  }
}

class TcpChatPage extends StatefulWidget {
  const TcpChatPage({super.key});
  @override
  State<TcpChatPage> createState() => _TcpChatPageState();
}

class _TcpChatPageState extends State<TcpChatPage> {
  final TextEditingController _ipController = TextEditingController(text: '10.0.2.2'); // emulator default
  final TextEditingController _portController = TextEditingController(text: '9000');
  final TextEditingController _messageController = TextEditingController();

  final List<ChatMessage> _messages = [];
  final ScrollController _scrollController = ScrollController();

  Socket? _socket;
  StreamSubscription<List<int>>? _socketSub;
  bool _connected = false;
  bool _connecting = false;

  void _addMessage(String text, bool isSent) {
    setState(() {
      _messages.add(ChatMessage(text, isSent));
    });
    // scroll
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent + 60,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _addSystem(String text) {
    _addMessage('[SYSTEM] $text', false);
  }

  Future<void> _connect() async {
    final ip = _ipController.text.trim();
    final port = int.tryParse(_portController.text.trim() ?? '');
    if (ip.isEmpty || port == null) {
      _addSystem('Invalid IP or port.');
      return;
    }
    if (_connected || _connecting) {
      _addSystem('Already connecting/connected.');
      return;
    }

    setState(() => _connecting = true);
    _addSystem('Connecting to $ip:$port ...');

    try {
      // timeout to avoid indefinite wait
      final socket = await Socket.connect(ip, port).timeout(const Duration(seconds: 8));
      _socket = socket;
      setState(() {
        _connected = true;
        _connecting = false;
      });

      _addSystem('Connected to ${socket.remoteAddress.address}:${socket.remotePort}');

      // listen for incoming data
      _socketSub = socket.listen((data) {
        final text = utf8.decode(data);
        _addMessage('[recv] $text', false);
      }, onError: (e) {
        _addSystem('Socket error: $e');
        _disconnectInternal();
      }, onDone: () {
        _addSystem('Remote closed connection.');
        _disconnectInternal();
      });
    } on TimeoutException {
      setState(() => _connecting = false);
      _addSystem('Connection timed out.');
    } catch (e) {
      setState(() => _connecting = false);
      _addSystem('Connect failed: $e');
    }
  }

  Future<void> _disconnectInternal() async {
    try {
      await _socketSub?.cancel();
    } catch (_) {}
    try {
      _socket?.destroy();
    } catch (_) {}
    _socket = null;
    _socketSub = null;
    setState(() {
      _connected = false;
      _connecting = false;
    });
    _addSystem('Disconnected.');
  }

  Future<void> _disconnect() async {
    if (!_connected && !_connecting) {
      _addSystem('Not connected.');
      return;
    }
    _addSystem('Disconnecting...');
    await _disconnectInternal();
  }

  Future<void> _send() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;
    if (_socket == null) {
      _addSystem('Not connected.');
      return;
    }
    try {
      final bytes = utf8.encode(text);
      _socket!.add(bytes);
      await _socket!.flush();
      _addMessage('[send] $text', true);
      _messageController.clear();
    } catch (e) {
      _addSystem('Send failed: $e');
    }
  }

  @override
  void dispose() {
    _disconnectInternal();
    _ipController.dispose();
    _portController.dispose();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Widget _messageTile(ChatMessage m) {
    final align = m.isSent ? Alignment.centerRight : Alignment.centerLeft;
    final bg = m.isSent ? Colors.blue[100] : Colors.grey[200];
    final timeStr = '${m.time.hour.toString().padLeft(2,'0')}:${m.time.minute.toString().padLeft(2,'0')}';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Align(
        alignment: align,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
          child: Column(
            crossAxisAlignment: m.isSent ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
                child: Text(m.text),
              ),
              const SizedBox(height: 4),
              Text(timeStr, style: const TextStyle(fontSize: 11, color: Colors.black54)),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final status = _connecting ? 'Connecting...' : (_connected ? 'Connected' : 'Not connected');
    return Scaffold(
      appBar: AppBar(title: Text('TCP Chat — $status')),
      body: SafeArea(
        child: Column(
          children: [
            // connection inputs
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: Row(children: [
                Expanded(child: TextField(controller: _ipController, decoration: const InputDecoration(labelText: 'Server IP'))),
                const SizedBox(width: 8),
                SizedBox(width: 100, child: TextField(controller: _portController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Port'))),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _connected || _connecting ? _disconnect : _connect,
                  child: Text(_connected ? 'Disconnect' : (_connecting ? 'Cancel' : 'Connect')),
                ),
              ]),
            ),

            const Divider(height: 1),

            // messages
            Expanded(
              child: Container(
                color: Colors.grey[50],
                child: ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(12),
                  itemCount: _messages.length,
                  itemBuilder: (c, i) => _messageTile(_messages[i]),
                ),
              ),
            ),

            // input
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      decoration: const InputDecoration(hintText: 'Type a message'),
                      onSubmitted: (_) => _send(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(onPressed: _send, child: const Text('Send')),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
