	.file	"simple.cpp"
	.intel_syntax noprefix
	.text
	.p2align 4
	.globl	"_Z6squarei"
	.type	"_Z6squarei", @function
"_Z6squarei":
.LFB2:
	.cfi_startproc
	imul	edi, edi
	mov	eax, edi
	ret
	.cfi_endproc
.LFE2:
	.size	"_Z6squarei", .-"_Z6squarei"
	.p2align 4
	.globl	"_Z14sum_of_squaresii"
	.type	"_Z14sum_of_squaresii", @function
"_Z14sum_of_squaresii":
.LFB3:
	.cfi_startproc
	imul	edi, edi
	imul	esi, esi
	lea	eax, [rdi+rsi]
	ret
	.cfi_endproc
.LFE3:
	.size	"_Z14sum_of_squaresii", .-"_Z14sum_of_squaresii"
	.p2align 4
	.globl	"_Z12bump_counterv"
	.type	"_Z12bump_counterv", @function
"_Z12bump_counterv":
.LFB4:
	.cfi_startproc
	add	DWORD PTR "global_counter"[rip], 1
	ret
	.cfi_endproc
.LFE4:
	.size	"_Z12bump_counterv", .-"_Z12bump_counterv"
	.section	.rodata.str1.8,"aMS",@progbits,1
	.align 8
.LC0:
	.string	"Result: %d, Counter: %d, Magic: %d\n"
	.section	.text.startup,"ax",@progbits
	.p2align 4
	.globl	"main"
	.type	"main", @function
"main":
.LFB5:
	.cfi_startproc
	sub	rsp, 8
	.cfi_def_cfa_offset 16
	mov	eax, DWORD PTR "global_counter"[rip]
	mov	ecx, 42
	mov	esi, 25
	lea	rdi, .LC0[rip]
	lea	edx, 1[rax]
	xor	eax, eax
	mov	DWORD PTR "global_counter"[rip], edx
	call	"printf"@PLT
	xor	eax, eax
	add	rsp, 8
	.cfi_def_cfa_offset 8
	ret
	.cfi_endproc
.LFE5:
	.size	"main", .-"main"
	.globl	"global_counter"
	.bss
	.align 4
	.type	"global_counter", @object
	.size	"global_counter", 4
"global_counter":
	.zero	4
	.ident	"GCC: (GNU) 16.2.1 20260810"
	.section	.note.GNU-stack,"",@progbits
