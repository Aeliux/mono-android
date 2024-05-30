#!/bin/bash

# firstly run these commands
# apt install -y wget perl python3 cmake unzip git ninja-build g++ p7zip-full ca-certificates gnupg

# sudo gpg --homedir /tmp --no-default-keyring --keyring /usr/share/keyrings/mono-official-archive-keyring.gpg --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys 3FA7E0328081BFF6A14DA29AA6A19B38D3D831EF
# echo "deb [signed-by=/usr/share/keyrings/mono-official-archive-keyring.gpg] https://download.mono-project.com/repo/ubuntu stable-focal main" | sudo tee /etc/apt/sources.list.d/mono-official-stable.list
# sudo apt update
# sudo apt install -y mono-devel

mkdir -p .ndk
mkdir -p .msbuild

pushd .ndk
wget https://dl.google.com/android/repository/android-ndk-r22-linux-x86_64.zip
unzip android-ndk-r22-linux-x86_64.zip
rm android-ndk-r22-linux-x86_64.zip
popd

pushd .msbuild
wget https://download.mono-project.com/repo/ubuntu/pool/main/m/msbuild/msbuild_16.10.1+xamarinxplat.2021.05.26.14.00-0xamarin2+ubuntu2004b1_all.deb
7z x msbuild_16.10.1+xamarinxplat.2021.05.26.14.00-0xamarin2+ubuntu2004b1_all.deb
tar xf data.tar
rm msbuild_16.10.1+xamarinxplat.2021.05.26.14.00-0xamarin2+ubuntu2004b1_all.deb data.tar
popd


