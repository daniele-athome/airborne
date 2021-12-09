
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_platform_widgets/flutter_platform_widgets.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:provider/provider.dart';

import '../../helpers/config.dart';
import '../../helpers/utils.dart';
import '../../models/flight_log_models.dart';
import '../../services/flight_log_services.dart';
import 'flight_log_list.dart';
import 'flight_log_modal.dart';

class FlightLogScreen extends StatefulWidget {
  const FlightLogScreen({Key? key}) : super(key: key);

  @override
  _FlightLogScreenState createState() => _FlightLogScreenState();
}

class _FlightLogScreenState extends State<FlightLogScreen> {

  late FToast _fToast;
  late FlightLogListController _logBookController;
  late AppConfig _appConfig;
  late FlightLogBookService _logBookService;

  @override
  void initState() {
    super.initState();
    _fToast = FToast();
    _fToast.init(context);
    _logBookController = FlightLogListController();
  }

  @override
  void didChangeDependencies() {
    _appConfig = Provider.of<AppConfig>(context, listen: false);
    _logBookService = Provider.of<FlightLogBookService>(context, listen: false);
    super.didChangeDependencies();
  }

  void _onTapItem(BuildContext context, FlightLogItem item) {
    _logFlight(context, item);
  }

  void _logFlight(BuildContext context, FlightLogItem? item) {
    final FlightLogItem model;
    if (item == null) {
      model = FlightLogItem(
        null,
        DateTime.now(),
        _appConfig.pilotName!,
        _appConfig.locationName,
        _appConfig.locationName,
        // TODO start and end hour
        0,
        0,
        null,
        null,
        null,
      );
    }
    else {
      model = item;
    }

    Widget pageRouteBuilder(BuildContext context) => Provider.value(
      value: _logBookService,
      child: FlightLogModal(model),
    );

    final route = isCupertino(context) ?
    CupertinoPageRoute(
      builder: pageRouteBuilder,
      fullscreenDialog: true,
    ) :
    MaterialPageRoute(
      builder: pageRouteBuilder,
      fullscreenDialog: true,
    );
    Navigator.of(context, rootNavigator: true)
        .push(route)
        .then((result) {
      if (result != null) {
        final String message;
        if (item == null) {
          message = AppLocalizations.of(context)!.flightLog_message_flight_added;
        }
        else if (result is DeletedFlightLogItem) {
          message = AppLocalizations.of(context)!.flightLog_message_flight_canceled;
        }
        else {
          message = AppLocalizations.of(context)!.flightLog_message_flight_updated;
        }
        showToast(_fToast, message, const Duration(seconds: 2));
        // refresh list
        _logBookController.markDirty();
      }
    });
  }

  Widget _buildBody(BuildContext context) {
    return FlightLogList(
      controller: _logBookController,
      logBookService: _logBookService,
      onTapItem: (context, item) => _onTapItem(context, item),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PlatformScaffold(
        iosContentPadding: true,
        appBar: isCupertino(context) ? null : PlatformAppBar(
          title: Text(AppLocalizations.of(context)!.flightLog_title),
          material: (context, platform) => MaterialAppBarData(
            toolbarHeight: MediaQuery.of(context).orientation == Orientation.portrait ?
            kPortraitToolbarHeight : kLandscapeToolbarHeight,
          ),
        ),
        material: (_, __) => MaterialScaffoldData(
          floatingActionButton: FloatingActionButton(
            key: const Key('button_bookFlight'),
            onPressed: () => _logFlight(context, null),
            tooltip: AppLocalizations.of(context)!.button_logFlight,
            child: const Icon(Icons.add),
            // TODO colors
          ),
          body: _buildBody(context),
        ),
        cupertino: (BuildContext context, __) => CupertinoPageScaffoldData(
          body: NestedScrollView(
            headerSliverBuilder: (_, __) => [CupertinoSliverNavigationBar(
              largeTitle: Text(AppLocalizations.of(context)!.flightLog_title),
              trailing: PlatformIconButton(
                key: const Key('button_logFlight'),
                onPressed: () => _logFlight(context, null),
                icon: Icon(CupertinoIcons.add,
                  color: CupertinoColors.systemRed,
                  semanticLabel: AppLocalizations.of(context)!.button_logFlight,
                ),
                // TODO not ready yet
                //color: CupertinoColors.systemRed,
                cupertino: (_, __) => CupertinoIconButtonData(
                  // workaround for https://github.com/flutter/flutter/issues/32701
                  padding: EdgeInsets.zero,
                ),
              ),
            )],
            body: _buildBody(context)
          )
        ),
    );
  }
}
