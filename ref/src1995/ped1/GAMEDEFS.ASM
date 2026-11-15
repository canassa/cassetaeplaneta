;	Static Name Aliases
;
	TITLE   d:\lc\demo\gamedefs.cpp
	.286p
	.287
INCLUDELIB      SLIBC7
INCLUDELIB	OLDNAMES.LIB
_TEXT	SEGMENT  WORD PUBLIC 'CODE'
_TEXT	ENDS
_DATA	SEGMENT  WORD PUBLIC 'DATA'
_DATA	ENDS
CONST	SEGMENT  WORD PUBLIC 'CONST'
CONST	ENDS
_BSS	SEGMENT  WORD PUBLIC 'BSS'
_BSS	ENDS
$$SYMBOLS	SEGMENT  BYTE PUBLIC 'DEBSYM'
$$SYMBOLS	ENDS
$$TYPES	SEGMENT  BYTE PUBLIC 'DEBTYP'
$$TYPES	ENDS
DGROUP	GROUP	CONST, _BSS, _DATA
	ASSUME DS: DGROUP, SS: DGROUP
PUBLIC  ??_C@_0BO@GBKI@?$CI?$CF03d?0?$CF03d?$CJ?$DN?$DO?$CI?$CF03d?0?$CF03d?0?$CF03d?$CJ?$AA@
PUBLIC  ?TransparentColor@@3EA
PUBLIC  ?ObjectList@@3PAVobject_list@@A
EXTRN	WINGRECOMMENDDIBFORMAT:FAR
EXTRN	??_I@YCXPAXIHP6CX0@Z@Z:NEAR
EXTRN	WINGCREATEBITMAP:FAR
EXTRN	GETSYSTEMPALETTEENTRIES:FAR
EXTRN	_CopyDIBits:NEAR
EXTRN	_TranspDIBits:NEAR
EXTRN	CREATEPALETTE:FAR
EXTRN	WINGBITBLT:FAR
EXTRN	??3@YAXPAX@Z:NEAR
EXTRN	SELECTPALETTE:FAR
EXTRN	REALIZEPALETTE:FAR
EXTRN	_strlen:NEAR
EXTRN	GETDC:FAR
EXTRN	__aNchkstk:NEAR
EXTRN	RELEASEDC:FAR
EXTRN	__aNlmul:NEAR
EXTRN	_sprintf:NEAR
EXTRN	__aNldiv:NEAR
EXTRN	_abs:NEAR
EXTRN	BITBLT:FAR
EXTRN	TEXTOUT:FAR
EXTRN	SELECTOBJECT:FAR
EXTRN	PATBLT:FAR
EXTRN	WINGCREATEDC:FAR
_DATA      SEGMENT
?TransparentColor@@3EA	DB	0aH
	ORG	$+1
?ObjectList@@3PAVobject_list@@A	DW	00H
	ORG	$-4
??_C@_0BO@GBKI@?$CI?$CF03d?0?$CF03d?$CJ?$DN?$DO?$CI?$CF03d?0?$CF03d?0?$CF03d?$CJ?$AA@	DB	'(%03d,%03d)=>(%03d,%03d,%03d)',  00H
_DATA      ENDS
_BSS      SEGMENT
	ORG	$+4
PUBLIC  _SetSystemTimer
_SetSystemTimer	DW 02H DUP (?)
PUBLIC  _KillSystemTimer
_KillSystemTimer	DW 02H DUP (?)
	ORG	$-12
PUBLIC  ?Orientation@@3JA
?Orientation@@3JA	DW 02H DUP (?)
_BSS      ENDS
_TEXT      SEGMENT
	ASSUME	CS: _TEXT
	PUBLIC	?IncrOccupation@occup_matrix@@QACDPAVobject@@@Z	; occup_matrix::IncrOccupation
?IncrOccupation@occup_matrix@@QACDPAVobject@@@Z	PROC NEAR	; occup_matrix::IncrOccupation
; Line 11
	push	bp
	mov	bp,sp
	mov	ax,10	;000aH
	call	__aNchkstk
	push	di
	push	si
	mov	si,WORD PTR [bp+4]	;this
;	register si = this
;	o = 6
; Line 12
	mov	bx,WORD PTR [bp+6]	;o
	cmp	WORD PTR [bx+8],0
	jge	$JCC21
	jmp	$I8056
$JCC21:
	mov	bx,WORD PTR [bp+6]	;o
	cmp	WORD PTR [bx+10],0
	jl	$JCC33
	jmp	$I8055
$JCC33:
$I8056:
; Line 13
	mov	al,255	;00ffH
	jmp	$EX8054
; Line 14
	jmp	$I8058
$I8055:
; Line 15
;	ColF = -8
;	register di = i
;	j = -10
;	LineI = -2
;	ColI = -4
;	LineF = -6
; Line 18
	mov	bx,WORD PTR [bp+6]	;o
	mov	ax,WORD PTR [bx+10]
	mov	bx,WORD PTR [bp+6]	;o
	add	ax,WORD PTR [bx+1100]
	sar	ax,4
	mov	WORD PTR [bp-2],ax	;LineI
; Line 19
	mov	bx,WORD PTR [bp+6]	;o
	mov	ax,WORD PTR [bx+8]
	mov	bx,WORD PTR [bp+6]	;o
	add	ax,WORD PTR [bx+1098]
	sar	ax,4
	mov	WORD PTR [bp-4],ax	;ColI
; Line 21
	mov	bx,WORD PTR [bp+6]	;o
	mov	ax,WORD PTR [bx+10]
	mov	bx,WORD PTR [bp+6]	;o
	add	ax,WORD PTR [bx+1100]
	mov	bx,WORD PTR [bp+6]	;o
	add	ax,WORD PTR [bx+1104]
	sar	ax,4
	mov	WORD PTR [bp-6],ax	;LineF
; Line 22
	mov	bx,WORD PTR [bp+6]	;o
	mov	ax,WORD PTR [bx+8]
	mov	bx,WORD PTR [bp+6]	;o
	add	ax,WORD PTR [bx+1098]
	mov	bx,WORD PTR [bp+6]	;o
	add	ax,WORD PTR [bx+1102]
	sar	ax,4
	mov	WORD PTR [bp-8],ax	;ColF
; Line 24
	mov	di,WORD PTR [bp-2]	;LineI
	jmp	$F8065
$FC8066:
	inc	di
$F8065:
	cmp	WORD PTR [bp-6],di	;LineF
	jge	$JCC146
	jmp	$FB8067
$JCC146:
; Line 25
; Line 26
	mov	ax,WORD PTR [bp-4]	;ColI
	mov	WORD PTR [bp-10],ax	;j
	jmp	$F8068
$FC8069:
	inc	WORD PTR [bp-10]	;j
$F8068:
	mov	ax,WORD PTR [bp-10]	;j
	cmp	WORD PTR [bp-8],ax	;ColF
	jg	$JCC169
	jmp	$FB8070
$JCC169:
; Line 27
; Line 28
	push	di
	push	WORD PTR [bp-10]	;j
	push	WORD PTR [bp+6]	;o
	push	si
	call	?IncrOccup@occup_matrix@@QACDHHPAVobject@@@Z	; occup_matrix::IncrOccup
; Line 29
	jmp	$FC8069
$FB8070:
; Line 30
	jmp	$FC8066
$FB8067:
; Line 31
	mov	al,1
	jmp	$EX8054
; Line 32
$I8058:
; Line 33
$EX8054:
	pop	si
	pop	di
	leave	
	ret	4

?IncrOccupation@occup_matrix@@QACDPAVobject@@@Z	ENDP
	PUBLIC	?DecrOccupation@occup_matrix@@QACDPAVobject@@@Z	; occup_matrix::DecrOccupation
?DecrOccupation@occup_matrix@@QACDPAVobject@@@Z	PROC NEAR	; occup_matrix::DecrOccupation
; Line 37
	push	bp
	mov	bp,sp
	mov	ax,10	;000aH
	call	__aNchkstk
	push	di
	push	si
	mov	si,WORD PTR [bp+4]	;this
;	register si = this
;	o = 6
; Line 38
	mov	bx,WORD PTR [bp+6]	;o
	cmp	WORD PTR [bx+8],0
	jge	$JCC223
	jmp	$I8076
$JCC223:
	mov	bx,WORD PTR [bp+6]	;o
	cmp	WORD PTR [bx+10],0
	jl	$JCC235
	jmp	$I8075
$JCC235:
$I8076:
; Line 39
	mov	al,255	;00ffH
	jmp	$EX8074
; Line 40
	jmp	$I8078
$I8075:
; Line 41
;	register di = i
;	j = -10
;	LineI = -2
;	ColI = -4
;	LineF = -6
;	ColF = -8
; Line 44
	mov	bx,WORD PTR [bp+6]	;o
	mov	ax,WORD PTR [bx+10]
	mov	bx,WORD PTR [bp+6]	;o
	add	ax,WORD PTR [bx+1100]
	sar	ax,4
	mov	WORD PTR [bp-2],ax	;LineI
; Line 45
	mov	bx,WORD PTR [bp+6]	;o
	mov	ax,WORD PTR [bx+8]
	mov	bx,WORD PTR [bp+6]	;o
	add	ax,WORD PTR [bx+1098]
	sar	ax,4
	mov	WORD PTR [bp-4],ax	;ColI
; Line 47
	mov	bx,WORD PTR [bp+6]	;o
	mov	ax,WORD PTR [bx+10]
	mov	bx,WORD PTR [bp+6]	;o
	add	ax,WORD PTR [bx+1100]
	mov	bx,WORD PTR [bp+6]	;o
	add	ax,WORD PTR [bx+1104]
	sar	ax,4
	mov	WORD PTR [bp-6],ax	;LineF
; Line 48
	mov	bx,WORD PTR [bp+6]	;o
	mov	ax,WORD PTR [bx+8]
	mov	bx,WORD PTR [bp+6]	;o
	add	ax,WORD PTR [bx+1098]
	mov	bx,WORD PTR [bp+6]	;o
	add	ax,WORD PTR [bx+1102]
	sar	ax,4
	mov	WORD PTR [bp-8],ax	;ColF
; Line 50
	mov	di,WORD PTR [bp-2]	;LineI
	jmp	$F8085
$FC8086:
	inc	di
$F8085:
	cmp	WORD PTR [bp-6],di	;LineF
	jge	$JCC348
	jmp	$FB8087
$JCC348:
; Line 51
; Line 52
	mov	ax,WORD PTR [bp-4]	;ColI
	mov	WORD PTR [bp-10],ax	;j
	jmp	$F8088
$FC8089:
	inc	WORD PTR [bp-10]	;j
$F8088:
	mov	ax,WORD PTR [bp-10]	;j
	cmp	WORD PTR [bp-8],ax	;ColF
	jg	$JCC371
	jmp	$FB8090
$JCC371:
; Line 53
; Line 54
	push	di
	push	WORD PTR [bp-10]	;j
	push	WORD PTR [bp+6]	;o
	push	si
	call	?DecrOccup@occup_matrix@@QACDHHPAVobject@@@Z	; occup_matrix::DecrOccup
; Line 55
	jmp	$FC8089
$FB8090:
; Line 56
	jmp	$FC8086
$FB8087:
; Line 57
	mov	al,1
	jmp	$EX8074
; Line 58
$I8078:
; Line 59
$EX8074:
	pop	si
	pop	di
	leave	
	ret	4

?DecrOccupation@occup_matrix@@QACDPAVobject@@@Z	ENDP
	PUBLIC	?Occupation@occup_matrix@@QACDHHHH@Z	; occup_matrix::Occupation
?Occupation@occup_matrix@@QACDHHHH@Z	PROC NEAR	; occup_matrix::Occupation
; Line 62
	push	bp
	mov	bp,sp
	mov	ax,2
	call	__aNchkstk
	push	di
	push	si
	mov	si,WORD PTR [bp+4]	;this
;	OccupObj = -2
;	register si = this
;	X = 12
;	Y = 10
;	Width = 8
;	Height = 6
; Line 63
	mov	WORD PTR [bp-2],0	;OccupObj
; Line 65
	push	WORD PTR [bp+12]	;X
	push	WORD PTR [bp+10]	;Y
	push	WORD PTR [bp+8]	;Width
	push	WORD PTR [bp+6]	;Height
	lea	ax,WORD PTR [bp-2]	;OccupObj
	push	ax
	push	si
	call	?Occupation@occup_matrix@@QACDHHHHAAPAVobject@@@Z	; occup_matrix::Occupation
	jmp	$EX8097
; Line 66
$EX8097:
	pop	si
	pop	di
	leave	
	ret	10	;000aH

?Occupation@occup_matrix@@QACDHHHH@Z	ENDP
	PUBLIC	?Occupation@occup_matrix@@QACDHHHHAAPAVobject@@@Z	; occup_matrix::Occupation
?Occupation@occup_matrix@@QACDHHHHAAPAVobject@@@Z	PROC NEAR	; occup_matrix::Occupation
; Line 69
	push	bp
	mov	bp,sp
	mov	ax,8
	call	__aNchkstk
	push	di
	push	si
	mov	si,WORD PTR [bp+4]	;this
;	register si = this
;	X = 14
;	Y = 12
;	Width = 10
;	Height = 8
;	OccupObj = 6
; Line 70
	cmp	WORD PTR [bp+14],0	;X
	jge	$JCC470
	jmp	$I8107
$JCC470:
	cmp	WORD PTR [bp+12],0	;Y
	jl	$JCC479
	jmp	$I8106
$JCC479:
$I8107:
; Line 71
	mov	al,255	;00ffH
	jmp	$EX8105
; Line 72
	jmp	$I8109
$I8106:
; Line 73
;	register di = i
;	j = -4
;	m = -6
;	n = -8
;	occ = -2
; Line 78
	sar	WORD PTR [bp+12],4	;Y
; Line 79
	sar	WORD PTR [bp+14],4	;X
; Line 81
	mov	ax,WORD PTR [bp+8]	;Height
	sar	ax,4
	add	ax,WORD PTR [bp+12]	;Y
	mov	WORD PTR [bp-6],ax	;m
; Line 82
	mov	ax,WORD PTR [bp+10]	;Width
	sar	ax,4
	add	ax,WORD PTR [bp+14]	;X
	mov	WORD PTR [bp-8],ax	;n
; Line 84
	mov	di,WORD PTR [bp+12]	;Y
	jmp	$F8115
$FC8116:
	inc	di
$F8115:
	cmp	WORD PTR [bp-6],di	;m
	jg	$JCC534
	jmp	$FB8117
$JCC534:
; Line 85
; Line 86
	mov	ax,WORD PTR [bp+14]	;X
	mov	WORD PTR [bp-4],ax	;j
	jmp	$F8118
$FC8119:
	inc	WORD PTR [bp-4]	;j
$F8118:
	mov	ax,WORD PTR [bp-4]	;j
	cmp	WORD PTR [bp-8],ax	;n
	jg	$JCC557
	jmp	$FB8120
$JCC557:
; Line 87
; Line 88
	imul	bx,di,81	;0051H
	add	bx,WORD PTR [bp-4]	;j
	mov	al,BYTE PTR [bx][si]
	mov	BYTE PTR [bp-2],al	;occ
; Line 89
	imul	bx,di,81	;0051H
	add	bx,WORD PTR [bp-4]	;j
	shl	bx,1
	mov	ax,WORD PTR [bx+5266][si]
	mov	bx,WORD PTR [bp+6]	;OccupObj
	mov	WORD PTR [bx],ax
; Line 90
	imul	bx,di,81	;0051H
	add	bx,WORD PTR [bp-4]	;j
	shl	bx,1
	mov	ax,WORD PTR [bx+5266][si]
	mov	WORD PTR [si+15796],ax
; Line 93
	cmp	BYTE PTR [bp-2],0	;occ
	jne	$JCC610
	jmp	$I8122
$JCC610:
; Line 94
; Line 95
	mov	al,BYTE PTR [bp-2]	;occ
	jmp	$EX8105
; Line 96
; Line 97
$I8122:
	jmp	$FC8119
$FB8120:
; Line 98
	jmp	$FC8116
$FB8117:
; Line 100
	mov	al,0
	jmp	$EX8105
; Line 101
$I8109:
; Line 102
$EX8105:
	pop	si
	pop	di
	leave	
	ret	12	;000cH

?Occupation@occup_matrix@@QACDHHHHAAPAVobject@@@Z	ENDP
	PUBLIC	?Init@object@@QACPAV1@PAVscreen@@@Z	; object::Init
?Init@object@@QACPAV1@PAVscreen@@@Z	PROC NEAR	; object::Init
; Line 107
	push	bp
	mov	bp,sp
	mov	ax,2
	call	__aNchkstk
	push	di
	push	si
	mov	si,WORD PTR [bp+4]	;this
;	hback = -2
;	register si = this
;	Screen = 6
; Line 110
	mov	bx,WORD PTR [bp+6]	;Screen
	push	si
	lea	di,WORD PTR [si+30]
	lea	si,WORD PTR [bx+32]
	mov	ax,ds
	mov	es,ax
	mov	cx,532	;0214H
	rep	movsw
	pop	si
; Line 113
	push	si
	call	?FrameWidth@object@@QACHXZ	; object::FrameWidth
	cwd	
	mov	WORD PTR [si+34],ax
	mov	WORD PTR [si+36],dx
; Line 114
	push	si
	call	?Sprite@object@@QACAAVsprite@@XZ	; object::Sprite
	mov	bx,ax
	mov	ax,WORD PTR [bx+4]
	push	si
	mov	di,ax
	call	?FrameHeight@object@@QACHXZ	; object::FrameHeight
	mov	cx,ax
	mov	ax,di
	mul	cx
	mov	WORD PTR [si+38],ax
	mov	WORD PTR [si+40],0
; Line 116
	call	FAR PTR WINGCREATEDC
	mov	WORD PTR [si+24],ax
; Line 117
	sub	ax,ax
	mov	WORD PTR [si+28],ax
	mov	WORD PTR [si+26],ax
; Line 120
	push	WORD PTR [si+24]
	lea	ax,WORD PTR [si+30]
	push	ds
	push	ax
	lea	ax,WORD PTR [si+26]
	push	ds
	push	ax
	call	FAR PTR WINGCREATEBITMAP
	mov	WORD PTR [bp-2],ax	;hback
; Line 122
	push	WORD PTR [si+24]
	push	WORD PTR [bp-2]	;hback
	call	FAR PTR SELECTOBJECT
	mov	WORD PTR [si+1094],ax
; Line 124
	push	WORD PTR [si+24]
	push	0
	push	0
	push	si
	call	?FrameWidth@object@@QACHXZ	; object::FrameWidth
	push	ax
	push	si
	call	?FrameHeight@object@@QACHXZ	; object::FrameHeight
	push	ax
	push	0
	push	66	;0042H
	call	FAR PTR PATBLT
; Line 129
; Line 131
	mov	bx,WORD PTR [bp+6]	;Screen
	push	WORD PTR [bx+2]
	push	si
	call	?SaveBackGround@object@@QACXPBUHDC__@@@Z	; object::SaveBackGround
; Line 135
	mov	ax,WORD PTR [bp+6]	;Screen
	add	ax,32	;0020H
	push	ds
	push	ax
	mov	bx,WORD PTR [bp+6]	;Screen
	push	WORD PTR [bx+6]
	push	WORD PTR [bx+4]
	push	si
	call	?PutIntoBuffer@object@@QACXPEUtagBITMAPINFO@@PEX@Z	; object::PutIntoBuffer
; Line 136
; Line 138
	push	WORD PTR [bp+6]	;Screen
	push	si
	mov	bx,WORD PTR [si]
	call	WORD PTR [bx+24]
; Line 140
	mov	ax,si
	jmp	$EX8126
; Line 141
$EX8126:
	pop	si
	pop	di
	leave	
	ret	4

?Init@object@@QACPAV1@PAVscreen@@@Z	ENDP
	PUBLIC	?Init@_3D_object@@UACPAV1@PAV_3D_screen@@@Z	; _3D_object::Init
?Init@_3D_object@@UACPAV1@PAV_3D_screen@@@Z	PROC NEAR	; _3D_object::Init
; Line 144
	push	bp
	mov	bp,sp
	mov	ax,0
	call	__aNchkstk
	push	di
	push	si
	mov	si,WORD PTR [bp+4]	;this
;	register si = this
;	Screen = 6
; Line 145
	push	WORD PTR [bp+6]	;Screen
	mov	bx,WORD PTR [si+2]
	mov	ax,WORD PTR [bx+2]
	add	ax,si
	add	ax,2
	push	ax
	call	?Init@object@@QACPAV1@PAVscreen@@@Z	; object::Init
; Line 147
	mov	ax,0
	mov	WORD PTR [si+14],ax
	mov	WORD PTR [si+12],ax
	mov	WORD PTR [si+10],ax
; Line 149
	mov	ax,si
	jmp	$EX8134
; Line 150
$EX8134:
	pop	si
	pop	di
	leave	
	ret	4

?Init@_3D_object@@UACPAV1@PAV_3D_screen@@@Z	ENDP
	PUBLIC	?x3D@_3D_object@@UACHXZ	; _3D_object::x3D
?x3D@_3D_object@@UACHXZ	PROC NEAR	; _3D_object::x3D
; Line 152
	push	bp
	mov	bp,sp
	mov	ax,0
	call	__aNchkstk
	push	di
	push	si
	mov	si,WORD PTR [bp+4]	;this
;	register si = this
	mov	ax,WORD PTR [si-18]
	jmp	$EX8137
$EX8137:
	pop	si
	pop	di
	leave	
	ret	2

?x3D@_3D_object@@UACHXZ	ENDP
	PUBLIC	?y3D@_3D_object@@UACHXZ	; _3D_object::y3D
?y3D@_3D_object@@UACHXZ	PROC NEAR	; _3D_object::y3D
; Line 153
	push	bp
	mov	bp,sp
	mov	ax,0
	call	__aNchkstk
	push	di
	push	si
	mov	si,WORD PTR [bp+4]	;this
;	register si = this
	mov	ax,WORD PTR [si-16]
	jmp	$EX8140
$EX8140:
	pop	si
	pop	di
	leave	
	ret	2

?y3D@_3D_object@@UACHXZ	ENDP
	PUBLIC	?z3D@_3D_object@@UACHXZ	; _3D_object::z3D
?z3D@_3D_object@@UACHXZ	PROC NEAR	; _3D_object::z3D
; Line 154
	push	bp
	mov	bp,sp
	mov	ax,0
	call	__aNchkstk
	push	di
	push	si
	mov	si,WORD PTR [bp+4]	;this
;	register si = this
	mov	ax,WORD PTR [si-14]
	jmp	$EX8143
$EX8143:
	pop	si
	pop	di
	leave	
	ret	2

?z3D@_3D_object@@UACHXZ	ENDP
	PUBLIC	?w3D@_3D_object@@UACHXZ	; _3D_object::w3D
?w3D@_3D_object@@UACHXZ	PROC NEAR	; _3D_object::w3D
; Line 155
	push	bp
	mov	bp,sp
	mov	ax,0
	call	__aNchkstk
	push	di
	push	si
	mov	si,WORD PTR [bp+4]	;this
;	register si = this
	mov	ax,WORD PTR [si-12]
	jmp	$EX8146
$EX8146:
	pop	si
	pop	di
	leave	
	ret	2

?w3D@_3D_object@@UACHXZ	ENDP
	PUBLIC	?h3D@_3D_object@@UACHXZ	; _3D_object::h3D
?h3D@_3D_object@@UACHXZ	PROC NEAR	; _3D_object::h3D
; Line 156
	push	bp
	mov	bp,sp
	mov	ax,0
	call	__aNchkstk
	push	di
	push	si
	mov	si,WORD PTR [bp+4]	;this
;	register si = this
	mov	ax,WORD PTR [si-10]
	jmp	$EX8149
$EX8149:
	pop	si
	pop	di
	leave	
	ret	2

?h3D@_3D_object@@UACHXZ	ENDP
	PUBLIC	?d3D@_3D_object@@UACHXZ	; _3D_object::d3D
?d3D@_3D_object@@UACHXZ	PROC NEAR	; _3D_object::d3D
; Line 157
	push	bp
	mov	bp,sp
	mov	ax,0
	call	__aNchkstk
	push	di
	push	si
	mov	si,WORD PTR [bp+4]	;this
;	register si = this
	mov	ax,WORD PTR [si-8]
	jmp	$EX8152
$EX8152:
	pop	si
	pop	di
	leave	
	ret	2

?d3D@_3D_object@@UACHXZ	ENDP
	PUBLIC	?DetectedCollision@_3D_moveable@@UAC?AW4boolean@@PAVobject@@PAV_3D_screen@@@Z	; _3D_moveable::DetectedCollision
?DetectedCollision@_3D_moveable@@UAC?AW4boolean@@PAVobject@@PAV_3D_screen@@@Z	PROC NEAR	; _3D_moveable::DetectedCollision
; Line 162
	push	bp
	mov	bp,sp
	mov	ax,24	;0018H
	call	__aNchkstk
	push	di
	push	si
	mov	si,WORD PTR [bp+4]	;this
;	_Y = -4
;	_X = -8
;	_x = -10
;	_y = -12
;	ox = -14
;	oy = -16
;	oz = -18
;	ow = -20
;	oh = -22
;	od = -24
;	register si = this
;	o = 8
;	Screen = 6
; Line 163
	mov	bx,WORD PTR [bp+6]	;Screen
	mov	ax,WORD PTR [bx+18]
	mov	bx,WORD PTR [si+2]
	mov	bx,WORD PTR [bx+4]
	sub	ax,WORD PTR [bx+20][si]
	sub	ax,WORD PTR [si+28]
	mov	bx,WORD PTR [bp+6]	;Screen
	add	ax,WORD PTR [bx+22]
	cwd	
	mov	WORD PTR [bp-4],ax	;_Y
	mov	WORD PTR [bp-2],dx
; Line 164
	mov	bx,WORD PTR [si+2]
	mov	bx,WORD PTR [bx+4]
	mov	ax,WORD PTR [bx+18][si]
	mov	bx,WORD PTR [bp+6]	;Screen
	sub	ax,WORD PTR [bx+16]
	add	ax,WORD PTR [si+26]
	cwd	
	mov	WORD PTR [bp-8],ax	;_X
	mov	WORD PTR [bp-6],dx
; Line 168
	mov	bx,WORD PTR [bp+6]	;Screen
	mov	ax,WORD PTR [bx+1100]
	cwd	
	mov	cx,WORD PTR [bp-4]	;_Y
	mov	bx,WORD PTR [bp-2]
	sub	cx,ax
	sbb	bx,dx
	push	bx
	push	cx
	mov	bx,WORD PTR [bp+6]	;Screen
	mov	ax,WORD PTR [bx+1098]
	cwd	
	mov	cx,WORD PTR [bp-8]	;_X
	mov	bx,WORD PTR [bp-6]
	sub	cx,ax
	sbb	bx,dx
	push	bx
	push	cx
	mov	bx,WORD PTR [si+2]
	mov	bx,WORD PTR [bx+4]
	mov	ax,WORD PTR [bx+10][si]
	cwd	
	sub	ax,WORD PTR [bp-4]	;_Y
	sbb	dx,WORD PTR [bp-2]
	push	dx
	push	ax
	call	__aNlmul
	push	dx
	push	ax
	call	__aNldiv
	mov	bx,WORD PTR [bp+6]	;Screen
	add	ax,WORD PTR [bx+1104]
	add	ax,WORD PTR [bp-8]	;_X
	mov	WORD PTR [bp-10],ax	;_x
; Line 170
	mov	bx,WORD PTR [bp+6]	;Screen
	mov	ax,WORD PTR [bx+1100]
	cwd	
	mov	cx,WORD PTR [bp-4]	;_Y
	mov	bx,WORD PTR [bp-2]
	sub	cx,ax
	sbb	bx,dx
	push	bx
	push	cx
	mov	bx,WORD PTR [bp+6]	;Screen
	mov	ax,WORD PTR [bx+1102]
	cwd	
	push	dx
	push	ax
	mov	bx,WORD PTR [si+2]
	mov	bx,WORD PTR [bx+4]
	mov	ax,WORD PTR [bx+10][si]
	cwd	
	sub	ax,WORD PTR [bp-4]	;_Y
	sbb	dx,WORD PTR [bp-2]
	push	dx
	push	ax
	call	__aNlmul
	push	dx
	push	ax
	call	__aNldiv
	mov	WORD PTR [bp-12],ax	;_y
; Line 173
	push	WORD PTR [bp+8]	;o
	mov	bx,WORD PTR [bp+8]	;o
	mov	bx,WORD PTR [bx]
	call	WORD PTR [bx]
	mov	WORD PTR [bp-14],ax	;ox
; Line 174
	push	WORD PTR [bp+8]	;o
	mov	bx,WORD PTR [bp+8]	;o
	mov	bx,WORD PTR [bx]
	call	WORD PTR [bx+2]
	mov	WORD PTR [bp-16],ax	;oy
; Line 175
	push	WORD PTR [bp+8]	;o
	mov	bx,WORD PTR [bp+8]	;o
	mov	bx,WORD PTR [bx]
	call	WORD PTR [bx+4]
	mov	WORD PTR [bp-18],ax	;oz
; Line 176
	push	WORD PTR [bp+8]	;o
	mov	bx,WORD PTR [bp+8]	;o
	mov	bx,WORD PTR [bx]
	call	WORD PTR [bx+6]
	mov	WORD PTR [bp-20],ax	;ow
; Line 177
	push	WORD PTR [bp+8]	;o
	mov	bx,WORD PTR [bp+8]	;o
	mov	bx,WORD PTR [bx]
	call	WORD PTR [bx+8]
	mov	WORD PTR [bp-22],ax	;oh
; Line 178
	push	WORD PTR [bp+8]	;o
	mov	bx,WORD PTR [bp+8]	;o
	mov	bx,WORD PTR [bx]
	call	WORD PTR [bx+10]
	mov	WORD PTR [bp-24],ax	;od
; Line 180
	mov	bx,WORD PTR [si+2]
	mov	bx,WORD PTR [bx+4]
	mov	ax,WORD PTR [bx+12][si]
	add	ax,WORD PTR [bp-10]	;_x
	cmp	ax,WORD PTR [bp-14]	;ox
	jl	$JCC1358
	jmp	$I8173
$JCC1358:
; Line 181
	mov	ax,0
	jmp	$EX8156
; Line 183
$I8173:
	mov	ax,WORD PTR [bp-20]	;ow
	add	ax,WORD PTR [bp-14]	;ox
	cmp	ax,WORD PTR [bp-10]	;_x
	jl	$JCC1378
	jmp	$I8174
$JCC1378:
; Line 184
	mov	ax,0
	jmp	$EX8156
; Line 186
$I8174:
	mov	bx,WORD PTR [si+2]
	mov	bx,WORD PTR [bx+4]
	mov	ax,WORD PTR [bx+16][si]
	add	ax,WORD PTR [bp-12]	;_y
	cmp	ax,WORD PTR [bp-16]	;oy
	jl	$JCC1404
	jmp	$I8175
$JCC1404:
; Line 187
	mov	ax,0
	jmp	$EX8156
; Line 189
$I8175:
	mov	ax,WORD PTR [bp-24]	;od
	add	ax,WORD PTR [bp-16]	;oy
	cmp	ax,WORD PTR [bp-12]	;_y
	jl	$JCC1424
	jmp	$I8176
$JCC1424:
; Line 190
	mov	ax,0
	jmp	$EX8156
; Line 192
$I8176:
	mov	bx,WORD PTR [si+2]
	mov	bx,WORD PTR [bx+4]
	mov	ax,WORD PTR [bx+10][si]
	mov	bx,WORD PTR [si+2]
	mov	bx,WORD PTR [bx+4]
	add	ax,WORD PTR [bx+14][si]
	cmp	ax,WORD PTR [bp-18]	;oz
	jl	$JCC1456
	jmp	$I8177
$JCC1456:
; Line 193
	mov	ax,0
	jmp	$EX8156
; Line 195
$I8177:
	mov	ax,WORD PTR [bp-22]	;oh
	add	ax,WORD PTR [bp-18]	;oz
	mov	bx,WORD PTR [si+2]
	mov	bx,WORD PTR [bx+4]
	cmp	WORD PTR [bx+10][si],ax
	jg	$JCC1482
	jmp	$I8178
$JCC1482:
; Line 196
	mov	ax,0
	jmp	$EX8156
; Line 198
$I8178:
	mov	ax,1
	jmp	$EX8156
; Line 199
$EX8156:
	pop	si
	pop	di
	leave	
	ret	6

?DetectedCollision@_3D_moveable@@UAC?AW4boolean@@PAVobject@@PAV_3D_screen@@@Z	ENDP
	PUBLIC	?DetectedCollision@moveable@@UAC?AW4boolean@@PAVobject@@PAVscreen@@@Z	; moveable::DetectedCollision
?DetectedCollision@moveable@@UAC?AW4boolean@@PAVobject@@PAVscreen@@@Z	PROC NEAR	; moveable::DetectedCollision
; Line 202
	push	bp
	mov	bp,sp
	mov	ax,0
	call	__aNchkstk
	push	di
	push	si
	mov	si,WORD PTR [bp+4]	;this
;	register si = this
;	o = 8
;	Screen = 6
; Line 203
	mov	bx,WORD PTR [si+2]
	mov	bx,WORD PTR [bx+2]
	mov	ax,WORD PTR [bx+10][si]
	mov	bx,WORD PTR [si+2]
	mov	bx,WORD PTR [bx+2]
	add	ax,WORD PTR [bx+1104][si]
	mov	bx,WORD PTR [bp+8]	;o
	cmp	ax,WORD PTR [bx+8]
	jl	$JCC1544
	jmp	$I8183
$JCC1544:
; Line 204
	mov	ax,0
	jmp	$EX8182
; Line 206
$I8183:
	mov	bx,WORD PTR [bp+8]	;o
	mov	ax,WORD PTR [bx+8]
	mov	bx,WORD PTR [bp+8]	;o
	add	ax,WORD PTR [bx+1102]
	mov	bx,WORD PTR [si+2]
	mov	bx,WORD PTR [bx+2]
	cmp	WORD PTR [bx+10][si],ax
	jg	$JCC1577
	jmp	$I8184
$JCC1577:
; Line 207
	mov	ax,0
	jmp	$EX8182
; Line 209
$I8184:
	mov	bx,WORD PTR [si+2]
	mov	bx,WORD PTR [bx+2]
	mov	ax,WORD PTR [bx+12][si]
	mov	bx,WORD PTR [si+2]
	mov	bx,WORD PTR [bx+2]
	add	ax,WORD PTR [bx+1106][si]
	mov	bx,WORD PTR [bp+8]	;o
	cmp	ax,WORD PTR [bx+10]
	jl	$JCC1613
	jmp	$I8185
$JCC1613:
; Line 210
	mov	ax,0
	jmp	$EX8182
; Line 212
$I8185:
	mov	bx,WORD PTR [bp+8]	;o
	mov	ax,WORD PTR [bx+10]
	mov	bx,WORD PTR [bp+8]	;o
	add	ax,WORD PTR [bx+1104]
	mov	bx,WORD PTR [si+2]
	mov	bx,WORD PTR [bx+2]
	cmp	WORD PTR [bx+12][si],ax
	jg	$JCC1646
	jmp	$I8186
$JCC1646:
; Line 213
	mov	ax,0
	jmp	$EX8182
; Line 215
$I8186:
	mov	ax,1
	jmp	$EX8182
; Line 216
$EX8182:
	pop	si
	pop	di
	leave	
	ret	6

?DetectedCollision@moveable@@UAC?AW4boolean@@PAVobject@@PAVscreen@@@Z	ENDP
	PUBLIC	?CanGo@moveable@@UAC?AW4boolean@@PAVoccup_screen@@@Z	; moveable::CanGo
?CanGo@moveable@@UAC?AW4boolean@@PAVoccup_screen@@@Z	PROC NEAR	; moveable::CanGo
; Line 219
	push	bp
	mov	bp,sp
	mov	ax,0
	call	__aNchkstk
	push	di
	push	si
	mov	si,WORD PTR [bp+4]	;this
;	register si = this
;	Screen = 6
; Line 221
; Line 222
	mov	bx,WORD PTR [si+2]
	mov	bx,WORD PTR [bx+2]
	mov	ax,WORD PTR [bx+1100][si]
	add	ax,WORD PTR [si+26]
	push	ax
	mov	bx,WORD PTR [si+2]
	mov	bx,WORD PTR [bx+2]
	mov	ax,WORD PTR [bx+1102][si]
	add	ax,WORD PTR [si+28]
	push	ax
	mov	bx,WORD PTR [si+2]
	mov	bx,WORD PTR [bx+2]
	push	WORD PTR [bx+1104][si]
	mov	bx,WORD PTR [si+2]
	mov	bx,WORD PTR [bx+2]
	push	WORD PTR [bx+1106][si]
	push	WORD PTR [bp+6]	;Screen
	mov	bx,WORD PTR [bp+6]	;Screen
	mov	bx,WORD PTR [bx]
	call	WORD PTR [bx+4]
	jmp	$EX8189
; Line 223
; Line 251
$EX8189:
	pop	si
	pop	di
	leave	
	ret	4

?CanGo@moveable@@UAC?AW4boolean@@PAVoccup_screen@@@Z	ENDP
	PUBLIC	?CanGo@_3D_moveable@@UAC?AW4boolean@@PAV_3D_screen@@@Z	; _3D_moveable::CanGo
?CanGo@_3D_moveable@@UAC?AW4boolean@@PAV_3D_screen@@@Z	PROC NEAR	; _3D_moveable::CanGo
; Line 255
	push	bp
	mov	bp,sp
	mov	ax,4
	call	__aNchkstk
	push	di
	push	si
	mov	si,WORD PTR [bp+4]	;this
;	register si = this
;	Screen = 6
; Line 261
;	Occup3DObj = -2
;	occ = -4
; Line 267
	mov	bx,WORD PTR [si+2]
	mov	bx,WORD PTR [bx+2]
	mov	ax,WORD PTR [bx+1100][si]
	add	ax,WORD PTR [si+26]
	push	ax
	mov	bx,WORD PTR [si+2]
	mov	bx,WORD PTR [bx+2]
	mov	ax,WORD PTR [bx+1102][si]
	add	ax,WORD PTR [si+28]
	push	ax
	mov	bx,WORD PTR [si+2]
	mov	bx,WORD PTR [bx+2]
	push	WORD PTR [bx+1104][si]
	mov	bx,WORD PTR [si+2]
	mov	bx,WORD PTR [bx+2]
	push	WORD PTR [bx+1106][si]
	lea	ax,WORD PTR [bp-2]	;Occup3DObj
	push	ax
	mov	bx,WORD PTR [bp+6]	;Screen
	push	WORD PTR [bx+1096]
	call	?Occupation@occup_matrix@@QACDHHHHAAPAVobject@@@Z	; occup_matrix::Occupation
	mov	BYTE PTR [bp-4],al	;occ
; Line 269
	cmp	BYTE PTR [bp-4],0	;occ
	jg	$JCC1834
	jmp	$I8196
$JCC1834:
; Line 270
; Line 271
	cmp	BYTE PTR [bp-4],1	;occ
	je	$JCC1843
	jmp	$I8197
$JCC1843:
; Line 272
; Line 273
	push	WORD PTR [bp-2]	;Occup3DObj
	push	WORD PTR [bp+6]	;Screen
	push	si
	mov	bx,WORD PTR [si]
	call	WORD PTR [bx+22]
	cmp	ax,1
	sbb	ax,ax
	neg	ax
	jmp	$EX8192
; Line 274
; Line 275
	jmp	$I8199
$I8197:
; Line 276
; Line 277
	mov	ax,0
	jmp	$EX8192
; Line 279
$I8199:
; Line 281
; Line 282
	jmp	$I8200
$I8196:
; Line 283
; Line 284
	cmp	BYTE PTR [bp-4],1	;occ
	sbb	ax,ax
	neg	ax
	jmp	$EX8192
; Line 285
$I8200:
; Line 287
; Line 288
$EX8192:
	pop	si
	pop	di
	leave	
	ret	4

?CanGo@_3D_moveable@@UAC?AW4boolean@@PAV_3D_screen@@@Z	ENDP
	PUBLIC	?Set3DPosition@_3D_object@@UACPAV1@PAV_3D_screen@@H@Z	; _3D_object::Set3DPosition
?Set3DPosition@_3D_object@@UACPAV1@PAV_3D_screen@@H@Z	PROC NEAR	; _3D_object::Set3DPosition
; Line 293
	push	bp
	mov	bp,sp
	mov	ax,8
	call	__aNchkstk
	push	di
	push	si
	mov	si,WORD PTR [bp+4]	;this
;	_Y = -4
;	_X = -8
;	register si = this
;	Screen = 8
;	_z = 6
; Line 294
	mov	bx,WORD PTR [bp+8]	;Screen
	mov	ax,WORD PTR [bx+18]
	mov	bx,WORD PTR [si+2]
	mov	bx,WORD PTR [bx+2]
	sub	ax,WORD PTR [bx+12][si]
	sub	ax,WORD PTR [si+18]
	mov	bx,WORD PTR [bp+8]	;Screen
	add	ax,WORD PTR [bx+22]
	cwd	
	mov	WORD PTR [bp-4],ax	;_Y
	mov	WORD PTR [bp-2],dx
; Line 295
	mov	bx,WORD PTR [si+2]
	mov	bx,WORD PTR [bx+2]
	mov	ax,WORD PTR [bx+10][si]
	mov	bx,WORD PTR [bp+8]	;Screen
	sub	ax,WORD PTR [bx+16]
	add	ax,WORD PTR [si+16]
	cwd	
	mov	WORD PTR [bp-8],ax	;_X
	mov	WORD PTR [bp-6],dx
; Line 297
	mov	ax,WORD PTR [bp+6]	;_z
	mov	WORD PTR [si+8],ax
; Line 299
	mov	bx,WORD PTR [bp+8]	;Screen
	mov	ax,WORD PTR [bx+1100]
	cwd	
	mov	cx,WORD PTR [bp-4]	;_Y
	mov	bx,WORD PTR [bp-2]
	sub	cx,ax
	sbb	bx,dx
	push	bx
	push	cx
	mov	ax,WORD PTR [si+8]
	cwd	
	sub	ax,WORD PTR [bp-4]	;_Y
	sbb	dx,WORD PTR [bp-2]
	push	dx
	push	ax
	mov	bx,WORD PTR [bp+8]	;Screen
	mov	ax,WORD PTR [bx+1098]
	cwd	
	mov	cx,WORD PTR [bp-8]	;_X
	mov	bx,WORD PTR [bp-6]
	sub	cx,ax
	sbb	bx,dx
	push	bx
	push	cx
	call	__aNlmul
	push	dx
	push	ax
	call	__aNldiv
	mov	bx,WORD PTR [bp+8]	;Screen
	add	ax,WORD PTR [bx+1104]
	add	ax,WORD PTR [bp-8]	;_X
	mov	WORD PTR [si+4],ax
; Line 301
	mov	bx,WORD PTR [bp+8]	;Screen
	mov	ax,WORD PTR [bx+1100]
	cwd	
	mov	cx,WORD PTR [bp-4]	;_Y
	mov	bx,WORD PTR [bp-2]
	sub	cx,ax
	sbb	bx,dx
	push	bx
	push	cx
	mov	bx,WORD PTR [bp+8]	;Screen
	mov	ax,WORD PTR [bx+1102]
	cwd	
	push	dx
	push	ax
	mov	ax,WORD PTR [si+8]
	cwd	
	sub	ax,WORD PTR [bp-4]	;_Y
	sbb	dx,WORD PTR [bp-2]
	push	dx
	push	ax
	call	__aNlmul
	push	dx
	push	ax
	call	__aNldiv
	mov	WORD PTR [si+6],ax
; Line 303
	mov	ax,si
	jmp	$EX8206
; Line 304
$EX8206:
	pop	si
	pop	di
	leave	
	ret	6

?Set3DPosition@_3D_object@@UACPAV1@PAV_3D_screen@@H@Z	ENDP
	PUBLIC	?Set3DDimensions@_3D_object@@UACPAV1@HHH@Z	; _3D_object::Set3DDimensions
?Set3DDimensions@_3D_object@@UACPAV1@HHH@Z	PROC NEAR	; _3D_object::Set3DDimensions
; Line 307
	push	bp
	mov	bp,sp
	mov	ax,0
	call	__aNchkstk
	push	di
	push	si
	mov	si,WORD PTR [bp+4]	;this
;	register si = this
;	width = 10
;	height = 8
;	depth = 6
; Line 308
	mov	ax,WORD PTR [bp+10]	;width
	mov	WORD PTR [si+10],ax
; Line 309
	mov	ax,WORD PTR [bp+8]	;height
	mov	WORD PTR [si+12],ax
; Line 310
	mov	ax,WORD PTR [bp+6]	;depth
	mov	WORD PTR [si+14],ax
; Line 312
	mov	ax,si
	jmp	$EX8219
; Line 313
$EX8219:
	pop	si
	pop	di
	leave	
	ret	8

?Set3DDimensions@_3D_object@@UACPAV1@HHH@Z	ENDP
	PUBLIC	?Set3DOrigin@_3D_object@@UACPAV1@HH@Z	; _3D_object::Set3DOrigin
?Set3DOrigin@_3D_object@@UACPAV1@HH@Z	PROC NEAR	; _3D_object::Set3DOrigin
; Line 317
	push	bp
	mov	bp,sp
	mov	ax,0
	call	__aNchkstk
	push	di
	push	si
	mov	si,WORD PTR [bp+4]	;this
;	register si = this
;	_X3DO = 8
;	_Y3DO = 6
; Line 318
	mov	ax,WORD PTR [bp+8]	;_X3DO
	mov	WORD PTR [si+16],ax
; Line 319
	mov	ax,WORD PTR [bp+6]	;_Y3DO
	mov	WORD PTR [si+18],ax
; Line 321
	mov	ax,si
	jmp	$EX8223
; Line 322
$EX8223:
	pop	si
	pop	di
	leave	
	ret	6

?Set3DOrigin@_3D_object@@UACPAV1@HH@Z	ENDP
	PUBLIC	?Set3DPosition@_3D_screen@@UACXPAV_3D_object@@H@Z	; _3D_screen::Set3DPosition
?Set3DPosition@_3D_screen@@UACXPAV_3D_object@@H@Z	PROC NEAR	; _3D_screen::Set3DPosition
; Line 327
	push	bp
	mov	bp,sp
	mov	ax,0
	call	__aNchkstk
	push	di
	push	si
	mov	si,WORD PTR [bp+4]	;this
;	register si = this
;	o = 8
;	_z = 6
; Line 328
	push	si
	push	WORD PTR [bp+6]	;_z
	push	WORD PTR [bp+8]	;o
	mov	bx,WORD PTR [bp+8]	;o
	mov	bx,WORD PTR [bx]
	call	WORD PTR [bx+2]
; Line 329
	jmp	$EX8227
$EX8227:
	pop	si
	pop	di
	leave	
	ret	6

?Set3DPosition@_3D_screen@@UACXPAV_3D_object@@H@Z	ENDP
	PUBLIC	?Init@screen@@UACPAV1@PBUHWND__@@@Z	; screen::Init
?Init@screen@@UACPAV1@PBUHWND__@@@Z	PROC NEAR	; screen::Init
; Line 335
	push	bp
	mov	bp,sp
	mov	ax,1032	;0408H
	call	__aNchkstk
	push	di
	push	si
	mov	si,WORD PTR [bp+4]	;this
;	hbm = -2
;	Screen = -4
;	LogicalPalette = -1032
;	register si = this
;	hwnd = 6
; Line 343
	mov	WORD PTR [bp-1032],768	;0300H	;LogicalPalette
; Line 345
	mov	WORD PTR [bp-1030],256	;0100H
	mov	ax,0
	mov	cx,512	;0200H
	lea	di,WORD PTR [bp-1028]
	push	ss
	pop	es
	rep	stosw
; Line 347
	push	si
	call	?InitBufferHeader@screen@@QACJXZ	; screen::InitBufferHeader
	mov	WORD PTR ?Orientation@@3JA,ax	;Orientation
	mov	WORD PTR ?Orientation@@3JA+2,dx	;Orientation
; Line 350
	push	0
	call	FAR PTR GETDC
	mov	WORD PTR [bp-4],ax	;Screen
; Line 352
	push	WORD PTR [bp-4]	;Screen
	push	0
	push	10	;000aH
	lea	ax,WORD PTR [bp-1028]
	push	ss
	push	ax
	call	FAR PTR GETSYSTEMPALETTEENTRIES
; Line 354
	push	WORD PTR [bp-4]	;Screen
	push	246	;00f6H
	push	10	;000aH
	lea	ax,WORD PTR [bp-44]
	push	ss
	push	ax
	call	FAR PTR GETSYSTEMPALETTEENTRIES
; Line 356
	push	0
	push	WORD PTR [bp-4]	;Screen
	call	FAR PTR RELEASEDC
; Line 359
	lea	ax,WORD PTR [bp-1032]	;LogicalPalette
	push	ax
	push	si
	call	?ReserveWindowsPalette@screen@@QACXAAUpal@@@Z	; screen::ReserveWindowsPalette
; Line 364
	lea	ax,WORD PTR [bp-1032]	;LogicalPalette
	push	ax
	push	si
	call	?FillPalette@screen@@QACXAAUpal@@@Z	; screen::FillPalette
; Line 367
	lea	ax,WORD PTR [bp-1032]	;LogicalPalette
	push	ss
	push	ax
	call	FAR PTR CREATEPALETTE
	mov	WORD PTR [si+28],ax
; Line 372
	call	FAR PTR WINGCREATEDC
	mov	WORD PTR [si+2],ax
; Line 374
	push	WORD PTR [si+2]
	lea	ax,WORD PTR [si+32]
	push	ds
	push	ax
	lea	ax,WORD PTR [si+4]
	push	ds
	push	ax
	call	FAR PTR WINGCREATEBITMAP
	mov	WORD PTR [bp-2],ax	;hbm
; Line 377
	push	WORD PTR [si+2]
	push	WORD PTR [bp-2]	;hbm
	call	FAR PTR SELECTOBJECT
	mov	WORD PTR [si+30],ax
; Line 380
	push	WORD PTR [si+2]
	push	0
	push	0
	push	WORD PTR [si+20]
	push	WORD PTR [si+22]
	push	0
	push	66	;0042H
	call	FAR PTR PATBLT
; Line 383
	push	si
	call	?Paint@screen@@QACXXZ	; screen::Paint
; Line 388
	mov	ax,si
	jmp	$EX8230
; Line 390
$EX8230:
	pop	si
	pop	di
	leave	
	ret	4

?Init@screen@@UACPAV1@PBUHWND__@@@Z	ENDP
	PUBLIC	?InitBufferHeader@screen@@QACJXZ	; screen::InitBufferHeader
?InitBufferHeader@screen@@QACJXZ	PROC NEAR	; screen::InitBufferHeader
; Line 393
	push	bp
	mov	bp,sp
	mov	ax,4
	call	__aNchkstk
	push	di
	push	si
	mov	si,WORD PTR [bp+4]	;this
;	Orientation = -4
;	register si = this
; Line 394
	mov	WORD PTR [bp-4],1	;Orientation
	mov	WORD PTR [bp-2],0
; Line 398
	lea	ax,WORD PTR [si+32]
	push	ds
	push	ax
	call	FAR PTR WINGRECOMMENDDIBFORMAT
	cwd	
	mov	WORD PTR [bp-4],ax	;Orientation
	mov	WORD PTR [bp-2],dx
; Line 400
	mov	ax,WORD PTR [bp-2]
	or	ax,WORD PTR [bp-4]	;Orientation
	jne	$JCC2496
	jmp	$I8242
$JCC2496:
; Line 401
; Line 404
	mov	WORD PTR [si+46],8
; Line 405
	sub	ax,ax
	mov	WORD PTR [si+50],ax
	mov	WORD PTR [si+48],ax
; Line 406
	cmp	WORD PTR [si+42],0
	jge	$JCC2518
	jmp	$L8500
$JCC2518:
	mov	ax,1
	mov	dx,0
	jmp	$L8501
$L8500:
	mov	ax,-1	;ffffH
	mov	dx,-1	;ffffH
$L8501:
	mov	WORD PTR [bp-4],ax	;Orientation
	mov	WORD PTR [bp-2],dx
; Line 407
; Line 408
	jmp	$I8243
$I8242:
; Line 409
; Line 412
	mov	WORD PTR [si+32],40	;0028H
	mov	WORD PTR [si+34],0
; Line 413
	mov	WORD PTR [si+44],1
; Line 414
	mov	WORD PTR [si+46],8
; Line 415
	sub	ax,ax
	mov	WORD PTR [si+50],ax
	mov	WORD PTR [si+48],ax
; Line 416
	sub	ax,ax
	mov	WORD PTR [si+54],ax
	mov	WORD PTR [si+52],ax
; Line 417
	sub	ax,ax
	mov	WORD PTR [si+66],ax
	mov	WORD PTR [si+64],ax
; Line 418
	sub	ax,ax
	mov	WORD PTR [si+70],ax
	mov	WORD PTR [si+68],ax
; Line 419
$I8243:
; Line 421
	mov	ax,WORD PTR [si+12]
	cwd	
	mov	WORD PTR [si+36],ax
	mov	WORD PTR [si+38],dx
; Line 422
	push	WORD PTR [bp-2]
	push	WORD PTR [bp-4]	;Orientation
	mov	ax,WORD PTR [si+14]
	cwd	
	push	dx
	push	ax
	call	__aNlmul
	mov	WORD PTR [si+40],ax
	mov	WORD PTR [si+42],dx
; Line 424
	mov	ax,WORD PTR [bp-4]	;Orientation
	mov	dx,WORD PTR [bp-2]
	jmp	$EX8239
; Line 425
$EX8239:
	pop	si
	pop	di
	leave	
	ret	2

?InitBufferHeader@screen@@QACJXZ	ENDP
	PUBLIC	?ReserveWindowsPalette@screen@@QACXAAUpal@@@Z	; screen::ReserveWindowsPalette
?ReserveWindowsPalette@screen@@QACXAAUpal@@@Z	PROC NEAR	; screen::ReserveWindowsPalette
; Line 429
	push	bp
	mov	bp,sp
	mov	ax,0
	call	__aNchkstk
	push	di
	push	si
	mov	si,WORD PTR [bp+4]	;this
;	register di = Counter
;	register si = this
;	LogicalPalette = 6
; Line 437
	mov	di,0
	jmp	$F8249
$FC8250:
	inc	di
$F8249:
	cmp	di,10	;000aH
	jl	$JCC2669
	jmp	$FB8251
$JCC2669:
; Line 438
; Line 444
	mov	bx,di
	shl	bx,2
	add	bx,WORD PTR [bp+6]	;LogicalPalette
	mov	al,BYTE PTR [bx+4]
	mov	bx,di
	shl	bx,2
	mov	BYTE PTR [bx+74][si],al
; Line 446
	mov	bx,di
	shl	bx,2
	add	bx,WORD PTR [bp+6]	;LogicalPalette
	mov	al,BYTE PTR [bx+5]
	mov	bx,di
	shl	bx,2
	mov	BYTE PTR [bx+73][si],al
; Line 448
	mov	bx,di
	shl	bx,2
	add	bx,WORD PTR [bp+6]	;LogicalPalette
	mov	al,BYTE PTR [bx+6]
	mov	bx,di
	shl	bx,2
	mov	BYTE PTR [bx+72][si],al
; Line 449
	mov	bx,di
	shl	bx,2
	mov	BYTE PTR [bx+75][si],0
; Line 451
	mov	bx,di
	shl	bx,2
	add	bx,WORD PTR [bp+6]	;LogicalPalette
	mov	BYTE PTR [bx+7],0
; Line 454
	mov	bx,di
	shl	bx,2
	add	bx,WORD PTR [bp+6]	;LogicalPalette
	mov	al,BYTE PTR [bx+988]
	mov	bx,di
	shl	bx,2
	mov	BYTE PTR [bx+1058][si],al
; Line 456
	mov	bx,di
	shl	bx,2
	add	bx,WORD PTR [bp+6]	;LogicalPalette
	mov	al,BYTE PTR [bx+989]
	mov	bx,di
	shl	bx,2
	mov	BYTE PTR [bx+1057][si],al
; Line 458
	mov	bx,di
	shl	bx,2
	add	bx,WORD PTR [bp+6]	;LogicalPalette
	mov	al,BYTE PTR [bx+990]
	mov	bx,di
	shl	bx,2
	mov	BYTE PTR [bx+1056][si],al
; Line 459
	mov	bx,di
	shl	bx,2
	mov	BYTE PTR [bx+1059][si],0
; Line 461
	mov	bx,di
	shl	bx,2
	add	bx,WORD PTR [bp+6]	;LogicalPalette
	mov	BYTE PTR [bx+991],0
; Line 462
	jmp	$FC8250
$FB8251:
; Line 464
	jmp	$EX8247
$EX8247:
	pop	si
	pop	di
	leave	
	ret	4

?ReserveWindowsPalette@screen@@QACXAAUpal@@@Z	ENDP
	PUBLIC	?FillPalette@screen@@QACXAAUpal@@@Z	; screen::FillPalette
?FillPalette@screen@@QACXAAUpal@@@Z	PROC NEAR	; screen::FillPalette
; Line 468
	push	bp
	mov	bp,sp
	mov	ax,4
	call	__aNchkstk
	push	di
	push	si
	mov	si,WORD PTR [bp+4]	;this
;	pColorTable = -4
;	register di = Counter
;	register si = this
;	LogicalPalette = 6
; Line 474
	les	bx,DWORD PTR [si+8]
	mov	ax,WORD PTR es:[bx]
	add	ax,WORD PTR [si+8]
	mov	dx,WORD PTR [si+10]
	mov	WORD PTR [bp-4],ax	;pColorTable
	mov	WORD PTR [bp-2],dx
; Line 482
	mov	di,10	;000aH
	jmp	$F8259
$FC8260:
	inc	di
$F8259:
	cmp	di,246	;00f6H
	jl	$JCC2893
	jmp	$FB8261
$JCC2893:
; Line 483
; Line 488
	mov	bx,di
	shl	bx,2
	mov	es,WORD PTR [bp-2]
	add	bx,WORD PTR [bp-4]	;pColorTable
	mov	al,BYTE PTR es:[bx+2]
	mov	bx,di
	shl	bx,2
	add	bx,WORD PTR [bp+6]	;LogicalPalette
	mov	BYTE PTR [bx+4],al
	mov	bx,di
	shl	bx,2
	mov	BYTE PTR [bx+74][si],al
; Line 491
	mov	bx,di
	shl	bx,2
	mov	es,WORD PTR [bp-2]
	add	bx,WORD PTR [bp-4]	;pColorTable
	mov	al,BYTE PTR es:[bx+1]
	mov	bx,di
	shl	bx,2
	add	bx,WORD PTR [bp+6]	;LogicalPalette
	mov	BYTE PTR [bx+5],al
	mov	bx,di
	shl	bx,2
	mov	BYTE PTR [bx+73][si],al
; Line 495
	mov	bx,di
	shl	bx,2
	mov	es,WORD PTR [bp-2]
	add	bx,WORD PTR [bp-4]	;pColorTable
	mov	al,BYTE PTR es:[bx]
	mov	bx,di
	shl	bx,2
	add	bx,WORD PTR [bp+6]	;LogicalPalette
	mov	BYTE PTR [bx+6],al
	mov	bx,di
	shl	bx,2
	mov	BYTE PTR [bx+72][si],al
; Line 496
	mov	bx,di
	shl	bx,2
	mov	BYTE PTR [bx+75][si],0
; Line 497
	mov	bx,di
	shl	bx,2
	add	bx,WORD PTR [bp+6]	;LogicalPalette
	mov	BYTE PTR [bx+7],1
; Line 498
	jmp	$FC8260
$FB8261:
; Line 499
	jmp	$EX8254
$EX8254:
	pop	si
	pop	di
	leave	
	ret	4

?FillPalette@screen@@QACXAAUpal@@@Z	ENDP
	PUBLIC	?TestScroll@screen@@QAC?AW4boolean@@PBUHDC__@@PAVmoveable@@HH@Z	; screen::TestScroll
?TestScroll@screen@@QAC?AW4boolean@@PBUHDC__@@PAVmoveable@@HH@Z	PROC NEAR	; screen::TestScroll
; Line 503
	push	bp
	mov	bp,sp
	mov	ax,2
	call	__aNchkstk
	push	di
	push	si
	mov	si,WORD PTR [bp+4]	;this
;	register di = Scrollx
;	Scrolly = -2
;	register si = this
;	hdc = 12
;	Object = 10
;	AuxX = 8
;	AuxY = 6
; Line 505
	mov	di,0
	mov	WORD PTR [bp-2],di	;Scrolly
; Line 507
	mov	ax,WORD PTR [bp+8]	;AuxX
	sub	ax,WORD PTR [si+16]
	cmp	ax,500	;01f4H
	jg	$JCC3061
	jmp	$I8270
$JCC3061:
; Line 508
	mov	di,1
; Line 509
	jmp	$I8271
$I8270:
	mov	ax,WORD PTR [bp+8]	;AuxX
	sub	ax,WORD PTR [si+16]
	cmp	ax,40	;0028H
	jl	$JCC3081
	jmp	$I8272
$JCC3081:
; Line 510
	mov	di,-1	;ffffH
; Line 512
$I8272:
$I8271:
	mov	ax,WORD PTR [bp+6]	;AuxY
	sub	ax,WORD PTR [si+18]
	cmp	ax,300	;012cH
	jg	$JCC3098
	jmp	$I8273
$JCC3098:
; Line 513
	mov	WORD PTR [bp-2],1	;Scrolly
; Line 514
	jmp	$I8274
$I8273:
	mov	ax,WORD PTR [bp+6]	;AuxY
	sub	ax,WORD PTR [si+18]
	cmp	ax,40	;0028H
	jl	$JCC3120
	jmp	$I8275
$JCC3120:
; Line 515
	mov	WORD PTR [bp-2],-1	;ffffH	;Scrolly
; Line 517
$I8275:
$I8274:
	cmp	di,0
	je	$JCC3133
	jmp	$I8276
$JCC3133:
	cmp	WORD PTR [bp-2],0	;Scrolly
	je	$JCC3142
	jmp	$I8276
$JCC3142:
; Line 518
	mov	ax,0
	jmp	$EX8267
; Line 523
$I8276:
	cmp	di,0
	jg	$JCC3156
	jmp	$I8277
$JCC3156:
; Line 524
; Line 525
	mov	ax,WORD PTR [si+16]
	add	ax,WORD PTR [si+20]
	add	ax,20	;0014H
	cmp	ax,WORD PTR [si+12]
	jg	$JCC3173
	jmp	$I8278
$JCC3173:
; Line 526
; Line 527
	mov	di,0
; Line 528
; Line 529
$I8278:
; Line 530
	jmp	$I8279
$I8277:
	cmp	di,0
	jl	$JCC3187
	jmp	$I8280
$JCC3187:
; Line 531
; Line 532
	mov	ax,WORD PTR [si+16]
	sub	ax,20	;0014H
	cmp	ax,0
	jl	$JCC3201
	jmp	$I8281
$JCC3201:
; Line 533
; Line 534
	mov	di,0
; Line 535
; Line 536
$I8281:
; Line 538
$I8280:
$I8279:
	cmp	WORD PTR [bp-2],0	;Scrolly
	jg	$JCC3213
	jmp	$I8282
$JCC3213:
; Line 539
; Line 540
	mov	ax,WORD PTR [si+18]
	add	ax,WORD PTR [si+22]
	add	ax,20	;0014H
	cmp	ax,WORD PTR [si+14]
	jg	$JCC3230
	jmp	$I8283
$JCC3230:
; Line 541
; Line 542
	mov	WORD PTR [bp-2],0	;Scrolly
; Line 543
; Line 544
$I8283:
; Line 545
	jmp	$I8284
$I8282:
	cmp	WORD PTR [bp-2],0	;Scrolly
	jl	$JCC3247
	jmp	$I8285
$JCC3247:
; Line 546
; Line 547
	mov	ax,WORD PTR [si+18]
	sub	ax,20	;0014H
	cmp	ax,0
	jl	$JCC3261
	jmp	$I8286
$JCC3261:
; Line 548
; Line 549
	mov	WORD PTR [bp-2],0	;Scrolly
; Line 550
; Line 551
$I8286:
; Line 555
$I8285:
$I8284:
	cmp	di,0
	jne	$JCC3274
	jmp	$I8287
$JCC3274:
; Line 556
; Line 557
	mov	ax,20	;0014H
	imul	di
	mov	di,ax
; Line 559
	add	WORD PTR [si+16],di
; Line 561
	cmp	WORD PTR [bp-2],0	;Scrolly
	jne	$JCC3293
	jmp	$I8288
$JCC3293:
; Line 562
; Line 563
	mov	ax,20	;0014H
	imul	WORD PTR [bp-2]	;Scrolly
	mov	WORD PTR [bp-2],ax	;Scrolly
; Line 565
	mov	ax,WORD PTR [bp-2]	;Scrolly
	add	WORD PTR [si+18],ax
; Line 567
	mov	bx,WORD PTR [bp+10]	;Object
	mov	bx,WORD PTR [bx+2]
	mov	bx,WORD PTR [bx+2]
	add	bx,WORD PTR [bp+10]	;Object
	mov	ax,WORD PTR [bx+10]
	add	ax,di
	push	ax
	mov	bx,WORD PTR [bp+10]	;Object
	mov	bx,WORD PTR [bx+2]
	mov	bx,WORD PTR [bx+2]
	add	bx,WORD PTR [bp+10]	;Object
	mov	ax,WORD PTR [bx+12]
	add	ax,WORD PTR [bp-2]	;Scrolly
	push	ax
	push	si
	push	WORD PTR [bp+10]	;Object
	mov	bx,WORD PTR [bp+10]	;Object
	mov	bx,WORD PTR [bx]
	call	WORD PTR [bx+2]
; Line 569
; Line 570
	jmp	$I8289
$I8288:
; Line 571
; Line 572
	mov	bx,WORD PTR [bp+10]	;Object
	mov	bx,WORD PTR [bx+2]
	mov	bx,WORD PTR [bx+2]
	add	bx,WORD PTR [bp+10]	;Object
	mov	ax,WORD PTR [bx+10]
	add	ax,di
	push	ax
	mov	bx,WORD PTR [bp+10]	;Object
	mov	bx,WORD PTR [bx+2]
	mov	bx,WORD PTR [bx+2]
	add	bx,WORD PTR [bp+10]	;Object
	push	WORD PTR [bx+12]
	push	si
	push	WORD PTR [bp+10]	;Object
	mov	bx,WORD PTR [bp+10]	;Object
	mov	bx,WORD PTR [bx]
	call	WORD PTR [bx+2]
; Line 573
$I8289:
; Line 574
; Line 575
	jmp	$I8290
$I8287:
; Line 576
; Line 577
	cmp	WORD PTR [bp-2],0	;Scrolly
	jne	$JCC3417
	jmp	$I8291
$JCC3417:
; Line 578
; Line 579
	mov	ax,20	;0014H
	imul	WORD PTR [bp-2]	;Scrolly
	mov	WORD PTR [bp-2],ax	;Scrolly
; Line 581
	mov	ax,WORD PTR [bp-2]	;Scrolly
	add	WORD PTR [si+18],ax
; Line 583
	mov	bx,WORD PTR [bp+10]	;Object
	mov	bx,WORD PTR [bx+2]
	mov	bx,WORD PTR [bx+2]
	add	bx,WORD PTR [bp+10]	;Object
	push	WORD PTR [bx+10]
	mov	bx,WORD PTR [bp+10]	;Object
	mov	bx,WORD PTR [bx+2]
	mov	bx,WORD PTR [bx+2]
	add	bx,WORD PTR [bp+10]	;Object
	mov	ax,WORD PTR [bx+12]
	add	ax,WORD PTR [bp-2]	;Scrolly
	push	ax
	push	si
	push	WORD PTR [bp+10]	;Object
	mov	bx,WORD PTR [bp+10]	;Object
	mov	bx,WORD PTR [bx]
	call	WORD PTR [bx+2]
; Line 584
; Line 585
	jmp	$I8292
$I8291:
; Line 586
; Line 587
	mov	ax,0
	jmp	$EX8267
; Line 588
$I8292:
; Line 589
$I8290:
; Line 591
	push	WORD PTR [bp+12]	;hdc
	push	si
	call	?Show@screen@@QACXPBUHDC__@@@Z	; screen::Show
; Line 593
	mov	ax,1
	jmp	$EX8267
; Line 596
$EX8267:
	pop	si
	pop	di
	leave	
	ret	10	;000aH

?TestScroll@screen@@QAC?AW4boolean@@PBUHDC__@@PAVmoveable@@HH@Z	ENDP
	PUBLIC	?Move@moveable@@QACXPBUHDC__@@HHPAVscreen@@@Z	; moveable::Move
?Move@moveable@@QACXPBUHDC__@@HHPAVscreen@@@Z	PROC NEAR	; moveable::Move
; Line 600
	push	bp
	mov	bp,sp
	mov	ax,0
	call	__aNchkstk
	push	di
	push	si
	mov	si,WORD PTR [bp+4]	;this
;	register si = this
;	hdc = 12
;	_NewX = 10
;	_NewY = 8
;	Screen = 6
; Line 601
	jmp	$EX8298
$EX8298:
	pop	si
	pop	di
	leave	
	ret	10	;000aH

?Move@moveable@@QACXPBUHDC__@@HHPAVscreen@@@Z	ENDP
	PUBLIC	?PlanNextPosition@moveable@@QACXXZ	; moveable::PlanNextPosition
?PlanNextPosition@moveable@@QACXXZ	PROC NEAR	; moveable::PlanNextPosition
; Line 604
	push	bp
	mov	bp,sp
	mov	ax,0
	call	__aNchkstk
	push	di
	push	si
	mov	si,WORD PTR [bp+4]	;this
;	register si = this
; Line 605
	cmp	WORD PTR [si+44],0
	jne	$JCC3552
	jmp	$I8302
$JCC3552:
; Line 606
; Line 607
	cmp	WORD PTR [si+38],0
	jle	$JCC3561
	jmp	$I8303
$JCC3561:
; Line 608
; Line 609
	mov	ax,WORD PTR [si+44]
	add	WORD PTR [si+38],ax
; Line 610
	mov	ax,WORD PTR [si+30]
	add	WORD PTR [si+26],ax
; Line 611
; Line 612
	jmp	$I8304
$I8303:
; Line 613
; Line 614
	mov	ax,WORD PTR [si+42]
	add	WORD PTR [si+38],ax
; Line 615
	mov	ax,WORD PTR [si+30]
	add	WORD PTR [si+26],ax
; Line 616
	mov	ax,WORD PTR [si+32]
	add	WORD PTR [si+28],ax
; Line 618
$I8304:
; Line 619
; Line 620
	jmp	$I8305
$I8302:
; Line 621
; Line 622
	cmp	WORD PTR [si+38],0
	jg	$JCC3606
	jmp	$I8306
$JCC3606:
; Line 623
; Line 624
	mov	ax,WORD PTR [si+46]
	add	WORD PTR [si+38],ax
; Line 625
	mov	ax,WORD PTR [si+32]
	add	WORD PTR [si+28],ax
; Line 626
; Line 627
	jmp	$I8307
$I8306:
; Line 628
; Line 629
	mov	ax,WORD PTR [si+42]
	add	WORD PTR [si+38],ax
; Line 630
	mov	ax,WORD PTR [si+30]
	add	WORD PTR [si+26],ax
; Line 631
	mov	ax,WORD PTR [si+32]
	add	WORD PTR [si+28],ax
; Line 633
$I8307:
; Line 634
$I8305:
; Line 635
	jmp	$EX8301
$EX8301:
	pop	si
	pop	di
	leave	
	ret	2

?PlanNextPosition@moveable@@QACXXZ	ENDP
	PUBLIC	?FinishedMovement@moveable@@QAC?AW4boolean@@XZ	; moveable::FinishedMovement
?FinishedMovement@moveable@@QAC?AW4boolean@@XZ	PROC NEAR	; moveable::FinishedMovement
; Line 639
	push	bp
	mov	bp,sp
	mov	ax,0
	call	__aNchkstk
	push	di
	push	si
	mov	si,WORD PTR [bp+4]	;this
;	register si = this
; Line 640
	cmp	WORD PTR [si+44],0
	jne	$JCC3671
	jmp	$I8311
$JCC3671:
; Line 641
; Line 642
	mov	ax,WORD PTR [si+26]
	sub	ax,WORD PTR [si+22]
	push	ax
	call	_abs
	add	sp,2
	push	WORD PTR [si+30]
	mov	di,ax
	call	_abs
	add	sp,2
	cmp	di,ax
	jle	$JCC3702
	jmp	$L8502
$JCC3702:
	mov	ax,1
	jmp	$L8503
$L8502:
	mov	ax,0
$L8503:
	jmp	$EX8310
; Line 643
; Line 644
	jmp	$I8313
$I8311:
; Line 645
; Line 646
	mov	ax,WORD PTR [si+28]
	sub	ax,WORD PTR [si+24]
	push	ax
	call	_abs
	add	sp,2
	push	WORD PTR [si+32]
	mov	di,ax
	call	_abs
	add	sp,2
	cmp	di,ax
	jle	$JCC3748
	jmp	$L8504
$JCC3748:
	mov	ax,1
	jmp	$L8505
$L8504:
	mov	ax,0
$L8505:
	jmp	$EX8310
; Line 647
$I8313:
; Line 648
$EX8310:
	pop	si
	pop	di
	leave	
	ret	2

?FinishedMovement@moveable@@QAC?AW4boolean@@XZ	ENDP
	PUBLIC	?Move1Step@_3D_moveable@@UACXPBUHWND__@@PAV_3D_screen@@@Z	; _3D_moveable::Move1Step
?Move1Step@_3D_moveable@@UACXPBUHWND__@@PAV_3D_screen@@@Z	PROC NEAR	; _3D_moveable::Move1Step
; Line 652
	push	bp
	mov	bp,sp
	mov	ax,4
	call	__aNchkstk
	push	di
	push	si
	mov	si,WORD PTR [bp+4]	;this
;	register si = this
;	hwnd = 8
;	Screen = 6
; Line 653
	cmp	WORD PTR [si+52],0
	jne	$JCC3789
	jmp	$I8319
$JCC3789:
; Line 654
;	hdc = -2
; Line 656
	push	WORD PTR [bp+8]	;hwnd
	call	FAR PTR GETDC
	mov	WORD PTR [bp-2],ax	;hdc
; Line 659
	push	si
	call	?PlanNextPosition@moveable@@QACXXZ	; moveable::PlanNextPosition
; Line 661
	push	WORD PTR [bp+6]	;Screen
	push	si
	mov	bx,WORD PTR [si]
	call	WORD PTR [bx+24]
	cmp	ax,0
	jne	$JCC3821
	jmp	$I8321
$JCC3821:
; Line 662
; Line 663
	push	WORD PTR [si+26]
	push	WORD PTR [si+28]
	push	WORD PTR [bp+6]	;Screen
	push	si
	call	?Paint@_3D_moveable@@UACXHHPAV_3D_screen@@@Z	; _3D_moveable::Paint
; Line 665
	mov	bx,WORD PTR [bp+6]	;Screen
	mov	bx,WORD PTR [bx+1096]
	cmp	WORD PTR [bx+15796],0
	jne	$JCC3851
	jmp	$I8322
$JCC3851:
; Line 666
;	OccupObj = -4
; Line 667
	mov	bx,WORD PTR [bp+6]	;Screen
	mov	bx,WORD PTR [bx+1096]
	mov	ax,WORD PTR [bx+15796]
	mov	WORD PTR [bp-4],ax	;OccupObj
; Line 669
	push	WORD PTR [bp-4]	;OccupObj
	mov	bx,WORD PTR [bp-4]	;OccupObj
	mov	bx,WORD PTR [bx]
	call	WORD PTR [bx+2]
	mov	bx,WORD PTR [si+2]
	mov	bx,WORD PTR [bx+4]
	cmp	WORD PTR [bx+8][si],ax
	jg	$JCC3890
	jmp	$I8324
$JCC3890:
; Line 670
; Line 671
	push	WORD PTR [bp+6]	;Screen
	push	WORD PTR [bp-4]	;OccupObj
	mov	bx,WORD PTR [bp-4]	;OccupObj
	mov	bx,WORD PTR [bx]
	call	WORD PTR [bx+12]
; Line 672
	push	WORD PTR [bp-2]	;hdc
	push	WORD PTR [bp+6]	;Screen
	push	WORD PTR [bp-4]	;OccupObj
	mov	bx,WORD PTR [bp-4]	;OccupObj
	mov	bx,WORD PTR [bx]
	call	WORD PTR [bx+18]
; Line 673
; Line 674
$I8324:
; Line 676
$I8322:
	push	WORD PTR [bp-2]	;hdc
	push	WORD PTR [bp+6]	;Screen
	lea	ax,WORD PTR [si+56]
	push	ax
	call	?Show@_3D_moveable@@UACXPBUHDC__@@PAVscreen@@@Z	; _3D_moveable::Show
; Line 678
	push	WORD PTR [bp-2]	;hdc
	push	si
	push	WORD PTR [si+26]
	push	WORD PTR [si+28]
	push	WORD PTR [bp+6]	;Screen
	call	?TestScroll@screen@@QAC?AW4boolean@@PBUHDC__@@PAVmoveable@@HH@Z	; screen::TestScroll
; Line 680
	push	si
	call	?FinishedMovement@moveable@@QAC?AW4boolean@@XZ	; moveable::FinishedMovement
	cmp	ax,0
	jne	$JCC3962
	jmp	$I8325
$JCC3962:
; Line 681
; Line 682
	push	WORD PTR [bp+8]	;hwnd
	push	WORD PTR [bp-2]	;hdc
	push	WORD PTR [bp+6]	;Screen
	push	si
	mov	bx,WORD PTR [si]
	call	WORD PTR [bx+16]
; Line 683
; Line 684
$I8325:
; Line 685
	jmp	$I8326
$I8321:
; Line 686
; Line 687
	push	WORD PTR [bp+8]	;hwnd
	push	WORD PTR [bp-2]	;hdc
	push	WORD PTR [bp+6]	;Screen
	push	si
	mov	bx,WORD PTR [si]
	call	WORD PTR [bx+16]
; Line 688
$I8326:
; Line 690
	push	WORD PTR [bp+8]	;hwnd
	push	WORD PTR [bp-2]	;hdc
	call	FAR PTR RELEASEDC
; Line 691
; Line 692
$I8319:
	jmp	$EX8318
$EX8318:
	pop	si
	pop	di
	leave	
	ret	6

?Move1Step@_3D_moveable@@UACXPBUHWND__@@PAV_3D_screen@@@Z	ENDP
	PUBLIC	?Move1Step@moveable@@UACXPBUHWND__@@PAVoccup_screen@@@Z	; moveable::Move1Step
?Move1Step@moveable@@UACXPBUHWND__@@PAVoccup_screen@@@Z	PROC NEAR	; moveable::Move1Step
; Line 695
	push	bp
	mov	bp,sp
	mov	ax,2
	call	__aNchkstk
	push	di
	push	si
	mov	si,WORD PTR [bp+4]	;this
;	register si = this
;	hwnd = 8
;	Screen = 6
; Line 696
	cmp	WORD PTR [si+52],0
	jne	$JCC4038
	jmp	$I8331
$JCC4038:
; Line 697
;	hdc = -2
; Line 699
	push	WORD PTR [bp+8]	;hwnd
	call	FAR PTR GETDC
	mov	WORD PTR [bp-2],ax	;hdc
; Line 702
	push	si
	call	?PlanNextPosition@moveable@@QACXXZ	; moveable::PlanNextPosition
; Line 704
	push	WORD PTR [bp+6]	;Screen
	push	si
	mov	bx,WORD PTR [si]
	call	WORD PTR [bx+4]
	cmp	ax,0
	jne	$JCC4070
	jmp	$I8333
$JCC4070:
; Line 705
; Line 706
	push	WORD PTR [si+26]
	push	WORD PTR [si+28]
	push	WORD PTR [bp+6]	;Screen
	push	si
	call	?Paint@moveable@@UACXHHPAVscreen@@@Z	; moveable::Paint
; Line 707
	push	WORD PTR [bp-2]	;hdc
	push	WORD PTR [bp+6]	;Screen
	lea	ax,WORD PTR [si+56]
	push	ax
	call	?Show@moveable@@UACXPBUHDC__@@PAVscreen@@@Z	; moveable::Show
; Line 709
	push	WORD PTR [bp-2]	;hdc
	push	si
	push	WORD PTR [si+26]
	push	WORD PTR [si+28]
	push	WORD PTR [bp+6]	;Screen
	call	?TestScroll@screen@@QAC?AW4boolean@@PBUHDC__@@PAVmoveable@@HH@Z	; screen::TestScroll
; Line 711
	push	si
	call	?FinishedMovement@moveable@@QAC?AW4boolean@@XZ	; moveable::FinishedMovement
	cmp	ax,0
	jne	$JCC4124
	jmp	$I8334
$JCC4124:
; Line 712
; Line 713
	push	WORD PTR [bp+8]	;hwnd
	push	WORD PTR [bp-2]	;hdc
	push	WORD PTR [bp+6]	;Screen
	push	si
	mov	bx,WORD PTR [si]
	call	WORD PTR [bx+16]
; Line 714
; Line 715
$I8334:
; Line 716
	jmp	$I8335
$I8333:
; Line 717
; Line 718
	push	WORD PTR [bp+8]	;hwnd
	push	WORD PTR [bp-2]	;hdc
	push	WORD PTR [bp+6]	;Screen
	push	si
	mov	bx,WORD PTR [si]
	call	WORD PTR [bx+16]
; Line 719
$I8335:
; Line 721
	push	WORD PTR [bp+8]	;hwnd
	push	WORD PTR [bp-2]	;hdc
	call	FAR PTR RELEASEDC
; Line 722
; Line 723
$I8331:
	jmp	$EX8330
$EX8330:
	pop	si
	pop	di
	leave	
	ret	6

?Move1Step@moveable@@UACXPBUHWND__@@PAVoccup_screen@@@Z	ENDP
	PUBLIC	?InitMove@moveable@@UACXPBUHWND__@@HHPAVoccup_screen@@@Z	; moveable::InitMove
?InitMove@moveable@@UACXPBUHWND__@@HHPAVoccup_screen@@@Z	PROC NEAR	; moveable::InitMove
; Line 809
	push	bp
	mov	bp,sp
	mov	ax,2
	call	__aNchkstk
	push	di
	push	si
	mov	si,WORD PTR [bp+4]	;this
;	hdc = -2
;	register si = this
;	hwnd = 12
;	_NewX = 10
;	_NewY = 8
;	Screen = 6
; Line 811
	push	WORD PTR [si+30]
	call	_abs
	add	sp,2
	mov	WORD PTR [si+30],ax
; Line 812
	push	WORD PTR [si+32]
	call	_abs
	add	sp,2
	mov	WORD PTR [si+32],ax
; Line 813
	mov	WORD PTR [si+52],1
; Line 815
	mov	bx,WORD PTR [si+2]
	mov	ax,WORD PTR [bx+2]
	add	ax,si
	add	ax,2
	push	ax
	call	?FrameWidth@object@@QACHXZ	; object::FrameWidth
	cwd	
	sub	ax,dx
	sar	ax,1
	mov	bx,WORD PTR [bp+6]	;Screen
	sub	ax,WORD PTR [bx+12]
	neg	ax
	mov	bx,WORD PTR [bp+6]	;Screen
	mov	cx,WORD PTR [bx+16]
	add	cx,WORD PTR [bp+10]	;_NewX
	cmp	ax,cx
	jl	$JCC4264
	jmp	$I8342
$JCC4264:
; Line 816
	mov	bx,WORD PTR [si+2]
	mov	ax,WORD PTR [bx+2]
	add	ax,si
	add	ax,2
	push	ax
	call	?FrameWidth@object@@QACHXZ	; object::FrameWidth
	mov	bx,WORD PTR [bp+6]	;Screen
	sub	ax,WORD PTR [bx+12]
	neg	ax
	mov	WORD PTR [si+22],ax
; Line 817
	jmp	$I8343
$I8342:
; Line 818
	mov	bx,WORD PTR [si+2]
	mov	ax,WORD PTR [bx+2]
	add	ax,si
	add	ax,2
	push	ax
	call	?FrameWidth@object@@QACHXZ	; object::FrameWidth
	cwd	
	sub	ax,dx
	sar	ax,1
	mov	bx,WORD PTR [bp+6]	;Screen
	sub	ax,WORD PTR [bx+16]
	neg	ax
	add	ax,WORD PTR [bp+10]	;_NewX
	mov	WORD PTR [si+22],ax
$I8343:
; Line 821
	mov	bx,WORD PTR [bp+6]	;Screen
	mov	ax,WORD PTR [bx+18]
	add	ax,WORD PTR [bp+8]	;_NewY
	mov	bx,WORD PTR [bp+6]	;Screen
	cmp	ax,WORD PTR [bx+14]
	jg	$JCC4347
	jmp	$I8344
$JCC4347:
; Line 822
	mov	bx,WORD PTR [si+2]
	mov	ax,WORD PTR [bx+2]
	add	ax,si
	add	ax,2
	push	ax
	call	?FrameHeight@object@@QACHXZ	; object::FrameHeight
	mov	bx,WORD PTR [bp+6]	;Screen
	sub	ax,WORD PTR [bx+14]
	neg	ax
	mov	WORD PTR [si+24],ax
; Line 823
	jmp	$I8345
$I8344:
; Line 824
	mov	bx,WORD PTR [si+2]
	mov	ax,WORD PTR [bx+2]
	add	ax,si
	add	ax,2
	push	ax
	call	?FrameHeight@object@@QACHXZ	; object::FrameHeight
	mov	bx,WORD PTR [bp+6]	;Screen
	sub	ax,WORD PTR [bx+18]
	neg	ax
	add	ax,WORD PTR [bp+8]	;_NewY
	mov	WORD PTR [si+24],ax
$I8345:
; Line 826
	mov	bx,WORD PTR [si+2]
	mov	bx,WORD PTR [bx+2]
	mov	ax,WORD PTR [bx+10][si]
	mov	WORD PTR [si+26],ax
; Line 827
	mov	bx,WORD PTR [si+2]
	mov	bx,WORD PTR [bx+2]
	mov	ax,WORD PTR [bx+12][si]
	mov	WORD PTR [si+28],ax
; Line 829
	mov	ax,WORD PTR [si+22]
	sub	ax,WORD PTR [si+26]
	mov	WORD PTR [si+34],ax
; Line 830
	mov	ax,WORD PTR [si+24]
	sub	ax,WORD PTR [si+28]
	mov	WORD PTR [si+36],ax
; Line 832
	cmp	WORD PTR [si+34],0
	jl	$JCC4456
	jmp	$I8346
$JCC4456:
; Line 833
; Line 834
	neg	WORD PTR [si+30]
; Line 835
	neg	WORD PTR [si+34]
; Line 836
; Line 838
$I8346:
	cmp	WORD PTR [si+36],0
	jl	$JCC4471
	jmp	$I8347
$JCC4471:
; Line 839
; Line 840
	neg	WORD PTR [si+32]
; Line 841
	neg	WORD PTR [si+36]
; Line 842
; Line 843
	jmp	$I8348
$I8347:
; Line 844
	cmp	WORD PTR [si+36],0
	je	$JCC4489
	jmp	$I8349
$JCC4489:
; Line 845
; Line 846
	mov	WORD PTR [si+36],1
; Line 847
; Line 849
$I8349:
$I8348:
	cmp	WORD PTR [si+34],0
	je	$JCC4503
	jmp	$I8350
$JCC4503:
	cmp	WORD PTR [si+36],1
	je	$JCC4512
	jmp	$I8350
$JCC4512:
; Line 850
; Line 851
	mov	WORD PTR [si+52],0
; Line 852
	jmp	$EX8341
; Line 853
; Line 856
$I8350:
	mov	ax,WORD PTR [si+36]
	cmp	WORD PTR [si+34],ax
	jg	$JCC4531
	jmp	$I8351
$JCC4531:
; Line 857
; Line 858
	mov	ax,WORD PTR [si+36]
	shl	ax,1
	mov	WORD PTR [si+44],ax
; Line 859
	mov	ax,WORD PTR [si+44]
	sub	ax,WORD PTR [si+34]
	mov	WORD PTR [si+38],ax
; Line 860
	mov	ax,WORD PTR [si+38]
	sub	ax,WORD PTR [si+34]
	mov	WORD PTR [si+42],ax
; Line 861
	mov	WORD PTR [si+46],0
; Line 862
; Line 863
	jmp	$I8352
$I8351:
; Line 864
; Line 865
	mov	ax,WORD PTR [si+34]
	shl	ax,1
	neg	ax
	mov	WORD PTR [si+46],ax
; Line 866
	mov	ax,WORD PTR [si+36]
	add	ax,WORD PTR [si+46]
	mov	WORD PTR [si+38],ax
; Line 867
	mov	ax,WORD PTR [si+36]
	add	ax,WORD PTR [si+38]
	mov	WORD PTR [si+42],ax
; Line 868
	mov	WORD PTR [si+44],0
; Line 869
$I8352:
; Line 871
	push	WORD PTR [bp+12]	;hwnd
	call	FAR PTR GETDC
	mov	WORD PTR [bp-2],ax	;hdc
; Line 873
	push	WORD PTR [bp-2]	;hdc
	mov	bx,WORD PTR [bp+6]	;Screen
	push	WORD PTR [bx+28]
	push	0
	call	FAR PTR SELECTPALETTE
; Line 874
	push	WORD PTR [bp-2]	;hdc
	call	FAR PTR REALIZEPALETTE
; Line 876
	push	WORD PTR [bp+12]	;hwnd
	push	WORD PTR [bp-2]	;hdc
	call	FAR PTR RELEASEDC
; Line 878
	push	WORD PTR [bp+12]	;hwnd
	push	WORD PTR [si+48]
	push	WORD PTR [si+50]
	push	0
	push	0
	call	DWORD PTR _SetSystemTimer
; Line 879
	jmp	$EX8341
$EX8341:
	pop	si
	pop	di
	leave	
	ret	10	;000aH

?InitMove@moveable@@UACXPBUHWND__@@HHPAVoccup_screen@@@Z	ENDP
	PUBLIC	?InitVMove@moveable@@UACXPBUHWND__@@PAVoccup_screen@@W4MVDIR@@@Z	; moveable::InitVMove
?InitVMove@moveable@@UACXPBUHWND__@@PAVoccup_screen@@W4MVDIR@@@Z	PROC NEAR	; moveable::InitVMove
; Line 882
	push	bp
	mov	bp,sp
	mov	ax,2
	call	__aNchkstk
	push	di
	push	si
	mov	si,WORD PTR [bp+4]	;this
;	hdc = -2
;	register si = this
;	hwnd = 10
;	Screen = 8
;	Direction = 6
; Line 884
	push	WORD PTR [si+30]
	call	_abs
	add	sp,2
	mov	WORD PTR [si+30],ax
; Line 885
	push	WORD PTR [si+32]
	call	_abs
	add	sp,2
	mov	WORD PTR [si+32],ax
; Line 886
	mov	WORD PTR [si+52],1
; Line 888
	mov	bx,WORD PTR [si+2]
	mov	bx,WORD PTR [bx+2]
	mov	ax,WORD PTR [bx+10][si]
	mov	WORD PTR [si+22],ax
; Line 890
	cmp	WORD PTR [bp+6],3	;Direction
	je	$JCC4734
	jmp	$I8359
$JCC4734:
; Line 891
; Line 892
	mov	bx,WORD PTR [si+2]
	mov	ax,WORD PTR [bx+2]
	add	ax,si
	add	ax,2
	push	ax
	call	?FrameHeight@object@@QACHXZ	; object::FrameHeight
	mov	bx,WORD PTR [bp+8]	;Screen
	sub	ax,WORD PTR [bx+14]
	neg	ax
	mov	WORD PTR [si+24],ax
; Line 893
; Line 894
	jmp	$I8360
$I8359:
; Line 895
	cmp	WORD PTR [bp+6],2	;Direction
	je	$JCC4772
	jmp	$I8361
$JCC4772:
; Line 896
; Line 897
	mov	bx,WORD PTR [si+2]
	mov	ax,WORD PTR [bx+2]
	add	ax,si
	add	ax,2
	push	ax
	call	?FrameHeight@object@@QACHXZ	; object::FrameHeight
	cwd	
	sub	ax,dx
	sar	ax,1
	neg	ax
	mov	WORD PTR [si+24],ax
; Line 898
; Line 899
	jmp	$I8362
$I8361:
; Line 900
; Line 901
	mov	WORD PTR [si+52],0
; Line 902
	jmp	$EX8358
; Line 903
$I8362:
$I8360:
; Line 906
	mov	bx,WORD PTR [si+2]
	mov	bx,WORD PTR [bx+2]
	mov	ax,WORD PTR [bx+10][si]
	mov	WORD PTR [si+26],ax
; Line 907
	mov	bx,WORD PTR [si+2]
	mov	bx,WORD PTR [bx+2]
	mov	ax,WORD PTR [bx+12][si]
	mov	WORD PTR [si+28],ax
; Line 909
	mov	WORD PTR [si+34],0
; Line 910
	mov	ax,WORD PTR [si+24]
	sub	ax,WORD PTR [si+28]
	mov	WORD PTR [si+36],ax
; Line 912
	cmp	WORD PTR [si+36],0
	jl	$JCC4855
	jmp	$I8363
$JCC4855:
; Line 913
; Line 914
	neg	WORD PTR [si+32]
; Line 915
	neg	WORD PTR [si+36]
; Line 916
; Line 917
	jmp	$I8364
$I8363:
; Line 918
	cmp	WORD PTR [si+36],0
	je	$JCC4873
	jmp	$I8365
$JCC4873:
; Line 919
; Line 920
	mov	WORD PTR [si+52],0
; Line 921
	jmp	$EX8358
; Line 922
; Line 924
$I8365:
$I8364:
	mov	ax,WORD PTR [si+34]
	shl	ax,1
	neg	ax
	mov	WORD PTR [si+46],ax
; Line 925
	mov	ax,WORD PTR [si+36]
	add	ax,WORD PTR [si+46]
	mov	WORD PTR [si+38],ax
; Line 926
	mov	ax,WORD PTR [si+36]
	add	ax,WORD PTR [si+38]
	mov	WORD PTR [si+42],ax
; Line 927
	mov	WORD PTR [si+44],0
; Line 930
	push	WORD PTR [bp+10]	;hwnd
	call	FAR PTR GETDC
	mov	WORD PTR [bp-2],ax	;hdc
; Line 932
	push	WORD PTR [bp-2]	;hdc
	mov	bx,WORD PTR [bp+8]	;Screen
	push	WORD PTR [bx+28]
	push	0
	call	FAR PTR SELECTPALETTE
; Line 933
	push	WORD PTR [bp-2]	;hdc
	call	FAR PTR REALIZEPALETTE
; Line 935
	push	WORD PTR [bp+10]	;hwnd
	push	WORD PTR [bp-2]	;hdc
	call	FAR PTR RELEASEDC
; Line 937
	push	WORD PTR [bp+10]	;hwnd
	push	WORD PTR [si+48]
	push	WORD PTR [si+50]
	push	0
	push	0
	call	DWORD PTR _SetSystemTimer
; Line 938
	jmp	$EX8358
$EX8358:
	pop	si
	pop	di
	leave	
	ret	8

?InitVMove@moveable@@UACXPBUHWND__@@PAVoccup_screen@@W4MVDIR@@@Z	ENDP
	PUBLIC	?InitHMove@moveable@@UACXPBUHWND__@@PAVoccup_screen@@W4MVDIR@@@Z	; moveable::InitHMove
?InitHMove@moveable@@UACXPBUHWND__@@PAVoccup_screen@@W4MVDIR@@@Z	PROC NEAR	; moveable::InitHMove
; Line 942
	push	bp
	mov	bp,sp
	mov	ax,2
	call	__aNchkstk
	push	di
	push	si
	mov	si,WORD PTR [bp+4]	;this
;	hdc = -2
;	register si = this
;	hwnd = 10
;	Screen = 8
;	Direction = 6
; Line 944
	push	WORD PTR [si+30]
	call	_abs
	add	sp,2
	mov	WORD PTR [si+30],ax
; Line 945
	push	WORD PTR [si+32]
	call	_abs
	add	sp,2
	mov	WORD PTR [si+32],ax
; Line 946
	mov	WORD PTR [si+52],1
; Line 948
	cmp	WORD PTR [bp+6],1	;Direction
	je	$JCC5038
	jmp	$I8372
$JCC5038:
; Line 949
; Line 950
	mov	bx,WORD PTR [si+2]
	mov	ax,WORD PTR [bx+2]
	add	ax,si
	add	ax,2
	push	ax
	call	?FrameWidth@object@@QACHXZ	; object::FrameWidth
	mov	bx,WORD PTR [bp+8]	;Screen
	sub	ax,WORD PTR [bx+12]
	neg	ax
	mov	WORD PTR [si+22],ax
; Line 951
; Line 952
	jmp	$I8373
$I8372:
; Line 953
	cmp	WORD PTR [bp+6],0	;Direction
	je	$JCC5076
	jmp	$I8374
$JCC5076:
; Line 954
; Line 955
	mov	bx,WORD PTR [si+2]
	mov	ax,WORD PTR [bx+2]
	add	ax,si
	add	ax,2
	push	ax
	call	?FrameWidth@object@@QACHXZ	; object::FrameWidth
	cwd	
	sub	ax,dx
	sar	ax,1
	neg	ax
	mov	WORD PTR [si+22],ax
; Line 956
; Line 957
	jmp	$I8375
$I8374:
; Line 958
; Line 959
	mov	WORD PTR [si+52],0
; Line 960
	jmp	$EX8371
; Line 961
$I8375:
$I8373:
; Line 963
	mov	bx,WORD PTR [si+2]
	mov	bx,WORD PTR [bx+2]
	mov	ax,WORD PTR [bx+12][si]
	mov	WORD PTR [si+24],ax
; Line 965
	mov	bx,WORD PTR [si+2]
	mov	bx,WORD PTR [bx+2]
	mov	ax,WORD PTR [bx+10][si]
	mov	WORD PTR [si+26],ax
; Line 966
	mov	bx,WORD PTR [si+2]
	mov	bx,WORD PTR [bx+2]
	mov	ax,WORD PTR [bx+12][si]
	mov	WORD PTR [si+28],ax
; Line 968
	mov	ax,WORD PTR [si+22]
	sub	ax,WORD PTR [si+26]
	mov	WORD PTR [si+34],ax
; Line 969
	mov	WORD PTR [si+36],1
; Line 971
	cmp	WORD PTR [si+34],0
	jl	$JCC5171
	jmp	$I8376
$JCC5171:
; Line 972
; Line 973
	neg	WORD PTR [si+30]
; Line 974
	neg	WORD PTR [si+34]
; Line 975
; Line 976
	jmp	$I8377
$I8376:
; Line 977
	cmp	WORD PTR [si+34],0
	je	$JCC5189
	jmp	$I8378
$JCC5189:
; Line 978
; Line 979
	mov	WORD PTR [si+52],0
; Line 980
	jmp	$EX8371
; Line 981
; Line 983
$I8378:
$I8377:
	mov	ax,WORD PTR [si+36]
	shl	ax,1
	mov	WORD PTR [si+44],ax
; Line 984
	mov	ax,WORD PTR [si+44]
	sub	ax,WORD PTR [si+34]
	mov	WORD PTR [si+38],ax
; Line 985
	mov	ax,WORD PTR [si+38]
	sub	ax,WORD PTR [si+34]
	mov	WORD PTR [si+42],ax
; Line 986
	mov	WORD PTR [si+46],0
; Line 988
	push	WORD PTR [bp+10]	;hwnd
	call	FAR PTR GETDC
	mov	WORD PTR [bp-2],ax	;hdc
; Line 990
	push	WORD PTR [bp-2]	;hdc
	mov	bx,WORD PTR [bp+8]	;Screen
	push	WORD PTR [bx+28]
	push	0
	call	FAR PTR SELECTPALETTE
; Line 991
	push	WORD PTR [bp-2]	;hdc
	call	FAR PTR REALIZEPALETTE
; Line 993
	push	WORD PTR [bp+10]	;hwnd
	push	WORD PTR [bp-2]	;hdc
	call	FAR PTR RELEASEDC
; Line 995
	push	WORD PTR [bp+10]	;hwnd
	push	WORD PTR [si+48]
	push	WORD PTR [si+50]
	push	0
	push	0
	call	DWORD PTR _SetSystemTimer
; Line 996
	jmp	$EX8371
$EX8371:
	pop	si
	pop	di
	leave	
	ret	8

?InitHMove@moveable@@UACXPBUHWND__@@PAVoccup_screen@@W4MVDIR@@@Z	ENDP
	PUBLIC	?EndMove@moveable@@UACXPBUHWND__@@PAVoccup_screen@@@Z	; moveable::EndMove
?EndMove@moveable@@UACXPBUHWND__@@PAVoccup_screen@@@Z	PROC NEAR	; moveable::EndMove
; Line 999
	push	bp
	mov	bp,sp
	mov	ax,2
	call	__aNchkstk
	push	di
	push	si
	mov	si,WORD PTR [bp+4]	;this
;	hdc = -2
;	register si = this
;	hwnd = 8
;	Screen = 6
; Line 1000
	push	WORD PTR [bp+8]	;hwnd
	call	FAR PTR GETDC
	mov	WORD PTR [bp-2],ax	;hdc
; Line 1015
	push	WORD PTR [bp+8]	;hwnd
	push	WORD PTR [bp-2]	;hdc
	push	WORD PTR [bp+6]	;Screen
	push	si
	call	?EndMove@moveable@@UACXPBUHWND__@@PBUHDC__@@PAVoccup_screen@@@Z	; moveable::EndMove
; Line 1017
	push	WORD PTR [bp+8]	;hwnd
	push	WORD PTR [bp-2]	;hdc
	call	FAR PTR RELEASEDC
; Line 1018
	jmp	$EX8383
$EX8383:
	pop	si
	pop	di
	leave	
	ret	6

?EndMove@moveable@@UACXPBUHWND__@@PAVoccup_screen@@@Z	ENDP
	PUBLIC	?EndMove@moveable@@UACXPBUHWND__@@PBUHDC__@@PAVoccup_screen@@@Z	; moveable::EndMove
?EndMove@moveable@@UACXPBUHWND__@@PBUHDC__@@PAVoccup_screen@@@Z	PROC NEAR	; moveable::EndMove
; Line 1022
	push	bp
	mov	bp,sp
	mov	ax,2
	call	__aNchkstk
	push	di
	push	si
	mov	si,WORD PTR [bp+4]	;this
;	register si = this
;	hwnd = 10
;	hdc = 8
;	Screen = 6
; Line 1023
	mov	WORD PTR [si+52],0
; Line 1025
	push	WORD PTR [bp+10]	;hwnd
	push	WORD PTR [si+48]
	call	DWORD PTR _KillSystemTimer
; Line 1027
	push	WORD PTR [si+30]
	call	_abs
	add	sp,2
	mov	WORD PTR [si+30],ax
; Line 1028
	push	WORD PTR [si+32]
	call	_abs
	add	sp,2
	mov	WORD PTR [si+32],ax
; Line 1030
	mov	bx,WORD PTR [si+2]
	mov	bx,WORD PTR [bx+2]
	mov	ax,WORD PTR [bx+10][si]
	mov	WORD PTR [si+22],ax
; Line 1031
	mov	bx,WORD PTR [si+2]
	mov	bx,WORD PTR [bx+2]
	mov	ax,WORD PTR [bx+12][si]
	mov	WORD PTR [si+24],ax
; Line 1035
	push	WORD PTR [si+22]
	push	WORD PTR [si+24]
	push	WORD PTR [bp+6]	;Screen
	push	si
	mov	bx,WORD PTR [si]
	call	WORD PTR [bx+2]
; Line 1037
	mov	bx,WORD PTR [bp+6]	;Screen
	mov	bx,WORD PTR [bx+1096]
	cmp	WORD PTR [bx+15796],0
	jne	$JCC5467
	jmp	$I8390
$JCC5467:
; Line 1038
;	OccupObj = -2
; Line 1039
	mov	bx,WORD PTR [bp+6]	;Screen
	mov	bx,WORD PTR [bx+1096]
	mov	ax,WORD PTR [bx+15796]
	mov	WORD PTR [bp-2],ax	;OccupObj
; Line 1041
	push	WORD PTR [bp-2]	;OccupObj
	mov	bx,WORD PTR [bp-2]	;OccupObj
	mov	bx,WORD PTR [bx]
	call	WORD PTR [bx+2]
	mov	bx,WORD PTR [si+2]
	mov	cx,WORD PTR [bx+2]
	add	cx,si
	add	cx,2
	push	cx
	mov	bx,WORD PTR [si+2]
	mov	bx,WORD PTR [bx+2]
	mov	bx,WORD PTR [bx+2][si]
	mov	di,ax
	call	WORD PTR [bx+2]
	cmp	di,ax
	jl	$JCC5525
	jmp	$I8392
$JCC5525:
; Line 1042
; Line 1043
	push	WORD PTR [bp+6]	;Screen
	push	WORD PTR [bp-2]	;OccupObj
	mov	bx,WORD PTR [bp-2]	;OccupObj
	mov	bx,WORD PTR [bx]
	call	WORD PTR [bx+12]
; Line 1044
	push	WORD PTR [bp+8]	;hdc
	push	WORD PTR [bp+6]	;Screen
	push	WORD PTR [bp-2]	;OccupObj
	mov	bx,WORD PTR [bp-2]	;OccupObj
	mov	bx,WORD PTR [bx]
	call	WORD PTR [bx+18]
; Line 1045
; Line 1046
$I8392:
; Line 1048
$I8390:
	push	WORD PTR [bp+8]	;hdc
	push	WORD PTR [bp+6]	;Screen
	mov	bx,WORD PTR [si+2]
	mov	ax,WORD PTR [bx+2]
	add	ax,si
	add	ax,2
	push	ax
	mov	bx,WORD PTR [si+2]
	mov	bx,WORD PTR [bx+2]
	mov	bx,WORD PTR [bx+2][si]
	call	WORD PTR [bx+18]
; Line 1050
	mov	bx,WORD PTR [si+2]
	mov	bx,WORD PTR [bx+2]
	mov	ax,WORD PTR [bx+10][si]
	mov	WORD PTR [si+18],ax
	mov	WORD PTR [si+22],ax
; Line 1051
	mov	bx,WORD PTR [si+2]
	mov	bx,WORD PTR [bx+2]
	mov	ax,WORD PTR [bx+12][si]
	mov	WORD PTR [si+20],ax
	mov	WORD PTR [si+24],ax
; Line 1053
	jmp	$EX8389
$EX8389:
	pop	si
	pop	di
	leave	
	ret	8

?EndMove@moveable@@UACXPBUHWND__@@PBUHDC__@@PAVoccup_screen@@@Z	ENDP
	PUBLIC	?InitAnim@animated@@UACXPBUHWND__@@PAVoccup_screen@@@Z	; animated::InitAnim
?InitAnim@animated@@UACXPBUHWND__@@PAVoccup_screen@@@Z	PROC NEAR	; animated::InitAnim
; Line 1057
	push	bp
	mov	bp,sp
	mov	ax,2
	call	__aNchkstk
	push	di
	push	si
	mov	si,WORD PTR [bp+4]	;this
;	hdc = -2
;	register si = this
;	hwnd = 8
;	Screen = 6
; Line 1058
	push	WORD PTR [bp+8]	;hwnd
	call	FAR PTR GETDC
	mov	WORD PTR [bp-2],ax	;hdc
; Line 1060
	push	WORD PTR [bp-2]	;hdc
	mov	bx,WORD PTR [bp+6]	;Screen
	push	WORD PTR [bx+28]
	push	0
	call	FAR PTR SELECTPALETTE
; Line 1061
	push	WORD PTR [bp-2]	;hdc
	call	FAR PTR REALIZEPALETTE
; Line 1063
	push	WORD PTR [bp+8]	;hwnd
	push	WORD PTR [bp-2]	;hdc
	call	FAR PTR RELEASEDC
; Line 1065
	push	WORD PTR [bp+8]	;hwnd
	push	WORD PTR [si+4]
	push	WORD PTR [si+6]
	push	0
	push	0
	call	DWORD PTR _SetSystemTimer
; Line 1066
	jmp	$EX8396
$EX8396:
	pop	si
	pop	di
	leave	
	ret	6

?InitAnim@animated@@UACXPBUHWND__@@PAVoccup_screen@@@Z	ENDP
	PUBLIC	?EndAnim@animated@@UACXPBUHWND__@@PAVoccup_screen@@@Z	; animated::EndAnim
?EndAnim@animated@@UACXPBUHWND__@@PAVoccup_screen@@@Z	PROC NEAR	; animated::EndAnim
; Line 1071
	push	bp
	mov	bp,sp
	mov	ax,2
	call	__aNchkstk
	push	di
	push	si
	mov	si,WORD PTR [bp+4]	;this
;	hdc = -2
;	register si = this
;	hwnd = 8
;	Screen = 6
; Line 1073
	push	WORD PTR [bp+8]	;hwnd
	call	FAR PTR GETDC
	mov	WORD PTR [bp-2],ax	;hdc
; Line 1075
	push	WORD PTR [bp+8]	;hwnd
	push	WORD PTR [bp-2]	;hdc
	push	WORD PTR [bp+6]	;Screen
	push	si
	mov	bx,WORD PTR [si]
	call	WORD PTR [bx+2]
; Line 1077
	push	WORD PTR [bp+8]	;hwnd
	push	WORD PTR [bp-2]	;hdc
	call	FAR PTR RELEASEDC
; Line 1078
	jmp	$EX8401
$EX8401:
	pop	si
	pop	di
	leave	
	ret	6

?EndAnim@animated@@UACXPBUHWND__@@PAVoccup_screen@@@Z	ENDP
	PUBLIC	?EndAnim@animated@@UACXPBUHWND__@@PBUHDC__@@PAVoccup_screen@@@Z	; animated::EndAnim
?EndAnim@animated@@UACXPBUHWND__@@PBUHDC__@@PAVoccup_screen@@@Z	PROC NEAR	; animated::EndAnim
; Line 1081
	push	bp
	mov	bp,sp
	mov	ax,2
	call	__aNchkstk
	push	di
	push	si
	mov	si,WORD PTR [bp+4]	;this
;	register si = this
;	hwnd = 10
;	hdc = 8
;	Screen = 6
; Line 1082
	push	WORD PTR [bp+10]	;hwnd
	push	WORD PTR [si+4]
	call	DWORD PTR _KillSystemTimer
; Line 1084
	push	WORD PTR [bp+6]	;Screen
	mov	bx,WORD PTR [si+2]
	mov	ax,WORD PTR [bx+2]
	add	ax,si
	add	ax,2
	push	ax
	mov	bx,WORD PTR [si+2]
	mov	bx,WORD PTR [bx+2]
	mov	bx,WORD PTR [bx+2][si]
	call	WORD PTR [bx+14]
; Line 1086
	mov	bx,WORD PTR [bp+6]	;Screen
	mov	bx,WORD PTR [bx+1096]
	cmp	WORD PTR [bx+15796],0
	jne	$JCC5839
	jmp	$I8408
$JCC5839:
; Line 1087
;	OccupObj = -2
; Line 1088
	mov	bx,WORD PTR [bp+6]	;Screen
	mov	bx,WORD PTR [bx+1096]
	mov	ax,WORD PTR [bx+15796]
	mov	WORD PTR [bp-2],ax	;OccupObj
; Line 1090
	push	WORD PTR [bp-2]	;OccupObj
	mov	bx,WORD PTR [bp-2]	;OccupObj
	mov	bx,WORD PTR [bx]
	call	WORD PTR [bx+2]
	mov	bx,WORD PTR [si+2]
	mov	cx,WORD PTR [bx+2]
	add	cx,si
	add	cx,2
	push	cx
	mov	bx,WORD PTR [si+2]
	mov	bx,WORD PTR [bx+2]
	mov	bx,WORD PTR [bx+2][si]
	mov	di,ax
	call	WORD PTR [bx+2]
	cmp	di,ax
	jl	$JCC5897
	jmp	$I8410
$JCC5897:
; Line 1091
; Line 1092
	push	WORD PTR [bp+6]	;Screen
	push	WORD PTR [bp-2]	;OccupObj
	mov	bx,WORD PTR [bp-2]	;OccupObj
	mov	bx,WORD PTR [bx]
	call	WORD PTR [bx+12]
; Line 1093
	push	WORD PTR [bp+8]	;hdc
	push	WORD PTR [bp+6]	;Screen
	push	WORD PTR [bp-2]	;OccupObj
	mov	bx,WORD PTR [bp-2]	;OccupObj
	mov	bx,WORD PTR [bx]
	call	WORD PTR [bx+18]
; Line 1094
; Line 1095
$I8410:
; Line 1098
$I8408:
	push	WORD PTR [bp+8]	;hdc
	push	WORD PTR [bp+6]	;Screen
	mov	bx,WORD PTR [si+2]
	mov	ax,WORD PTR [bx+2]
	add	ax,si
	add	ax,2
	push	ax
	call	?Show@object@@UACXPBUHDC__@@PAVscreen@@@Z	; object::Show
; Line 1099
	jmp	$EX8407
$EX8407:
	pop	si
	pop	di
	leave	
	ret	8

?EndAnim@animated@@UACXPBUHWND__@@PBUHDC__@@PAVoccup_screen@@@Z	ENDP
	PUBLIC	?Anim1Frame@animated@@UACXPBUHWND__@@PAVoccup_screen@@@Z	; animated::Anim1Frame
?Anim1Frame@animated@@UACXPBUHWND__@@PAVoccup_screen@@@Z	PROC NEAR	; animated::Anim1Frame
; Line 1102
	push	bp
	mov	bp,sp
	mov	ax,2
	call	__aNchkstk
	push	di
	push	si
	mov	si,WORD PTR [bp+4]	;this
;	hdc = -2
;	register si = this
;	hwnd = 8
;	Screen = 6
; Line 1103
	push	WORD PTR [bp+8]	;hwnd
	call	FAR PTR GETDC
	mov	WORD PTR [bp-2],ax	;hdc
; Line 1105
	mov	bx,WORD PTR [si+2]
	mov	ax,WORD PTR [bx+2]
	add	ax,si
	add	ax,2
	push	ax
	mov	bx,WORD PTR [si+2]
	mov	bx,WORD PTR [bx+2]
	mov	bx,WORD PTR [bx+2][si]
	call	WORD PTR [bx+20]
; Line 1106
	push	WORD PTR [bp+6]	;Screen
	mov	bx,WORD PTR [si+2]
	mov	ax,WORD PTR [bx+2]
	add	ax,si
	add	ax,2
	push	ax
	mov	bx,WORD PTR [si+2]
	mov	bx,WORD PTR [bx+2]
	mov	bx,WORD PTR [bx+2][si]
	call	WORD PTR [bx+14]
; Line 1107
	push	WORD PTR [bp-2]	;hdc
	push	WORD PTR [bp+6]	;Screen
	mov	bx,WORD PTR [si+2]
	mov	ax,WORD PTR [bx+2]
	add	ax,si
	add	ax,2
	push	ax
	call	?Show@object@@UACXPBUHDC__@@PAVscreen@@@Z	; object::Show
; Line 1109
	push	WORD PTR [bp+8]	;hwnd
	push	WORD PTR [bp-2]	;hdc
	call	FAR PTR RELEASEDC
; Line 1110
	jmp	$EX8414
$EX8414:
	pop	si
	pop	di
	leave	
	ret	6

?Anim1Frame@animated@@UACXPBUHWND__@@PAVoccup_screen@@@Z	ENDP
	PUBLIC	?Anim1Frame@_3D_animated@@UACXPBUHWND__@@PAV_3D_screen@@@Z	; _3D_animated::Anim1Frame
?Anim1Frame@_3D_animated@@UACXPBUHWND__@@PAV_3D_screen@@@Z	PROC NEAR	; _3D_animated::Anim1Frame
; Line 1114
	push	bp
	mov	bp,sp
	mov	ax,4
	call	__aNchkstk
	push	di
	push	si
	mov	si,WORD PTR [bp+4]	;this
;	hdc = -2
;	register si = this
;	hwnd = 8
;	Screen = 6
; Line 1115
	push	WORD PTR [bp+8]	;hwnd
	call	FAR PTR GETDC
	mov	WORD PTR [bp-2],ax	;hdc
; Line 1117
	mov	bx,WORD PTR [si+2]
	mov	ax,WORD PTR [bx+2]
	add	ax,si
	add	ax,2
	push	ax
	mov	bx,WORD PTR [si+2]
	mov	bx,WORD PTR [bx+2]
	mov	bx,WORD PTR [bx+2][si]
	call	WORD PTR [bx+20]
; Line 1118
	push	WORD PTR [bp+6]	;Screen
	mov	bx,WORD PTR [si+2]
	mov	ax,WORD PTR [bx+2]
	add	ax,si
	add	ax,2
	push	ax
	mov	bx,WORD PTR [si+2]
	mov	bx,WORD PTR [bx+2]
	mov	bx,WORD PTR [bx+2][si]
	call	WORD PTR [bx+14]
; Line 1120
	mov	bx,WORD PTR [bp+6]	;Screen
	mov	bx,WORD PTR [bx+1096]
	cmp	WORD PTR [bx+15796],0
	jne	$JCC6168
	jmp	$I8421
$JCC6168:
; Line 1121
;	OccupObj = -4
; Line 1122
	mov	bx,WORD PTR [bp+6]	;Screen
	mov	bx,WORD PTR [bx+1096]
	mov	ax,WORD PTR [bx+15796]
	mov	WORD PTR [bp-4],ax	;OccupObj
; Line 1124
	push	WORD PTR [bp-4]	;OccupObj
	mov	bx,WORD PTR [bp-4]	;OccupObj
	mov	bx,WORD PTR [bx]
	call	WORD PTR [bx+2]
	mov	bx,WORD PTR [si+2]
	mov	bx,WORD PTR [bx+4]
	cmp	WORD PTR [bx+8][si],ax
	jg	$JCC6207
	jmp	$I8423
$JCC6207:
; Line 1125
; Line 1126
	push	WORD PTR [bp+6]	;Screen
	push	WORD PTR [bp-4]	;OccupObj
	mov	bx,WORD PTR [bp-4]	;OccupObj
	mov	bx,WORD PTR [bx]
	call	WORD PTR [bx+12]
; Line 1127
	push	WORD PTR [bp-2]	;hdc
	push	WORD PTR [bp+6]	;Screen
	push	WORD PTR [bp-4]	;OccupObj
	mov	bx,WORD PTR [bp-4]	;OccupObj
	mov	bx,WORD PTR [bx]
	call	WORD PTR [bx+18]
; Line 1128
; Line 1129
$I8423:
; Line 1131
$I8421:
	push	WORD PTR [bp-2]	;hdc
	push	WORD PTR [bp+6]	;Screen
	mov	bx,WORD PTR [si+2]
	mov	ax,WORD PTR [bx+2]
	add	ax,si
	add	ax,2
	push	ax
	call	?Show@object@@UACXPBUHDC__@@PAVscreen@@@Z	; object::Show
; Line 1133
	push	WORD PTR [bp+8]	;hwnd
	push	WORD PTR [bp-2]	;hdc
	call	FAR PTR RELEASEDC
; Line 1134
	jmp	$EX8419
$EX8419:
	pop	si
	pop	di
	leave	
	ret	6

?Anim1Frame@_3D_animated@@UACXPBUHWND__@@PAV_3D_screen@@@Z	ENDP
	PUBLIC	?ReservePalette@object_list@@QACXAAUheader@@AAUpal@@@Z	; object_list::ReservePalette
?ReservePalette@object_list@@QACXAAUheader@@AAUpal@@@Z	PROC NEAR	; object_list::ReservePalette
; Line 1139
	push	bp
	mov	bp,sp
	mov	ax,8
	call	__aNchkstk
	push	di
	push	si
	mov	si,WORD PTR [bp+4]	;this
;	register di = Counter
;	End = -8
;	Object = -2
;	pColorTable = -6
;	register si = this
;	BufferHeader = 8
;	LogicalPalette = 6
; Line 1145
	mov	ax,WORD PTR [si]
	mov	WORD PTR [bp-2],ax	;Object
	jmp	$F8432
$FC8433:
	mov	bx,WORD PTR [bp-2]	;Object
	mov	ax,WORD PTR [bx+2]
	mov	WORD PTR [bp-2],ax	;Object
$F8432:
	cmp	WORD PTR [bp-2],0	;Object
	jne	$JCC6319
	jmp	$FB8434
$JCC6319:
; Line 1146
; Line 1148
	push	WORD PTR [bp-2]	;Object
	call	?pColorTable@object@@QACPEUtagRGBQUAD@@XZ	; object::pColorTable
	mov	WORD PTR [bp-6],ax	;pColorTable
	mov	WORD PTR [bp-4],dx
; Line 1151
	mov	bx,WORD PTR [bp-2]	;Object
	mov	di,WORD PTR [bx+12]
	mov	bx,WORD PTR [bp-2]	;Object
	mov	ax,WORD PTR [bx+14]
	add	ax,di
	mov	WORD PTR [bp-8],ax	;End
; Line 1152
	jmp	$F8435
$FC8436:
	inc	di
$F8435:
	cmp	WORD PTR [bp-8],di	;End
	jg	$JCC6360
	jmp	$FB8437
$JCC6360:
; Line 1153
; Line 1158
	mov	bx,di
	shl	bx,2
	mov	es,WORD PTR [bp-4]
	add	bx,WORD PTR [bp-6]	;pColorTable
	mov	al,BYTE PTR es:[bx+2]
	mov	bx,di
	shl	bx,2
	add	bx,WORD PTR [bp+6]	;LogicalPalette
	mov	BYTE PTR [bx+4],al
	mov	bx,di
	shl	bx,2
	add	bx,WORD PTR [bp+8]	;BufferHeader
	mov	BYTE PTR [bx+42],al
; Line 1161
	mov	bx,di
	shl	bx,2
	mov	es,WORD PTR [bp-4]
	add	bx,WORD PTR [bp-6]	;pColorTable
	mov	al,BYTE PTR es:[bx+1]
	mov	bx,di
	shl	bx,2
	add	bx,WORD PTR [bp+6]	;LogicalPalette
	mov	BYTE PTR [bx+5],al
	mov	bx,di
	shl	bx,2
	add	bx,WORD PTR [bp+8]	;BufferHeader
	mov	BYTE PTR [bx+41],al
; Line 1165
	mov	bx,di
	shl	bx,2
	mov	es,WORD PTR [bp-4]
	add	bx,WORD PTR [bp-6]	;pColorTable
	mov	al,BYTE PTR es:[bx]
	mov	bx,di
	shl	bx,2
	add	bx,WORD PTR [bp+6]	;LogicalPalette
	mov	BYTE PTR [bx+6],al
	mov	bx,di
	shl	bx,2
	add	bx,WORD PTR [bp+8]	;BufferHeader
	mov	BYTE PTR [bx+40],al
; Line 1166
	mov	bx,di
	shl	bx,2
	add	bx,WORD PTR [bp+8]	;BufferHeader
	mov	BYTE PTR [bx+43],0
; Line 1167
	mov	bx,di
	shl	bx,2
	add	bx,WORD PTR [bp+6]	;LogicalPalette
	mov	BYTE PTR [bx+7],4
; Line 1168
	jmp	$FC8436
$FB8437:
; Line 1170
	jmp	$FC8433
$FB8434:
; Line 1171
	jmp	$EX8427
$EX8427:
	pop	si
	pop	di
	leave	
	ret	6

?ReservePalette@object_list@@QACXAAUheader@@AAUpal@@@Z	ENDP
	PUBLIC	?PutIntoBuffer@object_list@@QACXPBUHDC__@@AAUheader@@PEX@Z	; object_list::PutIntoBuffer
?PutIntoBuffer@object_list@@QACXPBUHDC__@@AAUheader@@PEX@Z	PROC NEAR	; object_list::PutIntoBuffer
; Line 1174
	push	bp
	mov	bp,sp
	mov	ax,2
	call	__aNchkstk
	push	di
	push	si
	mov	si,WORD PTR [bp+4]	;this
;	Object = -2
;	register si = this
;	hBuffer = 12
;	BufferHeader = 10
;	pBuffer = 6
; Line 1177
	mov	ax,WORD PTR [si]
	mov	WORD PTR [bp-2],ax	;Object
	jmp	$F8444
$FC8445:
	mov	bx,WORD PTR [bp-2]	;Object
	mov	ax,WORD PTR [bx+2]
	mov	WORD PTR [bp-2],ax	;Object
$F8444:
	cmp	WORD PTR [bp-2],0	;Object
	jne	$JCC6549
	jmp	$FB8446
$JCC6549:
; Line 1178
; Line 1180
	mov	bx,WORD PTR [bp-2]	;Object
	cmp	WORD PTR [bx+1096],0
	jne	$JCC6562
	jmp	$I8447
$JCC6562:
; Line 1181
; Line 1183
	push	WORD PTR [bp+12]	;hBuffer
	push	WORD PTR [bp-2]	;Object
	call	?SaveBackGround@object@@QACXPBUHDC__@@@Z	; object::SaveBackGround
; Line 1186
	push	ds
	push	WORD PTR [bp+10]	;BufferHeader
	push	WORD PTR [bp+8]
	push	WORD PTR [bp+6]	;pBuffer
	push	WORD PTR [bp-2]	;Object
	call	?PutIntoBuffer@object@@QACXPEUtagBITMAPINFO@@PEX@Z	; object::PutIntoBuffer
; Line 1187
; Line 1188
$I8447:
	jmp	$FC8445
$FB8446:
; Line 1189
	jmp	$EX8442
$EX8442:
	pop	si
	pop	di
	leave	
	ret	10	;000aH

?PutIntoBuffer@object_list@@QACXPBUHDC__@@AAUheader@@PEX@Z	ENDP
	PUBLIC	?AddPointer@@YAPEDPEDJ@Z	; AddPointer
?AddPointer@@YAPEDPEDJ@Z	PROC NEAR	; AddPointer
; Line 1195
	push	bp
	mov	bp,sp
	mov	ax,12	;000cH
	call	__aNchkstk
	push	di
	push	si
;	seg = -4
;	off = -8
;	abs = -12
;	n = 8
;	p = 4
; Line 1200
	mov	ax,WORD PTR [bp+4]	;p
	mov	dx,WORD PTR [bp+6]
	mov	WORD PTR [bp-12],ax	;abs
	mov	WORD PTR [bp-10],dx
; Line 1202
	mov	ax,WORD PTR [bp-12]	;abs
	mov	dx,WORD PTR [bp-10]
	and	ax,4095	;0fffH
	and	dx,-1	;ffffH
	shl	ax,1
	rcl	dx,1
	rcl	ax,1
	rcl	dx,1
	rcl	ax,1
	rcl	dx,1
	rcl	ax,1
	rcl	dx,1
	rcl	ax,1
	xchg	ax,dx
	and	dx,15	;000fH
	add	ax,WORD PTR [bp-12]	;abs
	adc	dx,0
	mov	WORD PTR [bp-12],ax	;abs
	mov	WORD PTR [bp-10],dx
; Line 1204
	mov	ax,WORD PTR [bp+8]	;n
	mov	dx,WORD PTR [bp+10]
	add	WORD PTR [bp-12],ax	;abs
	adc	WORD PTR [bp-10],dx
; Line 1206
	mov	ax,WORD PTR [bp-12]	;abs
	mov	dx,WORD PTR [bp-10]
	and	ax,-16	;fff0H
	and	dx,-1	;ffffH
	shr	dx,1
	rcr	ax,1
	rcr	dx,1
	rcr	ax,1
	rcr	dx,1
	rcr	ax,1
	rcr	dx,1
	rcr	ax,1
	rcr	dx,1
	xchg	dx,ax
	and	ax,-4096	;f000H
	mov	WORD PTR [bp-4],ax	;seg
	mov	WORD PTR [bp-2],dx
; Line 1207
	mov	al,BYTE PTR [bp-12]	;abs
	and	ax,15	;000fH
	mov	WORD PTR [bp-8],ax	;off
	mov	WORD PTR [bp-6],0
; Line 1209
	mov	ax,WORD PTR [bp-8]	;off
	mov	dx,WORD PTR [bp-6]
	and	ax,WORD PTR [bp-4]	;seg
	and	dx,WORD PTR [bp-2]
	jmp	$EX8451
; Line 1211
$EX8451:
	pop	si
	pop	di
	leave	
	ret	

?AddPointer@@YAPEDPEDJ@Z	ENDP
	PUBLIC	??_Esprite@@QACPAXI@Z	; ??_Esprite@@QACPAXI@Z
??_Esprite@@QACPAXI@Z	PROC NEAR	; ??_Esprite@@QACPAXI@Z COMDAT
	push	bp
	mov	bp,sp
	mov	ax,0
	call	__aNchkstk
	push	di
	push	si
	mov	si,WORD PTR [bp+4]	;this
;	register si = this
;	__flags = 6
	test	BYTE PTR [bp+6],2	;__flags
	jne	$JCC18
	jmp	$E8465
$JCC18:
	push	si
	push	10	;000aH
	push	WORD PTR [si-2]
	push	OFFSET ??1sprite@@QAC@XZ	;sprite::~sprite
	call	??_I@YCXPAXIHP6CX0@Z@Z	; ??_I@YCXPAXIHP6CX0@Z@Z
	lea	ax,WORD PTR [si-2]
	push	ax
	call	??3@YAXPAX@Z	; operator delete
	add	sp,2
	jmp	$I8466
$E8465:
	push	si
	call	??1sprite@@QAC@XZ	; sprite::~sprite
	test	BYTE PTR [bp+6],1	;__flags
	jne	$JCC56
	jmp	$I8468
$JCC56:
	push	si
	call	??3@YAXPAX@Z	; operator delete
	add	sp,2
$I8468:
$I8466:
	mov	ax,si
	jmp	$EX8464
$EX8464:
	pop	si
	pop	di
	leave	
	ret	4

??_Esprite@@QACPAXI@Z	ENDP
	PUBLIC	?x3D@_3D_object@@WPPPPPLJI@ACHXZ	; _3D_object::x3D
?x3D@_3D_object@@WPPPPPLJI@ACHXZ	PROC NEAR	; _3D_object::x3D COMDAT
	mov	bx,sp
	sub	WORD PTR ss:[bx+2],-1128	;fb98H
	jmp	FAR PTR ?x3D@_3D_object@@UACHXZ	; _3D_object::x3D

?x3D@_3D_object@@WPPPPPLJI@ACHXZ	ENDP
	PUBLIC	?y3D@_3D_object@@WPPPPPLJI@ACHXZ	; _3D_object::y3D
?y3D@_3D_object@@WPPPPPLJI@ACHXZ	PROC NEAR	; _3D_object::y3D COMDAT
	mov	bx,sp
	sub	WORD PTR ss:[bx+2],-1128	;fb98H
	jmp	FAR PTR ?y3D@_3D_object@@UACHXZ	; _3D_object::y3D

?y3D@_3D_object@@WPPPPPLJI@ACHXZ	ENDP
	PUBLIC	?z3D@_3D_object@@WPPPPPLJI@ACHXZ	; _3D_object::z3D
?z3D@_3D_object@@WPPPPPLJI@ACHXZ	PROC NEAR	; _3D_object::z3D COMDAT
	mov	bx,sp
	sub	WORD PTR ss:[bx+2],-1128	;fb98H
	jmp	FAR PTR ?z3D@_3D_object@@UACHXZ	; _3D_object::z3D

?z3D@_3D_object@@WPPPPPLJI@ACHXZ	ENDP
	PUBLIC	?w3D@_3D_object@@WPPPPPLJI@ACHXZ	; _3D_object::w3D
?w3D@_3D_object@@WPPPPPLJI@ACHXZ	PROC NEAR	; _3D_object::w3D COMDAT
	mov	bx,sp
	sub	WORD PTR ss:[bx+2],-1128	;fb98H
	jmp	FAR PTR ?w3D@_3D_object@@UACHXZ	; _3D_object::w3D

?w3D@_3D_object@@WPPPPPLJI@ACHXZ	ENDP
	PUBLIC	?h3D@_3D_object@@WPPPPPLJI@ACHXZ	; _3D_object::h3D
?h3D@_3D_object@@WPPPPPLJI@ACHXZ	PROC NEAR	; _3D_object::h3D COMDAT
	mov	bx,sp
	sub	WORD PTR ss:[bx+2],-1128	;fb98H
	jmp	FAR PTR ?h3D@_3D_object@@UACHXZ	; _3D_object::h3D

?h3D@_3D_object@@WPPPPPLJI@ACHXZ	ENDP
	PUBLIC	?d3D@_3D_object@@WPPPPPLJI@ACHXZ	; _3D_object::d3D
?d3D@_3D_object@@WPPPPPLJI@ACHXZ	PROC NEAR	; _3D_object::d3D COMDAT
	mov	bx,sp
	sub	WORD PTR ss:[bx+2],-1128	;fb98H
	jmp	FAR PTR ?d3D@_3D_object@@UACHXZ	; _3D_object::d3D

?d3D@_3D_object@@WPPPPPLJI@ACHXZ	ENDP
	PUBLIC	?NextFrame@animated@@$4PPPPPPPO@A@ACHXZ	; animated::NextFrame
?NextFrame@animated@@$4PPPPPPPO@A@ACHXZ	PROC NEAR	; animated::NextFrame COMDAT
	mov	bx,sp
	mov	bx,WORD PTR ss:[bx+2]
	mov	ax,WORD PTR [bx+65534]
	mov	bx,sp
	sub	WORD PTR ss:[bx+2],ax
	jmp	?NextFrame@animated@@UACHXZ	; animated::NextFrame

?NextFrame@animated@@$4PPPPPPPO@A@ACHXZ	ENDP
	PUBLIC	?PreviousFrame@animated@@$4PPPPPPPO@A@ACHXZ	; animated::PreviousFrame
?PreviousFrame@animated@@$4PPPPPPPO@A@ACHXZ	PROC NEAR	; animated::PreviousFrame COMDAT
	mov	bx,sp
	mov	bx,WORD PTR ss:[bx+2]
	mov	ax,WORD PTR [bx+65534]
	mov	bx,sp
	sub	WORD PTR ss:[bx+2],ax
	jmp	?PreviousFrame@animated@@UACHXZ	; animated::PreviousFrame

?PreviousFrame@animated@@$4PPPPPPPO@A@ACHXZ	ENDP
	PUBLIC	?x3D@_3D_object@@$4PPPPPPPO@A@ACHXZ	; _3D_object::x3D
?x3D@_3D_object@@$4PPPPPPPO@A@ACHXZ	PROC NEAR	; _3D_object::x3D COMDAT
	mov	bx,sp
	mov	bx,WORD PTR ss:[bx+2]
	mov	ax,WORD PTR [bx+65534]
	mov	bx,sp
	sub	WORD PTR ss:[bx+2],ax
	jmp	?x3D@_3D_object@@UACHXZ	; _3D_object::x3D

?x3D@_3D_object@@$4PPPPPPPO@A@ACHXZ	ENDP
	PUBLIC	?y3D@_3D_object@@$4PPPPPPPO@A@ACHXZ	; _3D_object::y3D
?y3D@_3D_object@@$4PPPPPPPO@A@ACHXZ	PROC NEAR	; _3D_object::y3D COMDAT
	mov	bx,sp
	mov	bx,WORD PTR ss:[bx+2]
	mov	ax,WORD PTR [bx+65534]
	mov	bx,sp
	sub	WORD PTR ss:[bx+2],ax
	jmp	?y3D@_3D_object@@UACHXZ	; _3D_object::y3D

?y3D@_3D_object@@$4PPPPPPPO@A@ACHXZ	ENDP
	PUBLIC	?z3D@_3D_object@@$4PPPPPPPO@A@ACHXZ	; _3D_object::z3D
?z3D@_3D_object@@$4PPPPPPPO@A@ACHXZ	PROC NEAR	; _3D_object::z3D COMDAT
	mov	bx,sp
	mov	bx,WORD PTR ss:[bx+2]
	mov	ax,WORD PTR [bx+65534]
	mov	bx,sp
	sub	WORD PTR ss:[bx+2],ax
	jmp	?z3D@_3D_object@@UACHXZ	; _3D_object::z3D

?z3D@_3D_object@@$4PPPPPPPO@A@ACHXZ	ENDP
	PUBLIC	?w3D@_3D_object@@$4PPPPPPPO@A@ACHXZ	; _3D_object::w3D
?w3D@_3D_object@@$4PPPPPPPO@A@ACHXZ	PROC NEAR	; _3D_object::w3D COMDAT
	mov	bx,sp
	mov	bx,WORD PTR ss:[bx+2]
	mov	ax,WORD PTR [bx+65534]
	mov	bx,sp
	sub	WORD PTR ss:[bx+2],ax
	jmp	?w3D@_3D_object@@UACHXZ	; _3D_object::w3D

?w3D@_3D_object@@$4PPPPPPPO@A@ACHXZ	ENDP
	PUBLIC	?h3D@_3D_object@@$4PPPPPPPO@A@ACHXZ	; _3D_object::h3D
?h3D@_3D_object@@$4PPPPPPPO@A@ACHXZ	PROC NEAR	; _3D_object::h3D COMDAT
	mov	bx,sp
	mov	bx,WORD PTR ss:[bx+2]
	mov	ax,WORD PTR [bx+65534]
	mov	bx,sp
	sub	WORD PTR ss:[bx+2],ax
	jmp	?h3D@_3D_object@@UACHXZ	; _3D_object::h3D

?h3D@_3D_object@@$4PPPPPPPO@A@ACHXZ	ENDP
	PUBLIC	?d3D@_3D_object@@$4PPPPPPPO@A@ACHXZ	; _3D_object::d3D
?d3D@_3D_object@@$4PPPPPPPO@A@ACHXZ	PROC NEAR	; _3D_object::d3D COMDAT
	mov	bx,sp
	mov	bx,WORD PTR ss:[bx+2]
	mov	ax,WORD PTR [bx+65534]
	mov	bx,sp
	sub	WORD PTR ss:[bx+2],ax
	jmp	?d3D@_3D_object@@UACHXZ	; _3D_object::d3D

?d3D@_3D_object@@$4PPPPPPPO@A@ACHXZ	ENDP
	PUBLIC	?Show@moveable@@$4PPPPPPPO@A@ACXPBUHDC__@@PAVscreen@@@Z	; moveable::Show
?Show@moveable@@$4PPPPPPPO@A@ACXPBUHDC__@@PAVscreen@@@Z	PROC NEAR	; moveable::Show COMDAT
	mov	bx,sp
	mov	bx,WORD PTR ss:[bx+2]
	mov	ax,WORD PTR [bx+65534]
	mov	bx,sp
	sub	WORD PTR ss:[bx+2],ax
	jmp	?Show@moveable@@UACXPBUHDC__@@PAVscreen@@@Z	; moveable::Show

?Show@moveable@@$4PPPPPPPO@A@ACXPBUHDC__@@PAVscreen@@@Z	ENDP
	PUBLIC	?Show@moveable@@$4PPPPPPPO@O@ACXPBUHDC__@@PAVscreen@@@Z	; moveable::Show
?Show@moveable@@$4PPPPPPPO@O@ACXPBUHDC__@@PAVscreen@@@Z	PROC NEAR	; moveable::Show COMDAT
	mov	bx,sp
	mov	bx,WORD PTR ss:[bx+2]
	mov	ax,WORD PTR [bx+65534]
	add	ax,14	;000eH
	mov	bx,sp
	sub	WORD PTR ss:[bx+2],ax
	jmp	?Show@moveable@@UACXPBUHDC__@@PAVscreen@@@Z	; moveable::Show

?Show@moveable@@$4PPPPPPPO@O@ACXPBUHDC__@@PAVscreen@@@Z	ENDP
	PUBLIC	?NextFrame@animated@@W5ACHXZ	; animated::NextFrame
?NextFrame@animated@@W5ACHXZ	PROC NEAR	; animated::NextFrame COMDAT
	mov	bx,sp
	sub	WORD PTR ss:[bx+2],6
	jmp	FAR PTR ?NextFrame@animated@@UACHXZ	; animated::NextFrame

?NextFrame@animated@@W5ACHXZ	ENDP
	PUBLIC	?PreviousFrame@animated@@W5ACHXZ	; animated::PreviousFrame
?PreviousFrame@animated@@W5ACHXZ	PROC NEAR	; animated::PreviousFrame COMDAT
	mov	bx,sp
	sub	WORD PTR ss:[bx+2],6
	jmp	FAR PTR ?PreviousFrame@animated@@UACHXZ	; animated::PreviousFrame

?PreviousFrame@animated@@W5ACHXZ	ENDP
	PUBLIC	?OccupScreen@player@@$4PPPPPPPO@A@ACXPAVscreen@@@Z	; player::OccupScreen
?OccupScreen@player@@$4PPPPPPPO@A@ACXPAVscreen@@@Z	PROC NEAR	; player::OccupScreen COMDAT
	mov	bx,sp
	mov	bx,WORD PTR ss:[bx+2]
	mov	ax,WORD PTR [bx+65534]
	mov	bx,sp
	sub	WORD PTR ss:[bx+2],ax
	jmp	?OccupScreen@player@@UACXPAVscreen@@@Z	; player::OccupScreen

?OccupScreen@player@@$4PPPPPPPO@A@ACXPAVscreen@@@Z	ENDP
	PUBLIC	?Show@moveable@@$4PPPPPPPO@7ACXPBUHDC__@@PAVscreen@@@Z	; moveable::Show
?Show@moveable@@$4PPPPPPPO@7ACXPBUHDC__@@PAVscreen@@@Z	PROC NEAR	; moveable::Show COMDAT
	mov	bx,sp
	mov	bx,WORD PTR ss:[bx+2]
	mov	ax,WORD PTR [bx+65534]
	add	ax,8
	mov	bx,sp
	sub	WORD PTR ss:[bx+2],ax
	jmp	?Show@moveable@@UACXPBUHDC__@@PAVscreen@@@Z	; moveable::Show

?Show@moveable@@$4PPPPPPPO@7ACXPBUHDC__@@PAVscreen@@@Z	ENDP
	PUBLIC	?Show@_3D_moveable@@$4PPPPPPPO@O@ACXPBUHDC__@@PAVscreen@@@Z	; _3D_moveable::Show
?Show@_3D_moveable@@$4PPPPPPPO@O@ACXPBUHDC__@@PAVscreen@@@Z	PROC NEAR	; _3D_moveable::Show COMDAT
	mov	bx,sp
	mov	bx,WORD PTR ss:[bx+2]
	mov	ax,WORD PTR [bx+65534]
	add	ax,14	;000eH
	mov	bx,sp
	sub	WORD PTR ss:[bx+2],ax
	jmp	?Show@_3D_moveable@@UACXPBUHDC__@@PAVscreen@@@Z	; _3D_moveable::Show

?Show@_3D_moveable@@$4PPPPPPPO@O@ACXPBUHDC__@@PAVscreen@@@Z	ENDP
	PUBLIC	?OccupScreen@_3D_player@@$4PPPPPPPO@A@ACXPAVscreen@@@Z	; _3D_player::OccupScreen
?OccupScreen@_3D_player@@$4PPPPPPPO@A@ACXPAVscreen@@@Z	PROC NEAR	; _3D_player::OccupScreen COMDAT
	mov	bx,sp
	mov	bx,WORD PTR ss:[bx+2]
	mov	ax,WORD PTR [bx+65534]
	mov	bx,sp
	sub	WORD PTR ss:[bx+2],ax
	jmp	?OccupScreen@_3D_player@@UACXPAVscreen@@@Z	; _3D_player::OccupScreen

?OccupScreen@_3D_player@@$4PPPPPPPO@A@ACXPAVscreen@@@Z	ENDP
	PUBLIC	?Show@_3D_moveable@@$4PPPPPPPO@7ACXPBUHDC__@@PAVscreen@@@Z	; _3D_moveable::Show
?Show@_3D_moveable@@$4PPPPPPPO@7ACXPBUHDC__@@PAVscreen@@@Z	PROC NEAR	; _3D_moveable::Show COMDAT
	mov	bx,sp
	mov	bx,WORD PTR ss:[bx+2]
	mov	ax,WORD PTR [bx+65534]
	add	ax,8
	mov	bx,sp
	sub	WORD PTR ss:[bx+2],ax
	jmp	?Show@_3D_moveable@@UACXPBUHDC__@@PAVscreen@@@Z	; _3D_moveable::Show

?Show@_3D_moveable@@$4PPPPPPPO@7ACXPBUHDC__@@PAVscreen@@@Z	ENDP
	PUBLIC	?Show@_3D_moveable@@$4PPPPPPPO@A@ACXPBUHDC__@@PAVscreen@@@Z	; _3D_moveable::Show
?Show@_3D_moveable@@$4PPPPPPPO@A@ACXPBUHDC__@@PAVscreen@@@Z	PROC NEAR	; _3D_moveable::Show COMDAT
	mov	bx,sp
	mov	bx,WORD PTR ss:[bx+2]
	mov	ax,WORD PTR [bx+65534]
	mov	bx,sp
	sub	WORD PTR ss:[bx+2],ax
	jmp	?Show@_3D_moveable@@UACXPBUHDC__@@PAVscreen@@@Z	; _3D_moveable::Show

?Show@_3D_moveable@@$4PPPPPPPO@A@ACXPBUHDC__@@PAVscreen@@@Z	ENDP
	PUBLIC	?IncrOccup@occup_matrix@@QACDHHPAVobject@@@Z	; occup_matrix::IncrOccup
?IncrOccup@occup_matrix@@QACDHHPAVobject@@@Z	PROC NEAR	; occup_matrix::IncrOccup COMDAT
; Line 162
	push	bp
	mov	bp,sp
	mov	ax,0
	call	__aNchkstk
	push	di
	push	si
	mov	si,WORD PTR [bp+4]	;this
;	register si = this
;	Line = 10
;	Col = 8
;	o = 6
; Line 163
	mov	ax,WORD PTR [bp+6]	;o
	imul	bx,WORD PTR [bp+10],81	;0051H	;Line
	add	bx,WORD PTR [bp+8]	;Col
	shl	bx,1
	mov	WORD PTR [bx+5266][si],ax
; Line 165
	imul	bx,WORD PTR [bp+10],81	;0051H	;Line
	add	bx,WORD PTR [bp+8]	;Col
	cmp	BYTE PTR [bx][si],255	;00ffH
	jne	$JCC40
	jmp	$I6392
$JCC40:
; Line 166
; Line 167
	imul	bx,WORD PTR [bp+10],81	;0051H	;Line
	add	bx,WORD PTR [bp+8]	;Col
	inc	BYTE PTR [bx][si]
	mov	al,BYTE PTR [bx][si]
	jmp	$EX6390
; Line 168
; Line 169
	jmp	$I6394
$I6392:
; Line 170
; Line 171
	imul	bx,WORD PTR [bp+10],81	;0051H	;Line
	add	bx,WORD PTR [bp+8]	;Col
	mov	BYTE PTR [bx][si],1
; Line 172
	mov	al,1
	jmp	$EX6390
; Line 173
$I6394:
; Line 174
$EX6390:
	pop	si
	pop	di
	leave	
	ret	8

?IncrOccup@occup_matrix@@QACDHHPAVobject@@@Z	ENDP
	PUBLIC	?DecrOccup@occup_matrix@@QACDHHPAVobject@@@Z	; occup_matrix::DecrOccup
?DecrOccup@occup_matrix@@QACDHHPAVobject@@@Z	PROC NEAR	; occup_matrix::DecrOccup COMDAT
; Line 177
	push	bp
	mov	bp,sp
	mov	ax,0
	call	__aNchkstk
	push	di
	push	si
	mov	si,WORD PTR [bp+4]	;this
;	register si = this
;	Line = 10
;	Col = 8
;	o = 6
; Line 178
	imul	bx,WORD PTR [bp+10],81	;0051H	;Line
	add	bx,WORD PTR [bp+8]	;Col
	shl	bx,1
	mov	WORD PTR [bx+5266][si],0
; Line 180
	imul	bx,WORD PTR [bp+10],81	;0051H	;Line
	add	bx,WORD PTR [bp+8]	;Col
	cmp	BYTE PTR [bx][si],0
	jg	$JCC39
	jmp	$I6402
$JCC39:
; Line 181
; Line 182
	imul	bx,WORD PTR [bp+10],81	;0051H	;Line
	add	bx,WORD PTR [bp+8]	;Col
	dec	BYTE PTR [bx][si]
	mov	al,BYTE PTR [bx][si]
	jmp	$EX6400
; Line 183
; Line 184
	jmp	$I6404
$I6402:
; Line 185
; Line 186
	mov	al,255	;00ffH
	jmp	$EX6400
; Line 187
$I6404:
; Line 188
$EX6400:
	pop	si
	pop	di
	leave	
	ret	8

?DecrOccup@occup_matrix@@QACDHHPAVobject@@@Z	ENDP
	PUBLIC	?Show@screen@@QACXPBUHDC__@@@Z	; screen::Show
?Show@screen@@QACXPBUHDC__@@@Z	PROC NEAR	; screen::Show COMDAT
; Line 300
	push	bp
	mov	bp,sp
	mov	ax,0
	call	__aNchkstk
	push	di
	push	si
	mov	si,WORD PTR [bp+4]	;this
;	register si = this
;	hdc = 6
; Line 302
	push	WORD PTR [bp+6]	;hdc
	push	0
	push	0
	push	WORD PTR [si+20]
	push	WORD PTR [si+22]
	push	WORD PTR [si+2]
	push	WORD PTR [si+16]
	push	WORD PTR [si+18]
	call	FAR PTR WINGBITBLT
; Line 303
	jmp	$EX6514
$EX6514:
	pop	si
	pop	di
	leave	
	ret	4

?Show@screen@@QACXPBUHDC__@@@Z	ENDP
	PUBLIC	?Paint@screen@@QACXXZ	; screen::Paint
?Paint@screen@@QACXXZ	PROC NEAR	; screen::Paint COMDAT
; Line 306
	push	bp
	mov	bp,sp
	mov	ax,0
	call	__aNchkstk
	push	di
	push	si
	mov	si,WORD PTR [bp+4]	;this
;	register si = this
; Line 308
	push	0
	push	0
	push	0
	push	WORD PTR [si+10]
	push	WORD PTR [si+8]
	les	bx,DWORD PTR [si+8]
	mov	ax,WORD PTR es:[bx+32]
	shl	ax,2
	les	bx,DWORD PTR [si+8]
	add	ax,WORD PTR es:[bx]
	add	ax,WORD PTR [si+8]
	mov	dx,WORD PTR [si+10]
	push	dx
	push	ax
	push	0
	push	0
	push	WORD PTR [si+6]
	push	WORD PTR [si+4]
	lea	ax,WORD PTR [si+32]
	push	ds
	push	ax
	call	_CopyDIBits
	add	sp,26	;001aH
; Line 309
	jmp	$EX6517
$EX6517:
	pop	si
	pop	di
	leave	
	ret	2

?Paint@screen@@QACXXZ	ENDP
	PUBLIC	??1sprite@@QAC@XZ	; sprite::~sprite
??1sprite@@QAC@XZ	PROC NEAR	; sprite::~sprite COMDAT
; Line 597
	push	bp
	mov	bp,sp
	mov	ax,0
	call	__aNchkstk
	push	di
	push	si
	mov	si,WORD PTR [bp+4]	;this
;	register si = this
; Line 599
	jmp	$EX6746
$EX6746:
	pop	si
	pop	di
	leave	
	ret	2

??1sprite@@QAC@XZ	ENDP
	PUBLIC	?Sprite@object@@QACAAVsprite@@XZ	; object::Sprite
?Sprite@object@@QACAAVsprite@@XZ	PROC NEAR	; object::Sprite COMDAT
; Line 687
	push	bp
	mov	bp,sp
	mov	ax,0
	call	__aNchkstk
	push	di
	push	si
	mov	si,WORD PTR [bp+4]	;this
;	register si = this
; Line 688
	mov	ax,WORD PTR [si+20]
	mov	cx,ax
	shl	ax,2
	add	ax,cx
	shl	ax,1
	add	ax,WORD PTR [si+16]
	jmp	$EX6931
; Line 689
$EX6931:
	pop	si
	pop	di
	leave	
	ret	2

?Sprite@object@@QACAAVsprite@@XZ	ENDP
	PUBLIC	?FrameWidth@object@@QACHXZ	; object::FrameWidth
?FrameWidth@object@@QACHXZ	PROC NEAR	; object::FrameWidth COMDAT
; Line 709
	push	bp
	mov	bp,sp
	mov	ax,0
	call	__aNchkstk
	push	di
	push	si
	mov	si,WORD PTR [bp+4]	;this
;	register si = this
; Line 710
	push	si
	call	?Sprite@object@@QACAAVsprite@@XZ	; object::Sprite
	mov	bx,ax
	mov	ax,WORD PTR [bx]
	jmp	$EX6942
; Line 711
$EX6942:
	pop	si
	pop	di
	leave	
	ret	2

?FrameWidth@object@@QACHXZ	ENDP
	PUBLIC	?FrameHeight@object@@QACHXZ	; object::FrameHeight
?FrameHeight@object@@QACHXZ	PROC NEAR	; object::FrameHeight COMDAT
; Line 714
	push	bp
	mov	bp,sp
	mov	ax,0
	call	__aNchkstk
	push	di
	push	si
	mov	si,WORD PTR [bp+4]	;this
;	register si = this
; Line 715
	push	si
	call	?Sprite@object@@QACAAVsprite@@XZ	; object::Sprite
	mov	bx,ax
	mov	ax,WORD PTR [bx+2]
	jmp	$EX6945
; Line 717
$EX6945:
	pop	si
	pop	di
	leave	
	ret	2

?FrameHeight@object@@QACHXZ	ENDP
	PUBLIC	?SaveBackGround@object@@QACXPBUHDC__@@@Z	; object::SaveBackGround
?SaveBackGround@object@@QACXPBUHDC__@@@Z	PROC NEAR	; object::SaveBackGround COMDAT
; Line 735
	push	bp
	mov	bp,sp
	mov	ax,0
	call	__aNchkstk
	push	di
	push	si
	mov	si,WORD PTR [bp+4]	;this
;	register si = this
;	hBuffer = 6
; Line 737
	push	WORD PTR [si+24]
	push	0
	push	0
	push	si
	call	?FrameWidth@object@@QACHXZ	; object::FrameWidth
	push	ax
	push	si
	call	?FrameHeight@object@@QACHXZ	; object::FrameHeight
	push	ax
	push	WORD PTR [bp+6]	;hBuffer
	push	WORD PTR [si+8]
	push	WORD PTR [si+10]
	push	204	;00ccH
	push	32	;0020H
	call	FAR PTR BITBLT
; Line 738
	jmp	$EX6957
$EX6957:
	pop	si
	pop	di
	leave	
	ret	4

?SaveBackGround@object@@QACXPBUHDC__@@@Z	ENDP
	PUBLIC	?PutIntoBuffer@object@@QACXPEUtagBITMAPINFO@@PEX@Z	; object::PutIntoBuffer
?PutIntoBuffer@object@@QACXPEUtagBITMAPINFO@@PEX@Z	PROC NEAR	; object::PutIntoBuffer COMDAT
; Line 747
	push	bp
	mov	bp,sp
	mov	ax,0
	call	__aNchkstk
	push	di
	push	si
	mov	si,WORD PTR [bp+4]	;this
;	register si = this
;	pBufferHeader = 10
;	pBuffer = 6
; Line 758
	mov	al,BYTE PTR ?TransparentColor@@3EA	;TransparentColor
	push	ax
	push	0
	push	si
	call	?FrameHeight@object@@QACHXZ	; object::FrameHeight
	push	ax
	push	si
	call	?FrameWidth@object@@QACHXZ	; object::FrameWidth
	push	ax
	push	si
	call	?FrameY@object@@QACHXZ	; object::FrameY
	push	ax
	push	si
	call	?FrameX@object@@QACHXZ	; object::FrameX
	push	ax
	push	si
	call	?pBitMap@object@@QACPEUtagBITMAPINFOHEADER@@XZ	; object::pBitMap
	push	dx
	push	ax
	push	si
	call	?pBitMap@object@@QACPEUtagBITMAPINFOHEADER@@XZ	; object::pBitMap
	mov	es,dx
	mov	bx,ax
	mov	ax,WORD PTR es:[bx+32]
	shl	ax,2
	push	si
	mov	di,ax
	call	?pBitMap@object@@QACPEUtagBITMAPINFOHEADER@@XZ	; object::pBitMap
	mov	es,dx
	mov	bx,ax
	add	di,WORD PTR es:[bx]
	push	si
	call	?pBitMap@object@@QACPEUtagBITMAPINFOHEADER@@XZ	; object::pBitMap
	add	di,ax
	mov	cx,dx
	push	cx
	push	di
	push	WORD PTR [si+10]
	push	WORD PTR [si+8]
	push	WORD PTR [bp+8]
	push	WORD PTR [bp+6]	;pBuffer
	push	WORD PTR [bp+12]
	push	WORD PTR [bp+10]	;pBufferHeader
	call	_TranspDIBits
	add	sp,32	;0020H
; Line 759
	jmp	$EX6964
$EX6964:
	pop	si
	pop	di
	leave	
	ret	10	;000aH

?PutIntoBuffer@object@@QACXPEUtagBITMAPINFO@@PEX@Z	ENDP
	PUBLIC	?Show@object@@UACXPBUHDC__@@PAVscreen@@@Z	; object::Show
?Show@object@@UACXPBUHDC__@@PAVscreen@@@Z	PROC NEAR	; object::Show COMDAT
; Line 789
	push	bp
	mov	bp,sp
	mov	ax,0
	call	__aNchkstk
	push	di
	push	si
	mov	si,WORD PTR [bp+4]	;this
;	register si = this
;	hdc = 8
;	Screen = 6
; Line 792
	push	WORD PTR [bp+8]	;hdc
	mov	ax,WORD PTR [si+8]
	mov	bx,WORD PTR [bp+6]	;Screen
	sub	ax,WORD PTR [bx+16]
	push	ax
	mov	ax,WORD PTR [si+10]
	mov	bx,WORD PTR [bp+6]	;Screen
	sub	ax,WORD PTR [bx+18]
	push	ax
	push	si
	call	?FrameWidth@object@@QACHXZ	; object::FrameWidth
	push	ax
	push	si
	call	?FrameHeight@object@@QACHXZ	; object::FrameHeight
	push	ax
	mov	bx,WORD PTR [bp+6]	;Screen
	push	WORD PTR [bx+2]
	push	WORD PTR [si+8]
	push	WORD PTR [si+10]
	call	FAR PTR WINGBITBLT
; Line 793
	jmp	$EX6986
$EX6986:
	pop	si
	pop	di
	leave	
	ret	6

?Show@object@@UACXPBUHDC__@@PAVscreen@@@Z	ENDP
	PUBLIC	?pColorTable@object@@QACPEUtagRGBQUAD@@XZ	; object::pColorTable
?pColorTable@object@@QACPEUtagRGBQUAD@@XZ	PROC NEAR	; object::pColorTable COMDAT
; Line 797
	push	bp
	mov	bp,sp
	mov	ax,4
	call	__aNchkstk
	push	di
	push	si
	mov	si,WORD PTR [bp+4]	;this
;	register si = this
; Line 799
	push	si
	call	?pBitMap@object@@QACPEUtagBITMAPINFOHEADER@@XZ	; object::pBitMap
	mov	es,dx
	mov	bx,ax
	push	si
	mov	di,bx
	mov	WORD PTR [bp-4],di
	mov	WORD PTR [bp-2],es
	call	?pBitMap@object@@QACPEUtagBITMAPINFOHEADER@@XZ	; object::pBitMap
	les	bx,DWORD PTR [bp-4]
	add	ax,WORD PTR es:[bx]
	jmp	$EX6989
; Line 800
$EX6989:
	pop	si
	pop	di
	leave	
	ret	2

?pColorTable@object@@QACPEUtagRGBQUAD@@XZ	ENDP
	PUBLIC	?NextFrame@animated@@UACHXZ	; animated::NextFrame
?NextFrame@animated@@UACHXZ	PROC NEAR	; animated::NextFrame COMDAT
; Line 1210
	push	bp
	mov	bp,sp
	mov	ax,0
	call	__aNchkstk
	push	di
	push	si
	mov	si,WORD PTR [bp+4]	;this
;	register si = this
; Line 1211
	mov	bx,WORD PTR [si-8]
	mov	ax,WORD PTR [bx+2]
	add	ax,si
	sub	ax,8
	push	ax
	call	?Sprite@object@@QACAAVsprite@@XZ	; object::Sprite
	mov	bx,ax
	mov	di,WORD PTR [si-8]
	mov	ax,WORD PTR [bx+4]
	mov	bx,WORD PTR [di+2]
	sub	ax,WORD PTR [bx+14][si]
	neg	ax
	cmp	ax,-1	;ffffH
	je	$JCC48
	jmp	$I7246
$JCC48:
; Line 1212
; Line 1213
	mov	bx,WORD PTR [si-8]
	mov	bx,WORD PTR [bx+2]
	mov	WORD PTR [bx+14][si],0
; Line 1214
; Line 1215
	jmp	$I7247
$I7246:
; Line 1216
; Line 1217
	mov	bx,WORD PTR [si-8]
	mov	bx,WORD PTR [bx+2]
	inc	WORD PTR [bx+14][si]
; Line 1218
$I7247:
; Line 1220
	mov	bx,WORD PTR [si-8]
	mov	bx,WORD PTR [bx+2]
	mov	ax,WORD PTR [bx+14][si]
	jmp	$EX7245
; Line 1221
$EX7245:
	pop	si
	pop	di
	leave	
	ret	2

?NextFrame@animated@@UACHXZ	ENDP
	PUBLIC	?PreviousFrame@animated@@UACHXZ	; animated::PreviousFrame
?PreviousFrame@animated@@UACHXZ	PROC NEAR	; animated::PreviousFrame COMDAT
; Line 1224
	push	bp
	mov	bp,sp
	mov	ax,0
	call	__aNchkstk
	push	di
	push	si
	mov	si,WORD PTR [bp+4]	;this
;	register si = this
; Line 1225
	mov	bx,WORD PTR [si-8]
	mov	bx,WORD PTR [bx+2]
	cmp	WORD PTR [bx+14][si],0
	je	$JCC24
	jmp	$I7251
$JCC24:
; Line 1226
; Line 1227
	mov	bx,WORD PTR [si-8]
	mov	ax,WORD PTR [bx+2]
	add	ax,si
	sub	ax,8
	push	ax
	call	?Sprite@object@@QACAAVsprite@@XZ	; object::Sprite
	mov	bx,ax
	mov	ax,WORD PTR [bx+4]
	dec	ax
	mov	bx,WORD PTR [si-8]
	mov	bx,WORD PTR [bx+2]
	mov	WORD PTR [bx+14][si],ax
; Line 1228
; Line 1229
	jmp	$I7252
$I7251:
; Line 1230
; Line 1231
	mov	bx,WORD PTR [si-8]
	mov	bx,WORD PTR [bx+2]
	dec	WORD PTR [bx+14][si]
; Line 1232
$I7252:
; Line 1234
	mov	bx,WORD PTR [si-8]
	mov	bx,WORD PTR [bx+2]
	mov	ax,WORD PTR [bx+14][si]
	jmp	$EX7250
; Line 1235
$EX7250:
	pop	si
	pop	di
	leave	
	ret	2

?PreviousFrame@animated@@UACHXZ	ENDP
	PUBLIC	?Paint@moveable@@UACXHHPAVscreen@@@Z	; moveable::Paint
?Paint@moveable@@UACXHHPAVscreen@@@Z	PROC NEAR	; moveable::Paint COMDAT
; Line 1378
	push	bp
	mov	bp,sp
	mov	ax,0
	call	__aNchkstk
	push	di
	push	si
	mov	si,WORD PTR [bp+4]	;this
;	register si = this
;	_X = 10
;	_Y = 8
;	Screen = 6
; Line 1379
	mov	bx,WORD PTR [bp+6]	;Screen
	push	WORD PTR [bx+2]
	mov	bx,WORD PTR [si+2]
	mov	ax,WORD PTR [bx+2]
	add	ax,si
	add	ax,2
	push	ax
	call	?RestoreBackGround@object@@QACXPBUHDC__@@@Z	; object::RestoreBackGround
; Line 1381
	push	WORD PTR [bp+10]	;_X
	push	WORD PTR [bp+8]	;_Y
	push	si
	mov	bx,WORD PTR [si]
	call	WORD PTR [bx]
; Line 1383
	mov	bx,WORD PTR [bp+6]	;Screen
	push	WORD PTR [bx+2]
	mov	bx,WORD PTR [si+2]
	mov	ax,WORD PTR [bx+2]
	add	ax,si
	add	ax,2
	push	ax
	call	?SaveBackGround@object@@QACXPBUHDC__@@@Z	; object::SaveBackGround
; Line 1386
	mov	ax,WORD PTR [bp+6]	;Screen
	add	ax,32	;0020H
	push	ds
	push	ax
	mov	bx,WORD PTR [bp+6]	;Screen
	push	WORD PTR [bx+6]
	push	WORD PTR [bx+4]
	mov	bx,WORD PTR [si+2]
	mov	ax,WORD PTR [bx+2]
	add	ax,si
	add	ax,2
	push	ax
	call	?PutIntoBuffer@object@@QACXPEUtagBITMAPINFO@@PEX@Z	; object::PutIntoBuffer
; Line 1388
	jmp	$EX7415
$EX7415:
	pop	si
	pop	di
	leave	
	ret	8

?Paint@moveable@@UACXHHPAVscreen@@@Z	ENDP
	PUBLIC	?Show@moveable@@UACXPBUHDC__@@PAVscreen@@@Z	; moveable::Show
?Show@moveable@@UACXPBUHDC__@@PAVscreen@@@Z	PROC NEAR	; moveable::Show COMDAT
; Line 1391
	push	bp
	mov	bp,sp
	mov	ax,0
	call	__aNchkstk
	push	di
	push	si
	mov	si,WORD PTR [bp+4]	;this
;	register si = this
;	hdc = 8
;	Screen = 6
; Line 1394
	push	WORD PTR [bp+8]	;hdc
	mov	ax,WORD PTR [si-38]
	mov	bx,WORD PTR [bp+6]	;Screen
	sub	ax,WORD PTR [bx+16]
	push	ax
	mov	ax,WORD PTR [si-36]
	mov	bx,WORD PTR [bp+6]	;Screen
	sub	ax,WORD PTR [bx+18]
	push	ax
	mov	bx,WORD PTR [si-54]
	mov	ax,WORD PTR [bx+2]
	add	ax,si
	sub	ax,54	;0036H
	push	ax
	call	?FrameWidth@object@@QACHXZ	; object::FrameWidth
	push	ax
	mov	bx,WORD PTR [si-54]
	mov	ax,WORD PTR [bx+2]
	add	ax,si
	sub	ax,54	;0036H
	push	ax
	call	?FrameHeight@object@@QACHXZ	; object::FrameHeight
	push	ax
	mov	bx,WORD PTR [bp+6]	;Screen
	push	WORD PTR [bx+2]
	push	WORD PTR [si-38]
	push	WORD PTR [si-36]
	call	FAR PTR WINGBITBLT
; Line 1397
	push	WORD PTR [bp+8]	;hdc
	push	WORD PTR [bp+6]	;Screen
	mov	bx,WORD PTR [si-54]
	mov	ax,WORD PTR [bx+2]
	add	ax,si
	sub	ax,54	;0036H
	push	ax
	call	?Show@object@@UACXPBUHDC__@@PAVscreen@@@Z	; object::Show
; Line 1402
	jmp	$EX7420
$EX7420:
	pop	si
	pop	di
	leave	
	ret	6

?Show@moveable@@UACXPBUHDC__@@PAVscreen@@@Z	ENDP
	PUBLIC	?OccupScreen@player@@UACXPAVscreen@@@Z	; player::OccupScreen
?OccupScreen@player@@UACXPAVscreen@@@Z	PROC NEAR	; player::OccupScreen COMDAT
; Line 1567
	push	bp
	mov	bp,sp
	mov	ax,0
	call	__aNchkstk
	push	di
	push	si
	mov	si,WORD PTR [bp+4]	;this
;	register si = this
;	Screen = 6
; Line 1569
	jmp	$EX7612
$EX7612:
	pop	si
	pop	di
	leave	
	ret	4

?OccupScreen@player@@UACXPAVscreen@@@Z	ENDP
	PUBLIC	?Paint@_3D_moveable@@UACXHHPAV_3D_screen@@@Z	; _3D_moveable::Paint
?Paint@_3D_moveable@@UACXHHPAV_3D_screen@@@Z	PROC NEAR	; _3D_moveable::Paint COMDAT
; Line 1759
	push	bp
	mov	bp,sp
	mov	ax,0
	call	__aNchkstk
	push	di
	push	si
	mov	si,WORD PTR [bp+4]	;this
;	register si = this
;	_X = 10
;	_Y = 8
;	Screen = 6
; Line 1760
	mov	bx,WORD PTR [bp+6]	;Screen
	push	WORD PTR [bx+2]
	mov	bx,WORD PTR [si+2]
	mov	ax,WORD PTR [bx+2]
	add	ax,si
	add	ax,2
	push	ax
	call	?RestoreBackGround@object@@QACXPBUHDC__@@@Z	; object::RestoreBackGround
; Line 1762
	push	WORD PTR [bp+10]	;_X
	push	WORD PTR [bp+8]	;_Y
	push	WORD PTR [bp+6]	;Screen
	push	si
	mov	bx,WORD PTR [si]
	call	WORD PTR [bx+26]
; Line 1764
	mov	bx,WORD PTR [bp+6]	;Screen
	push	WORD PTR [bx+2]
	mov	bx,WORD PTR [si+2]
	mov	ax,WORD PTR [bx+2]
	add	ax,si
	add	ax,2
	push	ax
	call	?SaveBackGround@object@@QACXPBUHDC__@@@Z	; object::SaveBackGround
; Line 1767
	mov	ax,WORD PTR [bp+6]	;Screen
	add	ax,32	;0020H
	push	ds
	push	ax
	mov	bx,WORD PTR [bp+6]	;Screen
	push	WORD PTR [bx+6]
	push	WORD PTR [bx+4]
	mov	bx,WORD PTR [si+2]
	mov	ax,WORD PTR [bx+2]
	add	ax,si
	add	ax,2
	push	ax
	call	?PutIntoBuffer@object@@QACXPEUtagBITMAPINFO@@PEX@Z	; object::PutIntoBuffer
; Line 1769
	jmp	$EX7899
$EX7899:
	pop	si
	pop	di
	leave	
	ret	8

?Paint@_3D_moveable@@UACXHHPAV_3D_screen@@@Z	ENDP
	PUBLIC	?Show@_3D_moveable@@UACXPBUHDC__@@PAVscreen@@@Z	; _3D_moveable::Show
?Show@_3D_moveable@@UACXPBUHDC__@@PAVscreen@@@Z	PROC NEAR	; _3D_moveable::Show COMDAT
; Line 1772
	push	bp
	mov	bp,sp
	mov	ax,50	;0032H
	call	__aNchkstk
	push	di
	push	si
	mov	si,WORD PTR [bp+4]	;this
;	Buff = -50
;	register si = this
;	hdc = 8
;	Screen = 6
; Line 1774
	push	WORD PTR [bp+8]	;hdc
	push	WORD PTR [bp+6]	;Screen
	push	si
	call	?Show@moveable@@UACXPBUHDC__@@PAVscreen@@@Z	; moveable::Show
; Line 1779
	mov	bx,WORD PTR [si-54]
	mov	bx,WORD PTR [bx+4]
	push	WORD PTR [bx-46][si]
	mov	bx,WORD PTR [si-54]
	mov	bx,WORD PTR [bx+4]
	push	WORD PTR [bx-48][si]
	mov	bx,WORD PTR [si-54]
	mov	bx,WORD PTR [bx+4]
	push	WORD PTR [bx-50][si]
	mov	bx,WORD PTR [bp+6]	;Screen
	mov	ax,WORD PTR [bx+22]
	mov	bx,WORD PTR [si-54]
	mov	bx,WORD PTR [bx+2]
	sub	ax,WORD PTR [bx-44][si]
	mov	bx,WORD PTR [si-54]
	mov	bx,WORD PTR [bx+4]
	sub	ax,WORD PTR [bx-36][si]
	push	ax
	mov	bx,WORD PTR [si-54]
	mov	bx,WORD PTR [bx+4]
	mov	ax,WORD PTR [bx-38][si]
	mov	bx,WORD PTR [si-54]
	mov	bx,WORD PTR [bx+2]
	add	ax,WORD PTR [bx-46][si]
	push	ax
	push	OFFSET DGROUP:??_C@_0BO@GBKI@?$CI?$CF03d?0?$CF03d?$CJ?$DN?$DO?$CI?$CF03d?0?$CF03d?0?$CF03d?$CJ?$AA@
	lea	ax,WORD PTR [bp-50]	;Buff
	push	ax
	call	_sprintf
	add	sp,14	;000eH
; Line 1780
	push	WORD PTR [bp+8]	;hdc
	push	400	;0190H
	push	10	;000aH
	lea	ax,WORD PTR [bp-50]	;Buff
	push	ss
	push	ax
	push	ax
	call	_strlen
	add	sp,2
	push	ax
	call	FAR PTR TEXTOUT
; Line 1782
	jmp	$EX7904
$EX7904:
	pop	si
	pop	di
	leave	
	ret	6

?Show@_3D_moveable@@UACXPBUHDC__@@PAVscreen@@@Z	ENDP
	PUBLIC	?OccupScreen@_3D_player@@UACXPAVscreen@@@Z	; _3D_player::OccupScreen
?OccupScreen@_3D_player@@UACXPAVscreen@@@Z	PROC NEAR	; _3D_player::OccupScreen COMDAT
; Line 1864
	push	bp
	mov	bp,sp
	mov	ax,0
	call	__aNchkstk
	push	di
	push	si
	mov	si,WORD PTR [bp+4]	;this
;	register si = this
;	Screen = 6
; Line 1866
	jmp	$EX8051
$EX8051:
	pop	si
	pop	di
	leave	
	ret	4

?OccupScreen@_3D_player@@UACXPAVscreen@@@Z	ENDP
	PUBLIC	?pBitMap@object@@QACPEUtagBITMAPINFOHEADER@@XZ	; object::pBitMap
?pBitMap@object@@QACPEUtagBITMAPINFOHEADER@@XZ	PROC NEAR	; object::pBitMap COMDAT
; Line 698
	push	bp
	mov	bp,sp
	mov	ax,0
	call	__aNchkstk
	push	di
	push	si
	mov	si,WORD PTR [bp+4]	;this
;	register si = this
; Line 699
	push	si
	call	?Sprite@object@@QACAAVsprite@@XZ	; object::Sprite
	mov	bx,ax
	mov	ax,WORD PTR [bx+6]
	mov	dx,WORD PTR [bx+8]
	jmp	$EX6939
; Line 700
$EX6939:
	pop	si
	pop	di
	leave	
	ret	2

?pBitMap@object@@QACPEUtagBITMAPINFOHEADER@@XZ	ENDP
	PUBLIC	?FrameX@object@@QACHXZ	; object::FrameX
?FrameX@object@@QACHXZ	PROC NEAR	; object::FrameX COMDAT
; Line 720
	push	bp
	mov	bp,sp
	mov	ax,0
	call	__aNchkstk
	push	di
	push	si
	mov	si,WORD PTR [bp+4]	;this
;	register si = this
; Line 721
	push	WORD PTR [si+22]
	push	si
	call	?Sprite@object@@QACAAVsprite@@XZ	; object::Sprite
	push	ax
	call	?FrameX@sprite@@QACHH@Z	; sprite::FrameX
	jmp	$EX6948
; Line 722
$EX6948:
	pop	si
	pop	di
	leave	
	ret	2

?FrameX@object@@QACHXZ	ENDP
	PUBLIC	?FrameY@object@@QACHXZ	; object::FrameY
?FrameY@object@@QACHXZ	PROC NEAR	; object::FrameY COMDAT
; Line 725
	push	bp
	mov	bp,sp
	mov	ax,0
	call	__aNchkstk
	push	di
	push	si
	mov	si,WORD PTR [bp+4]	;this
;	register si = this
; Line 726
	push	WORD PTR [si+22]
	push	si
	call	?Sprite@object@@QACAAVsprite@@XZ	; object::Sprite
	push	ax
	call	?FrameY@sprite@@QACHH@Z	; sprite::FrameY
	jmp	$EX6951
; Line 727
$EX6951:
	pop	si
	pop	di
	leave	
	ret	2

?FrameY@object@@QACHXZ	ENDP
	PUBLIC	?RestoreBackGround@object@@QACXPBUHDC__@@@Z	; object::RestoreBackGround
?RestoreBackGround@object@@QACXPBUHDC__@@@Z	PROC NEAR	; object::RestoreBackGround COMDAT
; Line 741
	push	bp
	mov	bp,sp
	mov	ax,0
	call	__aNchkstk
	push	di
	push	si
	mov	si,WORD PTR [bp+4]	;this
;	register si = this
;	hBuffer = 6
; Line 743
	push	WORD PTR [bp+6]	;hBuffer
	push	WORD PTR [si+8]
	push	WORD PTR [si+10]
	push	si
	call	?FrameWidth@object@@QACHXZ	; object::FrameWidth
	push	ax
	push	si
	call	?FrameHeight@object@@QACHXZ	; object::FrameHeight
	push	ax
	push	WORD PTR [si+24]
	push	0
	push	0
	push	204	;00ccH
	push	32	;0020H
	call	FAR PTR BITBLT
; Line 744
	jmp	$EX6960
$EX6960:
	pop	si
	pop	di
	leave	
	ret	4

?RestoreBackGround@object@@QACXPBUHDC__@@@Z	ENDP
	PUBLIC	?FrameX@sprite@@QACHH@Z	; sprite::FrameX
?FrameX@sprite@@QACHH@Z	PROC NEAR	; sprite::FrameX COMDAT
; Line 608
	push	bp
	mov	bp,sp
	mov	ax,0
	call	__aNchkstk
	push	di
	push	si
	mov	si,WORD PTR [bp+4]	;this
;	register si = this
;	FrameNumber = 6
; Line 609
	mov	ax,0
	jmp	$EX6749
; Line 610
$EX6749:
	pop	si
	pop	di
	leave	
	ret	4

?FrameX@sprite@@QACHH@Z	ENDP
	PUBLIC	?FrameY@sprite@@QACHH@Z	; sprite::FrameY
?FrameY@sprite@@QACHH@Z	PROC NEAR	; sprite::FrameY COMDAT
; Line 613
	push	bp
	mov	bp,sp
	mov	ax,0
	call	__aNchkstk
	push	di
	push	si
	mov	si,WORD PTR [bp+4]	;this
;	register si = this
;	FrameNumber = 6
; Line 614
	mov	ax,WORD PTR [si+2]
	imul	WORD PTR [bp+6]	;FrameNumber
	jmp	$EX6752
; Line 615
$EX6752:
	pop	si
	pop	di
	leave	
	ret	4

?FrameY@sprite@@QACHH@Z	ENDP
_TEXT	ENDS
END
