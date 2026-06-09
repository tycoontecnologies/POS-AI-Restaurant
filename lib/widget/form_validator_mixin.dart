// form_validator_mixin.dart
mixin FormValidatorMixin {
  final Map<String, String?> _fieldErrors = {};
  final Map<String, dynamic> _fieldValues = {};

  void setFieldError(String fieldName, String? error) {
    _fieldErrors[fieldName] = error;
  }

  String? getFieldError(String fieldName) {
    return _fieldErrors[fieldName];
  }

  void setFieldValue(String fieldName, dynamic value) {
    _fieldValues[fieldName] = value;
  }

  dynamic getFieldValue(String fieldName) {
    return _fieldValues[fieldName];
  }

  bool validateForm() {
    _fieldErrors.removeWhere((key, value) => value == null);
    return _fieldErrors.isEmpty;
  }

  void clearErrors() {
    _fieldErrors.clear();
  }

  Map<String, dynamic> toJson() {
    return Map.from(_fieldValues);
  }
}