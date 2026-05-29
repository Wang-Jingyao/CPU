.text
ecall:
    # 保存 ra
    addi sp, sp, -4
    sw ra, 0(sp)
    
    # 根据 a7 的值跳转到对应的系统调用处理函数
    li t0, 1
    beq a7, t0, sys_print_int
    li t0, 5
    beq a7, t0, sys_read_int
    li t0, 10
    beq a7, t0, sys_exit
    li t0, 12
    beq a7, t0, sys_read_char
    li t0, 32
    beq a7, t0, sys_sleep
    li t0, 34
    beq a7, t0, sys_print_int_hex
    li t0, 41
    beq a7, t0, sys_rand_int
    
    # 未知系统调用号则直接返回
    j end_ecall

# == Service 1: Print Integer (Decimal) ==
sys_print_int:
    bge a0, zero, print_int_pos
    sub a0, zero, a0
print_int_pos:
    li t4, 8          # 数码管有 8 位
    li t5, 0          # 存放 BCD 的结果
    li t6, 0          # 移位计数值
print_int_loop:
    jal ra, div10
    sll t3, a1, t6
    or t5, t5, t3
    addi t6, t6, 4
    addi t4, t4, -1
    bgt t4, zero, print_int_loop

    lui t0, 0x100
    sw t5, 8(t0)      # SEG_DATA (0x00100008)
    j end_ecall
div10:
    # a0 = a0 / 10
    # a1 = a0 % 10
    li t0, 10
    li a1, 0
    li t1, 32
div10_loop:
    slli a1, a1, 1
    srli t2, a0, 31
    or a1, a1, t2
    slli a0, a0, 1
    blt a1, t0, div10_skip
    sub a1, a1, t0
    ori a0, a0, 1
div10_skip:
    addi t1, t1, -1
    bgt t1, zero, div10_loop
    ret

# == Service 5: Read Integer ==
sys_read_int:
    li a0, 0          # 累加结果
    li t4, 0          # 符号标志 (1 = 负数)
    lui t6, 0x100
read_int_wait_first:
    lw t0, 0x14(t6)   # 读 KBD_DATA (0x00100014)
    beq t0, zero, read_int_wait_first
    
    li t1, 45         # '-'
    bne t0, t1, read_int_process_char
    li t4, 1
read_int_loop:
    lw t0, 0x14(t6)
    beq t0, zero, read_int_loop
read_int_process_char:
    li t1, 13         # Enter (\r)
    beq t0, t1, read_int_done
    
    addi t0, t0, -48
    blt t0, zero, read_int_loop
    li t1, 9
    bgt t0, t1, read_int_loop
    
    # t5 = t5 * 10 + digit
    slli t1, t5, 3
    slli t2, t5, 1
    add a0, t1, t2
    add a0, a0, t0
    j read_int_loop
read_int_done:
    beq t4, zero, read_int_pos
    sub a0, zero, a0
read_int_pos:
    j end_ecall

# == Service 10: Exit ==
sys_exit:
    j sys_exit

# == Service 12: Read Char ==
sys_read_char:
    lui t6, 0x100
read_char_loop:
    lw a0, 0x14(t6)   # KBD_DATA (0x00100014)
    beq a0, zero, read_char_loop
    j end_ecall

# == Service 32: Sleep ==
sys_sleep:
    beq a0, zero, end_ecall
    mv t2, a0
    lui t6, 0x100
get_init_time:
    lw t4, 0x10(t6)         # TIME_HIGH
    lw t3, 0x0C(t6)         # TIME_LOW
    lw t5, 0x10(t6)         # 再次读取 TIME_HIGH 验证
    bne t4, t5, get_init_time

sleep_check:
    lw t5, 0x10(t6)         # TIME_HIGH
    lw t1, 0x0C(t6)         # TIME_LOW
    lw a1, 0x10(t6)         # 再次读取 TIME_HIGH 验证
    bne t5, a1, sleep_check

    sub t1, t1, t3
    sltu a2, t1, t3
    sub t5, t5, t4
    sub t5, t5, a2

    bne t5, zero, end_ecall
    bltu t1, t2, sleep_check
    j end_ecall

# == Service 34: Print Integer Hex ==
sys_print_int_hex:
    lui t6, 0x100
    sw a0, 8(t6)      # SEG_DATA (0x00100008)
    j end_ecall

# == Service 41: Rand Integer ==
sys_rand_int:
    lui t6, 0x100
    lw a0, 0x18(t6)   # RAND_NUM (0x00100018)
    j end_ecall

end_ecall:
    # 恢复 ra 并返回
    lw ra, 0(sp)
    addi sp, sp, 4
    jr ra