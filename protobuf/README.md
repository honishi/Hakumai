```shell
# prepare protoc
brew install swift-protobuf

# generate *.pb.swift files
protoc --proto_path=./nicolive-comment-protobuf --swift_out=../Hakumai/Models nicolive-comment-protobuf/**/*.proto
```
