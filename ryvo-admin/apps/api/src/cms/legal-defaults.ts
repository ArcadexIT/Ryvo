export const LEGAL_KEYS = ['terms', 'privacy'] as const;

export type LegalKey = (typeof LEGAL_KEYS)[number];

export const LEGAL_DEFAULTS: Record<LegalKey, { title: string; content: string }> = {
  terms: {
    title: 'Terms and Conditions',
    content: `## Introduction

These Terms and Conditions ("Terms") govern your use of the RYVO website, customer application and related services operated by Ryvo Ltd ("RYVO", "we", "our" or "us").

By creating an account or requesting a ride, you agree to these Terms and to our Privacy Policy. If you do not agree, do not use the Services.

This document is a product placeholder and should be reviewed by a lawyer before it is treated as a binding agreement.

## The service

RYVO provides a technology platform that connects riders who want a trip with independent drivers.

RYVO is not the driver. A driver who accepts your request is an independent business or individual, and the trip itself is performed by that driver.

## Who can use RYVO

You must be 18 or older to create an account. You agree to give accurate information, keep your login details secure, and tell us promptly if you believe someone else has used your account.

## Requests, pricing and payment

The price shown before you request a ride is an estimate based on the ride class, pickup and dropoff. The final fare is calculated from distance and time when the trip ends, and your saved card or wallet is charged then.

You agree to pay the charges for rides you request. Card payments are processed by a third-party payment provider. RYVO does not store complete payment card details.

## Cancellations

You can cancel a ride in the app before the trip is completed. A charge may apply once a driver has accepted or has started travelling to you. Any cancellation charge is shown in the app at the time you cancel.

## Location

Ride matching depends on knowing where you are. You agree that RYVO and the assigned driver may use your location to find you, estimate arrival and complete the trip.

## Your responsibilities

You agree to:

- Give a safe and accurate pickup and dropoff
- Be ready at the pickup point
- Treat the driver and their vehicle with care
- Use the Services only for lawful purposes

## Acceptable use

You must not misuse the platform, interfere with how it works, make false requests, harass a driver or another user, or try to access someone else's account.

## Liability

Drivers are responsible for the trip they accept. RYVO is responsible for operating the platform with reasonable care.

Nothing in these Terms limits any liability that cannot legally be limited, including liability for death or personal injury caused by negligence, or for fraud.

## Changes

We may update these Terms from time to time. The current version is published on this page and in the customer app. Continued use of the Services after an update means you accept the updated Terms.

## Contact

Questions about these Terms can be sent to:

Ryvo Ltd
128 City Road
London
United Kingdom
EC1V 2NX
Email: enquiries@ryvo.arcadexit.com`,
  },
  privacy: {
    title: 'Privacy Policy',
    content: `## Introduction

Ryvo Ltd ("RYVO", "we", "our", or "us") provides a technology platform that connects riders with independent drivers.

This Privacy Policy explains how we collect, use, store, disclose and protect personal information when you use our website, rider application, driver application and related services (collectively, the "Services"). This document is a product placeholder and should be reviewed before it is published as a binding policy.

## Information We Collect

We may collect the following information:

- Name, email address and telephone number
- Account registration information
- Trip details including pickup, dropoff and ride class
- Payment and transaction information
- Driver profile, vehicle and verification information
- Driving licence, insurance and qualification details where applicable
- Device identifiers, operating system and app usage information
- GPS and location information
- Communications made through the platform

## Location Data

RYVO relies on location services to match riders with nearby drivers and to show a live trip.

We may collect precise location information from riders requesting a trip and from drivers who are online or on a trip. This information is used to dispatch nearby drivers, provide estimated arrival times, enable navigation and improve the service.

Depending on app permissions and applicable laws, location information may be collected while the app is active and, where necessary to support ongoing services, in the background.

## How We Use Information

- Create and manage user accounts
- Connect riders with drivers
- Dispatch and manage ride requests
- Provide real-time tracking and trip status updates
- Process payments and refunds
- Verify driver identities, vehicles and credentials
- Provide customer support
- Improve platform performance and reliability
- Prevent fraud, abuse and unauthorised activity
- Comply with legal and regulatory obligations

## Information Sharing

To complete a ride, certain information is shared between riders and drivers.

Drivers may receive the rider's first name, pickup, dropoff and contact details needed for the trip.

Riders may receive the driver's name, vehicle, estimated arrival and trip status.

We may also share information with payment processors, cloud hosting providers, analytics providers, customer support providers and legal authorities where required by law.

## Payments

Payments made through the platform may be processed by third-party payment service providers. RYVO does not store complete payment card details on its own systems.

## Communications

We may retain communications made through the platform, including customer support requests, service-related messages and notifications, to assist with service delivery, dispute resolution, security and quality assurance.

## Cookies and Analytics

Our website and applications may use cookies, analytics tools and similar technologies to understand usage patterns, improve performance and enhance the user experience.

## Data Retention

We retain information only for as long as reasonably necessary to provide our Services, comply with legal obligations, resolve disputes and enforce our agreements.

## Data Security

We implement technical, administrative and organisational measures designed to protect information from unauthorised access, loss, misuse, disclosure or alteration. However, no method of transmission or storage can be guaranteed to be completely secure.

## Your Rights

Depending on your location and applicable data protection laws, you may have the right to:

- Access personal information we hold about you
- Request correction of inaccurate information
- Request deletion of personal information
- Object to or restrict certain processing activities
- Request transfer of your information where applicable
- Withdraw consent where processing relies on consent

## Children's Privacy

The Services are intended for users aged 18 years or older. We do not knowingly collect personal information from children.

## Changes to this Privacy Policy

We may update this Privacy Policy from time to time. Any changes will be published on this page and become effective upon publication.

## Contact Us

If you have any questions regarding this Privacy Policy, please contact:

Ryvo Ltd
128 City Road
London
United Kingdom
EC1V 2NX
Email: enquiries@ryvo.arcadexit.com`,
  },
};
