import 'package:flutter/material.dart';

import '../../../../shared/widgets/widgets.dart';
import 'item_detail_view.dart';

/// Opens a product's detail as a panel over whatever screen asked for it.
///
/// Every list in the app that names a product goes through here: the
/// catalogue, the dashboard's activity feed and alerts panel, the alerts
/// screen, the notification feed and the movement history. They used to push
/// `Routes.toItem` instead, which took the user off the list they were working
/// through — and coming back meant a navigation they had to undo. A panel
/// closes onto the row they tapped, scroll position and all.
///
/// One function rather than six copies, for the reason the catalogue's own
/// comment already gave about its two views: they cannot drift apart if there
/// is only one of them. The width is part of that — a product read at 560dp in
/// one screen and 440 in another is the same drift in a different currency.
///
/// **The route stays.** `Routes.toItem` is still how a deep link, a
/// notification opened from outside the app, or a test reaches a product. This
/// replaces the in-app taps only.
///
/// [ItemDetailView] carries its own header and its own Modifier / Supprimer
/// buttons here, because the panel has no page header to put them in. Links
/// inside it close the panel before they navigate — `DrawerScope` in
/// `app/navigation.dart` does that for every drawer, so nothing here has to
/// know it is in one.
Future<void> openProductDrawer(
  BuildContext context, {
  required String storeId,
  required String itemId,
}) {
  return DetailDrawer.showCustom(
    context,
    width: 560,
    builder: (drawerContext) => ItemDetailView(
      itemId: itemId,
      storeId: storeId,
      onClose: () => Navigator.of(drawerContext).pop(),
    ),
  );
}
