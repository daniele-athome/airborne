import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_platform_widgets/flutter_platform_widgets.dart';
import 'package:infinite_scroll_pagination/infinite_scroll_pagination.dart';
import 'package:intl/intl.dart';
import 'package:logging/logging.dart';

import '../../generated/intl/app_localizations.dart';
import '../../helpers/utils.dart';
import '../../models/activities_models.dart';
import '../../services/activities_services.dart';

final Logger _log = Logger((ActivityEntry).toString());

class ActivitiesList extends StatefulWidget {
  final ActivitiesService activitiesService;

  const ActivitiesList({super.key, required this.activitiesService});

  @override
  State<ActivitiesList> createState() => _ActivitiesListState();
}

class _ActivitiesListState extends State<ActivitiesList> {
  late final _pagingController = PagingController<int, ActivityEntry>(
    getNextPageKey: _nextPageKey,
    fetchPage: _fetchPage,
  );
  var _firstTime = true;

  /// The service tracks the cursor itself, so the page key is just a counter.
  /// Before the first fetch there is no cursor yet, hence [_firstTime].
  int? _nextPageKey(PagingState<int, ActivityEntry> state) =>
      (_firstTime || widget.activitiesService.hasMoreData())
      ? state.nextIntPageKey
      : null;

  Future<List<ActivityEntry>> _fetchPage(int pageKey) async {
    try {
      if (_firstTime) {
        await widget.activitiesService.reset();
        _firstTime = false;
      }

      final items = widget.activitiesService.hasMoreData()
          ? await widget.activitiesService.fetchItems()
          : <ActivityEntry>[];
      return items
          // ignore done items for now
          .where((entry) => entry.status != ActivityStatus.done)
          .toList(growable: false);
    } catch (error, stacktrace) {
      _log.warning('error loading activities data', error, stacktrace);
      rethrow;
    }
  }

  Future<void> _refresh() async {
    _firstTime = true;
    return Future.sync(() => _pagingController.refresh());
  }

  Widget noItemsFoundIndicator(BuildContext context) =>
      FirstPageExceptionIndicator(
        title: AppLocalizations.of(context)!.activities_error_noItemsFound,
        onTryAgain: _refresh,
      );

  Widget firstPageErrorIndicator(BuildContext context, Object? error) =>
      FirstPageExceptionIndicator(
        title: AppLocalizations.of(
          context,
        )!.activities_error_firstPageIndicator,
        message: getExceptionMessage(error),
        onTryAgain: _refresh,
      );

  Widget newPageErrorIndicator(BuildContext context, VoidCallback onRetry) =>
      NewPageErrorIndicator(
        message: AppLocalizations.of(
          context,
        )!.activities_error_newPageIndicator,
        onTap: onRetry,
      );

  Widget _buildListItem(BuildContext context, ActivityEntry item, int index) {
    return _EntryListItem(entry: item);
  }

  /// FIXME using PagedSliverList within a CustomScrollView for Material leads to errors
  @override
  Widget build(BuildContext context) {
    // TODO test scrolling physics with no content
    return PagingListener<int, ActivityEntry>(
      controller: _pagingController,
      builder: (context, state, fetchNextPage) => PlatformWidget(
        cupertino: (context, platform) => CustomScrollView(
          slivers: <Widget>[
            CupertinoSliverRefreshControl(onRefresh: () => _refresh()),
            SliverPadding(
              // 2 points less because something else is adding padding
              padding: const EdgeInsets.symmetric(vertical: 6.0),
              sliver: PagedSliverList.separated(
                state: state,
                fetchNextPage: fetchNextPage,
                separatorBuilder: (context, index) => const SizedBox.shrink(),
                builderDelegate: PagedChildBuilderDelegate<ActivityEntry>(
                  itemBuilder: _buildListItem,
                  firstPageErrorIndicatorBuilder: (context) =>
                      firstPageErrorIndicator(context, state.error),
                  newPageErrorIndicatorBuilder: (context) =>
                      newPageErrorIndicator(context, fetchNextPage),
                  noItemsFoundIndicatorBuilder: (context) =>
                      noItemsFoundIndicator(context),
                  firstPageProgressIndicatorBuilder: (context) =>
                      const CupertinoActivityIndicator(radius: 20),
                  newPageProgressIndicatorBuilder: (context) => const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: CupertinoActivityIndicator(radius: 16),
                  ),
                ),
              ),
            ),
          ],
        ),
        material: (context, platform) => RefreshIndicator(
          onRefresh: () => _refresh(),
          child: PagedListView.separated(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            state: state,
            fetchNextPage: fetchNextPage,
            separatorBuilder: (context, index) => const SizedBox.shrink(),
            builderDelegate: PagedChildBuilderDelegate<ActivityEntry>(
              itemBuilder: _buildListItem,
              firstPageErrorIndicatorBuilder: (context) =>
                  firstPageErrorIndicator(context, state.error),
              newPageErrorIndicatorBuilder: (context) =>
                  newPageErrorIndicator(context, fetchNextPage),
              noItemsFoundIndicatorBuilder: (context) =>
                  noItemsFoundIndicator(context),
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _pagingController.dispose();
    super.dispose();
  }
}

class _EntryListItem extends StatelessWidget {
  const _EntryListItem({
    // ignore: unused_element_parameter
    super.key,
    required this.entry,
  });

  final ActivityEntry entry;

  Color? _backgroundColor(BuildContext context, ActivityEntry entry) {
    return isCupertino(context)
        ? CupertinoColors.systemFill.resolveFrom(context)
        : null;
  }

  Widget _entryIndicator(BuildContext context, ActivityEntry entry) {
    const kIconSize = 20.0;
    final IconData icon;
    final Color bgColor;
    final Color iconColor;
    final String text;
    // FIXME "done" is filtered out for now
    if (entry.status == ActivityStatus.done) {
      bgColor = const Color(0xff6ad192);
      iconColor = Colors.white;
      icon = Icons.check;
      if (entry.lastStatusUpdate != null) {
        // TODO i18n
        text =
            "Fatto il ${DateFormat.yMd(context.localeString).format(entry.lastStatusUpdate!)}";
      } else {
        // TODO i18n
        text = "Fatto";
      }
    } else {
      switch (entry.type) {
        case ActivityType.note:
          bgColor = Colors.blue;
          iconColor = Colors.white;
          icon = Icons.note_alt_outlined;
          text = AppLocalizations.of(context)!.activities_activity_type_note;
          break;
        case ActivityType.minor:
          bgColor = Colors.teal;
          iconColor = Colors.white;
          icon = Icons.task_outlined;
          text = AppLocalizations.of(context)!.activities_activity_type_minor;
          break;
        case ActivityType.notice:
          bgColor = Colors.deepPurpleAccent;
          iconColor = Colors.white;
          icon = Icons.notifications_active_outlined;
          text = AppLocalizations.of(context)!.activities_activity_type_notice;
          break;
        case ActivityType.important:
          bgColor = Colors.amber;
          iconColor = Colors.white;
          icon = Icons.warning_amber_outlined;
          text = AppLocalizations.of(
            context,
          )!.activities_activity_type_important;
          break;
        case ActivityType.critical:
          bgColor = Colors.red;
          iconColor = Colors.white;
          icon = Icons.block_outlined;
          text = AppLocalizations.of(
            context,
          )!.activities_activity_type_critical;
          break;
      }
    }

    final dateTextColor =
        ThemeData.estimateBrightnessForColor(bgColor) == Brightness.light
        ? Colors.black
        : Colors.white;
    final textStyle = isCupertino(context)
        ? CupertinoTheme.of(
            context,
          ).textTheme.textStyle.copyWith(fontSize: 14, color: dateTextColor)
        : Theme.of(
            context,
          ).textTheme.bodyMedium!.copyWith(color: dateTextColor);

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8.0),
        color: bgColor,
      ),
      padding: const EdgeInsets.symmetric(vertical: 2.0, horizontal: 12.0),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: 24,
            width: 24,
            child: Icon(icon, size: kIconSize, color: iconColor),
          ),
          const SizedBox(width: 4.0),
          Text(text, style: textStyle),
        ],
      ),
    );
  }

  Widget _expireIndicator(BuildContext context, ActivityEntry entry) {
    const kIconSize = 20.0;
    final IconData icon;
    final Color bgColor;
    final Color iconColor;

    final today = DateTime.now();
    if (DateUtils.isSameDay(entry.dueDate, today) ||
        entry.dueDate!.isBefore(today)) {
      bgColor = Colors.red;
      iconColor = Colors.white;
      icon = Icons.warning_amber_outlined;
    } else {
      bgColor = Colors.amber;
      iconColor = Colors.black;
      icon = Icons.calendar_today_outlined;
    }

    final dateTextColor =
        ThemeData.estimateBrightnessForColor(bgColor) == Brightness.light
        ? Colors.black
        : Colors.white;
    final textStyle = isCupertino(context)
        ? CupertinoTheme.of(
            context,
          ).textTheme.textStyle.copyWith(fontSize: 14, color: dateTextColor)
        : Theme.of(
            context,
          ).textTheme.bodyMedium!.copyWith(color: dateTextColor);

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8.0),
        color: bgColor,
      ),
      padding: const EdgeInsets.symmetric(vertical: 2.0, horizontal: 12.0),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: 24,
            width: 24,
            child: Icon(icon, size: kIconSize, color: iconColor),
          ),
          const SizedBox(width: 4.0),
          Text(
            DateFormat.yMd(context.localeString).format(entry.dueDate!),
            style: textStyle,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final summaryTextStyle = isCupertino(context)
        ? CupertinoTheme.of(context).textTheme.textStyle
        : Theme.of(context).textTheme.titleLarge!;
    final contentTextStyle = isCupertino(context)
        ? CupertinoTheme.of(context).textTheme.textStyle.copyWith(fontSize: 14)
        : Theme.of(context).textTheme.bodyMedium!;

    final content = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(entry.summary, style: summaryTextStyle),
                if (entry.description != null) const SizedBox(height: 4),
                if (entry.description != null)
                  Text(entry.description!, style: contentTextStyle),
                const SizedBox(height: 8.0),
                Row(
                  children: [
                    _entryIndicator(context, entry),
                    const SizedBox(width: 8.0),
                    if (entry.status != ActivityStatus.done &&
                        entry.dueDate != null)
                      _expireIndicator(context, entry),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: PlatformWidget(
        cupertino: (context, platform) => Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(15.0),
            color: _backgroundColor(context, entry),
          ),
          // no shadow, so we manually create a margin
          margin: const EdgeInsets.symmetric(vertical: 4),
          child: content,
        ),
        material: (context, platform) => Card(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15.0),
          ),
          color: _backgroundColor(context, entry),
          elevation: 5,
          child: content,
        ),
      ),
    );
  }
}
