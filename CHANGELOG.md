# Changelog

## [1.8.0](https://github.com/daniele-athome/airborne/compare/v1.7.0...v1.8.0) (2025-10-27)


### Features

* bold pilot name text in confirmation dialog ([8fd99c2](https://github.com/daniele-athome/airborne/commit/8fd99c2277fafe59ea4ba784fc4f164353f0a6b1))
* visible password toggle in onboarding screen ([5d2adfe](https://github.com/daniele-athome/airborne/commit/5d2adfe4b31ead28d5106fe5965453caa0dd47ec)), closes [#104](https://github.com/daniele-athome/airborne/issues/104)

## [1.7.0](https://github.com/daniele-athome/airborne/compare/v1.6.0...v1.7.0) (2025-10-15)


### Features

* **flight-log:** preview total flight time in editor ([5a68c05](https://github.com/daniele-athome/airborne/commit/5a68c05032f0748ab36568b307aa3f36489cf900)), closes [#98](https://github.com/daniele-athome/airborne/issues/98)


### Bug Fixes

* correctly handle actual network timeouts ([73b74f1](https://github.com/daniele-athome/airborne/commit/73b74f1fc39b36dfb97270f8fe0f7c3bb0c03627)), closes [#105](https://github.com/daniele-athome/airborne/issues/105)
* do not use invalid data after logout ([8536ba1](https://github.com/daniele-athome/airborne/commit/8536ba112993cda5346013d6605f70904622ef07))
* fix retry button text color ([348f373](https://github.com/daniele-athome/airborne/commit/348f373487894f08cf6015832d404e0fe6027148)), closes [#102](https://github.com/daniele-athome/airborne/issues/102)
* **onboarding:** fix keyboard hints ([5fe03cc](https://github.com/daniele-athome/airborne/commit/5fe03cc9420e7674a774457950ae6dc552887922))

## [1.6.0](https://github.com/daniele-athome/airborne/compare/v1.5.0...v1.6.0) (2025-09-08)


### Features

* **about:** link to documents archive ([7913e9d](https://github.com/daniele-athome/airborne/commit/7913e9dd0366a4bdaf675903f47a83867b18ab3a)), closes [#82](https://github.com/daniele-athome/airborne/issues/82)
* **activities:** support for last status change date ([e0d29ae](https://github.com/daniele-athome/airborne/commit/e0d29ae116dbe38d277db244c3d4dc9b2716e094))
* aircraft data file creation tool ([5ed1ef5](https://github.com/daniele-athome/airborne/commit/5ed1ef5435ce2d24ca416174a5277a454e967a31)), closes [#31](https://github.com/daniele-athome/airborne/issues/31)
* better date/time pickers on iOS ([e29dcef](https://github.com/daniele-athome/airborne/commit/e29dcef73bea5f8acbd20cccbc6ecf4a95fafe1a)), closes [#47](https://github.com/daniele-athome/airborne/issues/47)
* **book-flight:** warn when trying to book a flight in the past ([f0a9283](https://github.com/daniele-athome/airborne/commit/f0a92833e746890251fb36d33aa03752e5c6db0e)), closes [#69](https://github.com/daniele-athome/airborne/issues/69)
* Material 3 theme ([48268c8](https://github.com/daniele-athome/airborne/commit/48268c893cd2341cfd96e097c92e94f7d051a0ef)), closes [#86](https://github.com/daniele-athome/airborne/issues/86)
* metadata key-value store and flight log hash check (close [#79](https://github.com/daniele-athome/airborne/issues/79)) ([3df9b5b](https://github.com/daniele-athome/airborne/commit/3df9b5b690f61105b0a008647ba4b558865a2e1f))
* modernize iOS user interface ([c42186a](https://github.com/daniele-athome/airborne/commit/c42186a0db6f127c791d2fd75b46dc5358f57974))
* support for encrypted aircraft data files ([9c0d69d](https://github.com/daniele-athome/airborne/commit/9c0d69dfc62730bc8ad8c1a506df6baa67049ad4)), closes [#83](https://github.com/daniele-athome/airborne/issues/83)


### Bug Fixes

* **aircraft-tool:** fix aircraft photo layout issue ([942c765](https://github.com/daniele-athome/airborne/commit/942c7650ab26ad206361307bb4f9e971b7546185))
* correctly handle RTL locales ([97b8a04](https://github.com/daniele-athome/airborne/commit/97b8a04362956e3a9304a5efbf3175f7e789b11e))
* fix progress dialog background and size issues ([373069d](https://github.com/daniele-athome/airborne/commit/373069da1ff5277f9754e1db16944cb7469f2dff))
* **flight-log:** fix autorefresh on resume ([a018334](https://github.com/daniele-athome/airborne/commit/a01833447452af7a5bd843e2f5f8dc545a19fe97))
* **flight-log:** fix hour meter sizing issues ([d275649](https://github.com/daniele-athome/airborne/commit/d2756491c6a1fd50226f1a18fb244064606abe15))
* **flight-log:** fix hour meter sizing issues ([c1b5dff](https://github.com/daniele-athome/airborne/commit/c1b5dff2b4efb6d53d058b6684444f1df80a2a9c))

## [1.5.0](https://github.com/daniele-athome/airborne/compare/v1.4.0...v1.5.0) (2023-08-15)


### Features

* **flight-log:** drop support for pre-configured fuel prices ([aa8482d](https://github.com/daniele-athome/airborne/commit/aa8482dc1d6b3ad2f6ca4c8b76df024a7ff1899f))


### Bug Fixes

* **flight-log:** force reload of log book on resume ([6043320](https://github.com/daniele-athome/airborne/commit/60433208378373983ac74f47ac39def03cf8267b)), closes [#74](https://github.com/daniele-athome/airborne/issues/74)
* **flight-log:** validate fuel quantity if price is entered ([10473f4](https://github.com/daniele-athome/airborne/commit/10473f48accc3eb05cd1a586a98504aca7bc462a)), closes [#76](https://github.com/daniele-athome/airborne/issues/76)
* wait properly for avatar cache to be evicted ([c5d6b2a](https://github.com/daniele-athome/airborne/commit/c5d6b2ad217fdbe613193036edd2fbea57719244)), closes [#73](https://github.com/daniele-athome/airborne/issues/73)

## [1.4.0](https://github.com/daniele-athome/airborne/compare/v1.3.0...v1.4.0) (2023-06-23)


### Features

* **activities:** show expire indicator ([ec5a903](https://github.com/daniele-athome/airborne/commit/ec5a903e3143f0daf2bc3c3947fbb008676d6bd4)), closes [#30](https://github.com/daniele-athome/airborne/issues/30)
* **book-flight:** show relative day name next to selected date ([df6fea8](https://github.com/daniele-athome/airborne/commit/df6fea8619311129817e0b57790a83c1d9de7788)), closes [#67](https://github.com/daniele-athome/airborne/issues/67)
* weather reporting links ([3866c17](https://github.com/daniele-athome/airborne/commit/3866c17b51f5c5d1b5556fdbb7da20f09f808cda)), closes [#70](https://github.com/daniele-athome/airborne/issues/70)


### Bug Fixes

* allow extra properties in aircraft JSON ([8f52f94](https://github.com/daniele-athome/airborne/commit/8f52f94e82a9b1e72b3ee564e97e3db0a45b7ae3))
* correct Cupertino scaffolding color ([01b4f27](https://github.com/daniele-athome/airborne/commit/01b4f27aef89402047858db1e1626ae6f258092e))

## [1.3.0](https://github.com/daniele-athome/airborne/compare/v1.2.0...v1.3.0) (2022-08-13)


### Features

* colorize bottom navigation bar ([b23b437](https://github.com/daniele-athome/airborne/commit/b23b437cfe1dbf3cd3bd4fee4f79609c7f66ed24))
* **flight-log:** input total fuel cost instead of unit price ([305dd63](https://github.com/daniele-athome/airborne/commit/305dd63fda15532031a0fe27dd1c5d3c2c62216f)), closes [#66](https://github.com/daniele-athome/airborne/issues/66)
* read-only activity journal ([5b42298](https://github.com/daniele-athome/airborne/commit/5b42298841e432105e6a92081daa2af409a3c9df)), closes [#30](https://github.com/daniele-athome/airborne/issues/30)


### Bug Fixes

* **about:** update pilots list after updating aircraft data ([ab31a81](https://github.com/daniele-athome/airborne/commit/ab31a81f33e4cc2dfd819bad8b3c900f356c85cc)), closes [#62](https://github.com/daniele-athome/airborne/issues/62)
* handle events spanning multiple weeks ([ee085a4](https://github.com/daniele-athome/airborne/commit/ee085a4b0edce57307b24ea897cd071ab77a0baa)), closes [#15](https://github.com/daniele-athome/airborne/issues/15)

## [1.2.0](https://github.com/daniele-athome/airborne/compare/v1.1.0...v1.2.0) (2022-04-13)


### Features

* **flight-log:** custom fuel price ([cc5d57b](https://github.com/daniele-athome/airborne/commit/cc5d57b22e15b34a9b4748f4d92d49f1713ef528)), closes [#55](https://github.com/daniele-athome/airborne/issues/55)

## [1.1.0](https://github.com/daniele-athome/airborne/compare/v1.0.0...v1.1.0) (2022-02-19)


### Features

* **onboarding:** even more strict validation of aircraft data ([4fdb7e0](https://github.com/daniele-athome/airborne/commit/4fdb7e01c869d1a99e6b9e27f7104a49f1a1e211)), closes [#49](https://github.com/daniele-athome/airborne/issues/49)


### Bug Fixes

* allow for decimals in keyboard for fuel quantity ([19ac7c3](https://github.com/daniele-athome/airborne/commit/19ac7c3111f6eb0d9c2f8e0195fe9391782c0645))
* location attributes in JSON schema should be mandatory ([0e3e810](https://github.com/daniele-athome/airborne/commit/0e3e810e112627fba5f958ed0109df6fee8dfa4a))

## 1.0.0 (2022-01-29)

First stable version!!
