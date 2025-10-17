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
  final ActivitiesListController controller;
  final ActivitiesService activitiesService;

  const ActivitiesList({
    super.key,
    required this.controller,
    required this.activitiesService,
  });

  @override
  State<ActivitiesList> createState() => _ActivitiesListState();
}

class _ActivitiesListState extends State<ActivitiesList> {
  final _pagingController = PagingController<int, ActivityEntry>(
    firstPageKey: 1,
  );
  var _firstTime = true;

  @override
  void initState() {
    _pagingController.addPageRequestListener((pageKey) => _fetchPage(pageKey));
    widget.controller.addListener(_refresh);
    super.initState();
  }

  @override
  void didUpdateWidget(ActivitiesList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.controller != oldWidget.controller) {
      oldWidget.controller.removeListener(_refresh);
      widget.controller.addListener(_refresh);
    }
  }

  Future<void> _fetchPage(int pageKey) async {
    try {
      if (_firstTime) {
        await widget.activitiesService.reset();
      }

      final items = widget.activitiesService.hasMoreData()
          ? await widget.activitiesService.fetchItems()
          : <ActivityEntry>[];
      final page = items
          // ignore done items for now
          .where((entry) => entry.status != ActivityStatus.done)
          .toList(growable: false);

      if (_firstTime) {
        if (page.isNotEmpty) {
          widget.controller.empty = false;
        } else {
          widget.controller.empty = true;
        }
        _firstTime = false;
      }

      if (widget.activitiesService.hasMoreData()) {
        _pagingController.appendPage(page, pageKey + 1);
      } else {
        _pagingController.appendLastPage(page);
      }
    } catch (error, stacktrace) {
      _log.warning('error loading activities data', error, stacktrace);
      _pagingController.error = error;
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

  Widget firstPageErrorIndicator(BuildContext context) =>
      FirstPageExceptionIndicator(
        title: AppLocalizations.of(
          context,
        )!.activities_error_firstPageIndicator,
        message: getExceptionMessage(_pagingController.error),
        onTryAgain: _refresh,
      );

  Widget newPageErrorIndicator(BuildContext context) => NewPageErrorIndicator(
    message: AppLocalizations.of(context)!.activities_error_newPageIndicator,
    onTap: _pagingController.retryLastFailedRequest,
  );

  Widget _buildListItem(BuildContext context, ActivityEntry item, int index) {
    return _EntryListItem(entry: item);
  }

  /// FIXME using PagedSliverList within a CustomScrollView for Material leads to errors
  @override
  Widget build(BuildContext context) {
    // TODO test scrolling physics with no content
    return PlatformWidget(
      cupertino: (context, platform) => CustomScrollView(
        slivers: <Widget>[
          CupertinoSliverRefreshControl(onRefresh: () => _refresh()),
          SliverPadding(
            // 2 points less because something else is adding padding
            padding: const EdgeInsets.symmetric(vertical: 6.0),
            sliver: PagedSliverList.separated(
              pagingController: _pagingController,
              separatorBuilder: (context, index) => const SizedBox.shrink(),
              builderDelegate: PagedChildBuilderDelegate<ActivityEntry>(
                itemBuilder: _buildListItem,
                firstPageErrorIndicatorBuilder: (context) =>
                    firstPageErrorIndicator(context),
                newPageErrorIndicatorBuilder: (context) =>
                    newPageErrorIndicator(context),
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
          pagingController: _pagingController,
          separatorBuilder: (context, index) => const SizedBox.shrink(),
          builderDelegate: PagedChildBuilderDelegate<ActivityEntry>(
            itemBuilder: _buildListItem,
            firstPageErrorIndicatorBuilder: (context) =>
                firstPageErrorIndicator(context),
            newPageErrorIndicatorBuilder: (context) =>
                newPageErrorIndicator(context),
            noItemsFoundIndicatorBuilder: (context) =>
                noItemsFoundIndicator(context),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _pagingController.dispose();
    widget.controller.removeListener(_refresh);
    super.dispose();
  }
}

class ActivitiesListController extends ValueNotifier<ActivitiesListState> {
  ActivitiesListController() : super(const ActivitiesListState());

  set empty(bool? empty) {
    value = ActivitiesListState(empty: empty);
  }

  bool? get empty {
    return value.empty;
  }

  void reset() {
    value = const ActivitiesListState();
  }
}

@immutable
class ActivitiesListState {
  const ActivitiesListState({this.empty});

  final bool? empty;
}

class _EntryListItem extends StatelessWidget {
  static final DateFormat _dateFormatter = DateFormat.yMd();

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
        text = "Fatto il ${_dateFormatter.format(entry.lastStatusUpdate!)}";
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
          Text(_dateFormatter.format(entry.dueDate!), style: textStyle),
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
