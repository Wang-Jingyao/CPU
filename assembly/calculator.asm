# 极简版计算器加减乘除
.text
	li s0,0x61 
	li s1,0x73 
	li s2,0x6D 
	li s3,0x64 
	li a7,5
	ecall
	addi t0,a0,0
	
	li a7,12
	ecall
	addi t1,a0,0
	
	li a7,12
	ecall
	
	li a7,5
	ecall
	addi t2,a0,0

	beq t1,s0,ADD
	beq t1,s1,SUB
	beq t1,s2,MUL
	beq t1,s3,DIV
	j error
ADD: 
	add t4,t0,t2
	j output
SUB:
	sub t4,t0,t2
	j output
MUL:
	mul t4,t0,t2
	j output
DIV:
	div t4,t0,t2
	j output
output:
	addi a0,t4,0
	li a7,1
	ecall
	j exit
error:
	li a0,-1
	li a7,1
	ecall
	j exit
	
exit:
	li a7,10
	ecall

	
