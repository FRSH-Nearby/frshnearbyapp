import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_fi.dart';
import 'app_localizations_sv.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('fi'),
    Locale('sv'),
  ];

  /// The application name shown in the app bar and launcher
  ///
  /// In en, this message translates to:
  /// **'FRSH nearby'**
  String get appTitle;

  /// Tagline shown on the landing/home screen
  ///
  /// In en, this message translates to:
  /// **'Fresh food from farms near you'**
  String get welcomeMessage;

  /// Generic continue button label
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get actionContinue;

  /// Generic cancel button label
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get actionCancel;

  /// Retry button shown on error states
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get actionRetry;

  /// Fallback error message
  ///
  /// In en, this message translates to:
  /// **'Something went wrong. Please try again.'**
  String get errorGeneric;

  /// The name of the current language, shown in the language picker
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get languageName;

  /// Registration screen heading
  ///
  /// In en, this message translates to:
  /// **'Join your local food community'**
  String get authRegisterTitle;

  /// Registration screen supporting text
  ///
  /// In en, this message translates to:
  /// **'Create your account in under a minute.'**
  String get authRegisterSubtitle;

  /// Login screen heading
  ///
  /// In en, this message translates to:
  /// **'Welcome back'**
  String get authLoginTitle;

  /// Login screen supporting text
  ///
  /// In en, this message translates to:
  /// **'Log in to discover fresh food nearby.'**
  String get authLoginSubtitle;

  /// Registration mode tab
  ///
  /// In en, this message translates to:
  /// **'Register'**
  String get authRegisterTab;

  /// Login mode tab
  ///
  /// In en, this message translates to:
  /// **'Log in'**
  String get authLoginTab;

  /// Divider between social and email login
  ///
  /// In en, this message translates to:
  /// **'or continue with email'**
  String get authOrEmail;

  /// Full name field label
  ///
  /// In en, this message translates to:
  /// **'Full name'**
  String get authFullName;

  /// Email field label
  ///
  /// In en, this message translates to:
  /// **'Email address'**
  String get authEmail;

  /// Password field label
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get authPassword;

  /// Password visibility tooltip
  ///
  /// In en, this message translates to:
  /// **'Show password'**
  String get authShowPassword;

  /// Password visibility tooltip
  ///
  /// In en, this message translates to:
  /// **'Hide password'**
  String get authHidePassword;

  /// Password recovery action
  ///
  /// In en, this message translates to:
  /// **'Forgot password?'**
  String get authForgotPassword;

  /// Role choice heading
  ///
  /// In en, this message translates to:
  /// **'I want to'**
  String get authRoleTitle;

  /// Consumer role label
  ///
  /// In en, this message translates to:
  /// **'Buy local'**
  String get authConsumer;

  /// Consumer role description
  ///
  /// In en, this message translates to:
  /// **'Discover fresh food nearby'**
  String get authConsumerShort;

  /// Producer role label
  ///
  /// In en, this message translates to:
  /// **'Sell food'**
  String get authProducer;

  /// Producer role description
  ///
  /// In en, this message translates to:
  /// **'Share what you produce'**
  String get authProducerShort;

  /// Minimum age confirmation
  ///
  /// In en, this message translates to:
  /// **'I confirm I am at least 18 years old.'**
  String get authAdultAgreement;

  /// Account creation button
  ///
  /// In en, this message translates to:
  /// **'Create account'**
  String get authCreateAccount;

  /// Login button
  ///
  /// In en, this message translates to:
  /// **'Log in'**
  String get authLoginAction;

  /// Terms acknowledgement
  ///
  /// In en, this message translates to:
  /// **'By creating an account, you agree to our Terms and Privacy Policy.'**
  String get authTerms;

  /// Empty name validation error
  ///
  /// In en, this message translates to:
  /// **'Enter your name.'**
  String get authNameError;

  /// Invalid email validation error
  ///
  /// In en, this message translates to:
  /// **'Enter a valid email address.'**
  String get authEmailError;

  /// Invalid password validation error
  ///
  /// In en, this message translates to:
  /// **'Use at least 8 characters.'**
  String get authPasswordError;

  /// Missing age confirmation error
  ///
  /// In en, this message translates to:
  /// **'Please confirm that you are at least 18.'**
  String get authAgeError;

  /// Prototype submission confirmation
  ///
  /// In en, this message translates to:
  /// **'Looks good! Authentication will be connected next.'**
  String get authDemoMessage;

  /// No description provided for @authSimpleTitle.
  ///
  /// In en, this message translates to:
  /// **'Fresh food near you'**
  String get authSimpleTitle;

  /// No description provided for @authSimpleSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Sign in or create your account in a few taps.'**
  String get authSimpleSubtitle;

  /// No description provided for @authContinueGoogle.
  ///
  /// In en, this message translates to:
  /// **'Continue with Google'**
  String get authContinueGoogle;

  /// No description provided for @authContinueApple.
  ///
  /// In en, this message translates to:
  /// **'Continue with Apple'**
  String get authContinueApple;

  /// No description provided for @authContinueFacebook.
  ///
  /// In en, this message translates to:
  /// **'Continue with Facebook'**
  String get authContinueFacebook;

  /// No description provided for @authSocialHint.
  ///
  /// In en, this message translates to:
  /// **'Already registered? We\'ll log you in. New here? We\'ll help you finish signing up.'**
  String get authSocialHint;

  /// No description provided for @authConfirmDetails.
  ///
  /// In en, this message translates to:
  /// **'Confirm your details'**
  String get authConfirmDetails;

  /// No description provided for @authConfirmDetailsHint.
  ///
  /// In en, this message translates to:
  /// **'We filled in what your account shared.'**
  String get authConfirmDetailsHint;

  /// No description provided for @authPhotoOptional.
  ///
  /// In en, this message translates to:
  /// **'Profile photo · optional'**
  String get authPhotoOptional;

  /// No description provided for @authGender.
  ///
  /// In en, this message translates to:
  /// **'Gender'**
  String get authGender;

  /// No description provided for @authGenderWoman.
  ///
  /// In en, this message translates to:
  /// **'Woman'**
  String get authGenderWoman;

  /// No description provided for @authGenderMan.
  ///
  /// In en, this message translates to:
  /// **'Man'**
  String get authGenderMan;

  /// No description provided for @authGenderOther.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get authGenderOther;

  /// No description provided for @authPhone.
  ///
  /// In en, this message translates to:
  /// **'Phone'**
  String get authPhone;

  /// No description provided for @authRoleTitleNew.
  ///
  /// In en, this message translates to:
  /// **'How will you use FRSH?'**
  String get authRoleTitleNew;

  /// No description provided for @authRoleHint.
  ///
  /// In en, this message translates to:
  /// **'Choose one for now. You can switch later.'**
  String get authRoleHint;

  /// No description provided for @authConsumerMessage.
  ///
  /// In en, this message translates to:
  /// **'Find fresh food and trusted producers close to you.'**
  String get authConsumerMessage;

  /// No description provided for @authProducerMessage.
  ///
  /// In en, this message translates to:
  /// **'Share your food locally. Your producer profile will be reviewed before publishing.'**
  String get authProducerMessage;

  /// No description provided for @authAlmostDone.
  ///
  /// In en, this message translates to:
  /// **'Almost done'**
  String get authAlmostDone;

  /// No description provided for @authAlmostDoneHint.
  ///
  /// In en, this message translates to:
  /// **'Check your setup and create your profile.'**
  String get authAlmostDoneHint;

  /// No description provided for @authDetailsConfirmed.
  ///
  /// In en, this message translates to:
  /// **'Personal details confirmed'**
  String get authDetailsConfirmed;

  /// No description provided for @authAdminReview.
  ///
  /// In en, this message translates to:
  /// **'Producer profiles are reviewed by our team'**
  String get authAdminReview;

  /// No description provided for @authFinishSetup.
  ///
  /// In en, this message translates to:
  /// **'Create my profile'**
  String get authFinishSetup;

  /// No description provided for @authWelcomeReady.
  ///
  /// In en, this message translates to:
  /// **'You\'re ready!'**
  String get authWelcomeReady;

  /// No description provided for @authVerificationPending.
  ///
  /// In en, this message translates to:
  /// **'Your profile is created. Producer verification may take a little time.'**
  String get authVerificationPending;

  /// No description provided for @authEnterApp.
  ///
  /// In en, this message translates to:
  /// **'Enter FRSH nearby'**
  String get authEnterApp;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'fi', 'sv'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'fi':
      return AppLocalizationsFi();
    case 'sv':
      return AppLocalizationsSv();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
