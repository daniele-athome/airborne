import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
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
        Padding(
          padding: const EdgeInsets.only(left: 20, right: 20, bottom: 10),
          // TODO i18n
          child: Text('Aeromobile', style: Theme.of(context).textTheme.headline5),
        ),
        ...List.generate(20, (index) => ListTile(
          title: Text('Item $index'),
        )),
        //AboutListTile(),
      ],
    );
  }
}
