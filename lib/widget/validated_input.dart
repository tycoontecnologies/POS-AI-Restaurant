// validated_input.dart
import 'package:flutter/material.dart';
import 'package:pos/utils/validation_utils.dart';

enum InputType {
  text,
  email,
  phone,
  number,
  integer,
  positiveNumber,
  multiline,
}

class ValidatedInput extends StatefulWidget {
  final String label;
  final String? hint;
  final TextEditingController controller;
  final InputType type;
  final String fieldName;
  final bool required;
  final int? minLength;
  final int? maxLength;
  final Widget? prefixIcon;
  final TextInputType? keyboardType;
  final int? maxLines;
  final Function(String)? onChanged;
  final Function(String)? onSubmitted;
  final bool autoFocus;
  final String? initialValue;
  final String? Function(String?)? validator;

  const ValidatedInput({
    super.key,
    required this.label,
    required this.controller,
    this.type = InputType.text,
    this.fieldName = 'This field',
    this.validator,
    this.required = true,
    this.minLength,
    this.maxLength,
    this.hint,
    this.prefixIcon,
    this.keyboardType,
    this.maxLines,
    this.onChanged,
    this.onSubmitted,
    this.autoFocus = false,
    this.initialValue,
  });

  @override
  State<ValidatedInput> createState() => _ValidatedInputState();
}

class _ValidatedInputState extends State<ValidatedInput> {
  String? _errorText;

  void _validate(String value) {
    setState(() {
      _errorText = _getValidationError(value);
    });
  }

  String? _getValidationError(String value) {
    if (!widget.required && value.isEmpty) return null;

    if (widget.required) {
      final requiredError = ValidationUtils.validateRequired(
        value,
        widget.fieldName,
      );
      if (requiredError != null) return requiredError;
    }

    switch (widget.type) {
      case InputType.email:
        return ValidationUtils.validateEmail(value);
      case InputType.phone:
        return ValidationUtils.validatePhone(value);
      case InputType.number:
        return ValidationUtils.validateNumber(value, widget.fieldName);
      case InputType.integer:
        return ValidationUtils.validateInteger(value, widget.fieldName);
      case InputType.positiveNumber:
        return ValidationUtils.validatePositiveNumber(value, widget.fieldName);
      default:
        break;
    }

    if (widget.minLength != null) {
      final minError = ValidationUtils.validateMinLength(
        value,
        widget.minLength!,
        widget.fieldName,
      );
      if (minError != null) return minError;
    }

    if (widget.maxLength != null) {
      final maxError = ValidationUtils.validateMaxLength(
        value,
        widget.maxLength!,
        widget.fieldName,
      );
      if (maxError != null) return maxError;
    }

    return null;
  }

  bool get isValid => _errorText == null;

  @override
  void initState() {
    super.initState();
    if (widget.initialValue != null) {
      widget.controller.text = widget.initialValue!;
      _validate(widget.initialValue!);
    }
    widget.controller.addListener(() {
      _validate(widget.controller.text);
    });
  }

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: widget.controller,
      validator: widget.validator,
      decoration: InputDecoration(
        labelText: widget.label,
        hintText: widget.hint,
        errorText: _errorText,
        prefixIcon: widget.prefixIcon,
        border: const OutlineInputBorder(),
      ),
      keyboardType: widget.keyboardType ?? _getKeyboardType(),
      maxLines: widget.maxLines ?? (widget.type == InputType.multiline ? 3 : 1),
      onChanged: (value) {
        _validate(value);
        widget.onChanged?.call(value);
      },
      onFieldSubmitted: widget.onSubmitted,
      autofocus: widget.autoFocus,
    );
  }

  TextInputType _getKeyboardType() {
    switch (widget.type) {
      case InputType.email:
        return TextInputType.emailAddress;
      case InputType.phone:
        return TextInputType.phone;
      case InputType.number:
      case InputType.positiveNumber:
        return TextInputType.numberWithOptions(decimal: true);
      case InputType.integer:
        return TextInputType.number;
      default:
        return TextInputType.text;
    }
  }
}
