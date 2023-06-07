# SkywaySample

[Skyway SDK](https://skyway.ntt.com/ja/docs/)を用いた通話実装のサンプル

# Requirement

* ruby 3.1.2 or later

# Installation

* install bundle
```bash
    $ gem install bundler
    $ bundle config set --local path vendor/bundle
    $ bundle install
```

* update CocoaPods repo
```bash
    $ bundle exec pod repo add skyway-ios-sdk-specs https://github.com/skyway/skyway-ios-sdk-specs.git
    $ bundle exec pod repo add skyway-ios-webrtc-specs https://github.com/skyway/skyway-ios-webrtc-specs.git
    $ bundle exec pod repo update
```

* install dependencies
```bash
    $ bundle exec pod install
```

# Usage

* Skyway で発行したトークンをセットする([参考](https://skyway.ntt.com/ja/docs/user-guide/authentication/))
```swift
final class SkywayConnectionManager {
    private static let token = ""
```

# License

[License](https://github.com/shuheyheyhey/SampleSkyway/blob/main/LICENSE)
