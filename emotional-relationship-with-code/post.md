---
layout: post
title: "The Emotional Relationship We Have With Code"
date: 2026-03-11 12:00:00 +0000
---

![The Emotional Relationship We Have With Code]({{ site.baseurl }}/emotional-relationship-with-code/image1.png)

One side effect of AI that we do not talk about enough is this, the emotional relationship people have with code.

For many of us, programming was never just about output.

There was a quiet satisfaction in typing every statement ourselves. Watching logic unfold line by line.

Back then there was no autocomplete. No AI suggestions. Often no mouse-heavy IDE workflow. Just a keyboard, a blinking cursor, and patience.

You typed everything.
You fixed everything.
You understood everything.

There was joy in seeing printf print exactly what you expected.
In zeroing a register with xor eax, eax.
In tightening a loop like while(index).

One piece of code that programmers have often held up as beautiful is the fast inverse square root from Quake III Arena: a tiny, hardware-aware hack that does one Newton–Raphson iteration after a magic constant to approximate 1/√x without a proper square root. It is the kind of craft that comes from knowing the machine.

```c
float Q_rsqrt(float number)
{
  long i;
  float x2, y;
  const float threehalfs = 1.5F;
  x2 = number * 0.5F;
  y  = number;
  i  = * ( long * ) &y;
  i  = 0x5f3759df - ( i >> 1 );
  y  = * ( float * ) &i;
  y  = y * ( threehalfs - ( x2 * y * y ) );
  return y;
}
```

Take Rust. Why do people love enums in Rust? Because they make invalid states unrepresentable. You do not have "maybe null" scattered everywhere; you have `Option<T>`. You do not hide errors in a magic value; you have `Result<T, E>`. The type system encodes the shape of your logic, and pattern matching forces you to handle every case. It is a different kind of craft: not bit-twiddling, but the pleasure of the compiler and the data structure in one.

```rust
enum Message {
    Quit,
    Move { x: i32, y: i32 },
    Write(String),
}

fn handle(msg: Message) {
    match msg {
        Message::Quit => { /* ... */ }
        Message::Move { x, y } => { /* ... */ }
        Message::Write(s) => { /* ... */ }
    }
}
```

It was not just about shipping software. It was craft.

I remember attending ILUGC meetups in early 2000 at IIT Madras. People gathered to talk about Linux, kernels, patches, open-source. I would walk up to strangers asking how they got their modem working on Debian 3.1. That is where I first heard serious discussions about FreeBSD and OpenBSD.

There were similar communities around the world, Chaos Computer Club, BSD user groups, Linux User Groups everywhere. Pure meetups of craft work. No branding. No hype. Just people obsessed with understanding systems.

This was also the era of 5.25-inch floppy disks, thin magnetic media inside soft sleeves. 360 KB or 1.2 MB felt sufficient. Many systems had no hard disks. There was no internet. No Windows. Just MS-DOS 4.01, a blinking A:\ prompt, and whatever tools fit on a floppy.

Abstraction was thin. You could almost see the hardware through the code.

Now AI-assisted tools generate much of that surface layer.

Syntax appears instantly.
Boilerplate disappears.
Patterns complete before you finish thinking.

Productivity increases. And that is a good thing.

But I sometimes think about what changes in our relationship with code when we stop typing the details ourselves.

Maybe the craft does not disappear.
Maybe it moves upward, from writing syntax to designing systems.

I know this may not matter from a productivity standpoint, but there was something meaningful about typing every line ourselves.

If you have read "The Story of Mel" you may understand the kind of craft I am referring to. It was never really about assembly code. It was about intimacy with the machine.

## The Story of Mel Summarized by AI

"The Story of Mel," written by Ed Nather, describes a remarkable programmer named Mel who worked on the early LGP-30 in the late 1950s. The machine used a rotating drum for memory, so accessing instructions depended on the physical timing of the drum. Mel understood this timing so deeply that he wrote assembly programs arranged precisely to match the drum's rotation. Instead of using conventional jumps, he positioned instructions so that when one finished executing, the next one would appear under the read head at exactly the right moment. His programs even used self-modifying code to adjust instruction addresses dynamically. Other programmers tried to rewrite his work in a cleaner, more understandable way, but their versions ran slower than Mel's original code. What made Mel's work extraordinary was that his code was not just logical; it was synchronized with the physical behavior of the hardware. The story shows a programmer who treated the machine almost like a mechanical instrument. It illustrates a time when deep knowledge of hardware and software together defined programming skill. Even today, the story is remembered as a symbol of craftsmanship and intimacy with the machine.
