/// TODO: Phase 3 — real authentication.
///
/// The seam is already there. `currentUserProvider` resolves the acting member
/// from a `meta` row rather than from a constant, and every movement and price
/// change is stamped with that person's name — so signing somebody in becomes a
/// write to that row rather than a change to everything that stamps.
class AuthService {}
