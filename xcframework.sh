#!/bin/bash
echo "Build script for AWS-CPP-SDK-Cognito-IDP Library for iOS Combined"
if [ -n "${AWS_BUILD_DIR}" ]; then
	echo "AWS_BUILD_DIR=${AWS_BUILD_DIR}"
else
	echo "Please specify location of AWS-CPP-SDK build using \`export AWS_BUILD_DIR=\"\"\`"
	exit 1;
fi

installDir=${AWS_BUILD_DIR}/install
echo "installDir=${installDir}"

cd ${installDir}
platforms=( OS64 SIMULATORARM64 MAC_ARM64 )
for platform in ${platforms[@]}; do
	if [ ! -d ${platform} ]; then
		echo "No install data for platform: ${platform}"
		exit 1;
	fi
done

cp -R ${installDir}/OS64/include ${installDir}
mkdir -p lib
cd lib
for file in ${installDir}/OS64/lib/*.a; do
	filename=${file##*/}
	libraries=""
	for platform in ${platforms[@]}; do
		platformFile=${installDir}/${platform}/lib/${filename}
		if [ ! -e ${platformFile} ]; then
			echo "No such file: ${platformFile}"
		fi
		libraries="${libraries} -library ${platformFile}"
	done
	
	rawFilename=${filename%.a}
	outputFile=${installDir}/lib/${rawFilename}.xcframework
	
	xcodebuild -create-xcframework${libraries} -output ${outputFile}
	
done
