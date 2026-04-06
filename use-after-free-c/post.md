---
layout: post
title: "Use-After-Free in C: Heaps, Undefined Behavior, and What GDB Shows"
date: 2026-03-19 12:00:00 +0000
---

**Use-after-free (UAF)** means using a pointer to heap memory **after** that memory has been returned to the allocator with `free`. In C, that is **undefined behavior**. It is also one of the most important bug classes in native code security: the same mistake that makes a program unreliable can, under the right conditions, become a serious memory corruption issue.

This post is for **learning and defense**. Exploit-style detail is only there to explain **why** teams care about UAF, not to give copy-paste attacks.

## How to Read This Post (Suggested Path)

1. **Basics:** What UAF means, a tiny C example, then pictures of heap reuse (including the lifetime timeline).
2. **Make it real:** The **GDB** section right after that; run the examples so the pointer behavior is something you have seen, not only read.
3. **Optional depth:** The **malloc / linked list** section if you want allocator internals; on a first pass you can **skip it** and come back later.
4. **Security story:** Why UAF is more than a crash, how abuse and RCE connect. There is a **plain-language story first**, then an **optional hex walkthrough** with fake addresses if you want the step-by-step replay.
5. **Build better software:** Mitigations and takeaways.

If anything feels dense, skip the sections marked **optional** and finish the GDB step; you can reread the rest once the core idea sticks.

## What Use-After-Free Means

You **own** a heap object while a pointer to it is valid and the object has not been freed. After `free(ptr)`, the allocator may **reuse** that storage for something else. Your old `ptr` is then a **dangling pointer**: the address might still look "fine" in a debugger, but the language rules say you must not read or write through it.

## A Minimal Example in C

```c
#include <stdio.h>
#include <stdlib.h>

int main(void) {
    int *p = malloc(sizeof(int));
    if (!p)
        return 1;
    *p = 42;
    free(p);
    /* dangling: p must not be used below */
    printf("%d\n", *p);  /* use-after-free (undefined behavior) */
    return 0;
}
```

Compilers and optimizers are allowed to assume you never do this. In real programs, UAF often hides behind longer lifetimes: a struct is freed, but some callback or cache still holds a pointer.

## How the Heap Can Reuse Memory

Conceptually, `free` does not "zero out" memory for you. It typically returns the chunk to an internal **free list** or similar structure so a future `malloc` can hand the same address out again. That is why two different parts of the program can end up with **different ideas** about what lives at the same address.

The diagrams below are simplified; real allocators (glibc `ptmalloc`, jemalloc, etc.) use more complex metadata and bins. An **optional** section later shows how free lists are often **singly or doubly linked** in a typical glibc-style design.

<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 720 200" role="img" aria-labelledby="uaf-heap-title">
  <title id="uaf-heap-title">Heap chunk lifecycle: live, freed, reused</title>
  <rect width="720" height="200" fill="#111"/>
  <text x="360" y="22" fill="#e0e0e0" font-family="ui-sans-serif, system-ui, sans-serif" font-size="14" text-anchor="middle">Simplified view: one heap chunk and a stale pointer</text>
  <rect x="24" y="44" width="200" height="132" rx="8" fill="#1a1a1a" stroke="#333"/>
  <text x="124" y="68" fill="#7eb8ff" font-family="ui-sans-serif, system-ui, sans-serif" font-size="12" text-anchor="middle">After malloc</text>
  <rect x="60" y="88" width="128" height="40" rx="4" fill="#2a2a2a" stroke="#555"/>
  <text x="124" y="112" fill="#e0e0e0" font-family="ui-monospace, monospace" font-size="12" text-anchor="middle">chunk (live)</text>
  <text x="124" y="148" fill="#cfcfcf" font-family="ui-monospace, monospace" font-size="11" text-anchor="middle">p points here</text>
  <path d="M124 138 L124 128" stroke="#7eb8ff" stroke-width="2" marker-end="url(#ah)"/>
  <rect x="260" y="44" width="200" height="132" rx="8" fill="#1a1a1a" stroke="#333"/>
  <text x="360" y="68" fill="#7eb8ff" font-family="ui-sans-serif, system-ui, sans-serif" font-size="12" text-anchor="middle">After free</text>
  <rect x="296" y="88" width="128" height="40" rx="4" fill="#2a1a1a" stroke="#884444"/>
  <text x="360" y="112" fill="#e0e0e0" font-family="ui-monospace, monospace" font-size="12" text-anchor="middle">chunk (freed)</text>
  <text x="360" y="148" fill="#cfcfcf" font-family="ui-monospace, monospace" font-size="11" text-anchor="middle">p is dangling</text>
  <rect x="496" y="44" width="200" height="132" rx="8" fill="#1a1a1a" stroke="#333"/>
  <text x="596" y="68" fill="#7eb8ff" font-family="ui-sans-serif, system-ui, sans-serif" font-size="12" text-anchor="middle">After malloc again</text>
  <rect x="532" y="88" width="128" height="40" rx="4" fill="#2a2a2a" stroke="#558855"/>
  <text x="596" y="112" fill="#e0e0e0" font-family="ui-monospace, monospace" font-size="12" text-anchor="middle">new object</text>
  <text x="596" y="148" fill="#cfcfcf" font-family="ui-monospace, monospace" font-size="10" text-anchor="middle">q may get same address;</text>
  <text x="596" y="162" fill="#cfcfcf" font-family="ui-monospace, monospace" font-size="10" text-anchor="middle">p is still wrong to use</text>
  <defs>
    <marker id="ah" markerWidth="8" markerHeight="8" refX="4" refY="4" orient="auto">
      <path d="M0,0 L8,4 L0,8 Z" fill="#7eb8ff"/>
    </marker>
  </defs>
</svg>

<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 720 120" role="img" aria-labelledby="uaf-time-title">
  <title id="uaf-time-title">Timeline: use must not cross free</title>
  <rect width="720" height="120" fill="#111"/>
  <text x="360" y="22" fill="#e0e0e0" font-family="ui-sans-serif, system-ui, sans-serif" font-size="14" text-anchor="middle">Lifetime rule: no read or write through p after free</text>
  <line x1="40" y1="70" x2="680" y2="70" stroke="#444" stroke-width="2"/>
  <circle cx="120" cy="70" r="8" fill="#558855"/>
  <text x="120" y="54" fill="#cfcfcf" font-family="ui-sans-serif, system-ui, sans-serif" font-size="11" text-anchor="middle">malloc</text>
  <circle cx="360" cy="70" r="8" fill="#aa6644"/>
  <text x="360" y="54" fill="#cfcfcf" font-family="ui-sans-serif, system-ui, sans-serif" font-size="11" text-anchor="middle">free</text>
  <circle cx="600" cy="70" r="8" fill="#884444"/>
  <text x="600" y="54" fill="#cfcfcf" font-family="ui-sans-serif, system-ui, sans-serif" font-size="11" text-anchor="middle">UAF if p used</text>
  <line x1="128" y1="70" x2="352" y2="70" stroke="#7eb8ff" stroke-width="4" opacity="0.85"/>
  <text x="240" y="98" fill="#7eb8ff" font-family="ui-sans-serif, system-ui, sans-serif" font-size="11" text-anchor="middle">OK window: valid heap object</text>
  <line x1="368" y1="70" x2="592" y2="70" stroke="#884444" stroke-width="4" opacity="0.5" stroke-dasharray="8 6"/>
  <text x="480" y="98" fill="#c98" font-family="ui-sans-serif, system-ui, sans-serif" font-size="11" text-anchor="middle">Stale p; must not dereference</text>
</svg>

## Watching a Stale Pointer in GDB

Build with debug symbols and without aggressive optimization so steps match the source lines you expect:

```bash
gcc -g -O0 -o uaf_demo uaf_demo.c
gdb ./uaf_demo
```

Example program (`uaf_demo.c`):

```c
#include <stdio.h>
#include <stdlib.h>

int main(void) {
    int *p = malloc(sizeof(int));
    if (!p)
        return 1;

    *p = 0x11111111;
    printf("live: *p = 0x%x\n", *p);

    free(p);

    /* Undefined behavior: for learning only, in a lab */
    *p = 0x22222222;

    return 0;
}
```

Useful GDB ideas (exact addresses and values will differ on your machine):

- Set a breakpoint on `main`, run, and print `p` after `malloc`.
- After `free(p)`, you can still **print `p`**; the pointer variable still holds the old address. That is the core lesson: **the pointer value is not magically invalidated**.
- Use `x/wx p` or `x/4bx p` to **examine** memory at the old address before and after `free`. You may still see old bits until something overwrites them.
- Optional: `watch *p` after the first assignment, then continue; when a write hits that address after `free`, you can see the event (behavior depends on allocator activity and HW watchpoint limits).

If you want a clearer "something else now owns this address" story, allocate again after `free` and print both the old dangling pointer and the new one; on many runs they may compare equal even though only the new pointer is legitimate.

```c
#include <stdio.h>
#include <stdlib.h>

int main(void) {
    int *p = malloc(sizeof(int));
    *p = 1;
    free(p);

    int *q = malloc(sizeof(int));
    *q = 2;

    printf("p=%p q=%p (often equal; only q is valid)\n", (void *)p, (void *)q);
    printf("via q: %d\n", *q);
    /* *p is still undefined behavior */
    return 0;
}
```

> **Checkpoint:** You should now have three concrete ideas: (1) UAF means using memory after `free`; (2) the allocator may hand the **same address** out again to a different pointer; (3) in GDB, the old variable still **shows** that address after `free`. The next section is **optional** allocator detail. After that, one continuous security narrative (plain language, then optional hex detail).

## Deep Dive (Optional): Do `malloc` Implementations Use Linked Lists?

**You can skip this on first read.** It answers "what does `free` leave behind in memory?" and why linked lists show up in explanations of glibc-style heaps. Understanding UAF does not require memorizing fast bins versus small bins.

There is no single answer for every libc or library. `malloc` is not one giant linked list of the whole heap. Typical allocators keep **metadata and free lists** so a new allocation can reuse a freed region without walking every byte of memory.

On **glibc** (the common `ptmalloc` family on many Linux systems), freed chunks are sorted into **bins** by size and state. Two linked-list shapes show up often:

- **Singly linked lists** back **fast bins**: each free chunk stores a pointer to the **next** chunk in that size class. The allocator can push and pop quickly (often LIFO).
- **Doubly linked lists** (in glibc, usually **circular** lists with forward `fd` and back `bk` pointers) appear in places like the **unsorted bin**, **small bins**, and **large bins**, so a chunk can be **unlinked** from the middle when it is allocated or merged with neighbors.

Other allocators (jemalloc, tcmalloc, mimalloc, embedded custom heaps) use different structures. The lesson for secure development is unchanged: **freed memory often still holds allocator bookkeeping**. A stray write through a dangling pointer can corrupt those pointers or chunk headers, not only "your" data.

The diagrams below are **schematic**. Real chunks include size fields, flags, and alignment; names `fd` and `bk` match common glibc-oriented explanations.

<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 720 210" role="img" aria-labelledby="sll-title">
  <title id="sll-title">Singly linked list of free chunks</title>
  <defs>
    <marker id="sll-arr" markerWidth="10" markerHeight="10" refX="9" refY="3" orient="auto">
      <path d="M0,0 L0,6 L9,3 z" fill="#7eb8ff"/>
    </marker>
  </defs>
  <rect width="720" height="210" fill="#111"/>
  <text x="360" y="22" fill="#e0e0e0" font-family="ui-sans-serif, system-ui, sans-serif" font-size="14" text-anchor="middle">Singly linked: each node points only to the next chunk</text>
  <text x="360" y="42" fill="#a0a0a0" font-family="ui-sans-serif, system-ui, sans-serif" font-size="11" text-anchor="middle">(conceptual fast-bin style list; "next" lives inside freed memory)</text>
  <rect x="32" y="95" width="64" height="40" rx="6" fill="#1e2a38" stroke="#7eb8ff"/>
  <text x="64" y="120" fill="#7eb8ff" font-family="ui-monospace, monospace" font-size="12" text-anchor="middle">head</text>
  <line x1="96" y1="115" x2="118" y2="115" stroke="#7eb8ff" stroke-width="2" marker-end="url(#sll-arr)"/>
  <rect x="120" y="95" width="100" height="40" rx="6" fill="#2a2a2a" stroke="#555"/>
  <text x="170" y="118" fill="#e0e0e0" font-family="ui-monospace, monospace" font-size="11" text-anchor="middle">free chunk A</text>
  <text x="170" y="132" fill="#888" font-family="ui-monospace, monospace" font-size="9" text-anchor="middle">next</text>
  <line x1="220" y1="115" x2="248" y2="115" stroke="#7eb8ff" stroke-width="2" marker-end="url(#sll-arr)"/>
  <rect x="250" y="95" width="100" height="40" rx="6" fill="#2a2a2a" stroke="#555"/>
  <text x="300" y="118" fill="#e0e0e0" font-family="ui-monospace, monospace" font-size="11" text-anchor="middle">free chunk B</text>
  <text x="300" y="132" fill="#888" font-family="ui-monospace, monospace" font-size="9" text-anchor="middle">next</text>
  <line x1="350" y1="115" x2="378" y2="115" stroke="#7eb8ff" stroke-width="2" marker-end="url(#sll-arr)"/>
  <rect x="380" y="95" width="100" height="40" rx="6" fill="#2a2a2a" stroke="#555"/>
  <text x="430" y="118" fill="#e0e0e0" font-family="ui-monospace, monospace" font-size="11" text-anchor="middle">free chunk C</text>
  <text x="430" y="132" fill="#888" font-family="ui-monospace, monospace" font-size="9" text-anchor="middle">next</text>
  <line x1="480" y1="115" x2="518" y2="115" stroke="#7eb8ff" stroke-width="2" marker-end="url(#sll-arr)"/>
  <text x="560" y="122" fill="#aa8866" font-family="ui-monospace, monospace" font-size="13" text-anchor="middle">NULL</text>
  <text x="360" y="188" fill="#a0a0a0" font-family="ui-sans-serif, system-ui, sans-serif" font-size="11" text-anchor="middle">Traversal follows a single chain; no back pointer in this pattern.</text>
</svg>

<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 720 240" role="img" aria-labelledby="dll-title">
  <title id="dll-title">Doubly linked list of free chunks</title>
  <defs>
    <marker id="dll-f" markerWidth="10" markerHeight="10" refX="9" refY="3" orient="auto">
      <path d="M0,0 L0,6 L9,3 z" fill="#7eb8ff"/>
    </marker>
    <marker id="dll-b" markerWidth="10" markerHeight="10" refX="1" refY="3" orient="auto">
      <path d="M9,0 L9,6 L0,3 z" fill="#dd9966"/>
    </marker>
  </defs>
  <rect width="720" height="240" fill="#111"/>
  <text x="360" y="22" fill="#e0e0e0" font-family="ui-sans-serif, system-ui, sans-serif" font-size="14" text-anchor="middle">Doubly linked: forward (fd) and back (bk) pointers</text>
  <text x="360" y="42" fill="#a0a0a0" font-family="ui-sans-serif, system-ui, sans-serif" font-size="11" text-anchor="middle">(sketch; glibc bin lists are circular in the real implementation)</text>
  <text x="88" y="62" fill="#dd9966" font-family="ui-monospace, monospace" font-size="10">bk</text>
  <line x1="372" y1="68" x2="342" y2="68" stroke="#dd9966" stroke-width="2" marker-end="url(#dll-b)"/>
  <line x1="232" y1="68" x2="202" y2="68" stroke="#dd9966" stroke-width="2" marker-end="url(#dll-b)"/>
  <rect x="90" y="88" width="110" height="52" rx="6" fill="#2a2a2a" stroke="#555"/>
  <text x="145" y="112" fill="#e0e0e0" font-family="ui-monospace, monospace" font-size="11" text-anchor="middle">chunk A</text>
  <text x="145" y="128" fill="#888" font-family="ui-monospace, monospace" font-size="9" text-anchor="middle">fd / bk</text>
  <rect x="230" y="88" width="110" height="52" rx="6" fill="#2a2a2a" stroke="#555"/>
  <text x="285" y="112" fill="#e0e0e0" font-family="ui-monospace, monospace" font-size="11" text-anchor="middle">chunk B</text>
  <text x="285" y="128" fill="#888" font-family="ui-monospace, monospace" font-size="9" text-anchor="middle">fd / bk</text>
  <rect x="370" y="88" width="110" height="52" rx="6" fill="#2a2a2a" stroke="#555"/>
  <text x="425" y="112" fill="#e0e0e0" font-family="ui-monospace, monospace" font-size="11" text-anchor="middle">chunk C</text>
  <text x="425" y="128" fill="#888" font-family="ui-monospace, monospace" font-size="9" text-anchor="middle">fd / bk</text>
  <text x="88" y="182" fill="#7eb8ff" font-family="ui-monospace, monospace" font-size="10">fd</text>
  <line x1="200" y1="168" x2="228" y2="168" stroke="#7eb8ff" stroke-width="2" marker-end="url(#dll-f)"/>
  <line x1="340" y1="168" x2="368" y2="168" stroke="#7eb8ff" stroke-width="2" marker-end="url(#dll-f)"/>
  <text x="520" y="172" fill="#a0a0a0" font-family="ui-monospace, monospace" font-size="10">...</text>
  <text x="360" y="222" fill="#a0a0a0" font-family="ui-sans-serif, system-ui, sans-serif" font-size="11" text-anchor="middle">Removing B requires rewiring A's fd and C's bk; doubly linked lists make that possible.</text>
</svg>

## Why UAF Is More Than a Crash (Security in One Arc)

From a security angle, the bug is always the same: **the program trusts a pointer** while **the memory at that address is no longer guaranteed to be the old object**. A later `malloc` can put **something else** in the same slot (you may have seen `p` and `q` print the same address in GDB). An attacker does not "magically" get RCE from that alone; they try to line up three ideas:

1. **Reuse:** influence allocation sizes and order so the freed slot is refilled while a **stale pointer** still exists (same story as `p` / `q`, but driven by real input paths).
2. **Shape bytes:** the refilled object holds data the attacker can affect, so the bytes at the stale address become **wrong for what the code assumes** (wrong length, wrong flags, or wrong **pointer fields**).
3. **Turn bytes into behavior:** if the program later **reads a pointer** from that address and **jumps through it** (virtual call, function pointer, return address in some chains), the CPU runs whatever address was stored there. **RCE** means ending up at **machine instructions or a chosen control-flow path** the attacker wanted, not only a crash.

Side effects along the way include **data-only bugs** (bad branches), **leaks** (reads that expose secrets or addresses and help beat **ASLR**), and **heap metadata corruption** (writes that break allocator lists). Full compromises usually stack many steps and fight **RELRO**, **NX**, **CFI**, and similar mitigations. This post does **not** give exploit recipes; it gives you language to read advisories and to **fix the root bug early**.

### The Same Address, Two Meanings (Story Before Hex)

Follow this short sequence **before** any addresses. It is the same plot as the GDB `p` / `q` example, with one extra twist: the second owner of the slot is **attacker-influenced**.

1. **Name A:** a variable still points at heap address **H** after `free` (dangling).
2. **Recycle:** the allocator gives **H** to a **new** allocation; the program has a **legitimate** pointer **B** to **H**.
3. **Different views:** through **B**, memory is "the new object"; through **A**, the program still acts as if the **old** object (or old layout) lived there. Only the **B** view is valid in C; using **A** is undefined.
4. **Attacker input:** if content behind **B** comes from the network or file, the bytes at **H** can be **crafted**.
5. **Bad outcome:** any **load** or **jump** that goes through **A** interprets those crafted bytes as **vtable pointers**, **lengths**, **function pointers**, and so on. That is how a **logic bug** escalates toward **control of where the CPU jumps next**. Turning one bad jump into **full RCE** usually needs more tricks (**ROP**, leaks, repeated writes) because of **NX** and **ASLR**.

If this five-step list makes sense, the long hex section below is only **the same story with labels** so you can match "Step 3" to "recycle slot H."

### Optional: Same Story With Fake Addresses (Detailed Replay)

**Read this only after** the five steps above. **Vtable in one line:** in many C++ implementations, the first bytes of an object can hold a **pointer to a table of function pointers**; a virtual call loads that pointer, reads a slot, and jumps there. The example uses that pattern because it maps cleanly to "bytes at H become a jump target." The addresses are **fabricated**; **ASLR** and allocator state change every run.

| Step | One-line meaning |
|------|------------------|
| 1 | An object is allocated at fake heap address **H**; program keeps `stale = H`. |
| 2 | Object is freed; `stale` still equals **H** (dangling). |
| 3 | New `malloc` returns **H** again; call that pointer `fresh`; only `fresh` is valid. |
| 4 | Attacker-controlled data fills the chunk at **H**; first word might point to a **fake table** at **T**. |
| 5 | Code path uses `stale` in a virtual-style call; CPU jumps using pointers taken from **H** and **T**. |
| 6 | **NX** pushes the attacker toward **ROP** and friends; **ASLR** pushes them toward **leaks**; one jump is rarely the whole chain. |
| 7 | **Fix UAF** removes the `stale` / `fresh` alias at **H**, so the story stops before controlled jumps. |

**Concrete labels (still fake):** let **H** be `0x000055555575a020`, **T** be `0x00005555557bf000`, and a placeholder jump target be `0x00007ffff6e114d0` (in reality something in a mapped binary, often found after a leak, not "random" hex).

```text
Address             Content (little-endian 64-bit example)
0x000055555575a020   0x00005555557bf000   ← treated as vtable pointer → points to fake table T
```

At **T**, the first 8-byte slot might hold `0x00007ffff6e114d0`. A virtual call through `stale` loads from **H**, follows to **T**, loads that slot, and **indirectly jumps**.

<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 720 200" role="img" aria-labelledby="uaf-rce-title">
  <title id="uaf-rce-title">Stale and fresh pointers alias the same address before a bad indirect call</title>
  <rect width="720" height="200" fill="#111"/>
  <text x="360" y="22" fill="#e0e0e0" font-family="ui-sans-serif, system-ui, sans-serif" font-size="13" text-anchor="middle">Same physical address, two names in the program</text>
  <rect x="280" y="50" width="160" height="72" rx="8" fill="#2a2a2a" stroke="#7eb8ff"/>
  <text x="360" y="78" fill="#7eb8ff" font-family="ui-monospace, monospace" font-size="12" text-anchor="middle">heap chunk</text>
  <text x="360" y="98" fill="#e0e0e0" font-family="ui-monospace, monospace" font-size="11" text-anchor="middle">0x000055555575a020</text>
  <text x="360" y="116" fill="#a0a0a0" font-family="ui-sans-serif, system-ui, sans-serif" font-size="10" text-anchor="middle">bytes here include a pointer into a fake vtable</text>
  <text x="120" y="150" fill="#dd9966" font-family="ui-monospace, monospace" font-size="11" text-anchor="end">stale</text>
  <path d="M130 145 L270 95" stroke="#dd9966" stroke-width="2" fill="none"/>
  <text x="600" y="150" fill="#7eb8ff" font-family="ui-monospace, monospace" font-size="11" text-anchor="start">fresh</text>
  <path d="M590 145 L450 95" stroke="#7eb8ff" stroke-width="2" fill="none"/>
  <text x="360" y="182" fill="#a0a0a0" font-family="ui-sans-serif, system-ui, sans-serif" font-size="11" text-anchor="middle">Victim indirect call via stale uses attacker-shaped words at that address.</text>
</svg>

**Step 7 (defender view):** mitigations (**full RELRO**, **CFI**, hardened allocators) complicate later stages, but **removing the UAF** removes the stable **alias** at **H**.

### Wait: Does the CPU "Run" the Bytes You Put in `malloc` Memory?

**Usually not, and that is the confusing part.** Many learners picture: "I store a series of bytes in a heap chunk; the CPU runs those bytes as shellcode." On typical modern Linux (and many other OS setups), **heap pages are not executable**. The hardware and OS use **NX** (no-execute, part of **W xor X**): that memory is for **data**, not for **instructions**. So if you literally placed shellcode bytes in a `malloc` buffer, a jump **into** that buffer would often **fault** instead of running your code.

**What actually happens in many attacks:** the attacker still places **bytes** in the chunk, but the **program interprets** some of those bytes as a **pointer** (an address), not as opcodes. Example: eight bytes at **H** might be the value `0x00007ffff6e114d0`. The vulnerable code does **not** say "execute the bytes at H." It says something like "load a pointer from H, then **indirect jump** to wherever that pointer points." The CPU then starts executing instructions at **`0x00007ffff6e114d0`**, which usually lies inside a **library or the main binary** (regions that **are** mapped **executable** and **read-only**). Those instructions were **already there** on disk; the attacker only **chose the entry point** by forging pointer values.

**So RCE is not "run my bytes from the heap."** It is more like **"trick the program into jumping to an address I control"** where that address is inside **existing** executable mappings. From one bad jump, attackers often build longer behavior with **return-oriented programming (ROP)**: chaining short instruction sequences (**gadgets**) that already exist in libc and the binary, while **NX** stops simple "shellcode on the heap" stories.

**Historical note:** on older systems or misconfigured builds, stack/heap could be executable, or attackers could call **`mprotect`**-style primitives to flip permissions; that is a different story. The default mental model today should be: **crafted heap bytes steer control flow; execution happens in mapped code segments, not by decoding the heap bytes as instructions.**

Other paths to RCE from the same bug class include corrupting a **function pointer** instead of a vtable, overwriting a **return address** if a stale pointer reaches the stack (less common directly from heap UAF), or upgrading to an **arbitrary write** first and then patching the GOT where **RELRO** is not full. The pattern is always: **confuse the program about what lives at a given address**, then let normal machine instructions do the dangerous load and jump.

## Mitigating These Classes of Security Bugs (Secure Development)

Use-after-free sits in a wider family of **memory corruption** issues: double free, buffer overflows, uninitialized reads, and type confusion through stale pointers. Mitigation is not a single tool; it is **how you design, build, test, and review** native code. The points below are aimed at **developers** who want a practical secure-development posture, not a one-off checklist.

### Clear Ownership and Lifetime Discipline

- **One clear owner** per heap object: decide who allocates, who frees, and who may read or write. Put that contract in comments, API docs, or type names where it helps.
- **Shorten pointer lifetimes**: return handles or indices instead of raw pointers when you can; scope `malloc`/`free` pairs as tightly as the design allows.
- **After `free`, stop using the pointer**: set the owning variable to `NULL` when there is a single obvious owner; it does not fix every bug, but it turns many UAF into fast, obvious failures on common platforms.
- **Callbacks and caches** are frequent UAF sources: if an object can be destroyed while another layer still holds a pointer, you need explicit invalidation, reference counting, or a different architecture.

### Safer Languages and Boundaries

- **Prefer memory-safe languages** for new components where performance and ecosystem allow (Rust, managed runtimes, or other options your team can support).
- For **C/C++ at boundaries** (FFI, parsers, crypto, device-facing code), treat the unsafe side as a **small, reviewed surface** and keep higher-level logic in safer layers.
- In **C++**, prefer RAII (`std::unique_ptr`, containers) over manual `new`/`delete` to tie lifetimes to scope and reduce dangling pointers.

### Tooling in Development and CI

- **AddressSanitizer (ASan)** on debug and CI builds catches many heap UAF, double frees, and overflows with low integration cost.
- **UndefinedBehaviorSanitizer (UBSan)** helps with other C undefined behavior that can interact badly with optimizations.
- **Fuzzing** (libFuzzer, AFL++, structured harnesses) plus sanitizers finds object-lifetime bugs in parsers and protocol handlers that unit tests miss.
- Enable **compiler hardening** your platform supports (`-D_FORTIFY_SOURCE` where appropriate, stack protection, PIE, RELRO) as **defense in depth**, not as a substitute for fixing root causes.

### Coding Habits That Reduce Heap Mistakes

- **Symmetry**: every `malloc`/`calloc`/`realloc` path should have one obvious `free` (or transfer of ownership documented elsewhere).
- **Avoid "use after logic says done"**: freeing inside error paths and then falling through to code that still touches the pointer is a common defect; use `goto cleanup` patterns or early returns with a single teardown block.
- **Do not reuse freed pointers** for new meaning; allocate fresh variables so code reviews can follow lifetimes.

### Code Review and Secure SDLC

- **Review native changes** for lifetime: who holds pointers, what invalidates them, what happens on error paths.
- **Threat model** components that parse untrusted input or run at high privilege; those deserve stricter tests and sanitizer coverage.
- **Reproduce bugs under sanitizers** before closing tickets; if a crash is "only" in production builds, treat that as a signal to improve test fidelity.

## Lab Only: Minimal C Program Where UAF Reaches a Shell (RCE)

**Legal and safety:** run this **only** on a machine and account **you own**, in a **throwaway VM** or lab image. **Never** aim vulnerable code at others' systems. The program below is **deliberately wrong** so you can see one complete chain: **stale pointer** + **reused chunk** + **indirect call through a function pointer** + **`execve("/bin/sh", ...)`** (local RCE demo).

**What this is not:** a remote exploit, a bypass of modern hardening in real browsers, or a pattern to ship. It is the **smallest** shape of “UAF + call through forged dispatch” that ends in a **new program** (here, a shell).

### Idea in One Sentence

`w1` is freed but the code still calls `w1->fn()`. The allocator gives the **same bytes** to `w2`, which sets `fn` to `bad`. The stale call runs **`bad`**, which runs **`execve`**; that is **arbitrary code choice** in the sense of **choosing what runs next** (here, a shell).

### Source (Also in the Topic Folder as `uaf_lab_rce_demo.c`)

```c
/*
 * LAB / EDUCATION ONLY: intentionally vulnerable.
 */
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>

static void good(void) {
    puts("good path");
}

static void bad(void) {
    puts("[!] UAF: stale pointer called bad().");
    fflush(stdout);
    char *argv[] = {"/bin/sh", "-i", NULL};
    char *envp[] = {NULL};
    execve("/bin/sh", argv, envp);
    perror("execve");
    _exit(127);
}

typedef struct {
    void (*fn)(void);
    unsigned id;
} Widget;

int main(void) {
    Widget *w1 = malloc(sizeof(Widget));
    w1->fn = good;
    w1->id = 1;
    free(w1);

    Widget *w2 = malloc(sizeof(Widget));
    w2->fn = bad;
    w2->id = 2;

    w1->fn();   /* BUG: use-after-free; dispatches through w2->fn */

    free(w2);
    return 0;
}
```

### Build and Run

```bash
cd use-after-free-c
gcc -O0 -g uaf_lab_rce_demo.c -o uaf_lab_rce_demo
./uaf_lab_rce_demo
```

You should see the UAF message, then an **interactive shell** (exit with `exit` or Ctrl-D). **AddressSanitizer** usually trips on the **first use** of the stale pointer (the load of `fn` before the call), so you get a **heap-use-after-free report** and typically **do not** reach `execve`:

```bash
gcc -O0 -g -fsanitize=address uaf_lab_rce_demo.c -o uaf_lab_asan
./uaf_lab_asan
```

### Fix (Own the Lifetime)

After `free(w1)`, do **not** call through `w1`. Set `w1 = NULL`, or restructure so the call uses only `w2` after reallocation. In real code, **one owner** and **no stale aliases**.

## Takeaways

Use-after-free is **undefined behavior in C**, a common source of **crashes and security flaws**, and easy to miss because **addresses still look plausible in GDB**. Treat any use after `free` as a bug, learn the heap lifecycle with small programs and a debugger, and pair that with **ownership discipline, sanitizers, fuzzing, and review** so these classes of issues are caught long before production.

## Hands-on follow-up

If you want structured practice beyond a single post (low-level debugging, memory lifetimes, and building safer habits in native code), see the [Hands-On Technical Mentorship Program](../hands-on-technical-mentorship-program/preview.html#top) (overview, format, and how sessions are run).

I conduct trainings and workshops on topics like this and related areas: use-after-free and heap behavior, GDB-focused labs, safer C/C++ practice, and adjacent themes (exploit-mitigation awareness, code review for lifetime bugs, and more). If your team wants a tailored session, reach out via the [blog home](../) or the contact options linked from there.
