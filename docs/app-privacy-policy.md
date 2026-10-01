---
layout: page
title: App Privacy Policy
---

## Privacy Policy

This privacy policy applies to the NaMi app for mobile devices. The app is developed and maintained by Janneck Lange.

## Scope

The app is intended to support work with DPSG-related member administration data. It is developed privately and is not an official service of the DPSG.

This privacy policy describes which data is processed by the app itself and which third-party services are used.

## Data processed in the app

The app can process member-related content that is entered by users or loaded from external systems. This data is processed on the device to provide app functionality.

Member data loaded from Hitobito is stored locally on the device in encrypted form so it can be used offline after the first successful sign-in and initial data load.

The app shows achievements for app usage, for example the number of days the app was opened or the number of saved member changes. The counters and unlock dates are stored only on the device, are never transferred and are deleted when the app is reset.

For the statistics of the active Stamm, the app keeps a monthly history of aggregated figures, for example the number of members per age section, for up to 24 months. It also stores the user's tile layout, custom counting tiles and target values for each Stamm. This data contains no names or other individual member data, is stored only on the device, is never transferred and is deleted when the app is reset.

## Analytics and diagnostics

The app can send analytics and diagnostics events if analytics are enabled in the app settings. This is used to better understand app usage, detect problems and improve the app.

The analytics setting can be changed by the user inside the app.

Analytics and diagnostics events may include, for example:

- app settings changes
- login and logout events
- work context or layer changes
- runtime errors
- technical event metadata required for diagnostics

The app is designed so that no intentional transfer of member data in plain text should take place as part of these analytics events.

## Nationwide statistics (optional)

The app offers an optional nationwide comparison of Stamm figures. It is only active after the signed-in user has explicitly agreed to share the figures of their Stamm. The consent applies only to that user and can be withdrawn at any time in the app settings or on the comparison page.

If enabled, the app sends aggregated figures of the active Stamm to the statistics server of the NaMi app about once a week: the number of members and leaders per group of an age section (for example per Meute), split by gender, and, for users who may read the whole Stamm, the number of leaders by age group, the number of regular memberships and the number of other members. Users who may only read their own group share only the figures of that group. No names, dates of birth, addresses, contact details or other individual member data are sent, and no data identifying the user.

Each app installation creates a random installation ID and secret that are used to recognise the installation. The server pseudonymises the Stamm, its groups and the installation ID before storing them. The IDs of the district and diocese are stored as sent, if the app can determine them. The server only returns nationwide aggregates, and only to installations that shared figures within the last 14 days. Figures reported by fewer than a minimum number of Stämme are not shown. For the operator, the server keeps a monthly overview with counts of participating installations, Stämme and groups and the number of Stämme per district and diocese ID, accessible only with a password and optionally announced via a Telegram message; it contains no Stamm or member data.

Withdrawing consent stops further transfers. Figures already shared remain stored but are no longer included in the nationwide aggregate once they are older than two months. Resetting the app deletes the installation ID and secret. The last transferred figures can be viewed in the app.

## Demo mode

On the sign-in screen, the app offers a demo without a Hitobito account. After choosing one of several demo roles, the demo shows a fictional Bezirk with fictional Stämme, invented names and contact details. It is read-only and does not contact Hitobito. Demo data is kept in memory only and is discarded when the demo ends. If analytics are enabled, the demo sends only a single "demo used" event; actions inside the demo are not tracked. For the nationwide comparison, the demo sends the figures of the fictional Stämme to a separate test instance of the statistics server that holds only synthetic data and no real Stämme.

## Feedback

The app integrates a feedback service so users can send feedback from within the app. If this feature is used, the information entered by the user is transmitted to that service.

## Location and address features

The app itself does not continuously collect precise location data for analytics purposes.

For address-related features, user input may be sent to an external geocoding service to retrieve address suggestions. This happens only when the corresponding feature is used.

For member detail maps and the map around the saved Stamm address, postal address data may also be sent to Geoapify to geocode the address. The app stores resulting coordinates locally on the device to reduce repeated requests. If no sufficiently precise address match can be determined, the app may also store a local "address not found" cache state for that address input to avoid repeated geocoding requests. Map tiles may additionally be cached locally for offline use and may be delivered via a configured tile provider such as MapTiler, with an OpenStreetMap-based fallback used if no explicit tile URL is configured.

TODO: Before broader rollout of map features, refine this section and the in-app first-start notice with a more explicit consent flow for Privacy Policy acknowledgement.

## Third-party services

The app currently uses third-party services such as:

- Wiredash for feedback, optional satisfaction surveys (promoter score) and event tracking
- Geoapify for address autocomplete and geocoding
- MapTiler for configured map tile delivery, with an OpenStreetMap-based fallback when no explicit tile endpoint is configured
- platform and store infrastructure provided by Apple and Google

These services process data under their own privacy policies:

- [Wiredash Privacy Policy](https://wiredash.io/legal/privacy-policy)
- [Geoapify Privacy Policy](https://www.geoapify.com/privacy-policy/)
- [MapTiler Privacy Policy](https://www.maptiler.com/privacy-policy/)
- [Google Play Services](https://www.google.com/policies/privacy/)
- [Apple Privacy Policy](https://www.apple.com/legal/privacy/)

## Data retention

Hitobito profile and member data remain on the device until the user logs out or the locally stored data exceeds the configured maximum retention period used by the app.

If an update from Hitobito fails, the app can continue to use the existing local data until that retention period is exceeded.

Analytics, diagnostics and feedback data may also be retained by the respective third-party providers according to their own retention policies.

## Security

Reasonable care is taken to avoid unnecessary exposure of sensitive data.

Sensitive Hitobito-related data used by the app is stored locally in encrypted form and is deleted on logout or when the locally cached data is considered too old by the app.

## Your choices

You can:

- disable analytics in the app settings
- withdraw consent to the nationwide statistics in the app settings
- stop using the app at any time
- uninstall the app from your device

## Changes

This privacy policy may be updated if app behavior or third-party services change.

Effective date: 2026-04-06

## Contact

If you have questions about privacy or data processing in the app, contact:

- [dev@jannecklange.de](mailto:dev@jannecklange.de)
