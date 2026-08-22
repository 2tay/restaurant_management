import '../models/team_member.dart';
import 'mock_reference.dart';
import 'mock_stores.dart';

/// The signed-in user, for the top-bar avatar and account settings.
final TeamMember mockCurrentUser = mockTeam.first;

final List<TeamMember> mockTeam = [
  TeamMember(
    id: 'user-marc',
    fullName: 'Marc Delvaux',
    email: 'marc.delvaux@brasserie-sablon.be',
    role: TeamRole.owner,
    storeIds: [StoreIds.sablon, StoreIds.liege, StoreIds.saintGilles],
    isActive: true,
    invitedAt: monthsAgo(38),
    lastActiveAt: hoursAgo(1),
  ),
  TeamMember(
    id: 'user-amelie',
    fullName: 'Amélie Vandenberghe',
    email: 'amelie.v@brasserie-sablon.be',
    role: TeamRole.manager,
    storeIds: [StoreIds.sablon],
    isActive: true,
    invitedAt: monthsAgo(22),
    lastActiveAt: hoursAgo(3),
  ),
  TeamMember(
    id: 'user-youssef',
    fullName: 'Youssef El Amrani',
    email: 'youssef.elamrani@comptoir-liege.be',
    role: TeamRole.manager,
    storeIds: [StoreIds.liege],
    isActive: true,
    invitedAt: monthsAgo(13),
    lastActiveAt: daysAgo(1),
  ),
  TeamMember(
    id: 'user-sophie',
    fullName: 'Sophie Lemmens',
    email: 'sophie.lemmens@brasserie-sablon.be',
    role: TeamRole.staff,
    storeIds: [StoreIds.sablon],
    isActive: true,
    invitedAt: monthsAgo(9),
    lastActiveAt: hoursAgo(5),
  ),
  TeamMember(
    id: 'user-thomas',
    fullName: 'Thomas Peeters',
    email: 'thomas.peeters@brasserie-sablon.be',
    role: TeamRole.staff,
    storeIds: [StoreIds.sablon],
    isActive: true,
    invitedAt: monthsAgo(5),
    lastActiveAt: daysAgo(2),
  ),
  TeamMember(
    id: 'user-lucas',
    fullName: 'Lucas Ferreira',
    email: 'lucas.ferreira@comptoir-liege.be',
    role: TeamRole.staff,
    storeIds: [StoreIds.liege],
    isActive: true,
    invitedAt: monthsAgo(4),
    lastActiveAt: daysAgo(3),
  ),

  // Invitation sent, not yet accepted. The team list needs a pending row so
  // that state is designed rather than discovered later.
  TeamMember(
    id: 'user-nadia',
    fullName: 'Nadia Bouzid',
    email: 'nadia.bouzid@comptoir-liege.be',
    role: TeamRole.staff,
    storeIds: [StoreIds.liege],
    isActive: false,
    invitedAt: daysAgo(3),
  ),
];
