import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:just_audio/just_audio.dart';
import '../theme/app_theme.dart';
import '../services/socket_service.dart';
import '../services/auth_service.dart';

class ChatMessage {
  final String senderId;
  final String text;
  final String? audioUrl;
  final DateTime time;
  final bool isMe;
  const ChatMessage({
    required this.senderId,
    required this.text,
    this.audioUrl,
    required this.time,
    required this.isMe,
  });
}

class RideChatScreen extends StatefulWidget {
  final String rideId;
  final String currentUserId;
  final String currentUserRole;
  final String otherUserName;
  const RideChatScreen({
    super.key,
    required this.rideId,
    required this.currentUserId,
    required this.currentUserRole,
    required this.otherUserName,
  });
  @override
  State<RideChatScreen> createState() => _RideChatScreenState();
}

class _RideChatScreenState extends State<RideChatScreen> {
  final _ctrl        = TextEditingController();
  final _scroll      = ScrollController();
  final List<ChatMessage> _messages = [];
  StreamSubscription? _chatSub;

  // ── Voice recording ───────────────────────────────────────────────────────
  late final AudioRecorder _recorder;
  bool  _isRecording   = false;
  bool  _recordingReady= false;
  String? _recordedPath;
  int   _recSeconds    = 0;
  Timer? _recTimer;

  @override
  void initState() {
    super.initState();
    _recorder = AudioRecorder();
    _chatSub  = SocketService.instance.onChatMessage.listen((payload) {
      if (payload['rideId'] != widget.rideId) return;
      if (mounted) {
        setState(() => _messages.add(ChatMessage(
          senderId: payload['senderId'] as String? ?? '',
          text:     payload['text']     as String? ?? '',
          audioUrl: payload['audioUrl'] as String?,
          time:     DateTime.tryParse(payload['timestamp'] as String? ?? '') ?? DateTime.now(),
          isMe:     payload['senderId'] == widget.currentUserId,
        )));
        _scrollToBottom();
      }
    });
  }

  @override
  void dispose() {
    _chatSub?.cancel();
    _recTimer?.cancel();
    _recorder.dispose();
    _ctrl.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(_scroll.position.maxScrollExtent,
            duration: const Duration(milliseconds: 200), curve: Curves.easeOut);
      }
    });
  }

  // ── Send text ──────────────────────────────────────────────────────────────
  void _sendText() {
    final text = _ctrl.text.trim();
    if (text.isEmpty) return;
    _ctrl.clear();
    SocketService.instance.emitChat(
      rideId:     widget.rideId,
      senderId:   widget.currentUserId,
      senderRole: widget.currentUserRole,
      text:       text,
    );
    setState(() => _messages.add(ChatMessage(
      senderId: widget.currentUserId,
      text:     text,
      time:     DateTime.now(),
      isMe:     true,
    )));
    _scrollToBottom();
  }

  // ── Voice recording ───────────────────────────────────────────────────────
  Future<void> _startRecording() async {
    final hasPermission = await _recorder.hasPermission();
    if (!hasPermission) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Microphone permission required'),
        backgroundColor: AppTheme.error, behavior: SnackBarBehavior.floating));
      return;
    }
    final dir  = await getTemporaryDirectory();
    final path = '${dir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
    await _recorder.start(const RecordConfig(encoder: AudioEncoder.aacLc), path: path);
    setState(() { _isRecording = true; _recSeconds = 0; _recordedPath = path; });
    _recTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _recSeconds++);
    });
  }

  Future<void> _stopAndSend() async {
    _recTimer?.cancel();
    final path = await _recorder.stop();
    if (path == null) { setState(() => _isRecording = false); return; }

    setState(() { _isRecording = false; _recordedPath = path; });

    // Upload voice note
    try {
      // Emit as voice note via socket (backend handles S3 upload)
      final bytes = await File(path).readAsBytes();
      final base64Audio = Uri.encodeComponent(String.fromCharCodes(bytes.take(100)));
      SocketService.instance.emitChat(
        rideId:     widget.rideId,
        senderId:   widget.currentUserId,
        senderRole: widget.currentUserRole,
        text:       '🎤 Voice Note (${_recSeconds}s)',
        audioUrl:   path, // local path — backend will upload
      );
      setState(() => _messages.add(ChatMessage(
        senderId: widget.currentUserId,
        text:     '',
        audioUrl: path,
        time:     DateTime.now(),
        isMe:     true,
      )));
      _scrollToBottom();
    } catch (_) {}
  }

  Future<void> _cancelRecording() async {
    _recTimer?.cancel();
    await _recorder.cancel();
    setState(() { _isRecording = false; _recSeconds = 0; _recordedPath = null; });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.primaryDark,
      appBar: AppBar(
        backgroundColor: AppTheme.primaryMid,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: AppTheme.textPrimary, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: AppTheme.primary.withOpacity(0.15),
            child: Text(
              widget.otherUserName.isNotEmpty ? widget.otherUserName[0].toUpperCase() : '?',
              style: const TextStyle(color: AppTheme.primary, fontWeight: FontWeight.w800),
            ),
          ),
          const SizedBox(width: 10),
          Text(widget.otherUserName, style: const TextStyle(
              color: AppTheme.textPrimary, fontWeight: FontWeight.w700, fontSize: 16)),
        ]),
      ),
      body: Column(children: [
        Expanded(
          child: _messages.isEmpty
              ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  const Icon(Icons.chat_bubble_outline_rounded, color: AppTheme.textMuted, size: 44),
                  const SizedBox(height: 10),
                  Text('Message ${widget.otherUserName}',
                      style: const TextStyle(color: AppTheme.textMuted, fontSize: 14)),
                ]))
              : ListView.builder(
                  controller: _scroll,
                  padding: const EdgeInsets.all(16),
                  itemCount: _messages.length,
                  itemBuilder: (_, i) => _MessageBubble(msg: _messages[i]),
                ),
        ),

        // ── Input bar ─────────────────────────────────────────────────────
        Container(
          color: AppTheme.primaryMid,
          padding: EdgeInsets.fromLTRB(
              12, 8, 12, MediaQuery.of(context).viewInsets.bottom + 8),
          child: _isRecording ? _RecordingBar(
            seconds: _recSeconds,
            onSend:   _stopAndSend,
            onCancel: _cancelRecording,
          ) : Row(children: [
            Expanded(child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(24),
              ),
              child: TextField(
                controller: _ctrl,
                style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14),
                onSubmitted: (_) => _sendText(),
                decoration: const InputDecoration(
                  hintText: 'Type a message...',
                  hintStyle: TextStyle(color: AppTheme.textMuted, fontSize: 14),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(vertical: 11),
                ),
              ),
            )),
            const SizedBox(width: 8),
            // Voice note button
            GestureDetector(
              onLongPressStart: (_) => _startRecording(),
              onLongPressEnd: (_) => _stopAndSend(),
              child: Container(
                width: 44, height: 44,
                decoration: BoxDecoration(
                  color: AppTheme.surface, shape: BoxShape.circle),
                child: const Icon(Icons.mic_outlined, color: AppTheme.textSecondary, size: 20),
              ),
            ),
            const SizedBox(width: 8),
            // Send button
            GestureDetector(
              onTap: _sendText,
              child: Container(
                width: 44, height: 44,
                decoration: BoxDecoration(color: AppTheme.primary, shape: BoxShape.circle),
                child: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
              ),
            ),
          ]),
        ),
      ]),
    );
  }
}

// ── Recording bar ─────────────────────────────────────────────────────────────
class _RecordingBar extends StatelessWidget {
  final int seconds;
  final VoidCallback onSend;
  final VoidCallback onCancel;
  const _RecordingBar({required this.seconds, required this.onSend, required this.onCancel});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    decoration: BoxDecoration(
      color: AppTheme.error.withOpacity(0.12),
      borderRadius: BorderRadius.circular(28),
      border: Border.all(color: AppTheme.error.withOpacity(0.3)),
    ),
    child: Row(children: [
      const Icon(Icons.fiber_manual_record, color: AppTheme.error, size: 12),
      const SizedBox(width: 6),
      Text('${seconds}s', style: const TextStyle(color: AppTheme.error, fontWeight: FontWeight.w700)),
      const SizedBox(width: 8),
      const Text('Recording...', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
      const Spacer(),
      IconButton(icon: const Icon(Icons.close, color: AppTheme.textMuted, size: 20), onPressed: onCancel),
      const SizedBox(width: 4),
      GestureDetector(
        onTap: onSend,
        child: Container(
          width: 40, height: 40,
          decoration: BoxDecoration(color: AppTheme.primary, shape: BoxShape.circle),
          child: const Icon(Icons.send_rounded, color: Colors.white, size: 18),
        ),
      ),
    ]),
  );
}

// ── Message bubble ────────────────────────────────────────────────────────────
class _MessageBubble extends StatelessWidget {
  final ChatMessage msg;
  const _MessageBubble({required this.msg});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(
      mainAxisAlignment: msg.isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
      children: [
        Container(
          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.72),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: msg.isMe ? AppTheme.primary : AppTheme.primaryMid,
            borderRadius: BorderRadius.only(
              topLeft:     const Radius.circular(16),
              topRight:    const Radius.circular(16),
              bottomLeft:  Radius.circular(msg.isMe ? 16 : 4),
              bottomRight: Radius.circular(msg.isMe ? 4  : 16),
            ),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            if (msg.audioUrl != null)
              _VoicePlayer(audioPath: msg.audioUrl!, isMe: msg.isMe)
            else
              Text(msg.text, style: TextStyle(
                  color: msg.isMe ? Colors.white : AppTheme.textPrimary,
                  fontSize: 14, height: 1.4)),
            const SizedBox(height: 3),
            Text(
              '${msg.time.hour.toString().padLeft(2,'0')}:${msg.time.minute.toString().padLeft(2,'0')}',
              style: TextStyle(
                color: msg.isMe ? Colors.white.withOpacity(0.6) : AppTheme.textMuted,
                fontSize: 10,
              ),
            ),
          ]),
        ),
      ],
    ),
  );
}

// ── Voice note player ─────────────────────────────────────────────────────────
class _VoicePlayer extends StatefulWidget {
  final String audioPath;
  final bool isMe;
  const _VoicePlayer({required this.audioPath, required this.isMe});
  @override
  State<_VoicePlayer> createState() => _VoicePlayerState();
}

class _VoicePlayerState extends State<_VoicePlayer> {
  late final AudioPlayer _player;
  bool _playing = false;
  Duration _pos = Duration.zero;
  Duration _dur = Duration.zero;

  @override
  void initState() {
    super.initState();
    _player = AudioPlayer();
    _initAudio();
  }

  Future<void> _initAudio() async {
    try {
      if (widget.audioPath.startsWith('http')) {
        await _player.setUrl(widget.audioPath);
      } else {
        await _player.setFilePath(widget.audioPath);
      }
      _player.durationStream.listen((d) { if (mounted && d != null) setState(() => _dur = d); });
      _player.positionStream.listen((p) { if (mounted) setState(() => _pos = p); });
      _player.playerStateStream.listen((s) {
        if (mounted) setState(() => _playing = s.playing);
      });
    } catch (_) {}
  }

  @override
  void dispose() { _player.dispose(); super.dispose(); }

  String _fmt(Duration d) =>
      '${d.inMinutes.toString().padLeft(2,'0')}:${(d.inSeconds%60).toString().padLeft(2,'0')}';

  @override
  Widget build(BuildContext context) {
    final color = widget.isMe ? Colors.white : AppTheme.textPrimary;
    final progress = _dur.inMilliseconds > 0 ? _pos.inMilliseconds / _dur.inMilliseconds : 0.0;
    return SizedBox(
      width: 180,
      child: Row(children: [
        GestureDetector(
          onTap: () async {
            if (_playing) await _player.pause();
            else await _player.play();
          },
          child: Container(
            width: 34, height: 34,
            decoration: BoxDecoration(
              color: widget.isMe ? Colors.white.withOpacity(0.2) : AppTheme.primary.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(
              _playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
              color: widget.isMe ? Colors.white : AppTheme.primary,
              size: 20,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: progress.clamp(0.0, 1.0),
              backgroundColor: color.withOpacity(0.2),
              valueColor: AlwaysStoppedAnimation<Color>(
                  widget.isMe ? Colors.white : AppTheme.primary),
              minHeight: 3,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            _playing ? _fmt(_pos) : _fmt(_dur),
            style: TextStyle(color: color.withOpacity(0.7), fontSize: 10),
          ),
        ])),
      ]),
    );
  }
}
