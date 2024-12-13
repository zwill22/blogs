#!/bin/bash
echo "Build script for AWS-CPP-SDK-Cognito-IDP Library for iOS Combined"
export ROOT_DIR=${PWD}
cd ..
export PROJECTS_DIR=${PWD}
cd ${ROOT_DIR}

echo "Root directory = ${ROOT_DIR}"
echo "Projects directory = "${PROJECTS_DIR}

mkdir build
cd build

wait 4

for platform in OS64 SIMULATORARM64;
do

mkdir ${platform}
cd ${platform}

cmake ${ROOT_DIR} -DCMAKE_TOOLCHAIN_FILE=${PROJECTS_DIR}/ios-cmake/ios.toolchain.cmake -DPLATFORM=${platform} -DBUILD_ONLY="cognito-idp" -G Ninja -DCMAKE_INSTALL_PREFIX=${ROOT_DIR}/build/install/${platform} -DDEPLOYMENT_TARGET=18.2 -DUSE_CRT_HTTP_CLIENT=ON -DAUTORUN_UNIT_TESTS=OFF -DFORCE_SHARED_CRT=OFF -DCPP_STANDARD=17 -DBUILD_SHARED_LIBS=OFF
cmake --build . --config Release --target aws-cpp-sdk-cognito-idp

cmake --install . --config Release

cd ..

done

cd ..
