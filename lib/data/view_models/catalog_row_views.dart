import '../../models/category.dart';
import '../../models/unit_of_measure.dart';

/// A category with the number of articles filed under it.
///
/// The count is the whole reason the row is a view model. It decides what the
/// row says *and* whether the delete button is allowed to proceed, so a page
/// that reads it per row reads it twice per row — once to draw and once to
/// check. One `GROUP BY` answers it for every row at once.
class CategoryRowView {
  const CategoryRowView({required this.category, required this.itemCount});

  final Category category;

  /// Articles in this category. Above zero, deleting is refused rather than
  /// warned about: articles reference their category by id, so removing one
  /// underneath them would leave those articles rendering as a dash.
  final int itemCount;
}

/// A unit with the number of articles measured in it.
class UnitRowView {
  const UnitRowView({required this.unit, required this.itemCount});

  final UnitOfMeasure unit;
  final int itemCount;
}
