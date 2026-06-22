ENTRY(_start)
MEMORY
{
    IMEM (rx) : ORIGIN = 0x00000000, LENGTH = 16K
}
SECTIONS
{
    .text : {
        *(.text*)
        *(.rodata*)
    } > IMEM
}
