#!/bin/bash

mkdir .msbuild || exit 1
cd .msbuild || exit

wget https://download.mono-project.com/repo/ubuntu/pool/main/m/msbuild/msbuild_16.10.1+xamarinxplat.2021.05.26.14.00-0xamarin2+ubuntu2004b1_all.deb || exit 1
7z x msbuild_16.10.1+xamarinxplat.2021.05.26.14.00-0xamarin2+ubuntu2004b1_all.deb || exit 1
tar xf data.tar || exit 1

rm msbuild_16.10.1+xamarinxplat.2021.05.26.14.00-0xamarin2+ubuntu2004b1_all.deb data.tar

