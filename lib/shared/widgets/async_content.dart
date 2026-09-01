import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'error_state.dart';
import 'loading_state.dart';

/// Renders one query's [AsyncValue] the way every screen in this app renders
/// one.
///
/// The house rule, in one place so twenty-three screens do not each invent it:
///
/// - **data** → the screen, built by [builder];
/// - **loading** → [skeleton], shaped like the content that is coming. Not a
///   spinner: `loading_state.dart` explains why, and the whole point of having
///   designed skeletons is that nothing moves when the data lands;
/// - **error** → [ErrorState] with a retry, because an error screen that is
///   only an apology leaves somebody mid-service with nothing to do.
///
/// Retry is a callback rather than something this widget works out for itself.
/// It cannot: it is handed a value, not the provider behind it, and Riverpod's
/// `invalidate` needs the provider. The call site writes
/// `onRetry: () => ref.invalidate(itemsProvider(storeId))`, which is one line
/// and says which query is being retried — worth more than the line it saves.
///
/// A screen watching several queries should combine them with [asyncAll2] and
/// friends and wrap the result in **one** of these. Four independent `.when`s
/// give four skeletons resolving at four different moments, which reads as a
/// page assembling itself rather than a page loading.
class AsyncContent<T> extends StatelessWidget {
  const AsyncContent({
    required this.value,
    required this.builder,
    this.skeleton,
    this.onRetry,
    this.errorTitle,
    this.errorMessage,
    super.key,
  });

  final AsyncValue<T> value;
  final Widget Function(BuildContext context, T data) builder;

  /// What stands in while the query runs. Defaults to [SkeletonList], which is
  /// right for most screens here and wrong for the grids — pass
  /// [SkeletonGrid] there.
  final Widget? skeleton;

  final VoidCallback? onRetry;
  final String? errorTitle;
  final String? errorMessage;

  @override
  Widget build(BuildContext context) {
    return value.when(
      data: (data) => builder(context, data),
      // A rebuild that already has data keeps showing it rather than flashing
      // the skeleton — `skipLoadingOnReload` is what stops a live drift stream
      // blinking the whole screen every time somebody else writes a row.
      skipLoadingOnReload: true,
      loading: () => skeleton ?? const SkeletonList(),
      error: (error, stackTrace) => ErrorState(
        title: errorTitle,
        message: errorMessage,
        onRetry: onRetry,
      ),
    );
  }
}

/// A query that resolved to nothing, when nothing is a legitimate answer.
///
/// The pairing this app needs constantly: a list screen wants a skeleton while
/// loading, an `EmptyState` when the establishment genuinely has no articles,
/// and the list otherwise. Writing that as `AsyncContent` plus an `isEmpty`
/// check at every call site is three lines of the same decision each time.
class AsyncListContent<T> extends StatelessWidget {
  const AsyncListContent({
    required this.value,
    required this.builder,
    required this.empty,
    this.skeleton,
    this.onRetry,
    super.key,
  });

  final AsyncValue<List<T>> value;
  final Widget Function(BuildContext context, List<T> items) builder;

  /// Shown when the query succeeded and returned nothing.
  final Widget empty;

  final Widget? skeleton;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return AsyncContent<List<T>>(
      value: value,
      skeleton: skeleton,
      onRetry: onRetry,
      builder: (context, items) =>
          items.isEmpty ? empty : builder(context, items),
    );
  }
}

// -----------------------------------------------------------------------------
// Combining
// -----------------------------------------------------------------------------
//
// A screen that needs four figures watches four providers, and until all four
// have arrived it has nothing to draw. These fold several [AsyncValue]s into
// one so the screen makes a single decision.
//
// **Error wins over loading.** If any query failed, the screen shows the error
// rather than a skeleton that will never resolve — a page that keeps loading
// forever is the worst of the three states, because it tells the user to wait
// for something that is not coming.

AsyncValue<R> asyncAll2<A, B, R>(
  AsyncValue<A> a,
  AsyncValue<B> b,
  R Function(A a, B b) combine,
) {
  final failure = _firstError([a, b]);
  if (failure != null) return failure.cast<R>();
  if (a.hasValue && b.hasValue) {
    return AsyncValue<R>.data(combine(a.requireValue, b.requireValue));
  }
  return const AsyncValue<Never>.loading().cast<R>();
}

AsyncValue<R> asyncAll3<A, B, C, R>(
  AsyncValue<A> a,
  AsyncValue<B> b,
  AsyncValue<C> c,
  R Function(A a, B b, C c) combine,
) {
  final failure = _firstError([a, b, c]);
  if (failure != null) return failure.cast<R>();
  if (a.hasValue && b.hasValue && c.hasValue) {
    return AsyncValue<R>.data(
      combine(a.requireValue, b.requireValue, c.requireValue),
    );
  }
  return const AsyncValue<Never>.loading().cast<R>();
}

AsyncValue<R> asyncAll4<A, B, C, D, R>(
  AsyncValue<A> a,
  AsyncValue<B> b,
  AsyncValue<C> c,
  AsyncValue<D> d,
  R Function(A a, B b, C c, D d) combine,
) {
  final failure = _firstError([a, b, c, d]);
  if (failure != null) return failure.cast<R>();
  if (a.hasValue && b.hasValue && c.hasValue && d.hasValue) {
    return AsyncValue<R>.data(
      combine(
        a.requireValue,
        b.requireValue,
        c.requireValue,
        d.requireValue,
      ),
    );
  }
  return const AsyncValue<Never>.loading().cast<R>();
}

/// The first of these that failed, if any did.
AsyncError<Never>? _firstError(List<AsyncValue<Object?>> values) {
  for (final value in values) {
    if (value case AsyncError(:final error, :final stackTrace)) {
      return AsyncError<Never>(error, stackTrace);
    }
  }
  return null;
}

/// Re-types an [AsyncValue] that carries no value — a loading or an error.
extension on AsyncValue<Never> {
  AsyncValue<R> cast<R>() => switch (this) {
    AsyncError(:final error, :final stackTrace) =>
      AsyncValue<R>.error(error, stackTrace),
    _ => AsyncValue<R>.loading(),
  };
}
