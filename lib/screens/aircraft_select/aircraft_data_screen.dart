import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_platform_widgets/flutter_platform_widgets.dart';
import 'package:future_progress_dialog/future_progress_dialog.dart';
import 'package:provider/provider.dart';
import 'package:validators/validators.dart';

import '../../helpers/aircraft_data.dart';
import '../../helpers/config.dart';
import '../../helpers/utils.dart';

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
        // TODO i18n
        title: Text('Setup aircraft'),
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
        // TODO i18n
        title: Text('Errore'),
        // TODO i18n
        content: Text(text),
        actions: <Widget>[
          PlatformDialogAction(
            onPressed: () {
              Navigator.pop(_context);
            },
            // TODO i18n
            child: Text('OK'),
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
          String? username, password;
          if (userpass != null) {
            final separator = userpass.indexOf(':');
            if (separator >= 0) {
              username = userpass.substring(0, separator);
              password = userpass.substring(separator + 1);
            }
          }
          return FutureProgressDialog(
            downloadToFile(_aircraftUrl!, 'aircraft.zip', username, password, true).then((value) async {
              print(value);
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
            }).catchError((error, stacktrace) {
              print('DOWNLOAD ERROR');
              print(error);
              // TODO analyze exception somehow (e.g. TimeoutException)
              WidgetsBinding.instance?.addPostFrameCallback((timeStamp) {
                _showError(getExceptionMessage(error));
              });
            }),
            // TODO i18n
            message: const Text('Downloading...'),
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
    print('VALIDATION: $validation');
    if (validation) {
      try {
        final dataFile = await addAircraftDataFile(reader);
        print(dataFile);
        await reader.open();
        final aircraftData = reader.toAircraftData();
        appConfig.addAircraft(aircraftData);
        return aircraftData;
      }
      catch (e, stacktrace) {
        print(e);
        print(stacktrace);
        WidgetsBinding.instance?.addPostFrameCallback((timeStamp) {
          // TODO i18n
          _showError('Unable to store aircraft data file.');
        });
      }
    }
    else {
      WidgetsBinding.instance?.addPostFrameCallback((timeStamp) {
        // TODO i18n
        _showError('Not a valid aircraft data file.');
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
          // TODO i18n
          Text('Please type in the address to the aircraft data and its password.',
            style: const TextStyle(fontSize: 16)),
          const SizedBox(
            height: 5,
          ),
          PlatformTextFormField(
            material: (context, platform) => MaterialTextFormFieldData(
              decoration: const InputDecoration(
                hintText: 'Aircraft data address',
              ),
            ),
            cupertino: (context, platform) => CupertinoTextFormFieldData(
            ),
            onSaved: (newValue) => _aircraftUrl = newValue,
            validator: (String? value) {
              if (value == null || value.isEmpty || !isURL(value, protocols: ['http', 'https'], requireProtocol: true)) {
                // TODO i18n
                return 'Please insert a valid address';
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
              decoration: const InputDecoration(
                hintText: 'Password',
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
            // TODO i18n
            child: Text('Install'),
            //cupertinoFilled: (_, __) => CupertinoFilledButtonData(),
          ),
        ],
      )
    );


}
