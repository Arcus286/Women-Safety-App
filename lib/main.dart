import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'package:sensors_plus/sensors_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_phone_direct_caller/flutter_phone_direct_caller.dart';

// ─────────────────────────────────────────
// CONFIG
// ─────────────────────────────────────────
const String kUserName          = 'Achyuth';
const String kUserCity          = 'Bengaluru';
const String kSosNumber         = '+919972369000';
const String kSosEmail          = 'akshayvenkat02@gmail.com';
const String kUserLocationUrl   = 'https://maps.google.com/?q=12.9716,77.5946';
const String kEmailJsServiceId  = 'service_5g2k1o4';
const String kEmailJsTemplateId = 'template_3qrw9eh';
const String kEmailJsPublicKey  = '7nl4fncQpJdODJZaR';

// ── Must match CHANNEL constant in MainActivity.kt exactly
const _kWakeChannel = 'com.example.coolapp/wakeword';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
  ));
  runApp(const MaterialApp(
    debugShowCheckedModeBanner: false,
    home: StealthHome(),
  ));
}

// ──────────────────────────────────────────────────────────────
// Accelerometer detector
// ──────────────────────────────────────────────────────────────
class AccelerometerDetector {
  static const double _jerkMagnitudeThreshold = 24.0;
  static const double _jerkDeltaThreshold     = 13.0;
  static const int    _jerkCountWindow         = 1500;
  static const int    _jerkCountRequired       = 2;
  static const double _freeFallThreshold       = 2.2;
  static const int    _freeFallMinMs           = 350;
  static const double _impactThreshold         = 21.0;

  double _prevMag = 9.81;
  final List<int> _jerkTimestamps = [];
  bool _inFreeFall    = false;
  int  _freeFallStart = 0;
  final VoidCallback onDistressDetected;
  bool _alertFired = false;

  AccelerometerDetector({required this.onDistressDetected});
  void reset() => _alertFired = false;

  void processSample(double x, double y, double z) {
    if (_alertFired) return;
    final int    now   = DateTime.now().millisecondsSinceEpoch;
    final double mag   = sqrt(x * x + y * y + z * z);
    final double delta = (mag - _prevMag).abs();
    if (mag > _jerkMagnitudeThreshold || delta > _jerkDeltaThreshold)
      _jerkTimestamps.add(now);
    _jerkTimestamps.removeWhere((t) => now - t > _jerkCountWindow);
    if (_jerkTimestamps.length >= _jerkCountRequired) { _triggerAlert(); return; }
    if (!_inFreeFall) {
      if (mag < _freeFallThreshold) { _inFreeFall = true; _freeFallStart = now; }
    } else {
      final int elapsed = now - _freeFallStart;
      if (mag > _impactThreshold && elapsed >= _freeFallMinMs) { _triggerAlert(); return; }
      else if (elapsed > 2000) _inFreeFall = false;
    }
    _prevMag = mag;
  }

  void _triggerAlert() {
    if (_alertFired) return;
    _alertFired = true;
    _jerkTimestamps.clear();
    _inFreeFall = false;
    onDistressDetected();
  }
}

// ──────────────────────────────────────────────────────────────
// COLOUR PALETTE
// ──────────────────────────────────────────────────────────────
class _P {
  static const bg0        = Color(0xFF0D0509);
  static const bg1        = Color(0xFF1A0812);
  static const bg2        = Color(0xFF260C1A);
  static const rose       = Color(0xFFE91E8C);
  static const roseSoft   = Color(0xFFFF6EB4);
  static const rosePale   = Color(0xFFFFB3D9);
  static const roseDeep   = Color(0xFFAD1457);
  static const hotPink    = Color(0xFFFF2D78);
  static const blush      = Color(0xFFFFD6E8);
  static const glass      = Color(0x1AFF6EB4);
  static const glassBorder= Color(0x33FF6EB4);
  static const textHi     = Color(0xFFFFF0F5);
  static const textMid    = Color(0xFFE8AECB);
  static const textLow    = Color(0xFF9E6080);
  static const safe       = Color(0xFF00E676);
  static const danger     = Color(0xFFFF1744);
  static const wakeActive = Color(0xFFFFAB40);
}

// ──────────────────────────────────────────────────────────────
// SOS HELPERS
// ──────────────────────────────────────────────────────────────
Future<void> triggerSosCall() async {
  try {
    await FlutterPhoneDirectCaller.callNumber(kSosNumber);
  } catch (e) {
    final Uri callUri = Uri(scheme: 'tel', path: kSosNumber);
    try { await launchUrl(callUri, mode: LaunchMode.externalApplication); }
    catch (_) {}
  }
}

Future<void> triggerSosEmail() async {
  final Uri endpoint = Uri.parse('https://api.emailjs.com/api/v1.0/email/send');
  try {
    final response = await http.post(
      endpoint,
      headers: {'Content-Type': 'application/json', 'origin': 'http://localhost'},
      body: jsonEncode({
        'service_id':  kEmailJsServiceId,
        'template_id': kEmailJsTemplateId,
        'user_id':     kEmailJsPublicKey,
        'template_params': {
          'to_email':     kSosEmail,
          'user_name':    kUserName,
          'user_city':    kUserCity,
          'location_url': kUserLocationUrl,
          'time':         DateTime.now().toLocal().toString(),
        },
      }),
    );
    debugPrint(response.statusCode == 200 ? 'SOS email sent' : 'SOS email failed: ${response.statusCode}');
  } catch (e) { debugPrint('SOS EMAIL ERROR: $e'); }
}

// ──────────────────────────────────────────────────────────────
// PARTICLE PAINTER
// ──────────────────────────────────────────────────────────────
class _Orb {
  double x, y, r, opacity, speed, phase;
  _Orb({required this.x, required this.y, required this.r,
        required this.opacity, required this.speed, required this.phase});
}

class _ParticlePainter extends CustomPainter {
  final double tick;
  final List<_Orb> orbs;
  _ParticlePainter(this.tick, this.orbs);

  @override
  void paint(Canvas canvas, Size size) {
    for (final orb in orbs) {
      final dy = sin(tick * orb.speed + orb.phase) * 18;
      final dx = cos(tick * orb.speed * 0.7 + orb.phase) * 10;
      final center = Offset(orb.x * size.width + dx, orb.y * size.height + dy);
      final paint = Paint()
        ..shader = RadialGradient(colors: [
          _P.rose.withOpacity(orb.opacity),
          _P.roseSoft.withOpacity(orb.opacity * 0.4),
          Colors.transparent,
        ]).createShader(Rect.fromCircle(center: center, radius: orb.r));
      canvas.drawCircle(center, orb.r, paint);
    }
  }

  @override
  bool shouldRepaint(_ParticlePainter old) => old.tick != tick;
}

// ──────────────────────────────────────────────────────────────
// WAKE WORD STATE
// ──────────────────────────────────────────────────────────────
enum WakeWordState { idle, listening, triggered }

// ──────────────────────────────────────────────────────────────
// MAIN APP
// ──────────────────────────────────────────────────────────────
class StealthHome extends StatefulWidget {
  const StealthHome({super.key});
  @override
  State<StealthHome> createState() => _StealthHomeState();
}

class _StealthHomeState extends State<StealthHome> with TickerProviderStateMixin {
  Timer?  _countdownTimer;
  int     _seconds    = 20;
  bool    _timeCapped = false;
  String  _currentViewState = 'home';

  final TextEditingController _safeLabelCtrl   = TextEditingController(text: 'Ligma');
  final TextEditingController _unsafeLabelCtrl = TextEditingController(text: 'Code Hazard');

  // ── accelerometer only (no noise meter)
  late final AccelerometerDetector _detector;
  StreamSubscription<UserAccelerometerEvent>? _accelSub;

  // ── wake word via MethodChannel
  static const _wakeChannel = MethodChannel(_kWakeChannel);
  WakeWordState _wakeState  = WakeWordState.idle;
  bool _wakeEnabled         = true;

  // ── animations
  late AnimationController _bgCtrl;
  late AnimationController _pulseCtrl;
  late AnimationController _shieldCtrl;
  late AnimationController _pageCtrl;
  late AnimationController _wakeRingCtrl;
  late Animation<double>   _pulseAnim;
  late Animation<double>   _shieldAnim;
  late Animation<double>   _pageAnim;
  late Animation<double>   _wakeRingAnim;

  late final List<_Orb> _orbs;

  @override
  void initState() {
    super.initState();
    final rng = Random(42);
    _orbs = List.generate(7, (_) => _Orb(
      x: rng.nextDouble(), y: rng.nextDouble(),
      r: rng.nextDouble() * 80 + 40,
      opacity: rng.nextDouble() * 0.07 + 0.03,
      speed: rng.nextDouble() * 0.4 + 0.2,
      phase: rng.nextDouble() * pi * 2,
    ));

    _bgCtrl       = AnimationController(vsync: this, duration: const Duration(seconds: 12))..repeat();
    _pulseCtrl    = AnimationController(vsync: this, duration: const Duration(milliseconds: 1600))..repeat(reverse: true);
    _shieldCtrl   = AnimationController(vsync: this, duration: const Duration(milliseconds: 2800))..repeat(reverse: true);
    _pageCtrl     = AnimationController(vsync: this, duration: const Duration(milliseconds: 600))..forward();
    _wakeRingCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))..repeat(reverse: true);

    _pulseAnim    = Tween<double>(begin: 1.0, end: 1.10).animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));
    _shieldAnim   = Tween<double>(begin: 0.0, end: 1.0).animate(CurvedAnimation(parent: _shieldCtrl, curve: Curves.easeInOut));
    _pageAnim     = CurvedAnimation(parent: _pageCtrl, curve: Curves.easeOut);
    _wakeRingAnim = Tween<double>(begin: 0.6, end: 1.0).animate(CurvedAnimation(parent: _wakeRingCtrl, curve: Curves.easeInOut));

    _detector = AccelerometerDetector(onDistressDetected: _onDistressDetected);

    // ── Receive callbacks FROM Kotlin
    _wakeChannel.setMethodCallHandler(_handleWakeChannelCall);

    _requestPermissionsAndStart();
  }

  // ────────────────────────────────────────
  // Kotlin → Dart callbacks
  // ────────────────────────────────────────
  Future<dynamic> _handleWakeChannelCall(MethodCall call) async {
    switch (call.method) {
      case 'triggered':
        debugPrint('Wake word triggered: ${call.arguments}');
        if (_currentViewState == 'home') _fireSosDirectly();
        break;
      case 'status':
        debugPrint('Wake status: ${call.arguments}');
        break;
      case 'error':
        debugPrint('Wake error: ${call.arguments}');
        break;
    }
  }

  // ── SOS fired by voice — no countdown, immediate
  void _fireSosDirectly() {
    HapticFeedback.heavyImpact();
    triggerSosCall();
    triggerSosEmail();
    _animatePageIn();
    setState(() {
      _currentViewState = 'result_unsafe';
      _wakeState = WakeWordState.triggered;
    });
  }

  void _animatePageIn() { _pageCtrl.reset(); _pageCtrl.forward(); }

  // ────────────────────────────────────────
  // PERMISSIONS + START
  // ────────────────────────────────────────
  Future<void> _requestPermissionsAndStart() async {
    await Permission.microphone.request();
    await Permission.phone.request();
    _startAccelerometer();
    await _startWakeWord();
  }

  // ────────────────────────────────────────
  // WAKE WORD — Dart side just calls Kotlin
  // ────────────────────────────────────────
  Future<void> _startWakeWord() async {
    try {
      final bool available = await _wakeChannel.invokeMethod('isAvailable') ?? false;
      if (!available) { debugPrint('Speech recognition unavailable'); return; }
      await _wakeChannel.invokeMethod('startListening');
      setState(() => _wakeState = WakeWordState.listening);
    } catch (e) { debugPrint('Wake start error: $e'); }
  }

  Future<void> _stopWakeWord() async {
    try {
      await _wakeChannel.invokeMethod('stopListening');
      setState(() => _wakeState = WakeWordState.idle);
    } catch (e) { debugPrint('Wake stop error: $e'); }
  }

  void _toggleWake() async {
    HapticFeedback.lightImpact();
    if (_wakeState == WakeWordState.idle) {
      _wakeEnabled = true;
      await _startWakeWord();
    } else {
      _wakeEnabled = false;
      await _stopWakeWord();
    }
  }

  // ────────────────────────────────────────
  // ACCELEROMETER ONLY (no noise meter)
  // ────────────────────────────────────────
  void _startAccelerometer() {
    _accelSub = userAccelerometerEventStream(
      samplingPeriod: const Duration(milliseconds: 80),
    ).listen((e) {
      _detector.processSample(e.x, e.y, e.z);
    });
  }

  void _onDistressDetected() {
    if (_currentViewState != 'home') return;
    _startCountdown();
  }

  void _startCountdown() {
    _animatePageIn();
    setState(() { _currentViewState = 'timer'; _seconds = 20; });
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        if (_seconds > 0) {
          _seconds--;
        } else {
          _countdownTimer?.cancel();
          _currentViewState = 'result_unsafe';
          triggerSosCall();
          triggerSosEmail();
          _animatePageIn();
        }
      });
    });
  }

  void _markSafe() {
    HapticFeedback.mediumImpact();
    _countdownTimer?.cancel();
    _animatePageIn();
    setState(() => _currentViewState = 'result_safe');
  }

  void _markUnsafe() {
    HapticFeedback.heavyImpact();
    _countdownTimer?.cancel();
    _animatePageIn();
    setState(() => _currentViewState = 'result_unsafe');
    triggerSosCall();
    triggerSosEmail();
  }

  void _extendTime() {
    if (_timeCapped) return;
    HapticFeedback.selectionClick();
    final int next = (_seconds + 10).clamp(0, 60);
    setState(() { _seconds = next; if (_seconds >= 60) _timeCapped = true; });
  }

  void _backToHome() async {
    _countdownTimer?.cancel();
    _detector.reset();
    _animatePageIn();
    setState(() {
      _currentViewState = 'home';
      _seconds          = 20;
      _timeCapped       = false;
      _wakeState        = WakeWordState.idle;
    });
    if (_wakeEnabled) await _startWakeWord();
  }

  @override
  void dispose() {
    _bgCtrl.dispose(); _pulseCtrl.dispose(); _shieldCtrl.dispose();
    _pageCtrl.dispose(); _wakeRingCtrl.dispose();
    _countdownTimer?.cancel();
    _accelSub?.cancel();
    _stopWakeWord();
    _safeLabelCtrl.dispose();
    _unsafeLabelCtrl.dispose();
    super.dispose();
  }

  // ══════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    Widget page;
    if (_currentViewState == 'result_safe')
      page = _SafePage(onBack: _backToHome);
    else if (_currentViewState == 'result_unsafe')
      page = _UnsafePage(onBack: _backToHome);
    else if (_currentViewState == 'timer')
      page = _timerPage();
    else
      page = _homePage();

    return FadeTransition(opacity: _pageAnim, child: page);
  }

  // ──────────────────────────────────────────────────────────────
  // SHARED: animated background
  // ──────────────────────────────────────────────────────────────
  Widget _animatedBg({required Widget child}) {
    return Stack(children: [
      Container(decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft, end: Alignment.bottomRight,
          colors: [_P.bg0, _P.bg1, _P.bg2, _P.bg1],
          stops: [0.0, 0.35, 0.7, 1.0],
        ),
      )),
      AnimatedBuilder(animation: _bgCtrl,
        builder: (_, __) => CustomPaint(
          painter: _ParticlePainter(_bgCtrl.value * 2 * pi, _orbs),
          child: const SizedBox.expand())),
      Container(decoration: BoxDecoration(
        gradient: RadialGradient(
          center: const Alignment(-0.6, -0.7), radius: 1.2,
          colors: [_P.roseDeep.withOpacity(0.18), Colors.transparent]))),
      child,
    ]);
  }

  // ──────────────────────────────────────────────────────────────
  // HOME PAGE
  // ──────────────────────────────────────────────────────────────
  Widget _homePage() {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: _animatedBg(
        child: SafeArea(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: MediaQuery.of(context).size.height -
                    MediaQuery.of(context).padding.top -
                    MediaQuery.of(context).padding.bottom,
              ),
              child: IntrinsicHeight(
                child: Column(children: [
                  const SizedBox(height: 36),
                  _buildHeader(),
                  const SizedBox(height: 28),
                  _buildLabelInputCard(),
                  const SizedBox(height: 20),
                  _buildStatusRow(),
                  const Spacer(),
                  _buildWakeWordSection(),
                  const Spacer(),
                  _buildRateUs(),
                  const SizedBox(height: 28),
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(children: [
      AnimatedBuilder(animation: _shieldAnim,
        builder: (_, __) => Stack(alignment: Alignment.center, children: [
          Container(width: 130, height: 130, decoration: BoxDecoration(shape: BoxShape.circle,
            border: Border.all(color: _P.rose.withOpacity(0.12 + _shieldAnim.value * 0.1), width: 1))),
          Container(width: 112, height: 112, decoration: BoxDecoration(shape: BoxShape.circle,
            border: Border.all(color: _P.rose.withOpacity(0.2 + _shieldAnim.value * 0.15), width: 1.5))),
          Container(width: 92, height: 92,
            decoration: BoxDecoration(shape: BoxShape.circle,
              gradient: RadialGradient(colors: [
                _P.rose.withOpacity(0.28 + _shieldAnim.value * 0.08),
                _P.roseDeep.withOpacity(0.35), _P.bg2,
              ], stops: const [0.0, 0.5, 1.0]),
              border: Border.all(color: _P.roseSoft.withOpacity(0.4 + _shieldAnim.value * 0.25), width: 1.5),
              boxShadow: [
                BoxShadow(color: _P.rose.withOpacity(0.25 + _shieldAnim.value * 0.2), blurRadius: 32, spreadRadius: 4),
                BoxShadow(color: _P.hotPink.withOpacity(0.10), blurRadius: 60, spreadRadius: 12),
              ]),
            child: const Icon(Icons.shield_rounded, color: _P.roseSoft, size: 44)),
        ])),
      const SizedBox(height: 20),
      ShaderMask(
        shaderCallback: (bounds) => const LinearGradient(
          colors: [_P.blush, _P.roseSoft, _P.rosePale],
          begin: Alignment.centerLeft, end: Alignment.centerRight,
        ).createShader(bounds),
        child: Text(kUserName, style: const TextStyle(color: Colors.white, fontSize: 32,
          fontWeight: FontWeight.w700, letterSpacing: 1.5, height: 1))),
      const SizedBox(height: 8),
      Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.location_on_rounded, size: 13, color: _P.rose.withOpacity(0.7)),
        const SizedBox(width: 4),
        Text(kUserCity, style: TextStyle(color: _P.textMid.withOpacity(0.7),
          fontSize: 13, letterSpacing: 1.2, fontWeight: FontWeight.w300)),
      ]),
    ]);
  }

  Widget _buildLabelInputCard() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: _glassCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(width: 3, height: 14,
            decoration: BoxDecoration(color: _P.rose, borderRadius: BorderRadius.circular(2))),
          const SizedBox(width: 10),
          const Text('BUTTON LABELS', style: TextStyle(color: _P.textMid, fontSize: 10,
            fontWeight: FontWeight.w700, letterSpacing: 2.0)),
        ]),
        const SizedBox(height: 18),
        _labelField(ctrl: _safeLabelCtrl, hint: 'e.g. Call Mom',    tag: '"I am safe" label',   dotColor: _P.safe),
        const SizedBox(height: 14),
        _labelField(ctrl: _unsafeLabelCtrl, hint: 'e.g. Order Pizza', tag: '"I am unsafe" label', dotColor: _P.roseSoft),
      ])),
    );
  }

  Widget _labelField({required TextEditingController ctrl, required String hint,
      required String tag, required Color dotColor}) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Container(width: 6, height: 6,
          decoration: BoxDecoration(shape: BoxShape.circle, color: dotColor)),
        const SizedBox(width: 8),
        Text(tag, style: const TextStyle(color: _P.textLow, fontSize: 10.5,
          letterSpacing: 0.6, fontWeight: FontWeight.w500)),
      ]),
      const SizedBox(height: 6),
      TextField(
        controller: ctrl,
        style: const TextStyle(color: _P.textHi, fontSize: 14, fontWeight: FontWeight.w500),
        onChanged: (_) => setState(() {}),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: _P.textLow.withOpacity(0.5), fontSize: 13),
          filled: true, fillColor: Colors.white.withOpacity(0.05), isDense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: _P.glassBorder.withOpacity(0.5), width: 1)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: _P.rose, width: 1.5)),
        ),
      ),
    ]);
  }

  // Status row — no mic pill, just protected + voice status
  Widget _buildStatusRow() {
    return Row(mainAxisAlignment: MainAxisAlignment.center, children: [
      _glowPill(icon: Icons.verified_user_rounded, label: 'PROTECTED', color: _P.safe),
      const SizedBox(width: 10),
      _glowPill(icon: Icons.record_voice_over_rounded,
        label: _wakeState == WakeWordState.listening ? 'VOICE ON' : 'VOICE OFF',
        color: _wakeState == WakeWordState.listening ? _P.wakeActive : _P.textLow),
    ]);
  }

  Widget _glowPill({required IconData icon, required String label, required Color color}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: color.withOpacity(0.3), width: 1)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 11, color: color),
        const SizedBox(width: 5),
        Text(label, style: TextStyle(color: color, fontSize: 10,
          fontWeight: FontWeight.w700, letterSpacing: 1.5)),
      ]),
    );
  }

  Widget _buildWakeWordSection() {
    final bool isOn  = _wakeState == WakeWordState.listening;
    final Color color = isOn ? _P.wakeActive : _P.textLow;
    return Column(children: [
      GestureDetector(
        onTap: _toggleWake,
        child: AnimatedContainer(duration: const Duration(milliseconds: 300),
          width: 86, height: 86,
          decoration: BoxDecoration(shape: BoxShape.circle,
            gradient: isOn
                ? LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight,
                    colors: [_P.wakeActive.withOpacity(0.30), _P.wakeActive.withOpacity(0.10)])
                : const LinearGradient(colors: [Color(0xFF140A00), Color(0xFF0D0500)]),
            border: Border.all(color: color.withOpacity(0.6), width: 1.8),
            boxShadow: isOn
                ? [BoxShadow(color: _P.wakeActive.withOpacity(0.35), blurRadius: 28, spreadRadius: 4)]
                : []),
          child: Icon(isOn ? Icons.record_voice_over_rounded : Icons.voice_over_off_rounded,
            color: color, size: 34)),
      ),
      const SizedBox(height: 12),
      AnimatedSwitcher(duration: const Duration(milliseconds: 300),
        child: Text(
          isOn ? 'Listening — scream "SAMOSA" to trigger SOS' : 'Voice trigger off — tap to enable',
          key: ValueKey(isOn),
          textAlign: TextAlign.center,
          style: TextStyle(color: color.withOpacity(0.75), fontSize: 12, letterSpacing: 0.4))),
    ]);
  }

  Widget _buildRateUs() {
    return GestureDetector(
      onTap: () {},
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 9),
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(30),
          border: Border.all(color: _P.glassBorder, width: 1), color: _P.glass),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.star_rounded, size: 13, color: _P.roseSoft.withOpacity(0.8)),
          const SizedBox(width: 7),
          Text('Rate this app', style: TextStyle(
            color: _P.textMid.withOpacity(0.7), fontSize: 12, letterSpacing: 0.4)),
        ]),
      ),
    );
  }

  Widget _glassCard({required Widget child}) {
    return Container(
      width: double.infinity, padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(20),
        color: Colors.white.withOpacity(0.04),
        border: Border.all(color: _P.glassBorder, width: 1),
        boxShadow: [BoxShadow(color: _P.rose.withOpacity(0.06), blurRadius: 24, spreadRadius: -4)]),
      child: child,
    );
  }

  // ──────────────────────────────────────────────────────────────
  // TIMER PAGE (triggered by accelerometer only)
  // ──────────────────────────────────────────────────────────────
  Widget _timerPage() {
    final double fraction = (_seconds / 20.0).clamp(0.0, 1.0);
    final Color ringColor = Color.lerp(_P.danger, _P.rose, fraction)!;
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: _animatedBg(child: SafeArea(child: Column(children: [
        const SizedBox(height: 32),
        Text('MOTION ALERT', style: TextStyle(color: _P.roseSoft.withOpacity(0.6),
          fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 3)),
        const SizedBox(height: 6),
        const Text('Answer', style: TextStyle(color: _P.textHi, fontSize: 22,
          fontWeight: FontWeight.w300, letterSpacing: 0.5)),
        const Spacer(),
        _TimerRing(seconds: _seconds, fraction: fraction, ringColor: ringColor),
        const Spacer(),
        Padding(padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(children: [
            _timerButton(
              label: _safeLabelCtrl.text.trim().isNotEmpty ? _safeLabelCtrl.text.trim() : 'Call Mom',
              gradient: const LinearGradient(colors: [Color(0xFFB5587A), Color(0xFF8C3A5C)],
                begin: Alignment.topLeft, end: Alignment.bottomRight),
              onTap: _markSafe),
            const SizedBox(height: 12),
            _timerButton(
              label: _unsafeLabelCtrl.text.trim().isNotEmpty ? _unsafeLabelCtrl.text.trim() : 'Order Pizza',
              gradient: const LinearGradient(colors: [Color(0xFF9C4A6A), Color(0xFF7A2E50)],
                begin: Alignment.topLeft, end: Alignment.bottomRight),
              onTap: _markUnsafe),
            const SizedBox(height: 18),
            IgnorePointer(ignoring: _timeCapped,
              child: GestureDetector(onTap: _extendTime,
                child: AnimatedOpacity(duration: const Duration(milliseconds: 250),
                  opacity: _timeCapped ? 0.25 : 1.0,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 8),
                    decoration: BoxDecoration(borderRadius: BorderRadius.circular(30),
                      border: Border.all(color: _P.glassBorder, width: 1), color: _P.glass),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(_timeCapped ? Icons.block : Icons.add, size: 13, color: _P.textLow),
                      const SizedBox(width: 4),
                      Text(_timeCapped ? 'Max 60s reached' : '+10 seconds',
                        style: const TextStyle(color: _P.textLow, fontSize: 12, letterSpacing: 0.5)),
                    ]))))),
          ])),
        const SizedBox(height: 36),
      ]))),
    );
  }

  Widget _timerButton({required String label, required Gradient gradient, required VoidCallback onTap}) {
    return GestureDetector(onTap: onTap,
      child: Container(width: double.infinity, height: 64,
        decoration: BoxDecoration(gradient: gradient, borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: _P.rose.withOpacity(0.2), blurRadius: 16, offset: const Offset(0, 4))]),
        child: Center(child: Text(label, style: const TextStyle(color: Colors.white,
          fontSize: 18, fontWeight: FontWeight.w600, letterSpacing: 0.3)))));
  }
}

// ──────────────────────────────────────────────────────────────
// TIMER RING
// ──────────────────────────────────────────────────────────────
class _TimerRing extends StatelessWidget {
  final int seconds; final double fraction; final Color ringColor;
  const _TimerRing({required this.seconds, required this.fraction, required this.ringColor});

  @override
  Widget build(BuildContext context) {
    return SizedBox(width: 200, height: 200,
      child: Stack(alignment: Alignment.center, children: [
        CustomPaint(size: const Size(200, 200),
          painter: _RingPainter(fraction: fraction, color: ringColor)),
        Column(mainAxisSize: MainAxisSize.min, children: [
          ShaderMask(
            shaderCallback: (b) => LinearGradient(
              colors: [ringColor, Colors.white],
              begin: Alignment.topCenter, end: Alignment.bottomCenter).createShader(b),
            child: Text('$seconds', style: const TextStyle(color: Colors.white,
              fontSize: 76, fontWeight: FontWeight.w200, height: 1, letterSpacing: -2))),
          Text('seconds', style: TextStyle(color: _P.textLow.withOpacity(0.7),
            fontSize: 11, letterSpacing: 2, fontWeight: FontWeight.w400)),
        ]),
      ]));
  }
}

class _RingPainter extends CustomPainter {
  final double fraction; final Color color;
  const _RingPainter({required this.fraction, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 10;
    const strokeW = 5.0;
    canvas.drawCircle(center, radius,
      Paint()..color = color.withOpacity(0.12)..style = PaintingStyle.stroke..strokeWidth = strokeW);
    final sweep = 2 * pi * fraction;
    canvas.drawArc(Rect.fromCircle(center: center, radius: radius), -pi / 2, sweep, false,
      Paint()..color = color..style = PaintingStyle.stroke..strokeWidth = strokeW
        ..strokeCap = StrokeCap.round
        ..shader = SweepGradient(startAngle: 0, endAngle: sweep,
          transform: const GradientRotation(-pi / 2),
          colors: [color.withOpacity(0.4), color]).createShader(
            Rect.fromCircle(center: center, radius: radius)));
    if (fraction > 0.02) {
      final angle = -pi / 2 + sweep;
      final dotCenter = Offset(center.dx + radius * cos(angle), center.dy + radius * sin(angle));
      canvas.drawCircle(dotCenter, 5, Paint()..color = color..style = PaintingStyle.fill);
      canvas.drawCircle(dotCenter, 5, Paint()..color = Colors.white.withOpacity(0.4)
        ..style = PaintingStyle.stroke..strokeWidth = 1.5);
    }
  }
  @override bool shouldRepaint(_RingPainter old) => old.fraction != fraction || old.color != color;
}

// ──────────────────────────────────────────────────────────────
// SAFE PAGE
// ──────────────────────────────────────────────────────────────
class _SafePage extends StatefulWidget {
  final VoidCallback onBack;
  const _SafePage({required this.onBack});
  @override State<_SafePage> createState() => _SafePageState();
}
class _SafePageState extends State<_SafePage> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale, _fade;
  @override void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 700))..forward();
    _scale = CurvedAnimation(parent: _ctrl, curve: Curves.elasticOut);
    _fade  = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
  }
  @override void dispose() { _ctrl.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    return Scaffold(backgroundColor: _P.bg0,
      body: Stack(children: [
        Positioned.fill(child: Container(decoration: BoxDecoration(gradient: RadialGradient(
          center: Alignment.center, radius: 0.9,
          colors: [_P.safe.withOpacity(0.10), Colors.transparent])))),
        FadeTransition(opacity: _fade, child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
          ScaleTransition(scale: _scale,
            child: Container(width: 110, height: 110,
              decoration: BoxDecoration(shape: BoxShape.circle, color: _P.safe.withOpacity(0.12),
                border: Border.all(color: _P.safe.withOpacity(0.5), width: 2),
                boxShadow: [BoxShadow(color: _P.safe.withOpacity(0.3), blurRadius: 40, spreadRadius: 4)]),
              child: const Icon(Icons.check_rounded, color: _P.safe, size: 56))),
          const SizedBox(height: 32),
          const Text('YOU ARE SAFE', style: TextStyle(color: _P.safe, fontSize: 28,
            fontWeight: FontWeight.w700, letterSpacing: 3)),
          const SizedBox(height: 10),
          Text('Protection is still active',
            style: TextStyle(color: _P.textMid.withOpacity(0.5), fontSize: 14, letterSpacing: 0.5)),
          const SizedBox(height: 48),
          _actionButton(label: 'Return to home', color: _P.safe, onTap: widget.onBack),
        ]))),
      ]));
  }
}

// ──────────────────────────────────────────────────────────────
// UNSAFE / SOS PAGE
// ──────────────────────────────────────────────────────────────
class _UnsafePage extends StatefulWidget {
  final VoidCallback onBack;
  const _UnsafePage({required this.onBack});
  @override State<_UnsafePage> createState() => _UnsafePageState();
}
class _UnsafePageState extends State<_UnsafePage> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _pulse;
  @override void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..repeat(reverse: true);
    _pulse = Tween<double>(begin: 0.9, end: 1.08).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }
  @override void dispose() { _ctrl.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    return Scaffold(backgroundColor: const Color(0xFF0D0003),
      body: Stack(children: [
        Positioned.fill(child: AnimatedBuilder(animation: _pulse,
          builder: (_, __) => Container(decoration: BoxDecoration(gradient: RadialGradient(
            center: Alignment.center, radius: _pulse.value,
            colors: [_P.danger.withOpacity(0.14), Colors.transparent]))))),
        SizedBox.expand(child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
          AnimatedBuilder(animation: _pulse,
            builder: (_, __) => Transform.scale(scale: _pulse.value,
              child: Container(width: 110, height: 110,
                decoration: BoxDecoration(shape: BoxShape.circle, color: _P.danger.withOpacity(0.12),
                  border: Border.all(color: _P.danger.withOpacity(0.6), width: 2),
                  boxShadow: [BoxShadow(color: _P.danger.withOpacity(0.35), blurRadius: 40, spreadRadius: 4)]),
                child: const Icon(Icons.warning_amber_rounded, color: _P.danger, size: 56)))),
          const SizedBox(height: 32),
          const Text('SOS ACTIVATED', style: TextStyle(color: _P.danger, fontSize: 28,
            fontWeight: FontWeight.w700, letterSpacing: 3)),
          const SizedBox(height: 24),
          ...[
            (Icons.phone_in_talk_rounded,        'Emergency call placed'),
            (Icons.email_rounded,                'Alert email sent'),
            (Icons.location_on_rounded,          'Location shared in email'),
            (Icons.notifications_active_rounded, 'Contacts alerted'),
          ].map((e) => Padding(padding: const EdgeInsets.symmetric(vertical: 5),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(e.$1, size: 15, color: _P.danger.withOpacity(0.8)),
              const SizedBox(width: 8),
              Text(e.$2, style: TextStyle(color: _P.textMid.withOpacity(0.6), fontSize: 14)),
            ]))),
          const SizedBox(height: 48),
          _actionButton(label: 'Reset system', color: _P.danger, onTap: widget.onBack),
        ]))),
      ]));
  }
}

// ──────────────────────────────────────────────────────────────
// SHARED WIDGETS
// ──────────────────────────────────────────────────────────────
Widget _actionButton({required String label, required Color color, required VoidCallback onTap}) {
  return GestureDetector(onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 14),
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(30),
        border: Border.all(color: color.withOpacity(0.4), width: 1.5),
        color: color.withOpacity(0.08)),
      child: Text(label, style: TextStyle(color: color, fontSize: 14,
        fontWeight: FontWeight.w600, letterSpacing: 1))));
}