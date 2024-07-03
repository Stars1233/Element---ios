# Installation

## Install build tools

To build Element iOS project you need:

- Xcode 11.4+.
- [Ruby](https://www.ruby-lang.org/), a dynamic programming language used by several build tools.
- [cmake](https://gitlab.kitware.com/cmake/cmake), used to build [cmark](https://github.com/commonmark/cmark) dependency of [MatrixKit](https://github.com/matrix-org/matrix-ios-kit) pod.
- [CocoaPods](https://cocoapods.org) 1.9.3. Manages library dependencies for Xcode projects.
- [Homebrew](http://brew.sh/) (recommended), is a package manager for macOS that can be used to install cmake.
- [bundler](https://bundler.io/) (optional), is also a dependency manager used to manage build tools dependency (CocoaPods, Fastlane).

### Install Ruby

Ruby is required for several build tools like CocoaPods, bundler and fastlane. Ruby is preinstalled on macOS, the system version is sufficient to build the porject tools, it's not required to install the latest version. If you want to install the lastest version of Ruby please check [official instructions](https://www.ruby-lang.org/en/documentation/installation/#homebrew).

If you do not want to grant the ruby package manager, [RubyGems](https://rubygems.org/), admin privileges and you prefer install gems into your user directory, you can read instructions from the CocoaPods [guide about sudo-less installation](https://guides.cocoapods.org/using/getting-started.html#sudo-less-installation).

### Install cmake

There are several ways to install cmake, downloading binary from [official website](https://cmake.org/download/) or using a package manager like [MacPorts](https://ports.macports.org/port/cmake/summary) or [Homebrew](http://brew.sh/).
To keep it up to date, we recommend you to install cmake using [Homebrew](http://brew.sh/):

```
brew install cmake
```

### Install CocoaPods

To install CocoaPods you can grab the right version by using `bundler` (recommended) or you can directly install it with RubyGems:

```
gem install cocoapods
```

In the last case please ensure that you are using the same version as indicated at the end of the `Podfile.lock` file.

### Install bundler (optional)

By using `bundler` you will ensure to use the right versions of build tools used to build and deliver the project. You can find dependency definitions in the `Gemfile`. To install `bundler`:

```
gem install bundler
```

## Choose Matrix SDKs version to build

To choose the [MatrixKit](https://github.com/matrix-org/matrix-ios-kit) version (and depending MatrixSDK and OLMKit) you want to develop and build against you will have to modify the right definitions of `$matrixKitVersion` variable in the `Podfile`. 

### Determine your needs

To select which `$matrixKitVersion` value to use you have to determine your needs:

- **Build an App Store release version**

To build the last published App Store code you just need to checkout master branch. If you want to build an older App Store version just checkout the tag of the corresponding version. You have nothing to modify in the `Podfile`. In this case `$matrixKitVersion` will be set to a specific version of the MatrixKit already published on CocoaPods repository.

- **Build last development code and modify Element project only**

If you want to build last development code you have to checkout the develop branch and use `$matrixKitVersion = {'develop' => 'develop'}` in the `Podfile`. This will also use MatrixKit and MatrixSDK develop branches.

- **Build specific branch of Kit and SDK and modify Element project only**

If you want to build a specific branch for the MatrixKit and the MatrixSDK you have to indicate them using a dictionary like this: `$matrixKitVersion = {'kit branch name' => 'sdk branch name'}`.

- **Build any branch and be able to modify MatrixKit and MatrixSDK locally**

If you want to modify MatrixKit and/or MatrixSDK locally and see the result in Element project you have to uncommment `$matrixKitVersion = :local` in the `Podfile`.
But before you have to checkout [MatrixKit](https://github.com/matrix-org/matrix-ios-kit) repository in `../matrix-ios-kit` and [MatrixSDK](https://github.com/matrix-org/matrix-ios-sdk) in `../matrix-ios-sdk` locally relatively to your Element iOS project folder.
Be sure to use compatible branches for Element iOS, MatrixKit and MatrixSDK. For example if you want to modify Element iOS from develop branch use MatrixKit and MatrixSDK develop branches and then make your modifications.

**Important**: By working with local pods (development pods) you will need to use legacy build system in Xcode, to have your local changes taken into account. To enable it go to Xcode menu and select `File > Workspace Settings… > Build System` and then choose `Legacy Build System`.

### Modify `$matrixKitVersion` after installation of dependencies

Assuming you have already completed the **Install dependencies** instructions from **Build** section below.

Each time you edit `$matrixKitVersion` variable in the `Podfile` you will have to run the `pod install` command.

## Build

### Install dependencies

Before opening the Element Xcode workspace, you need to install dependencies via CocoaPods.

To be sure to use the right CocoaPods version you can use `bundler`:

```
$ cd Riot
$ bundle install
$ bundle exec pod install
```

Or if you prefer to use directly CocoaPods:

```
$ cd Riot
$ pod install
```

This will load all dependencies for the Element source code, including [MatrixKit](https://github.com/matrix-org/matrix-ios-kit) 
and [MatrixSDK](https://github.com/matrix-org/matrix-ios-sdk). 

### Open workspace

Then, open `Riot.xcworkspace` with Xcode.

```
$ open Riot.xcworkspace
```

**Note**: If you have multiple Xcode versions installed don't forget to use the right version of Command Line Tools when you are building the app. To check the Command Line Tools version go to `Xcode > Preferences > Locations > Command Line Tools` and check that the displayed version match your Xcode version.

### Configure project

You may need to change the bundle identifier and app group identifier to be unique to get Xcode to build the app. Make sure to change the bundle identifier,  application group identifier and app name in the `Config/Common.xcconfig` file to your new identifiers.

## Generate IPA

To build the IPA we are currently using [fastlane](https://fastlane.tools/).

**Set your project informations**

Before making the release you need to modify the `fastlane/.env.default` file and set all your project informations like your App ID, Team ID, certificate names and so on.

**Install or update build tools**

The preferred way to use the fastlane script is to use `bundler`, to be sure to use the right dependency versions.

After opening the terminal in the project root folder. The first time you perform a release you need to run:

`bundle install`

For other times:

`bundle update`

**Run fastlane script**

Before executing the release command you need to export your Apple ID in environment variables:

`export APPLE_ID="foo.bar@apple.com"`

To make an App Store release you can directly execute this command:

`bundle exec fastlane app_store build_number:<your_build_number>`

Or you can use the wrapper script located at `/Tools/Release/buildRelease.sh`. For that go to the `Release` folder: 

`$ cd ./Tools/Release/`

And then indicate a branch or a tag like this:

`$ ./buildRelease.sh <tag or branch>`


