#!/bin/bash

export RUNDIR=${PWD}

echo "Build script for AWS-CPP-SDK-Cognito-IDP Library for iOS Combined"
if [ -n "${AWS_DIR}" ]; then
	echo "AWS_DIR=${AWS_DIR}"
else
	echo "Please specify location of AWS-CPP-SDK using \`export AWS_DIR=\"\"\`"
	exit 1;
fi
if [ ! -d ${AWS_DIR} ]; then
	>&2 echo "No such directory: ${AWS_DIR}"
	exit 1;
fi	

if [ -n "${AWS_BUILD_DIR}" ]; then
	echo "AWS_BUILD_DIR=${AWS_BUILD_DIR}"
else
	echo "Please specify build location for the AWS-CPP-SDK using \`export AWS_BUILD_DIR=\"\"\`"
	exit 1;
fi

if [ ! -d ${AWS_BUILD_DIR} ]; then
  mkdir -p ${AWS_BUILD_DIR};
fi


if [ -n "${IOS_CMAKE_DIR}" ]; then
	echo "IOS_CMAKE_DIR=${IOS_CMAKE_DIR}"
else
	echo "Please specify location of ios-cmake using \`export IOS_CMAKE_DIR=\"\"\`"
	exit 1;
fi

if [ ! -d "${IOS_CMAKE_DIR}" ]; then
	>&2 echo "No such directory: ${IOS_CMAKE_DIR}"
fi

cd ${AWS_BUILD_DIR}
export CXXFLAGS=-std=c++17
for platform in OS64 SIMULATORARM64 MAC_ARM64;
do

if [ ${platform} == MAC_ARM64 ]; then
	deploymentTarget="15.0"
else
	deploymentTarget="17.5"
fi
mkdir ${platform}
cd ${platform}

cmake ${AWS_DIR} -DCMAKE_TOOLCHAIN_FILE=${IOS_CMAKE_DIR}/ios.toolchain.cmake -DPLATFORM=${platform} -DBUILD_ONLY="cognito-idp" -G Xcode -DCMAKE_INSTALL_PREFIX=${AWS_BUILD_DIR}/install/${platform} -DUSE_CRT_HTTP_CLIENT=ON -DDEPLOYMENT_TARGET=${deploymentTarget} -DFORCE_SHARED_CRT=OFF -DBUILD_SHARED_LIBS=OFF -DCPP_STANDARD=17 -DTARGET_ARCH=apple -DHAS_MOUTLINE_ATOMICS=OFF || { (>&2 echo "CMake configuration failed for platform ${platform}") ; exit 1; }

cmake --build . --config Release || { (>&2 echo "Build failed for platform ${platform}"); exit 1; }

cmake --install . --config Release || { (>&2 echo "Installation failed for platform ${platform}"); exit 1; }

cd ..

done

cd ${RUNDIR}
