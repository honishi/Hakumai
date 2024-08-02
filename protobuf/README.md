```shell
# prepare protoc
brew install swift-protobuf

# generate *.pb.swift files
protoc --proto_path=./nicolive-comment-protobuf --swift_out=./output nicolive-comment-protobuf/**/*.proto
# -> copy output files to xcode project
```
