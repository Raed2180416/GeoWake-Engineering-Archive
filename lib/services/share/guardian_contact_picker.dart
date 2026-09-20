import 'package:flutter/services.dart';

class PickedGuardianContact {
  final String displayName;
  final String phoneNumber;

  const PickedGuardianContact({
    required this.displayName,
    required this.phoneNumber,
  });

  factory PickedGuardianContact.fromMap(Map<Object?, Object?> map) {
    return PickedGuardianContact(
      displayName: (map['displayName'] as String? ?? '').trim(),
      phoneNumber: (map['phoneNumber'] as String? ?? '').trim(),
    );
  }
}

/// Opens Android's system phone-contact picker. The user grants access to one
/// selected phone row; GeoWake never asks for broad READ_CONTACTS access.
class GuardianContactPicker {
  const GuardianContactPicker._();

  static const MethodChannel _channel = MethodChannel(
    'geowake/guardian_contact_picker',
  );

  static Future<PickedGuardianContact?> pickPhoneContact() async {
    try {
      final raw = await _channel.invokeMapMethod<Object?, Object?>(
        'pickPhoneContact',
      );
      if (raw == null) return null;
      final picked = PickedGuardianContact.fromMap(raw);
      if (picked.phoneNumber.isEmpty) return null;
      return picked;
    } on PlatformException {
      return null;
    } on MissingPluginException {
      return null;
    }
  }
}
