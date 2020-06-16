OUTPUT_DIR=out
DISKSIZE=128
BOOTSIZE=16384
BOOTTYPE=16
CXX_FLAGS= \
	-nostdinc -nostdlib -nostartfiles -fno-stack-protector -fno-threadsafe-statics -ffreestanding -fno-pie -fno-exceptions -fno-rtti \
	-std=c++17 -mno-red-zone \
	-Wall -Wextra -Werror

all:
	mkdir -p ${OUTPUT_DIR}
	make mking.c
	make boot.cpp

edk2:
	cd ./deps/edk2 && sudo /bin/bash ./edksetup.sh 2>/dev/null >/dev/null || true
	cp -f build/target.txt deps/edk2/Conf/target.txt
	cd ./deps/edk2 && make -C BaseTools && build -DDEBUG_ON_SERIAL_PORT=TRUE

image: all
	mkdir -p ${OUTPUT_DIR}/initrd ${OUTPUT_DIR}/initrd/sys
	cp ${OUTPUT_DIR}/kernel.elf ${OUTPUT_DIR}/initrd/sys/core
	cd ${OUTPUT_DIR}/initrd && (find . | cpio -H hpodc -o | gzip > ../initrd.bin) && cd ..
	rm -r ${OUTPUT_DIR}/initrd 2>/dev/null || true

	dd if=/dev/zero of=${OUTPUT_DIR}/bootpart.bin bs=1024 count=$(BOOTSIZE) >/dev/null 2>/dev/null
	mkfs.vfat -F $(BOOTTYPE) -n "EFI System" ${OUTPUT_DIR}/bootpart.bin 2>/dev/null >/dev/null
	mkdir -p ${OUTPUT_DIR}/boot
	sudo mount -o loop,user ${OUTPUT_DIR}/bootpart.bin ${OUTPUT_DIR}/boot || true
	sudo mkdir -p ${OUTPUT_DIR}/boot/BOOTBOOT
	sudo cp deps/bootboot/bootboot.bin ${OUTPUT_DIR}/boot/BOOTBOOT/LOADER
	sudo mkdir -p ${OUTPUT_DIR}/boot/EFI ${OUTPUT_DIR}/boot/EFI/BOOT
	sudo cp deps/bootboot/bootboot.efi ${OUTPUT_DIR}/boot/EFI/BOOT/BOOTX64.EFI
	sudo bash -c "echo -e "screen=800x600\nkernel=sys/core\n" > ${OUTPUT_DIR}/boot/BOOTBOOT/CONFIG"
	sudo cp ${OUTPUT_DIR}/initrd.bin ${OUTPUT_DIR}/boot/BOOTBOOT/INITRD || true
	sudo umount -f /dev/loop* 2>/dev/null || true

	cp deps/bootboot/boot.bin ${OUTPUT_DIR}/boot.bin	# fixme
	cd ${OUTPUT_DIR} && ./mkimg $(DISKSIZE) ./disk.img

boot.cpp: bprint.cpp util.cpp
	g++ ${CXX_FLAGS} -c src/boot/boot.cpp -o ${OUTPUT_DIR}/boot.o \
	-I src/include \
	-I deps/bootboot

	ld -r -b binary -o ${OUTPUT_DIR}/font.o deps/bootboot/mykernel/font.psf
	ld -nostdinc -nostdlib \
	-T src/boot/linker.ld \
	${OUTPUT_DIR}/font.o ${OUTPUT_DIR}/boot.o ${OUTPUT_DIR}/bprint.o ${OUTPUT_DIR}/util.o \
	-o ${OUTPUT_DIR}/kernel.elf

bprint.cpp:
	g++ ${CXX_FLAGS} -c src/kernel/bprint.cpp -o ${OUTPUT_DIR}/bprint.o \
	-I src/include \
	-I deps/bootboot

util.cpp:
	g++ ${CXX_FLAGS} -c src/kernel/util.cpp -o ${OUTPUT_DIR}/util.o \
	-I src/include \
	-I deps/bootboot

mking.c:
	gcc -ansi -pedantic -Wall -Wextra -g build/mkimg.c -o ${OUTPUT_DIR}/mkimg

clean:
	rm -rf ${OUTPUT_DIR}/*
