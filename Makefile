.PHONY: make qemu test

make:
	zig build --release=fast

qemu:
	qemu-system-x86_64 -m 1G -serial mon:stdio -display none -s -bios $(realpath OVMF.fd) -drive format=raw,file=fat:rw:zig-out,index=3

test: make qemu
