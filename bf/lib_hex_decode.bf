Hex decode: two ASCII chars (high, low) -> one byte.
Caller: ptr at high_ascii; uses cells 0..6. Result in cell 6 (or pass back).
Nibble: n = c-48; if n>9 then n-=39.
Byte = hi*16 + lo.

Subroutine convention: enter with ptr at high_ascii (first char).
  Cells: 0=high_ascii 1=low_ascii 2=48 3=nib_hi 4=nib_lo 5=byte 6=scratch
  We compute nib_hi from 0, nib_lo from 1, then byte = nib_hi*16+nib_lo at 5.

Step A: nibble from cell 0 into cell 3.
  0->3 copy, 3-=48 (use cell 2=48), then if 3>9 then 3-=39 (use 6 as flag).
  [->+>+<<]>>[-<<+>>]<<   copy 0 to 3 and restore 0
  >++++++++++++++++++++++++++++++++++++++++++++++++<  cell 2 = 48
  <<[>>-<-]>>  nib_hi (3) -= 48
  >>>+++++++++++++++++++++++++++++++++++++++++++++++  cell 6 = 39
  <<<<  at 3. Copy 3 to 6 (for compare). 6 -= 9. If 6>0 then 3-=39.
  [->+<] 3 to 4? No. We need: 3 to 6, 6-=9, while 6>0: 3-=39, 6--. So 6 as temp.
  Actually: 3 is nib_hi. 6 = 3. 6 -= 9. While 6>0: 3-=39, 6--. So:
  [->+>+<<]>>[-<<+>>]<<  copy 3 to 6
  >>------... 9 times: 6 -= 9
  [  while 6>0: 3-=39. So we need 39 in a cell. 7 = 39. While 6>0: 3-=39, 6--, 7-- and restore 7.
  This gets large. Minimal single-byte decode test follows.