/// The signed-in user — a Phase 1 teardown stub.
///
/// The old `mockCurrentUser` was a `TeamMember` from `mock_team.dart`, removed
/// with the rest of the Équipe module (see
/// `.claude/phase_gestion_employee.md`, Phase 1). Phase 2 replaces this with a
/// real `Employee` (`mockCurrentEmployee`, role owner); Phase 6 makes it the
/// result of an actual login. Until then it is two constants — enough for the
/// top-bar avatar and the dashboard greeting, which are the only things that
/// read it.
const String mockSignedInFullName = 'Marc Delvaux';

const String mockSignedInEmail = 'marc.delvaux@brasserie-sablon.be';
