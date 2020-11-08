<img src="./document/image/logo.png" width="500px">

[![Swift 5.0](https://img.shields.io/badge/Swift-5.0-orange.svg?style=flat)](https://swift.org/)
[![License MIT](https://img.shields.io/badge/License-MIT-lightgrey.svg?style=flat)](http://www.opensource.org/licenses/mit-license.php)
[![Build Status](https://github.com/honishi/Hakumai/workflows/Build%20and%20Run%20Tests/badge.svg?branch=develop)](https://github.com/honishi/Hakumai/actions)

* niconama comment viewer alternative for mac os x.
* download available at [http://honishi.github.io/Hakumai](http://honishi.github.io/Hakumai).

<img src="./document/screenshot/main.png" width="600px">

project setup
--
````
bundle install --path=vendor/bundle
bundle exec pod install
open Hakumai.xcworkspace
````

notes about dependencies
--
* `XCGLogger` is general purpose logger.
* `FMDB` is used to query chrome's cookie store in sqlite.
* `SSKeychain` is used to query chrome's encrypt key stored in keychain.
* `Ono` is used to parse html contents.
    * some contents are not properly parsed by `NSXMLDocument`.
* `Sparkle` is automatic software updater.

<!--
contribution
--
1. fork it ( http://github.com//honishi/Hakumai )
2. create your feature branch (`git checkout -b my-new-feature`)
3. commit your changes (`git commit -am 'add some feature'`)
4. push to the branch (`git push origin my-new-feature`)
5. create new pull request
-->

license
--
copyright &copy; 2015- honishi, hiroyuki onishi.

distributed under the [MIT license](http://www.opensource.org/licenses/mit-license.php).
