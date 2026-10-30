# MIL

MIL is a pre-processor language for 8086 assembly, written by Colin Mackie (M.I.
Systems) between 1991 and 1993. You write structured code (typed variables,
procedures with parameters and locals, `IF`/`ELSE`, `DO`/`REPEAT` loops, assignments
such as `total += 10`), and MIL translates it into Microsoft Macro Assembler (MASM)
source. Any line it doesn't recognise passes straight through, so plain 8086
instructions mix freely with MIL statements.

MIL is written in MIL: the source here compiles with the committed `MIL.EXE`, and the
build reproduces that 1993 binary byte for byte.

```
IF (AL >= 'A' && AL <= 'Z')         CMP AL,65
   count++                          JB el_0
ENDIF                               CMP AL,90
                                    JA el_0
                                    INC BYTE PTR count
                                    el_0:
```

The full language is described in the [MIL User Manual](docs/MANUAL.md).

## History

The repository has two original snapshots, each dated to match its files:

| Commit | Date | What |
|---|---|---|
| MIL 1.20 source | 30 April 1992 | the source from `MIL120.ZIP`, as found |
| MIL 1.25 source and `MIL.EXE` | 27 January 1993 | the last source, and the `MIL.EXE` built from it |

`git diff` between them shows nine months of 1992 development. `VERSIONS` is Colin's
own log of every version from 1.0 to 1.24, and `BUGS` lists the bugs he tracked. The
binaries of earlier versions that survive (1.17, 1.19, 1.20 and 1.24) are attached to
the repository's releases.

MIL was used to write, among other things, [MI-CACHE](https://github.com/cdmackie/micache),
a 1992 disk cache for MS-DOS.

## Files

| File | |
|---|---|
| `MIL.EXE` | MIL 1.25, built 27 January 1993 |
| `MINIT.MIL` | start-up, command line and help |
| `MMAIN.MIL` | the main translation loop: procedures, assignments and operands |
| `MMACROS.MIL` | the MIL statements: declarations, control flow, string and register macros |
| `MFILE.MIL` | source and output file handling |
| `MGP.MIL` | general string and number routines |
| `MBLOCKS.MIL` | memory block allocation |
| `MDATA.MIL`, `MDATAINC.MIL` | global data and messages, and their `EXTERNAL` declarations |
| `MCONST.MIL` | constants and structures shared by every module |
| `MORDER.MIL`, `MSTACK.MIL`, `MEND.MIL` | segment order, the stack, and the end of the program |
| `MMAKE.CTL`, `MLINK.CTL`, `MA.BAT` | the original makefile, linker response file and the batch file that runs them |
| `MLINKE.CTL`, `MSAVE.CTL`, `DB.BAT` | a packed-EXE link, a backup to floppy, and debugging with SYMDEB |
| `VERSIONS`, `BUGS` | Colin's version log and bug list |
| `build.sh` | rebuild `MIL.EXE` under DOSBox-X |

The source files are kept exactly as found, so they have DOS (CR LF) line endings and
some end with bytes left by the TopCopy word processor they were edited in. MIL needs
the CR LF line endings.

## Building

MIL, MASM and LINK are 16-bit DOS programs, so `build.sh` runs the original makefile
inside [DOSBox-X](https://dosbox-x.com/), from Git Bash on Windows:

```
bash build.sh
```

It needs Microsoft `MAKE.EXE`, `MASM.EXE` (4.00), `LINK.EXE` and `MAPSYM.EXE`, which
are not included: put them in the directory above this one, or set `TOOLS` to their
directory. DOSBox-X is expected in `C:\DOSBox-X` (or set `DOSBOX`). The committed
`MIL.EXE` compiles the source, and the new `out/MIL.EXE` is compared with it.

To build a program of your own: `MIL -p prog` writes `PROG.ASM`, then
`MASM prog.ASM /Z;` and `LINK prog;` as usual.

## License

MIT, see [LICENSE](LICENSE).
