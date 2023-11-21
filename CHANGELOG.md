# 3.3.0 (2023-11-21)

### Features

- Added support for `rxjs@7`
- Removed deprecated `@ionic-native/nfc` in `peerDependencies`

## 3.2.4 (2023-08-31)

### Bug Fixes

- catch `SecurityException` fatal error when Tag is out of date on Android 372e386

## 3.2.1 (2023-02-20)

### Others

- Updated dependency `org.apache.commons:commons-collections4:4.1` to `org.apache.commons:commons-collections4:4.4`

# 3.2.0 2022-11-23)

- Added support for Android 11 (Android target sdk 31)

## 3.1.4 (2022-03-22)

### Bug Fixes

- added gradle option allowInsecureProtocol = true 4007542

## 3.1.3 (2021-12-27)

### BREAKING CHANGE:

- renamed cordova id from `iotize-device-com-nfc` to `@iotize/device-com-nfc.cordova`

### Bug Fixes

- fix nfc Tap discovered twice leading to communication error ab55018

<a name="3.1.0"></a>

# [3.1.0](https://github.com/iotize-sas/device-com-nfc.cordova/compare/v3.0.1...v3.1.0) (2021-09-30)

- Changed plugin identifier from `cordova-plugin-iotize-device-com-nfc` to `@iotize/device-com-nfc.cordova` (requires cordova >= 10)

<a name="3.0.1"></a>

# [3.0.1](https://github.com/iotize-sas/device-com-nfc.cordova/compare/v3.0.0...v3.0.1) (2021-07-21)

### Bug Fixes

- fix NFC iOS communication: sleep some time to release ST25DV for SPI

<a name="3.0.0"></a>

# [3.0.0](https://github.com/iotize-sas/device-com-nfc.cordova/compare/v1.0.0-alpha.9...v3.0.0) (2021-02-19)

### Bug Fixes

- add bridging header, return in guards and rename 27d2104
- cannot find xcode and unable to graft xml errors in android install-build 7011035

### Features

- added nfc tap initialization in the android native part a4efe4d
- added NFCParingDoneToastMessage preference to customize toast message displayed to user 67c04e6

<a name="3.0.0-alpha.1"></a>

# [3.0.0-alpha.1](https://github.com/iotize-sas/device-com-nfc.cordova/compare/v1.0.0-alpha.9...v3.0.0-alpha.1) (2020-12-11)

- Migrated to `@iotize/tap@2.0.0` APIs

<a name="1.0.0-alpha.11">1.0.0-alpha.11</a>

### Features

- Add iOS 13 beta support
- Migrate all iOS code in swift
- Removed unsupported platforms

<a name="1.0.0-alpha.9">1.0.0-alpha.9</a>

### Bug fix

- fix tag nfdef messages parsing

<a name="1.0.0-alpha.9">1.0.0-alpha.8</a>

### Features

- added tap tap ndef message parsing function

<a name="1.0.0-alpha.7">1.0.0-alpha.7</a>

Fixed use of connect when the application is automatically opened after a tap. (Stores the MIMEtype intent triggered on application launch for later use, if any)

<a name="1.0.0-alpha.1"></a>
