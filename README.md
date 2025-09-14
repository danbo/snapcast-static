# snapcast-static

## Purpose:
- Create stand alone binaries of snapclient or snapserver that can be dropped on any linux system matching the build target architecture
- Support binaries for other architectures such as arm v7, not just amd64

## Tests platforms:
- linux-amd64
- linux-armhf / linux-arm-v7 (ie some raspberry pi's like pi 2 and some routers)

## Usage:
1. Ensure docker (or Docker desktop is installed) is installed (tested with Docker linux version 28.4.0)
2. Clone this repo: ```git clone https://github.com:danbo/snapcast-static.git```
3. Edit / configure ./build.sh - specify your $PLATFORM and update snap versions if necessary.
4. Execute ./build.sh
5. Get a coffee
6. You will find the binaries and other artifacts in in ./dist-linux-(platform_name):

    | artifact | description |
    |---|---|
    | snapclient | The snapcast client binary |
    | snapserver | The snapcast server binary |
    | snapweb | The snapweb ui to be used with the snapserver configuration file and binary |
    | snapserver.conf | A sample snapserver configuration file |    
  
7. Depending on your use case, copy the snapclient binary or the other 3 snapserver artifacts to your target system and execute (setting them up or having start scripts is system dependant and out of scope)

    > NOTE: in the snapserver.conf - you can specify where it should look for the snapweb artifact folder: ```doc_root = /usr/share/snapserver/snapweb```

8. After the build completes, a slim alpine ready to go docker image remains to use snapserver in dockerized setups for the target architecture. A sample ```docker-compose.yml``` is included. If you do not need it, you can remove it via ```docker rmi danbo/snapserver:v0.32.3_web-v0.9.1```. If you do need 


## How it works:

1. A new docker builder is created per platform to perform builds per best practices and isolation for cleanup later.
2. Docker creates two containers to create the final image - one for snapcast, one for snapweb and executes the builds in parallel
3. Once the builds are complete, docker creates the final slim alpine image which only contains the OS, binaries, ui assets and configuration file (which can be mounted/replaced). You can see in the ``` deployment_image``` stage no dependencies are installed to run the binaries.
4. The builder and intermediary build layers are removed
5. Docker is asked to copy the artifacts out of the produced image into dist subfolder: ./dist-linux-(platform_name)

## Notes:

1. When invoking the build, Docker is told which platform to build for and actually on - it uses QEMU under the hood to emulate that platform. Due to this emulation, builds can take longer for the target platform. Be aware that if you produce binaries for say arm v7, you have to test them on that platform, they won't execute on amd64 for a quick test.

2. for snapweb, debian is used instead of alpine because one of its build tools - swc does not have bindings for musl for some architectures like armv7. Also, node doesn't seem to have a debian 13 / trixie arm7 variant so we are using debian 12 / bookworm.  Theoretically, snapweb doesn't need to be compiled within the target architecture but it was easier execute both build stages under the same platform and builder.

3. A new / separate docker builder is created per platform as per best practices to do the build. Once completed, it purged.

4. Once the slim image with the artifacts is created, a temporary container is created to copy them out and then removed. The final docker image remains in case required and needs to be removed manually if it is not needed.

5. Some snapclient / snapserver dependencies are leveraged from alpine as it already has static builds for them, ie soxr, avahi, but some are compiled from scratch, mainly the audio codecs so that the latest or new versions can be set in the Dockerfile if necessary. Two other dependent libraries had to be statically compiled - alsa-lib and dbus (dbus for avahi)

6. Snapclient and Snapserver are compiled with the current defaults as described in their [v0.32.3 build.md](https://github.com/badaix/snapcast/blob/v0.32.3/doc/build.md), though I specify some explicitly in case you want to tune them, ie not build / include avahi:
    ```
    -DBUILD_CLIENT=<ON|OFF>: build the client: yes or no (default ON)
    -DBUILD_SERVER=<ON|OFF>: build the server: yes or no (default ON)
    -DBUILD_WITH_SSL=<ON|OFF>: build server and client with TLS support: yes or no (default ON)
    -DBUILD_WITH_FLAC=<ON|OFF>: build with FLAC support: yes or no (default ON)
    -DBUILD_WITH_VORBIS=<ON|OFF>: build with VORBIS support: yes or no (default ON)
    -DBUILD_WITH_TREMOR=<ON|OFF>: build with vorbis using TREMOR: yes or no (default ON)
    -DBUILD_WITH_OPUS=<ON|OFF>: build with OPUS support: yes or no (default ON)
    -DBUILD_WITH_AVAHI=<ON|OFF>: build with AVAHI support: yes or no (default ON)
    -DBUILD_WITH_EXPAT=<ON|OFF>: build with EXPAT support: yes or no (default ON)
    -DBUILD_WITH_PULSE=<ON|OFF>: build client with PulseAudio support: yes or no (default OFF)
    -DBUILD_WITH_JACK=<ON|OFF>: build with JACK support: yes or no (default OFF)
    ```
## Credits:

1. [@badaix](https://www.github.com/badaix) (and team) - thank you for creating such an amazing tool!

2. My original containerized build inspiration came from [@Saiyato](https://www.github.com/Saiyato)'s [snapserver_docker repo](https://github.com/Saiyato/snapserver_docker.git)

3. Static building inspiration came from [@wader](https://www.github.com/wader)'s [static-ffmpeg repo](https://github.com/wader/static-ffmpeg)

4. Technical support was provided by [Google Gemini](https://gemini.google.com) and [DeepSeek](https://www.deepseek.com)

## References:

1. [Official snapcast repo](https://github.com/badaix/snapcast)
2. [Official snapweb repo](https://github.com/badaix/snapweb)
