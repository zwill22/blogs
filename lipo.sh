#!/bin/bash
echo "Build script for AWS-CPP-SDK-Cognito-IDP Library for iOS Combined"
if [ -n "${AWSDIR}" ]; then
	echo "AWSDIR=${AWSDIR}"
else
	echo "Please specify location of AWS-CPP-SDK using \`export AWSDIR=\"\"\`"
	exit 1;
fi

installDir=${AWSDIR}/build/install
echo "installDir=${installDir}"

cd ${installDir}
for platform in OS64 SIMULATORARM64; do
	if [ ! -d ${platform} ]; then
		echo "No install data for platform: ${platform}"
		exit 1;
	fi
done

cp -R OS64/include .
mkdir -p lib
cd lib
for file in ${installDir}/OS64/lib/*.a; do
	filename=${file##*/}
	simFile=${installDir}/SIMULATORARM64/lib/${filename}
	if [ ! -e ${simFile} ]; then
		echo "No such file: ${simFile}"
	fi
	rawFilename=${filename%.a}
	outputFile=${installDir}/lib/${rawFilename}.xcframework
	
	xcodebuild -create-xcframework -library ${file} -library ${simFile} -output ${outputFile}
done
