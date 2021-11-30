import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';

import '../../helpers/cupertinoplus.dart';
import '../../helpers/digit_display.dart';

class HourListTile extends StatelessWidget {
  const HourListTile({
    Key? key,
    required this.controller,
    required this.hintText,
    this.showIcon = true,
    this.onTap,
  }) : super(key: key);

  final DigitDisplayController controller;
  final String hintText;
  final bool showIcon;
  final GestureTapCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20),
      leading: showIcon ? const SizedBox(height: double.infinity, child: Icon(Icons.timer)) : const Text(''),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // TODO try to replicate InputDecoration floating label text style
          Text(hintText, style: Theme.of(context).textTheme.caption!),
          DigitDisplayFormTextField(
            controller: controller,
            // TODO i18n
            validator: (value) => value == null || value == 0 ?
            'Inserire un orametro valido.' : null,
          ),
        ],
      ),
      onTap: onTap,
    );
  }

}

class CupertinoHourFormRow extends StatelessWidget {
  const CupertinoHourFormRow({
    Key? key,
    required this.controller,
    required this.hintText,
    this.onTap,
  }) : super(key: key);

  final DigitDisplayController controller;
  final String hintText;
  final GestureTapCallback? onTap;

  @override
  Widget build(BuildContext context) {
    // FIXME workaround https://github.com/flutter/flutter/issues/48438
    final TextStyle textStyle = CupertinoTheme.of(context).textTheme.textStyle;

    return CupertinoFormButtonRow(
      onPressed: onTap,
      padding: kDefaultCupertinoFormRowPadding,
      prefix: Text(
        hintText,
        style: textStyle,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          DigitDisplayFormTextField(
            controller: controller,
            // TODO i18n
            validator: (value) => value == null || value == 0 ?
            'Inserire un orametro valido.' : null,
          ),
        ],
      ),
    );
  }

}
