
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
// TODO import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_platform_widgets/flutter_platform_widgets.dart';
import 'package:provider/provider.dart';

import '../../helpers/config.dart';
import '../../helpers/utils.dart';
import '../../services/flight_log_services.dart';

class FlightLogScreen extends StatefulWidget {
  const FlightLogScreen({Key? key}) : super(key: key);

  @override
  _FlightLogScreenState createState() => _FlightLogScreenState();
}

class _FlightLogScreenState extends State<FlightLogScreen> {

  late AppConfig _appConfig;
  late FlightLogBookService _logBookService;

  @override
  void initState() {
    // TODO: implement initState
    super.initState();
  }

  @override
  void didChangeDependencies() {
    _appConfig = Provider.of<AppConfig>(context, listen: false);
    _logBookService = Provider.of<FlightLogBookService>(context, listen: false);
    super.didChangeDependencies();
  }

  Widget _buildBody(BuildContext context) {
    return Center(
      child: const Text('Under construction.'),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PlatformScaffold(
        iosContentPadding: true,
        appBar: isCupertino(context) ? null : PlatformAppBar(
          // TODO i18n
          title: Text('Flight log'),
          //leading: leadingAction,
          trailingActions: [
            //trailingAction,
          ],
          material: (context, platform) => MaterialAppBarData(
            toolbarHeight: MediaQuery.of(context).orientation == Orientation.portrait ?
            kPortraitToolbarHeight : kLandscapeToolbarHeight,
          ),
        ),
        material: (_, __) => MaterialScaffoldData(
          //floatingActionButton: fab,
          body: _buildBody(context)
        ),
        cupertino: (BuildContext context, __) => CupertinoPageScaffoldData(
          body: NestedScrollView(
            headerSliverBuilder: (_, __) => [CupertinoSliverNavigationBar(
              // TODO i18n
              largeTitle: Text('Flight log'),
            )],
            body: _buildBody(context)
          )
        ),
    );
  }
}
