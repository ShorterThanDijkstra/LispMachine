;;;; -*- Mode: Lisp -*-
;;;; Author:
;;;;     Yujian Zhang <yujian.zhang@gmail.com>
;;;; Description:
;;;;     Paging functions.
;;;; References:
;;;;     [1] AMD64 Architecture Programmer's Manual Volume 2: System Programming.
;;;;         Publication No. 24593; Revision: 3.25
;;;; License:
;;;;     GNU General Public License v2
;;;;     http://www.gnu.org/licenses/gpl-2.0.html
;;;; Copyright (C) 2015 Yujian Zhang

(in-package :cc)

(defparameter *paging-32*
  `(
    ;;; Technical details for 2 MB page translation can be found in
    ;;; section 5.3.4 (2-Mbyte Page Translation) of [1].
    ;;; At the beginning, paging setup is based on
    ;;; http://wiki.osdev.rg/Entering_Long_Mode_Directly
    ;;;
    ;;; Setup two mappings:
    ;;;   1) Identity mapping for bottom 2 MB physical address.
    ;;;   2) Map ALL available physical memory to higher memory space
    ;;;      starting from -2GB memory space below recursive mapping. As
    ;;;      recursive mapping occupies 512 GB and starts from #xffffff8000000000,
    ;;;      kernel starts from #xffffff7f80000000.
    ;;; Identity mapping will be removed after entering 64 bit mode
    ;;; by calling function unmap-lower-memory.
    ;;;
    ;;; Suppose PML4 points to address A (`pml4-base` below), then there are
    ;;; five 4 KB memory regions to be processed by this function (note that we put
    ;;; identity mapping after kernel mapping as identity mapping will be unmapped):
    ;;;   A          .. A + #x0fff: Page Map Level 4
    ;;;   A + #x1000 .. A + #x3fff: Page Directory Pointer Table for higher half mapping.
    ;;;   A + #x2000 .. A + #x4fff: Page Directory Table for higher half mapping.
    ;;;   A + #x3000 .. A + #x1fff: Page Directory Pointer Table for identity mapping.
    ;;;   A + #x4000 .. A + #x2fff: Page Directory Table for identity mapping.

    setup-paging

    (equ     pml4-base #x10000)
    (equ     page-table-size 4096)  ; Number of bytes occupied by a page table.

    ;; Page flags.
    (equ     page-present           (expt 2 0))
    (equ     page-writable          (expt 2 1))
    (equ     page-user-accessible   (expt 2 2))
    (equ     page-write-through     (expt 2 3))
    (equ     page-cache-disable     (expt 2 4))
    (equ     page-accessed          (expt 2 5))
    (equ     page-dirty             (expt 2 6))
    (equ     page-pde.ps            (expt 2 7))
    (equ     page-global            (expt 2 8))
    (equ     page-no-execuite       (expt 2 63))
    (equ     page-table-flag (+ page-present page-writable))
    (equ     page-entry-flag (+ page-table-flag page-pde.ps)) ; In addition to above flags, set PDE.PS for 2 MB page.

    (equ     kernel-virtual-base #xffffff7f80000000) ; Start virtual address for higher half kernel.

    ;; The position to store memory size.
    (equ     memory-size-physical-addr (+ mm-entries-physical-addr (* mm-entry-max mm-entry-size)))
    (equ     memory-size-virtual-addr (+ kernel-virtual-base memory-size-physical-addr))
    ;; Maximum number of page tables.
    (equ     page-table-end-next #x70000)
    (equ     page-table-max (/ (- page-table-end-next pml4-base) page-table-size))
    (equ     page-table-bitmap-virtual-addr (+ memory-size-virtual-addr 8)) ; 8 byte to store memory size.
    ;; In the calculation below, first 8 for bitmap-offset, second 8 because 1 bytes contains 8 bits.
    (equ     page-frame-bitmap-virtual-addr
             (+ page-table-bitmap-virtual-addr 8 (ceiling page-table-max 8)))
    (push    edx)
    (push    ecx)
    (push    ebx)
    (push    edi)

    ;; Firstly check the size of the kernel. When kernel is firstly loaded
    ;; (before relocated), the memory map of our code/data below 1 MB is like:
    ;;   0 - some BIOS stuff
    ;;     - kernel (starting from #x7c00)
    ;;     - page tables (starting from pml4-base)
    ;;     - FREE
    ;;     - stack
    ;;     - memory map (starting from mm-count-physical-addr)
    ;;     - memory size (starting from memory-size-physical-addr), page table bitmap
    ;;       and page frame bitmap
    ;;     - other BIOS stuff
    ;; If kernel size is too big, code about page tables will trash
    ;; the kernel. So the following check is needed.
    ;; TODO: we need to make sure that page tables do not run into the region for
    ;;       stack and memory map.
    (mov     edx kernel-physical-end)
    (cmp     edx pml4-base)
    (jb      .page-continue)
    ;; If code comes to this branch, increase pml4-base appropriately.
    .panic
    (hlt)
    (jmp     short .panic)

    .page-continue
    (call32  get-memory-size)
    ;; Store the memory size.
    (mov     ecx memory-size-physical-addr)
    (mov     (ecx) eax)
    (mov     (ecx 4) edx)
    ;; TODO. So far we only handle < 4GB memory. As memory size is in
    ;; EDX:EAX, we ignore the value in EDX for now. Use EDX to store
    ;; the memory size (< 4 GB).
    (mov     edx eax)

    ;; Zero out the 5 * 4 kB buffer.
    (mov     edi pml4-base)
    (mov     ecx #x1400)
    (xor     eax eax)
    (cld)
    (rep     stosd)
    (mov     edi pml4-base)

    ;; Build the Page Map Level 4.
    ;; First set entry the identity mapping.
    (mov     eax edi)
    (add     eax #x3000)              ; Address of the Page Directory Pointer Table for identity mapping.
    (or      eax page-table-flag)
    (mov     (edi) eax)
    ;; Secondly set entry for higher half mapping.
    (sub     eax #x2000)              ; Address of the Page Directory Pointer Table for higher half mapping.
    (mov     ebx 510)
    (mov     (ebx*8 edi) eax)
    (mov     eax 511)                 ; Now starts recursive mapping.
    (shl     eax 3)
    (add     eax edi)
    (mov     (eax) eax)

    ;; Build the Page Directory Pointer Table for identity mapping.
    (mov     eax edi)
    (add     eax #x4000)              ; Address of the Page Directory.
    (or      eax page-table-flag)
    (mov     (edi #x3000) eax)

    ;; Build the Page Directory Table for identity mapping. Just map 2 MB.
    (mov     eax page-entry-flag) ; Effectively point EAX to address #x0.
    (mov     (edi #x4000) eax)

    ;; Build the Page Directory Pointer Table for higher half mapping.
    (mov     edi (+ pml4-base #x1000))
    (mov     eax edi)
    (add     eax #x1000)              ; Address of the Page Directory.
    (or      eax page-table-flag)
    ;; TODO: we only map maximum 1 GB memory now. So we only handle the 2nd last entry here.
    (mov     ebx 510)                 ; The second last entry in the 512 entry table.
    (mov     (ebx*8 edi) eax)

    ;; Build the Page Directory Table for higher half mapping.
    (add     edi #x1000)
    (mov     eax page-entry-flag) ; Effectively point EAX to address #x0.
    .loop-page-directory-table
    (mov     (edi) eax)
    (add     eax #x200000)            ; Increase 2 MB.
    (add     edi 8)
    (cmp     eax edx)                 ; Has all memory been mapped?
    (jb      .loop-page-directory-table)

    (pop     edi)
    (pop     ebx)
    (pop     ecx)
    (pop     edx)

    (ret)))

(defparameter *paging*
  `(
    ;;; Remove identity mapping of bottom 2 MB.
    ,@(def-fun 'unmap-lower-memory nil
        `(
          (mov     rdi pml4-base)
          (mov     qword (rdi) 0)
          (invlpg  (abs 0))))

    ;; Mask to get bits 12-51 from page table entry for the physical address of the frame.
    (equ     page-frame-mask #x000ffffffffff000)

    ;;; Function pointed-frame. Returns page frame address (physical).
    ;;; Input:
    ;;;     RDI: page table entry address (virtual)
    ;;; Output:
    ;;;     RAX: page frame address. 0 if page table entry is invalid
    ;;;          (e.g. not present)
    ,@(def-fun'pointed-frame nil
          `(
            (mov     rax (rdi))
            (test    eax page-present)
            (je      .not-present)
            (mov     rsi page-frame-mask)
            (and     rax rsi)
            (jmp     short .done)
            .not-present
            (xor     eax eax)
            .done))

    ;;; Function page-directory-entry-set. Return a page directory entry (PDE) given
    ;;;   the physical frame base address and flags
    ;;; Input:
    ;;;     RDI: page frame base address (should be aligned at 2 MB boundary) and
    ;;;          smaller than 2^52 (due to x86-64 architecture limitation)
    ;;;     RSI: page flags
    ;;; Output:
    ;;;     RAX: the page directory entry (PDE).
    ;;; Technical details for 2 MB PDE can be found in section 5.3.4
    ;;; (2-Mbyte Page Translation) of [1], especially Figure 5-25. "2-Mbyte PDE - Long Mode"
    ,@(def-fun 'page-directory-entry-set nil
        `(
          (equ     pde-physical-base-address-mask #xfff00000001fffff)
          (mov     rdx pde-physical-base-address-mask)
          (test    rdi rdx)
          (jne     .panic)
          (or      rdi rsi)
          (mov     rax rdi)
          (jmp     short .done)
          .invalid-physical-base-address
          .panic
          (hlt)
          (jmp     short .panic)
          .done))
    ))
