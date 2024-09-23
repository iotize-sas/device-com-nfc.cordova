# [3.8.0](https://github.com/iotize-sas/device-com-nfc.cordova/compare/v3.6.1...v3.8.0) (2024-09-23)


### Features

* added nfc tag discovered event triggered at startup d076427



## [3.6.1](https://github.com/iotize-sas/device-com-nfc.cordova/compare/v3.5.0...v3.6.1) (2024-08-27)


### Features

* added configurable last tech name 165d9c1
* added message queue for send aa91bab
* added raw NFC connect ec6e911



# [3.5.0](https://github.com/iotize-sas/device-com-nfc.cordova/compare/v3.2.3...v3.5.0) (2024-04-30)


### Features

* added `parseTapNdefMessage()` and `parseTapNdefMessages()` and trigger tag discover systematically and added ndefMessage info if available 9556164


## [3.4.1](https://github.com/iotize-sas/device-com-nfc.cordova/compare/v3.2.3...v3.4.1) (2024-03-19)


### Features

* added `setTapDeviceDiscoveryEnabled` and improved `transceive` to connect to NFC tag automatically if not connected 8d28dcd
* added transceive raw data on android cf30f43



# [3.3.0](https://github.com/iotize-sas/device-com-nfc.cordova/compare/v3.2.3...v3.3.0) (2023-11-21)



## [3.2.2](https://github.com/iotize-sas/device-com-nfc.cordova/compare/v3.2.1...v3.2.2) (2023-08-31)


### Bug Fixes

* catch `SecurityException` fatal error when Tag is out of date on Android 372e386



## [3.2.1](https://github.com/iotize-sas/device-com-nfc.cordova/compare/v3.2.0...v3.2.1) (2023-02-20)



# [3.2.0](https://github.com/iotize-sas/device-com-nfc.cordova/compare/v3.1.6...v3.2.0) (2022-11-23)



## [3.1.4](https://github.com/iotize-sas/device-com-nfc.cordova/compare/v3.1.3...v3.1.4) (2022-03-22)


### Bug Fixes

* added gradle option allowInsecureProtocol = true 4007542



## [3.1.3](https://github.com/iotize-sas/device-com-nfc.cordova/compare/v3.1.0...v3.1.3) (2021-12-27)

### BREAKING CHANGE:

- renamed cordova id from iotize-device-com-nfc to @iotize/device-com-nfc.cordova

### Bug Fixes

- fix nfc Tap discovered twice leading to communication error ab55018

<a name="3.0.0"></a>

# [3.0.0](https://github.com/iotize-sas/device-com-nfc.cordova/compare/v1.0.0-alpha.9...v3.0.0) (2021-02-19)

### Bug Fixes

- add bridging header, return in guards and rename ([27d2104](https://github.com/iotize-sas/device-com-nfc.cordova/commit/27d2104))
- cannot find xcode and unable to graft xml errors in android install-build ([7011035](https://github.com/iotize-sas/device-com-nfc.cordova/commit/7011035))

### Features

- added nfc tap initialization in the android native part ([a4efe4d](https://github.com/iotize-sas/device-com-nfc.cordova/commit/a4efe4d))
- added NFCParingDoneToastMessage preference to customize toast message displayed to user ([67c04e6](https://github.com/iotize-sas/device-com-nfc.cordova/commit/67c04e6))

<a name="3.0.0-alpha.1"></a>

# [3.0.0-alpha.1](https://github.com/iotize-sas/device-com-nfc.cordova/compare/v1.0.0-alpha.9...v3.0.0-alpha.1) (2020-12-11)

### Bug Fixes

- add bridging header, return in guards and rename ([27d2104](https://github.com/iotize-sas/device-com-nfc.cordova/commit/27d2104))
- cannot find xcode and unable to graft xml errors in android install-build ([7011035](https://github.com/iotize-sas/device-com-nfc.cordova/commit/7011035))

### Features

- added nfc tap initialization in the android native part ([a4efe4d](https://github.com/iotize-sas/device-com-nfc.cordova/commit/a4efe4d))
- added NFCParingDoneToastMessage preference to customize toast message displayed to user ([67c04e6](https://github.com/iotize-sas/device-com-nfc.cordova/commit/67c04e6))
