freemlib for Neo-Geo Example 01: Hello World on the Fix Layer
================================================================================
[Introduction]
This first example isn't so much using the freemlib as it is setting up a basic
Neo-Geo program and writing some text to the screen on the Fix layer. The macros
in "mess_macro.inc" are not used here, so you can get a feel for how things
actually work (which is required for proper usage of the macros in mess_macro).

================================================================================
[Files]
(In the directory)
_c-asm68k.bat			Batch file for compiling with asm68k
_c-vasm68k.bat			Batch file for compiling with vasm (68k, mot syntax; executable renamed to "vasm86k")
_c-vasm68k.sh			Shell script for compiling with vasm (68k, mot syntax; executable renamed to "vasm86k")
01_helloFix.asm			Main file
header_68k.inc			68000 Vectors
header_cart.inc			Neo-Geo cartridge header
ram_user.inc			User space RAM ($100000-$10F2FF)
readme.txt				This file!

(Sub-directories)
fixtiles/				fix layer tilesets
	202-s1.s1			Fix Layer S ROM
sprtiles/
	202-c1.c1			C ROM 1/2
	202-c2.c2			C ROM 2/2
	in.smc				Source of C ROM (SNES format graphics; convert with recode16)

(Included from outside the directory)
../../src/inc/neogeo.inc		Neo-Geo hardware defines
../../src/inc/ram_bios.inc		Neo-Geo BIOS RAM location defines

================================================================================
[Setup]

<Palette>
In order to see anything displayed on the screen, you'll need to set some color
values in the palette first. Since this demo is simple, we won't need to be too
complex when it comes to the palette.

The Neo-Geo has two banks of palette RAM, each holding 4096 colors worth of data.
The system's palette RAM lives at $400000-$401FFF, and the active palette page
can be swapped by writing to either the PALETTE_BANK0 register ($3A001F) or the
PALETTE_BANK1 register ($3A000F).

The palette RAM is divided into 256 sets of 16 colors. Of these 256 sets, only
the first 16 sets can be used with the Fix Layer. Sprites can use any color set.

In this example, we'll only be using 4 sets of palettes with 3 colors each.
One is considered transparent, and the other two are active colors.

Dealing with the palette colors is a bit complex, but for now, let's just treat
it as a 12-bit color with values of $0000 to $0FFF. You should read it as $0RGB,
where R is Red, G is Green, and B is Blue. The palette is explained in further
detail in Example 03: Palette Basics.

<Fix Layer>
We must first understand the Fix Layer before we can draw to it. The Neo-Geo's
Fix Layer is a set of 8x8 pixel cells that display over everything else on
screen. As such, they're primarily used for game HUD elements.

In VRAM, the Fix layer lives from $7000-$7400. Tiles go vertically by default,
so the "normal order" may not be what you expect.

VRAM Addr.	Fix Tile Cell
-------------------------
$7000		x=0,y=0
$7001		x=0,y=1
$7020		x=1,y=0

The actual data for each cell consists of the following:
* Palette (0-F)
* Tile Number Upper Nibble (0-F)
* Tile Number Lower Byte (00-FF)

================================================================================
[Process]
There are two ways of writing tiles on the Fix Layer:
1) Doing it yourself with writes to the LSPC registers.
2) Letting the BIOS handle it via MESS_OUT.

This demo uses both methods of displaying tiles on the Fix Layer.

<LSPC Registers>
Writing directly to the LSPC registers may be a bit more familiar for those
coming off of programming other retro game consoles, as you end up setting
an address, the increment size, and then write the data to a register.

The key LSPC registers are as follows:

Address		Friendly Name	Description
-------------------------------------------
$3C0000		LSPC_ADDR		VRAM Address
$3C0002		LSPC_DATA		VRAM Data
$3C0004		LSPC_INCR		VRAM Increment

Since this seems to be the only reliable way to write to the sprite sections of
VRAM, you'll want to know how to write to the LSPC registers eventually.
But that's another story for another time...

When writing to the Fix layer, the value written to LSPC_ADDR will be between
$7000 and $74FF (unless you're using Fix bankswitching, which we're not).

LSPC_INCR can be many values, but the two most common are 1 (vertical writes)
and 0x20 (32 decimal; horizontal writes).

When LSPC_INCR and LSPC_ADDR are correctly set, you can just throw words at
LSPC_DATA to write them to VRAM.

<MESS_OUT>
The Neo-Geo BIOS has a function called MESS_OUT which outputs tiles on the Fix
layer. Compared to writing everything to the registers yourself, MESS_OUT
operates on a set of commands. Explaining MESS_OUT in full is beyond the scope
of this file; you will want to check the Neo-Geo Development Wiki's page on it:
https://wiki.neogeodev.org/index.php?title=MESS_OUT

; something about the flags and pointers

; writing data

; introduce basic commands

With MESS_OUT, there are two ways of displaying the result:
1) Doing a manual "jsr MESS_OUT".
2) Having MESS_OUT be called in the vblank/INT1.
This example uses the second method, so proper handling of the flags is needed.