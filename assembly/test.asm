.text
main:
    # Load n, A, B's value into Regs
    lw s0, 0(x3)    # n
    lw s1, 4(x3)    # A
    lw s2, 8(x3)    # B
    # init result R
    li s3, 0
    # case(n)
    li t0, 0
    beq s0, t0, case_0
    li t0, 1
    beq s0, t0, case_1
    li t0, 2
    beq s0, t0, case_2
    li t0, 3
    beq s0, t0, case_3
    li t0, 4
    beq s0, t0, case_4
    li t0, 5
    beq s0, t0, case_5
    li t0, 6
    beq s0, t0, case_6
    li t0, 7
    beq s0, t0, case_7
    li t0, 8
    beq s0, t0, case_8
    li t0, 9
    beq s0, t0, case_9
    j default

# and运算，实现按位与运算
case_0:
    and s3, s1, s2
    j default
# sll运算，实现左移运算，第二个操作数的低5bit是移动的位数。
case_1:
    sll s3, s1, s2
    j default
# sra运算，实现算术右移运算，第二个操作数的低5bit是移动的位数
case_2:
    sra s3, s1, s2
    j default
# lui+add，实现加载高20位立即数与加法运算
case_3:
    lui t0, 0x12345
    add s3, s1, t0
    j default
# jal+auipc,实现auipc系列操作
case_4:
    jal  a0, target
target:
    auipc a1, 0x12345
    sub s3, a1, a0
    add s3, s3, t1
    j default
# jal+jalr,实现函数调用和返回操作，并执行调用后的下一条加法运算
case_5:
    jal func
    add s3, t1, t2
    j default
func:     jr ra
# 实现斐波拉契数列计算，输入斐波拉契数列中数字的下标，
# 输出对应的斐波拉契数列中的数据。
# 如输入1；输出1；输入2，输出1；输入4，输出3
case_6:
    li t0, 1
    beq s1，t0, fib_base
    li t0, 2
    beq s1, t0, fib_base
    li t1, 1
    li t2, 1
    li t3, 3
fib_loop:
    add t4, t1, t2
    mv t1, t2
    mv t2, t4
    beq t3, s1, fib_done
    addi t3, t3, 1
    j fib_loop
fib_base:
    li s3, 1
    j default
fib_done:
    mv s3, t2
    j default
# 输出8bit中1的个数。输入8bit数据，输出8bit数据中1的个数。
# 如输入8'b11000001， 输出3。
case_7:
    mv t0, s1
    li t1, 0
    li t2, 8
cnt_loop:
    andi t3, t0, 1
    add t1, t1, t3
    srli t0, t0, 1
    addi t2, t2, -1
    bne t2, zero, cnt_loop
    mv s3, t1
    j default
# 16bitIEEE754编码浮点数的类型判断。
# 输入16bit数据，将其作为16bit的IEEE-754半精度浮点数
# （符号位1bit，指数位5bit，尾数位10bit）识别，
# 输出其对应的类型编码
#（0：正负0，1：正负无穷大，2：NaN，3:规约化数，4:非规约化数）如:
# 输入16'b1_00000_0000000000，输出0；
# 输入16'b0_11111_0000000000，输出1；
case_8:
    # 0: Exp == 0  && Frac == 0
    # 1: Exp == 31 && Frac == 0
    # 2: Exp == 31 && Frac != 0
    # 3: Exp in [1,30]
    # 4: Exp == 0  && Frac != 0

    # Exponent = bits[14:10]
    srli t0, s1, 10
    andi t0, t0, 0x1F
    # Fraction = bits[9:0]
    andi t1, s1, 0x3FF

    li t2, 0
    beq t0, t2, exp_is_zero
    li t2, 31
    beq t0, t2, exp_is_all1
    li s3, 3
    j default
exp_is_zero:
    beq t1, zero, out_zero
    li s3, 4
    j default
exp_is_all1:
    beq t1, zero, out_inf
    li s3, 2
    j default
out_zero:
    li s3, 0
    j default
out_inf:
    li s3, 1
    j default
# 浮点数的量化处理（16bit浮点数转为Q3.4的定点数）
# 输入16bit数据，将其作为16bit的IEEE-754半精度浮点数
# （符号位1bit，指数位5bit，尾数位10bit）识别，
# 将其转为Q3.4定点数(从最高位往最低位的方向依次为：
# 最高位是符号位，3bit的整数部分，4bit的小数部分)并进行量化，
# 将量化的结果做输出。（测试数据包括正数和负数,
# 不涉及超出Q3.4表示范围的数据，不涉及NAN,无穷大，非规约化数据;
# 如果是负数则输出对应的补码）如:
# 输入16'b0_01111_0000_0000_000，输出00010000。
# 输入16'b1_01111_1000_0000_000，输出11101000。
case_9:
    # value_fp = (-1)^sign * (1024 + frac) * 2^(Exp - 25)
    # value_q3.4 = (-1)^sign * (1024 + frac) * 2^(Exp - 21)
    # t4 = frac + 1024
    andi t2, s1, 0x3FF
    addi t4, t2, 1024

    # t1 = exp
    srli t1, s1, 10
    andi t1, t1, 0x1F

    # 右移位数 = 21 - Exp
    li      t5, 21
    sub     t6, t5, t1
    srl     a0, t4, t6

    # 无分支求负数补码
    slli t0, s1, 16
    srai t0, t0, 31
    xor a0, a0, t0
    sub a0, a0, t0

    # 截断输出
    andi s3, a0, 0xFF
    j default
# 保存答案，跳转开头
default:
    sw s3, 0xC(x3)
    j main