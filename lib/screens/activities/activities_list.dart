
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_platform_widgets/flutter_platform_widgets.dart';
import 'package:infinite_scroll_pagination/infinite_scroll_pagination.dart';
import 'package:intl/intl.dart';
import 'package:logging/logging.dart';
import 'package:timeline_tile/timeline_tile.dart';

import '../../helpers/utils.dart';
import '../../models/activities_models.dart';
import '../../services/activities_services.dart';

final Logger _log = Logger((ActivityEntry).toString());

class ActivitiesList extends StatefulWidget {

  final ActivitiesListController controller;
  final ActivitiesService activitiesService;

  const ActivitiesList({
    Key? key,
    required this.controller,
    required this.activitiesService,
  }) : super(key: key);

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

      final items = widget.activitiesService.hasMoreData() ?
      await widget.activitiesService.fetchItems() : <ActivityEntry>[];
      final page = items.toList(growable: false).reversed.toList(growable: false);

      if (_firstTime) {
        if (page.isNotEmpty) {
          widget.controller.empty = false;
        }
        else {
          widget.controller.empty = true;
        }
        _firstTime = false;
      }

      if (widget.activitiesService.hasMoreData()) {
        _pagingController.appendPage(page, pageKey + 1);
      }
      else {
        _pagingController.appendLastPage(page);
      }
    }
    catch (error, stacktrace) {
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
        title: AppLocalizations.of(context)!.activities_error_firstPageIndicator,
        message: getExceptionMessage(_pagingController.error),
        onTryAgain: _refresh,
      );

  Widget newPageErrorIndicator(BuildContext context) =>
      NewPageErrorIndicator(
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
    if (isCupertino(context)) {
      return CustomScrollView(
        slivers: <Widget>[
          CupertinoSliverRefreshControl(
            onRefresh: () => _refresh(),
          ),
          PagedSliverList.separated(
            pagingController: _pagingController,
            separatorBuilder: (context, index) => const SizedBox.shrink(),
            builderDelegate: PagedChildBuilderDelegate<ActivityEntry>(
              itemBuilder: _buildListItem,
              firstPageErrorIndicatorBuilder: (context) => firstPageErrorIndicator(context),
              newPageErrorIndicatorBuilder: (context) => newPageErrorIndicator(context),
              noItemsFoundIndicatorBuilder: (context) => noItemsFoundIndicator(context),
              firstPageProgressIndicatorBuilder: (context) => const CupertinoActivityIndicator(radius: 20),
              newPageProgressIndicatorBuilder: (context) => const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: CupertinoActivityIndicator(radius: 16),
              ),
            ),
          ),
        ],
      );
    }
    else {
      return RefreshIndicator(
        onRefresh: () => _refresh(),
        child: PagedListView.separated(
          physics: const AlwaysScrollableScrollPhysics(),
          pagingController: _pagingController,
          separatorBuilder: (context, index) => const SizedBox.shrink(),
          builderDelegate: PagedChildBuilderDelegate<ActivityEntry>(
            itemBuilder: _buildListItem,
            firstPageErrorIndicatorBuilder: (context) => firstPageErrorIndicator(context),
            newPageErrorIndicatorBuilder: (context) => newPageErrorIndicator(context),
            noItemsFoundIndicatorBuilder: (context) => noItemsFoundIndicator(context),
          ),
        ),
      );
    }
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
    value = ActivitiesListState(
      empty: empty,
    );
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
  const ActivitiesListState({
    this.empty
  });

  final bool? empty;
}

class _EntryListItem extends StatelessWidget {

  const _EntryListItem({
    Key? key,
    required this.entry,
  }) : super(key: key);

  final ActivityEntry entry;

  static final _dateFormatter = DateFormat.yMEd();

  Color? _backgroundColor(BuildContext context, ActivityEntry entry) {
    if (entry.type == ActivityType.critical && entry.status != ActivityStatus.done) {
      return Colors.red.shade800;
    }
    return isCupertino(context) ? CupertinoColors.systemFill.resolveFrom(context) : null;
  }

  Color? _textColor(ActivityEntry entry) {
    if (entry.type == ActivityType.critical && entry.status != ActivityStatus.done) {
      return Colors.white;
    }
    return null;
  }

  Widget _entryIndicator(ActivityEntry entry) {
    const kIconSize = 20.0;
    final IconData icon;
    final Color bgColor;
    final Color iconColor;
    if (entry.status == ActivityStatus.done) {
      bgColor = const Color(0xff6ad192);
      iconColor = Colors.white;
      icon = Icons.check;
    }
    else {
      switch (entry.type) {
        case ActivityType.note:
          bgColor = Colors.blue;
          iconColor = Colors.white;
          icon = Icons.note_alt_outlined;
          break;
        case ActivityType.minor:
          bgColor = Colors.teal;
          iconColor = Colors.white;
          icon = Icons.task_outlined;
          break;
        case ActivityType.notice:
          bgColor = Colors.deepPurpleAccent;
          iconColor = Colors.white;
          icon = Icons.notifications_active_outlined;
          break;
        case ActivityType.important:
          bgColor = Colors.amber;
          iconColor = Colors.white;
          icon = Icons.warning_amber_outlined;
          break;
        case ActivityType.critical:
          bgColor = Colors.red;
          iconColor = Colors.white;
          icon = Icons.block_outlined;
          break;
        default:
          throw UnsupportedError("Unknown type: ${entry.type.name}");
      }
    }

    return Stack(
      children: [
        Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: bgColor,
          ),
        ),
        Positioned.fill(
          child: Align(
            alignment: Alignment.center,
            child: SizedBox(
              height: 30,
              width: 30,
              child: Icon(
                icon,
                size: kIconSize,
                color: iconColor,
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final summaryTextStyle = isCupertino(context) ?
    CupertinoTheme.of(context).textTheme.textStyle.copyWith(color: _textColor(entry)) :
    Theme.of(context).textTheme.headline5!.copyWith(color: _textColor(entry));

    final dateBackgroundColor = isCupertino(context) ?
    CupertinoColors.link.resolveFrom(context) :
    Theme.of(context).primaryColorLight;
    final dateTextColor = ThemeData.estimateBrightnessForColor(dateBackgroundColor) == Brightness.light ?
    Colors.black : Colors.white;
    final dateTextStyle = isCupertino(context) ?
    CupertinoTheme.of(context).textTheme.textStyle.copyWith(
      fontSize: 14,
      color: dateTextColor,
    ) :
    Theme.of(context).textTheme.labelMedium!.copyWith(
      color: dateTextColor,
    );
    final contentTextStyle = isCupertino(context) ?
    CupertinoTheme.of(context).textTheme.textStyle.copyWith(fontSize: 14, color: _textColor(entry)) :
    Theme.of(context).textTheme.bodyMedium!.copyWith(color: _textColor(entry));

    final content = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(entry.summary, style: summaryTextStyle),
          Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8.0),
                color: dateBackgroundColor,
              ),
              padding: const EdgeInsets.symmetric(vertical: 2.0, horizontal: 8.0),
              child: Text(_dateFormatter.format(entry.creationDate), style: dateTextStyle)
          ),
          if (entry.description != null) const SizedBox(height: 4),
          if (entry.description != null) Text(entry.description!, style: contentTextStyle),
          //const SizedBox(height: 8),
        ],
      ),
    );

    return TimelineTile(
      alignment: TimelineAlign.manual,
      lineXY: 0.05,
      indicatorStyle: IndicatorStyle(
        padding: const EdgeInsets.all(8),
        indicatorXY: 0.5,
        drawGap: true,
        width: 30,
        height: 30,
        indicator: _entryIndicator(entry),
      ),
      endChild: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: isCupertino(context) ?
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(15.0),
            color: _backgroundColor(context, entry),
          ),
          // no shadow, so we manually create a margin
          margin: const EdgeInsets.symmetric(vertical: 4),
          child: content,
        ) :
        Card(
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
