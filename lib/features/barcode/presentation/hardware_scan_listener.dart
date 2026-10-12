import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// Catches a handheld barcode scanner — USB or Bluetooth — on the screen it
/// wraps, with nothing focused and no button to press.
///
/// Such a scanner is a keyboard: it types the code very fast and ends it with
/// Enter (some with Tab, some with nothing). Typed into a focused text field,
/// that already works — the field gets the code. This covers the moment
/// nothing is focused, which on a delivery is most of the time: the person
/// put the tablet down and picked up the scanner.
///
/// Told apart from a person typing by speed alone: every key of the burst
/// within [_maxGap] of the one before, and at least [_minLength] of them. A
/// person does not type 13 digits at 30ms apiece.
///
/// Stands aside whenever a text field has focus (the field gets the keys, as
/// above) and whenever its route is not the top one (a dialog over the page
/// is somebody else's keyboard). Nothing is swallowed except the Enter that
/// ends a scan, which would otherwise press whatever button had focus.
class HardwareScanListener extends StatefulWidget {
  const HardwareScanListener({
    required this.onScan,
    required this.child,
    this.enabled = true,
    super.key,
  });

  final ValueChanged<String> onScan;
  final Widget child;
  final bool enabled;

  @override
  State<HardwareScanListener> createState() => _HardwareScanListenerState();
}

/// The longest pause between two keys of one scan.
const Duration _maxGap = Duration(milliseconds: 60);

/// How long a burst may sit unfinished before it counts as a scan without a
/// terminator.
const Duration _idleEnd = Duration(milliseconds: 120);

/// The shortest code taken as a scan — EAN-8 is the shortest retail one.
const int _minLength = 6;

class _HardwareScanListenerState extends State<HardwareScanListener> {
  final StringBuffer _buffer = StringBuffer();
  DateTime? _lastKey;
  Timer? _idle;

  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_onKey);
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_onKey);
    _idle?.cancel();
    super.dispose();
  }

  bool get _listening {
    if (!widget.enabled || !mounted) return false;
    if (!(ModalRoute.of(context)?.isCurrent ?? true)) return false;
    final focused = FocusManager.instance.primaryFocus?.context;
    if (focused == null) return true;
    // The focus node of a text field lives under its EditableText.
    if (focused.widget is EditableText) return false;
    return focused.findAncestorWidgetOfExactType<EditableText>() == null;
  }

  void _reset() {
    _buffer.clear();
    _lastKey = null;
    _idle?.cancel();
  }

  bool _finish() {
    final code = _buffer.toString().trim();
    _reset();
    if (code.length < _minLength) return false;
    widget.onScan(code);
    return true;
  }

  bool _onKey(KeyEvent event) {
    if (event is! KeyDownEvent) return false;
    if (!_listening) {
      _reset();
      return false;
    }

    final now = DateTime.now();
    final last = _lastKey;
    if (last != null && now.difference(last) > _maxGap) _buffer.clear();

    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.numpadEnter ||
        key == LogicalKeyboardKey.tab) {
      // Only a burst that is still going: an Enter long after the last digit
      // is a person pressing Enter.
      if (last == null || now.difference(last) > _maxGap) {
        _reset();
        return false;
      }
      return _finish();
    }

    final character = event.character;
    if (character == null ||
        character.length != 1 ||
        character.codeUnitAt(0) < 0x20) {
      return false;
    }
    _buffer.write(character);
    _lastKey = now;
    _idle?.cancel();
    _idle = Timer(_idleEnd, _finish);
    return false;
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
