Hakumai
==

setup
--
````
git submodule update --init
````

note about submodules
--
* XCGLogger is general purpose logger.
* FMDB is used to query chrome's cookie store in sqlite.
* SSKeychain is used to query chrome's encrypt key stored in keychain.
* Ono is used to parse html contents, some contents are not properly parsed by `NSXMLDocument`.
