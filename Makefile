CC       := arm-none-eabi-gcc
CPP      := arm-none-eabi-cpp
LD       := arm-none-eabi-ld
AR       := arm-none-eabi-ar
AS       := arm-none-eabi-as
OBJCOPY  := arm-none-eabi-objcopy
GDB      := arm-none-eabi-gdb
REMOVE   := rm -f
SIZE     := arm-none-eabi-size
STRIP		 := arm-none-eabi-strip
RUSTC		 := rustc
CLANG		 := clang
LLC			 := llc-3.4

OPT      := 2

PROJECT  := operon
SRC      := src/main.rs
OBJ      :=
LIBS     :=
IDIR     := include
MODULES  := lib/cmsis/CMSIS lib/freescale/MKL25Z
DEVICE   := MKL25Z64
ADAPTER  := name=ftdi:vid=0x0403:pid=0x6010
PROG_DIR := programmer

CFLAGS   := -mcpu=cortex-m0plus -msoft-float -mthumb -ffunction-sections \
            -fdata-sections -fno-builtin -fstrict-volatile-bitfields \
            -W -Wall -Wundef -std=c99 -Wcast-qual -Wwrite-strings \
            -Wstrict-prototypes -Wmissing-prototypes -Wmissing-declarations \
            -ffreestanding -fno-builtin
LDFLAGS  := -mcpu=cortex-m0plus -mthumb -O$(OPT) -nostartfiles \
            -ffreestanding -fno-builtin -Wl,-Map=$(PROJECT).map -specs=nano.specs
ASFLAGS  := -mcpu=cortex-m0plus
LLCFLAGS := -mtriple=arm-none-eabi -march=thumb -mcpu=cortex-m0 --float-abi=soft -asm-verbose
RUSTFLAGS := --opt-level=$(OPT) --target arm-linux-eabi -Z debug-info
CLANGFLAGS := -target arm-none-eabi -ffreestanding -fno-builtin -g -v \
              -mcpu=cortex-m4 -mthumb -march=armv7

RUSTFLAGS += --cfg libc

#########################################################################

all: $(PROJECT).elf

include $(patsubst %,%/module.mk,$(MODULES))
include $(patsubst %.c,%.d,$(filter %.c,$(SRC))) \
        $(patsubst %.S,%.d,$(filter %.S,$(SRC)))

CFLAGS   += $(patsubst %,-I%,$(IDIR))
LDFLAGS   += -T$(LSCRIPT)
OBJ      += $(patsubst %.c,%.o,$(filter %.c,$(SRC))) \
						$(patsubst %.rs,%.o,$(filter %.rs,$(SRC))) \
            $(patsubst %.S,%.o,$(filter %.S,$(SRC)))

$(PROJECT).bin: $(PROJECT).elf
	$(OBJCOPY) -O binary -j .text -j .data $(PROJECT).elf $(PROJECT).bin

$(PROJECT).vect: $(PROJECT).elf
	$(OBJCOPY) -O binary -j .isr_vector $(PROJECT).elf $(PROJECT).vect

$(PROJECT).hex: $(PROJECT).elf
	$(OBJCOPY) -R .stack -O ihex $(PROJECT).elf $(PROJECT).hex

$(PROJECT).s19: $(PROJECT).elf
	$(OBJCOPY) -R .stack -O srec $(PROJECT).elf $(PROJECT).s19

$(PROJECT).elf: $(OBJ) $(LSCRIPT)
	$(CC) $(LDFLAGS) $(OBJ) -o $(PROJECT).elf

info: $(PROJECT).elf
	$(SIZE) $(PROJECT).elf

clean:
	$(REMOVE) $(OBJ)
	$(REMOVE) $(OBJ:.o=.d)
	$(REMOVE) $(PROJECT).hex
	$(REMOVE) $(PROJECT).elf
	$(REMOVE) $(PROJECT).s19
	$(REMOVE) $(PROJECT).map
	$(REMOVE) $(PROJECT).bin
	$(REMOVE) $(PROJECT).vect
	$(REMOVE) $(OBJ:.o=.lst)

flash-vect: $(PROJECT).vect
	ruby -I $(PROG_DIR) $(PROG_DIR)/flash.rb $(ADAPTER) $(PROJECT).vect 0

flash-bin: $(PROJECT).bin
	ruby -I $(PROG_DIR) $(PROG_DIR)/flash.rb $(ADAPTER) $(PROJECT).bin 0x400

flash-all: flash-bin flash-vect

debug:
	ruby -I $(PROG_DIR) $(PROG_DIR)/gdbserver.rb name=ftdi:vid=0x0403:pid=0x6010

#########################################################################

%.ll: %.rs
	$(RUSTC) $(RUSTFLAGS) -S --lib -o $*.ll --emit-llvm $<
	sed -i 's/arm--linux-eabi/arm-none-eabi/g' $*.ll

%.bc: %.rs
	$(RUSTC) $(RUSTFLAGS) --lib -o $*.bc --emit-llvm $<

# %.s: %.bc
# 	$(CLANG) $(CLANGFLAGS) -S -o $*.s $<

# %.o: %.bc
# 	$(CLANG) $(CLANGFLAGS) -o $*.o $<

%.s: %.ll
	$(LLC) $(LLCFLAGS) -o $*.s $<
	sed -i 's/.note.rustc,"aw"/.note.rustc,""/g' $*.s

%.o %.d: %.c
	$(CC) -MMD -MT $*.o -MF $*.d -c -o $*.o $< $(CFLAGS) -g -Wa,-alhsdn=$(basename $<).lst -fverbose-asm

%.o %.d: %.S
	$(CPP) -MMD -MT $*.o -MF $*.d $< | $(AS) -o $*.o $(ASFLAGS) -g -alsdn=$(basename $<).lst

# %.o: %.s
# 	$(AS) -o $*.o $(ASFLAGS) -g -alsdn=$*.lst $<

%.o: %.s
	$(CC) -c -o $*.o $< $(CFLAGS) -g -Wa,-alsdn=$*.lst
	#$(STRIP) $*.o -R .note.rustc

.PHONY: test clean all depend flash-bin flash-vect flash-all