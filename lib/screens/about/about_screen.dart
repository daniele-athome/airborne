import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_platform_widgets/flutter_platform_widgets.dart';
// TODO import 'package:logging/logging.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';

import '../../helpers/config.dart';
import '../../helpers/cupertinoplus.dart';
import '../../helpers/utils.dart';
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
      title: AppLocalizations.of(context)!.about_disconnect_confirm_title,
      text: AppLocalizations.of(context)!.about_disconnect_confirm_message,
      destructiveOk: true,
      okCallback: () {
        _appConfig.pilotName = null;
        _appConfig.currentAircraft = null;
        Navigator.of(context, rootNavigator: true).popAndPushNamed('aircraft-data');
      },
    );
  }

  List<Widget> _buildCupertinoItems(BuildContext context) => [
    CupertinoFormSection(
      header: Text(AppLocalizations.of(context)!.about_aircraft_info.toUpperCase()),
      children: [
        CupertinoFormRowContainer(
          child: CupertinoFormRow(
            padding: kDefaultCupertinoFormRowPadding,
            prefix: Text(AppLocalizations.of(context)!.about_aircraft_callsign),
            child: Text(_appConfig.currentAircraft!.callSign,
              style: CupertinoTheme.of(context).textTheme.textStyle.copyWith(fontWeight: FontWeight.bold)),
          ),
        ),
        CupertinoFormRowContainer(
          child: CupertinoFormButtonRow(
            onPressed: () => openUrl(context, _appConfig.locationUrl),
            padding: kDefaultCupertinoFormRowPadding,
            prefix: Text(AppLocalizations.of(context)!.about_aircraft_hangar),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(_appConfig.locationName),
                const SizedBox(width: 2),
                Icon(CupertinoIcons.chevron_forward, color: CupertinoColors.tertiaryLabel.resolveFrom(context)),
              ],
            ),
          ),
        ),
      ],
    ),
    CupertinoFormSection(
      header: Text(AppLocalizations.of(context)!.about_aircraft_pilots.toUpperCase()),
      children: [
        ..._appConfig.pilotNames.map((e) => CupertinoFormRowContainer(
          child: Padding(
            padding: kDefaultCupertinoFormRowPadding,
            child: Row(
              children: [
                CircleAvatar(backgroundImage: _appConfig.getPilotAvatar(e)),
                const SizedBox(width: 14),
                Expanded(child: Text(e)),
              ],
            ),
          ),
        )),
      ],
    ),
    CupertinoFormSection(
      header: Text(AppLocalizations.of(context)!.appName.toUpperCase()),
      children: [
        CupertinoFormRowContainer(
          child: CupertinoFormRow(
            padding: kDefaultCupertinoFormRowPadding,
            prefix: Text(AppLocalizations.of(context)!.about_app_version),
            child: FutureBuilder(
              future: PackageInfo.fromPlatform(),
              initialData: null,
              builder: (context, AsyncSnapshot<PackageInfo?> snapshot) => Text(
                snapshot.connectionState == ConnectionState.done ?
                '${AppLocalizations.of(context)!.appName} ${snapshot.data!.version} (${snapshot.data!.buildNumber})'
                    : '',
              ),
            ),
          ),
        ),
        CupertinoFormRowContainer(
          child: CupertinoFormButtonRow(
            onPressed: () => openUrl(context, pubspec.homepage),
            padding: kDefaultCupertinoFormRowPadding,
            prefix: Text(AppLocalizations.of(context)!.about_app_homepage),
            child: Icon(CupertinoIcons.chevron_forward, color: CupertinoColors.tertiaryLabel.resolveFrom(context)),
          ),
        ),
        CupertinoFormRowContainer(
          child: CupertinoFormButtonRow(
            onPressed: () => openUrl(context, pubspec.issueTracker),
            padding: kDefaultCupertinoFormRowPadding,
            prefix: Text(AppLocalizations.of(context)!.about_app_issues),
            child: Icon(CupertinoIcons.chevron_forward, color: CupertinoColors.tertiaryLabel.resolveFrom(context)),
          ),
        ),
      ],
    ),
    const SizedBox(height: kDefaultCupertinoFormSectionMargin),
    CupertinoFormSection(children: <Widget>[
      Row(
        children: [
          Expanded(
            child: CupertinoButton(
              onPressed: () => _onLogout(context),
              child: Text(AppLocalizations.of(context)!.about_app_disconnect_aircraft,
                style: const TextStyle(color: CupertinoColors.destructiveRed),
              ),
            ),
          ),
        ],
      )
    ]),
  ];

  List<Widget> _buildMaterialItems(BuildContext context) => [
    HeaderListTile(AppLocalizations.of(context)!.about_aircraft_info, first: true),
    ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20),
      subtitle: Text(AppLocalizations.of(context)!.about_aircraft_callsign),
      title: Text(_appConfig.currentAircraft!.callSign,
        style: Theme.of(context).textTheme.headline6!.copyWith(fontWeight: FontWeight.bold),
      ),
    ),
    ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20),
      subtitle: Text(AppLocalizations.of(context)!.about_aircraft_hangar),
      title: Text(_appConfig.locationName,
        style: Theme.of(context).textTheme.headline6,
      ),
      trailing: IconButton(
        onPressed: () => openUrl(context, _appConfig.locationUrl),
        tooltip: AppLocalizations.of(context)!.about_aircraft_hangar_open_maps,
        icon: const Icon(Icons.open_in_new),
      ),
    ),
    HeaderListTile(AppLocalizations.of(context)!.about_aircraft_pilots),
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
      subtitle: Text(AppLocalizations.of(context)!.about_app_version),
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
      title: Text(AppLocalizations.of(context)!.about_app_homepage),
      subtitle: Text(AppLocalizations.of(context)!.about_app_homepage_subtitle),
      onTap: () => openUrl(context, pubspec.homepage),
    ),
    ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20),
      leading: const SizedBox(
        height: double.infinity,
        child: Icon(Icons.bug_report, color: Colors.red),
      ),
      title: Text(AppLocalizations.of(context)!.about_app_issues),
      subtitle: Text(AppLocalizations.of(context)!.about_app_issues_subtitle),
      onTap: () => openUrl(context, pubspec.issueTracker),
    ),
    ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20),
      leading: SizedBox(
        height: double.infinity,
        child: Icon(Icons.logout, color: Colors.blue.shade600),
      ),
      title: Text(AppLocalizations.of(context)!.about_app_disconnect_aircraft),
      subtitle: Text(AppLocalizations.of(context)!.about_app_disconnect_aircraft_subtitle),
      onTap: () => _onLogout(context),
    ),
  ];
  
  @override
  Widget build(BuildContext context) {
    return Container(
      color: isCupertino(context) ? CupertinoColors.systemGroupedBackground.resolveFrom(context) :
      Theme.of(context).scaffoldBackgroundColor,
      child: ListView(
        children: [
          Stack(
            children: [
              Positioned(
                // TODO not very good sizing and loading indicator
                child: Image(
                  image: _appConfig.aircraftPicture,
                  frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
                    if (wasSynchronouslyLoaded) {
                      return child;
                    }
                    return Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(minHeight: 250),
                        child: AnimatedOpacity(
                          opacity: frame == null ? 0 : 1,
                          duration: const Duration(milliseconds: 400),
                          curve: Curves.easeOut,
                          child: child,
                        ),
                      ),
                    );
                  },
                  loadingBuilder: (BuildContext context, Widget child, ImageChunkEvent? loadingProgress) {
                    return loadingProgress != null ?
                      Container(
                        height: 250,
                        alignment: Alignment.center,
                        child: const CircularProgressIndicator.adaptive(),
                      ) :
                      child;
                  },
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
                      // TODO is this the right color? I'm getting confused...
                      color: isCupertino(context) ? CupertinoColors.systemGroupedBackground.resolveFrom(context) :
                        Theme.of(context).scaffoldBackgroundColor,
                      boxShadow: const [
                        BoxShadow(
                          color: Colors.black54,
                          offset: Offset(0.0, -1.0),
                          blurRadius: 5.0,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          ...isCupertino(context) ?
            _buildCupertinoItems(context) :
            _buildMaterialItems(context),
        ],
      ),
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
