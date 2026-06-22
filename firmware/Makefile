RISCV_PREFIX ?= riscv32-unknown-elf-
CFLAGS = -march=rv32i -mabi=ilp32 -nostdlib -ffreestanding -Wl,-T,linker.ld -Wl,--no-relax

all: firmware.hex

firmware.elf: firmware.S linker.ld
	$(RISCV_PREFIX)gcc $(CFLAGS) -o $@ firmware.S

firmware.bin: firmware.elf
	$(RISCV_PREFIX)objcopy -O binary $< $@

firmware.hex: firmware.bin bin2hex.py
	python3 bin2hex.py firmware.bin firmware.hex

clean:
	rm -f firmware.elf firmware.bin firmware.hex
