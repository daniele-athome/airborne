import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_platform_widgets/flutter_platform_widgets.dart';

import '../../helpers/cupertinoplus.dart';
import '../../helpers/digit_display.dart';

class HourListTile extends StatefulWidget {
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
  State<HourListTile> createState() => _HourListTileState();
}

class _HourListTileState extends State<HourListTile> {

  late DigitDisplayController _controller;

  @override
  void initState() {
    super.initState();
    _controller = DigitDisplayController(widget.controller.number);
  }

  _onTap(BuildContext context) {
    Widget pageRouteBuilder(BuildContext _context) => PlatformScaffold(
      appBar: PlatformAppBar(
        title: Text(widget.hintText),
        trailingActions: [PlatformIconButton(
          onPressed: () {
            Navigator.pop(_context, _controller.number);
          },
          icon: const Icon(Icons.check),
          material: (_, __) => MaterialIconButtonData(
            // FIXME maybe another tooltip?
            tooltip: AppLocalizations.of(context)!.dialog_button_done,
          ),
        )],
      ),
      body: HourMeterDialog(
        initialValue: widget.controller.number,
        onChanged: (value) => _controller.number = value,
      ),
    );

    Navigator.of(context, rootNavigator: true)
        .push(MaterialPageRoute(
      builder: pageRouteBuilder,
    )).then((value) {
      if (value != null) {
        setState(() {
          widget.controller.number = value;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20),
      leading: widget.showIcon ? const SizedBox(height: double.infinity, child: Icon(Icons.timer)) : const Text(''),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // TODO try to replicate InputDecoration floating label text style
          Text(widget.hintText, style: Theme.of(context).textTheme.caption!),
          DigitDisplayFormTextField(
            controller: widget.controller,
            // TODO i18n
            validator: (value) => value == null || value == 0 ?
            'Inserire un orametro valido.' : null,
          ),
        ],
      ),
      onTap: widget.onTap ?? () => _onTap(context),
    );
  }
}

class CupertinoHourFormRow extends StatefulWidget {
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
  State<CupertinoHourFormRow> createState() => _CupertinoHourFormRowState();
}

class _CupertinoHourFormRowState extends State<CupertinoHourFormRow> {

  late DigitDisplayController _controller;

  @override
  void initState() {
    super.initState();
    _controller = DigitDisplayController(widget.controller.number);
  }

  _onPressed(BuildContext context) {
    Widget pageRouteBuilder(BuildContext _context) => PlatformScaffold(
      iosContentPadding: true,
      appBar: PlatformAppBar(
        title: Text(widget.hintText),
        trailingActions: [PlatformTextButton(
          onPressed: () {
            Navigator.pop(_context, _controller.number);
          },
          cupertino: (_, __) => CupertinoTextButtonData(
            // workaround for https://github.com/flutter/flutter/issues/32701
            padding: EdgeInsets.zero,
          ),
          child: Text(AppLocalizations.of(context)!.dialog_button_done),
        )],
      ),
      cupertino: (context, platform) => CupertinoPageScaffoldData(
        backgroundColor: kCupertinoDialogScaffoldBackgroundColor(context),
      ),
      body: HourMeterDialog(
        initialValue: widget.controller.number,
        onChanged: (value) => _controller.number = value,
      ),
    );

    Navigator.of(context, rootNavigator: true)
        .push(CupertinoPageRoute(
      builder: pageRouteBuilder,
    )).then((value) {
      if (value != null) {
        setState(() {
          widget.controller.number = value;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // FIXME workaround https://github.com/flutter/flutter/issues/48438
    final TextStyle textStyle = CupertinoTheme.of(context).textTheme.textStyle;

    return CupertinoFormButtonRow(
      onPressed: widget.onTap ?? () => _onPressed(context),
      padding: kDefaultCupertinoFormRowPadding,
      prefix: Text(
        widget.hintText,
        style: textStyle,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          DigitDisplayFormTextField(
            controller: widget.controller,
            // TODO i18n
            validator: (value) => value == null || value == 0 ?
            'Inserire un orametro valido.' : null,
          ),
        ],
      ),
    );
  }
}

class HourMeterDialog extends StatefulWidget {
  const HourMeterDialog({
    Key? key,
    required this.initialValue,
    this.onChanged,
    this.onConfirm,
    this.onCancel,
  }) : super(key: key);

  final num initialValue;
  final Function(num value)? onChanged;
  final Function(num value)? onConfirm;
  final Function()? onCancel;

  @override
  State<HourMeterDialog> createState() => _HourMeterDialogState();
}

class _HourMeterDialogState extends State<HourMeterDialog> {

  late DigitDisplayController _controller;

  late Color _disabledButtonBackgroundColor;
  late TextStyle _textStyle;

  @override
  void initState() {
    _controller = DigitDisplayController(widget.initialValue, 0);
    super.initState();
  }

  /// Insipired by https://github.com/eopeter/flutter_dialpad
  _buildNumberButton(BuildContext context, String value, {
    String? text,
    bool enabled = true,
  }) {
    // TODO fix this number
    final sizeFactor = MediaQuery.of(context).size.height * 0.12;
    final darkMode = (isCupertino(context) ? CupertinoTheme.brightnessOf(context)
        : Theme.of(context).brightness) == Brightness.dark;

    return isCupertino(context) ?
    ClipOval(
      child: CupertinoInkWell(
        backgroundColor: enabled ? (darkMode ? Colors.white24 : Colors.black38) : _disabledButtonBackgroundColor,
        onPressed: enabled ? () => _onPressed(value) : null,
        child: SizedBox(
          height: sizeFactor,
          width: sizeFactor,
          child: Center(
            child: Text(text ?? value,
              style: _textStyle.copyWith(
                color: Colors.white,
              ),
            ),
          ),
        ),
      ),
    ) :
    InkResponse(
      onTap: enabled ? () => _onPressed(value) : null,
      radius: math.max(
        Material.defaultSplashRadius,
        sizeFactor * 0.7,
        // x 0.5 for diameter -> radius and + 40% overflow derived from other Material apps.
      ),
      child: SizedBox(
        height: sizeFactor,
        width: sizeFactor,
        child: Align(
          alignment: Alignment.center,
          child: Text(
            text ?? value,
            style: _textStyle,
          ),
        ),
      ),
    );
  }

  _onPressed(String value) {
    setState(() {
      final activeDigit = _controller.activeDigit!;
      int offset = (activeDigit >= kMaxDisplayIntegerDigits) ? 1 : 0;
      final number = kHoursFormatter.format(_controller.number)
          .replaceRange(activeDigit + offset, activeDigit + offset + 1, value);
      if (activeDigit < 6) {
        _controller.activeDigit = activeDigit + 1;
      }
      _controller.number = double.parse(number);
    });
    if (mounted && widget.onChanged != null) {
      widget.onChanged!(_controller.number);
    }
  }

  _onBackspace() {
    setState(() {
      final activeDigit = _controller.activeDigit!;
      // clear current digit and go backwards
      int offset = (activeDigit >= kMaxDisplayIntegerDigits) ? 1 : 0;
      final number = kHoursFormatter.format(_controller.number)
          .replaceRange(activeDigit + offset, activeDigit + offset + 1, '0');
      if (activeDigit > 0) {
        _controller.activeDigit = activeDigit - 1;
      }
      _controller.number = double.parse(number);
      /*
      if (_mode == _HourMeterDigitState.willReset) {
        _controller.number = 0;
        _mode = _HourMeterDigitState.integralPart;
        _controller.activeDigit = 4;
      }
      else if (_mode == _HourMeterDigitState.integralPart) {
        final number = _controller.number.toString();
        _controller.number = number.length > 1 ? int.parse(number.substring(0, number.length - 1)) : 0;
      }
      else if (_mode == _HourMeterDigitState.fractionalDigit1) {
        _mode = _HourMeterDigitState.integralPart;
        _controller.activeDigit = 4;
      }
      else if (_mode == _HourMeterDigitState.fractionalDigit2) {
        _controller.number = _controller.number.toInt();
        _mode = _HourMeterDigitState.fractionalDigit1;
        _controller.activeDigit = 5;
      }
      else if (_mode == _HourMeterDigitState.ended) {
        _controller.number = (_controller.number * 10).toInt() / 10;
        _mode = _HourMeterDigitState.fractionalDigit2;
        _controller.activeDigit = 6;
      }
       */
    });
    if (mounted && widget.onChanged != null) {
      widget.onChanged!(_controller.number);
    }
  }

  Widget _buildNumberPad(BuildContext context) {
    final padding = EdgeInsets.symmetric(vertical: isCupertino(context) ? 12 : 4);
    return Center(
      child: Column(
        children: [
          Padding(
            padding: padding,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildNumberButton(context, '1'),
                _buildNumberButton(context, '2'),
                _buildNumberButton(context, '3'),
              ],
            ),
          ),
          Padding(
            padding: padding,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildNumberButton(context, '4'),
                _buildNumberButton(context, '5'),
                _buildNumberButton(context, '6'),
              ],
            ),
          ),
          Padding(
            padding: padding,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildNumberButton(context, '7'),
                _buildNumberButton(context, '8'),
                _buildNumberButton(context, '9'),
              ],
            ),
          ),
          Padding(
            padding: padding,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildNumberButton(context, '0'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  double _getDigitDisplayFontSize(BuildContext context) {
    final mdq = MediaQuery.of(context);
    final paddingRatio = (mdq.size.width * 0.08).roundToDouble();
    final size = ((mdq.size.width - paddingRatio - 48) / 7).roundToDouble();
    return math.min(size, 42);
  }

  // FIXME not nice on landscape orientation
  Widget _buildMaterialNumberPad(BuildContext context) =>
    Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            DigitDisplayTextField(
              controller: _controller,
              fontSize: _getDigitDisplayFontSize(context),
              enabled: true,
            ),
            IconButton(
              // TODO onLongPress should reset the value
              onPressed: _onBackspace,
              icon: const Icon(Icons.backspace),
            ),
          ],
        ),
        Flexible(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: _buildNumberPad(context),
            )
        ),
      ],
    );

  // FIXME not nice on landscape orientation
  Widget _buildCupertinoNumberPad(BuildContext context) =>
    Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            DigitDisplayTextField(
              controller: _controller,
              fontSize: _getDigitDisplayFontSize(context),
              enabled: true,
            ),
            CupertinoButton(
              // TODO onLongPress should reset the value
              onPressed: _onBackspace,
              child: const Icon(Icons.backspace, size: 32),
            ),
          ],
        ),
        Flexible(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: _buildNumberPad(context),
          )
        ),
      ],
    );

  @override
  Widget build(BuildContext context) {
    if (isCupertino(context)) {
      _disabledButtonBackgroundColor = CupertinoColors.secondarySystemFill.resolveFrom(context);
      _textStyle = CupertinoTheme.of(context).textTheme.navLargeTitleTextStyle;
    }
    else {
      _disabledButtonBackgroundColor = Theme.of(context).colorScheme.primary;
      _textStyle = Theme.of(context).textTheme.button!.copyWith(
        fontSize: Theme.of(context).textTheme.headline4!.fontSize,
      );
    }

    return isCupertino(context) ?
      _buildCupertinoNumberPad(context) :
      _buildMaterialNumberPad(context);
  }

}
