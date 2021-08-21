
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
// TODO import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_platform_widgets/flutter_platform_widgets.dart';


class FlightLogScreen extends StatefulWidget {
  @override
  _FlightLogScreenState createState() => _FlightLogScreenState();
}

class _FlightLogScreenState extends State<FlightLogScreen> {

  @override
  void initState() {
    // TODO: implement initState
    super.initState();
  }

  Widget _buildBody(BuildContext context) {
    return Container(
      child: ListView(
        children: [
          const Text('07/06/2021'),
          const Text('06/06/2021'),
          const Text('05/06/2021'),
          const Text('04/06/2021'),
        ],
      ),
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
