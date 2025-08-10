import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

const int kMaxDisplayIntegerDigits = 5;
const double _kDefaultDigitFontSize = 20;
const EdgeInsetsGeometry _kDefaultDigitPadding =
    EdgeInsets.symmetric(vertical: 4);
const String kDigitDisplayFontName = 'MajorMonoDisplay';
final NumberFormat kHoursFormatter = NumberFormat("00000.00");

class DigitDisplayFormTextField extends FormField<num> {
  DigitDisplayFormTextField({
    super.key,
    DigitDisplayController? controller,
    super.onSaved,
    super.validator,
    double fontSize = _kDefaultDigitFontSize,
    EdgeInsetsGeometry padding = _kDefaultDigitPadding,
  }) : super(
          initialValue: controller?.value.number,
          builder: (field) {
            return DigitDisplayTextField(
              controller: controller,
              fontSize: fontSize,
              padding: padding,
            );
          },
        );
}

class DigitDisplayTextField extends StatefulWidget {
  const DigitDisplayTextField({
    super.key,
    this.controller,
    this.fontSize = _kDefaultDigitFontSize,
    this.errorText,
    this.padding = _kDefaultDigitPadding,
    this.enabled = false,
  });

  final DigitDisplayController? controller;
  final double fontSize;
  final String? errorText;
  final EdgeInsetsGeometry padding;
  final bool enabled;

  @override
  State<DigitDisplayTextField> createState() => _DigitDisplayTextFieldState();
}

class _DigitDisplayTextFieldState extends State<DigitDisplayTextField> {
  @override
  Widget build(BuildContext context) {
    if (widget.controller != null && widget.controller!.number > 99999) {
      throw UnsupportedError(
          'Numbers with more than 5 integer digits are not supported.');
    }

    final num number =
        widget.controller != null ? widget.controller!.number : 0;
    final numDigits = kHoursFormatter.format(number).split('');

    final children = <Widget>[];
    bool decimal = false;
    int i = 0;
    for (var e in numDigits) {
      final digit = int.tryParse(e);
      if (digit == null) {
        decimal = true;
        continue;
      }
      final digitNumber = i++;
      children.add(Padding(
        padding: widget.padding,
        child: SingleDigitText(
          digit: digit,
          decimal: decimal,
          fontSize: widget.fontSize,
          active: widget.controller?.activeDigit == digitNumber,
          onTap: widget.enabled
              ? () {
                  if (widget.controller != null) {
                    setState(() {
                      widget.controller?.activeDigit = digitNumber;
                    });
                  }
                }
              : null,
        ),
      ));
    }

    final field = Row(
      children: children,
    );
    return widget.errorText != null
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              field,
              // TODO text style
              Text(widget.errorText!),
            ],
          )
        : field;
  }
}

class DigitDisplayController extends ValueNotifier<DigitDisplay> {
  DigitDisplayController(num number, [int? activeDigit])
      : super(DigitDisplay(number: number, activeDigit: activeDigit));

  num get number => value.number;

  set number(num newNumber) {
    value = DigitDisplay(
      number: newNumber,
      activeDigit: value.activeDigit,
    );
  }

  int? get activeDigit => value.activeDigit;

  set activeDigit(int? digit) {
    value = DigitDisplay(
      number: value.number,
      activeDigit: digit,
    );
  }
}

@immutable
class DigitDisplay {
  const DigitDisplay({
    this.number = 0,
    this.activeDigit,
  });

  final num number;
  final int? activeDigit;
}

class SingleDigitText extends StatelessWidget {
  const SingleDigitText({
    super.key,
    required this.digit,
    this.decimal = false,
    this.fontSize = _kDefaultDigitFontSize,
    this.active = false,
    this.onTap,
  }) : assert(digit >= 0 && digit <= 9);

  final int digit;
  final bool decimal;
  final double fontSize;
  final bool active;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => _DigitText(
        text: digit.toString(),
        alternate: decimal,
        fontSize: fontSize,
        active: active,
        onTap: onTap,
      );
}

class _DigitText extends StatelessWidget {
  const _DigitText({
    // ignore: unused_element_parameter
    super.key,
    required this.text,
    this.alternate = false,
    this.fontSize = _kDefaultDigitFontSize,
    this.active = false,
    this.onTap,
  });

  final String text;
  final bool alternate;
  final double fontSize;
  final bool active;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final widget = Container(
      alignment: Alignment.center,
      // weird combination of sizes to make the active border appear on the inside of the digit
      padding: EdgeInsets.symmetric(
          horizontal: active ? 1 : 2, vertical: active ? 1 : 2),
      decoration: alternate
          ? BoxDecoration(
              border: Border.all(
                  color: active ? Colors.red : Colors.black,
                  width: active ? 2 : 1),
              color: Colors.white,
            )
          : BoxDecoration(
              border: Border.all(
                  color: active ? Colors.red : Colors.black,
                  width: active ? 2 : 1),
              color: Colors.black,
            ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontFamily: kDigitDisplayFontName,
          fontSize: fontSize,
          fontWeight: FontWeight.bold,
          color: alternate ? Colors.black : Colors.white,
        ),
      ),
    );
    return onTap != null
        ? GestureDetector(
            onTap: onTap,
            child: widget,
          )
        : widget;
  }
}
