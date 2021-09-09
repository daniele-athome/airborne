import 'package:airborne/helpers/utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
// TODO import 'package:logging/logging.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';

import '../../helpers/config.dart';
import '../../pubspec.yaml.g.dart' as pubspec;

// TODO final Logger _log = Logger((AboutScreen).toString());

// TODO convert to stateless widget if using only AppConfig
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

  void _onLogout(BuildContext context) {
    showConfirm(
      context: context,
      // TODO i18n
      title: "Disconnettere l'aereo?",
        // TODO i18n
      text: "Dovrai immettere di nuovo l'indirizzo dei dati dell'aereo.",
      destructiveOk: true,
      okCallback: () {
        _appConfig.pilotName = null;
        _appConfig.currentAircraft = null;
        Navigator.of(context, rootNavigator: true).popAndPushNamed('aircraft-data');
      },
    );
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
          subtitle: const Text('Marche'),
          title: Text(_appConfig.currentAircraft!.callSign,
            style: Theme.of(context).textTheme.headline6!.copyWith(fontWeight: FontWeight.bold),
          ),
        ),
        ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 20),
          // TODO i18n
          subtitle: const Text('Hangar'),
          title: Text('TODO hangar',
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
        HeaderListTile(AppLocalizations.of(context)!.appName),
        ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 20),
          leading: const SizedBox(
            height: double.infinity,
            child: Icon(Icons.info),
          ),
          // TODO i18n
          subtitle: const Text('Versione'),
          title: FutureBuilder(
            future: PackageInfo.fromPlatform(),
            initialData: null,
            builder: (context, AsyncSnapshot<PackageInfo?> snapshot) => Text(
              snapshot.connectionState == ConnectionState.done ?
              '${AppLocalizations.of(context)!.appName} ${snapshot.data!.version} (${snapshot.data!.buildNumber})'
                  : '',
            ),
          ),
        ),
        ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 20),
          leading: const SizedBox(
            height: double.infinity,
            child: Icon(Icons.all_inclusive),
          ),
          // TODO i18n
          title: const Text('Codice sorgente'),
          // TODO i18n
          subtitle: const Text("Vai al codice sorgente dell'app"),
          onTap: () => openUrl(context, pubspec.homepage),
        ),
        ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 20),
          leading: const SizedBox(
            height: double.infinity,
            child: Icon(Icons.bug_report, color: Colors.red),
          ),
          // TODO i18n
          title: const Text('Segnala problema'),
          // TODO i18n
          subtitle: const Text("Apri un bug per segnalare un problema con l'app"),
          onTap: () => openUrl(context, pubspec.issueTracker),
        ),
        ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 20),
          leading: SizedBox(
            height: double.infinity,
            child: Icon(Icons.logout, color: Colors.blue.shade600),
          ),
          // TODO i18n
          title: const Text('Disconnetti aereo'),
          // TODO i18n
          subtitle: const Text('Per cambiare aereo e riscaricare i dati'),
          onTap: () => _onLogout(context),
        ),
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
