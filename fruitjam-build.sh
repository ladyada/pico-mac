#!/bin/sh
set -e

# Some configurations that actually work at the time I committed this:
# ./fruitjam-build.sh  -v         # vga resolution, no psram, 128KiB
# ./fruitjam-build.sh  -v -m448   # vga resolution, no psram,  448KiB
# ./fruitjam-build.sh  -m4096     # 512x342 resolution, psram, 4096KiB
# ./fruitjam-build.sh  -d disk.img  # specify disk image

DISP_WIDTH=512
DISP_HEIGHT=342
MEMSIZE=400
DISK_IMAGE=""
CMAKE_ARGS=

while getopts "hvd:m:" o; do
    case "$o" in
    (v)
        DISP_WIDTH=640
        DISP_HEIGHT=480
        CMAKE_ARGS="$CMAKE_ARGS -DUSE_VGA_RES=1 -DHSTX_CKP=12 -DHSTX_D0P=14 -DHSTX_D1P=16 -DHSTX_D2P=18"
        ;;
    (m)
        MEMSIZE=$OPTARG
        ;;
    (d)
        DISK_IMAGE=$OPTARG
        ;;
    (h|?)
        echo "Usage: $0 [-v] [-m KiB] [-d diskimage]"
        echo ""
        echo "   -v: Use framebuffer resolution 640x480 instead of 512x342"
        echo "   -m: Set memory size in KiB"
        echo "   -d: Specify disk image to include"
        echo ""
        echo "PSRAM is automatically set depending on memory & framebuffer details"
        exit
        ;;
    esac
done

TAG=fruitjam_${DISP_WIDTH}x${DISP_HEIGHT}_${MEMSIZE}k
PSRAM=$((MEMSIZE > 448 || DISP_WIDTH < 640))
if [ $PSRAM -ne 0 ] ; then
    TAG=${TAG}_psram
    CMAKE_ARGS="$CMAKE_ARGS -DUSE_PSRAM=1"
fi

# Append disk name to build directory if disk image is specified
if [ -n "$DISK_IMAGE" ] && [ -f "$DISK_IMAGE" ]; then
    # Extract filename without extension
    DISK_NAME=$(basename "$DISK_IMAGE" | sed 's/\.[^.]*$//')
    TAG=${TAG}_${DISK_NAME}
fi

set -x
make -C external/umac clean
make -C external/umac DISP_WIDTH=${DISP_WIDTH} DISP_HEIGHT=${DISP_HEIGHT} MEMSIZE=${MEMSIZE}
rm -f rom.bin
./external/umac/main -r '4D1F8172 - MacPlus v3.ROM' -W rom.bin || true
[ -f rom.bin ]
xxd -i < rom.bin > incbin/umac-rom.h
if [ -n "$DISK_IMAGE" ] && [ -f "$DISK_IMAGE" ]; then
    xxd -i < "$DISK_IMAGE" > incbin/umac-disc.h
fi
rm -rf build_${TAG}
cmake -S . -B build_${TAG} \
    -DPICO_SDK_PATH=../pico-sdk \
    -DPICOTOOL_FETCH_FROM_GIT_PATH="$(pwd)/picotool" \
    -DBOARD=adafruit_fruit_jam -DPICO_BOARD=pimoroni_pico_plus2_rp2350 \
    -DMEMSIZE=${MEMSIZE} \
    -DUSE_HSTX=1 \
    -DSD_TX=35 -DSD_RX=36 -DSD_SCK=34 -DSD_CS=39 -DUSE_SD=1 \
    ${CMAKE_ARGS}
make -C build_${TAG} -j$(nproc)