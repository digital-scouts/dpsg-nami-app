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

## Feedback

The app integrates a feedback service so users can send feedback from within the app. If this feature is used, the information entered by the user is transmitted to that service.

## Location and address features

The app itself does not continuously collect precise location data for analytics purposes.

For address-related features, user input may be sent to an external geocoding service to retrieve address suggestions. This happens only when the corresponding feature is used.

For member detail maps and the map around the saved Stamm address, postal address data may also be sent to Geoapify to geocode the address. The app stores resulting coordinates locally on the device to reduce repeated requests. If no sufficiently precise address match can be determined, the app may also store a local "address not found" cache state for that address input to avoid repeated geocoding requests. Map tiles may additionally be cached locally for offline use and may be delivered via a configured tile provider such as MapTiler, with an OpenStreetMap-based fallback used if no explicit tile URL is configured.

TODO: Before broader rollout of map features, refine this section and the in-app first-start notice with a more explicit consent flow for Privacy Policy acknowledgement.

## Third-party services

The app currently uses third-party services such as:

- Wiredash for feedback and event tracking
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
- stop using the app at any time
- uninstall the app from your device

## Changes

This privacy policy may be updated if app behavior or third-party services change.

Effective date: 2026-04-06

## Contact

If you have questions about privacy or data processing in the app, contact:

- [dev@jannecklange.de](mailto:dev@jannecklange.de)
