.PHONY: make qemu test

make:
	zig build --release=fast

qemu-serial:
	qemu-system-x86_64 -m 1G -serial mon:stdio -display none -s -bios $(realpath OVMF.fd) -drive format=raw,file=fat:rw:zig-out,index=3

qemu-gtk:
	qemu-system-x86_64 -m 1G -serial none -display gtk -s -bios $(realpath OVMF.fd) -drive format=raw,file=fat:rw:zig-out,index=3

clean:
	rm -rf zig-out

test-serial: clean make qemu-serial
test-gtk: clean make qemu-gtk
