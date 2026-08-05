import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../notifications/device_installation_store.dart';

class BackendUser {
  const BackendUser({
    required this.onboardingStep,
    required this.verificationStatus,
    required this.roles,
    this.latestVerificationRequestTitle,
    this.latestVerificationMessage,
    this.latestVerificationRequestedDocuments = const [],
    this.latestVerificationRequiresTextResponse = false,
    this.displayName,
    this.phone,
    this.photoUrl,
    this.dateOfBirth,
    this.addressLine,
    this.addressUnit,
    this.city,
    this.postalCode,
    this.country,
    this.latitude,
    this.longitude,
    this.producerProfile,
    this.businessProfile,
  });
  final String onboardingStep;
  final String verificationStatus;
  final List<String> roles;
  final String? latestVerificationRequestTitle;
  final String? latestVerificationMessage;
  final List<String> latestVerificationRequestedDocuments;
  final bool latestVerificationRequiresTextResponse;
  final String? displayName;
  final String? phone;
  final String? photoUrl;
  final String? dateOfBirth;
  final String? addressLine;
  final String? addressUnit;
  final String? city;
  final String? postalCode;
  final String? country;
  final double? latitude;
  final double? longitude;
  final Map<String, dynamic>? producerProfile;
  final Map<String, dynamic>? businessProfile;

  factory BackendUser.fromJson(Map<String, dynamic> json) => BackendUser(
    onboardingStep: json['onboardingStep'] as String,
    verificationStatus: json['verificationStatus'] as String,
    roles: (json['roles'] as List<dynamic>).cast<String>(),
    latestVerificationRequestTitle:
        json['latestVerificationRequestTitle'] as String?,
    latestVerificationMessage: json['latestVerificationMessage'] as String?,
    latestVerificationRequestedDocuments:
        (json['latestVerificationRequestedDocuments'] as List<dynamic>? ?? [])
            .cast<String>(),
    latestVerificationRequiresTextResponse:
        json['latestVerificationRequiresTextResponse'] as bool? ?? false,
    displayName: json['displayName'] as String?,
    phone: json['phone'] as String?,
    photoUrl: json['photoUrl'] as String?,
    dateOfBirth: json['dateOfBirth'] as String?,
    addressLine: json['addressLine'] as String?,
    addressUnit: json['addressUnit'] as String?,
    city: json['city'] as String?,
    postalCode: json['postalCode'] as String?,
    country: json['country'] as String?,
    latitude: (json['latitude'] as num?)?.toDouble(),
    longitude: (json['longitude'] as num?)?.toDouble(),
    producerProfile: json['producerProfile'] as Map<String, dynamic>?,
    businessProfile: json['businessProfile'] as Map<String, dynamic>?,
  );
}

class EmailSignupChallenge {
  const EmailSignupChallenge({
    required this.email,
    required this.expiresAt,
    required this.resendAvailableAt,
  });

  final String email;
  final DateTime expiresAt;
  final DateTime resendAvailableAt;

  factory EmailSignupChallenge.fromJson(Map<String, dynamic> json) =>
      EmailSignupChallenge(
        email: json['email'] as String,
        expiresAt: DateTime.parse(json['expiresAt'] as String),
        resendAvailableAt: DateTime.parse(json['resendAvailableAt'] as String),
      );
}

class VerificationDocumentUpload {
  const VerificationDocumentUpload({
    required this.kind,
    required this.originalName,
    required this.mimeType,
    required this.bytes,
  });

  final String kind;
  final String originalName;
  final String mimeType;
  final Uint8List bytes;

  Map<String, dynamic> toJson() => {
    'kind': kind,
    'originalName': originalName,
    'mimeType': mimeType,
    'base64Data': base64Encode(bytes),
  };
}

class FarmMediaUploadResult {
  const FarmMediaUploadResult({required this.kind, required this.url});

  final String kind;
  final String url;
}

class ConfirmedLocation {
  const ConfirmedLocation({
    required this.addressLine,
    this.addressUnit,
    required this.city,
    required this.postalCode,
    required this.country,
    required this.latitude,
    required this.longitude,
  });
  final String addressLine;
  final String? addressUnit;
  final String city;
  final String postalCode;
  final String country;
  final double latitude;
  final double longitude;

  String get formattedAddress => [
    addressLine,
    addressUnit,
  ].where((value) => value?.isNotEmpty == true).join(', ');

  Map<String, dynamic> toJson() => {
    'addressLine': addressLine,
    if (addressUnit != null && addressUnit!.isNotEmpty)
      'addressUnit': addressUnit,
    'city': city,
    'postalCode': postalCode,
    'country': country,
    'latitude': latitude,
    'longitude': longitude,
  };
}

class BackendService {
  BackendService({FirebaseAuth? auth})
    : _providedAuth = auth,
      _dio = Dio(
        BaseOptions(
          baseUrl: const String.fromEnvironment(
            'FRSH_API_URL',
            defaultValue: 'https://frshnearby-api.onrender.com/graphql',
          ),
          connectTimeout: const Duration(seconds: 20),
          receiveTimeout: const Duration(seconds: 30),
        ),
      );

  final FirebaseAuth? _providedAuth;
  final Dio _dio;
  final _installationStore = DeviceInstallationStore();

  FirebaseAuth get _auth => _providedAuth ?? FirebaseAuth.instance;

  Future<Map<String, dynamic>> _gql(
    String query, [
    Map<String, dynamic> variables = const {},
  ]) async {
    return _send(query, variables, forceRefresh: false, authenticated: true);
  }

  Future<Map<String, dynamic>> _publicGql(
    String query, [
    Map<String, dynamic> variables = const {},
  ]) async {
    return _send(query, variables, forceRefresh: false, authenticated: false);
  }

  Future<Map<String, dynamic>> _send(
    String query,
    Map<String, dynamic> variables, {
    required bool forceRefresh,
    required bool authenticated,
  }) async {
    final token =
        authenticated
            ? await _auth.currentUser?.getIdToken(forceRefresh)
            : null;
    if (authenticated && token == null) {
      throw StateError('Please sign in again.');
    }
    final response = await _dio.post<Map<String, dynamic>>(
      '',
      data: {'query': query, 'variables': variables},
      options: Options(
        contentType: Headers.jsonContentType,
        headers: {
          if (token != null) 'authorization': 'Bearer $token',
          if (authenticated)
            'x-frsh-installation-id': await _installationStore.id(),
        },
        validateStatus: (_) => true,
      ),
    );
    final body = response.data ?? const {};
    final errors = body['errors'] as List<dynamic>?;
    if (errors != null && errors.isNotEmpty) {
      final first = errors.first as Map<String, dynamic>;
      final code = (first['extensions'] as Map<String, dynamic>?)?['code'];
      if (authenticated && !forceRefresh && code == 'UNAUTHENTICATED') {
        return _send(query, variables, forceRefresh: true, authenticated: true);
      }
      throw StateError(first['message'] as String? ?? 'Server request failed.');
    }
    final status = response.statusCode ?? 0;
    if (status < 200 || status >= 300) {
      final message = body['message'];
      throw StateError(
        message is String
            ? message
            : 'Server rejected the request (HTTP $status).',
      );
    }
    if (body['data'] is! Map<String, dynamic>) {
      throw StateError('The server returned an invalid response.');
    }
    return body['data'] as Map<String, dynamic>;
  }

  Future<BackendUser> session() async {
    final data = await _gql(
      'query { session { user { onboardingStep verificationStatus latestVerificationRequestTitle latestVerificationMessage latestVerificationRequestedDocuments latestVerificationRequiresTextResponse roles displayName phone photoUrl dateOfBirth addressLine addressUnit city postalCode country latitude longitude producerProfile { id publicName description profilePhotoUrl coverPhotoUrl productionType address city postalCode country } businessProfile { id publicDisplayName description profilePhotoUrl coverPhotoUrl legalBusinessName farmName businessId vatNumber businessType businessAddress city postalCode country logoUrl } } } }',
    );
    return BackendUser.fromJson(
      (data['session'] as Map<String, dynamic>)['user'] as Map<String, dynamic>,
    );
  }

  Future<EmailSignupChallenge> requestEmailSignup({
    required String email,
    required String password,
    required String displayName,
  }) async {
    final data = await _publicGql(
      'mutation(\$input: EmailSignupInput!) { requestEmailSignup(input: \$input) { email expiresAt resendAvailableAt } }',
      {
        'input': {
          'email': email.trim().toLowerCase(),
          'password': password,
          'displayName': displayName.trim(),
        },
      },
    );
    return EmailSignupChallenge.fromJson(
      data['requestEmailSignup'] as Map<String, dynamic>,
    );
  }

  Future<EmailSignupChallenge> resendEmailSignupCode(String email) async {
    final data = await _publicGql(
      'mutation(\$input: ResendEmailSignupCodeInput!) { resendEmailSignupCode(input: \$input) { email expiresAt resendAvailableAt } }',
      {
        'input': {'email': email.trim().toLowerCase()},
      },
    );
    return EmailSignupChallenge.fromJson(
      data['resendEmailSignupCode'] as Map<String, dynamic>,
    );
  }

  Future<String> verifyEmailSignup({
    required String email,
    required String code,
  }) async {
    final data = await _publicGql(
      'mutation(\$input: VerifyEmailSignupInput!) { verifyEmailSignup(input: \$input) { customToken } }',
      {
        'input': {'email': email.trim().toLowerCase(), 'code': code.trim()},
      },
    );
    final result = data['verifyEmailSignup'] as Map<String, dynamic>;
    return result['customToken'] as String;
  }

  Future<void> saveAccountType(String accountType) => _gql(
    'mutation(\$input: SelectAccountTypeInput!) { selectAccountType(input: \$input) { id } }',
    {
      'input': {'accountType': accountType},
    },
  );

  Future<void> savePersonalProfile({
    required String displayName,
    required String phone,
    required String dateOfBirth,
    String? photoUrl,
  }) => _gql(
    'mutation(\$input: PersonalProfileInput!) { updatePersonalProfile(input: \$input) { id } }',
    {
      'input': {
        'displayName': displayName,
        'phone': phone,
        'dateOfBirth': dateOfBirth,
        if (photoUrl != null) 'photoUrl': photoUrl,
      },
    },
  );

  Future<bool> isPhoneNumberAvailable(String phone) async {
    final data = await _gql(
      'query(\$phone: String!) { phoneNumberAvailable(phone: \$phone) }',
      {'phone': phone},
    );
    return data['phoneNumberAvailable'] as bool? ?? false;
  }

  Future<void> saveProducerProfile(Map<String, dynamic> input) => _gql(
    'mutation(\$input: ProducerProfileInput!) { saveProducerProfile(input: \$input) { id } }',
    {'input': input},
  );

  Future<void> saveBusinessProfile(Map<String, dynamic> input) => _gql(
    'mutation(\$input: BusinessProfileInput!) { saveBusinessProfile(input: \$input) { id } }',
    {'input': input},
  );

  Future<FarmMediaUploadResult> uploadFarmMedia({
    required String kind,
    required String mimeType,
    required Uint8List bytes,
  }) async {
    final data = await _gql(
      'mutation(\$input: FarmMediaUploadInput!) { uploadFarmMedia(input: \$input) { kind url } }',
      {
        'input': {
          'kind': kind,
          'mimeType': mimeType,
          'base64Data': base64Encode(bytes),
        },
      },
    );
    final result = data['uploadFarmMedia'] as Map<String, dynamic>;
    return FarmMediaUploadResult(
      kind: result['kind'] as String,
      url: result['url'] as String,
    );
  }

  Future<void> submitForVerification({
    required List<VerificationDocumentUpload> documents,
    String? responseMessage,
  }) => _gql(
    'mutation(\$input: SubmitVerificationInput!) { submitForVerification(input: \$input) { id } }',
    {
      'input': {
        'confirmation': true,
        'documents': documents.map((document) => document.toJson()).toList(),
        if (responseMessage?.trim().isNotEmpty == true)
          'responseMessage': responseMessage!.trim(),
      },
    },
  );

  Future<void> confirmLocation(ConfirmedLocation location) => _gql(
    'mutation(\$input: ConfirmLocationInput!) { confirmLocation(input: \$input) { id } }',
    {'input': location.toJson()},
  );

  Future<void> registerPushInstallation({
    required String installationId,
    required String token,
    required String platform,
    required String locale,
    String? deviceName,
  }) => _gql(
    'mutation(\$input: PushInstallationInput!) { registerPushInstallation(input: \$input) }',
    {
      'input': {
        'installationId': installationId,
        'token': token,
        'platform': platform,
        'locale': locale,
        if (deviceName?.isNotEmpty == true) 'deviceName': deviceName,
      },
    },
  );

  Future<void> unregisterPushInstallation(String token) => _gql(
    'mutation(\$token: String!) { unregisterPushInstallation(token: \$token) }',
    {'token': token},
  );

  Future<void> finish({
    required String displayName,
    required String phone,
    required String dateOfBirth,
    String? photoUrl,
    required String accountType,
    ConfirmedLocation? location,
    Map<String, dynamic>? sellerProfile,
  }) async {
    await _gql(
      'mutation(\$input: SelectAccountTypeInput!) { selectAccountType(input: \$input) { id } }',
      {
        'input': {'accountType': accountType},
      },
    );
    await _gql(
      'mutation(\$input: PersonalProfileInput!) { updatePersonalProfile(input: \$input) { id } }',
      {
        'input': {
          'displayName': displayName,
          'phone': phone,
          'dateOfBirth': dateOfBirth,
          if (photoUrl != null) 'photoUrl': photoUrl,
        },
      },
    );
    if (location != null) {
      await confirmLocation(location);
    }
    if (accountType == 'SIDE_HUSTLER') {
      await _gql(
        'mutation(\$input: ProducerProfileInput!) { saveProducerProfile(input: \$input) { id } }',
        {'input': sellerProfile},
      );
    } else if (accountType == 'BUSINESS') {
      await _gql(
        'mutation(\$input: BusinessProfileInput!) { saveBusinessProfile(input: \$input) { id } }',
        {'input': sellerProfile},
      );
    }
  }
}
