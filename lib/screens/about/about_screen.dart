import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:logging/logging.dart';
import 'package:provider/provider.dart';

import '../../helpers/config.dart';

final Logger _log = Logger((AboutScreen).toString());

class AboutScreen extends StatefulWidget {
  @override
  _AboutScreenState createState() => _AboutScreenState();
}

class _AboutScreenState extends State<AboutScreen> {
  late AppConfig _appConfig;

  @override
  void didChangeDependencies() {
    _appConfig = Provider.of<AppConfig>(context, listen: false);
    super.didChangeDependencies();
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        Stack(
          children: [
            Positioned(
              child: Image(
                image: _appConfig.aircraftPicture,
              ),
            ),
            Positioned.fill(
              bottom: -10,
              child: Align(
                alignment: Alignment.bottomCenter,
                child: Container(
                  height: 30.0,
                  decoration: BoxDecoration(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(20.0)),
                    color: Theme.of(context).scaffoldBackgroundColor,
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.grey,
                        offset: Offset(0.0, -2.0),
                        blurRadius: 5.0,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
        // TODO i18n
        const HeaderListTile('Aeromobile', first: true),
        ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 20),
          // TODO i18n
          title: const Text('Marche'),
          trailing: Text(_appConfig.currentAircraft!.callSign,
            style: Theme.of(context).textTheme.headline6!.copyWith(fontWeight: FontWeight.bold),
          ),
        ),
        ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 20),
          // TODO i18n
          title: const Text('Hangar'),
          trailing: Text('TODO hangar',
            style: Theme.of(context).textTheme.headline6,
          ),
          // TODO go to maps button
        ),
        // TODO i18n
        const HeaderListTile('Piloti'),
        ..._appConfig.pilotNames.map((e) => ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 20),
          leading: CircleAvatar(backgroundImage: _appConfig.getPilotAvatar(e)),
          title: Text(e),
        )).toList(growable: false),
        // TODO i18n
        HeaderListTile(AppLocalizations.of(context)!.appName),
        // TEST
        ...List.generate(10, (index) => ListTile(
          title: Text('Item $index'),
        )),
        //AboutListTile(),
      ],
    );
  }
}

class HeaderListTile extends StatelessWidget {

  const HeaderListTile(this.text, {
    Key? key,
    this.first = false,
  }) : super(key: key);

  /// The text to be displayed.
  final String text;
  /// True if this is the first header of the list.
  final bool first;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: first ? const EdgeInsets.fromLTRB(20, 0, 20, 10) : const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Text(text, style: Theme.of(context).textTheme.headline5),
    );
  }

}
