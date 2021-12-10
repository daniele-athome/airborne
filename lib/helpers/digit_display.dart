
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';

const int kMaxDisplayIntegerDigits = 5;
const double _kDefaultDigitFontSize = 20;

class DigitDisplayFormTextField extends FormField<num> {
  DigitDisplayFormTextField({
    Key? key,
    DigitDisplayController? controller,
    FormFieldSetter<num>? onSaved,
    FormFieldValidator<num>? validator,
    double fontSize = _kDefaultDigitFontSize,
  }) : super(
    key: key,
    onSaved: onSaved,
    initialValue: controller?.value.number,
    validator: validator,
    builder: (field) {
      return DigitDisplayTextField(
        controller: controller,
        fontSize: fontSize,
      );
    },
  );

}

class DigitDisplayTextField extends StatefulWidget {

  const DigitDisplayTextField({
    Key? key,
    this.controller,
    this.fontSize = _kDefaultDigitFontSize,
    this.errorText,
  }) : super(key: key);

  final DigitDisplayController? controller;
  final double fontSize;
  final String? errorText;

  @override
  State<DigitDisplayTextField> createState() => _DigitDisplayTextFieldState();
}

class _DigitDisplayTextFieldState extends State<DigitDisplayTextField> {

  static final _hoursFormatter = NumberFormat("00000.00");

  @override
  Widget build(BuildContext context) {
    if (widget.controller != null && widget.controller!.number > 99999) {
      throw UnsupportedError('Numbers with more than 5 integer digits are not supported.');
    }

    final num number = widget.controller != null ? widget.controller!.number : 0;
    final numDigits = _hoursFormatter.format(number).split('');
    
    final children = <Widget>[];
    bool decimal = false;
    for (var e in numDigits) {
      final digit = int.tryParse(e);
      if (digit == null) {
        decimal = true;
        continue;
      }
      children.add(SingleDigitText(digit: digit, decimal: decimal, fontSize: widget.fontSize));
    }

    final field = Row(
      children: children,
    );
    return widget.errorText != null ?
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            field,
            // TODO text style
            Text(widget.errorText!),
          ],
        ) : field;
  }

}

class DigitDisplayController extends ValueNotifier<DigitDisplay> {
  DigitDisplayController(num number) : super(DigitDisplay(number: number));

  num get number => value.number;

  set number(num newNumber) {
    value = DigitDisplay(number: newNumber);
  }

}

@immutable
class DigitDisplay {

  const DigitDisplay({
    this.number = 0,
  });

  final num number;

}

class SingleDigitText extends StatelessWidget {

  const SingleDigitText({
    Key? key,
    required this.digit,
    this.decimal = false,
    this.fontSize = _kDefaultDigitFontSize,
  }) : assert(digit >= 0 && digit <= 9),
        super(key: key);

  final int digit;
  final bool decimal;
  final double fontSize;

  @override
  Widget build(BuildContext context) =>
      _DigitText(
        text: digit.toString(),
        alternate: decimal,
        fontSize: fontSize,
      );

}

class _DigitText extends StatelessWidget {

  const _DigitText({
    Key? key,
    required this.text,
    this.alternate = false,
    this.fontSize = _kDefaultDigitFontSize,
  }) : super(key: key);

  final String text;
  final bool alternate;
  final double fontSize;

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
    alignment: Alignment.center,
    color: alternate ? null : Colors.black,
    decoration: alternate ? BoxDecoration(
      border: Border.all(color: Colors.black),
      color: Colors.white,
    ) : null,
    // TODO test on different screens
    width: fontSize,
    height: fontSize + 10,
    child: Text(text,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontFamily: 'MajorMonoDisplay',
          fontSize: fontSize,
          fontWeight: FontWeight.bold,
          color: alternate ? Colors.black : Colors.white,
        ),
    ),
  );

}
