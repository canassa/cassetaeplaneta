;	Static Name Aliases
;
	TITLE   d:\lc\demo\utils.cpp
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
EXTRN	__AHSHIFT:NEAR
EXTRN	OPENFILE:FAR
EXTRN	FINDRESOURCE:FAR
EXTRN	_LCLOSE:FAR
EXTRN	GLOBALALLOC:FAR
EXTRN	_LLSEEK:FAR
EXTRN	GLOBALREALLOC:FAR
EXTRN	HMEMCPY:FAR
EXTRN	GLOBALFREE:FAR
EXTRN	_LREAD:FAR
EXTRN	ACCESSRESOURCE:FAR
EXTRN	GLOBALLOCK:FAR
EXTRN	GLOBALUNLOCK:FAR
EXTRN	_HREAD:FAR
EXTRN	GLOBALHANDLE:FAR
EXTRN	CREATEPALETTE:FAR
EXTRN	SELECTPALETTE:FAR
EXTRN	REALIZEPALETTE:FAR
EXTRN	GETDC:FAR
EXTRN	__aNchkstk:NEAR
EXTRN	RELEASEDC:FAR
EXTRN	GETSTOCKOBJECT:FAR
EXTRN	DELETEOBJECT:FAR
EXTRN	GETPALETTEENTRIES:FAR
EXTRN	__AHINCR:NEAR
EXTRN	GETOBJECT:FAR
EXTRN	GETNEARESTPALETTEINDEX:FAR
_TEXT      SEGMENT
	ASSUME	CS: _TEXT
	PUBLIC	_ClearSystemPalette
_ClearSystemPalette	PROC NEAR
; Line 51
	push	bp
	mov	bp,sp
	mov	ax,1040	;0410H
	call	__aNchkstk
	push	di
	push	si
;	Palette = -1028
;	ScreenPalette = -1030
;	ScreenDC = -1032
;	Counter = -1034
;	nMapped = -1036
;	bOK = -1038
;	nOK = -1040
; Line 60
	mov	WORD PTR [bp-1028],768	;0300H	;Palette
; Line 62
	mov	WORD PTR [bp-1026],256	;0100H
	mov	ax,0
	mov	cx,512	;0200H
	lea	di,WORD PTR [bp-1024]
	push	ss
	pop	es
	rep	stosw
; Line 64
	mov	WORD PTR [bp-1030],0	;ScreenPalette
; Line 67
	mov	WORD PTR [bp-1036],0	;nMapped
; Line 68
	mov	WORD PTR [bp-1038],0	;bOK
; Line 69
	mov	WORD PTR [bp-1040],0	;nOK
; Line 72
	mov	WORD PTR [bp-1034],0	;Counter
	jmp	$F4154
$FC4155:
	inc	WORD PTR [bp-1034]	;Counter
$F4154:
	cmp	WORD PTR [bp-1034],256	;0100H	;Counter
	jl	$JCC80
	jmp	$FB4156
$JCC80:
; Line 73
; Line 74
	mov	si,WORD PTR [bp-1034]	;Counter
	shl	si,2
	mov	BYTE PTR [bp-1024][si],0
; Line 75
	mov	si,WORD PTR [bp-1034]	;Counter
	shl	si,2
	mov	BYTE PTR [bp-1023][si],0
; Line 76
	mov	si,WORD PTR [bp-1034]	;Counter
	shl	si,2
	mov	BYTE PTR [bp-1022][si],0
; Line 77
	mov	si,WORD PTR [bp-1034]	;Counter
	shl	si,2
	mov	BYTE PTR [bp-1021][si],4
; Line 78
	jmp	$FC4155
$FB4156:
; Line 81
	push	0
	call	FAR PTR GETDC
	mov	WORD PTR [bp-1032],ax	;ScreenDC
; Line 82
	lea	ax,WORD PTR [bp-1028]	;Palette
	push	ss
	push	ax
	call	FAR PTR CREATEPALETTE
	mov	WORD PTR [bp-1030],ax	;ScreenPalette
; Line 84
	cmp	WORD PTR [bp-1030],0	;ScreenPalette
	jne	$JCC167
	jmp	$I4158
$JCC167:
; Line 85
; Line 86
	push	WORD PTR [bp-1032]	;ScreenDC
	push	WORD PTR [bp-1030]	;ScreenPalette
	push	0
	call	FAR PTR SELECTPALETTE
	mov	WORD PTR [bp-1030],ax	;ScreenPalette
; Line 87
	push	WORD PTR [bp-1032]	;ScreenDC
	call	FAR PTR REALIZEPALETTE
	mov	WORD PTR [bp-1036],ax	;nMapped
; Line 88
	push	WORD PTR [bp-1032]	;ScreenDC
	push	WORD PTR [bp-1030]	;ScreenPalette
	push	0
	call	FAR PTR SELECTPALETTE
	mov	WORD PTR [bp-1030],ax	;ScreenPalette
; Line 89
	push	WORD PTR [bp-1030]	;ScreenPalette
	call	FAR PTR DELETEOBJECT
	mov	WORD PTR [bp-1038],ax	;bOK
; Line 90
; Line 92
$I4158:
	push	0
	push	WORD PTR [bp-1032]	;ScreenDC
	call	FAR PTR RELEASEDC
	mov	WORD PTR [bp-1040],ax	;nOK
; Line 94
	jmp	$EX4133
; Line 95
	jmp	$EX4133
$EX4133:
	pop	si
	pop	di
	leave	
	ret	

_ClearSystemPalette	ENDP
	PUBLIC	_DibOpenFile
_DibOpenFile	PROC NEAR
; Line 107
	push	bp
	mov	bp,sp
	mov	ax,156	;009cH
	call	__aNchkstk
	push	di
	push	si
;	fh = -2
;	dwLen = -6
;	dwBits = -10
;	pdib = -14
;	p = -18
;	of = -154
;	szFile = 4
; Line 121
	push	WORD PTR [bp+6]
	push	WORD PTR [bp+4]	;szFile
	lea	ax,WORD PTR [bp-154]	;of
	push	ss
	push	ax
	push	0
	call	FAR PTR OPENFILE
	mov	WORD PTR [bp-2],ax	;fh
; Line 123
	cmp	WORD PTR [bp-2],-1	;ffffH	;fh
	je	$JCC298
	jmp	$I4167
$JCC298:
; Line 124
;	h = -156
; Line 127
	push	ss
	push	WORD PTR [bp+6]
	push	WORD PTR [bp+4]	;szFile
	push	0
	push	2
	call	FAR PTR FINDRESOURCE
	mov	WORD PTR [bp-156],ax	;h
; Line 135
	cmp	WORD PTR [bp-156],0	;h
	jne	$JCC328
	jmp	$I4179
$JCC328:
; Line 136
	push	ss
	push	WORD PTR [bp-156]	;h
	call	FAR PTR ACCESSRESOURCE
	mov	WORD PTR [bp-2],ax	;fh
; Line 138
$I4179:
; Line 140
$I4167:
	cmp	WORD PTR [bp-2],-1	;ffffH	;fh
	je	$JCC350
	jmp	$I4184
$JCC350:
; Line 141
	mov	ax,0
	mov	dx,0
	jmp	$EX4160
; Line 143
$I4184:
	push	WORD PTR [bp-2]	;fh
	call	_DibReadBitmapInfo
	add	sp,2
	mov	WORD PTR [bp-14],ax	;pdib
	mov	WORD PTR [bp-12],dx
; Line 145
	mov	ax,WORD PTR [bp-12]
	or	ax,WORD PTR [bp-14]	;pdib
	je	$JCC385
	jmp	$I4185
$JCC385:
; Line 146
	mov	ax,0
	mov	dx,0
	jmp	$EX4160
; Line 150
$I4185:
	les	bx,DWORD PTR [bp-14]	;pdib
	mov	ax,WORD PTR es:[bx+20]
	mov	dx,WORD PTR es:[bx+22]
	mov	WORD PTR [bp-10],ax	;dwBits
	mov	WORD PTR [bp-8],dx
; Line 151
	les	bx,DWORD PTR [bp-14]	;pdib
	mov	ax,WORD PTR es:[bx+34]
	or	ax,WORD PTR es:[bx+32]
	je	$JCC427
	jmp	$L4526
$JCC427:
	les	bx,DWORD PTR [bp-14]	;pdib
	cmp	WORD PTR es:[bx+14],8
	jbe	$JCC440
	jmp	$L4526
$JCC440:
	les	bx,DWORD PTR [bp-14]	;pdib
	mov	cl,BYTE PTR es:[bx+14]
	mov	ax,1
	shl	ax,cl
	mov	WORD PTR [bp-156],ax	;h
	jmp	$L4527
$L4526:
	les	bx,DWORD PTR [bp-14]	;pdib
	mov	ax,WORD PTR es:[bx+32]
	mov	WORD PTR [bp-156],ax	;h
$L4527:
	mov	ax,WORD PTR [bp-156]	;h
	shl	ax,2
	sub	dx,dx
	les	bx,DWORD PTR [bp-14]	;pdib
	add	ax,WORD PTR es:[bx]
	adc	dx,WORD PTR es:[bx+2]
	add	ax,WORD PTR [bp-10]	;dwBits
	adc	dx,WORD PTR [bp-8]
	mov	WORD PTR [bp-6],ax	;dwLen
	mov	WORD PTR [bp-4],dx
; Line 155
	push	WORD PTR [bp-12]
	call	FAR PTR GLOBALHANDLE
	push	ax
	call	FAR PTR GLOBALUNLOCK
	push	WORD PTR [bp-12]
	call	FAR PTR GLOBALHANDLE
	push	ax
	push	WORD PTR [bp-4]
	push	WORD PTR [bp-6]	;dwLen
	push	0
	call	FAR PTR GLOBALREALLOC
	push	ax
	call	FAR PTR GLOBALLOCK
	mov	WORD PTR [bp-18],ax	;p
	mov	WORD PTR [bp-16],dx
; Line 157
	mov	ax,WORD PTR [bp-16]
	or	ax,WORD PTR [bp-18]	;p
	je	$JCC560
	jmp	$I4200
$JCC560:
; Line 158
; Line 159
	push	WORD PTR [bp-12]
	call	FAR PTR GLOBALHANDLE
	push	ax
	call	FAR PTR GLOBALUNLOCK
	push	WORD PTR [bp-12]
	call	FAR PTR GLOBALHANDLE
	push	ax
	call	FAR PTR GLOBALFREE
; Line 160
	sub	ax,ax
	mov	WORD PTR [bp-12],ax
	mov	WORD PTR [bp-14],ax	;pdib
; Line 161
; Line 162
	jmp	$I4212
$I4200:
; Line 163
; Line 164
	mov	ax,WORD PTR [bp-18]	;p
	mov	dx,WORD PTR [bp-16]
	mov	WORD PTR [bp-14],ax	;pdib
	mov	WORD PTR [bp-12],dx
; Line 165
$I4212:
; Line 167
	mov	ax,WORD PTR [bp-12]
	or	ax,WORD PTR [bp-14]	;pdib
	jne	$JCC622
	jmp	$I4214
$JCC622:
; Line 168
; Line 170
	les	bx,DWORD PTR [bp-14]	;pdib
	mov	ax,WORD PTR es:[bx+34]
	or	ax,WORD PTR es:[bx+32]
	je	$JCC638
	jmp	$L4528
$JCC638:
	les	bx,DWORD PTR [bp-14]	;pdib
	cmp	WORD PTR es:[bx+14],8
	jbe	$JCC651
	jmp	$L4528
$JCC651:
	les	bx,DWORD PTR [bp-14]	;pdib
	mov	cl,BYTE PTR es:[bx+14]
	mov	ax,1
	shl	ax,cl
	mov	WORD PTR [bp-156],ax	;h
	jmp	$L4529
$L4528:
	les	bx,DWORD PTR [bp-14]	;pdib
	mov	ax,WORD PTR es:[bx+32]
	mov	WORD PTR [bp-156],ax	;h
$L4529:
	push	WORD PTR [bp-2]	;fh
	les	bx,DWORD PTR [bp-14]	;pdib
	mov	ax,WORD PTR [bp-156]	;h
	shl	ax,2
	add	ax,WORD PTR es:[bx]
	add	ax,WORD PTR [bp-14]	;pdib
	mov	dx,WORD PTR [bp-12]
	push	dx
	push	ax
	push	WORD PTR [bp-8]
	push	WORD PTR [bp-10]	;dwBits
	call	FAR PTR _HREAD
; Line 171
; Line 173
$I4214:
	push	WORD PTR [bp-2]	;fh
	call	FAR PTR _LCLOSE
; Line 175
	mov	ax,WORD PTR [bp-14]	;pdib
	mov	dx,WORD PTR [bp-12]
	jmp	$EX4160
; Line 176
$EX4160:
	pop	si
	pop	di
	leave	
	ret	

_DibOpenFile	ENDP
	PUBLIC	_DibReadBitmapInfo
_DibReadBitmapInfo	PROC NEAR
; Line 188
	push	bp
	mov	bp,sp
	mov	ax,92	;005cH
	call	__aNchkstk
	push	di
	push	si
;	hbi = -6
;	size = -8
;	i = -10
;	nNumColors = -12
;	pRgb = -16
;	bi = -56
;	bc = -68
;	bf = -82
;	pdib = -86
;	off = -4
;	fh = 4
; Line 190
	mov	WORD PTR [bp-6],0	;hbi
; Line 201
	cmp	WORD PTR [bp+4],-1	;ffffH	;fh
	je	$JCC762
	jmp	$I4233
$JCC762:
; Line 202
	mov	ax,0
	mov	dx,0
	jmp	$EX4222
; Line 204
$I4233:
	push	WORD PTR [bp+4]	;fh
	push	0
	push	0
	push	1
	call	FAR PTR _LLSEEK
	mov	WORD PTR [bp-4],ax	;off
	mov	WORD PTR [bp-2],dx
; Line 206
	push	WORD PTR [bp+4]	;fh
	lea	ax,WORD PTR [bp-82]	;bf
	push	ss
	push	ax
	push	14	;000eH
	call	FAR PTR _LREAD
	cmp	ax,14	;000eH
	jne	$JCC814
	jmp	$I4235
$JCC814:
; Line 207
	mov	ax,0
	mov	dx,0
	jmp	$EX4222
; Line 212
$I4235:
	cmp	WORD PTR [bp-82],19778	;4d42H	;bf
	jne	$JCC833
	jmp	$I4236
$JCC833:
; Line 213
; Line 214
	sub	ax,ax
	mov	WORD PTR [bp-70],ax
	mov	WORD PTR [bp-72],ax
; Line 215
	push	WORD PTR [bp+4]	;fh
	push	WORD PTR [bp-2]
	push	WORD PTR [bp-4]	;off
	push	0
	call	FAR PTR _LLSEEK
; Line 216
; Line 218
$I4236:
	push	WORD PTR [bp+4]	;fh
	lea	ax,WORD PTR [bp-56]	;bi
	push	ss
	push	ax
	push	40	;0028H
	call	FAR PTR _LREAD
	cmp	ax,40	;0028H
	jne	$JCC880
	jmp	$I4238
$JCC880:
; Line 219
	mov	ax,0
	mov	dx,0
	jmp	$EX4222
; Line 224
$I4238:
	mov	ax,WORD PTR [bp-56]	;bi
	mov	WORD PTR [bp-8],ax	;size
	jmp	$S4240
; Line 225
; Line 226
$SD4244:
; Line 228
	jmp	$SB4241
; Line 230
$SC4247:
; Line 231
	lea	di,WORD PTR [bp-68]	;bc
	lea	si,WORD PTR [bp-56]	;bi
	mov	ax,ss
	mov	es,ax
	mov	cx,6
	rep	movsw
; Line 232
	mov	WORD PTR [bp-56],40	;0028H	;bi
	mov	WORD PTR [bp-54],0
; Line 233
	mov	ax,WORD PTR [bp-64]
	cwd	
	mov	WORD PTR [bp-52],ax
	mov	WORD PTR [bp-50],dx
; Line 234
	mov	ax,WORD PTR [bp-62]
	cwd	
	mov	WORD PTR [bp-48],ax
	mov	WORD PTR [bp-46],dx
; Line 235
	mov	ax,WORD PTR [bp-60]
	mov	WORD PTR [bp-44],ax
; Line 236
	mov	ax,WORD PTR [bp-58]
	mov	WORD PTR [bp-42],ax
; Line 237
	sub	ax,ax
	mov	WORD PTR [bp-38],ax
	mov	WORD PTR [bp-40],ax
; Line 238
	sub	ax,ax
	mov	WORD PTR [bp-34],ax
	mov	WORD PTR [bp-36],ax
; Line 239
	sub	ax,ax
	mov	WORD PTR [bp-30],ax
	mov	WORD PTR [bp-32],ax
; Line 240
	sub	ax,ax
	mov	WORD PTR [bp-26],ax
	mov	WORD PTR [bp-28],ax
; Line 241
	sub	ax,ax
	mov	WORD PTR [bp-22],ax
	mov	WORD PTR [bp-24],ax
; Line 242
	sub	ax,ax
	mov	WORD PTR [bp-18],ax
	mov	WORD PTR [bp-20],ax
; Line 244
	push	WORD PTR [bp+4]	;fh
	push	-1	;ffffH
	push	-28	;ffe4H
	push	1
	call	FAR PTR _LLSEEK
; Line 246
	jmp	$SB4241
; Line 247
	jmp	$SB4241
$S4240:
	sub	ax,12	;000cH
	jne	$JCC1034
	jmp	$SC4247
$JCC1034:
	jmp	$SD4244
$SB4241:
; Line 249
	mov	ax,WORD PTR [bp-22]
	or	ax,WORD PTR [bp-24]
	je	$JCC1048
	jmp	$L4530
$JCC1048:
	cmp	WORD PTR [bp-42],8
	jbe	$JCC1057
	jmp	$L4530
$JCC1057:
	mov	cl,BYTE PTR [bp-42]
	mov	ax,1
	shl	ax,cl
	mov	WORD PTR [bp-12],ax	;nNumColors
	jmp	$L4531
$L4530:
	mov	ax,WORD PTR [bp-24]
	mov	WORD PTR [bp-12],ax	;nNumColors
$L4531:
; Line 258
	mov	ax,WORD PTR [bp-34]
	or	ax,WORD PTR [bp-36]
	je	$JCC1088
	jmp	$I4260
$JCC1088:
	mov	ax,WORD PTR [bp-34]
	or	ax,WORD PTR [bp-36]
	je	$JCC1099
	jmp	$L4532
$JCC1099:
	mov	ax,WORD PTR [bp-52]
	mul	WORD PTR [bp-42]
	add	ax,31	;001fH
	and	ax,-25	;ffe7H
	shr	ax,3
	mul	WORD PTR [bp-48]
	mov	WORD PTR [bp-36],ax
	mov	WORD PTR [bp-34],dx
	jmp	$L4533
$L4532:
$L4533:
$I4260:
	mov	ax,WORD PTR [bp-22]
	or	ax,WORD PTR [bp-24]
	je	$JCC1137
	jmp	$I4269
$JCC1137:
	mov	ax,WORD PTR [bp-22]
	or	ax,WORD PTR [bp-24]
	je	$JCC1148
	jmp	$L4534
$JCC1148:
	cmp	WORD PTR [bp-42],8
	jbe	$JCC1157
	jmp	$L4534
$JCC1157:
	mov	cl,BYTE PTR [bp-42]
	mov	ax,1
	shl	ax,cl
	mov	WORD PTR [bp-88],ax
	jmp	$L4535
$L4534:
	mov	ax,WORD PTR [bp-24]
	mov	WORD PTR [bp-88],ax
$L4535:
	mov	ax,WORD PTR [bp-88]
	cwd	
	mov	WORD PTR [bp-24],ax
	mov	WORD PTR [bp-22],dx
$I4269:
	cmp	WORD PTR [bp-40],3
	je	$JCC1196
	jmp	$I4273
$JCC1196:
	cmp	WORD PTR [bp-38],0
	je	$JCC1205
	jmp	$I4273
$JCC1205:
	mov	ax,WORD PTR [bp-22]
	or	ax,WORD PTR [bp-24]
	je	$JCC1216
	jmp	$I4273
$JCC1216:
$I4273:
; Line 261
	push	2
	mov	ax,WORD PTR [bp-12]	;nNumColors
	shl	ax,2
	sub	dx,dx
	add	ax,WORD PTR [bp-56]	;bi
	adc	dx,WORD PTR [bp-54]
	push	dx
	push	ax
	call	FAR PTR GLOBALALLOC
	push	ax
	call	FAR PTR GLOBALLOCK
	mov	WORD PTR [bp-86],ax	;pdib
	mov	WORD PTR [bp-84],dx
; Line 263
	mov	ax,WORD PTR [bp-84]
	or	ax,WORD PTR [bp-86]	;pdib
	je	$JCC1262
	jmp	$I4277
$JCC1262:
; Line 264
	mov	ax,0
	mov	dx,0
	jmp	$EX4222
; Line 266
$I4277:
	lea	si,WORD PTR [bp-56]	;bi
	les	di,DWORD PTR [bp-86]	;pdib
	mov	cx,20	;0014H
	rep	movsw
; Line 268
	les	bx,DWORD PTR [bp-86]	;pdib
	mov	ax,WORD PTR es:[bx]
	add	ax,WORD PTR [bp-86]	;pdib
	mov	dx,WORD PTR [bp-84]
	mov	WORD PTR [bp-16],ax	;pRgb
	mov	WORD PTR [bp-14],dx
; Line 270
	cmp	WORD PTR [bp-12],0	;nNumColors
	jne	$JCC1309
	jmp	$I4281
$JCC1309:
; Line 271
; Line 272
	cmp	WORD PTR [bp-8],12	;000cH	;size
	je	$JCC1318
	jmp	$I4283
$JCC1318:
; Line 273
; Line 278
	push	WORD PTR [bp+4]	;fh
	push	WORD PTR [bp-14]
	push	WORD PTR [bp-16]	;pRgb
	mov	ax,WORD PTR [bp-12]	;nNumColors
	mov	cx,ax
	shl	ax,1
	add	ax,cx
	push	ax
	call	FAR PTR _LREAD
; Line 280
	mov	ax,WORD PTR [bp-12]	;nNumColors
	dec	ax
	mov	WORD PTR [bp-10],ax	;i
	jmp	$F4286
$FC4287:
	dec	WORD PTR [bp-10]	;i
$F4286:
	cmp	WORD PTR [bp-10],0	;i
	jge	$JCC1364
	jmp	$FB4288
$JCC1364:
; Line 281
;	rgb = -92
; Line 284
	mov	si,WORD PTR [bp-10]	;i
	mov	ax,si
	shl	si,1
	add	si,ax
	les	bx,DWORD PTR [bp-16]	;pRgb
	mov	al,BYTE PTR es:[bx+2][si]
	mov	BYTE PTR [bp-90],al
; Line 285
	mov	bx,WORD PTR [bp-10]	;i
	mov	ax,bx
	shl	bx,1
	add	bx,ax
	les	si,DWORD PTR [bp-16]	;pRgb
	mov	al,BYTE PTR es:[bx][si]
	mov	BYTE PTR [bp-92],al	;rgb
; Line 286
	mov	si,WORD PTR [bp-10]	;i
	mov	ax,si
	shl	si,1
	add	si,ax
	les	bx,DWORD PTR [bp-16]	;pRgb
	mov	al,BYTE PTR es:[bx+1][si]
	mov	BYTE PTR [bp-91],al
; Line 287
	mov	BYTE PTR [bp-89],0
; Line 289
	mov	bx,WORD PTR [bp-10]	;i
	shl	bx,2
	les	si,DWORD PTR [bp-16]	;pRgb
	mov	ax,WORD PTR [bp-92]	;rgb
	mov	dx,WORD PTR [bp-90]
	mov	WORD PTR es:[bx][si],ax
	mov	WORD PTR es:[bx+2][si],dx
; Line 290
	jmp	$FC4287
$FB4288:
; Line 291
; Line 292
	jmp	$I4294
$I4283:
; Line 293
; Line 294
	push	WORD PTR [bp+4]	;fh
	push	WORD PTR [bp-14]
	push	WORD PTR [bp-16]	;pRgb
	mov	ax,WORD PTR [bp-12]	;nNumColors
	shl	ax,2
	push	ax
	call	FAR PTR _LREAD
; Line 295
$I4294:
; Line 296
; Line 298
$I4281:
	mov	ax,WORD PTR [bp-70]
	or	ax,WORD PTR [bp-72]
	jne	$JCC1484
	jmp	$I4297
$JCC1484:
; Line 299
	push	WORD PTR [bp+4]	;fh
	mov	ax,WORD PTR [bp-72]
	mov	dx,WORD PTR [bp-70]
	add	ax,WORD PTR [bp-4]	;off
	adc	dx,WORD PTR [bp-2]
	push	dx
	push	ax
	push	0
	call	FAR PTR _LLSEEK
; Line 301
$I4297:
	mov	ax,WORD PTR [bp-86]	;pdib
	mov	dx,WORD PTR [bp-84]
	jmp	$EX4222
; Line 302
$EX4222:
	pop	si
	pop	di
	leave	
	ret	

_DibReadBitmapInfo	ENDP
	PUBLIC	_DibSetUsage
_DibSetUsage	PROC NEAR
; Line 316
	push	bp
	mov	bp,sp
	mov	ax,1036	;040cH
	call	__aNchkstk
	push	di
	push	si
;	ape = -1024
;	pRgb = -1028
;	pw = -1032
;	nColors = -1034
;	n = -1036
;	wUsage = 10
;	hpal = 8
;	pdib = 4
; Line 323
	cmp	WORD PTR [bp+8],0	;hpal
	je	$JCC1541
	jmp	$I4307
$JCC1541:
; Line 324
	push	15	;000fH
	call	FAR PTR GETSTOCKOBJECT
	mov	WORD PTR [bp+8],ax	;hpal
; Line 326
$I4307:
	mov	ax,WORD PTR [bp+6]
	or	ax,WORD PTR [bp+4]	;pdib
	je	$JCC1562
	jmp	$I4309
$JCC1562:
; Line 327
	mov	ax,0
	jmp	$EX4301
; Line 329
$I4309:
	les	bx,DWORD PTR [bp+4]	;pdib
	mov	ax,WORD PTR es:[bx+34]
	or	ax,WORD PTR es:[bx+32]
	je	$JCC1584
	jmp	$L4536
$JCC1584:
	les	bx,DWORD PTR [bp+4]	;pdib
	cmp	WORD PTR es:[bx+14],8
	jbe	$JCC1597
	jmp	$L4536
$JCC1597:
	les	bx,DWORD PTR [bp+4]	;pdib
	mov	cl,BYTE PTR es:[bx+14]
	mov	ax,1
	shl	ax,cl
	mov	WORD PTR [bp-1034],ax	;nColors
	jmp	$L4537
$L4536:
	les	bx,DWORD PTR [bp+4]	;pdib
	mov	ax,WORD PTR es:[bx+32]
	mov	WORD PTR [bp-1034],ax	;nColors
$L4537:
; Line 331
	cmp	WORD PTR [bp-1034],3	;nColors
	je	$JCC1637
	jmp	$I4315
$JCC1637:
	les	bx,DWORD PTR [bp+4]	;pdib
	cmp	WORD PTR es:[bx+16],3
	je	$JCC1650
	jmp	$I4315
$JCC1650:
	cmp	WORD PTR es:[bx+18],0
	je	$JCC1660
	jmp	$I4315
$JCC1660:
; Line 332
	mov	WORD PTR [bp-1034],0	;nColors
; Line 334
$I4315:
	cmp	WORD PTR [bp-1034],0	;nColors
	jg	$JCC1676
	jmp	$I4316
$JCC1676:
; Line 335
; Line 336
	les	bx,DWORD PTR [bp+4]	;pdib
	mov	ax,WORD PTR es:[bx]
	add	ax,WORD PTR [bp+4]	;pdib
	mov	dx,WORD PTR [bp+6]
	mov	WORD PTR [bp-1028],ax	;pRgb
	mov	WORD PTR [bp-1026],dx
; Line 338
	mov	ax,WORD PTR [bp+10]	;wUsage
	jmp	$S4320
; Line 339
; Line 343
$SC4324:
; Line 344
	mov	ax,WORD PTR [bp-1028]	;pRgb
	mov	dx,WORD PTR [bp-1026]
	mov	WORD PTR [bp-1032],ax	;pw
	mov	WORD PTR [bp-1030],dx
	mov	WORD PTR [bp-1036],0	;n
	jmp	$F4326
$FC4327:
	inc	WORD PTR [bp-1036]	;n
	add	WORD PTR [bp-1032],2	;pw
$F4326:
	mov	ax,WORD PTR [bp-1034]	;nColors
	cmp	WORD PTR [bp-1036],ax	;n
	jl	$JCC1749
	jmp	$FB4328
$JCC1749:
; Line 345
	mov	ax,WORD PTR [bp-1036]	;n
	les	bx,DWORD PTR [bp-1032]	;pw
	mov	WORD PTR es:[bx],ax
	jmp	$FC4327
$FB4328:
; Line 346
	jmp	$SB4321
; Line 351
$SD4329:
; Line 353
	mov	ax,WORD PTR [bp-1034]	;nColors
	cmp	ax,256	;0100H
	jg	$JCC1778
	jmp	$L4538
$JCC1778:
	mov	ax,256	;0100H
$L4538:
	mov	WORD PTR [bp-1034],ax	;nColors
; Line 355
	push	WORD PTR [bp+8]	;hpal
	push	0
	push	WORD PTR [bp-1034]	;nColors
	lea	ax,WORD PTR [bp-1024]	;ape
	push	ss
	push	ax
	call	FAR PTR GETPALETTEENTRIES
; Line 357
	mov	WORD PTR [bp-1036],0	;n
	jmp	$F4330
$FC4331:
	inc	WORD PTR [bp-1036]	;n
$F4330:
	mov	ax,WORD PTR [bp-1034]	;nColors
	cmp	WORD PTR [bp-1036],ax	;n
	jl	$JCC1831
	jmp	$FB4332
$JCC1831:
; Line 358
; Line 359
	mov	si,WORD PTR [bp-1036]	;n
	shl	si,2
	mov	al,BYTE PTR [bp-1024][si]
	mov	si,WORD PTR [bp-1036]	;n
	shl	si,2
	les	bx,DWORD PTR [bp-1028]	;pRgb
	mov	BYTE PTR es:[bx+2][si],al
; Line 360
	mov	si,WORD PTR [bp-1036]	;n
	shl	si,2
	mov	al,BYTE PTR [bp-1023][si]
	mov	si,WORD PTR [bp-1036]	;n
	shl	si,2
	les	bx,DWORD PTR [bp-1028]	;pRgb
	mov	BYTE PTR es:[bx+1][si],al
; Line 361
	mov	si,WORD PTR [bp-1036]	;n
	shl	si,2
	mov	al,BYTE PTR [bp-1022][si]
	mov	bx,WORD PTR [bp-1036]	;n
	shl	bx,2
	les	si,DWORD PTR [bp-1028]	;pRgb
	mov	BYTE PTR es:[bx][si],al
; Line 362
	mov	si,WORD PTR [bp-1036]	;n
	shl	si,2
	les	bx,DWORD PTR [bp-1028]	;pRgb
	mov	BYTE PTR es:[bx+3][si],0
; Line 363
	jmp	$FC4331
$FB4332:
; Line 364
	jmp	$SB4321
; Line 365
	jmp	$SB4321
$S4320:
	dec	ax
	jne	$JCC1939
	jmp	$SC4324
$JCC1939:
	jmp	$SD4329
$SB4321:
; Line 366
; Line 367
$I4316:
	mov	ax,1
	jmp	$EX4301
; Line 368
$EX4301:
	pop	si
	pop	di
	leave	
	ret	

_DibSetUsage	ENDP
	PUBLIC	_DibCreate
_DibCreate	PROC NEAR
; Line 378
	push	bp
	mov	bp,sp
	mov	ax,14	;000eH
	call	__aNchkstk
	push	di
	push	si
;	lpbi = -4
;	dwSizeImage = -8
;	i = -10
;	pdw = -14
;	dy = 8
;	dx = 6
;	bits = 4
; Line 384
	mov	ax,WORD PTR [bp+6]	;dx
	imul	WORD PTR [bp+4]	;bits
	cwd	
	and	dx,7
	add	ax,dx
	sar	ax,3
	add	ax,3
	and	ax,-4	;fffcH
	imul	WORD PTR [bp+8]	;dy
	mov	WORD PTR [bp-8],ax	;dwSizeImage
	mov	WORD PTR [bp-6],dx
; Line 386
	push	66	;0042H
	mov	ax,WORD PTR [bp-8]	;dwSizeImage
	mov	dx,WORD PTR [bp-6]
	add	ax,1064	;0428H
	adc	dx,0
	push	dx
	push	ax
	call	FAR PTR GLOBALALLOC
	push	ax
	call	FAR PTR GLOBALLOCK
	mov	WORD PTR [bp-4],ax	;lpbi
	mov	WORD PTR [bp-2],dx
; Line 388
	mov	ax,WORD PTR [bp-2]
	or	ax,WORD PTR [bp-4]	;lpbi
	je	$JCC2037
	jmp	$I4344
$JCC2037:
; Line 389
	mov	ax,0
	mov	dx,0
	jmp	$EX4336
; Line 391
$I4344:
	les	bx,DWORD PTR [bp-4]	;lpbi
	mov	WORD PTR es:[bx],40	;0028H
	mov	WORD PTR es:[bx+2],0
; Line 392
	mov	ax,WORD PTR [bp+6]	;dx
	cwd	
	les	bx,DWORD PTR [bp-4]	;lpbi
	mov	WORD PTR es:[bx+4],ax
	mov	WORD PTR es:[bx+6],dx
; Line 393
	mov	ax,WORD PTR [bp+8]	;dy
	cwd	
	les	bx,DWORD PTR [bp-4]	;lpbi
	mov	WORD PTR es:[bx+8],ax
	mov	WORD PTR es:[bx+10],dx
; Line 394
	les	bx,DWORD PTR [bp-4]	;lpbi
	mov	WORD PTR es:[bx+12],1
; Line 395
	mov	ax,WORD PTR [bp+4]	;bits
	les	bx,DWORD PTR [bp-4]	;lpbi
	mov	WORD PTR es:[bx+14],ax
; Line 396
	les	bx,DWORD PTR [bp-4]	;lpbi
	sub	ax,ax
	mov	WORD PTR es:[bx+18],ax
	mov	WORD PTR es:[bx+16],ax
; Line 397
	mov	ax,WORD PTR [bp-8]	;dwSizeImage
	mov	dx,WORD PTR [bp-6]
	les	bx,DWORD PTR [bp-4]	;lpbi
	mov	WORD PTR es:[bx+20],ax
	mov	WORD PTR es:[bx+22],dx
; Line 398
	les	bx,DWORD PTR [bp-4]	;lpbi
	sub	ax,ax
	mov	WORD PTR es:[bx+26],ax
	mov	WORD PTR es:[bx+24],ax
; Line 399
	les	bx,DWORD PTR [bp-4]	;lpbi
	sub	ax,ax
	mov	WORD PTR es:[bx+30],ax
	mov	WORD PTR es:[bx+28],ax
; Line 400
	les	bx,DWORD PTR [bp-4]	;lpbi
	sub	ax,ax
	mov	WORD PTR es:[bx+34],ax
	mov	WORD PTR es:[bx+32],ax
; Line 401
	les	bx,DWORD PTR [bp-4]	;lpbi
	sub	ax,ax
	mov	WORD PTR es:[bx+38],ax
	mov	WORD PTR es:[bx+36],ax
; Line 403
	cmp	WORD PTR [bp+4],4	;bits
	je	$JCC2200
	jmp	$I4346
$JCC2200:
; Line 404
	les	bx,DWORD PTR [bp-4]	;lpbi
	mov	WORD PTR es:[bx+32],16	;0010H
	mov	WORD PTR es:[bx+34],0
; Line 406
	jmp	$I4347
$I4346:
	cmp	WORD PTR [bp+4],8	;bits
	je	$JCC2227
	jmp	$I4348
$JCC2227:
; Line 407
	les	bx,DWORD PTR [bp-4]	;lpbi
	mov	WORD PTR es:[bx+32],256	;0100H
	mov	WORD PTR es:[bx+34],0
; Line 409
$I4348:
$I4347:
	les	bx,DWORD PTR [bp-4]	;lpbi
	mov	ax,WORD PTR es:[bx]
	add	ax,WORD PTR [bp-4]	;lpbi
	mov	dx,WORD PTR [bp-2]
	mov	WORD PTR [bp-14],ax	;pdw
	mov	WORD PTR [bp-12],dx
; Line 411
	mov	WORD PTR [bp-10],0	;i
	jmp	$F4353
$FC4354:
	inc	WORD PTR [bp-10]	;i
$F4353:
	les	bx,DWORD PTR [bp-4]	;lpbi
	mov	ax,WORD PTR es:[bx+32]
	cwd	
	and	dx,15	;000fH
	add	ax,dx
	sar	ax,4
	cmp	ax,WORD PTR [bp-10]	;i
	jg	$JCC2295
	jmp	$FB4355
$JCC2295:
; Line 412
; Line 413
	les	bx,DWORD PTR [bp-14]	;pdw
	add	WORD PTR [bp-14],4	;pdw
	sub	ax,ax
	mov	WORD PTR es:[bx+2],ax
	mov	WORD PTR es:[bx],ax
; Line 414
	les	bx,DWORD PTR [bp-14]	;pdw
	add	WORD PTR [bp-14],4	;pdw
	mov	WORD PTR es:[bx],0
	mov	WORD PTR es:[bx+2],128	;0080H
; Line 415
	les	bx,DWORD PTR [bp-14]	;pdw
	add	WORD PTR [bp-14],4	;pdw
	mov	WORD PTR es:[bx],-32768	;8000H
	mov	WORD PTR es:[bx+2],0
; Line 416
	les	bx,DWORD PTR [bp-14]	;pdw
	add	WORD PTR [bp-14],4	;pdw
	mov	WORD PTR es:[bx],-32768	;8000H
	mov	WORD PTR es:[bx+2],128	;0080H
; Line 417
	les	bx,DWORD PTR [bp-14]	;pdw
	add	WORD PTR [bp-14],4	;pdw
	mov	WORD PTR es:[bx],128	;0080H
	mov	WORD PTR es:[bx+2],0
; Line 418
	les	bx,DWORD PTR [bp-14]	;pdw
	add	WORD PTR [bp-14],4	;pdw
	mov	WORD PTR es:[bx],128	;0080H
	mov	WORD PTR es:[bx+2],128	;0080H
; Line 419
	les	bx,DWORD PTR [bp-14]	;pdw
	add	WORD PTR [bp-14],4	;pdw
	mov	WORD PTR es:[bx],-32640	;8080H
	mov	WORD PTR es:[bx+2],0
; Line 420
	les	bx,DWORD PTR [bp-14]	;pdw
	add	WORD PTR [bp-14],4	;pdw
	mov	WORD PTR es:[bx],-16192	;c0c0H
	mov	WORD PTR es:[bx+2],192	;00c0H
; Line 421
	les	bx,DWORD PTR [bp-14]	;pdw
	add	WORD PTR [bp-14],4	;pdw
	mov	WORD PTR es:[bx],-32640	;8080H
	mov	WORD PTR es:[bx+2],128	;0080H
; Line 422
	les	bx,DWORD PTR [bp-14]	;pdw
	add	WORD PTR [bp-14],4	;pdw
	mov	WORD PTR es:[bx],0
	mov	WORD PTR es:[bx+2],255	;00ffH
; Line 423
	les	bx,DWORD PTR [bp-14]	;pdw
	add	WORD PTR [bp-14],4	;pdw
	mov	WORD PTR es:[bx],-256	;ff00H
	mov	WORD PTR es:[bx+2],0
; Line 424
	les	bx,DWORD PTR [bp-14]	;pdw
	add	WORD PTR [bp-14],4	;pdw
	mov	WORD PTR es:[bx],-256	;ff00H
	mov	WORD PTR es:[bx+2],255	;00ffH
; Line 425
	les	bx,DWORD PTR [bp-14]	;pdw
	add	WORD PTR [bp-14],4	;pdw
	mov	WORD PTR es:[bx],255	;00ffH
	mov	WORD PTR es:[bx+2],0
; Line 426
	les	bx,DWORD PTR [bp-14]	;pdw
	add	WORD PTR [bp-14],4	;pdw
	mov	WORD PTR es:[bx],255	;00ffH
	mov	WORD PTR es:[bx+2],255	;00ffH
; Line 427
	les	bx,DWORD PTR [bp-14]	;pdw
	add	WORD PTR [bp-14],4	;pdw
	mov	WORD PTR es:[bx],-1	;ffffH
	mov	WORD PTR es:[bx+2],0
; Line 428
	les	bx,DWORD PTR [bp-14]	;pdw
	add	WORD PTR [bp-14],4	;pdw
	mov	WORD PTR es:[bx],-1	;ffffH
	mov	WORD PTR es:[bx+2],255	;00ffH
; Line 429
	jmp	$FC4354
$FB4355:
; Line 431
	mov	ax,WORD PTR [bp-4]	;lpbi
	mov	dx,WORD PTR [bp-2]
	jmp	$EX4336
; Line 432
$EX4336:
	pop	si
	pop	di
	leave	
	ret	

_DibCreate	ENDP

?xlatClut8@@YAXPEEK0@Z	PROC NEAR	; xlatClut8
; Line 435
	push	bp
	mov	bp,sp
	mov	ax,4
	call	__aNchkstk
	push	di
	push	si
;	dw = -4
;	xlat = 12
;	dwSize = 8
;	pb = 4
; Line 439
	sub	ax,ax
	mov	WORD PTR [bp-2],ax
	mov	WORD PTR [bp-4],ax	;dw
	jmp	$F4364
$FC4365:
	add	WORD PTR [bp-4],1	;dw
	adc	WORD PTR [bp-2],0
	add	WORD PTR [bp+4],1	;pb
	sbb	ax,ax
	and	ax,OFFSET __AHINCR
	add	WORD PTR [bp+6],ax
$F4364:
	mov	ax,WORD PTR [bp+8]	;dwSize
	mov	dx,WORD PTR [bp+10]
	cmp	WORD PTR [bp-2],dx
	jbe	$JCC2653
	jmp	$FB4366
$JCC2653:
	jae	$JCC2658
	jmp	$L4540
$JCC2658:
	cmp	WORD PTR [bp-4],ax	;dw
	jb	$JCC2666
	jmp	$FB4366
$JCC2666:
$L4540:
; Line 443
	les	bx,DWORD PTR [bp+4]	;pb
	mov	bl,BYTE PTR es:[bx]
	sub	bh,bh
	les	si,DWORD PTR [bp+12]	;xlat
	mov	al,BYTE PTR es:[bx][si]
	les	bx,DWORD PTR [bp+4]	;pb
	mov	BYTE PTR es:[bx],al
	jmp	$FC4365
$FB4366:
; Line 444
	jmp	$EX4361
$EX4361:
	pop	si
	pop	di
	leave	
	ret	

?xlatClut8@@YAXPEEK0@Z	ENDP

?xlatClut4@@YAXPEEK0@Z	PROC NEAR	; xlatClut4
; Line 447
	push	bp
	mov	bp,sp
	mov	ax,4
	call	__aNchkstk
	push	di
	push	si
;	dw = -4
;	xlat = 12
;	dwSize = 8
;	pb = 4
; Line 451
	sub	ax,ax
	mov	WORD PTR [bp-2],ax
	mov	WORD PTR [bp-4],ax	;dw
	jmp	$F4374
$FC4375:
	add	WORD PTR [bp-4],1	;dw
	adc	WORD PTR [bp-2],0
	add	WORD PTR [bp+4],1	;pb
	sbb	ax,ax
	and	ax,OFFSET __AHINCR
	add	WORD PTR [bp+6],ax
$F4374:
	mov	ax,WORD PTR [bp+8]	;dwSize
	mov	dx,WORD PTR [bp+10]
	cmp	WORD PTR [bp-2],dx
	jbe	$JCC2752
	jmp	$FB4376
$JCC2752:
	jae	$JCC2757
	jmp	$L4541
$JCC2757:
	cmp	WORD PTR [bp-4],ax	;dw
	jb	$JCC2765
	jmp	$FB4376
$JCC2765:
$L4541:
; Line 455
	les	bx,DWORD PTR [bp+4]	;pb
	mov	bl,BYTE PTR es:[bx]
	and	bx,15	;000fH
	les	si,DWORD PTR [bp+12]	;xlat
	les	si,DWORD PTR [bp+4]	;pb
	les	di,DWORD PTR [bp+12]	;xlat
	mov	al,BYTE PTR es:[bx][di]
	les	bx,DWORD PTR [bp+4]	;pb
	mov	bl,BYTE PTR es:[bx]
	shr	bl,4
	sub	bh,bh
	les	si,DWORD PTR [bp+12]	;xlat
	mov	cl,BYTE PTR es:[bx][si]
	shl	cl,4
	or	al,cl
	les	bx,DWORD PTR [bp+4]	;pb
	mov	BYTE PTR es:[bx],al
	jmp	$FC4375
$FB4376:
; Line 456
	jmp	$EX4371
$EX4371:
	pop	si
	pop	di
	leave	
	ret	

?xlatClut4@@YAXPEEK0@Z	ENDP

?xlatRle8@@YAXPEEK0@Z	PROC NEAR	; xlatRle8
; Line 464
	push	bp
	mov	bp,sp
	mov	ax,8
	call	__aNchkstk
	push	di
	push	si
;	cnt = -2
;	b = -4
;	prle = -8
;	xlat = 12
;	dwSize = 8
;	pb = 4
; Line 467
	mov	ax,WORD PTR [bp+4]	;pb
	mov	dx,WORD PTR [bp+6]
	mov	WORD PTR [bp-8],ax	;prle
	mov	WORD PTR [bp-6],dx
; Line 469
$FC4387:
; Line 470
; Line 471
	les	bx,DWORD PTR [bp-8]	;prle
	add	WORD PTR [bp-8],1	;prle
	jb	$JCC2859
	jmp	$L4542
$JCC2859:
	add	WORD PTR [bp-6],OFFSET __AHINCR
$L4542:
	mov	al,BYTE PTR es:[bx]
	mov	BYTE PTR [bp-2],al	;cnt
; Line 472
	les	bx,DWORD PTR [bp-8]	;prle
	mov	al,BYTE PTR es:[bx]
	mov	BYTE PTR [bp-4],al	;b
; Line 474
	cmp	BYTE PTR [bp-2],0	;cnt
	je	$JCC2888
	jmp	$I4389
$JCC2888:
; Line 475
; Line 476
	add	WORD PTR [bp-8],1	;prle
	sbb	ax,ax
	and	ax,OFFSET __AHINCR
	add	WORD PTR [bp-6],ax
; Line 478
	mov	al,BYTE PTR [bp-4]	;b
	sub	ah,ah
	jmp	$S4390
; Line 479
; Line 480
$SC4394:
; Line 481
	jmp	$EX4382
; Line 483
$SC4395:
; Line 484
	jmp	$SB4391
; Line 486
$SC4396:
; Line 487
	add	WORD PTR [bp-8],1	;prle
	sbb	ax,ax
	and	ax,OFFSET __AHINCR
	add	WORD PTR [bp-6],ax
; Line 488
	add	WORD PTR [bp-8],1	;prle
	sbb	ax,ax
	and	ax,OFFSET __AHINCR
	add	WORD PTR [bp-6],ax
; Line 489
	jmp	$SB4391
; Line 491
$SD4397:
; Line 492
	mov	al,BYTE PTR [bp-4]	;b
	mov	BYTE PTR [bp-2],al	;cnt
; Line 493
	mov	BYTE PTR [bp-4],0	;b
	jmp	$F4398
$FC4399:
	inc	BYTE PTR [bp-4]	;b
	add	WORD PTR [bp-8],1	;prle
	sbb	ax,ax
	and	ax,OFFSET __AHINCR
	add	WORD PTR [bp-6],ax
$F4398:
	mov	al,BYTE PTR [bp-2]	;cnt
	cmp	BYTE PTR [bp-4],al	;b
	jb	$JCC2980
	jmp	$FB4400
$JCC2980:
; Line 494
	les	bx,DWORD PTR [bp-8]	;prle
	mov	bl,BYTE PTR es:[bx]
	sub	bh,bh
	les	si,DWORD PTR [bp+12]	;xlat
	mov	al,BYTE PTR es:[bx][si]
	les	bx,DWORD PTR [bp-8]	;prle
	mov	BYTE PTR es:[bx],al
	jmp	$FC4399
$FB4400:
; Line 496
	test	BYTE PTR [bp-2],1	;cnt
	jne	$JCC3012
	jmp	$I4401
$JCC3012:
; Line 497
	add	WORD PTR [bp-8],1	;prle
	sbb	ax,ax
	and	ax,OFFSET __AHINCR
	add	WORD PTR [bp-6],ax
; Line 499
$I4401:
	jmp	$SB4391
; Line 500
	jmp	$SB4391
$S4390:
	or	ax,ax
	jne	$JCC3037
	jmp	$SC4395
$JCC3037:
	dec	ax
	jne	$JCC3043
	jmp	$SC4394
$JCC3043:
	dec	ax
	jne	$JCC3049
	jmp	$SC4396
$JCC3049:
	jmp	$SD4397
$SB4391:
; Line 501
; Line 502
	jmp	$I4402
$I4389:
; Line 503
; Line 504
	mov	bl,BYTE PTR [bp-4]	;b
	sub	bh,bh
	les	si,DWORD PTR [bp+12]	;xlat
	mov	al,BYTE PTR es:[bx][si]
	les	bx,DWORD PTR [bp-8]	;prle
	add	WORD PTR [bp-8],1	;prle
	jb	$JCC3078
	jmp	$L4543
$JCC3078:
	add	WORD PTR [bp-6],OFFSET __AHINCR
$L4543:
	mov	BYTE PTR es:[bx],al
; Line 505
$I4402:
; Line 506
	jmp	$FC4387
$FB4388:
; Line 507
	jmp	$EX4382
$EX4382:
	pop	si
	pop	di
	leave	
	ret	

?xlatRle8@@YAXPEEK0@Z	ENDP

?xlatRle4@@YAXPEEK0@Z	PROC NEAR	; xlatRle4
; Line 510
	push	bp
	mov	bp,sp
	mov	ax,0
	call	__aNchkstk
	push	di
	push	si
;	xlat = 12
;	dwSize = 8
;	pb = 4
; Line 511
	jmp	$EX4407
$EX4407:
	pop	si
	pop	di
	leave	
	ret	

?xlatRle4@@YAXPEEK0@Z	ENDP

?hmemmove@@YAXPIE0J@Z	PROC NEAR	; hmemmove
; Line 514
	push	bp
	mov	bp,sp
	mov	ax,4
	call	__aNchkstk
	push	di
	push	si
;	len = 12
;	s = 8
;	d = 4
; Line 515
	mov	ax,WORD PTR [bp+12]	;len
	mov	dx,WORD PTR [bp+14]
	sub	ax,1
	sbb	dx,0
	sub	bx,bx
	mov	cx,ax
	add	WORD PTR [bp+4],cx	;d
	adc	bx,dx
	mov	cx,OFFSET __AHSHIFT
	shl	bx,cl
	add	WORD PTR [bp+6],bx
; Line 516
	mov	ax,WORD PTR [bp+12]	;len
	mov	dx,WORD PTR [bp+14]
	sub	ax,1
	sbb	dx,0
	sub	bx,bx
	mov	cx,ax
	add	WORD PTR [bp+8],cx	;s
	adc	bx,dx
	mov	cx,OFFSET __AHSHIFT
	shl	bx,cl
	add	WORD PTR [bp+10],bx
; Line 518
$FC4414:
	mov	ax,WORD PTR [bp+12]	;len
	mov	dx,WORD PTR [bp+14]
	sub	WORD PTR [bp+12],1	;len
	sbb	WORD PTR [bp+14],0
	or	dx,ax
	jne	$JCC3204
	jmp	$FB4415
$JCC3204:
; Line 519
	les	bx,DWORD PTR [bp+8]	;s
	add	WORD PTR [bp+8],-1	;ffffH	;s
	jae	$JCC3216
	jmp	$L4546
$JCC3216:
	sub	WORD PTR [bp+10],OFFSET __AHINCR
$L4546:
	mov	al,BYTE PTR es:[bx]
	les	bx,DWORD PTR [bp+4]	;d
	add	WORD PTR [bp+4],-1	;ffffH	;d
	jae	$JCC3236
	jmp	$L4545
$JCC3236:
	sub	WORD PTR [bp+6],OFFSET __AHINCR
$L4545:
	mov	BYTE PTR es:[bx],al
	jmp	$FC4414
$FB4415:
; Line 520
	jmp	$EX4412
$EX4412:
	pop	si
	pop	di
	leave	
	ret	

?hmemmove@@YAXPIE0J@Z	ENDP
	PUBLIC	_DibMapToPalette
_DibMapToPalette	PROC NEAR
; Line 530
	push	bp
	mov	bp,sp
	mov	ax,282	;011aH
	call	__aNchkstk
	push	di
	push	si
;	lpbi = -4
;	pe = -8
;	n = -10
;	nDibColors = -12
;	nPalColors = -14
;	lpBits = -18
;	lpRgb = -22
;	xlat = -278
;	SizeImage = -282
;	hpal = 8
;	pdib = 4
; Line 535
	mov	WORD PTR [bp-14],0	;nPalColors
; Line 541
	cmp	WORD PTR [bp+8],0	;hpal
	jne	$JCC3279
	jmp	$I4429
$JCC3279:
	mov	ax,WORD PTR [bp+6]
	or	ax,WORD PTR [bp+4]	;pdib
	je	$JCC3290
	jmp	$I4428
$JCC3290:
$I4429:
; Line 542
	jmp	$EX4418
; Line 544
$I4428:
	mov	ax,WORD PTR [bp+4]	;pdib
	mov	dx,WORD PTR [bp+6]
	mov	WORD PTR [bp-4],ax	;lpbi
	mov	WORD PTR [bp-2],dx
; Line 545
	les	bx,DWORD PTR [bp+4]	;pdib
	mov	ax,WORD PTR es:[bx]
	add	ax,WORD PTR [bp+4]	;pdib
	mov	dx,WORD PTR [bp+6]
	mov	WORD PTR [bp-22],ax	;lpRgb
	mov	WORD PTR [bp-20],dx
; Line 547
	push	WORD PTR [bp+8]	;hpal
	push	2
	lea	ax,WORD PTR [bp-14]	;nPalColors
	push	ss
	push	ax
	call	FAR PTR GETOBJECT
; Line 548
	les	bx,DWORD PTR [bp+4]	;pdib
	mov	ax,WORD PTR es:[bx+34]
	or	ax,WORD PTR es:[bx+32]
	je	$JCC3354
	jmp	$L4547
$JCC3354:
	les	bx,DWORD PTR [bp+4]	;pdib
	cmp	WORD PTR es:[bx+14],8
	jbe	$JCC3367
	jmp	$L4547
$JCC3367:
	les	bx,DWORD PTR [bp+4]	;pdib
	mov	cl,BYTE PTR es:[bx+14]
	mov	ax,1
	shl	ax,cl
	mov	WORD PTR [bp-12],ax	;nDibColors
	jmp	$L4548
$L4547:
	les	bx,DWORD PTR [bp+4]	;pdib
	mov	ax,WORD PTR es:[bx+32]
	mov	WORD PTR [bp-12],ax	;nDibColors
$L4548:
; Line 550
	les	bx,DWORD PTR [bp-4]	;lpbi
	mov	ax,WORD PTR es:[bx+20]
	mov	dx,WORD PTR es:[bx+22]
	mov	WORD PTR [bp-282],ax	;SizeImage
	mov	WORD PTR [bp-280],dx
	or	dx,ax
	je	$JCC3421
	jmp	$I4439
$JCC3421:
; Line 551
	les	bx,DWORD PTR [bp-4]	;lpbi
	mov	ax,WORD PTR es:[bx+22]
	or	ax,WORD PTR es:[bx+20]
	je	$JCC3437
	jmp	$L4549
$JCC3437:
	les	bx,DWORD PTR [bp-4]	;lpbi
	mov	ax,WORD PTR es:[bx+4]
	les	bx,DWORD PTR [bp-4]	;lpbi
	mul	WORD PTR es:[bx+14]
	add	ax,31	;001fH
	and	ax,-25	;ffe7H
	shr	ax,3
	les	bx,DWORD PTR [bp-4]	;lpbi
	mul	WORD PTR es:[bx+8]
	jmp	$L4550
$L4549:
	les	bx,DWORD PTR [bp-4]	;lpbi
	mov	ax,WORD PTR es:[bx+20]
	mov	dx,WORD PTR es:[bx+22]
$L4550:
	mov	WORD PTR [bp-282],ax	;SizeImage
	mov	WORD PTR [bp-280],dx
; Line 557
$I4439:
	mov	WORD PTR [bp-10],0	;n
	jmp	$F4448
$FC4449:
	inc	WORD PTR [bp-10]	;n
$F4448:
	mov	ax,WORD PTR [bp-10]	;n
	cmp	WORD PTR [bp-12],ax	;nDibColors
	jg	$JCC3511
	jmp	$FB4450
$JCC3511:
; Line 558
	push	WORD PTR [bp+8]	;hpal
	mov	bx,WORD PTR [bp-10]	;n
	shl	bx,2
	les	si,DWORD PTR [bp-22]	;lpRgb
	mov	al,BYTE PTR es:[bx][si]
	sub	ah,ah
	mov	si,WORD PTR [bp-10]	;n
	shl	si,2
	les	bx,DWORD PTR [bp-22]	;lpRgb
	mov	ch,BYTE PTR es:[bx+1][si]
	sub	cl,cl
	mov	si,WORD PTR [bp-10]	;n
	shl	si,2
	les	bx,DWORD PTR [bp-22]	;lpRgb
	mov	dl,BYTE PTR es:[bx+2][si]
	sub	dh,dh
	or	cx,dx
	push	ax
	push	cx
	call	FAR PTR GETNEARESTPALETTEINDEX
	mov	si,WORD PTR [bp-10]	;n
	mov	BYTE PTR [bp-278][si],al
	jmp	$FC4449
$FB4450:
; Line 560
	les	bx,DWORD PTR [bp-4]	;lpbi
	mov	ax,WORD PTR es:[bx+32]
	shl	ax,2
	les	bx,DWORD PTR [bp-4]	;lpbi
	add	ax,WORD PTR es:[bx]
	add	ax,WORD PTR [bp-4]	;lpbi
	mov	dx,WORD PTR [bp-2]
	mov	WORD PTR [bp-18],ax	;lpBits
	mov	WORD PTR [bp-16],dx
; Line 561
	mov	ax,WORD PTR [bp-14]	;nPalColors
	cwd	
	les	bx,DWORD PTR [bp-4]	;lpbi
	mov	WORD PTR es:[bx+32],ax
	mov	WORD PTR es:[bx+34],dx
; Line 566
	mov	ax,WORD PTR [bp-12]	;nDibColors
	cmp	WORD PTR [bp-14],ax	;nPalColors
	jg	$JCC3631
	jmp	$I4463
$JCC3631:
; Line 567
; Line 568
	push	WORD PTR [bp-2]
	call	FAR PTR GLOBALHANDLE
	push	ax
	call	FAR PTR GLOBALUNLOCK
	push	WORD PTR [bp-2]
	call	FAR PTR GLOBALHANDLE
	push	ax
	mov	ax,WORD PTR [bp-14]	;nPalColors
	shl	ax,2
	sub	dx,dx
	les	bx,DWORD PTR [bp-4]	;lpbi
	add	ax,WORD PTR es:[bx]
	adc	dx,WORD PTR es:[bx+2]
	add	ax,WORD PTR [bp-282]	;SizeImage
	adc	dx,WORD PTR [bp-280]
	push	dx
	push	ax
	push	0
	call	FAR PTR GLOBALREALLOC
	push	ax
	call	FAR PTR GLOBALLOCK
; Line 569
	push	WORD PTR [bp-280]
	push	WORD PTR [bp-282]	;SizeImage
	push	WORD PTR [bp-16]
	push	WORD PTR [bp-18]	;lpBits
	les	bx,DWORD PTR [bp-4]	;lpbi
	mov	ax,WORD PTR es:[bx+32]
	shl	ax,2
	les	bx,DWORD PTR [bp-4]	;lpbi
	add	ax,WORD PTR es:[bx]
	add	ax,WORD PTR [bp-4]	;lpbi
	mov	dx,WORD PTR [bp-2]
	push	dx
	push	ax
	call	?hmemmove@@YAXPIE0J@Z	; hmemmove
	add	sp,12	;000cH
; Line 570
	les	bx,DWORD PTR [bp-4]	;lpbi
	mov	ax,WORD PTR es:[bx+32]
	shl	ax,2
	les	bx,DWORD PTR [bp-4]	;lpbi
	add	ax,WORD PTR es:[bx]
	add	ax,WORD PTR [bp-4]	;lpbi
	mov	dx,WORD PTR [bp-2]
	mov	WORD PTR [bp-18],ax	;lpBits
	mov	WORD PTR [bp-16],dx
; Line 571
; Line 572
	jmp	$I4488
$I4463:
	mov	ax,WORD PTR [bp-12]	;nDibColors
	cmp	WORD PTR [bp-14],ax	;nPalColors
	jl	$JCC3781
	jmp	$I4489
$JCC3781:
; Line 573
; Line 574
	les	bx,DWORD PTR [bp-4]	;lpbi
	mov	ax,WORD PTR es:[bx+32]
	shl	ax,2
	les	bx,DWORD PTR [bp-4]	;lpbi
	add	ax,WORD PTR es:[bx]
	add	ax,WORD PTR [bp-4]	;lpbi
	mov	dx,WORD PTR [bp-2]
	push	dx
	push	ax
	push	WORD PTR [bp-16]
	push	WORD PTR [bp-18]	;lpBits
	push	WORD PTR [bp-280]
	push	WORD PTR [bp-282]	;SizeImage
	call	FAR PTR HMEMCPY
; Line 575
	push	WORD PTR [bp-2]
	call	FAR PTR GLOBALHANDLE
	push	ax
	call	FAR PTR GLOBALUNLOCK
	push	WORD PTR [bp-2]
	call	FAR PTR GLOBALHANDLE
	push	ax
	mov	ax,WORD PTR [bp-14]	;nPalColors
	shl	ax,2
	sub	dx,dx
	les	bx,DWORD PTR [bp-4]	;lpbi
	add	ax,WORD PTR es:[bx]
	adc	dx,WORD PTR es:[bx+2]
	add	ax,WORD PTR [bp-282]	;SizeImage
	adc	dx,WORD PTR [bp-280]
	push	dx
	push	ax
	push	0
	call	FAR PTR GLOBALREALLOC
	push	ax
	call	FAR PTR GLOBALLOCK
; Line 576
	les	bx,DWORD PTR [bp-4]	;lpbi
	mov	ax,WORD PTR es:[bx+32]
	shl	ax,2
	les	bx,DWORD PTR [bp-4]	;lpbi
	add	ax,WORD PTR es:[bx]
	add	ax,WORD PTR [bp-4]	;lpbi
	mov	dx,WORD PTR [bp-2]
	mov	WORD PTR [bp-18],ax	;lpBits
	mov	WORD PTR [bp-16],dx
; Line 577
; Line 582
$I4489:
$I4488:
	les	bx,DWORD PTR [bp-4]	;lpbi
	mov	ax,WORD PTR es:[bx+16]
	mov	dx,WORD PTR es:[bx+18]
	jmp	$S4512
; Line 583
; Line 584
$SC4516:
; Line 585
	lea	ax,WORD PTR [bp-278]	;xlat
	push	ss
	push	ax
	push	WORD PTR [bp-280]
	push	WORD PTR [bp-282]	;SizeImage
	push	WORD PTR [bp-16]
	push	WORD PTR [bp-18]	;lpBits
	call	?xlatRle8@@YAXPEEK0@Z	; xlatRle8
	add	sp,12	;000cH
; Line 586
	jmp	$SB4513
; Line 588
$SC4517:
; Line 589
	lea	ax,WORD PTR [bp-278]	;xlat
	push	ss
	push	ax
	push	WORD PTR [bp-280]
	push	WORD PTR [bp-282]	;SizeImage
	push	WORD PTR [bp-16]
	push	WORD PTR [bp-18]	;lpBits
	call	?xlatRle4@@YAXPEEK0@Z	; xlatRle4
	add	sp,12	;000cH
; Line 590
	jmp	$SB4513
; Line 592
$SC4518:
; Line 593
	les	bx,DWORD PTR [bp-4]	;lpbi
	cmp	WORD PTR es:[bx+14],8
	je	$JCC4001
	jmp	$I4519
$JCC4001:
; Line 594
	lea	ax,WORD PTR [bp-278]	;xlat
	push	ss
	push	ax
	push	WORD PTR [bp-280]
	push	WORD PTR [bp-282]	;SizeImage
	push	WORD PTR [bp-16]
	push	WORD PTR [bp-18]	;lpBits
	call	?xlatClut8@@YAXPEEK0@Z	; xlatClut8
	add	sp,12	;000cH
; Line 595
	jmp	$I4520
$I4519:
; Line 596
	lea	ax,WORD PTR [bp-278]	;xlat
	push	ss
	push	ax
	push	WORD PTR [bp-280]
	push	WORD PTR [bp-282]	;SizeImage
	push	WORD PTR [bp-16]
	push	WORD PTR [bp-18]	;lpBits
	call	?xlatClut4@@YAXPEEK0@Z	; xlatClut4
	add	sp,12	;000cH
$I4520:
; Line 597
	jmp	$SB4513
; Line 598
	jmp	$SB4513
$S4512:
	or	dx,dx
	je	$JCC4069
	jmp	$SB4513
$JCC4069:
	or	ax,ax
	jne	$JCC4076
	jmp	$SC4518
$JCC4076:
	dec	ax
	jne	$JCC4082
	jmp	$SC4516
$JCC4082:
	dec	ax
	jne	$JCC4088
	jmp	$SC4517
$JCC4088:
	jmp	$SB4513
$SB4513:
; Line 603
	mov	WORD PTR [bp-10],0	;n
	jmp	$F4521
$FC4522:
	inc	WORD PTR [bp-10]	;n
$F4521:
	mov	ax,WORD PTR [bp-10]	;n
	cmp	WORD PTR [bp-14],ax	;nPalColors
	jg	$JCC4113
	jmp	$FB4523
$JCC4113:
; Line 604
; Line 605
	push	WORD PTR [bp+8]	;hpal
	push	WORD PTR [bp-10]	;n
	push	1
	lea	ax,WORD PTR [bp-8]	;pe
	push	ss
	push	ax
	call	FAR PTR GETPALETTEENTRIES
; Line 607
	mov	al,BYTE PTR [bp-8]	;pe
	mov	si,WORD PTR [bp-10]	;n
	shl	si,2
	les	bx,DWORD PTR [bp-22]	;lpRgb
	mov	BYTE PTR es:[bx+2][si],al
; Line 608
	mov	al,BYTE PTR [bp-7]
	mov	si,WORD PTR [bp-10]	;n
	shl	si,2
	les	bx,DWORD PTR [bp-22]	;lpRgb
	mov	BYTE PTR es:[bx+1][si],al
; Line 609
	mov	bx,WORD PTR [bp-10]	;n
	shl	bx,2
	les	si,DWORD PTR [bp-22]	;lpRgb
	mov	al,BYTE PTR [bp-6]
	mov	BYTE PTR es:[bx][si],al
; Line 610
	mov	si,WORD PTR [bp-10]	;n
	shl	si,2
	les	bx,DWORD PTR [bp-22]	;lpRgb
	mov	BYTE PTR es:[bx+3][si],0
; Line 611
	jmp	$FC4522
$FB4523:
; Line 613
	jmp	$EX4418
; Line 614
	jmp	$EX4418
$EX4418:
	pop	si
	pop	di
	leave	
	ret	

_DibMapToPalette	ENDP
_TEXT	ENDS
END
