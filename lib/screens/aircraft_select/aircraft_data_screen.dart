import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_platform_widgets/flutter_platform_widgets.dart';
import 'package:future_progress_dialog/future_progress_dialog.dart';
import 'package:logging/logging.dart';
import 'package:provider/provider.dart';
import 'package:validators/validators.dart';

import '../../helpers/aircraft_data.dart';
import '../../helpers/config.dart';
import '../../helpers/utils.dart';

final Logger _log = Logger((AircraftData).toString());

class SetAircraftDataScreen extends StatefulWidget {

  @override
  State<StatefulWidget> createState() => _SetAircraftDataScreenState();

}

class _SetAircraftDataScreenState extends State<SetAircraftDataScreen> {

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  String? _aircraftUrl;
  String? _aircraftPassword;

  @override
  Widget build(BuildContext context) {
    return PlatformScaffold(
      iosContentPadding: true,
      appBar: PlatformAppBar(
        title: Text(AppLocalizations.of(context)!.addAircraft_title),
      ),
      body: Container(
        padding: const EdgeInsets.all(20),
        child: Consumer<AppConfig>(
          builder: (context, appConfig, child) => _buildForm(context, appConfig),
        ),
      ),
    );
  }

  void _showError(String text) {
    showPlatformDialog(
      context: context,
      builder: (_context) => PlatformAlertDialog(
        title: Text(AppLocalizations.of(context)!.dialog_title_error),
        content: Text(text),
        actions: <Widget>[
          PlatformDialogAction(
            onPressed: () {
              Navigator.pop(_context);
            },
            child: Text(AppLocalizations.of(context)!.dialog_button_ok),
          ),
        ],
      ),
    );
  }

  void _downloadData(AppConfig appConfig) {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();

      showPlatformDialog(
        context: context,
        builder: (context) {
          final userpass = _aircraftPassword;
          String? username;
          String? password;
          if (userpass != null) {
            final separator = userpass.indexOf(':');
            if (separator >= 0) {
              username = userpass.substring(0, separator);
              password = userpass.substring(separator + 1);
            }
          }
          return FutureProgressDialog(
            downloadToFile(_aircraftUrl!, 'aircraft.zip', username, password, true).then((value) async {
              _log.finest(value);
              final aircraftData = await _validateAndStoreAircraft(value, appConfig);
              if (aircraftData != null) {
                // FIXME this should be handled with a simple rebuild by MyApp but it doesn't work
                // probably FutureProgressDialog popping the navigator has something to do with it
                WidgetsBinding.instance?.addPostFrameCallback((timeStamp) {
                  appConfig.currentAircraft = aircraftData;
                  Navigator.of(context, rootNavigator: true)
                      .pushReplacementNamed(appConfig.pilotName != null ? '/' : 'pilot-select');
                });
              }
            }).catchError((error, StackTrace? stacktrace) {
              _log.info('DOWNLOAD ERROR', error, stacktrace);
              // TODO analyze exception somehow (e.g. TimeoutException)
              WidgetsBinding.instance?.addPostFrameCallback((timeStamp) {
                _showError(getExceptionMessage(error));
              });
            }),
            message: Text(AppLocalizations.of(context)!.addAircraft_dialog_downloading),
          );
        },
      ).then((value) async {
        if (value != null) {
          // FIXME this should be handled with a simple rebuild by MyApp but it doesn't work
          // probably FutureProgressDialog popping the navigator has something to do with it
          WidgetsBinding.instance?.addPostFrameCallback((timeStamp) {
            Navigator.of(context, rootNavigator: true)
                .pushReplacementNamed(appConfig.pilotName != null ? '/' : 'pilot-select');
          });
        }
      });
    }
  }

  Future<AircraftData?> _validateAndStoreAircraft(File file, AppConfig appConfig) async {
    final reader = AircraftDataReader(dataFile: file);
    final validation = await reader.validate();
    _log.finest('VALIDATION: $validation');
    if (validation) {
      try {
        final dataFile = await addAircraftDataFile(reader);
        _log.finest(dataFile);
        await reader.open();
        final aircraftData = reader.toAircraftData();
        appConfig.addAircraft(aircraftData);
        return aircraftData;
      }
      catch (e, stacktrace) {
        _log.warning('Error storing aircraft data file', e, stacktrace);
        WidgetsBinding.instance?.addPostFrameCallback((timeStamp) {
          _showError(AppLocalizations.of(context)!.addAircraft_error_storing);
        });
      }
    }
    else {
      WidgetsBinding.instance?.addPostFrameCallback((timeStamp) {
        _showError(AppLocalizations.of(context)!.addAircraft_error_invalid_datafile);
      });
      return null;
    }
  }

  Widget _buildForm(BuildContext context, AppConfig appConfig) =>
    Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(AppLocalizations.of(context)!.addAircraft_text1,
            style: const TextStyle(fontSize: 16)),
          const SizedBox(
            height: 5,
          ),
          PlatformTextFormField(
            material: (context, platform) => MaterialTextFormFieldData(
              decoration: InputDecoration(
                hintText: AppLocalizations.of(context)!.addAircraft_hint_address,
              ),
            ),
            cupertino: (context, platform) => CupertinoTextFormFieldData(
            ),
            onSaved: (newValue) => _aircraftUrl = newValue,
            validator: (String? value) {
              if (value == null || value.isEmpty || !isURL(value, protocols: ['http', 'https'], requireProtocol: true)) {
                return AppLocalizations.of(context)!.addAircraft_error_invalid_address;
              }
              return null;
            },
          ),
          PlatformTextFormField(
            obscureText: true,
            enableSuggestions: false,
            keyboardType: TextInputType.visiblePassword,
            onSaved: (newValue) => _aircraftPassword = newValue,
            material: (context, platform) => MaterialTextFormFieldData(
              decoration: InputDecoration(
                hintText: AppLocalizations.of(context)!.addAircraft_hint_password,
              ),
            ),
            cupertino: (context, platform) => CupertinoTextFormFieldData(
            ),
          ),
          const SizedBox(
            height: 10,
          ),
          PlatformButton(
            onPressed: () => _downloadData(appConfig),
            child: Text(AppLocalizations.of(context)!.addAircraft_button_install),
            //cupertinoFilled: (_, __) => CupertinoFilledButtonData(),
          ),
        ],
      )
    );


}
