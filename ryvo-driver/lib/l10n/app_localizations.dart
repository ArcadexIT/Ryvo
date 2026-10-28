import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';

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

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
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
  static const List<Locale> supportedLocales = <Locale>[Locale('en')];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'Ryvo Driver'**
  String get appTitle;

  /// No description provided for @search.
  ///
  /// In en, this message translates to:
  /// **'Search...'**
  String get search;

  /// No description provided for @noMatches.
  ///
  /// In en, this message translates to:
  /// **'No matches'**
  String get noMatches;

  /// No description provided for @reasonOptional.
  ///
  /// In en, this message translates to:
  /// **'Reason (optional)'**
  String get reasonOptional;

  /// No description provided for @keepJob.
  ///
  /// In en, this message translates to:
  /// **'Keep job'**
  String get keepJob;

  /// No description provided for @cancelJob.
  ///
  /// In en, this message translates to:
  /// **'Cancel job'**
  String get cancelJob;

  /// No description provided for @ryvoDriver.
  ///
  /// In en, this message translates to:
  /// **'Ryvo Driver'**
  String get ryvoDriver;

  /// No description provided for @noActiveJobToChatOn.
  ///
  /// In en, this message translates to:
  /// **'No active job to chat on'**
  String get noActiveJobToChatOn;

  /// No description provided for @selectCountry.
  ///
  /// In en, this message translates to:
  /// **'Select Country'**
  String get selectCountry;

  /// No description provided for @couldNotLoadCountriesCheckYourConnection.
  ///
  /// In en, this message translates to:
  /// **'Could not load countries. Check your connection.'**
  String get couldNotLoadCountriesCheckYourConnection;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// No description provided for @noCountriesAreAvailableForRegistrationYetPleaseC.
  ///
  /// In en, this message translates to:
  /// **'No countries are available for registration yet. Please contact support.'**
  String get noCountriesAreAvailableForRegistrationYetPleaseC;

  /// No description provided for @searchCountryOrDialCode.
  ///
  /// In en, this message translates to:
  /// **'Search country or dial code'**
  String get searchCountryOrDialCode;

  /// No description provided for @noCountriesFound.
  ///
  /// In en, this message translates to:
  /// **'No countries found'**
  String get noCountriesFound;

  /// No description provided for @goOnlineEarn.
  ///
  /// In en, this message translates to:
  /// **'Go Online & Earn'**
  String get goOnlineEarn;

  /// No description provided for @toggleOnlineWhenYouReReadyReceiveNearbyJumpStart.
  ///
  /// In en, this message translates to:
  /// **'Toggle online when you\'re ready. Nearby ride requests come in, and you earn when the trip ends.'**
  String get toggleOnlineWhenYouReReadyReceiveNearbyJumpStart;

  /// No description provided for @acceptJobsInstantly.
  ///
  /// In en, this message translates to:
  /// **'Accept rides instantly'**
  String get acceptJobsInstantly;

  /// No description provided for @reviewCustomerDetailsDistanceAndPayoutAcceptOrDe.
  ///
  /// In en, this message translates to:
  /// **'See pickup, dropoff, and your earning. Accept or decline within seconds.'**
  String get reviewCustomerDetailsDistanceAndPayoutAcceptOrDe;

  /// No description provided for @getPaidFast.
  ///
  /// In en, this message translates to:
  /// **'Get Paid Fast'**
  String get getPaidFast;

  /// No description provided for @trackEarningsInRealTimeWithdrawToYourBankAccount.
  ///
  /// In en, this message translates to:
  /// **'Track earnings in real time. Withdraw to your bank account anytime.'**
  String get trackEarningsInRealTimeWithdrawToYourBankAccount;

  /// No description provided for @skip.
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get skip;

  /// No description provided for @providerEarnHelpingDrivers.
  ///
  /// In en, this message translates to:
  /// **'Driver — Earn Helping Drivers'**
  String get providerEarnHelpingDrivers;

  /// No description provided for @wallet.
  ///
  /// In en, this message translates to:
  /// **'Wallet'**
  String get wallet;

  /// No description provided for @paymentMethods.
  ///
  /// In en, this message translates to:
  /// **'Payment methods'**
  String get paymentMethods;

  /// No description provided for @availableToWithdraw.
  ///
  /// In en, this message translates to:
  /// **'Available to withdraw'**
  String get availableToWithdraw;

  /// No description provided for @inTransit.
  ///
  /// In en, this message translates to:
  /// **'In transit'**
  String get inTransit;

  /// No description provided for @addABankAccountBeforeWithdrawing.
  ///
  /// In en, this message translates to:
  /// **'Add a bank account before withdrawing'**
  String get addABankAccountBeforeWithdrawing;

  /// No description provided for @add.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get add;

  /// No description provided for @recentPayouts.
  ///
  /// In en, this message translates to:
  /// **'Recent Payouts'**
  String get recentPayouts;

  /// No description provided for @noPayoutsYet.
  ///
  /// In en, this message translates to:
  /// **'No payouts yet'**
  String get noPayoutsYet;

  /// No description provided for @withdrawalsYouRequestWillAppearHere.
  ///
  /// In en, this message translates to:
  /// **'Withdrawals you request will appear here'**
  String get withdrawalsYouRequestWillAppearHere;

  /// No description provided for @fillInBankNameHolderNameAndAccountNumber.
  ///
  /// In en, this message translates to:
  /// **'Fill in bank name, holder name, and account number'**
  String get fillInBankNameHolderNameAndAccountNumber;

  /// No description provided for @bankAccountAdded.
  ///
  /// In en, this message translates to:
  /// **'Bank account added'**
  String get bankAccountAdded;

  /// No description provided for @couldNotAddBankAccount.
  ///
  /// In en, this message translates to:
  /// **'Could not add bank account'**
  String get couldNotAddBankAccount;

  /// No description provided for @addBankAccount.
  ///
  /// In en, this message translates to:
  /// **'Add Bank Account'**
  String get addBankAccount;

  /// No description provided for @bankName.
  ///
  /// In en, this message translates to:
  /// **'Bank name'**
  String get bankName;

  /// No description provided for @bankName2.
  ///
  /// In en, this message translates to:
  /// **'Bank Name'**
  String get bankName2;

  /// No description provided for @accountHolderName.
  ///
  /// In en, this message translates to:
  /// **'Account holder name'**
  String get accountHolderName;

  /// No description provided for @accountHolder.
  ///
  /// In en, this message translates to:
  /// **'Account Holder'**
  String get accountHolder;

  /// No description provided for @accountNumber.
  ///
  /// In en, this message translates to:
  /// **'Account number'**
  String get accountNumber;

  /// No description provided for @accountNumber2.
  ///
  /// In en, this message translates to:
  /// **'Account Number'**
  String get accountNumber2;

  /// No description provided for @routingNumberOptional.
  ///
  /// In en, this message translates to:
  /// **'Routing number (optional)'**
  String get routingNumberOptional;

  /// No description provided for @routingNumber.
  ///
  /// In en, this message translates to:
  /// **'Routing Number'**
  String get routingNumber;

  /// No description provided for @payoutDestination.
  ///
  /// In en, this message translates to:
  /// **'Payout destination'**
  String get payoutDestination;

  /// No description provided for @addNewAccount.
  ///
  /// In en, this message translates to:
  /// **'Add new account'**
  String get addNewAccount;

  /// No description provided for @confirmWithdrawal.
  ///
  /// In en, this message translates to:
  /// **'Confirm withdrawal'**
  String get confirmWithdrawal;

  /// No description provided for @reviewTheDetailsBeforeSubmittingYourPayoutReques.
  ///
  /// In en, this message translates to:
  /// **'Review the details before submitting your payout request.'**
  String get reviewTheDetailsBeforeSubmittingYourPayoutReques;

  /// No description provided for @amount.
  ///
  /// In en, this message translates to:
  /// **'Amount'**
  String get amount;

  /// No description provided for @destination.
  ///
  /// In en, this message translates to:
  /// **'Destination'**
  String get destination;

  /// No description provided for @processing.
  ///
  /// In en, this message translates to:
  /// **'Processing'**
  String get processing;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @confirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get confirm;

  /// No description provided for @addABankAccountFirst.
  ///
  /// In en, this message translates to:
  /// **'Add a bank account first'**
  String get addABankAccountFirst;

  /// No description provided for @enterAValidAmount.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid amount'**
  String get enterAValidAmount;

  /// No description provided for @withdrawalSubmitted.
  ///
  /// In en, this message translates to:
  /// **'Withdrawal submitted'**
  String get withdrawalSubmitted;

  /// No description provided for @done.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get done;

  /// No description provided for @withdraw.
  ///
  /// In en, this message translates to:
  /// **'Withdraw'**
  String get withdraw;

  /// No description provided for @couldNotLoadBankAccounts.
  ///
  /// In en, this message translates to:
  /// **'Could not load bank accounts'**
  String get couldNotLoadBankAccounts;

  /// No description provided for @availableBalance.
  ///
  /// In en, this message translates to:
  /// **'Available balance'**
  String get availableBalance;

  /// No description provided for @payoutTo.
  ///
  /// In en, this message translates to:
  /// **'Payout to'**
  String get payoutTo;

  /// No description provided for @withdrawalAmount.
  ///
  /// In en, this message translates to:
  /// **'Withdrawal amount'**
  String get withdrawalAmount;

  /// No description provided for @enterAmount.
  ///
  /// In en, this message translates to:
  /// **'Enter amount'**
  String get enterAmount;

  /// No description provided for @noFundsAvailableToWithdraw.
  ///
  /// In en, this message translates to:
  /// **'No funds available to withdraw'**
  String get noFundsAvailableToWithdraw;

  /// No description provided for @earnings.
  ///
  /// In en, this message translates to:
  /// **'Earnings'**
  String get earnings;

  /// No description provided for @couldNotLoadEarnings.
  ///
  /// In en, this message translates to:
  /// **'Could not load earnings'**
  String get couldNotLoadEarnings;

  /// No description provided for @thisWeek.
  ///
  /// In en, this message translates to:
  /// **'This week'**
  String get thisWeek;

  /// No description provided for @jobs.
  ///
  /// In en, this message translates to:
  /// **'Jobs'**
  String get jobs;

  /// No description provided for @rating.
  ///
  /// In en, this message translates to:
  /// **'Rating'**
  String get rating;

  /// No description provided for @weeklyBreakdown.
  ///
  /// In en, this message translates to:
  /// **'Weekly breakdown'**
  String get weeklyBreakdown;

  /// No description provided for @recentEarnings.
  ///
  /// In en, this message translates to:
  /// **'Recent earnings'**
  String get recentEarnings;

  /// No description provided for @readyToWithdrawToYourBank.
  ///
  /// In en, this message translates to:
  /// **'Ready to withdraw to your bank'**
  String get readyToWithdrawToYourBank;

  /// No description provided for @noEarningsYet.
  ///
  /// In en, this message translates to:
  /// **'No earnings yet'**
  String get noEarningsYet;

  /// No description provided for @completedJobsWillShowUpHere.
  ///
  /// In en, this message translates to:
  /// **'Completed jobs will show up here'**
  String get completedJobsWillShowUpHere;

  /// No description provided for @transaction.
  ///
  /// In en, this message translates to:
  /// **'Transaction'**
  String get transaction;

  /// No description provided for @couldNotLoadTransaction.
  ///
  /// In en, this message translates to:
  /// **'Could not load transaction'**
  String get couldNotLoadTransaction;

  /// No description provided for @netPayout.
  ///
  /// In en, this message translates to:
  /// **'Net Payout'**
  String get netPayout;

  /// No description provided for @grossEarnings.
  ///
  /// In en, this message translates to:
  /// **'Gross Earnings'**
  String get grossEarnings;

  /// No description provided for @platformFee.
  ///
  /// In en, this message translates to:
  /// **'Platform Fee'**
  String get platformFee;

  /// No description provided for @jobDetails.
  ///
  /// In en, this message translates to:
  /// **'Job Details'**
  String get jobDetails;

  /// No description provided for @ticket.
  ///
  /// In en, this message translates to:
  /// **'Ticket'**
  String get ticket;

  /// No description provided for @writeAReply.
  ///
  /// In en, this message translates to:
  /// **'Write a reply...'**
  String get writeAReply;

  /// No description provided for @pleaseEnterSubjectAndMessage.
  ///
  /// In en, this message translates to:
  /// **'Please enter subject and message'**
  String get pleaseEnterSubjectAndMessage;

  /// No description provided for @newTicket.
  ///
  /// In en, this message translates to:
  /// **'New Ticket'**
  String get newTicket;

  /// No description provided for @subject.
  ///
  /// In en, this message translates to:
  /// **'Subject'**
  String get subject;

  /// No description provided for @briefSummary.
  ///
  /// In en, this message translates to:
  /// **'Brief summary'**
  String get briefSummary;

  /// No description provided for @message.
  ///
  /// In en, this message translates to:
  /// **'Message'**
  String get message;

  /// No description provided for @describeYourIssue.
  ///
  /// In en, this message translates to:
  /// **'Describe your issue'**
  String get describeYourIssue;

  /// No description provided for @myTickets.
  ///
  /// In en, this message translates to:
  /// **'My Tickets'**
  String get myTickets;

  /// No description provided for @noSupportTicketsYet.
  ///
  /// In en, this message translates to:
  /// **'No support tickets yet'**
  String get noSupportTicketsYet;

  /// No description provided for @createTicket.
  ///
  /// In en, this message translates to:
  /// **'Create Ticket'**
  String get createTicket;

  /// No description provided for @notifications.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get notifications;

  /// No description provided for @noNotificationsYet.
  ///
  /// In en, this message translates to:
  /// **'No notifications yet'**
  String get noNotificationsYet;

  /// No description provided for @myPerformance.
  ///
  /// In en, this message translates to:
  /// **'My Performance'**
  String get myPerformance;

  /// No description provided for @couldNotLoadPerformance.
  ///
  /// In en, this message translates to:
  /// **'Could not load performance'**
  String get couldNotLoadPerformance;

  /// No description provided for @acceptanceRate.
  ///
  /// In en, this message translates to:
  /// **'Acceptance Rate'**
  String get acceptanceRate;

  /// No description provided for @completionRate.
  ///
  /// In en, this message translates to:
  /// **'Completion Rate'**
  String get completionRate;

  /// No description provided for @totalJobs.
  ///
  /// In en, this message translates to:
  /// **'Total Jobs'**
  String get totalJobs;

  /// No description provided for @reviews.
  ///
  /// In en, this message translates to:
  /// **'Reviews'**
  String get reviews;

  /// No description provided for @averageRating.
  ///
  /// In en, this message translates to:
  /// **'Average Rating'**
  String get averageRating;

  /// No description provided for @customerReviews.
  ///
  /// In en, this message translates to:
  /// **'Customer Reviews'**
  String get customerReviews;

  /// No description provided for @noReviewsYet.
  ///
  /// In en, this message translates to:
  /// **'No reviews yet'**
  String get noReviewsYet;

  /// No description provided for @takePhoto.
  ///
  /// In en, this message translates to:
  /// **'Take Photo'**
  String get takePhoto;

  /// No description provided for @chooseFromGallery.
  ///
  /// In en, this message translates to:
  /// **'Choose from Gallery'**
  String get chooseFromGallery;

  /// No description provided for @profileUpdatedSuccessfully.
  ///
  /// In en, this message translates to:
  /// **'Profile updated successfully'**
  String get profileUpdatedSuccessfully;

  /// No description provided for @couldNotLoadProfile.
  ///
  /// In en, this message translates to:
  /// **'Could not load profile'**
  String get couldNotLoadProfile;

  /// No description provided for @checkYourConnectionAndTryAgain.
  ///
  /// In en, this message translates to:
  /// **'Check your connection and try again.'**
  String get checkYourConnectionAndTryAgain;

  /// No description provided for @personalInformation.
  ///
  /// In en, this message translates to:
  /// **'Personal Information'**
  String get personalInformation;

  /// No description provided for @updateYourProfileDetails.
  ///
  /// In en, this message translates to:
  /// **'Update your profile details'**
  String get updateYourProfileDetails;

  /// No description provided for @tapToChangePhoto.
  ///
  /// In en, this message translates to:
  /// **'Tap to change photo'**
  String get tapToChangePhoto;

  /// No description provided for @johnDoe.
  ///
  /// In en, this message translates to:
  /// **'John Doe'**
  String get johnDoe;

  /// No description provided for @fullName.
  ///
  /// In en, this message translates to:
  /// **'Full Name'**
  String get fullName;

  /// No description provided for @phoneNumber.
  ///
  /// In en, this message translates to:
  /// **'Phone Number'**
  String get phoneNumber;

  /// No description provided for @johnExampleCom.
  ///
  /// In en, this message translates to:
  /// **'john@example.com'**
  String get johnExampleCom;

  /// No description provided for @email.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get email;

  /// No description provided for @phoneAndEmailAreLinkedToYourAccountAndCannotBeCh.
  ///
  /// In en, this message translates to:
  /// **'Phone and email are linked to your account and cannot be changed here. Contact support if you need to update them.'**
  String get phoneAndEmailAreLinkedToYourAccountAndCannotBeCh;

  /// No description provided for @helpSupport.
  ///
  /// In en, this message translates to:
  /// **'Help & Support'**
  String get helpSupport;

  /// No description provided for @mySupportTickets.
  ///
  /// In en, this message translates to:
  /// **'My Support Tickets'**
  String get mySupportTickets;

  /// No description provided for @viewTicketsAndChatWithOurTeam.
  ///
  /// In en, this message translates to:
  /// **'View tickets and chat with our team'**
  String get viewTicketsAndChatWithOurTeam;

  /// No description provided for @contactSupport.
  ///
  /// In en, this message translates to:
  /// **'Contact Support'**
  String get contactSupport;

  /// No description provided for @openANewTicketForHelp.
  ///
  /// In en, this message translates to:
  /// **'Open a new ticket for help'**
  String get openANewTicketForHelp;

  /// No description provided for @faq.
  ///
  /// In en, this message translates to:
  /// **'FAQ'**
  String get faq;

  /// No description provided for @couldNotLoadFAQs.
  ///
  /// In en, this message translates to:
  /// **'Could not load FAQs'**
  String get couldNotLoadFAQs;

  /// No description provided for @quickContact.
  ///
  /// In en, this message translates to:
  /// **'Quick contact'**
  String get quickContact;

  /// No description provided for @technicalSupport.
  ///
  /// In en, this message translates to:
  /// **'Technical Support'**
  String get technicalSupport;

  /// No description provided for @appIssuesBugsCrashes.
  ///
  /// In en, this message translates to:
  /// **'App issues, bugs, crashes'**
  String get appIssuesBugsCrashes;

  /// No description provided for @paymentSupport.
  ///
  /// In en, this message translates to:
  /// **'Payment Support'**
  String get paymentSupport;

  /// No description provided for @earningsWithdrawalsFees.
  ///
  /// In en, this message translates to:
  /// **'Earnings, withdrawals, fees'**
  String get earningsWithdrawalsFees;

  /// No description provided for @couldNotLoadMakes.
  ///
  /// In en, this message translates to:
  /// **'Could not load makes'**
  String get couldNotLoadMakes;

  /// No description provided for @couldNotLoadModels.
  ///
  /// In en, this message translates to:
  /// **'Could not load models'**
  String get couldNotLoadModels;

  /// No description provided for @vehicleUpdated.
  ///
  /// In en, this message translates to:
  /// **'Vehicle updated'**
  String get vehicleUpdated;

  /// No description provided for @couldNotSaveVehicle.
  ///
  /// In en, this message translates to:
  /// **'Could not save vehicle'**
  String get couldNotSaveVehicle;

  /// No description provided for @vehicleInfo.
  ///
  /// In en, this message translates to:
  /// **'Vehicle Info'**
  String get vehicleInfo;

  /// No description provided for @addYourVehicle.
  ///
  /// In en, this message translates to:
  /// **'Add Your Vehicle'**
  String get addYourVehicle;

  /// No description provided for @editVehicle.
  ///
  /// In en, this message translates to:
  /// **'Edit Vehicle'**
  String get editVehicle;

  /// No description provided for @addVehiclePhoto.
  ///
  /// In en, this message translates to:
  /// **'Add vehicle photo'**
  String get addVehiclePhoto;

  /// No description provided for @optional.
  ///
  /// In en, this message translates to:
  /// **'Optional'**
  String get optional;

  /// No description provided for @licensePlate.
  ///
  /// In en, this message translates to:
  /// **'License Plate'**
  String get licensePlate;

  /// No description provided for @enterPlate.
  ///
  /// In en, this message translates to:
  /// **'Enter plate'**
  String get enterPlate;

  /// No description provided for @enter4DigitYear.
  ///
  /// In en, this message translates to:
  /// **'Enter 4-digit year'**
  String get enter4DigitYear;

  /// No description provided for @saveVehicle.
  ///
  /// In en, this message translates to:
  /// **'Save Vehicle'**
  String get saveVehicle;

  /// No description provided for @updateVehicle.
  ///
  /// In en, this message translates to:
  /// **'Update Vehicle'**
  String get updateVehicle;

  /// No description provided for @uploadingPhoto.
  ///
  /// In en, this message translates to:
  /// **'Uploading photo...'**
  String get uploadingPhoto;

  /// No description provided for @couldNotLoadVehicle.
  ///
  /// In en, this message translates to:
  /// **'Could not load vehicle'**
  String get couldNotLoadVehicle;

  /// No description provided for @vehicleType.
  ///
  /// In en, this message translates to:
  /// **'Vehicle Type'**
  String get vehicleType;

  /// No description provided for @selectType.
  ///
  /// In en, this message translates to:
  /// **'Select type'**
  String get selectType;

  /// No description provided for @car.
  ///
  /// In en, this message translates to:
  /// **'Car'**
  String get car;

  /// No description provided for @motorcycle.
  ///
  /// In en, this message translates to:
  /// **'Motorcycle'**
  String get motorcycle;

  /// No description provided for @make.
  ///
  /// In en, this message translates to:
  /// **'Make'**
  String get make;

  /// No description provided for @enterMake.
  ///
  /// In en, this message translates to:
  /// **'Enter make'**
  String get enterMake;

  /// No description provided for @makeName.
  ///
  /// In en, this message translates to:
  /// **'Make name'**
  String get makeName;

  /// No description provided for @model.
  ///
  /// In en, this message translates to:
  /// **'Model'**
  String get model;

  /// No description provided for @enterModel.
  ///
  /// In en, this message translates to:
  /// **'Enter model'**
  String get enterModel;

  /// No description provided for @modelName.
  ///
  /// In en, this message translates to:
  /// **'Model name'**
  String get modelName;

  /// No description provided for @year.
  ///
  /// In en, this message translates to:
  /// **'Year'**
  String get year;

  /// No description provided for @abc1234.
  ///
  /// In en, this message translates to:
  /// **'ABC-1234'**
  String get abc1234;

  /// No description provided for @plateNumber.
  ///
  /// In en, this message translates to:
  /// **'Plate Number'**
  String get plateNumber;

  /// No description provided for @transmission.
  ///
  /// In en, this message translates to:
  /// **'Transmission'**
  String get transmission;

  /// No description provided for @select.
  ///
  /// In en, this message translates to:
  /// **'Select'**
  String get select;

  /// No description provided for @manual.
  ///
  /// In en, this message translates to:
  /// **'Manual'**
  String get manual;

  /// No description provided for @auto.
  ///
  /// In en, this message translates to:
  /// **'Auto'**
  String get auto;

  /// No description provided for @fuelType.
  ///
  /// In en, this message translates to:
  /// **'Fuel Type'**
  String get fuelType;

  /// No description provided for @petrol.
  ///
  /// In en, this message translates to:
  /// **'Petrol'**
  String get petrol;

  /// No description provided for @diesel.
  ///
  /// In en, this message translates to:
  /// **'Diesel'**
  String get diesel;

  /// No description provided for @electric.
  ///
  /// In en, this message translates to:
  /// **'Electric'**
  String get electric;

  /// No description provided for @vehicleColour.
  ///
  /// In en, this message translates to:
  /// **'Colour'**
  String get vehicleColour;

  /// No description provided for @engine.
  ///
  /// In en, this message translates to:
  /// **'Engine'**
  String get engine;

  /// No description provided for @primaryAccountUpdated.
  ///
  /// In en, this message translates to:
  /// **'Primary account updated'**
  String get primaryAccountUpdated;

  /// No description provided for @couldNotUpdateAccount.
  ///
  /// In en, this message translates to:
  /// **'Could not update account'**
  String get couldNotUpdateAccount;

  /// No description provided for @removeBankAccount.
  ///
  /// In en, this message translates to:
  /// **'Remove bank account?'**
  String get removeBankAccount;

  /// No description provided for @thisAccountWillBeRemovedFromYourPayoutMethods.
  ///
  /// In en, this message translates to:
  /// **'This account will be removed from your payout methods.'**
  String get thisAccountWillBeRemovedFromYourPayoutMethods;

  /// No description provided for @remove.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get remove;

  /// No description provided for @bankAccountRemoved.
  ///
  /// In en, this message translates to:
  /// **'Bank account removed'**
  String get bankAccountRemoved;

  /// No description provided for @couldNotRemoveAccount.
  ///
  /// In en, this message translates to:
  /// **'Could not remove account'**
  String get couldNotRemoveAccount;

  /// No description provided for @paymentMethods2.
  ///
  /// In en, this message translates to:
  /// **'Payment Methods'**
  String get paymentMethods2;

  /// No description provided for @addAccount.
  ///
  /// In en, this message translates to:
  /// **'Add Account'**
  String get addAccount;

  /// No description provided for @couldNotLoadAccounts.
  ///
  /// In en, this message translates to:
  /// **'Could not load accounts'**
  String get couldNotLoadAccounts;

  /// No description provided for @noPayoutMethodAddedYet.
  ///
  /// In en, this message translates to:
  /// **'No payout method added yet'**
  String get noPayoutMethodAddedYet;

  /// No description provided for @addABankAccountToReceiveYourEarningsWhenYouWithd.
  ///
  /// In en, this message translates to:
  /// **'Add a bank account to receive your earnings when you withdraw.'**
  String get addABankAccountToReceiveYourEarningsWhenYouWithd;

  /// No description provided for @primary.
  ///
  /// In en, this message translates to:
  /// **'Primary'**
  String get primary;

  /// No description provided for @setAsPrimary.
  ///
  /// In en, this message translates to:
  /// **'Set as primary'**
  String get setAsPrimary;

  /// No description provided for @languageRegion.
  ///
  /// In en, this message translates to:
  /// **'Language & Region'**
  String get languageRegion;

  /// No description provided for @english.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get english;

  /// No description provided for @account.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get account;

  /// No description provided for @documentsVerification.
  ///
  /// In en, this message translates to:
  /// **'Documents & Verification'**
  String get documentsVerification;

  /// No description provided for @personalInfo.
  ///
  /// In en, this message translates to:
  /// **'Personal Info'**
  String get personalInfo;

  /// No description provided for @preferences.
  ///
  /// In en, this message translates to:
  /// **'Preferences'**
  String get preferences;

  /// No description provided for @support.
  ///
  /// In en, this message translates to:
  /// **'Support'**
  String get support;

  /// No description provided for @resumeActiveJob.
  ///
  /// In en, this message translates to:
  /// **'Resume active job'**
  String get resumeActiveJob;

  /// No description provided for @chatWithCustomer.
  ///
  /// In en, this message translates to:
  /// **'Chat with customer'**
  String get chatWithCustomer;

  /// No description provided for @logout.
  ///
  /// In en, this message translates to:
  /// **'Logout'**
  String get logout;

  /// No description provided for @jobHistory.
  ///
  /// In en, this message translates to:
  /// **'Job History'**
  String get jobHistory;

  /// No description provided for @couldNotLoadHistory.
  ///
  /// In en, this message translates to:
  /// **'Could not load history'**
  String get couldNotLoadHistory;

  /// No description provided for @noCompletedJobsYet.
  ///
  /// In en, this message translates to:
  /// **'No completed jobs yet'**
  String get noCompletedJobsYet;

  /// No description provided for @jobCompleted.
  ///
  /// In en, this message translates to:
  /// **'Job Completed!'**
  String get jobCompleted;

  /// No description provided for @weCouldNotLoadJobDetailsYourEarningsAreInYourWal.
  ///
  /// In en, this message translates to:
  /// **'We could not load job details. Your earnings are in your wallet.'**
  String get weCouldNotLoadJobDetailsYourEarningsAreInYourWal;

  /// No description provided for @backToHome.
  ///
  /// In en, this message translates to:
  /// **'Back to Home'**
  String get backToHome;

  /// No description provided for @youEarned.
  ///
  /// In en, this message translates to:
  /// **'You earned'**
  String get youEarned;

  /// No description provided for @distance.
  ///
  /// In en, this message translates to:
  /// **'Distance'**
  String get distance;

  /// No description provided for @duration.
  ///
  /// In en, this message translates to:
  /// **'Duration'**
  String get duration;

  /// No description provided for @service.
  ///
  /// In en, this message translates to:
  /// **'Service'**
  String get service;

  /// No description provided for @customer.
  ///
  /// In en, this message translates to:
  /// **'Customer'**
  String get customer;

  /// No description provided for @vehicle.
  ///
  /// In en, this message translates to:
  /// **'Vehicle'**
  String get vehicle;

  /// No description provided for @vehicleNotProvided.
  ///
  /// In en, this message translates to:
  /// **'Vehicle details not provided'**
  String get vehicleNotProvided;

  /// No description provided for @automatic.
  ///
  /// In en, this message translates to:
  /// **'Automatic'**
  String get automatic;

  /// No description provided for @location.
  ///
  /// In en, this message translates to:
  /// **'Location'**
  String get location;

  /// No description provided for @writeAReviewOptional.
  ///
  /// In en, this message translates to:
  /// **'Write a review (optional)'**
  String get writeAReviewOptional;

  /// No description provided for @arrived.
  ///
  /// In en, this message translates to:
  /// **'Arrived'**
  String get arrived;

  /// No description provided for @youVeArrived.
  ///
  /// In en, this message translates to:
  /// **'You\'ve arrived!'**
  String get youVeArrived;

  /// No description provided for @confirmYouReAtTheCustomerSLocation.
  ///
  /// In en, this message translates to:
  /// **'Confirm you\'re at the customer\'s location'**
  String get confirmYouReAtTheCustomerSLocation;

  /// No description provided for @callCustomer.
  ///
  /// In en, this message translates to:
  /// **'Call customer'**
  String get callCustomer;

  /// No description provided for @waitingForTheCustomerToConfirmJobStarted.
  ///
  /// In en, this message translates to:
  /// **'Waiting for the customer to confirm Job Started'**
  String get waitingForTheCustomerToConfirmJobStarted;

  /// No description provided for @enableLocationToNavigate.
  ///
  /// In en, this message translates to:
  /// **'Enable location to navigate'**
  String get enableLocationToNavigate;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @iVeArrived.
  ///
  /// In en, this message translates to:
  /// **'I\'ve Arrived'**
  String get iVeArrived;

  /// No description provided for @minimize.
  ///
  /// In en, this message translates to:
  /// **'Minimize'**
  String get minimize;

  /// No description provided for @serviceINPROGRESS.
  ///
  /// In en, this message translates to:
  /// **'SERVICE IN PROGRESS'**
  String get serviceINPROGRESS;

  /// No description provided for @jobReference.
  ///
  /// In en, this message translates to:
  /// **'Job Reference'**
  String get jobReference;

  /// No description provided for @completeService.
  ///
  /// In en, this message translates to:
  /// **'Complete Service'**
  String get completeService;

  /// No description provided for @addressCopied.
  ///
  /// In en, this message translates to:
  /// **'Address copied'**
  String get addressCopied;

  /// No description provided for @couldNotOpenGoogleMaps.
  ///
  /// In en, this message translates to:
  /// **'Could not open Google Maps'**
  String get couldNotOpenGoogleMaps;

  /// No description provided for @copyAddress.
  ///
  /// In en, this message translates to:
  /// **'Copy address'**
  String get copyAddress;

  /// No description provided for @openInGoogleMaps.
  ///
  /// In en, this message translates to:
  /// **'Open in Google Maps'**
  String get openInGoogleMaps;

  /// No description provided for @pleaseSelectYourCountry.
  ///
  /// In en, this message translates to:
  /// **'Please select your country'**
  String get pleaseSelectYourCountry;

  /// No description provided for @becomeAProvider.
  ///
  /// In en, this message translates to:
  /// **'Become a Driver'**
  String get becomeAProvider;

  /// No description provided for @joinRyvoAndStartEarningToday.
  ///
  /// In en, this message translates to:
  /// **'Join Ryvo and start earning today'**
  String get joinRyvoAndStartEarningToday;

  /// No description provided for @profilePhotoOptionalSelfieSetDuringVerification.
  ///
  /// In en, this message translates to:
  /// **'Profile Photo (optional — selfie set during verification)'**
  String get profilePhotoOptionalSelfieSetDuringVerification;

  /// No description provided for @min8Characters.
  ///
  /// In en, this message translates to:
  /// **'Min. 8 characters'**
  String get min8Characters;

  /// No description provided for @password.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get password;

  /// No description provided for @alreadyHaveAnAccount.
  ///
  /// In en, this message translates to:
  /// **'Already have an account? '**
  String get alreadyHaveAnAccount;

  /// No description provided for @signIn.
  ///
  /// In en, this message translates to:
  /// **'Sign in'**
  String get signIn;

  /// No description provided for @resetPassword.
  ///
  /// In en, this message translates to:
  /// **'Reset Password'**
  String get resetPassword;

  /// No description provided for @enterYourPhoneNumberAndWeLlSendAVerificationCode.
  ///
  /// In en, this message translates to:
  /// **'Enter your phone number and we\'ll send a verification code to reset your password.'**
  String get enterYourPhoneNumberAndWeLlSendAVerificationCode;

  /// No description provided for @welcomeBack.
  ///
  /// In en, this message translates to:
  /// **'Welcome back'**
  String get welcomeBack;

  /// No description provided for @signInToYourProviderAccount.
  ///
  /// In en, this message translates to:
  /// **'Sign in to your driver account'**
  String get signInToYourProviderAccount;

  /// No description provided for @enterPassword.
  ///
  /// In en, this message translates to:
  /// **'Enter password'**
  String get enterPassword;

  /// No description provided for @forgotPassword.
  ///
  /// In en, this message translates to:
  /// **'Forgot password?'**
  String get forgotPassword;

  /// No description provided for @donTHaveAnAccount.
  ///
  /// In en, this message translates to:
  /// **'Don\'t have an account? '**
  String get donTHaveAnAccount;

  /// No description provided for @signUp.
  ///
  /// In en, this message translates to:
  /// **'Sign up'**
  String get signUp;

  /// No description provided for @passwordResetPleaseSignIn.
  ///
  /// In en, this message translates to:
  /// **'Password reset. Please sign in.'**
  String get passwordResetPleaseSignIn;

  /// No description provided for @newPassword.
  ///
  /// In en, this message translates to:
  /// **'New Password'**
  String get newPassword;

  /// No description provided for @reset.
  ///
  /// In en, this message translates to:
  /// **'Reset'**
  String get reset;

  /// No description provided for @verifyPhone.
  ///
  /// In en, this message translates to:
  /// **'Verify Phone'**
  String get verifyPhone;

  /// No description provided for @enterThe6DigitCodeSentToYourNumber.
  ///
  /// In en, this message translates to:
  /// **'Enter the 6-digit code sent to your number'**
  String get enterThe6DigitCodeSentToYourNumber;

  /// No description provided for @resendCode.
  ///
  /// In en, this message translates to:
  /// **'Resend Code'**
  String get resendCode;

  /// No description provided for @verify.
  ///
  /// In en, this message translates to:
  /// **'Verify'**
  String get verify;

  /// No description provided for @noMessagesYetSayHiToYourCustomer.
  ///
  /// In en, this message translates to:
  /// **'No messages yet.\nSay hi to your customer.'**
  String get noMessagesYetSayHiToYourCustomer;

  /// No description provided for @typeAMessage.
  ///
  /// In en, this message translates to:
  /// **'Type a message...'**
  String get typeAMessage;

  /// No description provided for @oneOrMoreDocumentsWereRejectedTapReUploadOnEachR.
  ///
  /// In en, this message translates to:
  /// **'One or more documents were rejected. Tap Re-upload on each rejected document to submit again.'**
  String get oneOrMoreDocumentsWereRejectedTapReUploadOnEachR;

  /// No description provided for @verificationMayTakeUpTo48HoursYouLlBeNotifiedOnc.
  ///
  /// In en, this message translates to:
  /// **'Verification may take up to 48 hours. You\'ll be notified once approved.'**
  String get verificationMayTakeUpTo48HoursYouLlBeNotifiedOnc;

  /// No description provided for @addPhoto.
  ///
  /// In en, this message translates to:
  /// **'Add photo'**
  String get addPhoto;

  /// No description provided for @bothSidesAreRequiredBeforeYouCanSubmit.
  ///
  /// In en, this message translates to:
  /// **'Both sides are required before you can submit.'**
  String get bothSidesAreRequiredBeforeYouCanSubmit;

  /// No description provided for @takeAClearSelfieThisPhotoIsUsedForIdentityChecks.
  ///
  /// In en, this message translates to:
  /// **'Take a clear selfie. This photo is used for identity checks and your driver display picture.'**
  String get takeAClearSelfieThisPhotoIsUsedForIdentityChecks;

  /// No description provided for @addAtLeastOneClearPhotoOfYourServiceEquipment.
  ///
  /// In en, this message translates to:
  /// **'Add at least one clear photo of your service equipment.'**
  String get addAtLeastOneClearPhotoOfYourServiceEquipment;

  /// No description provided for @front.
  ///
  /// In en, this message translates to:
  /// **'Front'**
  String get front;

  /// No description provided for @back.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get back;

  /// No description provided for @previewReadyTapUploadToSubmit.
  ///
  /// In en, this message translates to:
  /// **'Preview ready — tap Upload to submit'**
  String get previewReadyTapUploadToSubmit;

  /// No description provided for @takeSelfie.
  ///
  /// In en, this message translates to:
  /// **'Take Selfie'**
  String get takeSelfie;

  /// No description provided for @chooseFromGalleryInstead.
  ///
  /// In en, this message translates to:
  /// **'Choose from gallery instead'**
  String get chooseFromGalleryInstead;

  /// No description provided for @camera.
  ///
  /// In en, this message translates to:
  /// **'Camera'**
  String get camera;

  /// No description provided for @gallery.
  ///
  /// In en, this message translates to:
  /// **'Gallery'**
  String get gallery;

  /// No description provided for @providerAgreement.
  ///
  /// In en, this message translates to:
  /// **'Driver Agreement'**
  String get providerAgreement;

  /// No description provided for @youCanStillReviewAndAcceptTheAgreementBelowForLo.
  ///
  /// In en, this message translates to:
  /// **'You can still review and accept the agreement below. For local API use:\n--dart-define=API_BASE_URL=http://YOUR_IP:4000/api/v1'**
  String get youCanStillReviewAndAcceptTheAgreementBelowForLo;

  /// No description provided for @documentStatus.
  ///
  /// In en, this message translates to:
  /// **'Document Status'**
  String get documentStatus;

  /// No description provided for @verificationProgress.
  ///
  /// In en, this message translates to:
  /// **'Verification Progress'**
  String get verificationProgress;

  /// No description provided for @home.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get home;

  /// No description provided for @history.
  ///
  /// In en, this message translates to:
  /// **'History'**
  String get history;

  /// No description provided for @profile.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get profile;

  /// No description provided for @completeOnboardingApprovalBeforeGoingOnline.
  ///
  /// In en, this message translates to:
  /// **'Complete onboarding approval before going online.'**
  String get completeOnboardingApprovalBeforeGoingOnline;

  /// No description provided for @paymentSecured.
  ///
  /// In en, this message translates to:
  /// **'Payment secured'**
  String get paymentSecured;

  /// No description provided for @requestExpiresIn.
  ///
  /// In en, this message translates to:
  /// **'Request expires in...'**
  String get requestExpiresIn;

  /// No description provided for @highPRIORITY.
  ///
  /// In en, this message translates to:
  /// **'HIGH PRIORITY'**
  String get highPRIORITY;

  /// No description provided for @veryUrgent.
  ///
  /// In en, this message translates to:
  /// **'Very Urgent'**
  String get veryUrgent;

  /// No description provided for @serviceREQUIRED.
  ///
  /// In en, this message translates to:
  /// **'SERVICE REQUIRED'**
  String get serviceREQUIRED;

  /// No description provided for @earn.
  ///
  /// In en, this message translates to:
  /// **'EARN'**
  String get earn;

  /// No description provided for @acceptJob.
  ///
  /// In en, this message translates to:
  /// **'Accept Job'**
  String get acceptJob;

  /// No description provided for @decline.
  ///
  /// In en, this message translates to:
  /// **'Decline'**
  String get decline;

  /// No description provided for @resume.
  ///
  /// In en, this message translates to:
  /// **'Resume'**
  String get resume;

  /// No description provided for @youReOffline.
  ///
  /// In en, this message translates to:
  /// **'You\'re Offline'**
  String get youReOffline;

  /// No description provided for @goOnlineToStartReceivingJobRequestsFromNearbyCus.
  ///
  /// In en, this message translates to:
  /// **'Go online to start receiving job requests from nearby customers.'**
  String get goOnlineToStartReceivingJobRequestsFromNearbyCus;

  /// No description provided for @goOnline.
  ///
  /// In en, this message translates to:
  /// **'Go Online'**
  String get goOnline;

  /// No description provided for @showFullRoute.
  ///
  /// In en, this message translates to:
  /// **'Show full route'**
  String get showFullRoute;

  /// No description provided for @zoomIn.
  ///
  /// In en, this message translates to:
  /// **'Zoom in'**
  String get zoomIn;

  /// No description provided for @zoomOut.
  ///
  /// In en, this message translates to:
  /// **'Zoom out'**
  String get zoomOut;

  /// No description provided for @goToCurrentLocation.
  ///
  /// In en, this message translates to:
  /// **'Go to current location'**
  String get goToCurrentLocation;

  /// No description provided for @contactNumberNotAvailableYet.
  ///
  /// In en, this message translates to:
  /// **'Contact number not available yet'**
  String get contactNumberNotAvailableYet;

  /// No description provided for @couldNotStartACall.
  ///
  /// In en, this message translates to:
  /// **'Could not start a call'**
  String get couldNotStartACall;

  /// No description provided for @somethingWentWrong.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong'**
  String get somethingWentWrong;

  /// No description provided for @tryAgain.
  ///
  /// In en, this message translates to:
  /// **'Try Again'**
  String get tryAgain;

  /// No description provided for @noInternetConnection.
  ///
  /// In en, this message translates to:
  /// **'No internet connection'**
  String get noInternetConnection;

  /// No description provided for @loading.
  ///
  /// In en, this message translates to:
  /// **'Loading...'**
  String get loading;

  /// No description provided for @uploadDocument.
  ///
  /// In en, this message translates to:
  /// **'Upload Document'**
  String get uploadDocument;

  /// No description provided for @replaceDocument.
  ///
  /// In en, this message translates to:
  /// **'Replace Document'**
  String get replaceDocument;

  /// No description provided for @online.
  ///
  /// In en, this message translates to:
  /// **'Online'**
  String get online;

  /// No description provided for @offline.
  ///
  /// In en, this message translates to:
  /// **'Offline'**
  String get offline;

  /// No description provided for @getStarted.
  ///
  /// In en, this message translates to:
  /// **'Get Started'**
  String get getStarted;

  /// No description provided for @next.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get next;

  /// No description provided for @home2.
  ///
  /// In en, this message translates to:
  /// **'/home'**
  String get home2;

  /// No description provided for @setUpBankAccount.
  ///
  /// In en, this message translates to:
  /// **'Set up bank account'**
  String get setUpBankAccount;

  /// No description provided for @withdrawFunds.
  ///
  /// In en, this message translates to:
  /// **'Withdraw Funds'**
  String get withdrawFunds;

  /// No description provided for @noFundsAvailable.
  ///
  /// In en, this message translates to:
  /// **'No funds available'**
  String get noFundsAvailable;

  /// No description provided for @pending.
  ///
  /// In en, this message translates to:
  /// **'pending'**
  String get pending;

  /// No description provided for @bankTransfer.
  ///
  /// In en, this message translates to:
  /// **'Bank transfer'**
  String get bankTransfer;

  /// No description provided for @saving.
  ///
  /// In en, this message translates to:
  /// **'Saving...'**
  String get saving;

  /// No description provided for @saveBankAccount.
  ///
  /// In en, this message translates to:
  /// **'Save Bank Account'**
  String get saveBankAccount;

  /// No description provided for @bank.
  ///
  /// In en, this message translates to:
  /// **'Bank'**
  String get bank;

  /// No description provided for @withdrawalFailed.
  ///
  /// In en, this message translates to:
  /// **'Withdrawal failed'**
  String get withdrawalFailed;

  /// No description provided for @addBankAccount2.
  ///
  /// In en, this message translates to:
  /// **'Add bank account'**
  String get addBankAccount2;

  /// No description provided for @requiredToReceivePayouts.
  ///
  /// In en, this message translates to:
  /// **'Required to receive payouts'**
  String get requiredToReceivePayouts;

  /// No description provided for @submitting.
  ///
  /// In en, this message translates to:
  /// **'Submitting...'**
  String get submitting;

  /// No description provided for @reviewWithdraw.
  ///
  /// In en, this message translates to:
  /// **'Review & Withdraw'**
  String get reviewWithdraw;

  /// No description provided for @roadsideService.
  ///
  /// In en, this message translates to:
  /// **'Roadside service'**
  String get roadsideService;

  /// No description provided for @am.
  ///
  /// In en, this message translates to:
  /// **'AM'**
  String get am;

  /// No description provided for @pm.
  ///
  /// In en, this message translates to:
  /// **'PM'**
  String get pm;

  /// No description provided for @jobPayout.
  ///
  /// In en, this message translates to:
  /// **'Job payout'**
  String get jobPayout;

  /// No description provided for @general.
  ///
  /// In en, this message translates to:
  /// **'general'**
  String get general;

  /// No description provided for @open.
  ///
  /// In en, this message translates to:
  /// **'open'**
  String get open;

  /// No description provided for @medium.
  ///
  /// In en, this message translates to:
  /// **'medium'**
  String get medium;

  /// No description provided for @user.
  ///
  /// In en, this message translates to:
  /// **'user'**
  String get user;

  /// No description provided for @supportTeam.
  ///
  /// In en, this message translates to:
  /// **'Support Team'**
  String get supportTeam;

  /// No description provided for @you.
  ///
  /// In en, this message translates to:
  /// **'You'**
  String get you;

  /// No description provided for @submitTicket.
  ///
  /// In en, this message translates to:
  /// **'Submit Ticket'**
  String get submitTicket;

  /// No description provided for @enterYourFullName.
  ///
  /// In en, this message translates to:
  /// **'Enter your full name'**
  String get enterYourFullName;

  /// No description provided for @saveChanges.
  ///
  /// In en, this message translates to:
  /// **'Save Changes'**
  String get saveChanges;

  /// No description provided for @motorcycle2.
  ///
  /// In en, this message translates to:
  /// **'motorcycle'**
  String get motorcycle2;

  /// No description provided for @car2.
  ///
  /// In en, this message translates to:
  /// **'car'**
  String get car2;

  /// No description provided for @selectVehicleType.
  ///
  /// In en, this message translates to:
  /// **'Select vehicle type'**
  String get selectVehicleType;

  /// No description provided for @selectTypeFirst.
  ///
  /// In en, this message translates to:
  /// **'Select type first'**
  String get selectTypeFirst;

  /// No description provided for @searchMake.
  ///
  /// In en, this message translates to:
  /// **'Search make'**
  String get searchMake;

  /// No description provided for @selectAMake.
  ///
  /// In en, this message translates to:
  /// **'Select a make'**
  String get selectAMake;

  /// No description provided for @enterAMake.
  ///
  /// In en, this message translates to:
  /// **'Enter a make'**
  String get enterAMake;

  /// No description provided for @selectMakeFirst.
  ///
  /// In en, this message translates to:
  /// **'Select make first'**
  String get selectMakeFirst;

  /// No description provided for @searchModel.
  ///
  /// In en, this message translates to:
  /// **'Search model'**
  String get searchModel;

  /// No description provided for @selectAModel.
  ///
  /// In en, this message translates to:
  /// **'Select a model'**
  String get selectAModel;

  /// No description provided for @enterAModel.
  ///
  /// In en, this message translates to:
  /// **'Enter a model'**
  String get enterAModel;

  /// No description provided for @selectTransmission.
  ///
  /// In en, this message translates to:
  /// **'Select transmission'**
  String get selectTransmission;

  /// No description provided for @selectFuelType.
  ///
  /// In en, this message translates to:
  /// **'Select fuel type'**
  String get selectFuelType;

  /// No description provided for @provider.
  ///
  /// In en, this message translates to:
  /// **'Driver'**
  String get provider;

  /// No description provided for @greatWorkEarningsAddedToYourWallet.
  ///
  /// In en, this message translates to:
  /// **'Great work — earnings added to your wallet'**
  String get greatWorkEarningsAddedToYourWallet;

  /// No description provided for @confirming.
  ///
  /// In en, this message translates to:
  /// **'Confirming…'**
  String get confirming;

  /// No description provided for @waitingForCustomer.
  ///
  /// In en, this message translates to:
  /// **'Waiting for customer…'**
  String get waitingForCustomer;

  /// No description provided for @confirmJobStarted.
  ///
  /// In en, this message translates to:
  /// **'Confirm Job Started'**
  String get confirmJobStarted;

  /// No description provided for @timerStartsAfterBothPartiesConfirmJobStarted.
  ///
  /// In en, this message translates to:
  /// **'Timer starts after both parties confirm Job Started'**
  String get timerStartsAfterBothPartiesConfirmJobStarted;

  /// No description provided for @elapsedTime.
  ///
  /// In en, this message translates to:
  /// **'Elapsed time'**
  String get elapsedTime;

  /// No description provided for @online2.
  ///
  /// In en, this message translates to:
  /// **'online'**
  String get online2;

  /// No description provided for @offline2.
  ///
  /// In en, this message translates to:
  /// **'offline'**
  String get offline2;

  /// No description provided for @enterAValidPhoneNumber.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid phone number'**
  String get enterAValidPhoneNumber;

  /// No description provided for @passwordMustBeAtLeast8Characters.
  ///
  /// In en, this message translates to:
  /// **'Password must be at least 8 characters'**
  String get passwordMustBeAtLeast8Characters;

  /// No description provided for @creatingAccount.
  ///
  /// In en, this message translates to:
  /// **'Creating account...'**
  String get creatingAccount;

  /// No description provided for @createAccount.
  ///
  /// In en, this message translates to:
  /// **'Create Account'**
  String get createAccount;

  /// No description provided for @enterYourPhoneNumber.
  ///
  /// In en, this message translates to:
  /// **'Enter your phone number'**
  String get enterYourPhoneNumber;

  /// No description provided for @sending.
  ///
  /// In en, this message translates to:
  /// **'Sending...'**
  String get sending;

  /// No description provided for @sendResetCode.
  ///
  /// In en, this message translates to:
  /// **'Send Reset Code'**
  String get sendResetCode;

  /// No description provided for @enterYourPassword.
  ///
  /// In en, this message translates to:
  /// **'Enter your password'**
  String get enterYourPassword;

  /// No description provided for @signingIn.
  ///
  /// In en, this message translates to:
  /// **'Signing in...'**
  String get signingIn;

  /// No description provided for @signIn2.
  ///
  /// In en, this message translates to:
  /// **'Sign In'**
  String get signIn2;

  /// No description provided for @authenticationFailed.
  ///
  /// In en, this message translates to:
  /// **'Authentication failed'**
  String get authenticationFailed;

  /// No description provided for @liveChat.
  ///
  /// In en, this message translates to:
  /// **'Live chat'**
  String get liveChat;

  /// No description provided for @viewVerificationStatus.
  ///
  /// In en, this message translates to:
  /// **'View Verification Status'**
  String get viewVerificationStatus;

  /// No description provided for @textContinue.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get textContinue;

  /// No description provided for @uploadAllRequiredDocumentsToContinue.
  ///
  /// In en, this message translates to:
  /// **'Upload all required documents to continue'**
  String get uploadAllRequiredDocumentsToContinue;

  /// No description provided for @uploadFailedPleaseTryAgain.
  ///
  /// In en, this message translates to:
  /// **'Upload failed. Please try again.'**
  String get uploadFailedPleaseTryAgain;

  /// No description provided for @previouslyUploaded.
  ///
  /// In en, this message translates to:
  /// **'Previously uploaded'**
  String get previouslyUploaded;

  /// No description provided for @documentReady.
  ///
  /// In en, this message translates to:
  /// **'Document ready'**
  String get documentReady;

  /// No description provided for @uploadAClearPhoto.
  ///
  /// In en, this message translates to:
  /// **'Upload a clear photo'**
  String get uploadAClearPhoto;

  /// No description provided for @uploading.
  ///
  /// In en, this message translates to:
  /// **'Uploading...'**
  String get uploading;

  /// No description provided for @reUploadBothSides.
  ///
  /// In en, this message translates to:
  /// **'Re-upload Both Sides'**
  String get reUploadBothSides;

  /// No description provided for @reUploadPhotos.
  ///
  /// In en, this message translates to:
  /// **'Re-upload Photos'**
  String get reUploadPhotos;

  /// No description provided for @reUploadDocument.
  ///
  /// In en, this message translates to:
  /// **'Re-upload Document'**
  String get reUploadDocument;

  /// No description provided for @uploadBothSides.
  ///
  /// In en, this message translates to:
  /// **'Upload Both Sides'**
  String get uploadBothSides;

  /// No description provided for @uploadPhotos.
  ///
  /// In en, this message translates to:
  /// **'Upload Photos'**
  String get uploadPhotos;

  /// No description provided for @uploadSelfie.
  ///
  /// In en, this message translates to:
  /// **'Upload Selfie'**
  String get uploadSelfie;

  /// No description provided for @acceptContinue.
  ///
  /// In en, this message translates to:
  /// **'Accept & Continue'**
  String get acceptContinue;

  /// No description provided for @documentsNeedAttention.
  ///
  /// In en, this message translates to:
  /// **'Documents Need Attention'**
  String get documentsNeedAttention;

  /// No description provided for @verificationInProgress.
  ///
  /// In en, this message translates to:
  /// **'Verification in Progress'**
  String get verificationInProgress;

  /// No description provided for @oneOrMoreDocumentsWereRejectedByOurTeamPleaseRev.
  ///
  /// In en, this message translates to:
  /// **'One or more documents were rejected by our team. Please review the reasons below and re-upload the affected documents.'**
  String get oneOrMoreDocumentsWereRejectedByOurTeamPleaseRev;

  /// No description provided for @yourDocumentsHaveBeenSubmittedSuccessfullyPlease.
  ///
  /// In en, this message translates to:
  /// **'Your documents have been submitted successfully. Please wait while our team reviews them — this usually takes up to 48 hours.'**
  String get yourDocumentsHaveBeenSubmittedSuccessfullyPlease;

  /// No description provided for @tapFixDocumentsToReUploadRejectedFilesPullDownTo.
  ///
  /// In en, this message translates to:
  /// **'Tap \"Fix Documents\" to re-upload rejected files. Pull down to refresh after admin approval.'**
  String get tapFixDocumentsToReUploadRejectedFilesPullDownTo;

  /// No description provided for @youLlReceiveANotificationOnceYourAccountIsApprov.
  ///
  /// In en, this message translates to:
  /// **'You\'ll receive a notification once your account is approved. Pull down to refresh status.'**
  String get youLlReceiveANotificationOnceYourAccountIsApprov;

  /// No description provided for @checking.
  ///
  /// In en, this message translates to:
  /// **'Checking...'**
  String get checking;

  /// No description provided for @checkStatus.
  ///
  /// In en, this message translates to:
  /// **'Check Status'**
  String get checkStatus;

  /// No description provided for @fixDocuments.
  ///
  /// In en, this message translates to:
  /// **'Fix Documents'**
  String get fixDocuments;

  /// No description provided for @backToDocuments.
  ///
  /// In en, this message translates to:
  /// **'Back to Documents'**
  String get backToDocuments;

  /// No description provided for @nearby.
  ///
  /// In en, this message translates to:
  /// **'Nearby'**
  String get nearby;

  /// No description provided for @enableLocationPermissionToUseTheMap.
  ///
  /// In en, this message translates to:
  /// **'Enable location permission to use the map'**
  String get enableLocationPermissionToUseTheMap;

  /// No description provided for @couldNotGetYourLocation.
  ///
  /// In en, this message translates to:
  /// **'Could not get your location'**
  String get couldNotGetYourLocation;

  /// No description provided for @paymentConfirmed.
  ///
  /// In en, this message translates to:
  /// **'Payment confirmed'**
  String get paymentConfirmed;

  /// No description provided for @activeJobInProgress.
  ///
  /// In en, this message translates to:
  /// **'Active job in progress'**
  String get activeJobInProgress;

  /// No description provided for @openingNavigationShortly.
  ///
  /// In en, this message translates to:
  /// **'Opening navigation shortly…'**
  String get openingNavigationShortly;

  /// No description provided for @followingYourLocation.
  ///
  /// In en, this message translates to:
  /// **'Following your location'**
  String get followingYourLocation;

  /// No description provided for @followMyLocation.
  ///
  /// In en, this message translates to:
  /// **'Follow my location'**
  String get followMyLocation;

  /// No description provided for @gpsActive.
  ///
  /// In en, this message translates to:
  /// **'GPS active'**
  String get gpsActive;

  /// No description provided for @customerLocation.
  ///
  /// In en, this message translates to:
  /// **'Customer location'**
  String get customerLocation;

  /// No description provided for @providerAgreementBody.
  ///
  /// In en, this message translates to:
  /// **'Ryvo Driver Service Agreement\n\nBy accepting this agreement, you confirm that:\n\n1. You are legally authorized to provide passenger rides in your operating area.\n\n2. All information and documents you submit (including your identity selfie, driving license, vehicle registration, insurance, and vehicle photos) are accurate and belong to you.\n\n3. Your identity selfie will be used to verify that you match your driving license and may be shown as your public driver profile photo to customers.\n\n4. You will maintain valid licenses, insurance, and a roadworthy vehicle at all times while offering services on RYVO.\n\n5. You agree to follow RYVO platform policies, safety standards, and professional conduct when interacting with customers.\n\n6. RYVO may suspend or terminate your driver account if documents are fraudulent, expired, or if you violate platform rules.\n\n7. Commission rates, payouts, and service terms are governed by the RYVO platform settings and applicable law.\n\nIf the agreement version is updated, you will be asked to accept the new version before continuing.'**
  String get providerAgreementBody;
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
      <String>['en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
