# MIL User Manual

*No manual for MIL survived from the 1990s. This one was written in October 2026 from the
1.25 source and its `VERSIONS` and `BUGS` notes.*

## Introduction

MIL is a pre-assembler for 8086 MS-DOS and Windows programs. You write in MIL, and MIL translates it into Microsoft Macro Assembler (MASM) source, which you then assemble and link as usual. MIL version 1.25 was written by M.I. Systems between 1991 and 1993; the startup banner calls it the "Macro Translator".

MIL keeps you close to the machine but takes away the repetitive parts of assembly:

- **Segments** are declared with one line each instead of `SEGMENT`/`ASSUME`/`ENDS` boilerplate.
- **Variables** are declared by type (`BYTE`, `WORD`, `STRING`, `MESSAGE`, `LIST`) and MIL adds `BYTE PTR`, `WORD PTR` and `OFFSET` for you.
- **Procedures** take named parameters and local variables; MIL builds the `BP` stack frame, the parameter equates, the `RET n` and the call sequence.
- **Assignments** such as `AX = count`, `total += 10` or `count++` replace `MOV`, `ADD` and `INC`.
- **Structured control flow** (`IF`/`ELSE`/`ENDIF`, `DO`/`END`, `REPEAT`/`ENDREP`, `EXIT`, `CONTINUE`) replaces hand-written compares, jumps and labels, with compound conditions using `&&` and `||`.
- **String instructions** and **register saving** get one-line macros.

Any line MIL does not recognise is copied to the output unchanged, so ordinary 8086 instructions (`INT 21H`, `NEG AX`, `SHR AX,CL`, `CLC`) can be mixed freely with MIL statements. MIL is self-hosting: the translator is itself written in MIL, and rebuilding it from the sources in this repository reproduces the 1993 `MIL.EXE` byte for byte.

A short taste. This MIL:

```
IF (AL >= 'A' && AL <= 'Z')
   count++
ENDIF
```

becomes this MASM:

```
CMP AL,65
JB el_0
CMP AL,90
JA el_0
INC BYTE PTR count
el_0:
```

## Running MIL

```
MIL [options] <sourcefile> [objectfile]
```

The source extension defaults to `.MIL` and the output name defaults to the source name with `.ASM`. `MIL hello` reads `HELLO.MIL` and writes `HELLO.ASM`. Options start with `-` or `/` and are not case sensitive.

| Option | Effect |
| --- | --- |
| `-?` | Show help and exit |
| `-N` | No output file; check the source for errors only |
| `-P` | Make every data declaration `PUBLIC` (procedures are always public) |
| `-S` | Screen output |
| `-Q` | Quiet: no banner and no procedure-name listing |
| `-T` | Accepted for compatibility; has no effect |

Without `-Q`, MIL prints each procedure name as it translates it, then `Translation completed`, followed by `  - with severe error(s) ` if anything failed. Errors are reported with the offending source line:

```
SYNTAX ERROR -- Undefined operand
>>  DI = pt.yD
```

### Building a program

1. **Translate:** `MIL -p prog` turns `PROG.MIL` into `PROG.ASM`.
2. **Assemble:** `MASM prog.ASM /Z;` turns `PROG.ASM` into `PROG.OBJ`. MASM 4.00 (`MASM.EXE`) is what MIL itself is built with.
3. **Link:** `LINK prog;` turns one or more `.OBJ` files into `PROG.EXE`.
4. **Optional symbols:** `LINK prog,prog,prog/M;` then `MAPSYM prog.map` gives a `.SYM` file for SYMDEB.

MIL's own build is a good template. `MMAKE.CTL` is a Microsoft MAKE file with an inference rule that runs steps 1 and 2 for each module and then deletes the intermediate `.ASM`:

```
.mil.obj:
   MIL -p -t $*
   MASM $*.ASM /Z;
   DEL $*.ASM
```

Run it with `MAKE MMAKE.CTL` (this is all `MA.BAT` does). The final step links the modules with the response file `MLINK.CTL` and runs `MAPSYM`.

### Running on a modern PC

MIL, MASM and LINK are 16-bit DOS programs and do not run on 64-bit Windows. Use DOSBox-X, mount the project folder as `C:` and run the tools as normal. Source files must have DOS line endings (CR LF); a file saved with Unix line endings translates to garbage.

## Source file structure

A MIL module is a sequence of segment declarations, each followed by its contents. MIL keywords are written in upper case; one statement goes on each line.

```
INCLUDE defs.mil          ; constants and STRUCTs first
EXTERNAL FAR print (WORD) ; things defined in other modules

DECLARE (STACK 256)
DECLARE (DATA)
   ...variables...
DECLARE (CODE)
   ...procedures...
```

**Comments.** A line starting with `;` is a comment and is not copied to the output.

**EQU.** `EQU` lines pass straight through to MASM (`MAXLEN EQU 80`) and are the normal way to name constants.

**INCLUDE.** `INCLUDE defs.mil` reads another MIL file in place. Put shared `EQU`s, `STRUCT`s and `EXTERNAL`s in include files; MIL's own sources all start with `INCLUDE mconst.mil`.

### DECLARE: segments

`DECLARE` opens a segment and closes the previous one, so you never write `SEGMENT`, `ENDS` or `ASSUME`.

| MIL | MASM produced |
| --- | --- |
| `DECLARE (STACK 256)` | `STACK SEGMENT STACK 'STACK'` plus `DB 256 DUP (0)` |
| `DECLARE (STACK)` | An empty stack segment |
| `DECLARE (DATA)` | `DATA SEGMENT PUBLIC 'DATA'` |
| `DECLARE (CODE)` | `CODE SEGMENT PUBLIC 'CODE'` and `ASSUME CS:CODE,DS:DATA` |
| `DECLARE (CODE AS GRAPHICS)` | `GRAPHICS SEGMENT PUBLIC 'CODE'` and `ASSUME CS:GRAPHICS,DS:DATA` |

A module can have several code segments; each `DECLARE (CODE AS name)` closes the last one. A module with only `DECLARE (CODE)` and no data segment gets `ASSUME CS:CODE,DS:CODE`, which suits a `.COM` file (add `ORG 100H` yourself).

MIL does not load `DS` for you. A DOS `.EXE` starts with:

```
AX = DATA
DS = AX
```

### MODULE: DOS or Windows

`MODULE (DOS)` is the default. `MODULE (WINDOWS)`, as the first statement, switches to the Windows segment names `_DATA SEGMENT WORD PUBLIC 'DATA'` and `_TEXT SEGMENT WORD PUBLIC 'CODE'`. It also enables `WINDOWS` procedures (see Procedures). A module can only have one `MODULE` statement.

### The main procedure and START

A procedure called `main` is special. MIL puts a `START:` label at its top and ends the file with `END START`, making it the program entry point. `main` gets no `RET`, so it must end the program itself, normally with `AX = 4C00H` and `INT 21H`. A module without `main` ends with a plain `END`. The `START` statement emits a `START:` label by hand; do not use it in a module that has `main`.

### EXTERNAL

`EXTERNAL` declares data or procedures in another module and becomes `EXTRN`. For procedures, list the parameter types so MIL can check calls:

```
EXTERNAL WORD errorcountD      ; EXTRN errorcountD:WORD
EXTERNAL BYTE moduletype       ; EXTRN moduletype:BYTE
EXTERNAL FAR strcpy (WORD,WORD); EXTRN strcpy:FAR
EXTERNAL NEAR showhelp ()      ; EXTRN showhelp:NEAR
```

Every procedure MIL translates is declared `PUBLIC`. Data is only `PUBLIC` when you translate with `-P`, which is how MIL's own modules share their variables.

## Data declarations

Data goes after `DECLARE (DATA)`. Each declaration names one variable and records its type, so later statements get the right `BYTE PTR`, `WORD PTR` or `OFFSET` automatically. Declare one name per line: `BYTE a,b` is not supported.

| MIL | MASM produced | Notes |
| --- | --- | --- |
| `BYTE flag` | `flag DB 0` | Byte, initialised to 0 |
| `BYTE count = 5` | `count DB 5` | Byte with a value |
| `WORD totalD` | `totalD DW 0` | Word |
| `WORD ptrD = 1234H` | `ptrD DW 1234H` | Word with a value |
| `MESSAGE hello = 'Hello'` | `hello DB 5 ,'Hello',0` | Length byte, text, zero terminator |
| `STRING nameS (20)` | `nameS DW $+4`, `DB 20,20`, `DB 20+1 DUP (0)` | String descriptor plus a 21-byte buffer |
| `LIST table = 1,2,3,4` | `table DB 1,2,3,4` | Initialised bytes; text allowed: `LIST ext = '.MIL',0` |
| `LIST buffer (100)` | `buffer DB 100 DUP (0)` | Zeroed block; size can be an expression or a STRUCT name |
| `ARRAY grid[10] OF WORD` | `grid DB (10)*(WORD) DUP (0)` | Type defaults to `BYTE` |

Ordinary `DB`/`DW` lines can be mixed in, for example the rows of a lookup table after a `LIST` header line.

**MESSAGE** is MIL's string-literal type. Its length byte comes first, so a routine receiving `&hello` can read the length at offset 0 and the text from offset 1. A `MESSAGE` line cannot carry a trailing comment.

**STRING** is a buffer with a 4-byte descriptor: a word holding the buffer address (`saddrD`), the maximum length (`smax`) and the current length (`slen`). MIL's own `MCONST.MIL` defines a matching `STRUCT STRING` so the fields can be read as `DI.saddrD.D`, `DI.smax` and `DI.slen`.

**ARRAY** reserves storage only. Indexed access such as `AX = grid[3]` is not implemented and stops the translation; address the memory with a register instead.

### STRUCT

`STRUCT` defines a record layout as a set of offset equates. Define structures before the first `DECLARE`, normally in an include file. Members can be `BYTE`, `WORD` or `LIST name (size)`.

```
STRUCT POINT {
   WORD xD
   WORD yD
   BYTE colour
}
```

becomes

```
xD EQU 0+0000
yD EQU xD+0002
colour EQU yD+0002
POINT EQU colour+0001
```

The structure name equals its total size, so `LIST pt (POINT)` reserves one record and `BX += POINT` steps to the next. Member names are global equates, so each must be unique across all structures.

### Numbers and characters

| Form | Meaning |
| --- | --- |
| `100` | Decimal (the default) |
| `0FFH`, `4C00H` | Hexadecimal; start with a digit |
| `101B` | Binary |
| `'A'` | Character; becomes its ASCII code (65) in code |
| `MAXLEN`, `TBLOCKLEN/16` | Any EQU name or MASM expression |

`DEFAULT (HEX)`, `DEFAULT (DECIMAL)` and `DEFAULT (BIN)` change the base for plain numbers in **code** statements from that point on; data declarations are not affected. Under `DEFAULT (HEX)`, `CX = 10` becomes `MOV CX,10H`, but MIL also appends `H` to numbers that already have one (`4C00H` becomes `4C00HH`). Switch back with `DEFAULT (DECIMAL)`. `DEFAULT (BYTE)` and `DEFAULT (WORD)` are accepted but have no visible effect.

### Naming convention

MIL's own sources end word variables with `D` (`totalD`, `msgD`) and string descriptors with `S` (`sourcefileS`). MIL does not require this; it is a readability convention. The `.D` *suffix* in register-relative operands is different and is required (see Assignments).

## Procedures

A procedure definition has a header, then a few attribute lines, then a body in braces:

```
add2 (aD, bD)          ; name and parameter names
FAR                    ; NEAR (default), FAR or WINDOWS
WORD                   ; type of aD
WORD                   ; type of bD
LOCAL WORD tmpD        ; local variables, if any
LOCAL LIST buf (10)
{
AX = aD
AX += bD
tmpD = AX
}
```

- **Distance:** the first line after the header can be `NEAR`, `FAR` or `WINDOWS`. Without it the procedure is `NEAR`.
- **Parameter types:** one line per parameter, in order: `WORD` or `BYTE`. MIL reports `Type of actual parameters must be defined` if they are missing.
- **Locals:** `LOCAL WORD name`, `LOCAL BYTE name` or `LOCAL LIST name (size)`, after the types and before `{`. The size can be a STRUCT name: `LOCAL LIST r (RECT)`.
- **Body:** `{` and `}` on lines of their own.

MIL reads all procedure headers in a module before translating, so a procedure can be called before it is defined. Every procedure becomes `PUBLIC`.

### What MIL generates

The definition above produces:

```
PUBLIC add2
add2 PROC FAR
P_000 EQU 06
P_001 EQU 08
PUSH BP
MOV BP,SP
L_000 = 0+0
L_001 = L_000+2
L_998 = (L_001+10+1)/2
L_999 = L_998 *2
SUB SP,L_999
MOV AX,WORD PTR [BP+P_000]
ADD AX,WORD PTR [BP+P_001]
MOV WORD PTR [BP+L_000-L_999],AX
add2X:
MOV SP,BP
POP BP
RET 0004
add2 ENDP
```

- **Parameters** become `P_nnn` equates: the first is at `[BP+4]` for a NEAR procedure and `[BP+6]` for FAR, each further one 2 bytes higher. The numbering continues through the module.
- **Locals** become `L_nnn` equates below `BP`. Each `BYTE` local takes 2 bytes, and the frame size is rounded up to an even number.
- **The callee removes its arguments** with `RET n`.
- **Every procedure ends at a label** named after it plus `X` (`add2X:`); `RETURN` jumps there.
- A procedure with no parameters and no locals gets no `BP` frame at all.

Inside the body, parameters and locals are used by name like any variable. `&name` gives the address: `AX = &tmpD` becomes `LEA AX,[BP+L_000-L_999]`. MIL looks names up as parameter, then local, then global, so a local hides a global with the same name.

### RETURN

`RETURN` jumps to the procedure's exit, so the epilogue still runs. It can take a condition, written like an `IF` condition:

```
RETURN                       ; always
RETURN (C)                   ; if carry is set
RETURN (AX = 0 && DX = 0)    ; if both are zero
```

MIL has no return value: by convention, MIL's own code returns results in `AX` and success or failure in the carry flag (`STC`/`CLC`).

### Calling procedures

Call a procedure by name with an argument list:

```
display(&hello)
add2(3, total)
add2(AX, BX)
pnear()
```

becomes

```
MOV AX,OFFSET hello
PUSH AX
CALL display
PUSH WORD PTR total
MOV AX,3
PUSH AX
CALL FAR PTR  add2
PUSH BX
PUSH AX
CALL FAR PTR  add2
CALL pnear
```

Arguments are pushed last-first. Registers and word variables are pushed directly. Constants and `&addresses` are loaded into `AX` first, **so passing one overwrites `AX`**. MIL checks each call against the definition or `EXTERNAL` declaration: the argument count (`Incorrect number of parameters in call`) and the argument types (`Type mismatch`). A `BYTE` parameter needs a byte argument, such as `putchar(AL)` rather than `putchar(AX)`; MIL then pushes the whole `AX`. A call cannot appear inside an expression: `AX = add2(1,2)` is not supported.

### WINDOWS procedures

In a `MODULE (WINDOWS)` file, a procedure marked `WINDOWS` is a FAR procedure with the Windows 3.x prologue and epilogue and Pascal parameter order, so the first parameter is at the highest offset:

```
WndProc (hWndD, msgD, wParamD, lParamLoD, lParamHiD)
WINDOWS
WORD
WORD
WORD
WORD
WORD
{
...
}
```

The generated code starts with `MOV AX,DS`, `NOP`, `INC BP`, `PUSH BP`, `MOV BP,SP`, `PUSH DS`, `MOV DS,AX`. It ends with `LEA SP,-2[BP]`, `POP DS`, `POP BP`, `DEC BP` and `RET 0010` for five word parameters.

## Assignments and expressions

An assignment has a destination, an operator and a source. MIL turns it into one or two instructions, adding the right `BYTE PTR`/`WORD PTR` from the declared types.

| MIL | MASM produced |
| --- | --- |
| `AX = 5` | `MOV AX,5` |
| `AL = 'A'` | `MOV AL,65` |
| `BX = AX` | `MOV BX,AX` |
| `CX = totalD` | `MOV CX,WORD PTR totalD` |
| `totalD = AX` | `MOV WORD PTR totalD,AX` |
| `flag = 1` | `MOV BYTE PTR flag,1` |
| `count++` / `count--` | `INC BYTE PTR count` / `DEC BYTE PTR count` |
| `SI++` | `INC SI` |
| `totalD += 10` | `ADD WORD PTR totalD,10` |
| `totalD -= CX` | `SUB WORD PTR totalD,CX` |
| `AX = BX + 3` | `MOV AX,BX` then `ADD AX,3` |
| `CX = AX - 5` | `MOV CX,AX` then `SUB CX,5` |
| `BX = sptrD - 3` | `MOV BX,WORD PTR sptrD` then `SUB BX,3` |
| `SI = &hello` | `MOV SI,OFFSET hello` |
| `AX = &tmpD` (local) | `LEA AX,[BP+L_000-L_999]` |

Operators are `=`, `+=`, `-=`, `++`, `--`, and `+` or `-` on the right-hand side. Each `+` or `-` term becomes its own `ADD` or `SUB`, so `AX += CODE + 5` gives `ADD AX,CODE` then `ADD AX,5`. Anything else, such as `SHL`, `AND` or `MUL`, is written as a normal instruction.

### Segment registers and memory-to-memory

The 8086 cannot move directly between some operands, so MIL goes through `AX` or the stack:

| MIL | MASM produced |
| --- | --- |
| `DS = AX` | `MOV DS,AX` |
| `DS = ES` | `PUSH ES` then `POP DS` |
| `ES = totalD` | `MOV AX,WORD PTR totalD` then `MOV ES,AX` |
| `totalD = ptrD` | `MOV AX,WORD PTR ptrD` then `MOV WORD PTR totalD,AX` |

**These forms overwrite `AX`.** Assigning between a byte and a word (`totalD = count`) is an error: `Cannot assign operands`.

### Pointer operands: the dot notation

MIL writes memory references through a register as `register.offset`. A plain offset means a byte; add `.D` for a word.

| MIL | MASM produced |
| --- | --- |
| `AL = BX.0` | `MOV AL,BYTE PTR [BX+0]` |
| `AX = BX.2.D` | `MOV AX,WORD PTR [BX+2+0]` |
| `BX.2.D = AX` | `MOV WORD PTR [BX+2+0],AX` |
| `AX = BX.yD.D` | `MOV AX,WORD PTR [BX+yD+0]` (STRUCT member) |
| `DI.slen += AL` | `ADD BYTE PTR [DI+slen],AL` |
| `AL = ES.SI.0` | `MOV AL,BYTE PTR ES:[SI+0]` (segment override) |
| `ES.DI.colour = AL` | `MOV BYTE PTR ES:[DI+colour],AL` |

`.D` works because `MCONST.MIL` defines `D EQU 0`, so it adds nothing to the address and only marks the size.

The same notation works on named variables, giving an offset into a `LIST` or a member of a `LIST` declared with a STRUCT size:

| MIL | MASM produced |
| --- | --- |
| `AL = table.2` | `MOV AL,BYTE PTR [table+2]` |
| `pt.xD.D = AX` | `MOV WORD PTR [pt+XD+0],AX` |
| `pt.colour = 3` | `MOV BYTE PTR [pt+COLOUR],3` |
| `lbuf.0.D = AX` (local) | `MOV WORD PTR [BP+L_002-L_999+0+0],AX` |

On a named variable, a word member needs `.D` (`pt.yD.D`); `pt.yD` alone is rejected.

### Far pointers

`ES:BX = farp` and `DS:SI = farp` become `LES BX,[farp]` and `LDS SI,[farp]`. MASM 4.00 rejects this when `farp` is a `LIST` (`Illegal size for item`), and MIL does not know variables declared with a raw `DD`. With MASM 4.00, write the instruction directly: `LES BX,DWORD PTR farp`.

## Control flow

MIL's control statements generate the compares, conditional jumps and labels for you. Each keyword goes on its own line, and blocks can be nested up to 30 deep.

### Conditions

A condition is in parentheses and is used by `IF`, `EXIT`, `CONTINUE` and `RETURN`.

| Condition | Meaning |
| --- | --- |
| `a = b`, `a <> b` | Equal, not equal |
| `a < b`, `a > b`, `a <= b`, `a >= b` | Unsigned comparison (`JB`, `JA`, ...) |
| `a #< b`, `a #> b`, `a #<= b`, `a #>= b` | Signed comparison (`JL`, `JG`, ...) |
| `C`, `NC`, `Z`, `NZ` | Test a flag left by an earlier instruction or call |
| `x && y`, `x \|\| y` | And, or; group with parentheses |

Each side of a comparison can be a register, variable, number, character or pointer operand, for example `(ES.SI.0 <> SPACE)` or `(DI.FDmode = 0 || DI.FDmode = 100)`. Flag tests are how MIL code checks results, because procedures return success in the carry flag:

```
loadupsourcefile()
IF (NC)
   error()
ENDIF
```

### IF, ELSE, ENDIF

```
IF (AL > 5 && BL <= 10)
   CX = 1
ELSE
   CX = 2
ENDIF
```

becomes

```
CMP AL,5
JBE el_1
CMP BL,10
JA el_1
MOV CX,1
JMP SHORT fi_1
el_1:
MOV CX,2
fi_1:
```

`ELSE` takes no condition; there is no else-if, so nest a second `IF` inside the `ELSE`. 8086 conditional jumps reach only 127 bytes, and the jump over the `ELSE` branch is a `JMP SHORT`, so MASM reports a jump out of range when a branch is longer. Use `IFL` and `ELSEL` (L for long) instead: MIL then jumps around a near `JMP`, which reaches anywhere in the segment.

```
IFL (C)
   ...long block...
ELSEL
   ...
ENDIF
```

### DO ... END: a breakable block

`DO ... END` is a block that runs **once**. `EXIT` jumps past `END`, `CONTINUE` jumps back to `DO`, and `LOOP {}` emits the 8086 `LOOP` instruction, which decrements `CX` and jumps back to `DO` while it is non-zero.

```
CX = 10
DO
   STOSB
   LOOP {}
END
```

becomes

```
MOV CX,10
DO_1:
STOSB
LOOP DO_1
EN_1:
```

`LOOP` ignores anything inside its braces; it is always a plain `LOOP`. MIL's own code also uses `DO ... END` without `LOOP`, as a block it can `EXIT` from as soon as a step fails:

```
DO
   open()
   EXIT (NC)
   fread()
   EXIT (NC)
   STC
END
```

### REPEAT ... ENDREP: an endless loop

`REPEAT ... ENDREP` jumps back to the top until an `EXIT` leaves it:

```
REPEAT
   AL = BX.0
   BX++
   EXIT (AL = 0)
ENDREP
```

becomes

```
DO_3:
MOV AL,BYTE PTR [BX+0]
INC BX
CMP AL,0
JZ EN_3
JMP SHORT DO_3
EN_3:
```

`ENDREP` uses a short jump back; for a body longer than 127 bytes close the loop with `ENDREPL` instead.

### EXIT and CONTINUE

| Statement | Effect |
| --- | --- |
| `EXIT` | Leave the innermost `DO` or `REPEAT` |
| `EXIT (cond)` | Leave it if the condition is true |
| `CONTINUE` / `CONTINUE (cond)` | Jump back to the top of it |
| `EXITL`, `CONTINUEL` | Long-jump versions, for targets more than 127 bytes away |

Using them outside a loop is an error (`Cannot use EXIT outside loop`).

### GOTO and LABEL

`LABEL name` places a label, and `GOTO name` jumps to it:

```
GOTO finish        ; JMP finish
...
LABEL finish       ; PUBLIC finish
                   ; finish:
```

The label is also made `PUBLIC`, which helps when debugging with SYMDEB.

### Generated label names

MIL numbers its labels `DO_n`, `EN_n`, `el_n`, `fi_n`, `if_n`, `fl_n` and `sc_n`, plus `nameX` for each procedure exit. Don't use these names for your own labels.

## String instructions and register saving

### MOVS, LODS, STOS, SCAS

The string macros take a code of up to three letters that sets the operand size, the direction flag and the repeat prefix in one go:

```
MOVS <size>[<direction>][R]
```

- **Size** (required, first letter): `B` byte, `W` word, `D` doubleword (386 only).
- **Direction** (optional): `I` increment emits `CLD`; `D` decrement emits `STD`. Without one, the direction flag is left as it is.
- **R** (optional): add a `REP` prefix.
- **SCAS with R** must also say whether to repeat while equal or not equal: `,Z` or `,NZ`.

| MIL | MASM produced |
| --- | --- |
| `MOVS BIR` | `CLD`, `REP MOVSB` |
| `MOVS WDR` | `STD`, `REP MOVSW` |
| `MOVS B` | `MOVSB` |
| `LODS B` | `LODSB` |
| `STOS WIR` | `CLD`, `REP STOSW` |
| `SCAS BIR,NZ` | `CLD`, `REPNZ SCASB` |
| `SCAS WIR,Z` | `CLD`, `REPZ SCASW` |
| `MOVS DIR` | `CLD`, `REP MOVSD` |

A `D` is a size only in first position, so `MOVS BDR` means byte, decrement, repeat. The doubleword forms need a 386-aware assembler; MASM 4.00 rejects `REP MOVSD`.

A typical use, finding a `.` in a filename (from MIL's own command-line parsing):

```
CL = DI.slen
CH = 0
AL = '.'
SCAS BIR,NZ
IF (NZ)
   ; no extension given
ENDIF
```

### SAVE: registers for one procedure

`SAVE` inside a procedure pushes the registers where it appears and pops them, in reverse order, at the procedure's exit, so every `RETURN` restores them too. Use it once per procedure.

```
worker ()
{
SAVE CX,DX
CX = 1
RETURN (Z)
}
```

becomes

```
worker PROC NEAR
PUSH CX
PUSH DX
MOV CX,1
JNZ sc_0
JMP workerX
sc_0:
workerX:
POP DX
POP CX
RET 0000
worker ENDP
```

### SAVEON: registers for every procedure

`SAVEON SI,DI` at the start of a module saves those registers in every procedure that follows: they are pushed at the top and popped at the exit label. `SAVEON` on its own turns it off again. This was added for Windows code, where `SI` and `DI` must be preserved.

### KEEP: registers around every call

`KEEP BX,SI` makes MIL push those registers before every procedure call and pop them after it, protecting values the callee might change:

```
KEEP BX,SI
...
nearproc()
```

becomes

```
PUSH BX
PUSH SI
CALL nearproc
POP SI
POP BX
```

`KEEP` with no registers turns it off. `KEEP` and `SAVEON` take up to 10 registers each and can be used at module level or inside a procedure.

## Complete example

`VOWELS.MIL` prints a message, counts its vowels and prints the count. It uses data declarations, procedures with parameters, `SAVE`, `REPEAT`, `DO`/`LOOP`, and an `IF` with `||`. It mixes in one plain instruction (`OR AL,20H`).

```
; VOWELS.MIL - print a message and count its vowels
DECLARE (STACK 256)
DECLARE (DATA)
MESSAGE greeting = 'Hello from MIL, 1993'
MESSAGE result = 'Vowels: '
BYTE count
DECLARE (CODE)
main ()
{
AX = DATA
DS = AX
print(&greeting)
newline()
countvowels(&greeting)
print(&result)
AL = count
AL += '0'
putchar(AL)
newline()
AX = 4C00H
INT 21H
}
;-----------------------------
print (msgD)
WORD
{
SAVE SI
SI = msgD
SI++                ; skip the length byte
REPEAT
   AL = SI.0
   EXIT (AL = 0)
   putchar(AL)
   SI++
ENDREP
}
;-----------------------------
putchar (ch)
BYTE
{
DL = ch
AH = 2
INT 21H
}
;-----------------------------
newline ()
{
putchar(13)
putchar(10)
}
;-----------------------------
countvowels (msgD)
WORD
{
SAVE SI
count = 0
SI = msgD
CL = SI.0           ; length byte
CH = 0
SI++
DO
   AL = SI.0
   OR AL,20H           ; fold to lower case
   IF (AL = 'a' || AL = 'e' || AL = 'i' || AL = 'o' || AL = 'u')
      count++
   ENDIF
   SI++
   LOOP {}
END
}
```

Build and run it:

```
C:\>MIL vowels
C:\>MASM vowels;
C:\>LINK vowels;
C:\>VOWELS
Hello from MIL, 1993
Vowels: 4
```

The 70 lines of MIL become 117 lines of MASM. Here is the translation of `print` and `countvowels`:

```
PUBLIC print
print PROC NEAR
P_000 EQU 04
PUSH BP
MOV BP,SP
PUSH SI
MOV SI,WORD PTR [BP+P_000]
INC SI
DO_0:
MOV AL,BYTE PTR [SI+0]
CMP AL,0
JZ EN_0
PUSH AX
CALL putchar
INC SI
JMP SHORT DO_0
EN_0:
printX:
POP SI
POP BP
RET 0002
print ENDP
...
PUBLIC countvowels
countvowels PROC NEAR
P_002 EQU 04
PUSH BP
MOV BP,SP
PUSH SI
MOV BYTE PTR count,0
MOV SI,WORD PTR [BP+P_002]
MOV CL,BYTE PTR [SI+0]
MOV CH,0
INC SI
DO_1:
MOV AL,BYTE PTR [SI+0]
OR AL,20H
CMP AL,97
JZ if_1
CMP AL,101
JZ if_1
CMP AL,105
JZ if_1
CMP AL,111
JZ if_1
CMP AL,117
JZ if_1
JMP SHORT el_1
if_1:
INC BYTE PTR count
el_1:
INC SI
LOOP DO_1
EN_1:
countvowelsX:
POP SI
POP BP
RET 0002
countvowels ENDP
```

For a much larger example, the MIL translator itself is about 9,300 lines of MIL in this repository.

## Errors, limits and history

### Error messages

Errors print as `SYNTAX ERROR -- <message>` followed by `>>` and the source line, and MIL keeps going so you see every error in one run. `Unrecognised command` is only a `WARNING ERROR`: the line is still copied to the output, which is how MASM directives such as `ORG 100H` outside a procedure get through. Ordinary instructions inside a procedure are copied silently. A labelled data line inside a procedure (`msg DB 'Hi$'`) reports `Undefined operand` but is copied anyway and assembles fine.

| Message | Usual cause |
| --- | --- |
| Type of actual parameters must be defined | Missing `WORD`/`BYTE` lines after a procedure header |
| Incorrect number of parameters in call | Argument count differs from the definition |
| Type mismatch | Byte argument for a word parameter, or the reverse |
| Cannot assign operands | Byte to word, or a form the 8086 cannot do (`pt.yD` without `.D`) |
| Undefined operand | Name not declared, or a construct MIL does not support |
| Must be Index Register | Pointer notation on a register that cannot address memory |
| Operator not defined | Unknown operator in an assignment |
| Numerical value expected | Bad number |
| Unbalanced statements in procedure | Unclosed `IF`, `DO` or `REPEAT`, or a stray `}` |
| No closing bracket / Bracket expected / Bracket out of place / Must have bracket here | Parentheses or braces missing or misplaced |
| No closing quote | Unterminated string; also a comment after a `MESSAGE` |
| Incorrect syntax for STRING / MESSAGE / LIST / ARRAY / DEFAULT | Malformed declaration |
| Label name expected | `LABEL` or `GOTO` without a name |
| Too many nested loops | More than 30 nested blocks |
| END does not match DO / ENDREP does not match REPEAT / ENDIF does not match IF | Mismatched block ends, or a second `ELSE` |
| Cannot use EXIT outside loop / Cannot use LOOP outside loop | `EXIT`, `CONTINUE` or `LOOP` with no enclosing block |
| Flag expected - C, NC, Z, NZ | Bad flag test |
| Incorrect syntax for a conditional expression | Malformed condition |
| Must specify B, W or D / Must specify Z or NZ / Invalid string operation | Bad string-macro code |
| Must specify a register / Invalid register / Too many registers | Bad `SAVE`, `KEEP` or `SAVEON` list (maximum 10) |
| Cannot use SAVE more then once in procedure | Second `SAVE` |
| Symbol not valid here | Statement in the wrong place, such as `STRUCT` inside a segment or `LOCAL` after `{` |
| Not a valid data type | Unknown type name |
| Include name must be specified / Cannot open file | Bad `INCLUDE` |
| MODULE already defined / Invalid MODULE type | Second `MODULE`, or not `DOS` or `WINDOWS` |
| Invalid DECLARE declaration, assuming CODE segment | Unknown segment type |
| Insufficient symbol space / Insufficient memory | Too many symbols, or not enough DOS memory |

### Limits

- Source lines up to 200 characters; source and output file names up to 30 characters.
- 30 levels of nested `IF`, `DO` and `REPEAT`.
- 10 registers in each `KEEP` or `SAVEON` list.
- One name per `BYTE` or `WORD` declaration.

### Known issues in version 1.25

- `ARRAY` storage can be declared but indexed access is not implemented; `AX = grid[3]` stops the translation and the output is cut short.
- `DEFAULT (HEX)` adds `H` to numbers that already end in `H`.
- A trailing comment after a `MESSAGE` string gives `No closing quote`.
- `ELSE (condition)` is accepted but the condition is ignored, and `LOOP {condition}` ignores its condition.
- `AX = doubleword.0.D` (open bug 2 in `BUGS`) is not supported.
- `REP MOVSD` and the other 386 forms do not assemble with MASM 4.00.
- `ES:BX = list` produces `LES BX,[list]`, which MASM 4.00 rejects for a byte `LIST`.
- The 1.17 notes say `SAVEON` is ignored for `WINDOWS` procedures, but 1.25 applies it to them.
- Source must use CR LF line endings.

### Version history

From `VERSIONS` and `BUGS`, newest first.

| Version | Date | Changes |
| --- | --- | --- |
| 1.25 | Jan 1993 | The surviving `MIL.EXE` (27 Jan 1993); no notes in `VERSIONS` |
| 1.24 | 24 Nov 1992 | Case-insensitive struct members in globals; fixed `.D` inside global names |
| 1.23 | 11 Nov 1992 | Fixed `func(&proc)` overwriting the definition; corrected the even-`SP` local frame |
| 1.22 | 22 Oct 1992 | `MOVS BDR` no longer read as doubleword |
| 1.21 | 30 Sep 1992 | `-Q` hides the banner; local frame kept even; `LIST name(x)` without a space |
| 1.20 | 29 Apr 1992 | New symbol-table format; `ARRAY` declarations (access unfinished) |
| 1.19 | 10 Apr 1992 | Procedure names may start with `_`; larger local-list store |
| 1.18 | 1 Apr 1992 | Statements outside procedures; several code segments per module; `-Q` |
| 1.17 | 24 Mar 1992 | `MODULE (DOS/WINDOWS)` and `_TEXT`/`_DATA`; locals sized by equates; `call(&local)` |
| 1.16 | 18 Mar 1992 | `KEEP`, `SAVEON`, conditional `RETURN`; renamed "Macro Translator"; `.COM` support |
| 1.15 | Mar 1992 | Lookup order parameter, local, global; `LOCAL LIST` |
| 1.14 | 26 Feb 1992 | Fixed `var++` and calls after `INC` |
| 1.13 | 24 Feb 1992 | `GOTO`/`LABEL`; `/?` help |
| 1.12 | 21 Feb 1992 | 386 `MOVSD`, `LODSD`, `STOSD` |
| 1.11 | 10 Feb 1992 | Larger operand buffer |
| 1.1 | 31 Jan 1992 | `WINDOWS` procedures with Pascal calling; locals reworked |
| 1.0 | Aug 1991 to Jan 1992 | First working version; TAB as whitespace; `&` addresses of parameters and locals; `DECLARE (CODE AS name)` |
