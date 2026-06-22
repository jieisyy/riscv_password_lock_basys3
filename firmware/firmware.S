    .section .text
    .globl _start

/* Memory map */
.equ DATA_BASE,       0x00010000
.equ PASSWORD_BASE,   0x00010000  /* password[4], word each */
.equ FAIL_BASE,       0x00010010  /* fail_count[4], word each */
.equ LOCK_BASE,       0x00010020  /* lock_state[4], word each */

.equ SWITCH_REG,      0x40000000
.equ BUTTON_REG,      0x40000004
.equ LED_REG,         0x40000008
.equ SEVENSEG_REG,    0x4000000C
.equ UART_TX_DATA,    0x40000010
.equ UART_STATUS,     0x40000014

/* LED bit assignment */
.equ LED_PASS,        0x0001
.equ LED_FAIL,        0x0002
.equ LED_LOCK,        0x0004
.equ LED_UART,        0x0008

_start:
    /* Initialize four passwords: 0x12, 0x34, 0x56, 0x78 */
    li t0, PASSWORD_BASE
    li t1, 0x12
    sw t1, 0(t0)
    li t1, 0x34
    sw t1, 4(t0)
    li t1, 0x56
    sw t1, 8(t0)
    li t1, 0x78
    sw t1, 12(t0)

    /* Clear fail_count[4] and lock_state[4] */
    li t0, FAIL_BASE
    sw zero, 0(t0)
    sw zero, 4(t0)
    sw zero, 8(t0)
    sw zero, 12(t0)
    li t0, LOCK_BASE
    sw zero, 0(t0)
    sw zero, 4(t0)
    sw zero, 8(t0)
    sw zero, 12(t0)

    li t0, LED_REG
    sw zero, 0(t0)
    li t0, SEVENSEG_REG
    sw zero, 0(t0)

main_loop:
    /* Wait for BTNC press */
wait_press:
    li t0, BUTTON_REG
    lw t1, 0(t0)
    andi t1, t1, 1
    beqz t1, wait_press

    /* Read switches: user_id = SW[9:8], password_input = SW[7:0] */
    li t0, SWITCH_REG
    lw s0, 0(t0)
    andi s1, s0, 0xFF        /* s1 = input password */
    srli s2, s0, 8
    andi s2, s2, 0x3         /* s2 = user_id */
    slli s3, s2, 2           /* s3 = user_id * 4 */

    /* Check lock_state[user_id] */
    li t0, LOCK_BASE
    add t0, t0, s3
    lw t1, 0(t0)
    bnez t1, locked_event

    /* Compare password[user_id] */
    li t0, PASSWORD_BASE
    add t0, t0, s3
    lw t1, 0(t0)
    beq s1, t1, pass_event

fail_event:
    /* fail_count[user_id]++ */
    li t0, FAIL_BASE
    add t0, t0, s3
    lw t1, 0(t0)
    addi t1, t1, 1
    sw t1, 0(t0)

    li t2, 3
    bge t1, t2, set_locked

    /* show FAIL */
    li t0, LED_REG
    li t1, LED_FAIL
    sw t1, 0(t0)
    li t0, SEVENSEG_REG
    li t1, 0x2222
    sw t1, 0(t0)

    jal ra, send_user_prefix
    li a0, 'F'
    jal ra, uart_putc
    li a0, 'A'
    jal ra, uart_putc
    li a0, 'I'
    jal ra, uart_putc
    li a0, 'L'
    jal ra, uart_putc
    jal ra, send_newline
    j wait_release

set_locked:
    li t0, LOCK_BASE
    add t0, t0, s3
    li t1, 1
    sw t1, 0(t0)
    j locked_event

pass_event:
    /* Clear fail_count[user_id] after successful login */
    li t0, FAIL_BASE
    add t0, t0, s3
    sw zero, 0(t0)

    li t0, LED_REG
    li t1, LED_PASS
    sw t1, 0(t0)
    li t0, SEVENSEG_REG
    li t1, 0x1111
    sw t1, 0(t0)

    jal ra, send_user_prefix
    li a0, 'P'
    jal ra, uart_putc
    li a0, 'A'
    jal ra, uart_putc
    li a0, 'S'
    jal ra, uart_putc
    li a0, 'S'
    jal ra, uart_putc
    jal ra, send_newline
    j wait_release

locked_event:
    li t0, LED_REG
    li t1, LED_LOCK
    sw t1, 0(t0)
    li t0, SEVENSEG_REG
    li t1, 0x9999
    sw t1, 0(t0)

    jal ra, send_user_prefix
    li a0, 'L'
    jal ra, uart_putc
    li a0, 'O'
    jal ra, uart_putc
    li a0, 'C'
    jal ra, uart_putc
    li a0, 'K'
    jal ra, uart_putc
    jal ra, send_newline

wait_release:
    li t0, BUTTON_REG
    lw t1, 0(t0)
    andi t1, t1, 1
    bnez t1, wait_release
    j main_loop

/* Print "USERx " where x is current user in s2 */
send_user_prefix:
    li a0, 'U'
    jal ra, uart_putc
    li a0, 'S'
    jal ra, uart_putc
    li a0, 'E'
    jal ra, uart_putc
    li a0, 'R'
    jal ra, uart_putc
    addi a0, s2, '0'
    jal ra, uart_putc
    li a0, ' '
    jal ra, uart_putc
    ret

send_newline:
    li a0, 13          /* CR */
    jal ra, uart_putc
    li a0, 10          /* LF */
    jal ra, uart_putc
    ret

/* UART put char: input a0[7:0] */
uart_putc:
    li t0, LED_REG
    li t1, LED_UART
    sw t1, 0(t0)

uart_wait:
    li t0, UART_STATUS
    lw t1, 0(t0)
    andi t1, t1, 1     /* bit0 = busy */
    bnez t1, uart_wait

    li t0, UART_TX_DATA
    sw a0, 0(t0)
    ret
