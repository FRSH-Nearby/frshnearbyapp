import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:country_picker/country_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart' hide Text;
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';

import '../notifications/push_notification_service.dart';
import '../hot_sales/hot_sales.dart';
import '../customer/consumer_explore.dart';

import 'auth_service.dart';
import 'backend_service.dart';
import 'location_sheet.dart';
import '../../l10n/localized_text.dart';
import 'onboarding_progress_store.dart';
import 'onboarding_draft_store.dart';
import 'app_preferences_store.dart';

const _green = Color(0xFF2F6B45);
const _deepGreen = Color(0xFF1C4630);
const _ink = Color(0xFF1B2A20);
const _muted = Color(0xFF66735F);
const _line = Color(0xFFE7E5DB);
const _mist = Color(0xFFEEF2E7);
const _cream = Color(0xFFFBFAF5);
const _field = Color(0xFFF3F2EA);

enum _AccountType { consumer, producer, business }

class AuthScreen extends StatefulWidget {
  const AuthScreen({
    required this.selectedLanguageCode,
    required this.onLanguageChanged,
    super.key,
  });

  final String? selectedLanguageCode;
  final ValueChanged<String> onLanguageChanged;

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  final _controller = PageController();
  final _emailKey = GlobalKey<FormState>();
  final _detailsKey = GlobalKey<FormState>();
  final _businessKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _verificationCodeController = TextEditingController();
  final _fullNameController = TextEditingController();
  final _dateOfBirthController = TextEditingController();
  final _displayNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _introController = TextEditingController();
  final _businessNameController = TextEditingController();
  final _farmNameController = TextEditingController();
  final _businessIdController = TextEditingController();
  final _vatController = TextEditingController();
  final _businessAddressController = TextEditingController();
  final _businessCityController = TextEditingController();
  final _businessPostalController = TextEditingController();
  final _verificationResponseController = TextEditingController();
  final _authService = AuthService();
  final _backend = BackendService();
  final _progressStore = OnboardingProgressStore();
  final _draftStore = OnboardingDraftStore();
  late final AnimationController _skyController;
  int _page = 0;
  bool _isConsumer = true;
  _AccountType? _sellerType;
  bool _registering = true;
  bool _hidePassword = true;
  bool _authBusy = false;
  String? _socialPhotoUrl;
  Uint8List? _pickedPhotoBytes;
  ConfirmedLocation? _confirmedLocation;
  String? _businessType;
  String? _farmId;
  String? _farmProfilePhotoUrl;
  String? _farmCoverPhotoUrl;
  String _verificationStatus = 'NOT_REQUIRED';
  String? _verificationRequestTitle;
  String? _verificationMessage;
  List<String> _requestedVerificationDocuments = [];
  bool _verificationRequiresTextResponse = false;
  Timer? _draftTimer;
  Timer? _verificationTimer;
  StreamSubscription<RemoteMessage>? _pushMessageSubscription;
  DateTime? _verificationExpiresAt;
  DateTime? _verificationResendAvailableAt;
  final List<VerificationDocumentUpload> _verificationDocuments = [];
  bool _verificationConfirmed = false;

  _AccountType get _effectiveType => _sellerType ?? _AccountType.consumer;
  int get _reviewPage => _sellerType == _AccountType.business ? 4 : 3;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _pushMessageSubscription = PushNotificationService
        .instance
        .foregroundMessages
        .listen(_handleForegroundPush);
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.light);
    _skyController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 18),
    )..repeat(reverse: true);
    for (final controller in _draftControllers) {
      controller.addListener(_scheduleDraftSave);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _restoreSession());
  }

  List<TextEditingController> get _draftControllers => [
    _fullNameController,
    _dateOfBirthController,
    _displayNameController,
    _phoneController,
    _introController,
    _businessNameController,
    _farmNameController,
    _businessIdController,
    _vatController,
    _businessAddressController,
    _businessCityController,
    _businessPostalController,
  ];

  void _scheduleDraftSave() {
    _draftTimer?.cancel();
    _draftTimer = Timer(const Duration(milliseconds: 450), _saveLocalDraft);
  }

  Future<void> _saveLocalDraft() async {
    final uid = _authService.currentUser?.uid;
    if (uid == null) return;
    final location = _confirmedLocation;
    await _draftStore.save(uid, {
      'fullName': _fullNameController.text,
      'dateOfBirth': _dateOfBirthController.text,
      'displayName': _displayNameController.text,
      'phone': _phoneController.text,
      'intro': _introController.text,
      'businessName': _businessNameController.text,
      'farmName': _farmNameController.text,
      'businessId': _businessIdController.text,
      'vatNumber': _vatController.text,
      'businessAddress': _businessAddressController.text,
      'businessCity': _businessCityController.text,
      'businessPostalCode': _businessPostalController.text,
      'businessType': _businessType,
      'consumer': _isConsumer,
      'sellerType': _sellerType?.name,
      if (location != null) 'location': location.toJson(),
    });
  }

  Future<void> _restoreLocalDraft(String uid) async {
    final draft = await _draftStore.load(uid);
    if (draft == null || !mounted) return;
    void restore(TextEditingController controller, String key) {
      final value = draft[key] as String?;
      if (controller.text.isEmpty && value?.isNotEmpty == true) {
        controller.text = value!;
      }
    }

    restore(_fullNameController, 'fullName');
    restore(_dateOfBirthController, 'dateOfBirth');
    restore(_displayNameController, 'displayName');
    restore(_phoneController, 'phone');
    restore(_introController, 'intro');
    restore(_businessNameController, 'businessName');
    restore(_farmNameController, 'farmName');
    restore(_businessIdController, 'businessId');
    restore(_vatController, 'vatNumber');
    restore(_businessAddressController, 'businessAddress');
    restore(_businessCityController, 'businessCity');
    restore(_businessPostalController, 'businessPostalCode');
    final seller = draft['sellerType'] as String?;
    final location = draft['location'] as Map<String, dynamic>?;
    setState(() {
      _isConsumer = draft['consumer'] as bool? ?? _isConsumer;
      _sellerType = switch (seller) {
        'producer' => _AccountType.producer,
        'business' => _AccountType.business,
        _ => _sellerType,
      };
      _businessType = draft['businessType'] as String? ?? _businessType;
      if (location != null) {
        _confirmedLocation = ConfirmedLocation(
          addressLine: location['addressLine'] as String? ?? '',
          addressUnit: location['addressUnit'] as String?,
          city: location['city'] as String? ?? '',
          postalCode: location['postalCode'] as String? ?? '',
          country: location['country'] as String? ?? '',
          latitude: (location['latitude'] as num?)?.toDouble() ?? 0,
          longitude: (location['longitude'] as num?)?.toDouble() ?? 0,
        );
      }
    });
  }

  Future<void> _restoreSession() async {
    User? user;
    try {
      user = _authService.currentUser;
    } on FirebaseException {
      // Widget previews/tests may render before Firebase is bootstrapped.
      return;
    }
    if (user == null || !mounted) return;
    _prefillFromUser(user);
    await _restoreLocalDraft(user.uid);
    final usesPassword = user.providerData.any(
      (provider) => provider.providerId == 'password',
    );
    if (usesPassword && !user.emailVerified) {
      _goTo(7);
      return;
    }
    try {
      final profile = await _backend.session();
      if (!mounted) return;
      _restoreBackendProfile(profile);
      _goTo(_resumePage(profile));
    } catch (error) {
      if (mounted) _showAuthError(_serverMessage(error));
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pushMessageSubscription?.cancel();
    _draftTimer?.cancel();
    _skyController.dispose();
    _controller.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _verificationCodeController.dispose();
    _fullNameController.dispose();
    _dateOfBirthController.dispose();
    _displayNameController.dispose();
    _phoneController.dispose();
    _introController.dispose();
    _businessNameController.dispose();
    _farmNameController.dispose();
    _businessIdController.dispose();
    _vatController.dispose();
    _businessAddressController.dispose();
    _businessCityController.dispose();
    _businessPostalController.dispose();
    _verificationResponseController.dispose();
    _verificationTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_refreshBackendProfile());
    }
  }

  void _handleForegroundPush(RemoteMessage message) {
    final type = message.data['type'];
    if (type == 'VERIFICATION_DECISION' || type == 'VERIFICATION_REQUESTED') {
      unawaited(_refreshBackendProfile());
    }
  }

  Future<void> _refreshBackendProfile() async {
    if (_authService.currentUser == null) return;
    try {
      final profile = await _backend.session();
      if (!mounted) return;
      setState(() => _restoreBackendProfile(profile));
    } catch (_) {
      // Keep the current screen stable; the next resume or request retries.
    }
  }

  Future<void> _runAuthentication(
    Future<UserCredential> Function() action,
  ) async {
    if (_authBusy) return;
    setState(() => _authBusy = true);
    try {
      final credential = await action();
      if (!mounted) return;
      _prefillFromUser(credential.user);
      if (credential.user != null) {
        await _restoreLocalDraft(credential.user!.uid);
      }
      final usesPassword =
          credential.user?.providerData.any(
            (provider) => provider.providerId == 'password',
          ) ??
          false;
      if (usesPassword && !(credential.user?.emailVerified ?? false)) {
        _goTo(7);
        return;
      }
      final profile = await _backend.session();
      if (!mounted) return;
      _restoreBackendProfile(profile);
      _goTo(_resumePage(profile));
    } on AuthCancelledException {
      // Closing a provider dialog is an intentional action, not an error.
    } on FirebaseAuthException catch (error) {
      if (mounted) _showAuthError(_authMessage(error));
    } catch (error) {
      if (mounted) {
        _showAuthError(_serverMessage(error));
      }
    } finally {
      if (mounted) setState(() => _authBusy = false);
    }
  }

  Future<void> _submitEmail() async {
    if (!(_emailKey.currentState?.validate() ?? false)) return;
    if (!_registering) {
      await _signInWithEmailAndPassword();
      return;
    }

    if (_authBusy) return;
    setState(() => _authBusy = true);
    try {
      final challenge = await _backend.requestEmailSignup(
        email: _emailController.text,
        password: _passwordController.text,
        displayName:
            _fullNameController.text.trim().isEmpty
                ? _emailController.text.trim().split('@').first
                : _fullNameController.text.trim(),
      );
      if (!mounted) return;
      _startEmailVerification(challenge);
    } on FirebaseAuthException catch (error) {
      if (mounted) _showAuthError(_authMessage(error));
    } catch (error) {
      if (mounted) _showAuthError(_serverMessage(error));
    } finally {
      if (mounted) setState(() => _authBusy = false);
    }
  }

  Future<void> _signInWithEmailAndPassword() async {
    if (_authBusy) return;
    setState(() => _authBusy = true);
    try {
      final credential = await _authService.signInWithEmail(
        email: _emailController.text,
        password: _passwordController.text,
      );
      if (!mounted) return;
      _prefillFromUser(credential.user);
      final usesPassword =
          credential.user?.providerData.any(
            (provider) => provider.providerId == 'password',
          ) ??
          false;
      if (usesPassword && !(credential.user?.emailVerified ?? false)) {
        final challenge = await _backend.requestEmailSignup(
          email: _emailController.text,
          password: _passwordController.text,
          displayName:
              credential.user?.displayName ??
              _emailController.text.trim().split('@').first,
        );
        if (!mounted) return;
        _startEmailVerification(challenge);
        return;
      }
      final profile = await _backend.session();
      if (!mounted) return;
      _restoreBackendProfile(profile);
      _goTo(_resumePage(profile));
    } on FirebaseAuthException catch (error) {
      if (mounted) _showAuthError(_authMessage(error));
    } catch (error) {
      if (mounted) _showAuthError(_serverMessage(error));
    } finally {
      if (mounted) setState(() => _authBusy = false);
    }
  }

  void _startEmailVerification(EmailSignupChallenge challenge) {
    _verificationCodeController.clear();
    _verificationTimer?.cancel();
    _verificationTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && _page == 7) setState(() {});
    });
    setState(() {
      _emailController.text = challenge.email;
      _verificationExpiresAt = challenge.expiresAt;
      _verificationResendAvailableAt = challenge.resendAvailableAt;
    });
    _goTo(7);
  }

  void _prefillFromUser(User? user) {
    if (user == null) return;
    if (_emailController.text.isEmpty && user.email != null) {
      _emailController.text = user.email!;
    }
    if (_fullNameController.text.isEmpty && user.displayName != null) {
      _fullNameController.text = user.displayName!;
    }
    if (_displayNameController.text.isEmpty && user.displayName != null) {
      _displayNameController.text = user.displayName!;
    }
    _socialPhotoUrl ??= user.photoURL;
  }

  void _restoreBackendProfile(BackendUser profile) {
    if (profile.displayName?.isNotEmpty ?? false) {
      _fullNameController.text = profile.displayName!;
    }
    if (profile.phone?.isNotEmpty ?? false) {
      _phoneController.text = profile.phone!;
    }
    if (profile.dateOfBirth != null) {
      final date = DateTime.tryParse(profile.dateOfBirth!);
      if (date != null) {
        _dateOfBirthController.text =
            '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
      }
    }
    _socialPhotoUrl = profile.photoUrl ?? _socialPhotoUrl;
    _verificationStatus = profile.verificationStatus;
    _verificationRequestTitle = profile.latestVerificationRequestTitle;
    _verificationMessage = profile.latestVerificationMessage;
    _requestedVerificationDocuments =
        profile.latestVerificationRequestedDocuments;
    _verificationRequiresTextResponse =
        profile.latestVerificationRequiresTextResponse;
    if (profile.roles.contains('BUSINESS')) {
      _sellerType = _AccountType.business;
    } else if (profile.roles.contains('SIDE_HUSTLER')) {
      _sellerType = _AccountType.producer;
    } else {
      _sellerType = null;
    }
    _isConsumer = profile.roles.contains('CONSUMER');
    final producer = profile.producerProfile;
    if (producer != null) {
      _farmId = producer['id'] as String?;
      _farmProfilePhotoUrl = producer['profilePhotoUrl'] as String?;
      _farmCoverPhotoUrl = producer['coverPhotoUrl'] as String?;
      _displayNameController.text = producer['publicName'] as String? ?? '';
      _introController.text = producer['description'] as String? ?? '';
    }
    final business = profile.businessProfile;
    if (business != null) {
      _farmId = business['id'] as String?;
      _farmProfilePhotoUrl = business['profilePhotoUrl'] as String?;
      _farmCoverPhotoUrl = business['coverPhotoUrl'] as String?;
      _displayNameController.text =
          business['publicDisplayName'] as String? ?? '';
      _introController.text = business['description'] as String? ?? '';
      _businessNameController.text =
          business['legalBusinessName'] as String? ?? '';
      _farmNameController.text = business['farmName'] as String? ?? '';
      _businessIdController.text = business['businessId'] as String? ?? '';
      _vatController.text = business['vatNumber'] as String? ?? '';
      _businessType = business['businessType'] as String?;
      _businessAddressController.text =
          business['businessAddress'] as String? ?? '';
      _businessCityController.text = business['city'] as String? ?? '';
      _businessPostalController.text = business['postalCode'] as String? ?? '';
    }
    if (profile.addressLine != null && profile.country != null) {
      _confirmedLocation = ConfirmedLocation(
        addressLine: profile.addressLine!,
        addressUnit: profile.addressUnit,
        city: profile.city ?? '',
        postalCode: profile.postalCode ?? '',
        country: profile.country!,
        latitude: profile.latitude ?? 0,
        longitude: profile.longitude ?? 0,
      );
    }
  }

  int _resumePage(BackendUser profile) {
    if (profile.onboardingStep == 'COMPLETE' ||
        profile.onboardingStep == 'SUBMITTED_FOR_REVIEW') {
      return 8;
    }
    if (profile.onboardingStep == 'BUSINESS_DETAILS_REQUIRED' &&
        profile.phone != null) {
      return 4;
    }
    if (profile.onboardingStep == 'PRODUCER_DETAILS_REQUIRED' ||
        profile.onboardingStep == 'BUSINESS_DETAILS_REQUIRED' ||
        profile.onboardingStep == 'PROFILE_REQUIRED') {
      return 3;
    }
    return 2;
  }

  Future<void> _changeVerificationEmail() async {
    await PushNotificationService.instance.unregisterCurrentDevice();
    await _authService.signOut();
    _passwordController.clear();
    _confirmPasswordController.clear();
    if (mounted) _goTo(1);
  }

  Future<void> _pickProfilePhoto(ImageSource source) async {
    final photo = await ImagePicker().pickImage(
      source: source,
      imageQuality: 82,
      maxWidth: 1200,
    );
    if (photo == null) return;
    final bytes = await photo.readAsBytes();
    if (mounted) setState(() => _pickedPhotoBytes = bytes);
  }

  void _showPhotoSource() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder:
          (context) => SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ListTile(
                    leading: const Icon(Icons.photo_library_outlined),
                    title: const Text('Choose from photos'),
                    onTap: () {
                      Navigator.pop(context);
                      _pickProfilePhoto(ImageSource.gallery);
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.photo_camera_outlined),
                    title: const Text('Take a photo'),
                    onTap: () {
                      Navigator.pop(context);
                      _pickProfilePhoto(ImageSource.camera);
                    },
                  ),
                ],
              ),
            ),
          ),
    );
  }

  Future<void> _checkVerification() async {
    if (_verificationCodeController.text.trim().length != 6) {
      _showAuthError('Enter the 6-digit verification code.');
      return;
    }
    setState(() => _authBusy = true);
    try {
      final customToken = await _backend.verifyEmailSignup(
        email: _emailController.text,
        code: _verificationCodeController.text,
      );
      final credential = await _authService.signInWithCustomToken(customToken);
      if (!mounted) return;
      _prefillFromUser(credential.user);
      if (credential.user != null) {
        await _restoreLocalDraft(credential.user!.uid);
      }
      _verificationTimer?.cancel();
      _goTo(2);
    } on FirebaseAuthException catch (error) {
      if (mounted) _showAuthError(_authMessage(error));
    } catch (error) {
      if (mounted) _showAuthError(_serverMessage(error));
    } finally {
      if (mounted) setState(() => _authBusy = false);
    }
  }

  Future<void> _resendVerification() async {
    try {
      final challenge = await _backend.resendEmailSignupCode(
        _emailController.text,
      );
      if (!mounted) return;
      _startEmailVerification(challenge);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('A new verification code was sent.')),
        );
      }
    } on FirebaseAuthException catch (error) {
      if (mounted) _showAuthError(_authMessage(error));
    } catch (error) {
      if (mounted) _showAuthError(_serverMessage(error));
    }
  }

  Future<void> _finishOnboarding() async {
    final user = _authService.currentUser;
    if (user == null) {
      _showAuthError('Your session expired. Please sign in again.');
      _goTo(0);
      return;
    }
    final location = _confirmedLocation;
    if (_effectiveType != _AccountType.consumer && location == null) {
      _showAuthError('Confirm your location before continuing.');
      return;
    }
    setState(() => _authBusy = true);
    try {
      final type = switch (_effectiveType) {
        _AccountType.consumer => 'CONSUMER',
        _AccountType.producer => 'SIDE_HUSTLER',
        _AccountType.business => 'BUSINESS',
      };
      Map<String, dynamic>? seller;
      if (_effectiveType == _AccountType.producer) {
        final sellerLocation = location!;
        seller = {
          'publicName': _displayNameController.text.trim(),
          if (_introController.text.trim().isNotEmpty)
            'description': _introController.text.trim(),
          'productionType': 'Local food producer',
          'address': sellerLocation.formattedAddress,
          'city': sellerLocation.city,
          'postalCode': sellerLocation.postalCode,
          'country': sellerLocation.country,
        };
      } else if (_effectiveType == _AccountType.business) {
        final sellerLocation = location!;
        seller = {
          'publicDisplayName': _displayNameController.text.trim(),
          if (_introController.text.trim().isNotEmpty)
            'description': _introController.text.trim(),
          'legalBusinessName': _businessNameController.text.trim(),
          if (_farmNameController.text.trim().isNotEmpty)
            'farmName': _farmNameController.text.trim(),
          'businessId': _businessIdController.text.trim(),
          if (_vatController.text.trim().isNotEmpty)
            'vatNumber': _vatController.text.trim(),
          'businessType': _businessType,
          'businessAddress': sellerLocation.formattedAddress,
          'city': _businessCityController.text.trim(),
          'postalCode': _businessPostalController.text.trim(),
          'country': sellerLocation.country,
        };
      }
      await _backend.finish(
        displayName: _fullNameController.text.trim(),
        phone: _phoneController.text.trim(),
        dateOfBirth: _isoDate(_dateOfBirthController.text),
        photoUrl: _socialPhotoUrl,
        accountType: type,
        location: location,
        sellerProfile: seller,
      );
      await _progressStore.markComplete(user.uid);
      _draftTimer?.cancel();
      await _draftStore.clear(user.uid);
      if (mounted) _goTo(6);
    } catch (error) {
      if (mounted) _showAuthError(_serverMessage(error));
    } finally {
      if (mounted) setState(() => _authBusy = false);
    }
  }

  Future<void> _forgotPassword() async {
    final email = _emailController.text.trim();
    if (!email.contains('@')) {
      _showAuthError('Enter your email address first.');
      return;
    }
    try {
      await _authService.sendPasswordReset(email);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Password reset email sent.')),
        );
      }
    } on FirebaseAuthException catch (error) {
      if (mounted) _showAuthError(_authMessage(error));
    }
  }

  Future<bool> _submitSellerVerification() async {
    if (_sellerType == null || _authBusy) return false;
    final requested = _requestedVerificationDocuments.toSet();
    final isChangeRequest = _verificationStatus == 'NEEDS_CHANGES';
    final requiredKinds =
        isChangeRequest
            ? requested
            : {
              _sellerType == _AccountType.business
                  ? 'BUSINESS_REGISTRATION'
                  : 'IDENTITY',
            };
    for (final kind in requiredKinds) {
      if (!_verificationDocuments.any((document) => document.kind == kind)) {
        _showAuthError('Upload ${_documentKindLabel(kind).toLowerCase()}.');
        return false;
      }
    }
    if (isChangeRequest &&
        _verificationRequiresTextResponse &&
        _verificationResponseController.text.trim().length < 2) {
      _showAuthError('Add a written response before submitting.');
      return false;
    }
    if (!_verificationConfirmed) {
      _showAuthError('Confirm your details before submitting.');
      return false;
    }
    setState(() => _authBusy = true);
    try {
      final submissionDocuments =
          isChangeRequest && requested.isNotEmpty
              ? _verificationDocuments
                  .where((document) => requested.contains(document.kind))
                  .toList()
              : isChangeRequest
              ? <VerificationDocumentUpload>[]
              : _verificationDocuments;
      await _backend.submitForVerification(
        documents: submissionDocuments,
        responseMessage: _verificationResponseController.text,
      );
      if (!mounted) return false;
      setState(() {
        _verificationStatus = 'SUBMITTED';
        _verificationMessage = null;
        _requestedVerificationDocuments = [];
        _verificationRequiresTextResponse = false;
        _verificationConfirmed = false;
      });
      _verificationResponseController.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Your verification request was sent for review.'),
        ),
      );
      return true;
    } catch (error) {
      if (mounted) _showAuthError(_serverMessage(error));
      return false;
    } finally {
      if (mounted) setState(() => _authBusy = false);
    }
  }

  Future<void> _openSellerVerification() async {
    if (_sellerType == null) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder:
            (_) => _SellerVerificationScreen(
              type: _sellerType!,
              status: _verificationStatus,
              requestTitle: _verificationRequestTitle,
              adminMessage: _verificationMessage,
              requestedDocuments: _requestedVerificationDocuments,
              requiresTextResponse: _verificationRequiresTextResponse,
              responseController: _verificationResponseController,
              documents: _verificationDocuments,
              initiallyConfirmed: _verificationConfirmed,
              onAddDocument: _addVerificationDocument,
              onRemoveDocument: _removeVerificationDocument,
              onConfirmed:
                  (value) => setState(() => _verificationConfirmed = value),
              onSubmit: _submitSellerVerification,
            ),
      ),
    );
  }

  String _documentKindLabel(String kind) => switch (kind) {
    'IDENTITY' => 'Proof of identity',
    'BUSINESS_REGISTRATION' => 'Business registration proof',
    'VAT_REGISTRATION' => 'Tax or VAT document',
    'ADDRESS_PROOF' => 'Activity or location proof',
    'OTHER' => 'Other document',
    _ => 'Verification document',
  };

  Future<void> _addVerificationDocument(String kind) async {
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png', 'webp'],
      withData: true,
    );
    final file = picked?.files.single;
    final bytes = file?.bytes;
    if (file == null || bytes == null) return;
    if (bytes.length > 8 * 1024 * 1024) {
      _showAuthError('Each verification file must be 8 MB or smaller.');
      return;
    }
    final mimeType = _mimeTypeForName(file.name);
    if (!{
      'application/pdf',
      'image/jpeg',
      'image/png',
      'image/webp',
    }.contains(mimeType)) {
      _showAuthError('Upload a PDF, JPG, PNG, or WEBP file.');
      return;
    }
    final document = VerificationDocumentUpload(
      kind: kind,
      originalName: file.name,
      mimeType: mimeType,
      bytes: bytes,
    );
    setState(() {
      _verificationDocuments.removeWhere((item) => item.kind == kind);
      _verificationDocuments.add(document);
    });
  }

  void _removeVerificationDocument(String kind) {
    setState(() {
      _verificationDocuments.removeWhere((document) => document.kind == kind);
    });
  }

  String _mimeTypeForName(String name) {
    final lower = name.toLowerCase();
    if (lower.endsWith('.pdf')) return 'application/pdf';
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.webp')) return 'image/webp';
    return 'image/jpeg';
  }

  Future<void> _signOutToWelcome() async {
    await PushNotificationService.instance.unregisterCurrentDevice();
    await _authService.signOut();
    if (mounted) _goTo(0);
  }

  void _showAuthError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  String _authMessage(FirebaseAuthException error) => switch (error.code) {
    'email-already-in-use' =>
      'This email already has an account. Try signing in.',
    'invalid-credential' ||
    'wrong-password' ||
    'user-not-found' => 'The email or password is incorrect.',
    'weak-password' => 'Choose a stronger password.',
    'network-request-failed' => 'Check your internet connection.',
    'account-exists-with-different-credential' =>
      'This email uses another sign-in method. Use that method first.',
    'operation-not-allowed' =>
      'This sign-in method is not enabled in Firebase yet.',
    _ => error.message ?? 'Authentication failed. Please try again.',
  };

  void _goTo(int page) {
    setState(() => _page = page);
    _controller.animateToPage(
      page,
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _continueFromRole() async {
    setState(() => _authBusy = true);
    try {
      await _backend.saveAccountType(_accountTypeCode);
      if (mounted) _goTo(3);
    } catch (error) {
      if (mounted) _showAuthError(_serverMessage(error));
    } finally {
      if (mounted) setState(() => _authBusy = false);
    }
  }

  String get _accountTypeCode => switch (_effectiveType) {
    _AccountType.consumer => 'CONSUMER',
    _AccountType.producer => 'SIDE_HUSTLER',
    _AccountType.business => 'BUSINESS',
  };

  void _goBack() {
    if (_page == 5 && _sellerType != _AccountType.business) {
      _goTo(3);
      return;
    }
    _goTo(_page - 1);
  }

  Future<void> _continueFromDetails() async {
    if (!(_detailsKey.currentState?.validate() ?? false)) return;
    setState(() => _authBusy = true);
    try {
      final phone = _phoneController.text.trim();
      final available = await _backend.isPhoneNumberAvailable(phone);
      if (!available) {
        _showAuthError(
          'This phone number is already registered. Sign in to the existing account or use another number.',
        );
        return;
      }
      await _backend.savePersonalProfile(
        displayName: _fullNameController.text.trim(),
        phone: phone,
        dateOfBirth: _isoDate(_dateOfBirthController.text),
        photoUrl: _socialPhotoUrl,
      );
    } catch (error) {
      if (mounted) _showAuthError(_serverMessage(error));
      return;
    } finally {
      if (mounted) setState(() => _authBusy = false);
    }
    if (!mounted) return;
    if (_effectiveType == _AccountType.consumer) {
      _goTo(5);
      return;
    }
    final location = await showModalBottomSheet<ConfirmedLocation>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder:
          (_) => LocationSheet(
            isBusiness: _effectiveType == _AccountType.business,
            initialLocation: _confirmedLocation,
          ),
    );
    if (location == null || !mounted) return;
    _confirmedLocation = location;
    _scheduleDraftSave();
    _businessAddressController.text = location.formattedAddress;
    _businessCityController.text = location.city;
    _businessPostalController.text = location.postalCode;
    try {
      await _backend.confirmLocation(location);
      if (_effectiveType == _AccountType.producer) {
        await _backend.saveProducerProfile(_producerPayload(location));
      }
    } catch (error) {
      if (mounted) _showAuthError(_serverMessage(error));
      return;
    }
    _goTo(_sellerType == _AccountType.business ? 4 : 5);
  }

  Map<String, dynamic> _producerPayload(ConfirmedLocation location) => {
    'publicName': _displayNameController.text.trim(),
    if (_introController.text.trim().isNotEmpty)
      'description': _introController.text.trim(),
    'productionType': 'Local food producer',
    'address': location.formattedAddress,
    'city': location.city,
    'postalCode': location.postalCode,
    'country': location.country,
  };

  Future<void> _continueFromBusiness() async {
    if (!(_businessKey.currentState?.validate() ?? false)) return;
    final location = _confirmedLocation;
    if (location == null) {
      _showAuthError('Confirm your registered location first.');
      return;
    }
    setState(() => _authBusy = true);
    try {
      await _backend.saveBusinessProfile({
        'publicDisplayName': _displayNameController.text.trim(),
        if (_introController.text.trim().isNotEmpty)
          'description': _introController.text.trim(),
        'legalBusinessName': _businessNameController.text.trim(),
        if (_farmNameController.text.trim().isNotEmpty)
          'farmName': _farmNameController.text.trim(),
        'businessId': _businessIdController.text.trim(),
        if (_vatController.text.trim().isNotEmpty)
          'vatNumber': _vatController.text.trim(),
        'businessType': _businessType,
        'businessAddress': _businessAddressController.text.trim(),
        'city': _businessCityController.text.trim(),
        'postalCode': _businessPostalController.text.trim(),
        'country': location.country,
      });
      if (mounted) _goTo(5);
    } catch (error) {
      if (mounted) _showAuthError(_serverMessage(error));
    } finally {
      if (mounted) setState(() => _authBusy = false);
    }
  }

  Future<void> _editLocationFromSettings() async {
    final location = await showModalBottomSheet<ConfirmedLocation>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder:
          (_) => LocationSheet(
            isBusiness: _effectiveType == _AccountType.business,
            initialLocation: _confirmedLocation,
          ),
    );
    if (location == null || !mounted) return;

    setState(() => _authBusy = true);
    try {
      await _backend.confirmLocation(location);
      _confirmedLocation = location;
      _businessAddressController.text = location.formattedAddress;
      _businessCityController.text = location.city;
      _businessPostalController.text = location.postalCode;
      if (_effectiveType == _AccountType.producer) {
        await _backend.saveProducerProfile(_producerPayload(location));
      } else if (_effectiveType == _AccountType.business) {
        await _backend.saveBusinessProfile({
          'publicDisplayName': _displayNameController.text.trim(),
          if (_introController.text.trim().isNotEmpty)
            'description': _introController.text.trim(),
          'legalBusinessName': _businessNameController.text.trim(),
          if (_farmNameController.text.trim().isNotEmpty)
            'farmName': _farmNameController.text.trim(),
          'businessId': _businessIdController.text.trim(),
          if (_vatController.text.trim().isNotEmpty)
            'vatNumber': _vatController.text.trim(),
          'businessType': _businessType,
          'businessAddress': location.formattedAddress,
          'city': location.city,
          'postalCode': location.postalCode,
          'country': location.country,
        });
      }
      if (mounted) {
        setState(() {});
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Location updated.')),
        );
      }
    } catch (error) {
      if (mounted) _showAuthError(_serverMessage(error));
    } finally {
      if (mounted) setState(() => _authBusy = false);
    }
  }

  Future<void> _editFarmAbout() async {
    final nameController = TextEditingController(
      text:
          _farmNameController.text.trim().isNotEmpty
              ? _farmNameController.text.trim()
              : _displayNameController.text.trim(),
    );
    final aboutController = TextEditingController(
      text: _introController.text.trim(),
    );
    final result = await showDialog<(String, String)>(
      context: context,
      builder:
          (dialogContext) => AlertDialog(
            title: const Text('Edit public farm profile'),
            content: SizedBox(
              width: 420,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameController,
                    maxLength: 100,
                    decoration: const InputDecoration(
                      labelText: 'Farm profile name',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: aboutController,
                    minLines: 4,
                    maxLines: 7,
                    maxLength: 600,
                    decoration: const InputDecoration(
                      labelText: 'About your farm',
                      hintText:
                          'Share your story, growing methods and what makes your farm special.',
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () {
                  final name = nameController.text.trim();
                  final about = aboutController.text.trim();
                  if (name.length < 2 || about.isEmpty) return;
                  Navigator.pop(dialogContext, (name, about));
                },
                child: const Text('Save'),
              ),
            ],
          ),
    );
    nameController.dispose();
    aboutController.dispose();
    if (result == null || !mounted) return;
    final location = _confirmedLocation;
    if (location == null) {
      _showAuthError('Add your farm location before editing the public profile.');
      return;
    }

    setState(() => _authBusy = true);
    try {
      _displayNameController.text = result.$1;
      _introController.text = result.$2;
      if (_effectiveType == _AccountType.producer) {
        await _backend.saveProducerProfile(_producerPayload(location));
      } else {
        _farmNameController.text = result.$1;
        await _backend.saveBusinessProfile({
          'publicDisplayName': result.$1,
          'description': result.$2,
          'legalBusinessName': _businessNameController.text.trim(),
          'farmName': result.$1,
          'businessId': _businessIdController.text.trim(),
          if (_vatController.text.trim().isNotEmpty)
            'vatNumber': _vatController.text.trim(),
          'businessType': _businessType,
          'businessAddress': location.formattedAddress,
          'city': location.city,
          'postalCode': location.postalCode,
          'country': location.country,
        });
      }
      await _refreshBackendProfile();
      if (mounted) {
        setState(() {});
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Public farm profile updated.')),
        );
      }
    } catch (error) {
      if (mounted) _showAuthError(_serverMessage(error));
    } finally {
      if (mounted) setState(() => _authBusy = false);
    }
  }

  String _isoDate(String value) {
    final p = value.split('/');
    return p.length == 3 ? '${p[2]}-${p[1]}-${p[0]}' : value;
  }

  String _serverMessage(Object error) => error
      .toString()
      .replaceFirst('Bad state: ', '')
      .replaceFirst('DioException [bad response]: ', '');

  @override
  Widget build(BuildContext context) {
    if (_page == 8) {
      return _MainAppShell(
        type: _effectiveType,
        isConsumer: _isConsumer,
        fullName: _fullNameController.text.trim(),
        email: _emailController.text.trim(),
        phone: _phoneController.text.trim(),
        photoUrl: _socialPhotoUrl,
        profilePhotoBytes: _pickedPhotoBytes,
        publicName: _displayNameController.text.trim(),
        businessName: _businessNameController.text.trim(),
        farmName: _farmNameController.text.trim(),
        farmDescription: _introController.text.trim(),
        farmId: _farmId,
        farmProfilePhotoUrl: _farmProfilePhotoUrl,
        farmCoverPhotoUrl: _farmCoverPhotoUrl,
        location: _confirmedLocation,
        verificationStatus: _verificationStatus,
        verificationRequestTitle: _verificationRequestTitle,
        verificationMessage: _verificationMessage,
        selectedLanguageCode: widget.selectedLanguageCode,
        onLanguageChanged: widget.onLanguageChanged,
        onOpenVerification: _openSellerVerification,
        onEditProfile: () => _goTo(3),
        onEditFarmAbout: _editFarmAbout,
        onEditLocation: _editLocationFromSettings,
        onEditBusiness:
            _sellerType == _AccountType.business ? () => _goTo(4) : null,
        onSignOut: _signOutToWelcome,
      );
    }
    return Scaffold(
      backgroundColor: const Color(0xFF0F231A),
      body: Stack(
        children: [
          Positioned.fill(child: _KenBurnsBackdrop(animation: _skyController)),
          const Positioned.fill(child: _BackdropScrim()),
          SafeArea(
            bottom: false,
            child: Column(
              children: [
                _TopBar(page: _page, onBack: _goBack),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 380),
                  curve: Curves.easeOutCubic,
                  height: _page == 0 ? 128.0 : 56.0,
                ),
                Expanded(
                  child: Container(
                    width: double.infinity,
                    constraints: const BoxConstraints(maxWidth: 520),
                    padding: EdgeInsets.only(
                      bottom: MediaQuery.of(context).padding.bottom,
                    ),
                    clipBehavior: Clip.antiAlias,
                    decoration: const BoxDecoration(
                      color: _cream,
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(30),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Color(0x40061209),
                          blurRadius: 34,
                          offset: Offset(0, -10),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        if (_page > 0 && _page < 5)
                          _Progress(current: _progressForPage()),
                        Expanded(
                          child: PageView(
                            controller: _controller,
                            physics: const NeverScrollableScrollPhysics(),
                            children: [
                              _WelcomePage(
                                loading: _authBusy,
                                onGoogle:
                                    () => _runAuthentication(
                                      _authService.signInWithGoogle,
                                    ),
                                onEmail: () => _goTo(1),
                              ),
                              _EmailPage(
                                formKey: _emailKey,
                                emailController: _emailController,
                                passwordController: _passwordController,
                                confirmPasswordController:
                                    _confirmPasswordController,
                                registering: _registering,
                                hidePassword: _hidePassword,
                                loading: _authBusy,
                                onMode:
                                    (value) =>
                                        setState(() => _registering = value),
                                onTogglePassword:
                                    () => setState(
                                      () => _hidePassword = !_hidePassword,
                                    ),
                                onForgotPassword: _forgotPassword,
                                onContinue: _submitEmail,
                              ),
                              _AccountTypePage(
                                consumer: _isConsumer,
                                sellerType: _sellerType,
                                onConsumer:
                                    () => setState(() {
                                      if (_isConsumer && _sellerType == null) {
                                        return;
                                      }
                                      _isConsumer = !_isConsumer;
                                      _scheduleDraftSave();
                                    }),
                                onSeller:
                                    (value) => setState(() {
                                      _sellerType =
                                          _sellerType == value ? null : value;
                                      if (_sellerType == null) {
                                        _isConsumer = true;
                                      }
                                      _scheduleDraftSave();
                                    }),
                                onContinue: _continueFromRole,
                              ),
                              _DetailsPage(
                                formKey: _detailsKey,
                                type: _effectiveType,
                                email: _emailController.text,
                                fullNameController: _fullNameController,
                                dateOfBirthController: _dateOfBirthController,
                                displayNameController: _displayNameController,
                                phoneController: _phoneController,
                                introController: _introController,
                                photoUrl: _socialPhotoUrl,
                                photoBytes: _pickedPhotoBytes,
                                onPhoto: _showPhotoSource,
                                onContinue: _continueFromDetails,
                              ),
                              _BusinessPage(
                                formKey: _businessKey,
                                businessNameController: _businessNameController,
                                farmNameController: _farmNameController,
                                businessIdController: _businessIdController,
                                vatController: _vatController,
                                addressController: _businessAddressController,
                                cityController: _businessCityController,
                                postalController: _businessPostalController,
                                businessType: _businessType,
                                onBusinessType:
                                    (value) => setState(() {
                                      _businessType = value;
                                      _scheduleDraftSave();
                                    }),
                                onContinue: _continueFromBusiness,
                              ),
                              _ReviewPage(
                                type: _effectiveType,
                                consumer: _isConsumer,
                                fullName: _fullNameController.text.trim(),
                                phone: _phoneController.text.trim(),
                                publicName: _displayNameController.text.trim(),
                                businessName:
                                    _businessNameController.text.trim(),
                                location: _confirmedLocation,
                                onEditProfile: () => _goTo(3),
                                onEditBusiness:
                                    _effectiveType == _AccountType.business
                                        ? () => _goTo(4)
                                        : null,
                                onFinish: _finishOnboarding,
                                loading: _authBusy,
                              ),
                              _CompletePage(
                                type: _effectiveType,
                                onDone: () => _goTo(8),
                              ),
                              _EmailVerificationPage(
                                email: _emailController.text.trim(),
                                codeController: _verificationCodeController,
                                expiresAt: _verificationExpiresAt,
                                resendAvailableAt:
                                    _verificationResendAvailableAt,
                                loading: _authBusy,
                                onCheck: _checkVerification,
                                onResend: _resendVerification,
                                onChangeEmail: _changeVerificationEmail,
                              ),
                              _ProfilePage(
                                type: _effectiveType,
                                consumer: _isConsumer,
                                fullName: _fullNameController.text.trim(),
                                email: _emailController.text.trim(),
                                phone: _phoneController.text.trim(),
                                photoUrl: _socialPhotoUrl,
                                publicName: _displayNameController.text.trim(),
                                businessName:
                                    _businessNameController.text.trim(),
                                location: _confirmedLocation,
                                verificationStatus: _verificationStatus,
                                verificationMessage: _verificationMessage,
                                requestedVerificationDocuments:
                                    _requestedVerificationDocuments,
                                verificationRequiresTextResponse:
                                    _verificationRequiresTextResponse,
                                verificationResponseController:
                                    _verificationResponseController,
                                verificationDocuments: _verificationDocuments,
                                verificationConfirmed: _verificationConfirmed,
                                busy: _authBusy,
                                onEditProfile: () => _goTo(3),
                                onEditBusiness:
                                    _sellerType == _AccountType.business
                                        ? () => _goTo(4)
                                        : null,
                                onAddVerificationDocument:
                                    _addVerificationDocument,
                                onRemoveVerificationDocument:
                                    _removeVerificationDocument,
                                onVerificationConfirmed:
                                    (value) => setState(
                                      () =>
                                          _verificationConfirmed =
                                              value ?? false,
                                    ),
                                onVerify: _submitSellerVerification,
                                onSignOut: _signOutToWelcome,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  int _progressForPage() {
    if (_page <= 2) return 1;
    if (_page == 3) return 2;
    if (_page == 4) return 3;
    return _reviewPage == 4 ? 4 : 3;
  }
}

class _KenBurnsBackdrop extends StatelessWidget {
  const _KenBurnsBackdrop({required this.animation});
  final Animation<double> animation;

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: ClipRect(
      child: AnimatedBuilder(
        animation: animation,
        builder:
            (context, child) => Transform.scale(
              scale: 1.04 + (animation.value * 0.05),
              alignment: Alignment.topCenter,
              child: child,
            ),
        child: Image.asset(
          'assets/images/auth_backdrop.jpg',
          fit: BoxFit.cover,
          alignment: Alignment.topCenter,
        ),
      ),
    ),
  );
}

class _BackdropScrim extends StatelessWidget {
  const _BackdropScrim();

  @override
  Widget build(BuildContext context) => const IgnorePointer(
    child: DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0x59081710), Color(0x1A081710), Color(0x8C081710)],
          stops: [0, .38, 1],
        ),
      ),
    ),
  );
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.page, required this.onBack});
  final int page;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
    child: Row(
      children: [
        SizedBox(
          width: 44,
          height: 44,
          child:
              (page > 0 && page < 6)
                  ? IconButton(
                    onPressed: onBack,
                    style: IconButton.styleFrom(
                      backgroundColor: const Color(0x26FFFFFF),
                      foregroundColor: _cream,
                      side: const BorderSide(color: Color(0x33FFFFFF)),
                    ),
                    icon: const Icon(Icons.arrow_back_rounded, size: 20),
                  )
                  : null,
        ),
        const Spacer(),
        const _Wordmark(),
        const Spacer(),
        const SizedBox(width: 44),
      ],
    ),
  );
}

class _Wordmark extends StatelessWidget {
  const _Wordmark();

  @override
  Widget build(BuildContext context) => Text.rich(
    TextSpan(
      children: [
        TextSpan(
          text: 'FRSH ',
          style: GoogleFonts.fraunces(
            color: _cream,
            fontSize: 21,
            fontWeight: FontWeight.w600,
            letterSpacing: .6,
          ),
        ),
        TextSpan(
          text: 'nearby',
          style: GoogleFonts.fraunces(
            color: _cream.withValues(alpha: .82),
            fontSize: 20,
            fontWeight: FontWeight.w400,
            fontStyle: FontStyle.italic,
          ),
        ),
      ],
    ),
  );
}

class _Progress extends StatelessWidget {
  const _Progress({required this.current});
  final int current;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
    child: Column(
      children: [
        Row(
          children: [
            const Text(
              'YOUR SETUP',
              style: TextStyle(
                color: Color(0xFF57705C),
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.8,
              ),
            ),
            const Spacer(),
            Text(
              '$current of 4',
              style: const TextStyle(
                color: _muted,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: SizedBox(
            height: 3,
            width: double.infinity,
            child: Stack(
              children: [
                const Positioned.fill(child: ColoredBox(color: _line)),
                AnimatedFractionallySizedBox(
                  duration: const Duration(milliseconds: 420),
                  curve: Curves.easeOutCubic,
                  alignment: Alignment.centerLeft,
                  widthFactor: current / 4,
                  heightFactor: 1,
                  child: const ColoredBox(color: _green),
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}

class _WelcomePage extends StatelessWidget {
  const _WelcomePage({
    required this.loading,
    required this.onGoogle,
    required this.onEmail,
  });
  final bool loading;
  final VoidCallback onGoogle;
  final VoidCallback onEmail;

  @override
  Widget build(BuildContext context) => _ScrollPage(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 6),
        const Center(child: _Eyebrow('WELCOME')),
        const SizedBox(height: 2),
        Text(
          'Fresh food near you',
          textAlign: TextAlign.center,
          style: GoogleFonts.fraunces(
            color: _ink,
            fontSize: 32,
            height: 1.08,
            fontWeight: FontWeight.w600,
            letterSpacing: -.5,
          ),
        ),
        const SizedBox(height: 10),
        const Text(
          'One account for discovering, making and selling local food.',
          textAlign: TextAlign.center,
          style: TextStyle(color: _muted, fontSize: 14.5, height: 1.45),
        ),
        const SizedBox(height: 26),
        _ProviderButton(
          label: 'Continue with Google',
          loading: loading,
          onPressed: onGoogle,
        ),
        const SizedBox(height: 14),
        const Row(
          children: [
            Expanded(child: Divider(color: _line)),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 12),
              child: Text('or', style: TextStyle(color: _muted, fontSize: 13)),
            ),
            Expanded(child: Divider(color: _line)),
          ],
        ),
        const SizedBox(height: 14),
        OutlinedButton(
          onPressed: loading ? null : onEmail,
          style: _outlineStyle,
          child: const Text('Continue with email'),
        ),
        const SizedBox(height: 16),
        const Text(
          'Secure sign-in • your saved setup resumes automatically',
          textAlign: TextAlign.center,
          style: TextStyle(color: _muted, fontSize: 11.5),
        ),
      ],
    ),
  );
}

class _EmailPage extends StatelessWidget {
  const _EmailPage({
    required this.formKey,
    required this.emailController,
    required this.passwordController,
    required this.confirmPasswordController,
    required this.registering,
    required this.hidePassword,
    required this.loading,
    required this.onMode,
    required this.onTogglePassword,
    required this.onForgotPassword,
    required this.onContinue,
  });
  final GlobalKey<FormState> formKey;
  final TextEditingController emailController;
  final TextEditingController passwordController;
  final TextEditingController confirmPasswordController;
  final bool registering;
  final bool hidePassword;
  final bool loading;
  final ValueChanged<bool> onMode;
  final VoidCallback onTogglePassword;
  final VoidCallback onForgotPassword;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) => _ScrollPage(
    child: Form(
      key: formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _Eyebrow('YOUR ACCOUNT'),
          Text(
            registering ? 'Create your account' : 'Welcome back',
            style: _title,
          ),
          const SizedBox(height: 6),
          Text(
            registering
                ? 'A few details now, then make FRSH yours.'
                : 'Use the email and password you registered with.',
            style: const TextStyle(color: _muted),
          ),
          const SizedBox(height: 18),
          _Segmented(
            left: 'Create account',
            right: 'Sign in',
            leftSelected: registering,
            onLeft: () => onMode(true),
            onRight: () => onMode(false),
          ),
          const SizedBox(height: 20),
          TextFormField(
            controller: emailController,
            enabled: !loading,
            keyboardType: TextInputType.emailAddress,
            decoration: InputDecoration(
              labelText: localizeText(context, 'Email address'),
            ),
            validator:
                (value) =>
                    value != null && value.contains('@')
                        ? null
                        : localizeText(context, 'Enter a valid email address.'),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: passwordController,
            enabled: !loading,
            obscureText: hidePassword,
            decoration: InputDecoration(
              labelText: localizeText(context, 'Password'),
              suffixIcon: IconButton(
                onPressed: onTogglePassword,
                icon: Icon(
                  hidePassword
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                ),
              ),
            ),
            validator:
                (value) =>
                    (value?.length ?? 0) >= 8
                        ? null
                        : localizeText(context, 'Use at least 8 characters.'),
          ),
          if (registering) ...[
            const SizedBox(height: 12),
            TextFormField(
              controller: confirmPasswordController,
              enabled: !loading,
              obscureText: hidePassword,
              decoration: InputDecoration(
                labelText: localizeText(context, 'Confirm password'),
              ),
              validator:
                  (value) =>
                      value == passwordController.text
                          ? null
                          : localizeText(context, 'Passwords do not match.'),
            ),
          ],
          if (!registering)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: loading ? null : onForgotPassword,
                child: const Text('Forgot password?'),
              ),
            ),
          const SizedBox(height: 20),
          _PrimaryButton(
            label: registering ? 'Continue' : 'Sign in',
            onPressed: onContinue,
            loading: loading,
          ),
        ],
      ),
    ),
  );
}

class _AccountTypePage extends StatelessWidget {
  const _AccountTypePage({
    required this.consumer,
    required this.sellerType,
    required this.onConsumer,
    required this.onSeller,
    required this.onContinue,
  });
  final bool consumer;
  final _AccountType? sellerType;
  final VoidCallback onConsumer;
  final ValueChanged<_AccountType> onSeller;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) => _ScrollPage(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _Eyebrow('STEP 1 OF 4'),
        Text('How will you use FRSH?', style: _title),
        const SizedBox(height: 6),
        const Text(
          'You can also be a consumer. Choose only one type of seller profile.',
          style: TextStyle(color: _muted),
        ),
        const SizedBox(height: 18),
        _TypeCard(
          selected: consumer,
          image: 'assets/images/role_consumer.jpg',
          title: 'Consumer',
          subtitle: 'Discover fresh food and trusted makers nearby.',
          onTap: onConsumer,
        ),
        const SizedBox(height: 12),
        _TypeCard(
          selected: sellerType == _AccountType.producer,
          image: 'assets/images/role_producer.jpg',
          title: 'Side-hustle producer',
          subtitle: 'Sell small-batch, seasonal or homemade products.',
          badge: 'INDIVIDUAL',
          onTap: () => onSeller(_AccountType.producer),
        ),
        const SizedBox(height: 12),
        _TypeCard(
          selected: sellerType == _AccountType.business,
          image: 'assets/images/role_business.jpg',
          title: 'Registered business',
          subtitle: 'Build a verified storefront for your farm or company.',
          badge: 'BUSINESS',
          onTap: () => onSeller(_AccountType.business),
        ),
        const SizedBox(height: 20),
        _PrimaryButton(label: 'Continue', onPressed: onContinue),
      ],
    ),
  );
}

class _EmailVerificationPage extends StatelessWidget {
  const _EmailVerificationPage({
    required this.email,
    required this.codeController,
    required this.expiresAt,
    required this.resendAvailableAt,
    required this.loading,
    required this.onCheck,
    required this.onResend,
    required this.onChangeEmail,
  });
  final String email;
  final TextEditingController codeController;
  final DateTime? expiresAt;
  final DateTime? resendAvailableAt;
  final bool loading;
  final VoidCallback onCheck;
  final VoidCallback onResend;
  final VoidCallback onChangeEmail;

  bool get _isExpired {
    final expires = expiresAt;
    return expires != null && DateTime.now().isAfter(expires);
  }

  bool get _canResend {
    final resendAt = resendAvailableAt;
    return resendAt == null || !DateTime.now().isBefore(resendAt);
  }

  String _formatDuration(DateTime? target) {
    if (target == null) return '0:00';
    final duration = target.difference(DateTime.now());
    final safe = duration.isNegative ? Duration.zero : duration;
    final minutes = safe.inMinutes.remainder(60);
    final seconds = safe.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) => _ScrollPage(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 6),
        Center(
          child: Container(
            width: 68,
            height: 68,
            decoration: BoxDecoration(
              color: _mist,
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFFDFE7D6)),
            ),
            child: const Icon(
              Icons.mark_email_unread_outlined,
              color: _green,
              size: 30,
            ),
          ),
        ),
        const SizedBox(height: 20),
        Text(
          'Enter verification code',
          textAlign: TextAlign.center,
          style: _title,
        ),
        const SizedBox(height: 8),
        Text(
          'We sent a 6-digit code to\n$email',
          textAlign: TextAlign.center,
          style: const TextStyle(color: _muted, height: 1.4),
        ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: _mist,
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Text(
            'Check your inbox and spam folder. The code is sent by FRSH Nearby and expires soon.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, height: 1.4, color: _ink),
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: codeController,
          keyboardType: TextInputType.number,
          textInputAction: TextInputAction.done,
          maxLength: 6,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w600,
            letterSpacing: 10,
            color: _ink,
          ),
          decoration: InputDecoration(
            labelText: localizeText(context, 'Verification code'),
            counterText: '',
          ),
        ),
        const SizedBox(height: 12),
        Text(
          _isExpired
              ? 'Code expired. Request a new code.'
              : 'Code expires in ${_formatDuration(expiresAt)}',
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: _muted,
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 20),
        _PrimaryButton(
          label: 'Verify email',
          onPressed: _isExpired ? null : onCheck,
          loading: loading,
        ),
        const SizedBox(height: 8),
        TextButton(
          onPressed: loading || !_canResend ? null : onResend,
          child: Text(
            _canResend
                ? 'Resend verification code'
                : 'Resend in ${_formatDuration(resendAvailableAt)}',
          ),
        ),
        TextButton(
          onPressed: loading ? null : onChangeEmail,
          child: const Text('Use a different email'),
        ),
      ],
    ),
  );
}

class _DetailsPage extends StatelessWidget {
  const _DetailsPage({
    required this.formKey,
    required this.type,
    required this.email,
    required this.fullNameController,
    required this.dateOfBirthController,
    required this.displayNameController,
    required this.phoneController,
    required this.introController,
    required this.photoUrl,
    required this.photoBytes,
    required this.onPhoto,
    required this.onContinue,
  });
  final GlobalKey<FormState> formKey;
  final _AccountType type;
  final String email;
  final TextEditingController fullNameController;
  final TextEditingController dateOfBirthController;
  final TextEditingController displayNameController;
  final TextEditingController phoneController;
  final TextEditingController introController;
  final String? photoUrl;
  final Uint8List? photoBytes;
  final VoidCallback onPhoto;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    final isSeller = type != _AccountType.consumer;
    return _ScrollPage(
      child: Form(
        key: formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _Eyebrow('STEP 2 OF 4'),
            Text(
              isSeller ? 'Create your public profile' : 'Tell us about you',
              style: _title,
            ),
            const SizedBox(height: 6),
            Text(
              isSeller
                  ? 'This is how local customers will recognise you.'
                  : 'We use this to make your experience feel local.',
              style: const TextStyle(color: _muted),
            ),
            const SizedBox(height: 18),
            _PhotoPicker(
              photoUrl: photoUrl,
              photoBytes: photoBytes,
              onTap: onPhoto,
            ),
            const SizedBox(height: 16),
            _RequiredField(label: 'Full name', controller: fullNameController),
            const SizedBox(height: 12),
            InputDecorator(
              decoration: InputDecoration(
                labelText: localizeText(context, 'Verified email address'),
                suffixIcon: Icon(
                  Icons.verified_outlined,
                  color: _green,
                  size: 20,
                ),
              ),
              child: Text(email),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: dateOfBirthController,
              readOnly: true,
              decoration: InputDecoration(
                labelText: localizeText(context, 'Date of birth *'),
                hintText: localizeText(context, 'Select date'),
                suffixIcon: Icon(
                  Icons.calendar_today_outlined,
                  color: _muted,
                  size: 18,
                ),
              ),
              onTap: () async {
                final now = DateTime.now();
                final selected = await showDatePicker(
                  context: context,
                  initialDate: DateTime(now.year - 18),
                  firstDate: DateTime(1900),
                  lastDate: DateTime(now.year - 18, now.month, now.day),
                );
                if (selected != null) {
                  dateOfBirthController.text =
                      '${selected.day.toString().padLeft(2, '0')}/'
                      '${selected.month.toString().padLeft(2, '0')}/'
                      '${selected.year}';
                }
              },
              validator:
                  (value) =>
                      value == null || value.isEmpty
                          ? localizeText(context, 'Select your date of birth.')
                          : null,
            ),
            const SizedBox(height: 12),
            if (isSeller) ...[
              _RequiredField(
                label: 'Display name (public)',
                controller: displayNameController,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: introController,
                minLines: 3,
                maxLines: 5,
                maxLength: 600,
                decoration: InputDecoration(
                  labelText: localizeText(context, 'About your farm'),
                  hintText: localizeText(
                    context,
                    'Tell customers your story and what makes your farm special.',
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
            _InternationalPhoneField(controller: phoneController),
            const SizedBox(height: 20),
            _PrimaryButton(label: 'Continue', onPressed: onContinue),
          ],
        ),
      ),
    );
  }
}

class _BusinessPage extends StatelessWidget {
  const _BusinessPage({
    required this.formKey,
    required this.businessNameController,
    required this.farmNameController,
    required this.businessIdController,
    required this.vatController,
    required this.addressController,
    required this.cityController,
    required this.postalController,
    required this.businessType,
    required this.onBusinessType,
    required this.onContinue,
  });
  final GlobalKey<FormState> formKey;
  final TextEditingController businessNameController;
  final TextEditingController farmNameController;
  final TextEditingController businessIdController;
  final TextEditingController vatController;
  final TextEditingController addressController;
  final TextEditingController cityController;
  final TextEditingController postalController;
  final String? businessType;
  final ValueChanged<String?> onBusinessType;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) => _ScrollPage(
    child: Form(
      key: formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _Eyebrow('STEP 3 OF 4'),
          Text('Business details', style: _title),
          const SizedBox(height: 6),
          const Text(
            'These details help us verify your storefront. Only your public name and address area are shown.',
            style: TextStyle(color: _muted, height: 1.4),
          ),
          const SizedBox(height: 18),
          _RequiredField(
            label: 'Business name',
            controller: businessNameController,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: farmNameController,
            decoration: InputDecoration(
              labelText: localizeText(context, 'Farm name'),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _RequiredField(
                  label: 'Business ID',
                  controller: businessIdController,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextFormField(
                  controller: vatController,
                  decoration: InputDecoration(
                    labelText: localizeText(context, 'VAT number'),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: businessType,
            decoration: InputDecoration(
              labelText: localizeText(context, 'Business type *'),
            ),
            items: const [
              DropdownMenuItem(value: 'farm', child: Text('Farm')),
              DropdownMenuItem(value: 'food', child: Text('Food producer')),
              DropdownMenuItem(value: 'retail', child: Text('Retailer')),
              DropdownMenuItem(value: 'other', child: Text('Other')),
            ],
            onChanged: onBusinessType,
            validator:
                (value) =>
                    value == null
                        ? localizeText(context, 'Select a business type.')
                        : null,
          ),
          const SizedBox(height: 12),
          _RequiredField(
            label: 'Business address',
            controller: addressController,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _RequiredField(
                  label: 'City',
                  controller: cityController,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _RequiredField(
                  label: 'Zip code',
                  controller: postalController,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _PrimaryButton(label: 'Review application', onPressed: onContinue),
        ],
      ),
    ),
  );
}

class _ReviewPage extends StatelessWidget {
  const _ReviewPage({
    required this.type,
    required this.consumer,
    required this.fullName,
    required this.phone,
    required this.publicName,
    required this.businessName,
    required this.location,
    required this.onEditProfile,
    required this.onEditBusiness,
    required this.onFinish,
    required this.loading,
  });
  final _AccountType type;
  final bool consumer;
  final String fullName;
  final String phone;
  final String publicName;
  final String businessName;
  final ConfirmedLocation? location;
  final VoidCallback onEditProfile;
  final VoidCallback? onEditBusiness;
  final VoidCallback onFinish;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final sellerTitle = switch (type) {
      _AccountType.consumer => 'Consumer',
      _AccountType.producer => 'Side-hustle producer',
      _AccountType.business => 'Registered business',
    };
    final title =
        consumer && type != _AccountType.consumer
            ? 'Consumer + $sellerTitle'
            : sellerTitle;
    return _ScrollPage(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _Eyebrow('FINAL STEP'),
          Text('Everything looks fresh', style: _title),
          const SizedBox(height: 6),
          const Text(
            'Confirm what we saved. You can edit anything before continuing.',
            style: TextStyle(color: _muted),
          ),
          const SizedBox(height: 22),
          _SummaryTile(
            icon: Icons.account_circle_outlined,
            title: 'Account type',
            value: title,
          ),
          const SizedBox(height: 10),
          _SummaryTile(
            icon: Icons.badge_outlined,
            title: fullName,
            value: phone,
            onEdit: onEditProfile,
          ),
          if (type != _AccountType.consumer) ...[
            const SizedBox(height: 10),
            _SummaryTile(
              icon:
                  type == _AccountType.business
                      ? Icons.storefront_outlined
                      : Icons.spa_outlined,
              title: 'Public identity',
              value: type == _AccountType.business ? businessName : publicName,
              onEdit: onEditBusiness ?? onEditProfile,
            ),
            if (location != null) ...[
              const SizedBox(height: 10),
              _SummaryTile(
                icon: Icons.location_on_outlined,
                title: 'Registered location',
                value: [
                  location!.addressLine,
                  location!.addressUnit,
                  location!.postalCode,
                  location!.city,
                  location!.country,
                ].where((value) => value?.isNotEmpty == true).join(', '),
                onEdit: onEditProfile,
              ),
            ],
            const SizedBox(height: 10),
            const _SummaryTile(
              icon: Icons.verified_user_outlined,
              title: 'Seller verification',
              value: 'Available later from your profile',
            ),
          ],
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: _mist,
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.lock_outline_rounded, color: _green, size: 20),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Your private account and verification details are never displayed publicly.',
                    style: TextStyle(fontSize: 13, height: 1.35),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          _PrimaryButton(
            label: 'Create my account',
            onPressed: onFinish,
            loading: loading,
          ),
          const SizedBox(height: 10),
          const Text(
            'By continuing, you agree to our Terms and Privacy Policy.',
            textAlign: TextAlign.center,
            style: TextStyle(color: _muted, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _CompletePage extends StatelessWidget {
  const _CompletePage({required this.type, required this.onDone});
  final _AccountType type;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) => _ScrollPage(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 8),
        Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.bottomCenter,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: AspectRatio(
                aspectRatio: 16 / 11,
                child: Image.asset(
                  'assets/images/auth_sunrise.jpg',
                  fit: BoxFit.cover,
                ),
              ),
            ),
            Positioned(
              bottom: -30,
              child: Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: _green,
                  shape: BoxShape.circle,
                  border: Border.all(color: _cream, width: 4),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x2E12331F),
                      blurRadius: 16,
                      offset: Offset(0, 8),
                    ),
                  ],
                ),
                child: const Center(child: _DrawnCheck()),
              ),
            ),
          ],
        ),
        const SizedBox(height: 48),
        Text(
          'Welcome to FRSH nearby!',
          textAlign: TextAlign.center,
          style: _title,
        ),
        const SizedBox(height: 8),
        Text(
          type == _AccountType.consumer
              ? 'Your local food journey starts now.'
              : 'Your profile is ready. You can apply for seller verification later from your profile.',
          textAlign: TextAlign.center,
          style: const TextStyle(color: _muted, height: 1.45),
        ),
        const SizedBox(height: 30),
        _PrimaryButton(label: 'Explore FRSH', onPressed: onDone),
      ],
    ),
  );
}

class _DrawnCheck extends StatelessWidget {
  const _DrawnCheck();

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    tween: Tween(begin: 0, end: 1),
    duration: const Duration(milliseconds: 750),
    curve: Curves.easeOutCubic,
    builder:
        (context, value, _) => CustomPaint(
          size: const Size(28, 28),
          painter: _CheckPainter(progress: value),
        ),
  );
}

class _CheckPainter extends CustomPainter {
  _CheckPainter({required this.progress});
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    if (progress == 0) return;
    final path =
        Path()
          ..moveTo(size.width * .14, size.height * .55)
          ..lineTo(size.width * .40, size.height * .78)
          ..lineTo(size.width * .86, size.height * .26);
    final drawn = Path();
    var remaining =
        path.computeMetrics().fold<double>(0, (sum, m) => sum + m.length) *
        progress;
    for (final metric in path.computeMetrics()) {
      final length = remaining.clamp(0.0, metric.length);
      drawn.addPath(metric.extractPath(0, length), Offset.zero);
      remaining -= length;
      if (remaining <= 0) break;
    }
    canvas.drawPath(
      drawn,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.2
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(_CheckPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

class _MainAppShell extends StatefulWidget {
  const _MainAppShell({
    required this.type,
    required this.isConsumer,
    required this.fullName,
    required this.email,
    required this.phone,
    required this.photoUrl,
    required this.profilePhotoBytes,
    required this.publicName,
    required this.businessName,
    required this.farmName,
    required this.farmDescription,
    required this.farmId,
    required this.farmProfilePhotoUrl,
    required this.farmCoverPhotoUrl,
    required this.location,
    required this.verificationStatus,
    required this.verificationRequestTitle,
    required this.verificationMessage,
    required this.selectedLanguageCode,
    required this.onLanguageChanged,
    required this.onOpenVerification,
    required this.onEditProfile,
    required this.onEditFarmAbout,
    required this.onEditLocation,
    required this.onEditBusiness,
    required this.onSignOut,
  });

  final _AccountType type;
  final bool isConsumer;
  final String fullName;
  final String email;
  final String phone;
  final String? photoUrl;
  final Uint8List? profilePhotoBytes;
  final String publicName;
  final String businessName;
  final String farmName;
  final String farmDescription;
  final String? farmId;
  final String? farmProfilePhotoUrl;
  final String? farmCoverPhotoUrl;
  final ConfirmedLocation? location;
  final String verificationStatus;
  final String? verificationRequestTitle;
  final String? verificationMessage;
  final String? selectedLanguageCode;
  final ValueChanged<String> onLanguageChanged;
  final VoidCallback onOpenVerification;
  final VoidCallback onEditProfile;
  final VoidCallback onEditFarmAbout;
  final VoidCallback onEditLocation;
  final VoidCallback? onEditBusiness;
  final VoidCallback onSignOut;

  @override
  State<_MainAppShell> createState() => _MainAppShellState();
}

class _MainAppShellState extends State<_MainAppShell> {
  int _index = 0;
  final _preferences = AppPreferencesStore();
  late _AccountType _activeType = widget.type;
  Uint8List? _coverPhotoBytes;
  Uint8List? _farmProfilePhotoBytes;
  late String? _coverPhotoUrl;
  late String? _farmProfilePhotoUrl;
  final _backend = BackendService();

  @override
  void initState() {
    super.initState();
    _coverPhotoUrl = widget.farmCoverPhotoUrl;
    _farmProfilePhotoUrl = widget.farmProfilePhotoUrl;
    _loadAccountMode();
  }

  @override
  void didUpdateWidget(covariant _MainAppShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_coverPhotoBytes == null &&
        oldWidget.farmCoverPhotoUrl != widget.farmCoverPhotoUrl) {
      _coverPhotoUrl = widget.farmCoverPhotoUrl;
    }
    if (_farmProfilePhotoBytes == null &&
        oldWidget.farmProfilePhotoUrl != widget.farmProfilePhotoUrl) {
      _farmProfilePhotoUrl = widget.farmProfilePhotoUrl;
    }
  }

  Future<void> _loadAccountMode() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final mode = await _preferences.accountMode(uid);
    if (!mounted || mode == null) return;
    setState(() {
      _activeType = switch (mode) {
        'consumer' => _AccountType.consumer,
        'seller' => widget.type,
        _ => widget.type,
      };
    });
  }

  Future<void> _setAccountType(_AccountType type) async {
    if (_activeType == type) return;
    setState(() {
      _activeType = type;
      _index = 0;
    });
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      await _preferences.setAccountMode(
        uid,
        type == _AccountType.consumer ? 'consumer' : 'seller',
      );
    }
  }

  Future<void> _openSettings() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder:
            (_) => _SettingsScreen(
              selectedLanguageCode: widget.selectedLanguageCode,
              onLanguageChanged: widget.onLanguageChanged,
              activeType: _activeType,
              sellerType: widget.type,
              canSwitchAccount:
                  widget.isConsumer && widget.type != _AccountType.consumer,
              onAccountTypeChanged: _setAccountType,
              onEditPersonalDetails: widget.onEditProfile,
              onEditFarmProfile: widget.onEditBusiness ?? widget.onEditProfile,
              onEditLocation: widget.onEditLocation,
            ),
      ),
    );
  }

  Future<void> _changeCoverPhoto() async {
    final photo = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 84,
      maxWidth: 1800,
    );
    if (photo == null) return;
    final bytes = await photo.readAsBytes();
    if (!mounted) return;
    setState(() => _coverPhotoBytes = bytes);
    await _uploadFarmMedia(
      kind: 'COVER',
      bytes: bytes,
      mimeType: photo.mimeType ?? _imageMimeType(photo.name),
    );
  }

  Future<void> _changeFarmProfilePhoto() async {
    final photo = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 84,
      maxWidth: 1000,
    );
    if (photo == null) return;
    final bytes = await photo.readAsBytes();
    if (!mounted) return;
    setState(() => _farmProfilePhotoBytes = bytes);
    await _uploadFarmMedia(
      kind: 'PROFILE',
      bytes: bytes,
      mimeType: photo.mimeType ?? _imageMimeType(photo.name),
    );
  }

  String _imageMimeType(String name) {
    final lower = name.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.webp')) return 'image/webp';
    return 'image/jpeg';
  }

  Future<void> _uploadFarmMedia({
    required String kind,
    required Uint8List bytes,
    required String mimeType,
  }) async {
    try {
      final uploaded = await _backend.uploadFarmMedia(
        kind: kind,
        mimeType: mimeType,
        bytes: bytes,
      );
      if (!mounted) return;
      try {
        await precacheImage(CachedNetworkImageProvider(uploaded.url), context);
      } catch (_) {
        // The upload is already durable. A later image request can warm cache.
      }
      if (!mounted) return;
      setState(() {
        if (kind == 'COVER') {
          _coverPhotoUrl = uploaded.url;
          _coverPhotoBytes = null;
        } else {
          _farmProfilePhotoUrl = uploaded.url;
          _farmProfilePhotoBytes = null;
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            kind == 'COVER'
                ? 'Cover photo saved.'
                : 'Farm profile photo saved.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() {
        if (kind == 'COVER') {
          _coverPhotoBytes = null;
        } else {
          _farmProfilePhotoBytes = null;
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Photo upload failed: ${error.toString().replaceFirst('Bad state: ', '')}',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isConsumerMode = _activeType == _AccountType.consumer;
    final pages =
        isConsumerMode
            ? <Widget>[
              if (widget.location == null)
                const _FutureTab(
                  icon: Icons.location_off_outlined,
                  title: 'Confirm your location to explore nearby Hot Sales',
                )
              else
                ConsumerExplorePage(location: widget.location!),
              const _FutureTab(
                icon: Icons.storefront_outlined,
                title: 'Your local marketplace is coming next',
              ),
              _ConsumerProfilePage(
                fullName: widget.fullName,
                email: widget.email,
                phone: widget.phone,
                photoUrl: widget.photoUrl,
                profilePhotoBytes: widget.profilePhotoBytes,
                onEditProfile: widget.onEditProfile,
                onOpenSettings: _openSettings,
                onSignOut: widget.onSignOut,
              ),
            ]
            : <Widget>[
              _SellerDashboardPage(
                type: _activeType,
                fullName: widget.fullName,
                publicName: widget.publicName,
                businessName: widget.businessName,
                location: widget.location,
                verificationStatus: widget.verificationStatus,
              ),
              const _FutureTab(
                icon: Icons.receipt_long_outlined,
                title: 'Seller orders are coming next',
              ),
              _RevampedProfilePage(
                type: _activeType,
                fullName: widget.fullName,
                profilePhotoBytes: _farmProfilePhotoBytes,
                publicName: widget.publicName,
                businessName: widget.businessName,
                farmName: widget.farmName,
                farmDescription: widget.farmDescription,
                farmId: widget.farmId,
                coverPhotoUrl: _coverPhotoUrl,
                farmProfilePhotoUrl: _farmProfilePhotoUrl,
                location: widget.location,
                verificationStatus: widget.verificationStatus,
                coverPhotoBytes: _coverPhotoBytes,
                followerCount: 0,
                onChangeCoverPhoto: _changeCoverPhoto,
                onChangeProfilePhoto: _changeFarmProfilePhoto,
                onEditFarmAbout: widget.onEditFarmAbout,
                onEditLocation: widget.onEditLocation,
                onOpenSettings: _openSettings,
                onSignOut: widget.onSignOut,
              ),
            ];
    final destinations =
        isConsumerMode
            ? [
              NavigationDestination(
                icon: const Icon(Icons.map_outlined),
                selectedIcon: const Icon(Icons.map_rounded),
                label: localizeText(context, 'Explore'),
              ),
              NavigationDestination(
                icon: const Icon(Icons.storefront_outlined),
                selectedIcon: const Icon(Icons.storefront_rounded),
                label: localizeText(context, 'Market'),
              ),
              NavigationDestination(
                icon: const Icon(Icons.person_outline_rounded),
                selectedIcon: const Icon(Icons.person_rounded),
                label: localizeText(context, 'Profile'),
              ),
            ]
            : [
              NavigationDestination(
                icon: const Icon(Icons.dashboard_outlined),
                selectedIcon: const Icon(Icons.dashboard_rounded),
                label: localizeText(context, 'Dashboard'),
              ),
              NavigationDestination(
                icon: const Icon(Icons.receipt_long_outlined),
                selectedIcon: const Icon(Icons.receipt_long_rounded),
                label: localizeText(context, 'Orders'),
              ),
              NavigationDestination(
                icon: const Icon(Icons.person_outline_rounded),
                selectedIcon: const Icon(Icons.person_rounded),
                label: localizeText(context, 'Profile'),
              ),
            ];
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 360),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder:
          (child, animation) => FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position: Tween(
                begin: const Offset(.035, 0),
                end: Offset.zero,
              ).animate(animation),
              child: child,
            ),
          ),
      child: Scaffold(
        key: ValueKey(isConsumerMode),
        backgroundColor: _cream,
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              if (!isConsumerMode && widget.verificationStatus != 'VERIFIED')
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
                  child: _VerificationBanner(
                    status: widget.verificationStatus,
                    requestTitle: widget.verificationRequestTitle,
                    message: widget.verificationMessage,
                    onTap:
                        widget.verificationStatus == 'SUBMITTED' ||
                                widget.verificationStatus == 'IN_REVIEW'
                            ? null
                            : widget.onOpenVerification,
                    compact: true,
                  ),
                ),
              Expanded(child: IndexedStack(index: _index, children: pages)),
            ],
          ),
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _index,
          onDestinationSelected: (value) => setState(() => _index = value),
          backgroundColor: Colors.white,
          indicatorColor: const Color(0xFFDCEBD7),
          destinations: destinations,
        ),
      ),
    );
  }
}

// ignore: unused_element
class _ConsumerDashboardPage extends StatefulWidget {
  const _ConsumerDashboardPage({required this.fullName});
  final String fullName;

  @override
  State<_ConsumerDashboardPage> createState() =>
      _ConsumerDashboardPageState();
}

class _ConsumerDashboardPageState extends State<_ConsumerDashboardPage> {
  static const _farms = [
    _FeaturedFarm(
      id: 'green-meadow',
      name: 'Green Meadow Farm',
      location: 'Espoo, Finland',
      description: 'Seasonal vegetables, herbs and free-range eggs.',
      image: 'assets/images/role_producer.jpg',
      followerCount: 28,
    ),
    _FeaturedFarm(
      id: 'sunrise-bakery',
      name: 'Sunrise Farm Bakery',
      location: 'Helsinki, Finland',
      description: 'Small-batch sourdough and locally milled grains.',
      image: 'assets/images/role_business.jpg',
      followerCount: 41,
    ),
  ];

  final _preferences = AppPreferencesStore();
  Set<String> _followedFarmIds = {};

  @override
  void initState() {
    super.initState();
    _loadFollowedFarms();
  }

  Future<void> _loadFollowedFarms() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final followed = await _preferences.followedFarms(uid);
    if (mounted) setState(() => _followedFarmIds = followed);
  }

  Future<void> _toggleFollow(_FeaturedFarm farm) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final followed = !_followedFarmIds.contains(farm.id);
    setState(() {
      followed
          ? _followedFarmIds.add(farm.id)
          : _followedFarmIds.remove(farm.id);
    });
    await _preferences.setFarmFollowed(uid, farm.id, followed: followed);
  }

  Future<void> _openFarm(_FeaturedFarm farm) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder:
            (_) => _PublicFarmProfilePage(
              farm: farm,
              initiallyFollowed: _followedFarmIds.contains(farm.id),
              onToggleFollow: () => _toggleFollow(farm),
            ),
      ),
    );
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final firstName =
        widget.fullName.trim().isEmpty
            ? 'there'
            : widget.fullName.trim().split(' ').first;
    return ColoredBox(
      color: const Color(0xFFFFFAF0),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 22, 18, 30),
          children: [
            Text(
              'Hello, $firstName',
              style: const TextStyle(
                color: _muted,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Fresh food near you',
              style: GoogleFonts.fraunces(
                fontSize: 34,
                height: 1.05,
                fontWeight: FontWeight.w700,
                color: _ink,
              ),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF194D35), Color(0xFF2E7350)],
                ),
                borderRadius: BorderRadius.circular(26),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.location_on_outlined, color: Color(0xFFFFD979)),
                  SizedBox(height: 22),
                  Text(
                    'Discover local producers',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 21,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  SizedBox(height: 6),
                  Text(
                    'Seasonal food and small businesses, close to home.',
                    style: TextStyle(color: Color(0xFFDDEAE3), height: 1.4),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Text('Browse by category', style: _title),
            const SizedBox(height: 12),
            const Wrap(
              spacing: 9,
              runSpacing: 9,
              children: [
                _CategoryChip(icon: Icons.eco_outlined, label: 'Vegetables'),
                _CategoryChip(
                  icon: Icons.bakery_dining_outlined,
                  label: 'Bakery',
                ),
                _CategoryChip(icon: Icons.egg_outlined, label: 'Eggs & dairy'),
              ],
            ),
            const SizedBox(height: 26),
            Text('Nearby farmers', style: _title),
            const SizedBox(height: 12),
            ..._farms.map(
              (farm) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _FarmPreviewCard(
                  farm: farm,
                  followed: _followedFarmIds.contains(farm.id),
                  onTap: () => _openFarm(farm),
                  onFollow: () => _toggleFollow(farm),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FeaturedFarm {
  const _FeaturedFarm({
    required this.id,
    required this.name,
    required this.location,
    required this.description,
    required this.image,
    required this.followerCount,
  });

  final String id;
  final String name;
  final String location;
  final String description;
  final String image;
  final int followerCount;
}

class _FarmPreviewCard extends StatelessWidget {
  const _FarmPreviewCard({
    required this.farm,
    required this.followed,
    required this.onTap,
    required this.onFollow,
  });

  final _FeaturedFarm farm;
  final bool followed;
  final VoidCallback onTap;
  final VoidCallback onFollow;

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.white,
    borderRadius: BorderRadius.circular(22),
    child: InkWell(
      borderRadius: BorderRadius.circular(22),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.asset(
                farm.image,
                width: 84,
                height: 84,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    farm.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    farm.location,
                    style: const TextStyle(color: _muted, fontSize: 12.5),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${farm.followerCount + (followed ? 1 : 0)} followers',
                    style: const TextStyle(
                      color: _green,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: followed ? 'Unfollow' : 'Follow',
              onPressed: onFollow,
              icon: Icon(
                followed ? Icons.favorite_rounded : Icons.favorite_border,
                color: followed ? _green : _muted,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _PublicFarmProfilePage extends StatefulWidget {
  const _PublicFarmProfilePage({
    required this.farm,
    required this.initiallyFollowed,
    required this.onToggleFollow,
  });

  final _FeaturedFarm farm;
  final bool initiallyFollowed;
  final Future<void> Function() onToggleFollow;

  @override
  State<_PublicFarmProfilePage> createState() =>
      _PublicFarmProfilePageState();
}

class _PublicFarmProfilePageState extends State<_PublicFarmProfilePage> {
  late bool _followed = widget.initiallyFollowed;
  bool _busy = false;

  Future<void> _toggleFollow() async {
    if (_busy) return;
    setState(() => _busy = true);
    await widget.onToggleFollow();
    if (mounted) {
      setState(() {
        _followed = !_followed;
        _busy = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: _cream,
    appBar: AppBar(
      backgroundColor: _cream,
      surfaceTintColor: Colors.transparent,
      title: const Text('Farm profile'),
    ),
    body: ListView(
      padding: const EdgeInsets.fromLTRB(18, 8, 18, 30),
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: Image.asset(
            widget.farm.image,
            height: 220,
            width: double.infinity,
            fit: BoxFit.cover,
          ),
        ),
        const SizedBox(height: 20),
        Text(
          widget.farm.name,
          style: GoogleFonts.fraunces(
            fontSize: 28,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            const Icon(Icons.location_on_outlined, size: 18, color: _muted),
            const SizedBox(width: 5),
            Text(widget.farm.location, style: const TextStyle(color: _muted)),
          ],
        ),
        const SizedBox(height: 14),
        Text(widget.farm.description, style: const TextStyle(height: 1.5)),
        const SizedBox(height: 18),
        Text(
          '${widget.farm.followerCount + (_followed ? 1 : 0)} followers',
          style: const TextStyle(fontWeight: FontWeight.w700, color: _green),
        ),
        const SizedBox(height: 14),
        FilledButton.icon(
          onPressed: _busy ? null : _toggleFollow,
          icon: Icon(
            _followed ? Icons.check_rounded : Icons.add_rounded,
          ),
          label: Text(_followed ? 'Following' : 'Follow farm'),
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 15),
          ),
        ),
      ],
    ),
  );
}

class _SellerDashboardPage extends StatelessWidget {
  const _SellerDashboardPage({
    required this.type,
    required this.fullName,
    required this.publicName,
    required this.businessName,
    required this.location,
    required this.verificationStatus,
  });
  final _AccountType type;
  final String fullName;
  final String publicName;
  final String businessName;
  final ConfirmedLocation? location;
  final String verificationStatus;

  String get displayName =>
      type == _AccountType.business && businessName.isNotEmpty
          ? businessName
          : publicName.isNotEmpty
          ? publicName
          : type == _AccountType.business
          ? 'Your business'
          : 'Your farm';

  String get initials {
    final words = displayName
        .trim()
        .split(RegExp(r'\s+'))
        .where((word) => word.isNotEmpty)
        .take(2);
    return words.map((word) => word[0].toUpperCase()).join();
  }

  String get greeting {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 18) return 'Good day';
    return 'Good evening';
  }

  String? get shortAddress {
    final current = location;
    if (current == null) return null;
    return [
      current.city,
      current.country,
    ].where((value) => value.isNotEmpty).join(', ');
  }

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: const Color(0xFFF1F6ED),
    child: SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 30),
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 21,
                backgroundColor: _green,
                child: Text(
                  initials.isEmpty ? 'F' : initials,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            displayName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        if (verificationStatus == 'VERIFIED') ...[
                          const SizedBox(width: 5),
                          const Icon(
                            Icons.verified_rounded,
                            color: _green,
                            size: 18,
                          ),
                        ],
                      ],
                    ),
                    if (shortAddress?.isNotEmpty == true)
                      Text(
                        shortAddress!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: _muted, fontSize: 12),
                      ),
                  ],
                ),
              ),
              IconButton(
                tooltip: localizeText(context, 'Notifications'),
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text('Notifications are coming next'),
                    ),
                  );
                },
                icon: const Icon(Icons.notifications_none_rounded),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Text(
            greeting,
            style: const TextStyle(fontSize: 25, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 5),
          const Text(
            'Manage your products, fulfil orders, and share your farm page.',
            style: TextStyle(color: _muted, fontSize: 16, height: 1.45),
          ),
          const SizedBox(height: 22),
          const Row(
            children: [
              Expanded(
                child: _MetricCard(
                  label: 'Active orders',
                  value: '—',
                  icon: Icons.receipt_long_outlined,
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: _MetricCard(
                  label: 'This month',
                  value: '—',
                  icon: Icons.trending_up_rounded,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          const HotSalesDashboardSection(),
        ],
      ),
    ),
  );
}

class _ConsumerProfilePage extends StatelessWidget {
  const _ConsumerProfilePage({
    required this.fullName,
    required this.email,
    required this.phone,
    required this.photoUrl,
    required this.profilePhotoBytes,
    required this.onEditProfile,
    required this.onOpenSettings,
    required this.onSignOut,
  });
  final String fullName;
  final String email;
  final String phone;
  final String? photoUrl;
  final Uint8List? profilePhotoBytes;
  final VoidCallback onEditProfile;
  final VoidCallback onOpenSettings;
  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFFFBF2DD), _cream],
        stops: [0, .32],
      ),
    ),
    child: SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 30),
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'My profile',
                  style: GoogleFonts.fraunces(
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    color: _ink,
                  ),
                ),
              ),
              IconButton(
                tooltip: localizeText(context, 'Settings'),
                onPressed: onOpenSettings,
                icon: const Icon(Icons.settings_outlined),
              ),
            ],
          ),
          const SizedBox(height: 6),
          _ProfileIdentityCard(
            image: 'assets/images/role_consumer.jpg',
            photoUrl: photoUrl,
            profilePhotoBytes: profilePhotoBytes,
            initialsSource: fullName,
            heading: fullName.isEmpty ? 'FRSH member' : fullName,
            badgeIcon: Icons.shopping_basket_outlined,
            badgeLabel: 'Consumer account',
          ),
          const SizedBox(height: 20),
          _ProfileSection(
            icon: Icons.person_outline_rounded,
            title: 'Personal details',
            lines: [email, phone].where((value) => value.isNotEmpty).toList(),
            onEdit: onEditProfile,
          ),
          const SizedBox(height: 18),
          OutlinedButton.icon(
            onPressed: onSignOut,
            icon: const Icon(Icons.logout_rounded),
            label: const Text('Sign out'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 15),
            ),
          ),
        ],
      ),
    ),
  );
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({required this.icon, required this.label});
  final IconData icon;
  final String label;
  @override
  Widget build(BuildContext context) => Chip(
    avatar: Icon(icon, size: 18, color: _green),
    label: Text(label),
    backgroundColor: Colors.white,
    side: const BorderSide(color: Color(0xFFE8DDC6)),
  );
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.label,
    required this.value,
    required this.icon,
  });
  final String label;
  final String value;
  final IconData icon;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(17),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: _line),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: _green),
        const SizedBox(height: 16),
        Text(
          value,
          style: const TextStyle(fontSize: 25, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(color: _muted)),
      ],
    ),
  );
}

class _FutureTab extends StatelessWidget {
  const _FutureTab({required this.icon, required this.title});
  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) => SafeArea(
    child: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 42, color: _green),
          const SizedBox(height: 12),
          Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
        ],
      ),
    ),
  );
}

class _RevampedProfilePage extends StatelessWidget {
  const _RevampedProfilePage({
    required this.type,
    required this.fullName,
    required this.profilePhotoBytes,
    required this.publicName,
    required this.businessName,
    required this.farmName,
    required this.farmDescription,
    required this.farmId,
    required this.coverPhotoUrl,
    required this.farmProfilePhotoUrl,
    required this.location,
    required this.verificationStatus,
    required this.coverPhotoBytes,
    required this.followerCount,
    required this.onChangeCoverPhoto,
    required this.onChangeProfilePhoto,
    required this.onEditFarmAbout,
    required this.onEditLocation,
    required this.onOpenSettings,
    required this.onSignOut,
  });

  final _AccountType type;
  final String fullName;
  final Uint8List? profilePhotoBytes;
  final String publicName;
  final String businessName;
  final String farmName;
  final String farmDescription;
  final String? farmId;
  final String? coverPhotoUrl;
  final String? farmProfilePhotoUrl;
  final ConfirmedLocation? location;
  final String verificationStatus;
  final Uint8List? coverPhotoBytes;
  final int followerCount;
  final VoidCallback onChangeCoverPhoto;
  final VoidCallback onChangeProfilePhoto;
  final VoidCallback onEditFarmAbout;
  final VoidCallback onEditLocation;
  final VoidCallback onOpenSettings;
  final VoidCallback onSignOut;

  bool get _isSeller => type != _AccountType.consumer;

  String get _accountLabel => switch (type) {
    _AccountType.consumer => 'Consumer',
    _AccountType.producer => 'Side-hustle producer',
    _AccountType.business => 'Registered business',
  };

  String get _profileDisplayName {
    if (farmName.isNotEmpty) return farmName;
    if (publicName.isNotEmpty) return publicName;
    if (businessName.isNotEmpty) return businessName;
    return fullName.isEmpty ? 'FRSH member' : fullName;
  }

  String get _heroImage => switch (type) {
    _AccountType.consumer => 'assets/images/role_consumer.jpg',
    _AccountType.producer => 'assets/images/role_producer.jpg',
    _AccountType.business => 'assets/images/role_business.jpg',
  };

  IconData get _badgeIcon => switch (type) {
    _AccountType.consumer => Icons.shopping_basket_outlined,
    _AccountType.producer => Icons.spa_outlined,
    _AccountType.business => Icons.storefront_outlined,
  };

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFFF2F7EE), _cream],
        stops: [0, .42],
      ),
    ),
    child: SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 28),
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Profile',
                  style: GoogleFonts.fraunces(
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    color: _ink,
                  ),
                ),
              ),
              IconButton(
                tooltip: localizeText(context, 'Settings'),
                onPressed: onOpenSettings,
                icon: const Icon(Icons.settings_outlined),
              ),
            ],
          ),
          const SizedBox(height: 6),
          _ProfileIdentityCard(
            image: _heroImage,
            coverPhotoUrl: coverPhotoUrl,
            coverPhotoBytes: coverPhotoBytes,
            photoUrl: farmProfilePhotoUrl,
            profilePhotoBytes: profilePhotoBytes,
            initialsSource: _profileDisplayName,
            heading: _profileDisplayName,
            badgeIcon: _badgeIcon,
            badgeLabel: _accountLabel,
            verified: _isSeller && verificationStatus == 'VERIFIED',
            followerCount: _isSeller ? followerCount : null,
            onChangeCoverPhoto: _isSeller ? onChangeCoverPhoto : null,
            onChangeProfilePhoto: _isSeller ? onChangeProfilePhoto : null,
          ),
          const SizedBox(height: 20),
          _FarmStoryCard(
            description: farmDescription,
            farmId: farmId,
            onEdit: onEditFarmAbout,
          ),
          const SizedBox(height: 12),
          _ProfileSection(
            icon: Icons.location_on_outlined,
            title: 'Farm location',
            lines: [
              if (location != null) location!.formattedAddress,
              if (location != null)
                [
                  location!.postalCode,
                  location!.city,
                  location!.country,
                ].where((value) => value.isNotEmpty).join(', ')
              else
                'Add the location customers should discover.',
            ],
            onEdit: onEditLocation,
          ),
          const SizedBox(height: 18),
          OutlinedButton.icon(
            onPressed: onSignOut,
            icon: const Icon(Icons.logout_rounded),
            label: const Text('Sign out'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 15),
            ),
          ),
        ],
      ),
    ),
  );
}

/// Profile identity showcase: a role photo with the member's avatar
/// overlapping its bottom edge, name, and an account-type badge below.
class _ProfileIdentityCard extends StatelessWidget {
  const _ProfileIdentityCard({
    required this.image,
    this.coverPhotoUrl,
    this.coverPhotoBytes,
    required this.photoUrl,
    this.profilePhotoBytes,
    required this.initialsSource,
    required this.heading,
    required this.badgeIcon,
    required this.badgeLabel,
    this.verified = false,
    this.followerCount,
    this.onChangeCoverPhoto,
    this.onChangeProfilePhoto,
  });

  final String image;
  final String? coverPhotoUrl;
  final Uint8List? coverPhotoBytes;
  final String? photoUrl;
  final Uint8List? profilePhotoBytes;
  final String initialsSource;
  final String heading;
  final IconData badgeIcon;
  final String badgeLabel;
  final bool verified;
  final int? followerCount;
  final VoidCallback? onChangeCoverPhoto;
  final VoidCallback? onChangeProfilePhoto;

  ImageProvider<Object>? get _avatarImage {
    if (profilePhotoBytes != null) return MemoryImage(profilePhotoBytes!);
    if (photoUrl?.isNotEmpty == true) {
      return CachedNetworkImageProvider(photoUrl!);
    }
    return null;
  }

  @override
  Widget build(BuildContext context) => Column(
    children: [
      SizedBox(
        height: 220,
        child: Stack(
          alignment: Alignment.topCenter,
          children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(28),
            child: SizedBox(
              height: 168,
              width: double.infinity,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (coverPhotoBytes != null)
                    Image.memory(coverPhotoBytes!, fit: BoxFit.cover)
                  else if (coverPhotoUrl?.isNotEmpty == true)
                    CachedNetworkImage(
                      imageUrl: coverPhotoUrl!,
                      fit: BoxFit.cover,
                      placeholder:
                          (_, _) => Image.asset(image, fit: BoxFit.cover),
                      errorWidget:
                          (_, _, _) => Image.asset(image, fit: BoxFit.cover),
                    )
                  else
                    Image.asset(image, fit: BoxFit.cover),
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Color(0x00081710), Color(0xB3081710)],
                        stops: [0.45, 1],
                      ),
                    ),
                  ),
                  if (onChangeCoverPhoto != null)
                    Positioned(
                      top: 12,
                      right: 12,
                      child: Material(
                        color: const Color(0xD9FFFFFF),
                        shape: const CircleBorder(),
                        child: IconButton(
                          tooltip: 'Change cover photo',
                          onPressed: onChangeCoverPhoto,
                          icon: const Icon(Icons.photo_camera_outlined),
                          color: _deepGreen,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
            Positioned(
              top: 124,
              child: Semantics(
                button: onChangeProfilePhoto != null,
                label: 'Change farm profile photo',
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: onChangeProfilePhoto,
                    customBorder: const CircleBorder(),
                    child: SizedBox(
              width: 96,
              height: 96,
              child: Stack(
                children: [
                  Positioned(
                    top: 0,
                    left: 0,
                    child: Container(
                      width: 88,
                      height: 88,
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Color(0x1F0D2A1B),
                            blurRadius: 18,
                            offset: Offset(0, 8),
                          ),
                        ],
                      ),
                      child: CircleAvatar(
                        backgroundColor: _mist,
                        backgroundImage: _avatarImage,
                        child:
                            profilePhotoBytes != null ||
                                    photoUrl?.isNotEmpty == true
                                ? null
                                : Text(
                                  initialsSource.isEmpty
                                      ? 'F'
                                      : initialsSource[0].toUpperCase(),
                                  style: GoogleFonts.fraunces(
                                    color: _green,
                                    fontSize: 28,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                      ),
                    ),
                  ),
                  if (onChangeProfilePhoto != null)
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: IgnorePointer(
                        child: Tooltip(
                          message: 'Change farm profile photo',
                          child: Material(
                            color: _green,
                            shape: const CircleBorder(),
                            elevation: 2,
                            child: const SizedBox(
                              width: 34,
                              height: 34,
                              child: Icon(
                                Icons.photo_camera_outlined,
                                color: Colors.white,
                                size: 18,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
                    ),
                  ),
                ),
              ),
              ),
            ),
          ],
        ),
      ),
      Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: Text(
              heading,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w800),
            ),
          ),
          if (verified) ...[
            const SizedBox(width: 6),
            Tooltip(
              message: localizeText(context, 'Verified seller'),
              child: const Icon(
                Icons.verified_rounded,
                size: 19,
                color: _green,
              ),
            ),
          ],
        ],
      ),
      const SizedBox(height: 8),
      if (followerCount != null) ...[
        Text(
          '$followerCount ${followerCount == 1 ? 'follower' : 'followers'}',
          style: const TextStyle(
            color: _muted,
            fontSize: 13.5,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
      ],
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: _line),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(badgeIcon, size: 15, color: _green),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                badgeLabel,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: _ink,
                ),
              ),
            ),
          ],
        ),
      ),
    ],
  );
}

class _SettingsScreen extends StatefulWidget {
  const _SettingsScreen({
    required this.selectedLanguageCode,
    required this.onLanguageChanged,
    required this.activeType,
    required this.sellerType,
    required this.canSwitchAccount,
    required this.onAccountTypeChanged,
    required this.onEditPersonalDetails,
    required this.onEditFarmProfile,
    required this.onEditLocation,
  });

  final String? selectedLanguageCode;
  final ValueChanged<String> onLanguageChanged;
  final _AccountType activeType;
  final _AccountType sellerType;
  final bool canSwitchAccount;
  final Future<void> Function(_AccountType type) onAccountTypeChanged;
  final VoidCallback onEditPersonalDetails;
  final VoidCallback onEditFarmProfile;
  final VoidCallback onEditLocation;

  @override
  State<_SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<_SettingsScreen> {
  late String _languageCode;
  late _AccountType _activeType = widget.activeType;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _languageCode =
        widget.selectedLanguageCode ??
        Localizations.localeOf(context).languageCode;
  }

  String get _sellerLabel => switch (widget.sellerType) {
    _AccountType.business => 'Business account',
    _AccountType.producer => 'Side-hustler account',
    _AccountType.consumer => 'Consumer account',
  };

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: _cream,
    appBar: AppBar(
      backgroundColor: _cream,
      surfaceTintColor: Colors.transparent,
      title: const Text('Settings'),
    ),
    body: ListView(
      padding: const EdgeInsets.fromLTRB(18, 8, 18, 28),
      children: [
        if (_activeType != _AccountType.consumer) ...[
          Text('Profile management', style: _title),
          const SizedBox(height: 6),
          const Text(
            'Update the information customers see on your farm profile.',
            style: TextStyle(color: _muted),
          ),
          const SizedBox(height: 14),
          _SettingsCard(
            children: [
              _SettingsAction(
                icon: Icons.person_outline_rounded,
                title: 'Personal details',
                subtitle: 'Name, profile photo, phone and introduction',
                onTap: () => _openEditor(widget.onEditPersonalDetails),
              ),
              const Divider(height: 1),
              _SettingsAction(
                icon: Icons.spa_outlined,
                title: 'Farm profile',
                subtitle: 'Public farm and business information',
                onTap: () => _openEditor(widget.onEditFarmProfile),
              ),
              const Divider(height: 1),
              _SettingsAction(
                icon: Icons.location_on_outlined,
                title: 'Farm location',
                subtitle: 'Change the location customers discover',
                onTap: () => _openEditor(widget.onEditLocation),
              ),
            ],
          ),
          const SizedBox(height: 28),
        ],
        Text('Language', style: _title),
        const SizedBox(height: 6),
        const Text(
          'Choose the language used throughout the app.',
          style: TextStyle(color: _muted),
        ),
        const SizedBox(height: 14),
        _SettingsCard(
          children: [
            _LanguageOption(
              flag: '🇬🇧',
              title: 'English',
              value: 'en',
              groupValue: _languageCode,
              onChanged: _changeLanguage,
            ),
            const Divider(height: 1),
            _LanguageOption(
              flag: '🇫🇮',
              title: 'Finnish',
              value: 'fi',
              groupValue: _languageCode,
              onChanged: _changeLanguage,
            ),
            const Divider(height: 1),
            _LanguageOption(
              flag: '🇸🇪',
              title: 'Swedish',
              value: 'sv',
              groupValue: _languageCode,
              onChanged: _changeLanguage,
            ),
          ],
        ),
        if (widget.canSwitchAccount) ...[
          const SizedBox(height: 28),
          Text('Active account', style: _title),
          const SizedBox(height: 6),
          const Text(
            'Switch how you are using FRSH. This does not remove either profile.',
            style: TextStyle(color: _muted),
          ),
          const SizedBox(height: 14),
          _SettingsCard(
            children: [
              _AccountOption(
                icon: Icons.shopping_basket_outlined,
                title: 'Consumer account',
                subtitle: 'Discover and buy local food',
                selected: _activeType == _AccountType.consumer,
                onTap: () => _changeAccount(_AccountType.consumer),
              ),
              const Divider(height: 1),
              _AccountOption(
                icon:
                    widget.sellerType == _AccountType.business
                        ? Icons.storefront_outlined
                        : Icons.spa_outlined,
                title: _sellerLabel,
                subtitle:
                    widget.sellerType == _AccountType.business
                        ? 'Manage your registered business profile'
                        : 'Manage your producer profile',
                selected: _activeType != _AccountType.consumer,
                onTap: () => _changeAccount(widget.sellerType),
              ),
            ],
          ),
        ],
      ],
    ),
  );

  void _changeLanguage(String languageCode) {
    setState(() => _languageCode = languageCode);
    widget.onLanguageChanged(languageCode);
  }

  Future<void> _changeAccount(_AccountType type) async {
    if (_activeType == type) return;
    setState(() => _activeType = type);
    Navigator.of(context).pop();
    await Future<void>.delayed(const Duration(milliseconds: 90));
    await widget.onAccountTypeChanged(type);
  }

  void _openEditor(VoidCallback editor) {
    Navigator.of(context).pop();
    WidgetsBinding.instance.addPostFrameCallback((_) => editor());
  }
}

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Container(
    clipBehavior: Clip.antiAlias,
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: _line),
    ),
    child: Column(children: children),
  );
}

class _SettingsAction extends StatelessWidget {
  const _SettingsAction({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => ListTile(
    leading: Icon(icon, color: _green),
    title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
    subtitle: Text(subtitle),
    trailing: const Icon(Icons.chevron_right_rounded),
    onTap: onTap,
  );
}

class _LanguageOption extends StatelessWidget {
  const _LanguageOption({
    required this.flag,
    required this.title,
    required this.value,
    required this.groupValue,
    required this.onChanged,
  });
  final String flag;
  final String title;
  final String value;
  final String groupValue;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) => RadioListTile<String>(
    value: value,
    groupValue: groupValue,
    onChanged: (value) {
      if (value != null) onChanged(value);
    },
    secondary: Text(flag, style: const TextStyle(fontSize: 27)),
    title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
    activeColor: _green,
  );
}

class _AccountOption extends StatelessWidget {
  const _AccountOption({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => ListTile(
    onTap: onTap,
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
    leading: CircleAvatar(
      backgroundColor: selected ? const Color(0xFFDCEBD7) : _field,
      foregroundColor: selected ? _green : _muted,
      child: Icon(icon),
    ),
    title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
    subtitle: Text(subtitle),
    trailing:
        selected
            ? const Icon(Icons.check_circle_rounded, color: _green)
            : const Icon(Icons.circle_outlined, color: _line),
  );
}

class _VerificationBanner extends StatelessWidget {
  const _VerificationBanner({
    required this.status,
    required this.requestTitle,
    required this.message,
    required this.onTap,
    this.compact = false,
  });

  final String status;
  final String? requestTitle;
  final String? message;
  final VoidCallback? onTap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final needsAction =
        status == 'DRAFT' || status == 'NEEDS_CHANGES' || status == 'REJECTED';
    final title = switch (status) {
      'NEEDS_CHANGES' =>
        requestTitle?.trim().isNotEmpty == true
            ? requestTitle!
            : 'Action required for verification',
      'SUBMITTED' || 'IN_REVIEW' => 'Verification pending',
      'REJECTED' => 'Verification needs your attention',
      _ => 'Verify your seller profile',
    };
    final subtitle = switch (status) {
      'NEEDS_CHANGES' =>
        message?.trim().isNotEmpty == true
            ? message!
            : 'The verification team needs more information.',
      'SUBMITTED' ||
      'IN_REVIEW' => 'We will notify you when the review is complete.',
      'REJECTED' =>
        message?.trim().isNotEmpty == true
            ? message!
            : 'Review the decision and submit a new request.',
      _ => 'Complete verification to unlock seller features.',
    };
    final background =
        needsAction ? const Color(0xFFFFE9B0) : const Color(0xFFDCE9F4);
    final foreground =
        needsAction ? const Color(0xFF5D3D00) : const Color(0xFF173E5B);
    return Material(
      color: background,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 14 : 16,
            vertical: compact ? 12 : 16,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: compact ? 38 : 42,
                height: compact ? 38 : 42,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: .64),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  needsAction
                      ? Icons.priority_high_rounded
                      : Icons.hourglass_top_rounded,
                  color: foreground,
                ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: compact ? 1 : 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: foreground,
                        fontWeight: FontWeight.w800,
                        fontSize: 15.5,
                      ),
                    ),
                    if (!compact) ...[
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: foreground.withValues(alpha: .78),
                          height: 1.35,
                          fontSize: 12.5,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (onTap != null)
                Icon(Icons.arrow_forward_rounded, color: foreground)
              else
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: .64),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    'PENDING',
                    style: TextStyle(
                      color: foreground,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SellerVerificationScreen extends StatefulWidget {
  const _SellerVerificationScreen({
    required this.type,
    required this.status,
    required this.requestTitle,
    required this.adminMessage,
    required this.requestedDocuments,
    required this.requiresTextResponse,
    required this.responseController,
    required this.documents,
    required this.initiallyConfirmed,
    required this.onAddDocument,
    required this.onRemoveDocument,
    required this.onConfirmed,
    required this.onSubmit,
  });

  final _AccountType type;
  final String status;
  final String? requestTitle;
  final String? adminMessage;
  final List<String> requestedDocuments;
  final bool requiresTextResponse;
  final TextEditingController responseController;
  final List<VerificationDocumentUpload> documents;
  final bool initiallyConfirmed;
  final Future<void> Function(String kind) onAddDocument;
  final void Function(String kind) onRemoveDocument;
  final ValueChanged<bool> onConfirmed;
  final Future<bool> Function() onSubmit;

  @override
  State<_SellerVerificationScreen> createState() =>
      _SellerVerificationScreenState();
}

class _SellerVerificationScreenState extends State<_SellerVerificationScreen> {
  late bool _confirmed = widget.initiallyConfirmed;
  bool _submitting = false;

  bool get _readOnly =>
      widget.status == 'SUBMITTED' || widget.status == 'IN_REVIEW';

  @override
  Widget build(BuildContext context) {
    final isAdminRequest = widget.status == 'NEEDS_CHANGES';
    final title =
        isAdminRequest && widget.requestTitle?.trim().isNotEmpty == true
            ? widget.requestTitle!
            : _readOnly
            ? 'Verification under review'
            : 'Verify your seller profile';
    return Scaffold(
      backgroundColor: _cream,
      appBar: AppBar(
        backgroundColor: _cream,
        surfaceTintColor: Colors.transparent,
        title: const Text('Seller verification'),
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 8, 18, 28),
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color:
                    isAdminRequest
                        ? const Color(0xFFFFE9B0)
                        : const Color(0xFFE7F0E2),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    isAdminRequest
                        ? Icons.mark_email_unread_outlined
                        : Icons.verified_user_outlined,
                    color: _deepGreen,
                    size: 30,
                  ),
                  const SizedBox(height: 14),
                  Text(title, style: _title),
                  const SizedBox(height: 7),
                  Text(
                    isAdminRequest &&
                            widget.adminMessage?.trim().isNotEmpty == true
                        ? widget.adminMessage!
                        : _readOnly
                        ? 'Your documents were submitted. We will notify you when the review is complete.'
                        : 'Help customers trust your seller profile by confirming who you are.',
                    style: const TextStyle(color: _muted, height: 1.45),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            if (_readOnly)
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: _line),
                ),
                child: const Row(
                  children: [
                    CircularProgressIndicator(strokeWidth: 2),
                    SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        'No action is needed while the verification team reviews your submission.',
                      ),
                    ),
                  ],
                ),
              )
            else ...[
              _VerificationDocumentsCard(
                type: widget.type,
                verificationStatus: widget.status,
                requestedDocuments: widget.requestedDocuments,
                requiresTextResponse: widget.requiresTextResponse,
                responseController: widget.responseController,
                documents: widget.documents,
                confirmed: _confirmed,
                onAdd: (kind) async {
                  await widget.onAddDocument(kind);
                  if (mounted) setState(() {});
                },
                onRemove: (kind) {
                  widget.onRemoveDocument(kind);
                  setState(() {});
                },
                onConfirmed: (value) {
                  final confirmed = value ?? false;
                  setState(() => _confirmed = confirmed);
                  widget.onConfirmed(confirmed);
                },
              ),
              const SizedBox(height: 18),
              _PrimaryButton(
                label:
                    isAdminRequest
                        ? 'Submit requested information'
                        : 'Submit for verification',
                loading: _submitting,
                onPressed: () async {
                  setState(() => _submitting = true);
                  final submitted = await widget.onSubmit();
                  if (!context.mounted) return;
                  setState(() => _submitting = false);
                  if (submitted) Navigator.pop(context);
                },
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ProfilePage extends StatelessWidget {
  const _ProfilePage({
    required this.type,
    required this.consumer,
    required this.fullName,
    required this.email,
    required this.phone,
    required this.photoUrl,
    required this.publicName,
    required this.businessName,
    required this.location,
    required this.verificationStatus,
    required this.verificationMessage,
    required this.requestedVerificationDocuments,
    required this.verificationRequiresTextResponse,
    required this.verificationResponseController,
    required this.verificationDocuments,
    required this.verificationConfirmed,
    required this.busy,
    required this.onEditProfile,
    required this.onEditBusiness,
    required this.onAddVerificationDocument,
    required this.onRemoveVerificationDocument,
    required this.onVerificationConfirmed,
    required this.onVerify,
    required this.onSignOut,
  });
  final _AccountType type;
  final bool consumer;
  final String fullName;
  final String email;
  final String phone;
  final String? photoUrl;
  final String publicName;
  final String businessName;
  final ConfirmedLocation? location;
  final String verificationStatus;
  final String? verificationMessage;
  final List<String> requestedVerificationDocuments;
  final bool verificationRequiresTextResponse;
  final TextEditingController verificationResponseController;
  final List<VerificationDocumentUpload> verificationDocuments;
  final bool verificationConfirmed;
  final bool busy;
  final VoidCallback onEditProfile;
  final VoidCallback? onEditBusiness;
  final ValueChanged<String> onAddVerificationDocument;
  final ValueChanged<String> onRemoveVerificationDocument;
  final ValueChanged<bool?> onVerificationConfirmed;
  final VoidCallback onVerify;
  final VoidCallback onSignOut;

  String get _accountLabel {
    final seller = switch (type) {
      _AccountType.consumer => 'Consumer',
      _AccountType.producer => 'Side-hustle producer',
      _AccountType.business => 'Registered business',
    };
    return consumer && type != _AccountType.consumer
        ? 'Consumer + $seller'
        : seller;
  }

  @override
  Widget build(BuildContext context) {
    final isSeller = type != _AccountType.consumer;
    final canVerify = const {
      'DRAFT',
      'NEEDS_CHANGES',
      'REJECTED',
    }.contains(verificationStatus);
    return _ScrollPage(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 34,
                backgroundColor: _mist,
                backgroundImage:
                    photoUrl?.isNotEmpty == true
                        ? NetworkImage(photoUrl!)
                        : null,
                child:
                    photoUrl?.isNotEmpty == true
                        ? null
                        : Text(
                          fullName.isEmpty ? 'F' : fullName[0].toUpperCase(),
                          style: GoogleFonts.fraunces(
                            color: _green,
                            fontSize: 26,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _Eyebrow('YOUR PROFILE'),
                    Text(
                      fullName.isEmpty ? 'FRSH member' : fullName,
                      style: _title,
                    ),
                    const SizedBox(height: 4),
                    Text(_accountLabel, style: const TextStyle(color: _muted)),
                  ],
                ),
              ),
              IconButton(
                tooltip: localizeText(context, 'Edit profile'),
                onPressed: onEditProfile,
                icon: const Icon(Icons.edit_outlined),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _ProfileSection(
            icon: Icons.person_outline_rounded,
            title: 'Account details',
            lines: [email, phone].where((value) => value.isNotEmpty).toList(),
            onEdit: onEditProfile,
          ),
          if (isSeller) ...[
            const SizedBox(height: 12),
            _ProfileSection(
              icon:
                  type == _AccountType.business
                      ? Icons.storefront_outlined
                      : Icons.spa_outlined,
              title:
                  type == _AccountType.business
                      ? (businessName.isEmpty
                          ? 'Business profile'
                          : businessName)
                      : (publicName.isEmpty ? 'Seller profile' : publicName),
              lines: [
                if (location != null) location!.formattedAddress,
                if (location != null)
                  [
                    location!.postalCode,
                    location!.city,
                    location!.country,
                  ].where((value) => value.isNotEmpty).join(', '),
              ],
              onEdit: onEditBusiness ?? onEditProfile,
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color:
                    verificationStatus == 'VERIFIED'
                        ? const Color(0xFFE5F3DF)
                        : const Color(0xFFFFF5D9),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Icon(
                        verificationStatus == 'VERIFIED'
                            ? Icons.verified_rounded
                            : Icons.verified_user_outlined,
                        color: _deepGreen,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Seller verification',
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                            Text(
                              verificationStatus.replaceAll('_', ' '),
                              style: const TextStyle(
                                color: _muted,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (verificationMessage?.isNotEmpty == true &&
                      const {
                        'NEEDS_CHANGES',
                        'REJECTED',
                      }.contains(verificationStatus)) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.72),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        verificationMessage!,
                        style: const TextStyle(fontSize: 13, height: 1.4),
                      ),
                    ),
                  ],
                  if (canVerify) ...[
                    const SizedBox(height: 13),
                    _VerificationDocumentsCard(
                      type: type,
                      verificationStatus: verificationStatus,
                      requestedDocuments: requestedVerificationDocuments,
                      requiresTextResponse: verificationRequiresTextResponse,
                      responseController: verificationResponseController,
                      documents: verificationDocuments,
                      confirmed: verificationConfirmed,
                      onAdd: onAddVerificationDocument,
                      onRemove: onRemoveVerificationDocument,
                      onConfirmed: onVerificationConfirmed,
                    ),
                    const SizedBox(height: 13),
                    _PrimaryButton(
                      label:
                          verificationStatus == 'NEEDS_CHANGES'
                              ? 'Resubmit for verification'
                              : 'Apply for verification',
                      onPressed: onVerify,
                      loading: busy,
                    ),
                  ],
                ],
              ),
            ),
          ],
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: onSignOut,
            icon: const Icon(Icons.logout_rounded),
            label: const Text('Sign out'),
            style: _outlineStyle,
          ),
        ],
      ),
    );
  }
}

class _FarmStoryCard extends StatelessWidget {
  const _FarmStoryCard({
    required this.description,
    required this.farmId,
    required this.onEdit,
  });

  final String description;
  final String? farmId;
  final VoidCallback onEdit;

  String get _shortFarmId {
    final id = farmId;
    if (id == null || id.isEmpty) return '';
    return id.length <= 10 ? id : id.substring(id.length - 10).toUpperCase();
  }

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF1C5137), Color(0xFF347652)],
      ),
      borderRadius: BorderRadius.circular(24),
      boxShadow: const [
        BoxShadow(
          color: Color(0x24133C29),
          blurRadius: 22,
          offset: Offset(0, 10),
        ),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: .14),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.auto_stories_outlined,
                color: Colors.white,
                size: 21,
              ),
            ),
            const SizedBox(width: 11),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'OUR STORY',
                    style: TextStyle(
                      color: Color(0xFFCDE4D4),
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.2,
                    ),
                  ),
                  Text(
                    'About the farm',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Edit farm story',
              onPressed: onEdit,
              icon: const Icon(Icons.edit_outlined, color: Colors.white),
            ),
          ],
        ),
        const SizedBox(height: 15),
        Text(
          description.isNotEmpty
              ? description
              : 'Tell customers what you grow or make, how you work, and what makes your farm worth following.',
          style: TextStyle(
            color:
                description.isNotEmpty
                    ? Colors.white
                    : Colors.white.withValues(alpha: .72),
            height: 1.5,
            fontSize: 14,
          ),
        ),
        if (_shortFarmId.isNotEmpty) ...[
          const SizedBox(height: 18),
          InkWell(
            borderRadius: BorderRadius.circular(999),
            onTap: () async {
              await Clipboard.setData(ClipboardData(text: farmId!));
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Farm ID copied.')),
                );
              }
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: .12),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.fingerprint_rounded,
                    color: Color(0xFFCDE4D4),
                    size: 15,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Farm ID  $_shortFarmId',
                    style: const TextStyle(
                      color: Color(0xFFE7F3EA),
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Icon(
                    Icons.copy_rounded,
                    color: Color(0xFFCDE4D4),
                    size: 13,
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    ),
  );
}

class _ProfileSection extends StatelessWidget {
  const _ProfileSection({
    required this.icon,
    required this.title,
    required this.lines,
    required this.onEdit,
  });
  final IconData icon;
  final String title;
  final List<String> lines;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(15),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      boxShadow: const [
        BoxShadow(
          color: Color(0x0F0D2A1B),
          blurRadius: 16,
          offset: Offset(0, 6),
        ),
      ],
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: _mist,
            borderRadius: BorderRadius.circular(13),
          ),
          child: Icon(icon, color: _green, size: 21),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
              for (final line in lines)
                Padding(
                  padding: const EdgeInsets.only(top: 3),
                  child: Text(
                    line,
                    style: const TextStyle(color: _muted, fontSize: 12),
                  ),
                ),
            ],
          ),
        ),
        TextButton(onPressed: onEdit, child: const Text('Edit')),
      ],
    ),
  );
}

class _VerificationDocumentsCard extends StatelessWidget {
  const _VerificationDocumentsCard({
    required this.type,
    required this.verificationStatus,
    required this.requestedDocuments,
    required this.requiresTextResponse,
    required this.responseController,
    required this.documents,
    required this.confirmed,
    required this.onAdd,
    required this.onRemove,
    required this.onConfirmed,
  });

  final _AccountType type;
  final String verificationStatus;
  final List<String> requestedDocuments;
  final bool requiresTextResponse;
  final TextEditingController responseController;
  final List<VerificationDocumentUpload> documents;
  final bool confirmed;
  final ValueChanged<String> onAdd;
  final ValueChanged<String> onRemove;
  final ValueChanged<bool?> onConfirmed;

  List<_VerificationDocumentRequirement> get _requirements {
    if (verificationStatus == 'NEEDS_CHANGES') {
      return requestedDocuments
          .map(
            (kind) => _VerificationDocumentRequirement(
              kind: kind,
              label: _documentKindLabel(kind),
              required: true,
            ),
          )
          .toList();
    }
    if (type == _AccountType.business) {
      return const [
        _VerificationDocumentRequirement(
          kind: 'BUSINESS_REGISTRATION',
          label: 'Business registration',
          required: true,
        ),
        _VerificationDocumentRequirement(
          kind: 'VAT_REGISTRATION',
          label: 'Tax or VAT document',
        ),
      ];
    }
    return const [
      _VerificationDocumentRequirement(
        kind: 'IDENTITY',
        label: 'Proof of identity',
        required: true,
      ),
      _VerificationDocumentRequirement(
        kind: 'ADDRESS_PROOF',
        label: 'Activity or location proof',
      ),
    ];
  }

  VerificationDocumentUpload? _documentFor(String kind) {
    for (final document in documents) {
      if (document.kind == kind) return document;
    }
    return null;
  }

  static String _documentKindLabel(String kind) => switch (kind) {
    'IDENTITY' => 'Proof of identity',
    'BUSINESS_REGISTRATION' => 'Business registration proof',
    'VAT_REGISTRATION' => 'Tax or VAT document',
    'ADDRESS_PROOF' => 'Activity or location proof',
    'OTHER' => 'Other document',
    _ => 'Verification document',
  };

  @override
  Widget build(BuildContext context) {
    final isChangeRequest = verificationStatus == 'NEEDS_CHANGES';
    final requirements = _requirements;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.76),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            isChangeRequest ? 'Requested update' : 'Verification proof',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 5),
          Text(
            isChangeRequest
                ? 'Reply to the review team and upload only the requested file(s).'
                : 'Review the details above, attach proof, then confirm they are correct.',
            style: TextStyle(color: _muted, fontSize: 12, height: 1.35),
          ),
          const SizedBox(height: 12),
          if (requirements.isEmpty && isChangeRequest)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _cream,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _line),
              ),
              child: const Text(
                'No new file upload requested.',
                style: TextStyle(color: _muted, fontSize: 12, height: 1.35),
              ),
            )
          else
            for (final requirement in requirements) ...[
              _VerificationDocumentRow(
                requirement: requirement,
                document: _documentFor(requirement.kind),
                onAdd: () => onAdd(requirement.kind),
                onRemove: () => onRemove(requirement.kind),
              ),
              const SizedBox(height: 8),
            ],
          if (requiresTextResponse) ...[
            const SizedBox(height: 4),
            TextField(
              controller: responseController,
              minLines: 3,
              maxLines: 5,
              textInputAction: TextInputAction.newline,
              decoration: InputDecoration(
                labelText: localizeText(context, 'Response to reviewer'),
                hintText: localizeText(
                  context,
                  'Answer the question or explain what you changed.',
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            value: confirmed,
            onChanged: onConfirmed,
            title: const Text(
              'I confirm these details are accurate and I am responsible for the products I sell.',
              style: TextStyle(fontSize: 12, height: 1.35),
            ),
          ),
        ],
      ),
    );
  }
}

class _VerificationDocumentRequirement {
  const _VerificationDocumentRequirement({
    required this.kind,
    required this.label,
    this.required = false,
  });

  final String kind;
  final String label;
  final bool required;
}

class _VerificationDocumentRow extends StatelessWidget {
  const _VerificationDocumentRow({
    required this.requirement,
    required this.document,
    required this.onAdd,
    required this.onRemove,
  });

  final _VerificationDocumentRequirement requirement;
  final VerificationDocumentUpload? document;
  final VoidCallback onAdd;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    decoration: BoxDecoration(
      color: _cream,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: _line),
    ),
    child: Row(
      children: [
        Icon(
          document == null
              ? Icons.upload_file_outlined
              : Icons.check_circle_rounded,
          color: _green,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                requirement.required
                    ? '${requirement.label} *'
                    : requirement.label,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              Text(
                document?.originalName ?? 'PDF or image upload',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: _muted, fontSize: 12),
              ),
            ],
          ),
        ),
        if (document == null)
          TextButton(onPressed: onAdd, child: const Text('Add'))
        else
          IconButton(
            tooltip: localizeText(context, 'Remove'),
            onPressed: onRemove,
            icon: const Icon(Icons.close_rounded),
          ),
      ],
    ),
  );
}

class _PhotoPicker extends StatelessWidget {
  const _PhotoPicker({
    required this.photoUrl,
    required this.photoBytes,
    required this.onTap,
  });
  final String? photoUrl;
  final Uint8List? photoBytes;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Center(
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Column(
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              CircleAvatar(
                radius: 38,
                backgroundColor: _mist,
                backgroundImage:
                    photoBytes != null
                        ? MemoryImage(photoBytes!)
                        : photoUrl == null
                        ? null
                        : NetworkImage(photoUrl!),
                child:
                    photoBytes == null && photoUrl == null
                        ? const Icon(
                          Icons.person_outline_rounded,
                          color: _green,
                          size: 38,
                        )
                        : null,
              ),
              Positioned(
                right: -4,
                bottom: -2,
                child: Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: _green,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  child: const Icon(
                    Icons.add_rounded,
                    size: 18,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 7),
          Text(
            photoBytes != null || photoUrl != null
                ? 'Change profile photo'
                : 'Add profile photo · optional',
            style: const TextStyle(color: _muted, fontSize: 12),
          ),
        ],
      ),
    ),
  );
}

class _RequiredField extends StatelessWidget {
  const _RequiredField({required this.label, this.controller});
  final String label;
  final TextEditingController? controller;

  @override
  Widget build(BuildContext context) => TextFormField(
    controller: controller,
    decoration: InputDecoration(labelText: '${localizeText(context, label)} *'),
    validator:
        (value) =>
            value == null || value.trim().isEmpty
                ? localizeText(context, '$label is required.')
                : null,
  );
}

class _InternationalPhoneField extends StatefulWidget {
  const _InternationalPhoneField({required this.controller});
  final TextEditingController controller;

  @override
  State<_InternationalPhoneField> createState() =>
      _InternationalPhoneFieldState();
}

class _InternationalPhoneFieldState extends State<_InternationalPhoneField> {
  late Country _country;
  final _national = TextEditingController();
  bool _writingCanonical = false;

  @override
  void initState() {
    super.initState();
    final locales = WidgetsBinding.instance.platformDispatcher.locales;
    final region =
        locales
            .map((locale) => locale.countryCode?.toUpperCase())
            .whereType<String>()
            .where((code) => code.isNotEmpty && code != 'US')
            .firstOrNull;

    // Many browsers report en-US even when the user is physically elsewhere.
    // FRSH Nearby currently launches in Finland, so do not turn that generic
    // browser fallback into an incorrect +1 default. The picker remains
    // available for users whose calling code differs from their device region.
    _country = Country.tryParse(region ?? 'FI') ?? Country.parse('FI');
    widget.controller.addListener(_hydrateFromCanonical);
    _hydrateFromCanonical();
    _sync();
  }

  @override
  void dispose() {
    widget.controller.removeListener(_hydrateFromCanonical);
    _national.dispose();
    super.dispose();
  }

  void _hydrateFromCanonical() {
    if (_writingCanonical || _national.text.isNotEmpty) return;
    final canonical = widget.controller.text.trim();
    if (!canonical.startsWith('+')) return;
    final countries =
        CountryService()
            .getAll()
            .where((item) => canonical.startsWith('+${item.phoneCode}'))
            .toList()
          ..sort((a, b) => b.phoneCode.length.compareTo(a.phoneCode.length));
    if (countries.isEmpty) return;
    final selected = countries.first;
    final national = canonical.substring(selected.phoneCode.length + 1);
    if (mounted) {
      setState(() => _country = selected);
      _national.text = national;
    }
  }

  void _sync() {
    final number = _national.text
        .replaceAll(RegExp(r'\D'), '')
        .replaceFirst(RegExp(r'^0+'), '');
    _writingCanonical = true;
    widget.controller.text = '+${_country.phoneCode}$number';
    _writingCanonical = false;
  }

  void _chooseCountry() {
    showCountryPicker(
      context: context,
      showPhoneCode: true,
      countryListTheme: CountryListThemeData(
        bottomSheetHeight: 560,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        inputDecoration: InputDecoration(
          labelText: localizeText(context, 'Search country or code'),
          prefixIcon: const Icon(Icons.search),
        ),
      ),
      onSelect: (country) {
        setState(() => _country = country);
        _sync();
      },
    );
  }

  @override
  Widget build(BuildContext context) => TextFormField(
    controller: _national,
    keyboardType: TextInputType.phone,
    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
    onChanged: (_) => _sync(),
    decoration: InputDecoration(
      labelText: localizeText(context, 'Phone number *'),
      hintText:
          _country.example.isEmpty
              ? localizeText(context, 'Phone number')
              : _country.example,
      prefixIconConstraints: const BoxConstraints(minWidth: 108),
      prefixIcon: InkWell(
        onTap: _chooseCountry,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_country.flagEmoji, style: const TextStyle(fontSize: 21)),
              const SizedBox(width: 6),
              Text('+${_country.phoneCode}'),
              const SizedBox(width: 2),
              const Icon(Icons.arrow_drop_down, size: 18),
            ],
          ),
        ),
      ),
    ),
    validator: (_) {
      final value = widget.controller.text;
      return RegExp(r'^\+[1-9]\d{7,14}$').hasMatch(value)
          ? null
          : localizeText(context, 'Enter a valid phone number.');
    },
  );
}

class _TypeCard extends StatelessWidget {
  const _TypeCard({
    required this.selected,
    required this.image,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.badge,
  });
  final bool selected;
  final String image;
  final String title;
  final String subtitle;
  final String? badge;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    selected: selected,
    button: true,
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFF2F6EE) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? _green : _line,
            width: selected ? 1.6 : 1,
          ),
          boxShadow:
              selected
                  ? const [
                    BoxShadow(
                      color: Color(0x142F6B45),
                      blurRadius: 14,
                      offset: Offset(0, 6),
                    ),
                  ]
                  : const [],
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Image.asset(
                image,
                width: 60,
                height: 60,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          title,
                          style: const TextStyle(
                            fontSize: 15.5,
                            fontWeight: FontWeight.w600,
                            color: _ink,
                          ),
                        ),
                      ),
                      if (badge != null) ...[
                        const SizedBox(width: 7),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1EFE6),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(color: _line),
                          ),
                          child: Text(
                            badge!,
                            style: const TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              letterSpacing: .6,
                              color: _muted,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: _muted,
                      fontSize: 12.5,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              transitionBuilder:
                  (child, animation) =>
                      ScaleTransition(scale: animation, child: child),
              child: Icon(
                selected
                    ? Icons.check_circle_rounded
                    : Icons.radio_button_unchecked_rounded,
                key: ValueKey(selected),
                color: selected ? _green : _line,
                size: 22,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _SummaryTile extends StatelessWidget {
  const _SummaryTile({
    required this.icon,
    required this.title,
    required this.value,
    this.onEdit,
  });
  final IconData icon;
  final String title;
  final String value;
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: _line),
    ),
    child: Row(
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: _mist,
            borderRadius: BorderRadius.circular(13),
          ),
          child: Icon(icon, color: _green, size: 21),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(color: _muted, fontSize: 12)),
              Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
            ],
          ),
        ),
        if (onEdit != null)
          TextButton(onPressed: onEdit, child: const Text('Edit'))
        else
          const Icon(Icons.check_circle_rounded, color: _green, size: 20),
      ],
    ),
  );
}

class _Segmented extends StatelessWidget {
  const _Segmented({
    required this.left,
    required this.right,
    required this.leftSelected,
    required this.onLeft,
    required this.onRight,
  });
  final String left;
  final String right;
  final bool leftSelected;
  final VoidCallback onLeft;
  final VoidCallback onRight;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(4),
    decoration: BoxDecoration(
      color: _field,
      borderRadius: BorderRadius.circular(999),
    ),
    child: Row(
      children: [
        Expanded(
          child: _Segment(label: left, selected: leftSelected, onTap: onLeft),
        ),
        Expanded(
          child: _Segment(
            label: right,
            selected: !leftSelected,
            onTap: onRight,
          ),
        ),
      ],
    ),
  );
}

class _Segment extends StatelessWidget {
  const _Segment({
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(999),
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
      padding: const EdgeInsets.symmetric(vertical: 11),
      decoration: BoxDecoration(
        color: selected ? Colors.white : Colors.transparent,
        borderRadius: BorderRadius.circular(999),
        boxShadow:
            selected
                ? const [
                  BoxShadow(
                    color: Color(0x1420301F),
                    blurRadius: 8,
                    offset: Offset(0, 2),
                  ),
                ]
                : const [],
      ),
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: selected ? _ink : _muted,
          fontWeight: FontWeight.w600,
          fontSize: 13.5,
        ),
      ),
    ),
  );
}

class _ProviderButton extends StatelessWidget {
  const _ProviderButton({
    required this.label,
    required this.loading,
    required this.onPressed,
  });
  final String label;
  final bool loading;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => OutlinedButton(
    onPressed: loading ? null : onPressed,
    style: _outlineStyle,
    child: Row(
      children: [
        SizedBox(
          width: 22,
          height: 22,
          child: SvgPicture.string(_googleLogoSvg),
        ),
        Expanded(child: Text(label, textAlign: TextAlign.center)),
        const SizedBox(width: 22),
      ],
    ),
  );
}

const _googleLogoSvg = '''
<svg viewBox="0 0 48 48" xmlns="http://www.w3.org/2000/svg">
<path fill="#EA4335" d="M24 9.5c3.54 0 6.71 1.22 9.21 3.6l6.85-6.85C35.9 2.38 30.47 0 24 0 14.62 0 6.51 5.38 2.56 13.22l7.98 6.19C12.43 13.72 17.74 9.5 24 9.5z"/>
<path fill="#4285F4" d="M46.98 24.55c0-1.57-.15-3.09-.38-4.55H24v9.02h12.94c-.58 2.96-2.26 5.48-4.78 7.18l7.73 6c4.51-4.18 7.09-10.36 7.09-17.65z"/>
<path fill="#FBBC05" d="M10.53 28.59c-.48-1.45-.76-2.99-.76-4.59s.27-3.14.76-4.59l-7.98-6.19C.92 16.46 0 20.12 0 24c0 3.88.92 7.54 2.56 10.78l7.97-6.19z"/>
<path fill="#34A853" d="M24 48c6.48 0 11.93-2.13 15.89-5.81l-7.73-6c-2.15 1.45-4.92 2.3-8.16 2.3-6.26 0-11.57-4.22-13.47-9.91l-7.98 6.19C6.51 42.62 14.62 48 24 48z"/>
</svg>
''';

class _PrimaryButton extends StatefulWidget {
  const _PrimaryButton({
    required this.label,
    required this.onPressed,
    this.loading = false,
  });
  final String label;
  final VoidCallback? onPressed;
  final bool loading;

  @override
  State<_PrimaryButton> createState() => _PrimaryButtonState();
}

class _PrimaryButtonState extends State<_PrimaryButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final enabled = !widget.loading && widget.onPressed != null;
    return AnimatedScale(
      scale: _pressed && enabled ? .98 : 1,
      duration: const Duration(milliseconds: 120),
      curve: Curves.easeOut,
      child: Listener(
        onPointerDown: (_) => setState(() => _pressed = true),
        onPointerUp: (_) => setState(() => _pressed = false),
        onPointerCancel: (_) => setState(() => _pressed = false),
        child: FilledButton(
          onPressed: widget.loading ? null : widget.onPressed,
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(56),
            backgroundColor: _deepGreen,
            disabledBackgroundColor:
                widget.loading ? _deepGreen : const Color(0xFFD8DCD2),
            disabledForegroundColor: widget.loading ? Colors.white70 : _muted,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            textStyle: const TextStyle(
              fontSize: 15.5,
              fontWeight: FontWeight.w600,
              letterSpacing: .2,
            ),
          ),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child:
                widget.loading
                    ? const SizedBox(
                      key: ValueKey('spinner'),
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                    : Text(widget.label, key: const ValueKey('label')),
          ),
        ),
      ),
    );
  }
}

class _Eyebrow extends StatelessWidget {
  const _Eyebrow(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 7),
    child: Text(
      text,
      style: const TextStyle(
        color: Color(0xFF57705C),
        fontSize: 10.5,
        letterSpacing: 1.8,
        fontWeight: FontWeight.w700,
      ),
    ),
  );
}

class _ScrollPage extends StatelessWidget {
  const _ScrollPage({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    tween: Tween(begin: 0, end: 1),
    duration: const Duration(milliseconds: 450),
    curve: Curves.easeOutCubic,
    builder:
        (context, value, child) => Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 14 * (1 - value)),
            child: child,
          ),
        ),
    child: SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 22, 24, 28),
      child: child,
    ),
  );
}

final _title = GoogleFonts.fraunces(
  color: _ink,
  fontSize: 25,
  height: 1.15,
  fontWeight: FontWeight.w600,
  letterSpacing: -.3,
);

final _outlineStyle = OutlinedButton.styleFrom(
  minimumSize: const Size.fromHeight(54),
  foregroundColor: _ink,
  backgroundColor: Colors.white,
  side: const BorderSide(color: _line),
  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
  textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
);
