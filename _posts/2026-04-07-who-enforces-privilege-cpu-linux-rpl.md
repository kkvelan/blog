---
layout: post
title: "Who Enforces Privilege: The CPU, Linux, or Both? Real Mode, RPL, and Syscalls in Plain English"
date: 2026-04-07 12:00:00 +0000
---

This article is for students and security people who have seen **local privilege escalation** on Linux and wondered what actually changed under the hood. It stays in **simple English**. It mixes a personal learning path with facts you can cross-check in the **Intel manuals**, **Understanding the Linux Kernel**, and the **[OSDev Wiki](https://wiki.osdev.org/Main_Page)**.

## The pattern that started the question

Years ago, on Linux tests, I kept seeing the same end state:

1. Run a **local privilege escalation** exploit.
2. Run **`id`**.
3. See **user id 0** (root).

The interesting question is not the exploit string. It is: **what changed in the system?** And behind that: **who** is supposed to stop things—the **operating system**, the **processor**, or **both**?

![Two layers: Linux policy vs CPU hardware rules]({{ site.baseurl }}/hardware-kernel-privilege-rpl/layers-hardware-kernel.svg)

## Two different jobs

Roughly:

- **Linux** keeps **records** for each process: user id, group id, **capabilities**, and so on. When you use a **syscall**, kernel code runs and **decides** if that operation is allowed. The **`id`** command reads what the kernel **currently** has on file for your process. The CPU does not “know” Unix **root** as a person; it runs instructions.

- The **CPU** (with **MMU** help on modern systems) enforces **hard rules**: **user mode vs kernel mode**, **who can touch which memory**, and **how** you are allowed to enter kernel code. **Syscalls** (and interrupts) are the **normal door** into the kernel, not a random jump.

Both matter. Confusing them makes exploits feel like magic.

## How I learned to separate them

I stopped treating the exploit as the whole curriculum and **read the machine**—**Intel’s documentation** helped. I wrote a **bootloader** (512-byte stage 1, then stage 2), then moved from **real mode** into **protected mode** (**A20**, **GDT**, **LDT**). That path matches what many **OS bring-up** tutorials describe; **[OSDev’s protected mode](https://wiki.osdev.org/Protected_Mode)** articles are a solid free companion even if their examples are in C or assembly.

## Real mode: no hardware “this is kernel memory” stop

After reset, x86-class CPUs start in **real mode** (8086-style). In that world there are **no privilege rings** like you later use for “user vs kernel.” There is **no protected-mode segment privilege check** that faults because “this byte belongs to the OS.”

So running code can **read and write** large parts of the address space—including **low memory** where structures like the **interrupt vector table** live—without the CPU saying “that is **kernel-only**.” Classic **DOS** lived in that kind of world.

![Real mode vs protected mode (simplified)]({{ site.baseurl }}/hardware-kernel-privilege-rpl/real-vs-protected.svg)

**Further reading:** [OSDev: Real mode](https://wiki.osdev.org/Real_Mode).

### Why early PC malware could be so destructive

In that environment, **one program** could often **touch almost any memory** the address lines could reach, with **little hardware pushback**. Malware did not need a syscall story to **scribble over important bytes**. Today we also had weak backups and a lot of trust in software—but the **thin hardware boundary** is the part that connects to **why protected mode and later paging matter**.

## Protected mode: GDT, selectors, and RPL

**Protected mode** introduces tables of **segment descriptors** (**GDT** / **LDT**). Each descriptor describes a region and carries **privilege information** (the **DPL**, descriptor privilege level, in the segment story).

Programs use a **16-bit selector** to pick a descriptor. The low **two bits** of the selector are the **RPL**—**Requested Privilege Level**.

![Segment selector and RPL (concept)]({{ site.baseurl }}/hardware-kernel-privilege-rpl/selector-rpl-bits.svg)

The CPU combines **RPL** with **CPL** (current privilege level, tied to the **code segment**) and the descriptor’s **DPL** when it decides if a **segment load** or some **far** references are legal. The point in one sentence: **RPL is part of how the hardware refuses “convenient” segment use that would widen privilege.**

| Term (x86 segment world) | Plain meaning |
|--------------------------|----------------|
| **CPL** | Current privilege level—tied to the running code segment; “who the CPU considers active.” |
| **DPL** | Descriptor privilege level—stored in the GDT/LDT entry for that segment. |
| **RPL** | Requested privilege level—two bits in the **selector**; joins CPL/DPL in the access rules. |

Exact comparisons use `max(CPL,RPL)` in several data-segment cases; when you need precision, use the **Intel SDM** or an OSDev page rather than memorising one formula.

**Further reading:** [OSDev: Global Descriptor Table](https://wiki.osdev.org/Global_Descriptor_Table), [Segment Selector](https://wiki.osdev.org/Segment_Selector), [Privilege](https://wiki.osdev.org/Privilege).

### A plain English “what if the CPU did not check?”

Picture a **descriptor** that is only meant for **supervisor** use—kernel-private data. If the CPU **did not** enforce **DPL / RPL / CPL** rules on **data segment** loads, a **normal program** could load that selector into a data segment register and then **read or write** that memory with **ordinary** load/store instructions. **No syscall.** **No kernel bug** needed for *that* kind of collapse—**isolation would be gone**. In real hardware, illegal loads are supposed to **fault**.

That thought experiment is **not** the same as “how I become root on Linux.” It explains **why** learning RPL mattered to me: **privilege is enforced in more than one place**, and some checks are **silicon rules**, not “the `passwd` file.”

## Rings and the syscall door

On x86 Linux you still hear **ring 0** (kernel / supervisor) and **ring 3** (user). User code is **not** supposed to poke kernel memory directly; it asks through **syscalls** and similar **controlled entry**.

![Rings (concept) and syscall]({{ site.baseurl }}/hardware-kernel-privilege-rpl/rings-syscall.svg)

![Syscall flow at a high level]({{ site.baseurl }}/hardware-kernel-privilege-rpl/syscall-flow.svg)

**Further reading:** [OSDev: System calls](https://wiki.osdev.org/System_Calls).

### What Linux does **inside** a syscall (still plain English)

When your program issues a **syscall**, the **CPU** switches to **kernel mode** so **kernel code** can run. Then **Linux’s own code** runs the **policy**:

- **Who is this process?** (stored **UID**, **GID**, **capabilities**, sometimes more.)
- **Is this operation allowed** for that identity—open that file, mount, **ptrace**, and so on?

**Allow** or **deny** (for example `EPERM`) is decided by **kernel logic** and **data structures**, on top of the hardware having gotten you into the kernel **safely** through the syscall path. The **hardware** does not print **`id`** output.

## Where RPL fits vs where “root” fits

- **RPL** belongs to the **x86 segment protection** story in **protected mode**—a **hardware** participation rule.

- **`id` showing 0** belongs to **Linux’s saved idea of your user id** for that process—a **kernel bookkeeping** story.

So **local privilege escalation** that ends with **`id` as root** is usually **not** “we fooled RPL.” It is **kernel trust got broken**: memory corruption, logic bugs, **credential structures** overwritten, **execution** in kernel context, and similar. **`id` changes because the kernel’s saved idea of your user id changed.**

![Typical LPE outcome: kernel state, not CPU ring magic]({{ site.baseurl }}/hardware-kernel-privilege-rpl/lpe-kernel-state.svg)

## 64-bit Linux today (short honest note)

On **64-bit x86-64 Linux**, **paging** (**MMU** + **page tables**) carries most of the **user vs kernel memory** separation you rely on day to day. **Segments** are mostly a **flat** story; **RPL** still **exists** in the architecture, but the **lesson** you carry is the same: **hardware enforces some walls**, **the kernel enforces identity and policy**, and **exploits** often aim at the **kernel half** of that stack.

## Minimal OS as a lab for yourself

You do not have to build an OS to understand the split—but a **tiny kernel**, a **GDT**, and deliberate **wrong** selector values made the CPU **fault** in ways a PDF alone did not. If you try it, expect long nights and small wins. It pays off in **intuition**.

## Further reading (compact)

| Topic | Where to start |
|--------|----------------|
| Real / protected mode, GDT, selectors | [OSDev Wiki](https://wiki.osdev.org/Main_Page) sections linked above |
| Official CPU rules | Intel **Software Developer’s Manuals** (system programming volumes) |
| Linux kernel structure (older but clear) | *Understanding the Linux Kernel*, 3rd ed. (**2.4-era** internals; still good for **shape** of the code) |

## Takeaways

1. **`id`** reflects **kernel data** about your process, not a wire on the chip that says “root.”
2. **Syscalls** are the **normal door**; **Linux** applies **policy** after the **CPU** has entered kernel mode.
3. **RPL** is a real part of **x86 segment privilege**; it is **not** the explanation for **UID 0** by itself.
4. **Real mode** shows what happens when **hardware enforcement is thin**; **protected mode + paging** add layers.
5. **Privilege escalation** often **breaks kernel trust**; understanding **where** enforcement lives helps you read **advisories** and **lab notes** with less confusion.

If you are deep in **Rust OS** tutorials today, the same **OSDev** pages help you map **concepts** from C/assembly examples into your own **Rust** bring-up. Concepts first, syntax second.
