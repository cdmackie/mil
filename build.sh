#!/bin/bash
# Rebuild MIL.EXE from the MIL source under DOSBox-X, with the original makefile
# (MA.BAT: make mmake.ctl). MIL is written in MIL, so the committed MIL.EXE
# compiles it. Needs, in TOOLS (default: the directory above this one), the
# Microsoft MAKE.EXE, MASM.EXE (4.00), LINK.EXE and MAPSYM.EXE, and DOSBox-X
# (DOSBOX, default C:\DOSBox-X\dosbox-x.exe). Output and logs land in ./out,
# and the new MIL.EXE is compared with the committed one.
set -e
HERE="$(cd "$(dirname "$0")" && pwd)"
TOOLS="${TOOLS:-$(cd "$HERE/.." && pwd)}"
DOSBOX="${DOSBOX:-/c/DOSBox-X/dosbox-x.exe}"
W="$HERE/out"
for t in MAKE.EXE MASM.EXE LINK.EXE MAPSYM.EXE; do
	[ -f "$TOOLS/$t" ] || { echo "missing $TOOLS/$t (set TOOLS)"; exit 1; }
done
rm -rf "$W"; mkdir -p "$W"
cp "$HERE"/*.MIL "$HERE"/*.CTL "$HERE"/MA.BAT "$W/"
# the compiler that builds the new one, kept apart so that out/MIL.EXE can
# only be the newly linked one
mkdir "$W/BOOT"; cp "$HERE/MIL.EXE" "$W/BOOT/"
for t in MAKE.EXE MASM.EXE LINK.EXE MAPSYM.EXE; do cp "$TOOLS/$t" "$W/"; done
# (what MA.BAT does; COMMAND.COM can't redirect the output of a CALL)
printf '@echo off\r\nset PATH=C:\\BOOT\r\nmake mmake.ctl > BUILD.LOG\r\n' > "$W/RUN.BAT"
cat > "$W/dbx.conf" <<'EOF'
[cpu]
core=normal
cycles=max
EOF
timeout 300 "$DOSBOX" -silent -nogui -nomenu -conf "$(cygpath -w "$W/dbx.conf")" \
	-c "mount c \"$(cygpath -w "$W")\"" -c "c:" -c "RUN.BAT" -c "exit" >/dev/null 2>&1 || true
rm -f "$W"/*.MIL "$W"/*.CTL "$W"/MA.BAT "$W"/RUN.BAT "$W"/dbx.conf "$W"/BOOT/MIL.EXE
rmdir "$W/BOOT"
for t in MAKE.EXE MASM.EXE LINK.EXE MAPSYM.EXE; do rm -f "$W/$t"; done
# (MIL lists each procedure it translates, and one is called "error")
grep -E "^ *[1-9][0-9]* (Warning|Severe) +Errors|error [A-Z][0-9]|fatal" "$W/BUILD.LOG" || true
if cmp -s "$W/MIL.EXE" "$HERE/MIL.EXE"; then
	echo "out/MIL.EXE is identical to MIL.EXE"
elif [ -f "$W/MIL.EXE" ]; then
	echo "out/MIL.EXE differs from MIL.EXE"
else
	echo "NO EXE: see out/BUILD.LOG"; exit 1
fi
