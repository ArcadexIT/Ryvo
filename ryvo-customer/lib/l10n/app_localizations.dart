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
  /// **'Ryvo'**
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

  /// No description provided for @enterAddress.
  ///
  /// In en, this message translates to:
  /// **'Enter address'**
  String get enterAddress;

  /// No description provided for @typeTheAssistanceAddressThenConfirmItOnTheMap.
  ///
  /// In en, this message translates to:
  /// **'Type the address, then confirm it on the map.'**
  String get typeTheAssistanceAddressThenConfirmItOnTheMap;

  /// No description provided for @streetCityOrLandmark.
  ///
  /// In en, this message translates to:
  /// **'Street, city, or landmark'**
  String get streetCityOrLandmark;

  /// No description provided for @assistanceAddress.
  ///
  /// In en, this message translates to:
  /// **'Pickup address'**
  String get assistanceAddress;

  /// No description provided for @reasonOptional.
  ///
  /// In en, this message translates to:
  /// **'Reason (optional)'**
  String get reasonOptional;

  /// No description provided for @keepJob.
  ///
  /// In en, this message translates to:
  /// **'Keep trip'**
  String get keepJob;

  /// No description provided for @cancelJob.
  ///
  /// In en, this message translates to:
  /// **'Cancel trip'**
  String get cancelJob;

  /// No description provided for @selectCountry.
  ///
  /// In en, this message translates to:
  /// **'Select country'**
  String get selectCountry;

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

  /// No description provided for @searchCountryOrCode.
  ///
  /// In en, this message translates to:
  /// **'Search country or code'**
  String get searchCountryOrCode;

  /// No description provided for @noCountriesFound.
  ///
  /// In en, this message translates to:
  /// **'No countries found'**
  String get noCountriesFound;

  /// No description provided for @instantJumpStart.
  ///
  /// In en, this message translates to:
  /// **'Request a ride'**
  String get instantJumpStart;

  /// No description provided for @strandedWithADeadBatteryGetAVerifiedProviderToYo.
  ///
  /// In en, this message translates to:
  /// **'Set a pickup and dropoff. A nearby driver accepts, and you pay when you arrive.'**
  String get strandedWithADeadBatteryGetAVerifiedProviderToYo;

  /// No description provided for @verifiedTrusted.
  ///
  /// In en, this message translates to:
  /// **'Verified & Trusted'**
  String get verifiedTrusted;

  /// No description provided for @everyProviderIsBackgroundCheckedCertifiedAndRate.
  ///
  /// In en, this message translates to:
  /// **'Every driver is licence-checked, insured, and rated by riders.'**
  String get everyProviderIsBackgroundCheckedCertifiedAndRate;

  /// No description provided for @liveTracking.
  ///
  /// In en, this message translates to:
  /// **'Live Tracking'**
  String get liveTracking;

  /// No description provided for @watchYourProviderNavigateToYouInRealTimeKnowExac.
  ///
  /// In en, this message translates to:
  /// **'Watch your driver on the map, from pickup through to dropoff.'**
  String get watchYourProviderNavigateToYouInRealTimeKnowExac;

  /// No description provided for @skip.
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get skip;

  /// No description provided for @emergencyJumpStartInstantly.
  ///
  /// In en, this message translates to:
  /// **'Your ride, when you need it'**
  String get emergencyJumpStartInstantly;

  /// No description provided for @notifications.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get notifications;

  /// No description provided for @markAllRead.
  ///
  /// In en, this message translates to:
  /// **'Mark all read'**
  String get markAllRead;

  /// No description provided for @failedToLoadNotifications.
  ///
  /// In en, this message translates to:
  /// **'Failed to load notifications'**
  String get failedToLoadNotifications;

  /// No description provided for @noNotificationsYet.
  ///
  /// In en, this message translates to:
  /// **'No notifications yet'**
  String get noNotificationsYet;

  /// No description provided for @findingYourProvider.
  ///
  /// In en, this message translates to:
  /// **'Finding a driver...'**
  String get findingYourProvider;

  /// No description provided for @weReMatchingYouWithTheNearestVerifiedProvider.
  ///
  /// In en, this message translates to:
  /// **'Nearby drivers can see your offer and accept it'**
  String get weReMatchingYouWithTheNearestVerifiedProvider;

  /// No description provided for @noProvidersAvailable.
  ///
  /// In en, this message translates to:
  /// **'No drivers available'**
  String get noProvidersAvailable;

  /// No description provided for @thereAreNoProvidersAvailableNearbyRightNowPlease.
  ///
  /// In en, this message translates to:
  /// **'There are no drivers available nearby right now. Please try again in a few minutes.'**
  String get thereAreNoProvidersAvailableNearbyRightNowPlease;

  /// No description provided for @backToHome.
  ///
  /// In en, this message translates to:
  /// **'Back to home'**
  String get backToHome;

  /// No description provided for @priceEstimate.
  ///
  /// In en, this message translates to:
  /// **'Price Estimate'**
  String get priceEstimate;

  /// No description provided for @priceBreakdown.
  ///
  /// In en, this message translates to:
  /// **'Price Breakdown'**
  String get priceBreakdown;

  /// No description provided for @estimatedFare.
  ///
  /// In en, this message translates to:
  /// **'Estimated fare'**
  String get estimatedFare;

  /// No description provided for @total.
  ///
  /// In en, this message translates to:
  /// **'Total'**
  String get total;

  /// No description provided for @estimatedArrival.
  ///
  /// In en, this message translates to:
  /// **'Estimated arrival: '**
  String get estimatedArrival;

  /// No description provided for @text38Minutes.
  ///
  /// In en, this message translates to:
  /// **'3–8 minutes'**
  String get text38Minutes;

  /// No description provided for @paymentMethod.
  ///
  /// In en, this message translates to:
  /// **'Payment Method'**
  String get paymentMethod;

  /// No description provided for @noPaymentMethodsAreCurrentlyAvailablePleaseConta.
  ///
  /// In en, this message translates to:
  /// **'No payment methods are currently available. Please contact support.'**
  String get noPaymentMethodsAreCurrentlyAvailablePleaseConta;

  /// No description provided for @wallet.
  ///
  /// In en, this message translates to:
  /// **'Wallet'**
  String get wallet;

  /// No description provided for @card.
  ///
  /// In en, this message translates to:
  /// **'Card'**
  String get card;

  /// No description provided for @cash.
  ///
  /// In en, this message translates to:
  /// **'Cash'**
  String get cash;

  /// No description provided for @walletBalance.
  ///
  /// In en, this message translates to:
  /// **'Wallet Balance: '**
  String get walletBalance;

  /// No description provided for @pleaseAddAVehicleBeforeContinuing.
  ///
  /// In en, this message translates to:
  /// **'Please add a vehicle before continuing'**
  String get pleaseAddAVehicleBeforeContinuing;

  /// No description provided for @add.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get add;

  /// No description provided for @whatDoYouNeed.
  ///
  /// In en, this message translates to:
  /// **'Choose a ride'**
  String get whatDoYouNeed;

  /// No description provided for @additionalDetails.
  ///
  /// In en, this message translates to:
  /// **'Additional Details'**
  String get additionalDetails;

  /// No description provided for @helpTheProviderUnderstandYourSituation.
  ///
  /// In en, this message translates to:
  /// **'Add a note for your driver'**
  String get helpTheProviderUnderstandYourSituation;

  /// No description provided for @vehicle.
  ///
  /// In en, this message translates to:
  /// **'Vehicle'**
  String get vehicle;

  /// No description provided for @noVehicleAdded.
  ///
  /// In en, this message translates to:
  /// **'No vehicle added'**
  String get noVehicleAdded;

  /// No description provided for @addYourVehicleBeforeContinuingWithTheServiceRequ.
  ///
  /// In en, this message translates to:
  /// **'A personal vehicle is not required to request a ride.'**
  String get addYourVehicleBeforeContinuingWithTheServiceRequ;

  /// No description provided for @addVehicle.
  ///
  /// In en, this message translates to:
  /// **'Add Vehicle'**
  String get addVehicle;

  /// No description provided for @change.
  ///
  /// In en, this message translates to:
  /// **'Change'**
  String get change;

  /// No description provided for @eGCarWonTStartBatterySeemsDead.
  ///
  /// In en, this message translates to:
  /// **'e.g. Meet me at the main entrance'**
  String get eGCarWonTStartBatterySeemsDead;

  /// No description provided for @notesOptional.
  ///
  /// In en, this message translates to:
  /// **'Notes (Optional)'**
  String get notesOptional;

  /// No description provided for @dragMapToMovePin.
  ///
  /// In en, this message translates to:
  /// **'Drag map to move pin'**
  String get dragMapToMovePin;

  /// No description provided for @resolvingAddress.
  ///
  /// In en, this message translates to:
  /// **'Resolving address…'**
  String get resolvingAddress;

  /// No description provided for @providerAssigned.
  ///
  /// In en, this message translates to:
  /// **'Driver assigned'**
  String get providerAssigned;

  /// No description provided for @providerHasArrived.
  ///
  /// In en, this message translates to:
  /// **'Driver has arrived'**
  String get providerHasArrived;

  /// No description provided for @yourProviderIsAtYourLocation.
  ///
  /// In en, this message translates to:
  /// **'Your driver is at your pickup'**
  String get yourProviderIsAtYourLocation;

  /// No description provided for @arrivingIn.
  ///
  /// In en, this message translates to:
  /// **'Arriving in'**
  String get arrivingIn;

  /// No description provided for @verified.
  ///
  /// In en, this message translates to:
  /// **'Verified'**
  String get verified;

  /// No description provided for @plate.
  ///
  /// In en, this message translates to:
  /// **'Plate'**
  String get plate;

  /// No description provided for @color.
  ///
  /// In en, this message translates to:
  /// **'Color'**
  String get color;

  /// No description provided for @backgroundCheckedCertified.
  ///
  /// In en, this message translates to:
  /// **'Background checked & certified'**
  String get backgroundCheckedCertified;

  /// No description provided for @trackOnMap.
  ///
  /// In en, this message translates to:
  /// **'Track on Map'**
  String get trackOnMap;

  /// No description provided for @providerArrived.
  ///
  /// In en, this message translates to:
  /// **'Driver arrived'**
  String get providerArrived;

  /// No description provided for @serviceInProgress.
  ///
  /// In en, this message translates to:
  /// **'Trip in progress'**
  String get serviceInProgress;

  /// No description provided for @serviceComplete.
  ///
  /// In en, this message translates to:
  /// **'Trip complete'**
  String get serviceComplete;

  /// No description provided for @serviceInProgress2.
  ///
  /// In en, this message translates to:
  /// **'Trip in progress'**
  String get serviceInProgress2;

  /// No description provided for @live.
  ///
  /// In en, this message translates to:
  /// **'LIVE'**
  String get live;

  /// No description provided for @timeElapsed.
  ///
  /// In en, this message translates to:
  /// **'Time elapsed'**
  String get timeElapsed;

  /// No description provided for @serviceStatus.
  ///
  /// In en, this message translates to:
  /// **'Trip status'**
  String get serviceStatus;

  /// No description provided for @callProvider.
  ///
  /// In en, this message translates to:
  /// **'Call driver'**
  String get callProvider;

  /// No description provided for @waitingForProviderToFinish.
  ///
  /// In en, this message translates to:
  /// **'Waiting for your driver to finish the trip…'**
  String get waitingForProviderToFinish;

  /// No description provided for @distance.
  ///
  /// In en, this message translates to:
  /// **'Distance'**
  String get distance;

  /// No description provided for @eta.
  ///
  /// In en, this message translates to:
  /// **'ETA'**
  String get eta;

  /// No description provided for @availableBalance.
  ///
  /// In en, this message translates to:
  /// **'Available Balance'**
  String get availableBalance;

  /// No description provided for @active.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get active;

  /// No description provided for @topUp.
  ///
  /// In en, this message translates to:
  /// **'Top Up'**
  String get topUp;

  /// No description provided for @transactionHistory.
  ///
  /// In en, this message translates to:
  /// **'Transaction History'**
  String get transactionHistory;

  /// No description provided for @noTransactionsYet.
  ///
  /// In en, this message translates to:
  /// **'No transactions yet'**
  String get noTransactionsYet;

  /// No description provided for @topUpWallet.
  ///
  /// In en, this message translates to:
  /// **'Top Up Wallet'**
  String get topUpWallet;

  /// No description provided for @currentBalance.
  ///
  /// In en, this message translates to:
  /// **'Current Balance'**
  String get currentBalance;

  /// No description provided for @selectAmount.
  ///
  /// In en, this message translates to:
  /// **'Select Amount'**
  String get selectAmount;

  /// No description provided for @orEnterCustomAmount.
  ///
  /// In en, this message translates to:
  /// **'Or enter custom amount'**
  String get orEnterCustomAmount;

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

  /// No description provided for @thisTicketIsClosedCreateANewTicketIfYouNeedMoreH.
  ///
  /// In en, this message translates to:
  /// **'This ticket is closed. Create a new ticket if you need more help.'**
  String get thisTicketIsClosedCreateANewTicketIfYouNeedMoreH;

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

  /// No description provided for @noFAQsAvailableYet.
  ///
  /// In en, this message translates to:
  /// **'No FAQs available yet.'**
  String get noFAQsAvailableYet;

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

  /// No description provided for @walletCardPaymentsRefunds.
  ///
  /// In en, this message translates to:
  /// **'Wallet, card payments, refunds'**
  String get walletCardPaymentsRefunds;

  /// No description provided for @newTicket.
  ///
  /// In en, this message translates to:
  /// **'New Ticket'**
  String get newTicket;

  /// No description provided for @category.
  ///
  /// In en, this message translates to:
  /// **'Category'**
  String get category;

  /// No description provided for @subject.
  ///
  /// In en, this message translates to:
  /// **'Subject'**
  String get subject;

  /// No description provided for @briefSummaryOfYourIssue.
  ///
  /// In en, this message translates to:
  /// **'Brief summary of your issue'**
  String get briefSummaryOfYourIssue;

  /// No description provided for @message.
  ///
  /// In en, this message translates to:
  /// **'Message'**
  String get message;

  /// No description provided for @describeYourIssueInDetail.
  ///
  /// In en, this message translates to:
  /// **'Describe your issue in detail'**
  String get describeYourIssueInDetail;

  /// No description provided for @linkedToAJob.
  ///
  /// In en, this message translates to:
  /// **'Linked to a trip'**
  String get linkedToAJob;

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

  /// No description provided for @needHelpCreateATicketAndOurTeamWillRespond.
  ///
  /// In en, this message translates to:
  /// **'Need help? Create a ticket and our team will respond.'**
  String get needHelpCreateATicketAndOurTeamWillRespond;

  /// No description provided for @createTicket.
  ///
  /// In en, this message translates to:
  /// **'Create Ticket'**
  String get createTicket;

  /// No description provided for @profile.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get profile;

  /// No description provided for @notSignedIn.
  ///
  /// In en, this message translates to:
  /// **'Not signed in'**
  String get notSignedIn;

  /// No description provided for @trips.
  ///
  /// In en, this message translates to:
  /// **'Trips'**
  String get trips;

  /// No description provided for @rating.
  ///
  /// In en, this message translates to:
  /// **'Rating'**
  String get rating;

  /// No description provided for @appearance.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get appearance;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @privacyPolicy.
  ///
  /// In en, this message translates to:
  /// **'Privacy Policy'**
  String get privacyPolicy;

  /// No description provided for @signOut.
  ///
  /// In en, this message translates to:
  /// **'Sign Out'**
  String get signOut;

  /// No description provided for @ryvoV100.
  ///
  /// In en, this message translates to:
  /// **'Ryvo v1.0.0'**
  String get ryvoV100;

  /// No description provided for @light.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get light;

  /// No description provided for @dark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get dark;

  /// No description provided for @system.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get system;

  /// No description provided for @securePayment.
  ///
  /// In en, this message translates to:
  /// **'Secure Payment'**
  String get securePayment;

  /// No description provided for @noPaymentMethodsAreCurrentlyAvailablePleaseTryAg.
  ///
  /// In en, this message translates to:
  /// **'No payment methods are currently available. Please try again later or contact support.'**
  String get noPaymentMethodsAreCurrentlyAvailablePleaseTryAg;

  /// No description provided for @choosePaymentMethod.
  ///
  /// In en, this message translates to:
  /// **'Choose Payment Method'**
  String get choosePaymentMethod;

  /// No description provided for @cardStripe.
  ///
  /// In en, this message translates to:
  /// **'Card'**
  String get cardStripe;

  /// No description provided for @paySecurelyWithYourCard.
  ///
  /// In en, this message translates to:
  /// **'Visa, Mastercard, or a new card'**
  String get paySecurelyWithYourCard;

  /// No description provided for @googlePay.
  ///
  /// In en, this message translates to:
  /// **'Google Pay'**
  String get googlePay;

  /// No description provided for @payWithCardsInGoogleWallet.
  ///
  /// In en, this message translates to:
  /// **'Pay with a card saved in Google Wallet'**
  String get payWithCardsInGoogleWallet;

  /// No description provided for @applePay.
  ///
  /// In en, this message translates to:
  /// **'Apple Pay'**
  String get applePay;

  /// No description provided for @payWithApplePay.
  ///
  /// In en, this message translates to:
  /// **'Pay with a card saved in Apple Wallet'**
  String get payWithApplePay;

  /// No description provided for @payTheProviderWhenServiceCompletes.
  ///
  /// In en, this message translates to:
  /// **'Pay the driver when the trip ends'**
  String get payTheProviderWhenServiceCompletes;

  /// No description provided for @paymentSuccessful.
  ///
  /// In en, this message translates to:
  /// **'Payment Successful!'**
  String get paymentSuccessful;

  /// No description provided for @service.
  ///
  /// In en, this message translates to:
  /// **'Ride'**
  String get service;

  /// No description provided for @provider.
  ///
  /// In en, this message translates to:
  /// **'Driver'**
  String get provider;

  /// No description provided for @job.
  ///
  /// In en, this message translates to:
  /// **'Trip #'**
  String get job;

  /// No description provided for @paymentVia.
  ///
  /// In en, this message translates to:
  /// **'Payment via'**
  String get paymentVia;

  /// No description provided for @totalPaid.
  ///
  /// In en, this message translates to:
  /// **'Total Paid'**
  String get totalPaid;

  /// No description provided for @howWasYourExperience.
  ///
  /// In en, this message translates to:
  /// **'How was your experience?'**
  String get howWasYourExperience;

  /// No description provided for @writeAReviewOptional.
  ///
  /// In en, this message translates to:
  /// **'Write a review (optional)'**
  String get writeAReviewOptional;

  /// No description provided for @createAccount.
  ///
  /// In en, this message translates to:
  /// **'Create Account'**
  String get createAccount;

  /// No description provided for @joinRyvoAndGetHelpInMinutes.
  ///
  /// In en, this message translates to:
  /// **'Join Ryvo and request a ride in minutes'**
  String get joinRyvoAndGetHelpInMinutes;

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

  /// No description provided for @byCreatingAnAccountYouAgreeToOurTermsOfServiceAn.
  ///
  /// In en, this message translates to:
  /// **'By creating an account, you agree to our\nTerms of Service and Privacy Policy'**
  String get byCreatingAnAccountYouAgreeToOurTermsOfServiceAn;

  /// No description provided for @termsAndConditions.
  ///
  /// In en, this message translates to:
  /// **'Terms and Conditions'**
  String get termsAndConditions;

  /// No description provided for @iAgreeToThe.
  ///
  /// In en, this message translates to:
  /// **'I agree to the '**
  String get iAgreeToThe;

  /// No description provided for @andWord.
  ///
  /// In en, this message translates to:
  /// **'and'**
  String get andWord;

  /// No description provided for @pleaseAcceptTheTermsAndPrivacyPolicy.
  ///
  /// In en, this message translates to:
  /// **'Please accept the Terms and Conditions and Privacy Policy'**
  String get pleaseAcceptTheTermsAndPrivacyPolicy;

  /// No description provided for @couldNotLoadThisDocument.
  ///
  /// In en, this message translates to:
  /// **'Could not load this document. Please try again.'**
  String get couldNotLoadThisDocument;

  /// No description provided for @lastUpdated.
  ///
  /// In en, this message translates to:
  /// **'Last updated'**
  String get lastUpdated;

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

  /// No description provided for @signInToContinue.
  ///
  /// In en, this message translates to:
  /// **'Sign in to continue'**
  String get signInToContinue;

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

  /// No description provided for @enterNewPasswordMin6.
  ///
  /// In en, this message translates to:
  /// **'Enter new password (min 6)'**
  String get enterNewPasswordMin6;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @reset.
  ///
  /// In en, this message translates to:
  /// **'Reset'**
  String get reset;

  /// No description provided for @verificationCodeSent.
  ///
  /// In en, this message translates to:
  /// **'Verification code sent'**
  String get verificationCodeSent;

  /// No description provided for @verifyPhone.
  ///
  /// In en, this message translates to:
  /// **'Verify Phone'**
  String get verifyPhone;

  /// No description provided for @resendCode.
  ///
  /// In en, this message translates to:
  /// **'Resend Code'**
  String get resendCode;

  /// No description provided for @myBookings.
  ///
  /// In en, this message translates to:
  /// **'My Bookings'**
  String get myBookings;

  /// No description provided for @totalJobs.
  ///
  /// In en, this message translates to:
  /// **'Total trips'**
  String get totalJobs;

  /// No description provided for @totalSpent.
  ///
  /// In en, this message translates to:
  /// **'Total Spent'**
  String get totalSpent;

  /// No description provided for @recentBookings.
  ///
  /// In en, this message translates to:
  /// **'Recent Bookings'**
  String get recentBookings;

  /// No description provided for @noBookingsYet.
  ///
  /// In en, this message translates to:
  /// **'No bookings yet'**
  String get noBookingsYet;

  /// No description provided for @noMessagesYet.
  ///
  /// In en, this message translates to:
  /// **'No messages yet'**
  String get noMessagesYet;

  /// No description provided for @typeAMessage.
  ///
  /// In en, this message translates to:
  /// **'Type a message...'**
  String get typeAMessage;

  /// No description provided for @editVehicle.
  ///
  /// In en, this message translates to:
  /// **'Edit Vehicle'**
  String get editVehicle;

  /// No description provided for @vehicleDetails.
  ///
  /// In en, this message translates to:
  /// **'Vehicle Details'**
  String get vehicleDetails;

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

  /// No description provided for @model.
  ///
  /// In en, this message translates to:
  /// **'Model'**
  String get model;

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

  /// No description provided for @licensePlate.
  ///
  /// In en, this message translates to:
  /// **'License Plate'**
  String get licensePlate;

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

  /// No description provided for @skipForNow.
  ///
  /// In en, this message translates to:
  /// **'Skip for now'**
  String get skipForNow;

  /// No description provided for @home.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get home;

  /// No description provided for @bookings.
  ///
  /// In en, this message translates to:
  /// **'Bookings'**
  String get bookings;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @myVehicle.
  ///
  /// In en, this message translates to:
  /// **'My Vehicle'**
  String get myVehicle;

  /// No description provided for @readyToHelpYou.
  ///
  /// In en, this message translates to:
  /// **'Ready for a ride'**
  String get readyToHelpYou;

  /// No description provided for @backgroundChecked.
  ///
  /// In en, this message translates to:
  /// **'Background checked'**
  String get backgroundChecked;

  /// No description provided for @whatDoYouNeedHelpWith.
  ///
  /// In en, this message translates to:
  /// **'Where to?'**
  String get whatDoYouNeedHelpWith;

  /// No description provided for @couldNotLoadServicesTapToRetry.
  ///
  /// In en, this message translates to:
  /// **'Could not load rides — tap to retry'**
  String get couldNotLoadServicesTapToRetry;

  /// No description provided for @whereAreYou.
  ///
  /// In en, this message translates to:
  /// **'Where are you?'**
  String get whereAreYou;

  /// No description provided for @bookNow.
  ///
  /// In en, this message translates to:
  /// **'Book Now'**
  String get bookNow;

  /// No description provided for @iNeedHelpRightAway.
  ///
  /// In en, this message translates to:
  /// **'I need help right away'**
  String get iNeedHelpRightAway;

  /// No description provided for @bookLater.
  ///
  /// In en, this message translates to:
  /// **'Book Later'**
  String get bookLater;

  /// No description provided for @resume.
  ///
  /// In en, this message translates to:
  /// **'Resume'**
  String get resume;

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

  /// No description provided for @loading.
  ///
  /// In en, this message translates to:
  /// **'Loading...'**
  String get loading;

  /// No description provided for @findingAddress.
  ///
  /// In en, this message translates to:
  /// **'Finding address…'**
  String get findingAddress;

  /// No description provided for @useThisAddress.
  ///
  /// In en, this message translates to:
  /// **'Use this address'**
  String get useThisAddress;

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

  /// No description provided for @cancelling.
  ///
  /// In en, this message translates to:
  /// **'Cancelling...'**
  String get cancelling;

  /// No description provided for @cancelRequest.
  ///
  /// In en, this message translates to:
  /// **'Cancel Request'**
  String get cancelRequest;

  /// No description provided for @missingServiceDetails.
  ///
  /// In en, this message translates to:
  /// **'Missing ride details'**
  String get missingServiceDetails;

  /// No description provided for @confirmYourAssistanceAddressFirst.
  ///
  /// In en, this message translates to:
  /// **'Confirm your pickup first'**
  String get confirmYourAssistanceAddressFirst;

  /// No description provided for @noPaymentMethodsAreAvailable.
  ///
  /// In en, this message translates to:
  /// **'No payment methods are available'**
  String get noPaymentMethodsAreAvailable;

  /// No description provided for @sufficient.
  ///
  /// In en, this message translates to:
  /// **'Sufficient'**
  String get sufficient;

  /// No description provided for @lowBalance.
  ///
  /// In en, this message translates to:
  /// **'Low balance'**
  String get lowBalance;

  /// No description provided for @creatingRequest.
  ///
  /// In en, this message translates to:
  /// **'Creating request...'**
  String get creatingRequest;

  /// No description provided for @continueToPayment.
  ///
  /// In en, this message translates to:
  /// **'Continue to Payment'**
  String get continueToPayment;

  /// No description provided for @finishCurrentRequestBeforeStartingAnother.
  ///
  /// In en, this message translates to:
  /// **'Finish your current request before starting another.'**
  String get finishCurrentRequestBeforeStartingAnother;

  /// No description provided for @couldNotCancelUnpaidRequest.
  ///
  /// In en, this message translates to:
  /// **'Could not remove the unpaid request. Please try again.'**
  String get couldNotCancelUnpaidRequest;

  /// No description provided for @payFirstThenWeFindYourProvider.
  ///
  /// In en, this message translates to:
  /// **'Confirm your payment method, then we find a driver'**
  String get payFirstThenWeFindYourProvider;

  /// No description provided for @pleaseSelectAService.
  ///
  /// In en, this message translates to:
  /// **'Please select a ride'**
  String get pleaseSelectAService;

  /// No description provided for @addAVehicleFirst.
  ///
  /// In en, this message translates to:
  /// **'Add a vehicle first'**
  String get addAVehicleFirst;

  /// No description provided for @selectAService.
  ///
  /// In en, this message translates to:
  /// **'Select a ride'**
  String get selectAService;

  /// No description provided for @selectService.
  ///
  /// In en, this message translates to:
  /// **'Choose a ride'**
  String get selectService;

  /// No description provided for @addDetails.
  ///
  /// In en, this message translates to:
  /// **'Add Details'**
  String get addDetails;

  /// No description provided for @confirmLocation.
  ///
  /// In en, this message translates to:
  /// **'Confirm Location'**
  String get confirmLocation;

  /// No description provided for @addVehicleToContinue.
  ///
  /// In en, this message translates to:
  /// **'Add vehicle to continue'**
  String get addVehicleToContinue;

  /// No description provided for @textContinue.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get textContinue;

  /// No description provided for @gettingEstimate.
  ///
  /// In en, this message translates to:
  /// **'Getting estimate…'**
  String get gettingEstimate;

  /// No description provided for @resolvingLocation.
  ///
  /// In en, this message translates to:
  /// **'Resolving location…'**
  String get resolvingLocation;

  /// No description provided for @confirmThisLocation.
  ///
  /// In en, this message translates to:
  /// **'Confirm this location'**
  String get confirmThisLocation;

  /// No description provided for @yourProvider.
  ///
  /// In en, this message translates to:
  /// **'Your driver'**
  String get yourProvider;

  /// No description provided for @matched.
  ///
  /// In en, this message translates to:
  /// **'matched'**
  String get matched;

  /// No description provided for @providerIsOnTheWay.
  ///
  /// In en, this message translates to:
  /// **'Driver is on the way'**
  String get providerIsOnTheWay;

  /// No description provided for @providerIsHeadingToYou.
  ///
  /// In en, this message translates to:
  /// **'Driver is heading to you'**
  String get providerIsHeadingToYou;

  /// No description provided for @roadsideService.
  ///
  /// In en, this message translates to:
  /// **'Ride'**
  String get roadsideService;

  /// No description provided for @locating.
  ///
  /// In en, this message translates to:
  /// **'Locating...'**
  String get locating;

  /// No description provided for @arrived.
  ///
  /// In en, this message translates to:
  /// **'Arrived'**
  String get arrived;

  /// No description provided for @confirming.
  ///
  /// In en, this message translates to:
  /// **'Confirming…'**
  String get confirming;

  /// No description provided for @waitingForProvider.
  ///
  /// In en, this message translates to:
  /// **'Waiting for driver…'**
  String get waitingForProvider;

  /// No description provided for @confirmJobStarted.
  ///
  /// In en, this message translates to:
  /// **'Start trip'**
  String get confirmJobStarted;

  /// No description provided for @availableAfterYourProviderMarksArrived.
  ///
  /// In en, this message translates to:
  /// **'Available after your driver arrives'**
  String get availableAfterYourProviderMarksArrived;

  /// No description provided for @waitingForYourProviderToConfirmJobStarted.
  ///
  /// In en, this message translates to:
  /// **'Waiting for your driver to start the trip'**
  String get waitingForYourProviderToConfirmJobStarted;

  /// No description provided for @bothYouAndTheProviderMustConfirmBeforeTheTimerSt.
  ///
  /// In en, this message translates to:
  /// **'You and your driver both confirm before the trip starts'**
  String get bothYouAndTheProviderMustConfirmBeforeTheTimerSt;

  /// No description provided for @processing.
  ///
  /// In en, this message translates to:
  /// **'Processing...'**
  String get processing;

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

  /// No description provided for @pleaseEnterASubjectAndMessage.
  ///
  /// In en, this message translates to:
  /// **'Please enter a subject and message'**
  String get pleaseEnterASubjectAndMessage;

  /// No description provided for @general.
  ///
  /// In en, this message translates to:
  /// **'general'**
  String get general;

  /// No description provided for @required.
  ///
  /// In en, this message translates to:
  /// **'Required'**
  String get required;

  /// No description provided for @submitting.
  ///
  /// In en, this message translates to:
  /// **'Submitting...'**
  String get submitting;

  /// No description provided for @submitTicket.
  ///
  /// In en, this message translates to:
  /// **'Submit Ticket'**
  String get submitTicket;

  /// No description provided for @noActiveJob.
  ///
  /// In en, this message translates to:
  /// **'No active trip'**
  String get noActiveJob;

  /// No description provided for @noPaymentMethodsAreAvailableContactSupport.
  ///
  /// In en, this message translates to:
  /// **'No payment methods are available. Contact support.'**
  String get noPaymentMethodsAreAvailableContactSupport;

  /// No description provided for @paymentWasSubmittedButTheJobIsStillAwaitingConfi.
  ///
  /// In en, this message translates to:
  /// **'Payment was submitted but the trip is still awaiting confirmation. Please try again.'**
  String get paymentWasSubmittedButTheJobIsStillAwaitingConfi;

  /// No description provided for @paymentFailedPleaseTryAgain.
  ///
  /// In en, this message translates to:
  /// **'Payment failed. Please try again.'**
  String get paymentFailedPleaseTryAgain;

  /// No description provided for @ryvo.
  ///
  /// In en, this message translates to:
  /// **'Ryvo'**
  String get ryvo;

  /// No description provided for @youWillPayTheProviderInCashWhenTheServiceIsCompl.
  ///
  /// In en, this message translates to:
  /// **'You will pay the driver in cash when the trip ends.'**
  String get youWillPayTheProviderInCashWhenTheServiceIsCompl;

  /// No description provided for @fundsAreHeldSecurelyUntilYourServiceIsCompletedI.
  ///
  /// In en, this message translates to:
  /// **'Nothing is charged yet. Your card or wallet is charged when the trip ends.'**
  String get fundsAreHeldSecurelyUntilYourServiceIsCompletedI;

  /// No description provided for @recommended.
  ///
  /// In en, this message translates to:
  /// **'Recommended'**
  String get recommended;

  /// No description provided for @confirmFindProvider.
  ///
  /// In en, this message translates to:
  /// **'Confirm ride'**
  String get confirmFindProvider;

  /// No description provided for @payFindProvider.
  ///
  /// In en, this message translates to:
  /// **'Request ride'**
  String get payFindProvider;

  /// No description provided for @payCashToYourProviderOnCompletion.
  ///
  /// In en, this message translates to:
  /// **'Pay the driver in cash when you arrive'**
  String get payCashToYourProviderOnCompletion;

  /// No description provided for @securePaymentBeforeMatching.
  ///
  /// In en, this message translates to:
  /// **'Save a payment method before matching'**
  String get securePaymentBeforeMatching;

  /// No description provided for @backToHome2.
  ///
  /// In en, this message translates to:
  /// **'Back to Home'**
  String get backToHome2;

  /// No description provided for @pleaseSelectYourCountry.
  ///
  /// In en, this message translates to:
  /// **'Please select your country'**
  String get pleaseSelectYourCountry;

  /// No description provided for @enterYourFullName.
  ///
  /// In en, this message translates to:
  /// **'Enter your full name'**
  String get enterYourFullName;

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

  /// No description provided for @enterThe6DigitCodeSentToYourNumber.
  ///
  /// In en, this message translates to:
  /// **'Enter the 6-digit code sent to your number'**
  String get enterThe6DigitCodeSentToYourNumber;

  /// No description provided for @verifying.
  ///
  /// In en, this message translates to:
  /// **'Verifying...'**
  String get verifying;

  /// No description provided for @verify.
  ///
  /// In en, this message translates to:
  /// **'Verify'**
  String get verify;

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

  /// No description provided for @addYourVehicle.
  ///
  /// In en, this message translates to:
  /// **'Add Your Vehicle'**
  String get addYourVehicle;

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

  /// No description provided for @enterAModel.
  ///
  /// In en, this message translates to:
  /// **'Enter a model'**
  String get enterAModel;

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

  /// No description provided for @enter4DigitYear.
  ///
  /// In en, this message translates to:
  /// **'Enter 4-digit year'**
  String get enter4DigitYear;

  /// No description provided for @enterPlate.
  ///
  /// In en, this message translates to:
  /// **'Enter plate'**
  String get enterPlate;

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

  /// No description provided for @uploadingPhoto.
  ///
  /// In en, this message translates to:
  /// **'Uploading photo...'**
  String get uploadingPhoto;

  /// No description provided for @saving.
  ///
  /// In en, this message translates to:
  /// **'Saving...'**
  String get saving;

  /// No description provided for @updateVehicle.
  ///
  /// In en, this message translates to:
  /// **'Update Vehicle'**
  String get updateVehicle;

  /// No description provided for @saveVehicle.
  ///
  /// In en, this message translates to:
  /// **'Save Vehicle'**
  String get saveVehicle;

  /// No description provided for @welcome.
  ///
  /// In en, this message translates to:
  /// **'Welcome'**
  String get welcome;

  /// No description provided for @tapToEnterAddress.
  ///
  /// In en, this message translates to:
  /// **'Tap to enter address'**
  String get tapToEnterAddress;

  /// No description provided for @tapToEnterOrUseGPS.
  ///
  /// In en, this message translates to:
  /// **'Tap to enter or use GPS'**
  String get tapToEnterOrUseGPS;

  /// No description provided for @dragPinOrTapMap.
  ///
  /// In en, this message translates to:
  /// **'Hold and drag the pin, or tap the map'**
  String get dragPinOrTapMap;

  /// No description provided for @setYourLocation.
  ///
  /// In en, this message translates to:
  /// **'Set your location'**
  String get setYourLocation;

  /// No description provided for @searchForAPlace.
  ///
  /// In en, this message translates to:
  /// **'Search for a place'**
  String get searchForAPlace;

  /// No description provided for @searchUkAddress.
  ///
  /// In en, this message translates to:
  /// **'Search a UK address'**
  String get searchUkAddress;

  /// No description provided for @noMatchingUkAddresses.
  ///
  /// In en, this message translates to:
  /// **'No matching UK addresses'**
  String get noMatchingUkAddresses;

  /// No description provided for @changeLocation.
  ///
  /// In en, this message translates to:
  /// **'Change location'**
  String get changeLocation;

  /// No description provided for @useCurrentLocation.
  ///
  /// In en, this message translates to:
  /// **'Use current location'**
  String get useCurrentLocation;

  /// No description provided for @scheduleForLater.
  ///
  /// In en, this message translates to:
  /// **'Schedule for later'**
  String get scheduleForLater;

  /// No description provided for @providersWillComeToYourLocation.
  ///
  /// In en, this message translates to:
  /// **'A driver accepts, then you ride'**
  String get providersWillComeToYourLocation;

  /// No description provided for @tapBookLaterToSetATime.
  ///
  /// In en, this message translates to:
  /// **'Tap Book Later to set a time'**
  String get tapBookLaterToSetATime;

  /// No description provided for @shareTrip.
  ///
  /// In en, this message translates to:
  /// **'Share trip'**
  String get shareTrip;

  /// No description provided for @followMyRyvoTrip.
  ///
  /// In en, this message translates to:
  /// **'Follow my Ryvo trip'**
  String get followMyRyvoTrip;

  /// No description provided for @shareAgain.
  ///
  /// In en, this message translates to:
  /// **'Share again'**
  String get shareAgain;

  /// No description provided for @stopSharing.
  ///
  /// In en, this message translates to:
  /// **'Stop sharing'**
  String get stopSharing;

  /// No description provided for @sharingStopped.
  ///
  /// In en, this message translates to:
  /// **'Family can no longer follow this trip'**
  String get sharingStopped;

  /// No description provided for @couldNotShareTrip.
  ///
  /// In en, this message translates to:
  /// **'Could not create a trip link'**
  String get couldNotShareTrip;

  /// No description provided for @tripShareHint.
  ///
  /// In en, this message translates to:
  /// **'Anyone with this link can follow the car until the trip ends.'**
  String get tripShareHint;
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
