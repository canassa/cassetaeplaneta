;	Static Name Aliases
;
	TITLE   d:\lc\demo\tblt.cpp
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
EXTRN	INTERSECTRECT:FAR
EXTRN	__aNchkstk:NEAR
EXTRN	__aNlmul:NEAR
EXTRN	__AHSHIFT:NEAR
EXTRN	__aNulmul:NEAR
EXTRN	TRANSCOPYDIBBITS:FAR
EXTRN	COPYDIBBITS:FAR
_TEXT      SEGMENT
	ASSUME	CS: _TEXT
	PUBLIC	_TranspDIBits
_TranspDIBits	PROC NEAR
; Line 56
	push	bp
	mov	bp,sp
	mov	ax,60	;003cH
	call	__aNchkstk
	push	di
	push	si
;	pSource = -26
;	DestSelector = -28
;	DestOffset = -32
;	SourceRectangle = -40
;	DestinationRectangle = -48
;	ClippedRectangle = -56
;	ReturnValue = -2
;	NewDestinationXOrigin = -4
;	NewDestinationYOrigin = -6
;	DestinationDeltaX = -8
;	DestinationDeltaY = -10
;	Width = -12
;	Height = -14
;	NewSourceXOrigin = -16
;	NewSourceYOrigin = -18
;	Orientation = -20
;	DestinationHeight = -22
;	TransparentColor = 34
;	iUsage = 32
;	SourceHeight = 30
;	SourceWidth = 28
;	nYOriginSrc = 26
;	nXOriginSrc = 24
;	pBitmapInfo = 20
;	pBits = 16
;	nYOriginDest = 14
;	nXOriginDest = 12
;	pBufferBits = 8
;	pBufferHeader = 4
; Line 57
	mov	WORD PTR [bp-2],0	;ReturnValue
; Line 67
	mov	WORD PTR [bp-20],1	;Orientation
; Line 68
	les	bx,DWORD PTR [bp+4]	;pBufferHeader
	mov	ax,WORD PTR es:[bx+8]
	mov	WORD PTR [bp-22],ax	;DestinationHeight
; Line 76
	mov	ax,WORD PTR [bp+12]	;nXOriginDest
	mov	WORD PTR [bp-40],ax	;SourceRectangle
	mov	ax,WORD PTR [bp+14]	;nYOriginDest
	mov	WORD PTR [bp-38],ax
; Line 77
	mov	ax,WORD PTR [bp+28]	;SourceWidth
	add	ax,WORD PTR [bp+12]	;nXOriginDest
	mov	WORD PTR [bp-36],ax
	mov	ax,WORD PTR [bp+30]	;SourceHeight
	add	ax,WORD PTR [bp+14]	;nYOriginDest
	mov	WORD PTR [bp-34],ax
; Line 84
	mov	ax,WORD PTR [bp+16]	;pBits
	mov	dx,WORD PTR [bp+18]
	mov	WORD PTR [bp-26],ax	;pSource
	mov	WORD PTR [bp-24],dx
; Line 87
	mov	ax,WORD PTR [bp+26]	;nYOriginSrc
	cwd	
	push	dx
	push	ax
	les	bx,DWORD PTR [bp+20]	;pBitmapInfo
	mov	ax,WORD PTR es:[bx+4]
	les	bx,DWORD PTR [bp+20]	;pBitmapInfo
	mul	WORD PTR es:[bx+14]
	add	ax,31	;001fH
	and	ax,-25	;ffe7H
	shr	ax,3
	push	0
	push	ax
	call	__aNlmul
	mov	cx,ax
	mov	ax,WORD PTR [bp+24]	;nXOriginSrc
	mov	bx,dx
	cwd	
	add	cx,ax
	adc	bx,dx
	mov	ax,cx
	sub	dx,dx
	mov	cx,ax
	add	WORD PTR [bp-26],cx	;pSource
	adc	dx,bx
	mov	cx,OFFSET __AHSHIFT
	shl	dx,cl
	add	WORD PTR [bp-24],dx
; Line 89
	mov	ax,WORD PTR [bp-26]	;pSource
	mov	dx,WORD PTR [bp-24]
	mov	WORD PTR [bp+16],ax	;pBits
	mov	WORD PTR [bp+18],dx
; Line 92
	cmp	WORD PTR [bp-22],0	;DestinationHeight
	jl	$JCC155
	jmp	$I4241
$JCC155:
; Line 93
; Line 94
	mov	WORD PTR [bp-20],-1	;ffffH	;Orientation
; Line 95
	neg	WORD PTR [bp-22]	;DestinationHeight
; Line 96
; Line 98
$I4241:
	mov	WORD PTR [bp-46],0
; Line 99
	mov	WORD PTR [bp-48],0	;DestinationRectangle
; Line 100
	mov	ax,WORD PTR [bp-22]	;DestinationHeight
	mov	WORD PTR [bp-42],ax
; Line 101
	les	bx,DWORD PTR [bp+4]	;pBufferHeader
	mov	ax,WORD PTR es:[bx+4]
	mov	WORD PTR [bp-44],ax
; Line 106
	lea	ax,WORD PTR [bp-56]	;ClippedRectangle
	push	ss
	push	ax
	lea	cx,WORD PTR [bp-40]	;SourceRectangle
	push	ss
	push	cx
	lea	cx,WORD PTR [bp-48]	;DestinationRectangle
	push	ss
	push	cx
	call	FAR PTR INTERSECTRECT
	cmp	ax,0
	jne	$JCC217
	jmp	$I4244
$JCC217:
; Line 107
;	DestinationScanDelta = -60
; Line 109
	les	bx,DWORD PTR [bp+4]	;pBufferHeader
	mov	ax,WORD PTR es:[bx+4]
	les	bx,DWORD PTR [bp+4]	;pBufferHeader
	mul	WORD PTR es:[bx+14]
	add	ax,31	;001fH
	and	ax,-25	;ffe7H
	shr	ax,3
	mov	WORD PTR [bp-60],ax	;DestinationScanDelta
	mov	WORD PTR [bp-58],0
; Line 112
	mov	ax,WORD PTR [bp-56]	;ClippedRectangle
	mov	WORD PTR [bp-4],ax	;NewDestinationXOrigin
; Line 113
	mov	ax,WORD PTR [bp-54]
	mov	WORD PTR [bp-6],ax	;NewDestinationYOrigin
; Line 115
	mov	ax,WORD PTR [bp-4]	;NewDestinationXOrigin
	sub	ax,WORD PTR [bp+12]	;nXOriginDest
	mov	WORD PTR [bp-8],ax	;DestinationDeltaX
; Line 116
	mov	ax,WORD PTR [bp-6]	;NewDestinationYOrigin
	sub	ax,WORD PTR [bp+14]	;nYOriginDest
	mov	WORD PTR [bp-10],ax	;DestinationDeltaY
; Line 118
	mov	ax,WORD PTR [bp-52]
	sub	ax,WORD PTR [bp-56]	;ClippedRectangle
	mov	WORD PTR [bp-12],ax	;Width
; Line 119
	mov	ax,WORD PTR [bp-50]
	sub	ax,WORD PTR [bp-54]
	mov	WORD PTR [bp-14],ax	;Height
; Line 121
	mov	ax,WORD PTR [bp+16]	;pBits
	mov	dx,WORD PTR [bp+18]
	mov	WORD PTR [bp-26],ax	;pSource
	mov	WORD PTR [bp-24],dx
; Line 123
	mov	ax,WORD PTR [bp-8]	;DestinationDeltaX
	mov	WORD PTR [bp-16],ax	;NewSourceXOrigin
; Line 124
	mov	ax,WORD PTR [bp-10]	;DestinationDeltaY
	mov	WORD PTR [bp-18],ax	;NewSourceYOrigin
; Line 128
	mov	ax,WORD PTR [bp-14]	;Height
	add	ax,WORD PTR [bp-10]	;DestinationDeltaY
	cwd	
	mov	cx,ax
	mov	ax,WORD PTR [bp+30]	;SourceHeight
	mov	bx,dx
	cwd	
	sub	ax,cx
	sbb	dx,bx
	push	dx
	push	ax
	les	bx,DWORD PTR [bp+20]	;pBitmapInfo
	mov	ax,WORD PTR es:[bx+4]
	les	bx,DWORD PTR [bp+20]	;pBitmapInfo
	mul	WORD PTR es:[bx+14]
	add	ax,31	;001fH
	and	ax,-25	;ffe7H
	shr	ax,3
	push	0
	push	ax
	call	__aNlmul
	mov	cx,ax
	mov	ax,WORD PTR [bp-8]	;DestinationDeltaX
	mov	bx,dx
	cwd	
	add	cx,ax
	adc	bx,dx
	mov	ax,cx
	sub	dx,dx
	mov	cx,ax
	add	WORD PTR [bp-26],cx	;pSource
	adc	dx,bx
	mov	cx,OFFSET __AHSHIFT
	shl	dx,cl
	add	WORD PTR [bp-24],dx
; Line 133
	mov	ax,WORD PTR [bp+10]
	mov	WORD PTR [bp-28],ax	;DestSelector
; Line 135
	cmp	WORD PTR [bp-20],0	;Orientation
	jl	$JCC416
	jmp	$I4259
$JCC416:
; Line 136
; Line 139
	neg	WORD PTR [bp-60]	;DestinationScanDelta
	adc	WORD PTR [bp-58],0
	neg	WORD PTR [bp-58]
; Line 143
	mov	ax,WORD PTR [bp-14]	;Height
	add	ax,WORD PTR [bp-6]	;NewDestinationYOrigin
	dec	ax
	cwd	
	push	dx
	push	ax
	les	bx,DWORD PTR [bp+4]	;pBufferHeader
	mov	ax,WORD PTR es:[bx+4]
	les	bx,DWORD PTR [bp+4]	;pBufferHeader
	mul	WORD PTR es:[bx+14]
	add	ax,31	;001fH
	and	ax,-25	;ffe7H
	shr	ax,3
	push	0
	push	ax
	call	__aNulmul
	mov	cx,ax
	mov	ax,WORD PTR [bp-4]	;NewDestinationXOrigin
	mov	bx,dx
	cwd	
	add	cx,ax
	adc	bx,dx
	mov	WORD PTR [bp-32],cx	;DestOffset
	mov	WORD PTR [bp-30],bx
; Line 144
; Line 145
	jmp	$I4266
$I4259:
; Line 146
; Line 152
	mov	ax,WORD PTR [bp-14]	;Height
	add	ax,WORD PTR [bp-6]	;NewDestinationYOrigin
	cwd	
	mov	cx,ax
	mov	ax,WORD PTR [bp-22]	;DestinationHeight
	mov	bx,dx
	cwd	
	sub	ax,cx
	sbb	dx,bx
	push	dx
	push	ax
	les	bx,DWORD PTR [bp+4]	;pBufferHeader
	mov	ax,WORD PTR es:[bx+4]
	les	bx,DWORD PTR [bp+4]	;pBufferHeader
	mul	WORD PTR es:[bx+14]
	add	ax,31	;001fH
	and	ax,-25	;ffe7H
	shr	ax,3
	push	0
	push	ax
	call	__aNulmul
	mov	cx,ax
	mov	ax,WORD PTR [bp-4]	;NewDestinationXOrigin
	mov	bx,dx
	cwd	
	add	cx,ax
	adc	bx,dx
	mov	WORD PTR [bp-32],cx	;DestOffset
	mov	WORD PTR [bp-30],bx
; Line 153
$I4266:
; Line 158
	push	WORD PTR [bp-28]	;DestSelector
	push	WORD PTR [bp-30]
	push	WORD PTR [bp-32]	;DestOffset
	push	WORD PTR [bp-24]
	push	WORD PTR [bp-26]	;pSource
	mov	ax,WORD PTR [bp-12]	;Width
	cwd	
	push	dx
	push	ax
	mov	ax,WORD PTR [bp-14]	;Height
	cwd	
	push	dx
	push	ax
	push	WORD PTR [bp-58]
	push	WORD PTR [bp-60]	;DestinationScanDelta
	les	bx,DWORD PTR [bp+20]	;pBitmapInfo
	mov	ax,WORD PTR es:[bx+4]
	les	bx,DWORD PTR [bp+20]	;pBitmapInfo
	mul	WORD PTR es:[bx+14]
	add	ax,31	;001fH
	and	ax,-25	;ffe7H
	shr	ax,3
	push	0
	push	ax
	mov	al,BYTE PTR [bp+34]	;TransparentColor
	push	ax
	call	FAR PTR TRANSCOPYDIBBITS
; Line 160
	mov	WORD PTR [bp-2],1	;ReturnValue
; Line 161
; Line 163
$I4244:
	mov	ax,WORD PTR [bp-2]	;ReturnValue
	jmp	$EX4212
; Line 164
$EX4212:
	pop	si
	pop	di
	leave	
	ret	

_TranspDIBits	ENDP
	PUBLIC	_TransparentDIBits
_TransparentDIBits	PROC NEAR
; Line 178
	push	bp
	mov	bp,sp
	mov	ax,64	;0040H
	call	__aNchkstk
	push	di
	push	si
;	ReturnValue = -2
;	NewDestinationXOrigin = -4
;	NewDestinationYOrigin = -6
;	DestinationDeltaX = -8
;	DestinationDeltaY = -10
;	Width = -12
;	Height = -14
;	NewSourceXOrigin = -16
;	NewSourceYOrigin = -18
;	Orientation = -20
;	DestinationHeight = -22
;	SourceWidth = -24
;	SourceHeight = -26
;	pSource = -30
;	DestSelector = -32
;	DestOffset = -36
;	SourceRectangle = -44
;	DestinationRectangle = -52
;	ClippedRectangle = -60
;	TransparentColor = 30
;	iUsage = 28
;	nYOriginSrc = 26
;	nXOriginSrc = 24
;	pBitmapInfo = 20
;	pBits = 16
;	nYOriginDest = 14
;	nXOriginDest = 12
;	pBufferBits = 8
;	pBufferHeader = 4
; Line 179
	mov	WORD PTR [bp-2],0	;ReturnValue
; Line 189
	mov	WORD PTR [bp-20],1	;Orientation
; Line 190
	les	bx,DWORD PTR [bp+4]	;pBufferHeader
	mov	ax,WORD PTR es:[bx+8]
	mov	WORD PTR [bp-22],ax	;DestinationHeight
; Line 191
	les	bx,DWORD PTR [bp+20]	;pBitmapInfo
	mov	ax,WORD PTR es:[bx+4]
	mov	WORD PTR [bp-24],ax	;SourceWidth
; Line 192
	les	bx,DWORD PTR [bp+20]	;pBitmapInfo
	mov	ax,WORD PTR es:[bx+8]
	mov	WORD PTR [bp-26],ax	;SourceHeight
; Line 198
	mov	ax,WORD PTR [bp+12]	;nXOriginDest
	mov	WORD PTR [bp-44],ax	;SourceRectangle
	mov	ax,WORD PTR [bp+14]	;nYOriginDest
	mov	WORD PTR [bp-42],ax
; Line 199
	mov	ax,WORD PTR [bp-24]	;SourceWidth
	add	ax,WORD PTR [bp+12]	;nXOriginDest
	mov	WORD PTR [bp-40],ax
	mov	ax,WORD PTR [bp-26]	;SourceHeight
	add	ax,WORD PTR [bp+14]	;nYOriginDest
	mov	WORD PTR [bp-38],ax
; Line 205
	cmp	WORD PTR [bp-22],0	;DestinationHeight
	jl	$JCC727
	jmp	$I4313
$JCC727:
; Line 206
; Line 207
	mov	WORD PTR [bp-20],-1	;ffffH	;Orientation
; Line 208
	neg	WORD PTR [bp-22]	;DestinationHeight
; Line 209
; Line 211
$I4313:
	mov	WORD PTR [bp-50],0
; Line 212
	mov	WORD PTR [bp-52],0	;DestinationRectangle
; Line 213
	mov	ax,WORD PTR [bp-22]	;DestinationHeight
	mov	WORD PTR [bp-46],ax
; Line 214
	les	bx,DWORD PTR [bp+4]	;pBufferHeader
	mov	ax,WORD PTR es:[bx+4]
	mov	WORD PTR [bp-48],ax
; Line 219
	lea	ax,WORD PTR [bp-60]	;ClippedRectangle
	push	ss
	push	ax
	lea	cx,WORD PTR [bp-44]	;SourceRectangle
	push	ss
	push	cx
	lea	cx,WORD PTR [bp-52]	;DestinationRectangle
	push	ss
	push	cx
	call	FAR PTR INTERSECTRECT
	cmp	ax,0
	jne	$JCC789
	jmp	$I4316
$JCC789:
; Line 220
;	DestinationScanDelta = -64
; Line 222
	les	bx,DWORD PTR [bp+4]	;pBufferHeader
	mov	ax,WORD PTR es:[bx+4]
	les	bx,DWORD PTR [bp+4]	;pBufferHeader
	mul	WORD PTR es:[bx+14]
	add	ax,31	;001fH
	and	ax,-25	;ffe7H
	shr	ax,3
	mov	WORD PTR [bp-64],ax	;DestinationScanDelta
	mov	WORD PTR [bp-62],0
; Line 225
	mov	ax,WORD PTR [bp-60]	;ClippedRectangle
	mov	WORD PTR [bp-4],ax	;NewDestinationXOrigin
; Line 226
	mov	ax,WORD PTR [bp-58]
	mov	WORD PTR [bp-6],ax	;NewDestinationYOrigin
; Line 228
	mov	ax,WORD PTR [bp-4]	;NewDestinationXOrigin
	sub	ax,WORD PTR [bp+12]	;nXOriginDest
	mov	WORD PTR [bp-8],ax	;DestinationDeltaX
; Line 229
	mov	ax,WORD PTR [bp-6]	;NewDestinationYOrigin
	sub	ax,WORD PTR [bp+14]	;nYOriginDest
	mov	WORD PTR [bp-10],ax	;DestinationDeltaY
; Line 231
	mov	ax,WORD PTR [bp-56]
	sub	ax,WORD PTR [bp-60]	;ClippedRectangle
	mov	WORD PTR [bp-12],ax	;Width
; Line 232
	mov	ax,WORD PTR [bp-54]
	sub	ax,WORD PTR [bp-58]
	mov	WORD PTR [bp-14],ax	;Height
; Line 234
	mov	ax,WORD PTR [bp+16]	;pBits
	mov	dx,WORD PTR [bp+18]
	mov	WORD PTR [bp-30],ax	;pSource
	mov	WORD PTR [bp-28],dx
; Line 236
	mov	ax,WORD PTR [bp-8]	;DestinationDeltaX
	mov	WORD PTR [bp-16],ax	;NewSourceXOrigin
; Line 237
	mov	ax,WORD PTR [bp-10]	;DestinationDeltaY
	mov	WORD PTR [bp-18],ax	;NewSourceYOrigin
; Line 241
	mov	ax,WORD PTR [bp-14]	;Height
	add	ax,WORD PTR [bp-10]	;DestinationDeltaY
	cwd	
	mov	cx,ax
	mov	ax,WORD PTR [bp-26]	;SourceHeight
	mov	bx,dx
	cwd	
	sub	ax,cx
	sbb	dx,bx
	push	dx
	push	ax
	les	bx,DWORD PTR [bp+20]	;pBitmapInfo
	mov	ax,WORD PTR es:[bx+4]
	les	bx,DWORD PTR [bp+20]	;pBitmapInfo
	mul	WORD PTR es:[bx+14]
	add	ax,31	;001fH
	and	ax,-25	;ffe7H
	shr	ax,3
	push	0
	push	ax
	call	__aNlmul
	mov	cx,ax
	mov	ax,WORD PTR [bp-8]	;DestinationDeltaX
	mov	bx,dx
	cwd	
	add	cx,ax
	adc	bx,dx
	mov	ax,cx
	sub	dx,dx
	mov	cx,ax
	add	WORD PTR [bp-30],cx	;pSource
	adc	dx,bx
	mov	cx,OFFSET __AHSHIFT
	shl	dx,cl
	add	WORD PTR [bp-28],dx
; Line 246
	mov	ax,WORD PTR [bp+10]
	mov	WORD PTR [bp-32],ax	;DestSelector
; Line 248
	cmp	WORD PTR [bp-20],0	;Orientation
	jl	$JCC988
	jmp	$I4331
$JCC988:
; Line 249
; Line 252
	neg	WORD PTR [bp-64]	;DestinationScanDelta
	adc	WORD PTR [bp-62],0
	neg	WORD PTR [bp-62]
; Line 256
	mov	ax,WORD PTR [bp-14]	;Height
	add	ax,WORD PTR [bp-6]	;NewDestinationYOrigin
	dec	ax
	cwd	
	push	dx
	push	ax
	les	bx,DWORD PTR [bp+4]	;pBufferHeader
	mov	ax,WORD PTR es:[bx+4]
	les	bx,DWORD PTR [bp+4]	;pBufferHeader
	mul	WORD PTR es:[bx+14]
	add	ax,31	;001fH
	and	ax,-25	;ffe7H
	shr	ax,3
	push	0
	push	ax
	call	__aNulmul
	mov	cx,ax
	mov	ax,WORD PTR [bp-4]	;NewDestinationXOrigin
	mov	bx,dx
	cwd	
	add	cx,ax
	adc	bx,dx
	mov	WORD PTR [bp-36],cx	;DestOffset
	mov	WORD PTR [bp-34],bx
; Line 257
; Line 258
	jmp	$I4338
$I4331:
; Line 259
; Line 265
	mov	ax,WORD PTR [bp-14]	;Height
	add	ax,WORD PTR [bp-6]	;NewDestinationYOrigin
	cwd	
	mov	cx,ax
	mov	ax,WORD PTR [bp-22]	;DestinationHeight
	mov	bx,dx
	cwd	
	sub	ax,cx
	sbb	dx,bx
	push	dx
	push	ax
	les	bx,DWORD PTR [bp+4]	;pBufferHeader
	mov	ax,WORD PTR es:[bx+4]
	les	bx,DWORD PTR [bp+4]	;pBufferHeader
	mul	WORD PTR es:[bx+14]
	add	ax,31	;001fH
	and	ax,-25	;ffe7H
	shr	ax,3
	push	0
	push	ax
	call	__aNulmul
	mov	cx,ax
	mov	ax,WORD PTR [bp-4]	;NewDestinationXOrigin
	mov	bx,dx
	cwd	
	add	cx,ax
	adc	bx,dx
	mov	WORD PTR [bp-36],cx	;DestOffset
	mov	WORD PTR [bp-34],bx
; Line 266
$I4338:
; Line 271
	push	WORD PTR [bp-32]	;DestSelector
	push	WORD PTR [bp-34]
	push	WORD PTR [bp-36]	;DestOffset
	push	WORD PTR [bp-28]
	push	WORD PTR [bp-30]	;pSource
	mov	ax,WORD PTR [bp-12]	;Width
	cwd	
	push	dx
	push	ax
	mov	ax,WORD PTR [bp-14]	;Height
	cwd	
	push	dx
	push	ax
	push	WORD PTR [bp-62]
	push	WORD PTR [bp-64]	;DestinationScanDelta
	les	bx,DWORD PTR [bp+20]	;pBitmapInfo
	mov	ax,WORD PTR es:[bx+4]
	les	bx,DWORD PTR [bp+20]	;pBitmapInfo
	mul	WORD PTR es:[bx+14]
	add	ax,31	;001fH
	and	ax,-25	;ffe7H
	shr	ax,3
	push	0
	push	ax
	mov	al,BYTE PTR [bp+30]	;TransparentColor
	push	ax
	call	FAR PTR TRANSCOPYDIBBITS
; Line 273
	mov	WORD PTR [bp-2],1	;ReturnValue
; Line 274
; Line 276
$I4316:
	mov	ax,WORD PTR [bp-2]	;ReturnValue
	jmp	$EX4287
; Line 277
$EX4287:
	pop	si
	pop	di
	leave	
	ret	

_TransparentDIBits	ENDP
	PUBLIC	_CopyDIBits
_CopyDIBits	PROC NEAR
; Line 286
	push	bp
	mov	bp,sp
	mov	ax,64	;0040H
	call	__aNchkstk
	push	di
	push	si
;	ReturnValue = -2
;	NewDestinationXOrigin = -4
;	NewDestinationYOrigin = -6
;	DestinationDeltaX = -8
;	DestinationDeltaY = -10
;	Width = -12
;	Height = -14
;	NewSourceXOrigin = -16
;	NewSourceYOrigin = -18
;	Orientation = -20
;	DestinationHeight = -22
;	SourceWidth = -24
;	SourceHeight = -26
;	pSource = -30
;	DestSelector = -32
;	DestOffset = -36
;	SourceRectangle = -44
;	DestinationRectangle = -52
;	ClippedRectangle = -60
;	iUsage = 28
;	nYOriginSrc = 26
;	nXOriginSrc = 24
;	pBitmapInfo = 20
;	pBits = 16
;	nYOriginDest = 14
;	nXOriginDest = 12
;	pBufferBits = 8
;	pBufferHeader = 4
; Line 287
	mov	WORD PTR [bp-2],0	;ReturnValue
; Line 297
	mov	WORD PTR [bp-20],1	;Orientation
; Line 298
	les	bx,DWORD PTR [bp+4]	;pBufferHeader
	mov	ax,WORD PTR es:[bx+8]
	mov	WORD PTR [bp-22],ax	;DestinationHeight
; Line 299
	les	bx,DWORD PTR [bp+20]	;pBitmapInfo
	mov	ax,WORD PTR es:[bx+4]
	mov	WORD PTR [bp-24],ax	;SourceWidth
; Line 300
	les	bx,DWORD PTR [bp+20]	;pBitmapInfo
	mov	ax,WORD PTR es:[bx+8]
	mov	WORD PTR [bp-26],ax	;SourceHeight
; Line 306
	mov	ax,WORD PTR [bp+12]	;nXOriginDest
	mov	WORD PTR [bp-44],ax	;SourceRectangle
	mov	ax,WORD PTR [bp+14]	;nYOriginDest
	mov	WORD PTR [bp-42],ax
; Line 307
	mov	ax,WORD PTR [bp-24]	;SourceWidth
	add	ax,WORD PTR [bp+12]	;nXOriginDest
	mov	WORD PTR [bp-40],ax
	mov	ax,WORD PTR [bp-26]	;SourceHeight
	add	ax,WORD PTR [bp+14]	;nYOriginDest
	mov	WORD PTR [bp-38],ax
; Line 313
	cmp	WORD PTR [bp-22],0	;DestinationHeight
	jl	$JCC1299
	jmp	$I4384
$JCC1299:
; Line 314
; Line 315
	mov	WORD PTR [bp-20],-1	;ffffH	;Orientation
; Line 316
	neg	WORD PTR [bp-22]	;DestinationHeight
; Line 317
; Line 319
$I4384:
	mov	WORD PTR [bp-50],0
; Line 320
	mov	WORD PTR [bp-52],0	;DestinationRectangle
; Line 321
	mov	ax,WORD PTR [bp-22]	;DestinationHeight
	mov	WORD PTR [bp-46],ax
; Line 322
	les	bx,DWORD PTR [bp+4]	;pBufferHeader
	mov	ax,WORD PTR es:[bx+4]
	mov	WORD PTR [bp-48],ax
; Line 327
	lea	ax,WORD PTR [bp-60]	;ClippedRectangle
	push	ss
	push	ax
	lea	cx,WORD PTR [bp-44]	;SourceRectangle
	push	ss
	push	cx
	lea	cx,WORD PTR [bp-52]	;DestinationRectangle
	push	ss
	push	cx
	call	FAR PTR INTERSECTRECT
	cmp	ax,0
	jne	$JCC1361
	jmp	$I4387
$JCC1361:
; Line 328
;	DestinationScanDelta = -64
; Line 330
	les	bx,DWORD PTR [bp+4]	;pBufferHeader
	mov	ax,WORD PTR es:[bx+4]
	les	bx,DWORD PTR [bp+4]	;pBufferHeader
	mul	WORD PTR es:[bx+14]
	add	ax,31	;001fH
	and	ax,-25	;ffe7H
	shr	ax,3
	mov	WORD PTR [bp-64],ax	;DestinationScanDelta
	mov	WORD PTR [bp-62],0
; Line 333
	mov	ax,WORD PTR [bp-60]	;ClippedRectangle
	mov	WORD PTR [bp-4],ax	;NewDestinationXOrigin
; Line 334
	mov	ax,WORD PTR [bp-58]
	mov	WORD PTR [bp-6],ax	;NewDestinationYOrigin
; Line 336
	mov	ax,WORD PTR [bp-4]	;NewDestinationXOrigin
	sub	ax,WORD PTR [bp+12]	;nXOriginDest
	mov	WORD PTR [bp-8],ax	;DestinationDeltaX
; Line 337
	mov	ax,WORD PTR [bp-6]	;NewDestinationYOrigin
	sub	ax,WORD PTR [bp+14]	;nYOriginDest
	mov	WORD PTR [bp-10],ax	;DestinationDeltaY
; Line 339
	mov	ax,WORD PTR [bp-56]
	sub	ax,WORD PTR [bp-60]	;ClippedRectangle
	mov	WORD PTR [bp-12],ax	;Width
; Line 340
	mov	ax,WORD PTR [bp-54]
	sub	ax,WORD PTR [bp-58]
	mov	WORD PTR [bp-14],ax	;Height
; Line 342
	mov	ax,WORD PTR [bp+16]	;pBits
	mov	dx,WORD PTR [bp+18]
	mov	WORD PTR [bp-30],ax	;pSource
	mov	WORD PTR [bp-28],dx
; Line 344
	mov	ax,WORD PTR [bp-8]	;DestinationDeltaX
	mov	WORD PTR [bp-16],ax	;NewSourceXOrigin
; Line 345
	mov	ax,WORD PTR [bp-10]	;DestinationDeltaY
	mov	WORD PTR [bp-18],ax	;NewSourceYOrigin
; Line 349
	mov	ax,WORD PTR [bp-18]	;NewSourceYOrigin
	add	ax,WORD PTR [bp-14]	;Height
	cwd	
	mov	cx,ax
	mov	ax,WORD PTR [bp-26]	;SourceHeight
	mov	bx,dx
	cwd	
	sub	ax,cx
	sbb	dx,bx
	push	dx
	push	ax
	les	bx,DWORD PTR [bp+20]	;pBitmapInfo
	mov	ax,WORD PTR es:[bx+4]
	les	bx,DWORD PTR [bp+20]	;pBitmapInfo
	mul	WORD PTR es:[bx+14]
	add	ax,31	;001fH
	and	ax,-25	;ffe7H
	shr	ax,3
	push	0
	push	ax
	call	__aNlmul
	mov	cx,ax
	mov	ax,WORD PTR [bp-16]	;NewSourceXOrigin
	mov	bx,dx
	cwd	
	add	cx,ax
	adc	bx,dx
	mov	ax,cx
	sub	dx,dx
	mov	cx,ax
	add	WORD PTR [bp-30],cx	;pSource
	adc	dx,bx
	mov	cx,OFFSET __AHSHIFT
	shl	dx,cl
	add	WORD PTR [bp-28],dx
; Line 354
	mov	ax,WORD PTR [bp+10]
	mov	WORD PTR [bp-32],ax	;DestSelector
; Line 356
	cmp	WORD PTR [bp-20],0	;Orientation
	jl	$JCC1560
	jmp	$I4402
$JCC1560:
; Line 357
; Line 360
	neg	WORD PTR [bp-64]	;DestinationScanDelta
	adc	WORD PTR [bp-62],0
	neg	WORD PTR [bp-62]
; Line 364
	mov	ax,WORD PTR [bp-14]	;Height
	add	ax,WORD PTR [bp-6]	;NewDestinationYOrigin
	dec	ax
	cwd	
	push	dx
	push	ax
	les	bx,DWORD PTR [bp+4]	;pBufferHeader
	mov	ax,WORD PTR es:[bx+4]
	les	bx,DWORD PTR [bp+4]	;pBufferHeader
	mul	WORD PTR es:[bx+14]
	add	ax,31	;001fH
	and	ax,-25	;ffe7H
	shr	ax,3
	push	0
	push	ax
	call	__aNulmul
	mov	cx,ax
	mov	ax,WORD PTR [bp-4]	;NewDestinationXOrigin
	mov	bx,dx
	cwd	
	add	cx,ax
	adc	bx,dx
	mov	WORD PTR [bp-36],cx	;DestOffset
	mov	WORD PTR [bp-34],bx
; Line 365
; Line 366
	jmp	$I4409
$I4402:
; Line 367
; Line 373
	mov	ax,WORD PTR [bp-14]	;Height
	add	ax,WORD PTR [bp-6]	;NewDestinationYOrigin
	cwd	
	mov	cx,ax
	mov	ax,WORD PTR [bp-22]	;DestinationHeight
	mov	bx,dx
	cwd	
	sub	ax,cx
	sbb	dx,bx
	push	dx
	push	ax
	les	bx,DWORD PTR [bp+4]	;pBufferHeader
	mov	ax,WORD PTR es:[bx+4]
	les	bx,DWORD PTR [bp+4]	;pBufferHeader
	mul	WORD PTR es:[bx+14]
	add	ax,31	;001fH
	and	ax,-25	;ffe7H
	shr	ax,3
	push	0
	push	ax
	call	__aNulmul
	mov	cx,ax
	mov	ax,WORD PTR [bp-4]	;NewDestinationXOrigin
	mov	bx,dx
	cwd	
	add	cx,ax
	adc	bx,dx
	mov	WORD PTR [bp-36],cx	;DestOffset
	mov	WORD PTR [bp-34],bx
; Line 374
$I4409:
; Line 378
	push	WORD PTR [bp-32]	;DestSelector
	push	WORD PTR [bp-34]
	push	WORD PTR [bp-36]	;DestOffset
	push	WORD PTR [bp-28]
	push	WORD PTR [bp-30]	;pSource
	mov	ax,WORD PTR [bp-12]	;Width
	cwd	
	push	dx
	push	ax
	mov	ax,WORD PTR [bp-14]	;Height
	cwd	
	push	dx
	push	ax
	push	WORD PTR [bp-62]
	push	WORD PTR [bp-64]	;DestinationScanDelta
	les	bx,DWORD PTR [bp+20]	;pBitmapInfo
	mov	ax,WORD PTR es:[bx+4]
	les	bx,DWORD PTR [bp+20]	;pBitmapInfo
	mul	WORD PTR es:[bx+14]
	add	ax,31	;001fH
	and	ax,-25	;ffe7H
	shr	ax,3
	push	0
	push	ax
	call	FAR PTR COPYDIBBITS
; Line 381
	mov	WORD PTR [bp-2],1	;ReturnValue
; Line 382
; Line 384
$I4387:
	mov	ax,WORD PTR [bp-2]	;ReturnValue
	jmp	$EX4358
; Line 385
$EX4358:
	pop	si
	pop	di
	leave	
	ret	

_CopyDIBits	ENDP
_TEXT	ENDS
END
