import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../core/services/realtime_service.dart';
import '../data/account_repository.dart';
import '../domain/account_models.dart';

class ActiveCallPage extends ConsumerStatefulWidget {
  const ActiveCallPage({
    super.key,
    required this.args,
  });

  static const routePath = '/active-call';

  final ActiveCallArgs args;

  @override
  ConsumerState<ActiveCallPage> createState() => _ActiveCallPageState();
}

class _ActiveCallPageState extends ConsumerState<ActiveCallPage> {
  StateController<String?>? _activeCallRoomController;
  RealtimeService? _realtimeService;
  StreamSubscription<String>? _callReadySubscription;
  StreamSubscription<Map<String, dynamic>>? _rtcMessageSubscription;
  StreamSubscription<String>? _byeSubscription;
  RTCPeerConnection? _peerConnection;
  MediaStream? _localStream;
  MediaStreamTrack? _audioTrack;
  final List<RTCIceCandidate> _pendingIceCandidates = <RTCIceCandidate>[];
  bool _remoteDescriptionSet = false;
  Timer? _durationTimer;
  DateTime? _connectedAt;
  String _callState = 'Connecting protected audio...';
  bool _isMuted = false;
  bool _speakerOn = true;
  bool _callStarted = false;
  bool _offerSent = false;
  bool _accepting = false;
  List<Map<String, dynamic>> _iceServers = <Map<String, dynamic>>[
    <String, dynamic>{
      'urls': <String>[
        'stun:stun.l.google.com:19302',
        'stun:stun1.l.google.com:19302',
      ],
    },
  ];

  String? get _partnerImageUrl {
    final value = widget.args.partnerImageUrl?.trim();
    if (value == null ||
        value.isEmpty ||
        value.toLowerCase() == 'undefined' ||
        value.toLowerCase() == 'null' ||
        value.endsWith('/undefined') ||
        value.endsWith('/null')) {
      return null;
    }
    return value;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_bootstrap());
    });
  }

  Future<void> _bootstrap() async {
    if (!mounted) {
      return;
    }
    _activeCallRoomController = ref.read(activeCallRoomProvider.notifier);
    _activeCallRoomController!.state = widget.args.roomId;
    final realtimeService = ref.read(realtimeServiceProvider);
    _realtimeService = realtimeService;
    try {
      final configuredServers =
          await ref.read(accountRepositoryProvider).getCallIceServers();
      if (configuredServers.isNotEmpty) {
        _iceServers = configuredServers;
      }
    } catch (error) {
      debugPrint('Call ICE configuration fallback: $error');
    }
    if (!(await Permission.microphone.request()).isGranted) {
      if (mounted) {
        Navigator.of(context).pop();
      }
      return;
    }
    _bindSocketEvents();
    // Retain the room before attempting the network connection. The realtime
    // service rejoins it automatically after transient nginx/network outages.
    realtimeService.joinCall(widget.args.roomId);
    try {
      await realtimeService.connect();
    } catch (error) {
      debugPrint('Call signaling is reconnecting: $error');
      if (mounted) {
        setState(() {
          _callState = 'Reconnecting call...';
        });
      }
    }
    if (widget.args.isCaller) {
      await _startPeer();
      try {
        await ref.read(accountRepositoryProvider).makeMaskedCall(
              receiverId: widget.args.partnerId,
              roomId: widget.args.roomId,
              onRideId: widget.args.onRideId,
            );
        if (mounted) {
          setState(() {
            _callState = 'Calling ${widget.args.partnerName}...';
          });
        }
      } catch (error) {
        if (!mounted) {
          return;
        }
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$error')));
        Navigator.of(context).pop();
      }
    } else {
      setState(() {
        _callState = '${widget.args.partnerName} is calling you';
      });
    }
  }

  void _bindSocketEvents() {
    final realtimeService = _realtimeService;
    if (realtimeService == null) {
      return;
    }
    _callReadySubscription?.cancel();
    _rtcMessageSubscription?.cancel();
    _byeSubscription?.cancel();
    _callReadySubscription = realtimeService.callReady.listen((roomId) {
      if (roomId != widget.args.roomId) {
        return;
      }
      if (widget.args.isCaller && _peerConnection != null) {
        unawaited(_createOffer());
      }
    });
    _rtcMessageSubscription = realtimeService.rtcMessages.listen((payload) {
      unawaited(_handleRtcMessage(payload));
    });
    _byeSubscription = realtimeService.callBye.listen((roomId) {
      if (roomId != widget.args.roomId) {
        return;
      }
      if (mounted) {
        Navigator.of(context).pop();
      }
    });
  }

  Future<void> _startPeer() async {
    if (_callStarted) {
      return;
    }
    _callStarted = true;
    _localStream = await navigator.mediaDevices.getUserMedia(<String, dynamic>{
      'audio': true,
      'video': false,
    });
    _audioTrack = _localStream?.getAudioTracks().isNotEmpty == true
        ? _localStream!.getAudioTracks().first
        : null;
    _peerConnection = await createPeerConnection(
      <String, dynamic>{
        'iceServers': _iceServers,
      },
      <String, dynamic>{},
    );
    for (final track in _localStream?.getTracks() ?? <MediaStreamTrack>[]) {
      await _peerConnection?.addTrack(track, _localStream!);
    }
    _peerConnection?.onIceCandidate = (candidate) {
      if (candidate.candidate == null) {
        return;
      }
      _realtimeService?.sendRtcMessage(<String, dynamic>{
        'room_id': widget.args.roomId,
        'message_type': 'candidate',
        'candidate': <dynamic>[
          candidate.sdpMid,
          candidate.sdpMLineIndex,
          candidate.candidate,
        ],
      });
    };
    _peerConnection?.onIceConnectionState = (state) {
      if (!mounted) {
        return;
      }
      if (state == RTCIceConnectionState.RTCIceConnectionStateConnected ||
          state == RTCIceConnectionState.RTCIceConnectionStateCompleted) {
        _markConnected();
      } else if (state ==
              RTCIceConnectionState.RTCIceConnectionStateDisconnected ||
          state == RTCIceConnectionState.RTCIceConnectionStateFailed) {
        setState(() {
          _callState = 'Call connection interrupted';
        });
      }
    };
    _peerConnection?.onConnectionState = (state) {
      if (!mounted) {
        return;
      }
      if (state == RTCPeerConnectionState.RTCPeerConnectionStateConnected) {
        _markConnected();
      } else if (state == RTCPeerConnectionState.RTCPeerConnectionStateFailed) {
        setState(() {
          _callState = 'Audio connection failed. Please call again.';
        });
      }
    };
    _peerConnection?.onTrack = (event) {
      if (event.track.kind == 'audio') {
        event.track.enabled = true;
        unawaited(Helper.setSpeakerphoneOn(_speakerOn));
        _markConnected();
      }
    };
    await Helper.setSpeakerphoneOn(_speakerOn);
  }

  Future<void> _createOffer() async {
    if (_offerSent) {
      return;
    }
    _offerSent = true;
    final description = await _peerConnection?.createOffer();
    if (description == null) {
      _offerSent = false;
      return;
    }
    await _peerConnection?.setLocalDescription(description);
    _realtimeService?.sendRtcMessage(<String, dynamic>{
      'room_id': widget.args.roomId,
      'message_type': 'offer',
      'sdp': description.sdp,
    });
  }

  Future<void> _createAnswer() async {
    final description = await _peerConnection?.createAnswer();
    if (description == null) {
      return;
    }
    await _peerConnection?.setLocalDescription(description);
    _realtimeService?.sendRtcMessage(<String, dynamic>{
      'room_id': widget.args.roomId,
      'message_type': 'answer',
      'sdp': description.sdp,
    });
  }

  Future<void> _handleRtcMessage(dynamic payload) async {
    final mapped = _asMap(payload);
    if (mapped['room_id']?.toString() != widget.args.roomId) {
      return;
    }
    final messageType = mapped['message_type']?.toString() ?? '';
    if (messageType == 'offer' || messageType == 'answer') {
      await _startPeer();
      await _peerConnection?.setRemoteDescription(
        RTCSessionDescription(
          mapped['sdp']?.toString() ?? '',
          messageType,
        ),
      );
      _remoteDescriptionSet = true;
      await _flushPendingIceCandidates();
      if (messageType == 'offer') {
        await _createAnswer();
      }
    } else if (messageType == 'candidate') {
      final candidate = mapped['candidate'];
      if (candidate is List && candidate.length >= 3) {
        await _addOrQueueIceCandidate(
          RTCIceCandidate(
            candidate[2]?.toString(),
            candidate[0]?.toString(),
            candidate[1] is int
                ? candidate[1] as int
                : int.tryParse(candidate[1].toString()),
          ),
        );
      }
    }
  }

  Future<void> _addOrQueueIceCandidate(RTCIceCandidate candidate) async {
    final peerConnection = _peerConnection;
    if (peerConnection == null || !_remoteDescriptionSet) {
      _pendingIceCandidates.add(candidate);
      return;
    }
    await peerConnection.addCandidate(candidate);
  }

  Future<void> _flushPendingIceCandidates() async {
    final peerConnection = _peerConnection;
    if (peerConnection == null || !_remoteDescriptionSet) {
      return;
    }
    final candidates = List<RTCIceCandidate>.from(_pendingIceCandidates);
    _pendingIceCandidates.clear();
    for (final candidate in candidates) {
      await peerConnection.addCandidate(candidate);
    }
  }

  Map<String, dynamic> _asMap(dynamic payload) {
    if (payload is Map<String, dynamic>) {
      return payload;
    }
    if (payload is Map) {
      return payload.map((key, value) => MapEntry(key.toString(), value));
    }
    if (payload is String && payload.trim().isNotEmpty) {
      final decoded = jsonDecode(payload);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
    }
    return <String, dynamic>{};
  }

  void _markConnected() {
    if (_connectedAt != null || !mounted) {
      return;
    }
    setState(() {
      _connectedAt = DateTime.now();
      _callState = 'Connected';
    });
    _durationTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  String get _durationLabel {
    final connectedAt = _connectedAt;
    if (connectedAt == null) {
      return '00:00';
    }
    final elapsed = DateTime.now().difference(connectedAt).inSeconds;
    final minutes = (elapsed ~/ 60).toString().padLeft(2, '0');
    final seconds = (elapsed % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  Future<void> _acceptIncomingCall() async {
    if (_accepting) {
      return;
    }
    _accepting = true;
    try {
      await _startPeer();
      _realtimeService?.readyCall(widget.args.roomId);
      if (mounted) {
        setState(() {
          _callState = 'Connecting...';
        });
      }
    } finally {
      _accepting = false;
    }
  }

  Future<void> _toggleMute() async {
    final next = !_isMuted;
    final audioTrack = _audioTrack;
    if (audioTrack != null) {
      await Helper.setMicrophoneMute(next, audioTrack);
      audioTrack.enabled = !next;
    }
    if (mounted) {
      setState(() {
        _isMuted = next;
      });
    }
  }

  Future<void> _toggleSpeaker() async {
    final next = !_speakerOn;
    await Helper.setSpeakerphoneOn(next);
    if (mounted) {
      setState(() {
        _speakerOn = next;
      });
    }
  }

  Future<void> _endCall() async {
    _realtimeService?.sendBye(widget.args.roomId);
    try {
      await ref.read(accountRepositoryProvider).endMaskedCall(
            roomId: widget.args.roomId,
            receiverId: widget.args.partnerId,
          );
    } catch (_) {}
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  void dispose() {
    final activeCallRoom = _activeCallRoomController;
    final roomId = widget.args.roomId;
    // Riverpod rejects provider writes while the widget tree is unmounting.
    // Clear the global call marker immediately after this lifecycle completes.
    Future<void>.microtask(() {
      if (activeCallRoom?.state == roomId) {
        activeCallRoom?.state = null;
      }
    });
    _durationTimer?.cancel();
    _pendingIceCandidates.clear();
    _callReadySubscription?.cancel();
    _rtcMessageSubscription?.cancel();
    _byeSubscription?.cancel();
    _peerConnection?.close();
    _peerConnection?.dispose();
    _localStream?.dispose();
    Helper.setSpeakerphoneOn(false);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF151210),
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF211B18), Color(0xFF100E0D)],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 18, 24, 34),
            child: Column(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.09),
                    ),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.lock_rounded,
                          size: 14, color: Color(0xFFFF8A6B)),
                      SizedBox(width: 7),
                      Text(
                        'SHILOTA  •  SECURE CALL',
                        style: TextStyle(
                          color: Color(0xFFD7CBC5),
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.1,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(flex: 2),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: const Color(0xFFF04E29).withValues(alpha: 0.35),
                    ),
                  ),
                  child: Container(
                    padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withValues(alpha: 0.06),
                    ),
                    child: CircleAvatar(
                      radius: 55,
                      backgroundColor: const Color(0xFFFCE7E1),
                      backgroundImage: _partnerImageUrl != null
                          ? NetworkImage(_partnerImageUrl!)
                          : null,
                      child: _partnerImageUrl == null
                          ? const Icon(
                              Icons.person_rounded,
                              size: 44,
                              color: Color(0xFFF04E29),
                            )
                          : null,
                    ),
                  ),
                ),
                const SizedBox(height: 28),
                Text(
                  widget.args.partnerName,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 30,
                    height: 1.1,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.6,
                  ),
                ),
                const SizedBox(height: 13),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF04E29).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    _callState,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Color(0xFFFFA68F),
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  _durationLabel,
                  style: const TextStyle(
                    color: Color(0xFFD7CBC5),
                    fontSize: 22,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 1.2,
                  ),
                ),
                const Spacer(flex: 3),
                if (!widget.args.isCaller && !_callStarted)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _CallActionButton(
                        label: 'Decline',
                        icon: Icons.call_end_rounded,
                        accent: const Color(0xFFFF6B64),
                        onTap: _endCall,
                      ),
                      _CallActionButton(
                        label: 'Answer',
                        icon: Icons.call_rounded,
                        accent: const Color(0xFF2FB66D),
                        filled: true,
                        onTap: _acceptIncomingCall,
                      ),
                    ],
                  )
                else
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _CallActionButton(
                        label: _isMuted ? 'Unmute' : 'Mute',
                        icon: _isMuted
                            ? Icons.mic_off_rounded
                            : Icons.mic_rounded,
                        onTap: _toggleMute,
                      ),
                      _CallActionButton(
                        label: _speakerOn ? 'Speaker' : 'Earpiece',
                        icon: _speakerOn
                            ? Icons.volume_up_rounded
                            : Icons.hearing_rounded,
                        onTap: _toggleSpeaker,
                      ),
                      _CallActionButton(
                        label: 'End',
                        icon: Icons.call_end_rounded,
                        accent: const Color(0xFFD84322),
                        filled: true,
                        onTap: _endCall,
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CallActionButton extends StatelessWidget {
  const _CallActionButton({
    required this.label,
    required this.icon,
    required this.onTap,
    this.accent = Colors.white,
    this.filled = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final Color accent;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(999),
          child: Ink(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: filled ? accent : Colors.white.withValues(alpha: 0.08),
              shape: BoxShape.circle,
              border: Border.all(
                color: filled ? accent : Colors.white.withValues(alpha: 0.14),
              ),
              boxShadow: filled
                  ? [
                      BoxShadow(
                        color: accent.withValues(alpha: 0.28),
                        blurRadius: 22,
                        offset: const Offset(0, 8),
                      ),
                    ]
                  : null,
            ),
            child: Icon(icon, color: Colors.white, size: 28),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFFE9E1DD),
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
