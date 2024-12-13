# Building and linking the AWS-SDK-CPP for iOS and simulator

I have recently been trying to create a
[new iOS app to track Bus locations in real-time](https://github.com/zwill22/BusTracker.git).
The location data is taken from the UK's [Bus Open Data Service](https://www.bus-data.dft.gov.uk).
Having managed to get the prototype app to load some bus data directly from this service,
I decided to use an
[AWS API Gateway](https://docs.aws.amazon.com/apigateway/latest/developerguide/welcome.html) 
as the access point to the API. At some point I will write a guide to setting this up as it took me a while to figure it out.
I then setup a
[Cognito Identity Pool](https://docs.aws.amazon.com/apigateway/latest/developerguide/apigateway-integrate-with-cognito.html)
to control access to the API.
Now my app needs to request access codes from here which can then be used to call the main API.
My initial thought to implement this was to use the [AWS-SDK-Swift](https://aws.amazon.com/sdk-for-swift/)
to manage access. This seems like the obvious method.

Firstly, I am not a seasoned Swift developer and this is my first app, and secondly, the Swift SDK does not appear to be the
most developed of the AWS-SDKs and the documentation is lacking. I perservered and eventually I was trying to use the documentation
for the other SDKs to find what I needed in the Swift one. Eventually, I decided to use the
[AWS-SDK-CPP](https://aws.amazon.com/developer/language/cpp).
I have a background in C++ development and thought that Swift and C++ interoperability was easy to achieve.

## AWS-SDK-CPP for MacOS

My first port of call for this was `conda install aws-sdk-cpp -c conda-forge`,
unfortunately this build does not include the `cognito-idp` module which is needed to authenticate users
using cognito. It does provide a `cognito-identity` module but this seems to be more for managing user pools
rather than using them. To download AWS-SDK-CPP (with its submodules) I used:
```
git clone --recurse-submodules https://github.com/aws/aws-sdk-cpp
```
However, as this is quite a large repository even this has failed for me.
To avoid such a large download, an alternative is:
```
git clone https://github.com/aws/aws-sdk-cpp --depth 1
cd aws-sdk-cpp
git submodule update --init --recursive --depth 1  
```
From inside the `aws-sdk-cpp` directory build and install with:
```
cmake . -DBUILD_ONLY="cognito-idp"
cmake --build . --config=Release
cmake --build . --target install
```
I thought this was the hard part.

## The OpenID module

So, I have my [BusTracker app](https://github.com/zwill22/BusTracker.git) and the AWS-SDK-CPP installed on my Mac.
I decided to write the interface to AWS-SDK-CPP as its own library,
which after many name changes is now the [OpenID](https://github.com/zwill22/OpenID.git) library.
The original aim behind this was to be able to import it into the BusTracker app without having to worry about
including the AWS-SDK-CPP library directly.

This library is pure C++ but I also provide an optional C header which is built using:
```
cmake . -DC_INTERFACE=ON
cmake --build .
```
After completing this library I needed to include it in the BusTracker app - simple? NO!

## Building CMake libraries for iOS and simulator

I expected this to be a flag in cmake but no such luck. Firstly, after much research and head-scratching, I found that
a toolchain file is helpful in this situation. For this I found the
[iOS-CMake Library](https://github.com/leetal/ios-cmake.git)
which is a fork of an earlier library of the same name. This library recommends building using
```
cmake -B build -G Xcode -DCMAKE_TOOLCHAIN_FILE=${IOSCMAKE_DIR}/ios.toolchain.cmake -DPLATFORM=${PLATFORM}
cmake --build build --config Release
```
where `${PLATFORM}` may be one of a number of Apple Platforms.
As I am using an Apple Silicon Mac, the relevent options for me are:
- OS64 - to build for iOS (arm64 only)
- SIMULATORARM64 - to build for iOS simulator 64 bit (arm64)
- VISIONOS - to build for visionOS (arm64) -- Apple Silicon Required
- SIMULATOR_VISIONOS - to build for visionOS Simulator (arm64) -- Apple Silicon Required
- TVOS - to build for tvOS (arm64)
- SIMULATORARM64_TVOS = to build for tvOS Simulator (arm64)
- WATCHOS - to build for watchOS (armv7k, arm64_32)
- SIMULATORARM64_WATCHOS = to build for watchOS Simulator (arm64)
- MAC_ARM64 - to build for macOS on Apple Silicon (arm64)
- MAC_CATALYST_ARM64 - to build iOS for Mac on Apple Silicon (Catalyst, arm64)

However, the library also provides the following options:
- OS64COMBINED - to build for iOS & iOS Simulator (FAT lib) (arm64, x86_64)
- VISIONOSCOMBINED - to build for visionOS & visionOS Simulator (FAT lib) (arm64) -- Apple Silicon Required
- TVOSCOMBINED - to build for tvOS & tvOS Simulator (arm64, x86_64)
- WATCHOSCOMBINED - to build for watchOS & Simulator (armv7k, arm64_32, i386)

These options build FAT libraries which combine the libraries for the device and the simulator into a single
library. These must be built using the `Xcode` generator and must be installed using `cmake --install . --config Release`. I attempted to build the `OS64COMBINED` library for AWS-SDK-CPP without success. Instead, I recommend building the libraries separately and using the `Ninja` generator rather than `Xcode`.

## Building AWS-SDK-CPP for iOS and Simulator

Following that generic discussion on building libraries for iOS and simulator, you may think that the hard-work is done. In fact, there are a number of other issues when compiling AWS-SDK-CPP for iOS. The full cmake configure command that I used in the end was:
```
cmake ${AWS_DIR} -DCMAKE_TOOLCHAIN_FILE=${IOSCMAKE_DIR}/ios.toolchain.cmake -DPLATFORM=${PLATFORM} -DBUILD_ONLY="cognito-idp" -G Ninja -DCMAKE_INSTALL_PREFIX=${AWS_INSTALL_PREFIX}/${PLATFORM} -DDEPLOYMENT_TARGET=18.2 -DUSE_CRT_HTTP_CLIENT=ON -DAUTORUN_UNIT_TESTS=OFF -DFORCE_SHARED_CRT=OFF -DCPP_STANDARD=17 -DBUILD_SHARED_LIBS=OFF
```
Unpacking these, the first four should be obvious from above. I personally built the library for the
`OS64` and `SIMULATORARM64` platforms, using the latest deployment target, and disabled unit tests.
I wanted to build the static version of the library so set `BUILD_SHARED_LIBS=OFF` and `FORCE_SHARED_CRT=OFF`. Additionally, the option `USE_CRT_HTTP_CLIENT=ON` is necessary to avoid a
dependence on `libcurl` and, by extension `libssl`. 

Running the standard build command after this will lead to an error. Fortunately this error occurs
when the library `aws-sdk-cpp-cognito-idp-gen-tests` is built. Instead, running
```
cmake --build . --config Release --target aws-cpp-sdk-cognito-idp
cmake --install . --config Release
```
builds the required libraries in directory `${AWS_INSTALL_PREFIX}/${PLATFORM}`. Doing this for both 
platforms should not present a problem.

## Building OpenID for iOS and simulator

Having built the `cognito-idp` for AWS-SDK-CPP two steps remain:
- Building OpenID for iOS and Simulator
- Including the library in BusTracker

Building OpenID is relatively simple, a
[`CMakePresets.json`](https://github.com/zwill22/OpenID/blob/main/CMakePresets.json)
file is included the [OpenID repository](https://github.com/zwill22/OpenID.git)
with configurations `iOSBuild` and `iOSSimulatorBuild`. However, the complete `cmake` configure
commands is
```
cmake . -DCMAKE_TOOLCHAIN_FILE=${IOSCMAKE_DIR}/ios.toolchain.cmake -DPLATFORM=${PLATFORM} -G Ninja -DCMAKE_INSTALL_PREFIX=${OPENID_INSTALL_PREFIX}/${PLATFORM} -DDEPLOYMENT_TARGET=18.2 -DAWSSDK_ROOT_DIR=${AWS_INSTALL_PREFIX}/${PLATFORM} -DC_INTERFACE=ON -DUSE_CATCH=OFF -DBUILD_SHARED_LIBS=OFF
```
where `${AWS_INSTALL_PREFIX}/${PLATFORM}` is the location where the AWS-SDK-CPP library for the 
respective platform was installed. 

## Including the libraries in BusTracker

If OpenID built correctly, there should be two static library files for each platform, `libOpenID.a`
contains the full OpenID C++ library and `libOpenIDC.a` includes the C interface functions. Having built
these, all that remains is to include these in Xcode.