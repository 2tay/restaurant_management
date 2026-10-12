import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../l10n/app_localizations.dart';
import 'barcode_support.dart';

/// What became of one code seen by the camera, for the strip at the bottom of
/// the viewfinder.
class ScanOutcome {
  const ScanOutcome.added(this.message) : kind = ScanOutcomeKind.added;

  /// Nothing has this code. Closes the camera, handing the code back, so the
  /// screen underneath can offer to create the product or link it — that
  /// takes a form, and a form does not belong over a viewfinder.
  const ScanOutcome.unknown() : message = null, kind = ScanOutcomeKind.unknown;

  /// Seen, and turned down — "pas dans cette commande".
  const ScanOutcome.refused(this.message) : kind = ScanOutcomeKind.refused;

  /// The person backed out of a question the scan asked.
  const ScanOutcome.cancelled() : message = null, kind = ScanOutcomeKind.none;

  final String? message;
  final ScanOutcomeKind kind;
}

enum ScanOutcomeKind { added, unknown, refused, none }

/// The full-screen viewfinder.
///
/// [scanOnce] for a field — the first code read closes it and is returned.
/// [scanContinuous] for a delivery: it stays open, every product read goes
/// through `onCode` and says what happened in the strip at the bottom, and
/// « Terminer » closes it.
///
/// Pushed on the root navigator, above the shell, so it is the whole screen
/// on a phone, sidebar and all.
abstract final class BarcodeCameraPage {
  static Future<String?> scanOnce(BuildContext context) {
    return Navigator.of(context, rootNavigator: true).push<String>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => const _CameraView(onCode: null),
      ),
    );
  }

  /// Returns the code that closed the camera because nothing has it, or null
  /// when the person closed it themselves.
  static Future<String?> scanContinuous(
    BuildContext context, {
    required Future<ScanOutcome> Function(String code) onCode,
  }) {
    return Navigator.of(context, rootNavigator: true).push<String>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => _CameraView(onCode: onCode),
      ),
    );
  }
}

class _CameraView extends StatefulWidget {
  const _CameraView({required this.onCode});

  /// Null for a single scan.
  final Future<ScanOutcome> Function(String code)? onCode;

  @override
  State<_CameraView> createState() => _CameraViewState();
}

/// How long a code has to be out of sight before seeing it again counts as a
/// second scan. Holding a tin in front of the camera reads it four times a
/// second; it is one tin until it is taken away and shown again.
const Duration _rescanGap = Duration(milliseconds: 1200);

class _CameraViewState extends State<_CameraView> {
  final MobileScannerController _controller = MobileScannerController(
    formats: const [
      BarcodeFormat.ean13,
      BarcodeFormat.ean8,
      BarcodeFormat.upcA,
      BarcodeFormat.upcE,
      BarcodeFormat.code128,
      BarcodeFormat.code39,
      BarcodeFormat.code93,
      BarcodeFormat.itf14,
      BarcodeFormat.codabar,
      BarcodeFormat.dataMatrix,
      BarcodeFormat.qrCode,
    ],
  );

  /// When each code was last in the frame.
  final Map<String, DateTime> _lastSeen = {};

  bool _busy = false;
  bool _closed = false;
  int _count = 0;
  ScanOutcome? _last;
  Timer? _clearLast;

  @override
  void dispose() {
    _clearLast?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _close([String? result]) {
    if (_closed) return;
    _closed = true;
    Navigator.of(context).pop(result);
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_closed) return;
    final now = DateTime.now();
    String? fresh;
    for (final barcode in capture.barcodes) {
      final code = barcode.rawValue?.trim();
      if (code == null || code.isEmpty) continue;
      final seen = _lastSeen[code];
      _lastSeen[code] = now;
      if (fresh == null &&
          (seen == null || now.difference(seen) > _rescanGap)) {
        fresh = code;
      }
    }
    if (fresh == null || _busy) return;

    final onCode = widget.onCode;
    if (onCode == null) {
      scanFeedback();
      _close(fresh);
      return;
    }

    setState(() => _busy = true);
    final outcome = await onCode(fresh);
    if (!mounted) return;
    // Whatever the question took, the code is still in front of the lens:
    // start its gap from now so it is not read again on the way out.
    _lastSeen[fresh] = DateTime.now();

    if (outcome.kind == ScanOutcomeKind.unknown) {
      scanMissFeedback();
      _close(fresh);
      return;
    }
    if (outcome.kind == ScanOutcomeKind.added) {
      scanFeedback();
      _count++;
    } else if (outcome.kind == ScanOutcomeKind.refused) {
      scanMissFeedback();
    }
    setState(() {
      _busy = false;
      if (outcome.message != null) _last = outcome;
    });
    _clearLast?.cancel();
    _clearLast = Timer(const Duration(seconds: 3), () {
      if (mounted) setState(() => _last = null);
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final continuous = widget.onCode != null;

    return Scaffold(
      backgroundColor: Colors.black,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final side = (constraints.maxWidth * 0.78).clamp(220.0, 420.0);
          final window = Rect.fromCenter(
            center: constraints.biggest.center(Offset.zero),
            width: side,
            height: side * 0.62,
          );

          return Stack(
            fit: StackFit.expand,
            children: [
              MobileScanner(
                controller: _controller,
                onDetect: _onDetect,
                scanWindow: window,
                errorBuilder: (context, error) => _CameraError(error: error),
              ),
              IgnorePointer(
                child: CustomPaint(painter: _WindowPainter(window)),
              ),

              // The top bar: close, what to do, the torch and the other lens.
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  child: Row(
                    children: [
                      _RoundButton(
                        icon: LucideIcons.x,
                        tooltip: MaterialLocalizations.of(
                          context,
                        ).closeButtonTooltip,
                        onPressed: () => _close(),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Text(
                          l10n.scanCameraTitle,
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: Colors.white,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      ValueListenableBuilder<MobileScannerState>(
                        valueListenable: _controller,
                        builder: (context, state, _) => _RoundButton(
                          icon: state.torchState == TorchState.on
                              ? LucideIcons.flashlightOff
                              : LucideIcons.flashlight,
                          tooltip: l10n.scanTorch,
                          onPressed: state.torchState == TorchState.unavailable
                              ? null
                              : _controller.toggleTorch,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      _RoundButton(
                        icon: LucideIcons.switchCamera,
                        tooltip: l10n.scanSwitchCamera,
                        onPressed: _controller.switchCamera,
                      ),
                    ],
                  ),
                ),
              ),

              // Under the window: what to do, then what just happened.
              Positioned(
                left: AppSpacing.lg,
                right: AppSpacing.lg,
                top: window.bottom + AppSpacing.lg,
                child: Text(
                  continuous
                      ? l10n.scanCameraContinuousHint
                      : l10n.scanCameraHint,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: Colors.white.withValues(alpha: 0.85),
                  ),
                ),
              ),

              if (continuous)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: SafeArea(
                    top: false,
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 200),
                            child: _last == null
                                ? const SizedBox(height: 48)
                                : _OutcomeStrip(
                                    key: ValueKey(_last),
                                    outcome: _last!,
                                  ),
                          ),
                          const SizedBox(height: AppSpacing.md),
                          FilledButton.icon(
                            onPressed: () => _close(),
                            icon: const Icon(LucideIcons.check),
                            label: Text(
                              _count == 0
                                  ? l10n.scanDone
                                  : '${l10n.scanDone} · ${l10n.scanCount(_count)}',
                            ),
                            style: FilledButton.styleFrom(
                              minimumSize: const Size.fromHeight(
                                AppSizing.buttonHeight,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

/// "+1 · Coca 33cl" in green, or why a code was turned down in amber.
class _OutcomeStrip extends StatelessWidget {
  const _OutcomeStrip({required this.outcome, super.key});

  final ScanOutcome outcome;

  @override
  Widget build(BuildContext context) {
    final added = outcome.kind == ScanOutcomeKind.added;
    final colors = added ? AppColors.inStock : AppColors.lowStock;

    return Container(
      constraints: const BoxConstraints(minHeight: 48),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      decoration: BoxDecoration(
        color: colors.container,
        borderRadius: AppRadius.mdAll,
      ),
      child: Row(
        children: [
          Icon(
            added ? LucideIcons.circleCheck : LucideIcons.triangleAlert,
            size: AppSizing.iconMd,
            color: colors.solid,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              outcome.message ?? '',
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(color: colors.foreground),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _RoundButton extends StatelessWidget {
  const _RoundButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton.filled(
      tooltip: tooltip,
      onPressed: onPressed,
      icon: Icon(icon, size: AppSizing.iconMd),
      style: IconButton.styleFrom(
        backgroundColor: Colors.black.withValues(alpha: 0.45),
        foregroundColor: Colors.white,
        disabledBackgroundColor: Colors.black.withValues(alpha: 0.25),
        disabledForegroundColor: Colors.white38,
        minimumSize: const Size.square(AppSizing.minTapTarget),
      ),
    );
  }
}

/// Darkens everything but the scan window, and draws its corners.
class _WindowPainter extends CustomPainter {
  const _WindowPainter(this.window);

  final Rect window;

  @override
  void paint(Canvas canvas, Size size) {
    final rounded = RRect.fromRectAndRadius(window, const Radius.circular(16));
    canvas.drawPath(
      Path.combine(
        PathOperation.difference,
        Path()..addRect(Offset.zero & size),
        Path()..addRRect(rounded),
      ),
      Paint()..color = Colors.black.withValues(alpha: 0.55),
    );

    final corner = Paint()
      ..color = Colors.white
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    const len = 28.0;
    final r = window;
    for (final (x, y, dx, dy) in [
      (r.left, r.top, 1.0, 1.0),
      (r.right, r.top, -1.0, 1.0),
      (r.left, r.bottom, 1.0, -1.0),
      (r.right, r.bottom, -1.0, -1.0),
    ]) {
      canvas.drawLine(Offset(x, y + dy * 4), Offset(x, y + dy * len), corner);
      canvas.drawLine(Offset(x + dx * 4, y), Offset(x + dx * len, y), corner);
    }
  }

  @override
  bool shouldRepaint(_WindowPainter oldDelegate) =>
      oldDelegate.window != window;
}

/// Why there is no picture: the permission, or no camera at all.
class _CameraError extends StatelessWidget {
  const _CameraError({required this.error});

  final MobileScannerException error;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final denied = error.errorCode == MobileScannerErrorCode.permissionDenied;

    return ColoredBox(
      color: Colors.black,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                LucideIcons.cameraOff,
                size: 48,
                color: Colors.white70,
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                denied ? l10n.scanPermissionDenied : l10n.scanCameraUnavailable,
                textAlign: TextAlign.center,
                style: Theme.of(
                  context,
                ).textTheme.bodyLarge?.copyWith(color: Colors.white),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
