import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_platform_widgets/flutter_platform_widgets.dart';
import 'package:infinite_scroll_pagination/infinite_scroll_pagination.dart';
import 'package:intl/intl.dart';
import 'package:logging/logging.dart';

import '../../generated/intl/app_localizations.dart';
import '../../helpers/cupertinoplus.dart';
import '../../helpers/utils.dart';
import '../../models/flight_log_models.dart';
import '../../services/flight_log_services.dart';

final Logger _log = Logger((FlightLogItem).toString());

class FlightLogList extends StatelessWidget {
  const FlightLogList({
    super.key,
    required this.controller,
    required this.onTapItem,
    required this.hourmeterMultiplier,
  });

  final FlightLogListController controller;
  final Function(BuildContext context, FlightLogItem item) onTapItem;
  final int hourmeterMultiplier;

  Future<void> _refresh() async => controller.refresh();

  Widget _buildListItem(BuildContext context, FlightLogItem item, int index) =>
      FlightLogListItem(
        item: item,
        onTapItem: onTapItem,
        hourmeterMultiplier: hourmeterMultiplier,
      );

  Widget noItemsFoundIndicator(BuildContext context) =>
      FirstPageExceptionIndicator(
        title: AppLocalizations.of(context)!.flightLog_error_noItemsFound,
        onTryAgain: _refresh,
      );

  Widget firstPageErrorIndicator(BuildContext context, Object? error) =>
      FirstPageExceptionIndicator(
        title: AppLocalizations.of(context)!.flightLog_error_firstPageIndicator,
        message: getExceptionMessage(error),
        onTryAgain: _refresh,
      );

  Widget newPageErrorIndicator(BuildContext context, VoidCallback onRetry) =>
      NewPageErrorIndicator(
        message: AppLocalizations.of(context)!.flightLog_error_newPageIndicator,
        onTap: onRetry,
      );

  /// FIXME using PagedSliverList within a CustomScrollView for Material leads to errors
  @override
  Widget build(BuildContext context) {
    // TODO test scrolling physics with no content
    return PagingListener<int, FlightLogItem>(
      controller: controller,
      builder: (context, state, fetchNextPage) => PlatformWidget(
        material: (context, platform) => RefreshIndicator(
          onRefresh: () => _refresh(),
          child: PagedListView.separated(
            physics: const AlwaysScrollableScrollPhysics(),
            state: state,
            fetchNextPage: fetchNextPage,
            separatorBuilder: (context, index) => FlightLogListDivider(),
            builderDelegate: PagedChildBuilderDelegate<FlightLogItem>(
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
        cupertino: (context, platform) => CustomScrollView(
          slivers: <Widget>[
            CupertinoSliverRefreshControl(onRefresh: () => _refresh()),
            PagedSliverList.separated(
              state: state,
              fetchNextPage: fetchNextPage,
              separatorBuilder: (context, index) => FlightLogListDivider(),
              builderDelegate: PagedChildBuilderDelegate<FlightLogItem>(
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
          ],
        ),
      ),
    );
  }
}

class FlightLogListItem extends StatelessWidget {
  final _hoursFormatter = NumberFormat.decimalPattern();

  final FlightLogItem item;
  final Function(BuildContext context, FlightLogItem item) onTapItem;
  final int hourmeterMultiplier;

  FlightLogListItem({
    super.key,
    required this.item,
    required this.onTapItem,
    required this.hourmeterMultiplier,
  });

  @override
  Widget build(BuildContext context) {
    final dateStyle = platformThemeData(
      context,
      // TODO do we need this? -- fontWeight: FontWeight.bold,
      material: (ThemeData data) =>
          data.textTheme.bodyLarge!.copyWith(fontSize: 16),
      cupertino: (CupertinoThemeData data) =>
          data.textTheme.textStyle.copyWith(fontSize: 16),
    );
    final subtitleStyle = platformThemeData(
      context,
      material: (ThemeData data) => data.textTheme.titleMedium!.copyWith(
        color: data.textTheme.bodySmall!.color,
      ),
      cupertino: (CupertinoThemeData data) => data.textTheme.textStyle,
    );
    final pilotStyle = platformThemeData(
      context,
      // TODO do we need this? -- fontWeight: FontWeight.w300,
      material: (ThemeData data) =>
          data.textTheme.bodyMedium!.copyWith(fontSize: 17),
      cupertino: (CupertinoThemeData data) =>
          data.textTheme.textStyle.copyWith(fontSize: 17),
    );
    final timeStyle = platformThemeData(
      context,
      material: (ThemeData data) =>
          data.textTheme.bodyMedium!.copyWith(fontSize: 20),
      cupertino: (CupertinoThemeData data) =>
          data.textTheme.textStyle.copyWith(fontSize: 20),
    );

    final listItem = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            flex: 8,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Text(
                    DateFormat.yMEd(context.localeString).format(item.date),
                    style: dateStyle,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    children: [
                      Icon(
                        PlatformIcons(context).locationSolid,
                        color: Colors.red,
                        size: 18,
                      ),
                      const SizedBox(width: 4),
                      Text(_buildLocationName(item), style: subtitleStyle),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    children: [
                      Icon(
                        PlatformIcons(context).clockSolid,
                        color: Colors.blue,
                        size: 18,
                      ),
                      const SizedBox(width: 4),
                      Text(_buildHours(item), style: subtitleStyle),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 4,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: AutoSizeText(
                    item.pilotName,
                    style: pilotStyle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.end,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      if (item.fuel != null && item.fuel! > 0)
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 4),
                          child: Icon(
                            Icons.local_gas_station,
                            color: Colors.green,
                            size: 24,
                          ),
                        ),
                      Text(_buildTime(item), style: timeStyle),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );

    return PlatformWidgetBuilder(
      material: (_, child, _) =>
          InkWell(onTap: () => onTapItem(context, item), child: child),
      cupertino: (_, child, _) => CupertinoInkWell(
        onPressed: () => onTapItem(context, item),
        child: child!,
      ),
      child: listItem,
    );
  }

  String _buildLocationName(FlightLogItem item) =>
      (item.origin != item.destination)
      ? '${item.origin} – ${item.destination}'
      : item.origin;

  String _buildHours(FlightLogItem item) =>
      '${_hoursFormatter.format(item.startHour)} – ${_hoursFormatter.format(item.endHour)}';

  String _buildTime(FlightLogItem item) {
    int startMinutes = item.startHour.toMinutes(hourmeterMultiplier);
    int endMinutes = item.endHour.toMinutes(hourmeterMultiplier);
    return '${(endMinutes - startMinutes).round().toString()}′';
  }
}

/// Holds the whole state of the flight log list, driving the log book service.
class FlightLogListController extends PagingController<int, FlightLogItem> {
  FlightLogListController._(
    this._logBookService, {
    required super.getNextPageKey,
    required super.fetchPage,
  });

  /// The callbacks need the instance itself, hence the factory.
  factory FlightLogListController(FlightLogBookService logBookService) {
    late final FlightLogListController controller;
    return controller = FlightLogListController._(
      logBookService,
      getNextPageKey: (state) => controller._nextPageKey(state),
      fetchPage: (pageKey) => controller._fetchPage(pageKey),
    );
  }

  final FlightLogBookService _logBookService;
  var _firstTime = true;

  /// Hourmeter of the last logged flight. Null if not loaded yet or empty.
  num? get lastEndHourMeter => items?.firstOrNull?.endHour;

  /// Whether the first page was loaded, even if empty.
  bool get loaded => items != null;

  @override
  void refresh() {
    _firstTime = true;
    super.refresh();
  }

  /// The service keeps the cursor itself, so the page key is just a counter.
  /// There is no cursor before the first fetch, hence [_firstTime].
  int? _nextPageKey(PagingState<int, FlightLogItem> state) =>
      (_firstTime || _logBookService.hasMoreData())
      ? state.nextIntPageKey
      : null;

  Future<List<FlightLogItem>> _fetchPage(int pageKey) async {
    try {
      if (_firstTime) {
        await _logBookService.reset();
        _firstTime = false;
      }

      final items = _logBookService.hasMoreData()
          ? await _logBookService.fetchItems()
          : <FlightLogItem>[];
      // the log book is stored in chronological order, we display it reversed
      return items.toList(growable: false).reversed.toList(growable: false);
    } catch (error, stacktrace) {
      _log.warning('error loading log book data', error, stacktrace);
      rethrow;
    }
  }
}

class FlightLogListDivider extends PlatformWidget {
  const FlightLogListDivider({super.key});

  @override
  Widget createCupertinoWidget(BuildContext context) =>
      buildCupertinoFormRowDivider(context, true);

  @override
  Widget createMaterialWidget(BuildContext context) => const Divider(height: 0);
}
