mconst.asm: mconst.mil
   MIL -p -t mconst

.mil.obj:
   MIL -p -t $*
   MASM $*.ASM /Z;
   DEL $*.ASM

morder.obj: morder.mil

mstack.obj: mstack.mil

mdata.obj: mdata.mil

mmain.obj: mmain.mil

mmacros.obj: mmacros.mil

minit.obj: minit.mil

mfile.obj: mfile.mil

mgp.obj: mgp.mil

mblocks.obj: mblocks.mil

mend.obj: mend.mil

mil.exe: morder.obj mstack.obj mdata.obj mmain.obj \
         mmacros.obj minit.obj \
         mfile.obj mgp.obj mblocks.obj mend.obj
         link @mlink.ctl
         mapsym mil.map
