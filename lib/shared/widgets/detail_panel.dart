import 'package:flutter/material.dart';

import 'detail_drawer.dart';

/// Builds one panel's content, given the controller it can navigate with.
typedef PanelBuilder = Widget Function(
  BuildContext context,
  PanelController panel,
);

/// What a panel's content can do to the panel it is in.
///
/// Handed to every [PanelBuilder] so a view never has to know whether it is in
/// a panel, a page or a pane — it asks for what it wants and the host decides
/// whether that is possible.
abstract class PanelController {
  /// Walks forward to another panel, keeping the way back.
  void open(PanelBuilder builder);

  /// Returns to the panel underneath. Does nothing at the first one.
  void back();

  /// Dismisses the whole panel.
  void close();

  /// Whether [back] leads anywhere — which is what decides between drawing a
  /// back arrow and drawing nothing.
  bool get canGoBack;
}

/// A slide-in panel whose content can walk to another panel and back.
///
/// **One panel, not a stack of them.** A réception opened from inside a
/// commande replaces what the panel is showing and grows a back arrow, the way
/// a phone's navigation drawer moves between levels. Sliding a second panel
/// over the first would pile up scrims, and on a phone — where a panel is
/// already full width — the one underneath is invisible anyway, so the stack
/// would be a cost with nothing to show for it.
///
/// The back arrow lives in the content, not in a frame around it, because each
/// view already draws its own header: the arrow belongs where the close button
/// is, and only the view knows where that is.
Future<void> showDetailPanel(
  BuildContext context, {
  required PanelBuilder builder,
  double width = 560,
}) {
  return DetailDrawer.showCustom(
    context,
    width: width,
    builder: (drawerContext) => _PanelHost(
      first: builder,
      onClose: () => Navigator.of(drawerContext).pop(),
    ),
  );
}

class _PanelHost extends StatefulWidget {
  const _PanelHost({required this.first, required this.onClose});

  final PanelBuilder first;
  final VoidCallback onClose;

  @override
  State<_PanelHost> createState() => _PanelHostState();
}

class _PanelHostState extends State<_PanelHost> implements PanelController {
  late final List<PanelBuilder> _stack = [widget.first];

  @override
  bool get canGoBack => _stack.length > 1;

  @override
  void open(PanelBuilder builder) => setState(() => _stack.add(builder));

  @override
  void back() {
    if (!canGoBack) return;
    setState(() => _stack.removeLast());
  }

  @override
  void close() => widget.onClose();

  @override
  Widget build(BuildContext context) {
    // Keyed by depth so moving between panels rebuilds the subtree rather than
    // trying to reuse one view's state for the next one's content.
    return KeyedSubtree(
      key: ValueKey(_stack.length),
      child: _stack.last(context, this),
    );
  }
}
