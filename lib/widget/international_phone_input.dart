// international_phone_input.dart
import 'package:flutter/material.dart';
import 'package:intl_phone_field/intl_phone_field.dart';
import 'package:intl_phone_field/phone_number.dart';

class InternationalPhoneInput extends FormField<String> {
  InternationalPhoneInput({
    Key? key,
    required String label,
    required TextEditingController controller,
    String? initialValue,
    String? initialCountryCode,
    bool required = true,
    String? Function(String?)? validator,
    Function(PhoneNumber)? onChanged,
  }) : super(
         key: key,
         initialValue: initialValue ?? '',
         validator: (value) {
           final fullNumber = value ?? '';

           if (required && fullNumber.trim().isEmpty) {
             return 'Phone number is required';
           }

           if (fullNumber.isNotEmpty) {
             final cleaned = fullNumber.replaceAll(RegExp(r'[^0-9+]'), '');
             final phoneRegex = RegExp(r'^\+?[0-9]{8,15}$');
             if (!phoneRegex.hasMatch(cleaned)) {
               return 'Enter a valid phone number';
             }
           }

           return validator?.call(fullNumber);
         },
         builder: (FormFieldState<String> state) {
           return Column(
             crossAxisAlignment: CrossAxisAlignment.start,
             children: [
               IntlPhoneField(
                 controller: controller,
                 initialCountryCode: initialCountryCode ?? 'US',
                 decoration: InputDecoration(
                   labelText: label,
                   border: const OutlineInputBorder(),
                   errorText: state.errorText,
                 ),
                 onChanged: (phone) {
                   controller.text = phone.completeNumber;
                   state.didChange(phone.completeNumber);
                   onChanged?.call(phone);
                 },
               ),
             ],
           );
         },
       );
}
