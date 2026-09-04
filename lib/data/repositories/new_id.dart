import 'package:uuid/uuid.dart';

const Uuid _uuid = Uuid();

/// An id for a record created by the app.
///
/// UUID v4. Phase 1 handed out `item-new-7` from a counter that reset with the
/// process, which was fine while nothing survived a restart and collides the
/// moment data does.
///
/// No type prefix. The seeded records keep their readable slugs — `item-tomates`
/// is worth having in a debug dump — but a generated id is opaque either way,
/// and prefixing it would make it look parseable when nothing parses it.
String newId() => _uuid.v4();
