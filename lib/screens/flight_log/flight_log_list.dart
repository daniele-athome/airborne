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

class FlightLogList extends StatefulWidget {
  const FlightLogList({
    super.key,
    required this.controller,
    required this.logBookService,
    required this.onTapItem,
  });

  final FlightLogListController controller;
  final FlightLogBookService logBookService;
  final Function(BuildContext context, FlightLogItem item) onTapItem;

  @override
  State<FlightLogList> createState() => _FlightLogListState();
}

class _FlightLogListState extends State<FlightLogList> {
  final _pagingController = PagingController<int, FlightLogItem>(
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
  void didUpdateWidget(FlightLogList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.controller != oldWidget.controller) {
      oldWidget.controller.removeListener(_refresh);
      widget.controller.addListener(_refresh);
    }
  }

  Future<void> _fetchPage(int pageKey) async {
    try {
      if (_firstTime) {
        await widget.logBookService.reset();
      }

      final items = widget.logBookService.hasMoreData()
          ? await widget.logBookService.fetchItems()
          : <FlightLogItem>[];
      final page =
          items.toList(growable: false).reversed.toList(growable: false);

      if (_firstTime) {
        if (page.isNotEmpty) {
          widget.controller.lastEndHourMeter = page[0].endHour;
          widget.controller.empty = false;
        } else {
          widget.controller.lastEndHourMeter = 0;
          widget.controller.empty = true;
        }
        _firstTime = false;
      }

      if (widget.logBookService.hasMoreData()) {
        _pagingController.appendPage(page, pageKey + 1);
      } else {
        _pagingController.appendLastPage(page);
      }
    } catch (error, stacktrace) {
      _log.warning('error loading log book data', error, stacktrace);
      _pagingController.error = error;
    }
  }

  Future<void> _refresh() async {
    _firstTime = true;
    return Future.sync(() => _pagingController.refresh());
  }

  Widget _buildListItem(BuildContext context, FlightLogItem item, int index) =>
      FlightLogListItem(item: item, onTapItem: widget.onTapItem);

  Widget noItemsFoundIndicator(BuildContext context) =>
      FirstPageExceptionIndicator(
        title: AppLocalizations.of(context)!.flightLog_error_noItemsFound,
        onTryAgain: _refresh,
      );

  Widget firstPageErrorIndicator(BuildContext context) =>
      FirstPageExceptionIndicator(
        title: AppLocalizations.of(context)!.flightLog_error_firstPageIndicator,
        message: getExceptionMessage(_pagingController.error),
        onTryAgain: _refresh,
      );

  Widget newPageErrorIndicator(BuildContext context) => NewPageErrorIndicator(
        message: AppLocalizations.of(context)!.flightLog_error_newPageIndicator,
        onTap: _pagingController.retryLastFailedRequest,
      );

  /// FIXME using PagedSliverList within a CustomScrollView for Material leads to errors
  @override
  Widget build(BuildContext context) {
    // TODO test scrolling physics with no content
    return PlatformWidget(
      material: (context, platform) => RefreshIndicator(
        onRefresh: () => _refresh(),
        child: PagedListView.separated(
          physics: const AlwaysScrollableScrollPhysics(),
          pagingController: _pagingController,
          separatorBuilder: (context, index) => FlightLogListDivider(),
          builderDelegate: PagedChildBuilderDelegate<FlightLogItem>(
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
      cupertino: (context, platform) => CustomScrollView(
        slivers: <Widget>[
          CupertinoSliverRefreshControl(
            onRefresh: () => _refresh(),
          ),
          PagedSliverList.separated(
            pagingController: _pagingController,
            separatorBuilder: (context, index) => FlightLogListDivider(),
            builderDelegate: PagedChildBuilderDelegate<FlightLogItem>(
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
        ],
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

class FlightLogListItem extends StatelessWidget {
  final _hoursFormatter = NumberFormat.decimalPattern();
  final _dateFormatter = DateFormat.yMEd();

  final FlightLogItem item;
  final Function(BuildContext context, FlightLogItem item) onTapItem;

  FlightLogListItem({
    super.key,
    required this.item,
    required this.onTapItem,
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
      material: (ThemeData data) => data.textTheme.titleMedium!
          .copyWith(color: data.textTheme.bodySmall!.color),
      cupertino: (CupertinoThemeData data) => data.textTheme.textStyle,
    );
    final pilotStyle = platformThemeData(
      context,
      // TODO do we need this? -- fontWeight: FontWeight.w300,
      material: (ThemeData data) => data.textTheme.bodyMedium!.copyWith(
        fontSize: 17,
      ),
      cupertino: (CupertinoThemeData data) => data.textTheme.textStyle.copyWith(
        fontSize: 17,
      ),
    );
    final timeStyle = platformThemeData(
      context,
      material: (ThemeData data) => data.textTheme.bodyMedium!.copyWith(
        fontSize: 20,
      ),
      cupertino: (CupertinoThemeData data) => data.textTheme.textStyle.copyWith(
        fontSize: 20,
      ),
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
                    child: Text(_dateFormatter.format(item.date),
                        style: dateStyle),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      children: [
                        Icon(PlatformIcons(context).locationSolid,
                            color: Colors.red, size: 18),
                        const SizedBox(width: 4),
                        Text(_buildLocationName(item), style: subtitleStyle),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      children: [
                        Icon(PlatformIcons(context).clockSolid,
                            color: Colors.blue, size: 18),
                        const SizedBox(width: 4),
                        Text(_buildHours(item), style: subtitleStyle),
                      ],
                    ),
                  ),
                ],
              )),
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
                          child: Icon(Icons.local_gas_station,
                              color: Colors.green, size: 24),
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
      material: (_, child, __) => InkWell(
        onTap: () => onTapItem(context, item),
        child: child,
      ),
      cupertino: (_, child, __) => CupertinoInkWell(
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

  String _buildTime(FlightLogItem item) =>
      '${((item.endHour - item.startHour) * 60).round().toString()}′';
}

class FlightLogListController extends ValueNotifier<FlightLogListState> {
  FlightLogListController() : super(const FlightLogListState());

  set lastEndHourMeter(num? number) {
    value = FlightLogListState(
      lastEndHourMeter: number,
      empty: value.empty,
    );
  }

  num? get lastEndHourMeter {
    return value.lastEndHourMeter;
  }

  set empty(bool? empty) {
    value = FlightLogListState(
      lastEndHourMeter: value.lastEndHourMeter,
      empty: empty,
    );
  }

  bool? get empty {
    return value.empty;
  }

  void reset() {
    value = const FlightLogListState();
  }
}

@immutable
class FlightLogListState {
  const FlightLogListState({this.lastEndHourMeter, this.empty});

  final num? lastEndHourMeter;
  final bool? empty;
}

class FlightLogListDivider extends PlatformWidget {
  FlightLogListDivider({super.key});

  @override
  Widget createCupertinoWidget(BuildContext context) =>
      buildCupertinoFormRowDivider(context, true);

  @override
  Widget createMaterialWidget(BuildContext context) => const Divider(height: 0);
}
