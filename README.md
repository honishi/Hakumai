Hakumai
==
niconama comment viewer alternative for mac os x.

<img src="./document/screenshot/main.png" width="525px">

project setup
--
````
git submodule update --init
open Hakumai.xcodeproj
````

note about submodules
--
* XCGLogger is general purpose logger.
* FMDB is used to query chrome's cookie store in sqlite.
* SSKeychain is used to query chrome's encrypt key stored in keychain.
* Ono is used to parse html contents, some contents are not properly parsed by `NSXMLDocument`.

license
--
copyright &copy; 2015- honishi, hiroyuki onishi.

distributed under the [MIT license][mit].
[mit]: http://www.opensource.org/licenses/mit-license.php
