;;;; -*- Mode: Lisp -*-
;;;; Author:
;;;;     Yujian Zhang <yujian.zhang@gmail.com>
;;;; Description:
;;;;     Syntax tables for x86-64.
;;;; References:
;;;;     [1] Intel 64 and IA-32 Architectures Software Developer's Manual
;;;;         Volume 2, Instruction Set Reference, A-Z. June 2015
;;;; License:
;;;;     GNU General Public License v2
;;;;     http://www.gnu.org/licenses/gpl-2.0.html
;;;; Copyright (C) 2009-2015 Yujian Zhang

(in-package :cc)

(defun arith-syntax-1 (mnemonic 64bit-only?)
  "Return syntax table for arithmetic operations:
adc/add/and/cmp/or/sbb/sub/xor."
  (let ((base   ; Base opcode for operation on r/m8 r8.
         (ecase mnemonic
           (adc #x10) (add #x00) (and #x20) (cmp #x38)
           (or  #x08) (sbb #x18) (sub #x28) (xor #x30)))
        (opcode ; Opcode used when one operand is immediate.
         (ecase mnemonic
           (adc '/2) (add '/0) (and '/4) (cmp '/7)
           (or  '/1) (sbb '/3) (sub '/5) (xor '/6))))
    (if 64bit-only?
        `(;; TODO: For imm8, encode with imm8 with generic r64
          ;; (instead of rax) seems to save 3 bytes.
          ((,mnemonic rax imm32)                 . (rex.w ,(+ base #x05) id))
          ((,mnemonic (r/m64 r64) (imm32 imm16)) . (rex.w #x81 ,opcode id))
          ((,mnemonic qword m (imm32 imm16))     . (rex.w #x81 ,opcode id))
          ((,mnemonic (r/m64 r64) imm8)          . (rex.w #x83 ,opcode ib))
          ((,mnemonic qword m imm8)              . (rex.w #x83 ,opcode ib))
          ((,mnemonic (r/m64 r64 m) r64)         . (rex.w ,(+ base #x01) /r))
          ((,mnemonic r64 (r/m64 r64 m))         . (rex.w ,(+ base #x03) /r)))
        `(((,mnemonic al imm8)                   . (,(+ base #x04) ib))
          ((,mnemonic ax imm16)                  . (o16 ,(+ base #x05) iw))
          ((,mnemonic eax imm32)                 . (o32 ,(+ base #x05) id))
          ((,mnemonic (r/m8 r8) imm8)            . (#x80 ,opcode ib))
          ((,mnemonic byte m imm8)               . (#x80 ,opcode ib))
          ((,mnemonic (r/m16 r16) imm8)          . (o16 #x83 ,opcode ib))
          ((,mnemonic (r/m32 r32) imm8)          . (o32 #x83 ,opcode ib))
          ((,mnemonic word m imm8)               . (o16 #x83 ,opcode ib))
          ((,mnemonic dword m imm8)              . (o32 #x83 ,opcode ib))
          ((,mnemonic (r/m16 r16) imm16)         . (o16 #x81 ,opcode iw))
          ((,mnemonic word m imm16)              . (o16 #x81 ,opcode iw))
          ((,mnemonic (r/m32 r32) (imm32 imm16)) . (o32 #x81 ,opcode id))
          ((,mnemonic dword m (imm32 imm16))     . (o32 #x81 ,opcode id))
          ((,mnemonic r/m8 r8)                   . (,base /r))
          ((,mnemonic (r/m16 r16 m) r16)         . (o16 ,(+ base #x01) /r))
          ((,mnemonic (r/m32 r32 m) r32)         . (o32 ,(+ base #x01) /r))
          ((,mnemonic r8 r/m8)                   . (,(+ base #x02) /r))
          ((,mnemonic r16 (r/m16 r16 m))         . (o16 ,(+ base #x03) /r))
          ((,mnemonic r32 (r/m32 r32 m))         . (o32 ,(+ base #x03) /r))))))

(defun arith-syntax-2 (mnemonic 64bit-only?)
  "Return syntax table for arithmetic operations: div/mul/neg/not."
  (let ((opcode (ecase mnemonic
                  (div '/6) (mul '/4) (neg '/3) (not '/2))))
    (if 64bit-only?
        `(((,mnemonic (r/m64 r64))               . (rex.w #xf7 ,opcode))
          ((,mnemonic qword m)                   . (rex.w #xf7 ,opcode)))
        `(((,mnemonic (r/m8 r8))                 . (#xf6 ,opcode))
          ((,mnemonic byte m)                    . (#xf6 ,opcode))
          ((,mnemonic (r/m16 r16))               . (o16 #xf7 ,opcode))
          ((,mnemonic word m)                    . (o16 #xf7 ,opcode))
          ((,mnemonic (r/m32 r32))               . (o32 #xf7 ,opcode))
          ((,mnemonic dword m)                   . (o32 #xf7 ,opcode))))))

(defun shift-syntax (mnemonic 64bit-only?)
  "Return syntax table for shift operations: sal/sar/shl/shr."
  (let ((opcode (ecase mnemonic
                  (sal '/4) (sar '/7) (shl '/4) (shr '/5))))
    (if 64bit-only?
        `(((,mnemonic r64 1)                     . (rex.w #xd1 ,opcode))
          ((,mnemonic qword m 1)                 . (rex.w #xd1 ,opcode))
          ((,mnemonic r64 cl)                    . (rex.w #xd3 ,opcode))
          ((,mnemonic qword m cl)                . (rex.w #xd3 ,opcode))
          ((,mnemonic r64 imm8)                  . (rex.w #xc1 ,opcode ib))
          ((,mnemonic qword m imm8)              . (rex.w #xc1 ,opcode ib)))
        `(((,mnemonic r8 1)                      . (#xd0 ,opcode))
          ((,mnemonic byte m 1)                  . (#xd0 ,opcode))
          ((,mnemonic r8 cl)                     . (#xd2 ,opcode))
          ((,mnemonic byte m cl)                 . (#xd2 ,opcode))
          ((,mnemonic r8 imm8)                   . (#xc0 ,opcode ib))
          ((,mnemonic byte m imm8)               . (#xc0 ,opcode ib))
          ((,mnemonic r16 1)                     . (o16 #xd1 ,opcode))
          ((,mnemonic word m 1)                  . (o16 #xd1 ,opcode))
          ((,mnemonic r16 cl)                    . (o16 #xd3 ,opcode))
          ((,mnemonic word m cl)                 . (o16 #xd3 ,opcode))
          ((,mnemonic r16 imm8)                  . (o16 #xc1 ,opcode ib))
          ((,mnemonic word m imm8)               . (o16 #xc1 ,opcode ib))
          ((,mnemonic r32 1)                     . (o32 #xd1 ,opcode))
          ((,mnemonic dword m 1)                 . (o32 #xd1 ,opcode))
          ((,mnemonic r32 cl)                    . (o32 #xd3 ,opcode))
          ((,mnemonic dword m cl)                . (o32 #xd3 ,opcode))
          ((,mnemonic r32 imm8)                  . (o32 #xc1 ,opcode ib))
          ((,mnemonic dword m imm8)              . (o32 #xc1 ,opcode ib))))))

(defun bit-syntax (mnemonic 64bit-only?)
  "Return syntax table for arithmetic operations: bt/btc/btr/bts."
  (let ((base   ; Base opcode for operation on r/m16, r16, r/m32, r32, r/m64, r64.
         (ecase mnemonic
           (bt #x0) (btc #x18) (btr #x10) (bts #x8)))
        (opcode ; Opcode used when one operand is immediate.
         (ecase mnemonic
           (bt '/4) (btc '/7) (btr '/6) (bts '/5))))
    (if 64bit-only?
        `(((,mnemonic r/m64 r64)  . (rex.w #x0f ,(+ base #xa3) /r))
          ((,mnemonic r/m64 imm8) . (rex.w #x0f #xba ,opcode ib)))
        `(((,mnemonic r/m16 r16)  . (o16 #x0f ,(+ base #xa3) /r))
          ((,mnemonic r/m32 r32)  . (o32 #x0f ,(+ base #xa3) /r))
          ((,mnemonic r/m16 imm8) . (o16 #x0f #xba ,opcode ib))
          ((,mnemonic r/m32 imm8) . (o32 #x0f #xba ,opcode ib))))))

;;; Following are syntax tables for x86-64. For each entry, 1st part
;;; is the instruction type, 2nd part is the corresponding opcode.
;;; Note that for the 1st part, list may be used for the operand to
;;; match the type (e.g. imm8 converted to imm16). Note that the
;;; canonical form should be placed first (e.g. if the operand type
;;; should be imm16, place it as the car of the list).
;;;
;;;  For details,
;;;    refer to https://github.com/whily/yalo/blob/master/doc/AssemblyX64.md

(defparameter *x86-64-syntax-common*
  `(
    ,@(arith-syntax-1 'adc nil)
    ,@(arith-syntax-1 'add nil)
    ,@(arith-syntax-1 'and nil)
    ((bswap r32)                             . (#x0f (+ #xc8 r)))
    ,@(bit-syntax 'bt nil)
    ,@(bit-syntax 'btc nil)
    ,@(bit-syntax 'btr nil)
    ,@(bit-syntax 'bts nil)
    ((bsf r16 r/m16)                         . (o16 #x0f #xbc /r))
    ((bsf r32 r/m32)                         . (o32 #x0f #xbc /r))
    ((bsr r16 r/m16)                         . (o16 #x0f #xbd /r))
    ((bsr r32 r/m32)                         . (o32 #x0f #xbd /r))
    ((call   (imm32 imm64 imm16 imm8 label)) . (o32 #xe8 cd))
    ;; Below is just an hack so that we can always use 32 bit operand
    ;; when operating in 32 bit mode.  TODO.
    ;; As current assembler did not differentiate too much between 16
    ;; bit and 32 bit mode, as we need 32 bit operand size for near
    ;; relative call in 32 bit, one SHOULD always use call32 below to
    ;; call function when working in 32 bit mode (so far in our
    ;; bootloader, 32 bit mode is transient as we just setup paging
    ;; and goes to 64 bit mode.
    ;; Warning: simply using `call` might result in stack corruption
    ;; (as 16 bit IP is pushed to stack instead of 32 bit), and memory exception
    ;; might occur when return using wrong EIP.
    ((call32 (imm32 imm64 imm16 imm8 label)) . (o32 #xe8 cd))
    ((clc)                                   . (#xf8))
    ((cld)                                   . (#xfc))
    ((cli)                                   . (#xfa))
    ((cmovcc r16 r/m16)                      . (o16 #x0f (+ #x40 cc) /r))
    ((cmovcc r32 r/m32)                      . (o32 #x0f (+ #x40 cc) /r))
    ,@(arith-syntax-1 'cmp nil)
    ((cmpxchg r/m8 r8)                       . (#x0f #xb0 /r))
    ((cmpxchg r/m16 r16)                     . (o16 #x0f #xb1 /r))
    ((cmpxchg r/m32 r32)                     . (o32 #x0f #xb1 /r))
    ((cmpxchg8b m)                           . (#x0f #xc7 /1))
    ((cpuid)                                 . (#x0f #xa2))
    ((dec    (r/m8 r8))                      . (#xfe /1))
    ((dec    byte m)                         . (#xfe /1))
    ((dec    (r/m16 r16))                    . (o16 #xff /1))
    ((dec    word m)                         . (o16 #xff /1))
    ((dec    (r/m32 r32))                    . (o32 #xff /1))
    ((dec    dword m)                        . (o32 #xff /1))
    ,@(arith-syntax-2 'div nil)
    ((hlt)                                   . (#xf4))
    ((in     al imm8)                        . (#xe4 ib))
    ((in     ax imm8)                        . (#xe5 ib))
    ((in     al dx)                          . (#xec))
    ((in     ax dx)                          . (#xed))
    ((inc    (r/m8 r8))                      . (#xfe /0))
    ((inc    byte m)                         . (#xfe /0))
    ((inc    (r/m16 r16))                    . (o16 #xff /0))
    ((inc    word m)                         . (o16 #xff /0))
    ((inc    (r/m32 r32))                    . (o32 #xff /0))
    ((inc    dword m)                        . (o32 #xff /0))
    ((int    3)                              . (#xcc))
    ((int    imm8)                           . (#xcd ib))
    ((invlpg m)                              . (#x0f #x01 /7))
    ((jcc    (imm8 label imm16 imm32 imm64)) . ((+ #x70 cc) cb))
    ((jcc    near (imm32 label imm8 imm16 imm64)) . (#x0f (+ #x80 cc) cd))
    ((jecxz   (imm8 label imm16 imm32 imm64)) . (a32 #xe3 cb))
    ((jmp    short (imm8 label imm16 imm32 imm64)) . (#xeb cb))
    ((lgdt   m)                              . (#x0f #x01 /2))
    ((lidt   m)                              . (#x0f #x01 /3))
    ((lldt   r/m16)                          . (#x0f #x00 /2))
    ((lodsb)                                 . (#xac))
    ((lodsw)                                 . (o16 #xad))
    ((lodsd)                                 . (o32 #xad))
    ((loop   (imm8 label imm16 imm32 imm64)) . (#xe2 cb))
    ((mov    r8 imm8)                        . ((+ #xb0 r) ib))
    ((mov    r16 (imm16 imm8 imm label))     . (o16 (+ #xb8 r) iw))
    ((mov    r32 (imm32 imm16 imm8 imm label)) . (o32 (+ #xb8 r) id))
    ((mov    r/m8 r8)                        . (#x88 /r))
    ((mov    r/m16 r16)                      . (o16 #x89 /r))
    ((mov    r/m32 r32)                      . (o32 #x89 /r))
    ((mov    r8 r/m8)                        . (#x8a /r))
    ((mov    r16 r/m16)                      . (o16 #x8b /r))
    ((mov    r32 r/m32)                      . (o32 #x8b /r))
    ((mov    byte m (imm8 imm label))        . (#xc6 /0 ib))
    ((mov    word m (imm16 imm8 imm label))  . (o16 #xc7 /0 iw))
    ((mov    dword m (imm32 imm16 imm8 imm label)) . (o32 #xc7 /0 id))
    ((mov    sreg r/m16)                     . (#x8e /r))
    ((mov    r/m16 sreg)                     . (#x8c /r))
    ((movsb)                                 . (#xa4))
    ((movsw)                                 . (o16 #xa5))
    ((movsd)                                 . (o32 #xa5))
    ((movzx  r16 r/m8)                       . (o16 #x0f #xb6 /r))
    ((movzx  r32 (r/m8 r8))                  . (o32 #x0f #xb6 /r))
    ((movzx  r32 byte m)                     . (o32 #x0f #xb6 /r))
    ((movzx  r32 (r/m16 r16))                . (o32 #x0f #xb7 /r))
    ((movzx  r32 word m)                     . (o32 #x0f #xb7 /r))
    ,@(arith-syntax-2 'mul nil)
    ,@(arith-syntax-2 'neg nil)
    ((nop)                                   . (#x90))
    ,@(arith-syntax-2 'not nil)
    ,@(arith-syntax-1 'or nil)
    ((out    imm8 r8)                        . (#xe6 ib))   ; (out imm8 al)
    ((out    imm8 r16)                       . (#xe7 ib))   ; (out imm8 ax)
    ((out    dx al)                          . (#xee))
    ((out    dx ax)                          . (#xef))
    ((pop    r16)                            . (o16 (+ #x58 r)))
    ;; Note that for 64 bit mode, prefix #x66 should be used according
    ;; to section 4.2 (INSTRUCTIONS (N-Z)) of [1]. This is different from NASM.
    ((popf)                                  . (o16 #x9d))
    ((push   r16)                            . (o16 (+ #x50 r)))
    ;; Note that for 64 bit mode, prefix #x66 should be used according
    ;; to section 4.2 (INSTRUCTIONS (N-Z)) of [1]. This is different from NASM.
    ((pushf)                                 . (o16 #x9c))
    ((ret)                                   . (#xc3))
    ((rdmsr)                                 . (#x0f #x32))
    ,@(shift-syntax 'sal nil)
    ,@(shift-syntax 'sar nil)
    ,@(shift-syntax 'shl nil)
    ,@(shift-syntax 'shr nil)
    ((stc)                                   . (#xf9))
    ((std)                                   . (#xfd))
    ((sti)                                   . (#xfb))
    ((stosb)                                 . (#xaa))
    ((stosw)                                 . (o16 #xab))
    ((stosd)                                 . (o32 #xab))
    ,@(arith-syntax-1 'sbb nil)
    ,@(arith-syntax-1 'sub nil)
    ((test    al imm8)                       . (#xa8 ib))
    ((test    ax imm16)                      . (#xa9 iw))
    ((test    (r/m8 r8) imm8)                . (#xf6 /0 ib))
    ((test    byte m imm8)                   . (#xf6 /0 ib))
    ((test    r/m16 imm16)                   . (#xf7 /0 iw))
    ((test    word m imm16)                  . (#xf7 /0 iw))
    ((test    r/m32 imm32)                   . (#xf7 /0 id))
    ((test    dword m imm32)                 . (#xf7 /0 id))
    ((test    r/m8 r8)                       . (#x84 /r))
    ((test    r/m16 r16)                     . (#x85 /r))
    ((test    r/m32 r32)                     . (#x85 /r))
    ((wrmsr)                                 . (#x0f #x30))
    ((xadd    r/m8 r8)                       . (#x0f #xc0 /r))
    ((xadd    r/m16 r16)                     . (o16 #x0f #xc1 /r))
    ((xadd    r/m32 r32)                     . (o32 #x0f #xc1 /r))
    ((xchg    r16 ax)                        . (o16 (+ #x90 r)))
    ((xchg    r32 eax)                       . (o32 (+ #x90 r)))
    ((xchg    r/m8 r8)                       . (#x86 /r))
    ((xchg    r8 r/m8)                       . (#x86 /r))
    ((xchg    r/m16 r16)                     . (o16 #x87 /r))
    ((xchg    r16 r/m16)                     . (o16 #x87 /r))
    ((xchg    r/m32 r32)                     . (o32 #x87 /r))
    ((xchg    r32 r/m32)                     . (o32 #x87 /r))
    ,@(arith-syntax-1 'xor nil))
  "Valid for both 16-bit and 64-bit modes.")

(defparameter *x86-64-syntax-16/32-bit-only*
  `(((call   (imm16 imm8 label))             . (o16 #xe8 cw))
    ((dec    r16)                            . (o16 (+ #x48 r)))
    ((dec    r32)                            . (o32 (+ #x48 r)))
    ((inc    r16)                            . (o16 (+ #x40 r)))
    ((inc    r32)                            . (o32 (+ #x40 r)))
    ((jcxz   (imm8 label imm16 imm32))       . (a16 #xe3 cb))
    ((jmp    near (imm16 label imm8 imm32))  . (#xe9 cw))
    ((mov    r32 cr0-cr7)                    . (#x0f #x20 /r))
    ((mov    cr0-cr7 r32)                    . (#x0f #x22 /r))
    ((pop    r32)                            . (o32 (+ #x58 r)))
    ((pop    ss)                             . (#x17))
    ((pop    ds)                             . (#x1f))
    ((pop    es)                             . (#x07))
    ((popfd)                                 . (o32 #x9d))
    ((push   r32)                            . (o32 (+ #x50 r)))
    ((push   cs)                             . (#x0e))
    ((push   ss)                             . (#x16))
    ((push   ds)                             . (#x1e))
    ((push   es)                             . (#x06))
    ((pushfd)                                . (o32 #x9c)))
  "Valid for 16-bit mode only.")

(defparameter *x86-64-syntax-64-bit-only*
  `(
    ,@(arith-syntax-1 'adc t)
    ,@(arith-syntax-1 'add t)
    ,@(arith-syntax-1 'and t)
    ((bswap r64)                             . (rex.w #x0f (+ #xc8 r)))
    ,@(bit-syntax 'bt t)
    ,@(bit-syntax 'btc t)
    ,@(bit-syntax 'btr t)
    ,@(bit-syntax 'bts t)
    ((bsf r64 r/m64)                         . (rex.w #x0f #xbc /r))
    ((bsr r64 r/m64)                         . (rex.w #x0f #xbd /r))
    ((cmovcc r64 r/m64)                      . (rex.w #x0f (+ #x40 cc) /r))
    ((cmpxchg r/m64 r64)                     . (rex.w #x0f #xb1 /r))
    ((cmpxchg16b m)                          . (rex.w #x0f #xc7 /1))
    ,@(arith-syntax-1 'cmp t)
    ((dec    (r/m64 r64))                    . (rex.w #xff /1))
    ((dec    qword m)                        . (rex.w #xff /1))
    ,@(arith-syntax-2 'div t)
    ((inc    (r/m64 r64))                    . (rex.w #xff /0))
    ((inc    qword m)                        . (rex.w #xff /0))
    ((iretq)                                 . (rex.w #xcf))
    ;; The following instruction is available for 16/32 bit, but we only support it
    ;; in 64 bit for simplicity (there are already more compact `jmp near` in 16/32 bits.)
    ((jmp    near (imm32 label imm8 imm16 imm64))  . (#xe9 cd))
    ((jmp    near r/m64)                     . (#xff /4))
    ((jrcxz  (imm8 label imm16 imm32 imm64)) . (#xe3 cb))
    ((leave)                                 . (#xc9))
    ((lodsq)                                 . (rex.w #xad))
    ;; For the following two instructions (including the one commented out)
    ;; we use id instead of io (as in instruction manual) for imm32.
    ;; NASM generates same results.
    ;; The following instruction is handled in function match-instruction,
    ;; therefore commented out.
    ;; ((mov    r64 -imm32)                     . (rex.w #xc7 /0 id))
    ((mov    qword m (imm32 imm16 imm8 imm label)) . (rex.w #xc7 /0 id))
    ((mov    r64 (imm32 imm16 imm8 imm))     . ((+ #xb8 r) id))
    ((mov    r64 (imm64 label))              . (rex.w (+ #xb8 r) io))
    ((mov    r/m64 r64)                      . (rex.w #x89 /r))
    ((mov    r64 r/m64)                      . (rex.w #x8b /r))
    ((movsq)                                 . (rex.w #xa5))
    ((movzx  r64 (r/m8 r8))                  . (rex.w #x0f #xb6 /r))
    ((movzx  r64 byte m)                     . (rex.w #x0f #xb6 /r))
    ((movzx  r64 (r/m16 r16))                . (rex.w #x0f #xb7 /r))
    ((movzx  r64 word m)                     . (rex.w #x0f #xb7 /r))
    ,@(arith-syntax-2 'mul t)
    ,@(arith-syntax-2 'neg t)
    ,@(arith-syntax-2 'not t)
    ,@(arith-syntax-1 'or  t)
    ((pop    r64)                            . ((+ #x58 r)))
    ((popcnt r64 r/m64)                      . (#xf3 rex.w #x0f #xb8 /r))
    ((popfq)                                 . (#x9d))
    ((push   r64)                            . ((+ #x50 r)))
    ((pushfq)                                . (#x9c))
    ((setcc r/m8)                            . (#x0f (+ #x90 cc) /0))
    ,@(shift-syntax 'sal t)
    ,@(shift-syntax 'sar t)
    ,@(shift-syntax 'shl t)
    ,@(shift-syntax 'shr t)
    ,@(arith-syntax-1 'sbb t)
    ((stosq)                                 . (rex.w #xab))
    ,@(arith-syntax-1 'sub t)
    ((syscall)                               . (#x0f #x05))
    ((sysret)                                . (#x0f #x07))
    ((test    rax imm32)                     . (rex.w #xa9 id))
    ((test    r/m64 imm32)                   . (rex.w #xf7 /0 id))
    ((test    qword m imm32)                 . (rex.w #xf7 /0 id))
    ((test    r/m64 r64)                     . (rex.w #x85 /r))
    ((xadd    r/m64 r64)                     . (rex.w #x0f #xc1 /r))
    ((xchg    r64 rax)                       . (rex.w (+ #x90 r)))
    ((xchg    r/m64 r64)                     . (rex.w #x87 /r))
    ((xchg    r64 r/m64)                     . (rex.w #x87 /r))
    ,@(arith-syntax-1 'xor t)))

(defparameter *x86-64-syntax-16/32-bit*
  (append *x86-64-syntax-16/32-bit-only* *x86-64-syntax-common*)
  "Syntax table for 16-bit mode.")

(defparameter *x86-64-syntax-64-bit*
  (append *x86-64-syntax-64-bit-only* *x86-64-syntax-common*)
  "Syntax table for 64-bit mode.")

(defun x86-64-syntax (bits)
  "Returns syntax table according to bit mode (16, 32 or 64)."
  (ecase bits
    ((16 32) *x86-64-syntax-16/32-bit*)
    (64 *x86-64-syntax-64-bit*)))
