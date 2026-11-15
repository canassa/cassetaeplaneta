;	Static Name Aliases
;
;	$S7070_szAppName	EQU	szAppName
;	$S7071_hInstApp	EQU	hInstApp
;	$S7072_hwndApp	EQU	hwndApp
;	$S7073_hpalApp	EQU	hpalApp
;	$S7074_fAppActive	EQU	fAppActive
;	$S7272__aag	EQU	_aag
	TITLE   d:\lc\demo\mech.cpp
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
XIFCB	SEGMENT  WORD PUBLIC 'DATA'
XIFCB	ENDS
XIFU	SEGMENT  WORD PUBLIC 'DATA'
XIFU	ENDS
XIFL	SEGMENT  WORD PUBLIC 'DATA'
XIFL	ENDS
XIFM	SEGMENT  WORD PUBLIC 'DATA'
XIFM	ENDS
XIFCE	SEGMENT  WORD PUBLIC 'DATA'
XIFCE	ENDS
DGROUP	GROUP	CONST, _BSS, _DATA
	ASSUME DS: DGROUP, SS: DGROUP
PUBLIC  ?MechFrames@@3QAHA
PUBLIC  ??_7actor@@6Bmoveable@@@
PUBLIC  ?MechWidth@@3QAHA
PUBLIC  ??_7actor@@6Bobject@@@
PUBLIC  ?MechHeight@@3QAHA
PUBLIC  ??_8actor@@7Bmoveable@@@
PUBLIC  ??_8actor@@7Banimated@@@
PUBLIC  ??_7animated@@6B@
PUBLIC  ??_8animated@@7B@
PUBLIC  ?pBuffer@@3PEXE
PUBLIC  ??_7sprite@@6B@
PUBLIC  ?Buffer@@3PBUHDC__@@B
PUBLIC  ?pBackBuffer@@3PEXE
PUBLIC  ??_7screen@@6B@
PUBLIC  ?BackBuffer@@3PBUHDC__@@B
PUBLIC  ?LP@@3Upal@@A
PUBLIC  ??_7object@@6B@
PUBLIC  ?gbmOldMonoBitmap@@3PBUHBITMAP__@@B
PUBLIC  ?gBackOldMonoBitmap@@3PBUHBITMAP__@@B
PUBLIC  ??_7mech@@6Bmoveable@@@
PUBLIC  ??_7mech@@6Bobject@@@
PUBLIC  ??_7moveable@@6B0@@
PUBLIC  ??_8mech@@7Bmoveable@@@
PUBLIC  ??_7moveable@@6Bobject@@@
PUBLIC  ??_8mech@@7Banimated@@@
PUBLIC  ??_8moveable@@7B@
PUBLIC  ??_7player@@6Bmoveable@@@
PUBLIC  ?InicioBufferX@@3HA
PUBLIC  ??_7player@@6Bobject@@@
PUBLIC  ?InicioBufferY@@3HA
PUBLIC  ??_8player@@7Bmoveable@@@
PUBLIC  ?Scrollx@@3HA
PUBLIC  ??_8player@@7Banimated@@@
PUBLIC  ?Scrolly@@3HA
PUBLIC  ?SpriteOrder@@3HA
PUBLIC  ?MechNames@@3QAPADA
EXTRN	__acrtused:ABS
EXTRN	_ClearSystemPalette:NEAR
EXTRN	DEFWINDOWPROC:FAR
EXTRN	??_I@YCXPAXIHP6CX0@Z@Z:NEAR
EXTRN	_DibOpenFile:NEAR
EXTRN	LOADICON:FAR
EXTRN	?TransparentDIBits@@YAHPEUtagBITMAPINFO@@PIXHHPFXPFU1@HHHE@Z:NEAR
EXTRN	DIALOGBOX:FAR
EXTRN	SHOWWINDOW:FAR
EXTRN	BEGINPAINT:FAR
EXTRN	POSTMESSAGE:FAR
EXTRN	GETMODULEHANDLE:FAR
EXTRN	ENDPAINT:FAR
EXTRN	?InitMove@moveable@@UACXPBUHWND__@@HHPAVscreen@@@Z:NEAR
EXTRN	WINGCREATEDC:FAR
EXTRN	GETPROCADDRESS:FAR
EXTRN	?EndMove@moveable@@UACXPBUHWND__@@PBUHDC__@@PAVscreen@@@Z:NEAR
EXTRN	__aNchkstk:NEAR
EXTRN	DELETEDC:FAR
EXTRN	WINGCREATEBITMAP:FAR
EXTRN	?InitHMove@moveable@@UACXPBUHWND__@@PAVscreen@@W4MVDIR@@@Z:NEAR
EXTRN	MESSAGEBOX:FAR
EXTRN	ENDDIALOG:FAR
EXTRN	?InitVMove@moveable@@UACXPBUHWND__@@PAVscreen@@W4MVDIR@@@Z:NEAR
EXTRN	POSTQUITMESSAGE:FAR
EXTRN	INVALIDATERECT:FAR
EXTRN	?EndMove@moveable@@UACXPBUHWND__@@PAVscreen@@@Z:NEAR
EXTRN	?Move1Step@moveable@@UACXPBUHWND__@@PAVscreen@@@Z:NEAR
EXTRN	??2@YAPAXI@Z:NEAR
EXTRN	LOADCURSOR:FAR
EXTRN	??3@YAXPAX@Z:NEAR
EXTRN	SELECTPALETTE:FAR
EXTRN	CREATEWINDOW:FAR
EXTRN	REALIZEPALETTE:FAR
EXTRN	GETDC:FAR
EXTRN	RELEASEDC:FAR
EXTRN	PEEKMESSAGE:FAR
EXTRN	BITBLT:FAR
EXTRN	REGISTERCLASS:FAR
EXTRN	WAITMESSAGE:FAR
EXTRN	DELETEOBJECT:FAR
EXTRN	?Init@screen@@UACXPBUHWND__@@@Z:NEAR
EXTRN	WINGBITBLT:FAR
EXTRN	SELECTOBJECT:FAR
EXTRN	PATBLT:FAR
EXTRN	??_H@YCXPAXIHP6CX0@Z@Z:NEAR
EXTRN	TRANSLATEMESSAGE:FAR
EXTRN	DISPATCHMESSAGE:FAR
EXTRN	_SetSystemTimer:DWORD
EXTRN	_KillSystemTimer:DWORD
EXTRN	?TransparentColor@@3EA:BYTE
EXTRN	?ObjectList@@3PAVobject_list@@A:WORD
_DATA      SEGMENT
$S7070_szAppName	DB	'WinG Sprite Demo',  00H
	ORG	$+1
?pBuffer@@3PEXE	DD	00H
?Buffer@@3PBUHDC__@@B	DW	00H
?pBackBuffer@@3PEXE	DD	00H
?BackBuffer@@3PBUHDC__@@B	DW	00H
?LP@@3Upal@@A	DW	0300H
	DW	0100H
 	DB	1024 DUP(0)

?gbmOldMonoBitmap@@3PBUHBITMAP__@@B	DW	00H
?gBackOldMonoBitmap@@3PBUHBITMAP__@@B	DW	00H
?InicioBufferX@@3HA	DW	00H
?InicioBufferY@@3HA	DW	00H
?Scrollx@@3HA	DW	00H
?Scrolly@@3HA	DW	00H
?SpriteOrder@@3HA	DW	01H
$SG7102	DB	'Mech2.bmp',  00H
$SG7103	DB	'Mechint.bmp',  00H
$SG7104	DB	'Mechins.bmp',  00H
?MechNames@@3QAPADA	DW	DGROUP:$SG7102
	DW	DGROUP:$SG7103
	DW	DGROUP:$SG7104
?MechFrames@@3QAHA	DW	02H
	DW	01H
	DW	01H
?MechWidth@@3QAHA	DW	019H
	DW	0140H
	DW	0140H
?MechHeight@@3QAHA	DW	019H
	DW	0c8H
	DW	0c8H
$SG7153	DB	'AppIcon',  00H
$SG7159	DB	'Mechback.bmp',  00H
$SG7192	DB	'O aplicativo j',  0e1H, ' est',  0e1H, ' aberto !!!',  00H
$SG7201	DB	'USER',  00H
$SG7206	DB	'USER',  00H
$SG7263	DB	'AppAbout',  00H
_DATA      ENDS
XIFU      SEGMENT
$S7272__aag	DD	_aaf
XIFU      ENDS
_DATA      SEGMENT
	ORG	$-1202
??_7sprite@@6B@	DW	?Frame@sprite@@UACPEUtagBITMAPINFOHEADER@@H@Z
	ORG	$-2
??_7object@@6B@	DW	?Paint@object@@UACXPAVscreen@@@Z
	DW	?Hide@object@@UACXPBUHDC__@@PAVscreen@@@Z
	DW	?Show@object@@UACXPBUHDC__@@PAVscreen@@@Z
	DW	?NextFrame@object@@UACPEUtagBITMAPINFOHEADER@@XZ
	DW	?PreviousFrame@object@@UACPEUtagBITMAPINFOHEADER@@XZ
	ORG	$-10
??_7actor@@6Bmoveable@@@	DW	?Paint@moveable@@UACXHHPAVscreen@@@Z
	DW	?InitMove@moveable@@UACXPBUHWND__@@HHPAVscreen@@@Z
	DW	?EndMove@moveable@@UACXPBUHWND__@@PAVscreen@@@Z
	DW	?EndMove@moveable@@UACXPBUHWND__@@PBUHDC__@@PAVscreen@@@Z
	DW	?InitHMove@moveable@@UACXPBUHWND__@@PAVscreen@@W4MVDIR@@@Z
	DW	?InitVMove@moveable@@UACXPBUHWND__@@PAVscreen@@W4MVDIR@@@Z
	DW	?Move1Step@actor@@UACXPBUHWND__@@PAVscreen@@@Z
	ORG	$-14
??_7actor@@6Bobject@@@	DW	?Paint@object@@UACXPAVscreen@@@Z
	DW	?Hide@object@@UACXPBUHDC__@@PAVscreen@@@Z
	DW	?Show@moveable@@$4PPPPPPPO@1ACXPBUHDC__@@PAVscreen@@@Z
	DW	?NextFrame@animated@@UACPEUtagBITMAPINFOHEADER@@XZ
	DW	?PreviousFrame@animated@@UACPEUtagBITMAPINFOHEADER@@XZ
	ORG	$-10
??_8actor@@7Bmoveable@@@	DW	0fffeH
	DW	036H
	ORG	$-4
??_8actor@@7Banimated@@@	DW	00H
	DW	04H
	ORG	$-4
??_7moveable@@6B0@@	DW	?Paint@moveable@@UACXHHPAVscreen@@@Z
	DW	?InitMove@moveable@@UACXPBUHWND__@@HHPAVscreen@@@Z
	DW	?EndMove@moveable@@UACXPBUHWND__@@PAVscreen@@@Z
	DW	?EndMove@moveable@@UACXPBUHWND__@@PBUHDC__@@PAVscreen@@@Z
	DW	?InitHMove@moveable@@UACXPBUHWND__@@PAVscreen@@W4MVDIR@@@Z
	DW	?InitVMove@moveable@@UACXPBUHWND__@@PAVscreen@@W4MVDIR@@@Z
	DW	?Move1Step@moveable@@UACXPBUHWND__@@PAVscreen@@@Z
	ORG	$-14
??_7moveable@@6Bobject@@@	DW	?Paint@object@@UACXPAVscreen@@@Z
	DW	?Hide@object@@UACXPBUHDC__@@PAVscreen@@@Z
	DW	?Show@moveable@@$4PPPPPPPO@A@ACXPBUHDC__@@PAVscreen@@@Z
	DW	?NextFrame@object@@UACPEUtagBITMAPINFOHEADER@@XZ
	DW	?PreviousFrame@object@@UACPEUtagBITMAPINFOHEADER@@XZ
	ORG	$-10
??_8moveable@@7B@	DW	0fffeH
	DW	034H
	ORG	$-4
??_7player@@6Bmoveable@@@	DW	?Paint@moveable@@UACXHHPAVscreen@@@Z
	DW	?InitMove@moveable@@UACXPBUHWND__@@HHPAVscreen@@@Z
	DW	?EndMove@moveable@@UACXPBUHWND__@@PAVscreen@@@Z
	DW	?EndMove@moveable@@UACXPBUHWND__@@PBUHDC__@@PAVscreen@@@Z
	DW	?InitHMove@moveable@@UACXPBUHWND__@@PAVscreen@@W4MVDIR@@@Z
	DW	?InitVMove@moveable@@UACXPBUHWND__@@PAVscreen@@W4MVDIR@@@Z
	DW	?Move1Step@actor@@UACXPBUHWND__@@PAVscreen@@@Z
	ORG	$-14
??_7player@@6Bobject@@@	DW	?Paint@object@@UACXPAVscreen@@@Z
	DW	?Hide@object@@UACXPBUHDC__@@PAVscreen@@@Z
	DW	?Show@moveable@@$4PPPPPPPO@7ACXPBUHDC__@@PAVscreen@@@Z
	DW	?NextFrame@animated@@W5ACPEUtagBITMAPINFOHEADER@@XZ
	DW	?PreviousFrame@animated@@W5ACPEUtagBITMAPINFOHEADER@@XZ
	ORG	$-10
??_8player@@7Bmoveable@@@	DW	0fffeH
	DW	03cH
	ORG	$-4
??_8player@@7Banimated@@@	DW	00H
	DW	0aH
	ORG	$-4
??_7animated@@6B@	DW	?Paint@object@@UACXPAVscreen@@@Z
	DW	?Hide@object@@UACXPBUHDC__@@PAVscreen@@@Z
	DW	?Show@object@@UACXPBUHDC__@@PAVscreen@@@Z
	DW	?NextFrame@animated@@$4PPPPPPPO@A@ACPEUtagBITMAPINFOHEADER@@XZ
	DW	?PreviousFrame@animated@@$4PPPPPPPO@A@ACPEUtagBITMAPINFOHEADER@@XZ
	ORG	$-10
??_8animated@@7B@	DW	00H
	DW	04H
	ORG	$-4
??_7mech@@6Bmoveable@@@	DW	?Paint@moveable@@UACXHHPAVscreen@@@Z
	DW	?InitMove@mech@@UACXPBUHWND__@@HHPAVscreen@@@Z
	DW	?EndMove@moveable@@UACXPBUHWND__@@PAVscreen@@@Z
	DW	?EndMove@mech@@UACXPBUHWND__@@PBUHDC__@@PAVscreen@@@Z
	DW	?InitHMove@moveable@@UACXPBUHWND__@@PAVscreen@@W4MVDIR@@@Z
	DW	?InitVMove@moveable@@UACXPBUHWND__@@PAVscreen@@W4MVDIR@@@Z
	DW	?Move1Step@actor@@UACXPBUHWND__@@PAVscreen@@@Z
	ORG	$-14
??_7mech@@6Bobject@@@	DW	?Paint@object@@UACXPAVscreen@@@Z
	DW	?Hide@object@@UACXPBUHDC__@@PAVscreen@@@Z
	DW	?Show@moveable@@$4PPPPPPPO@7ACXPBUHDC__@@PAVscreen@@@Z
	DW	?NextFrame@animated@@W5ACPEUtagBITMAPINFOHEADER@@XZ
	DW	?PreviousFrame@animated@@W5ACPEUtagBITMAPINFOHEADER@@XZ
	ORG	$-10
??_8mech@@7Bmoveable@@@	DW	0fffeH
	DW	03cH
	ORG	$-4
??_8mech@@7Banimated@@@	DW	00H
	DW	0aH
	ORG	$-4
??_7screen@@6B@	DW	?Init@screen@@UACXPBUHWND__@@@Z
	DW	?CantGo@screen@@UAC?AW4boolean@@II@Z
	DW	?CanGo@screen@@UAC?AW4boolean@@II@Z
	DW	?IncrOccupation@screen@@UACHIIII@Z
	DW	?DecrOccupation@screen@@UACHIIII@Z
_DATA      ENDS
_BSS      SEGMENT
	ORG	$+1100
PUBLIC  ?Tela1@@3PAVscreen@@A
?Tela1@@3PAVscreen@@A	DW 01H DUP (?)
PUBLIC  ?Mech1@@3PAVmech@@A
?Mech1@@3PAVmech@@A	DW 01H DUP (?)
	ORG	$-1104
$S7071_hInstApp	DW 01H DUP (?)
$S7072_hwndApp	DW 01H DUP (?)
$S7073_hpalApp	DW 01H DUP (?)
$S7074_fAppActive	DW 01H DUP (?)
PUBLIC  ?BufferH@@3Uheader@@A
?BufferH@@3Uheader@@A	DW 0214H DUP (?)
PUBLIC  ?BufferHeader@@3AAUheader@@A
?BufferHeader@@3AAUheader@@A	DW 01H DUP (?)
PUBLIC  ?LogicalPalette@@3AAUpal@@A
?LogicalPalette@@3AAUpal@@A	DW 01H DUP (?)
PUBLIC  ?pBitmap@@3PEUtagBITMAPINFOHEADER@@E
?pBitmap@@3PEUtagBITMAPINFOHEADER@@E	DW 02H DUP (?)
PUBLIC  ?pBack@@3PEUtagBITMAPINFOHEADER@@E
?pBack@@3PEUtagBITMAPINFOHEADER@@E	DW 02H DUP (?)
PUBLIC  ?BackX@@3HA
?BackX@@3HA	DW 01H DUP (?)
PUBLIC  ?BackY@@3HA
?BackY@@3HA	DW 01H DUP (?)
PUBLIC  ?DogX@@3HA
?DogX@@3HA	DW 01H DUP (?)
PUBLIC  ?DogY@@3HA
?DogY@@3HA	DW 01H DUP (?)
PUBLIC  ?dx@@3HA
?dx@@3HA	DW 01H DUP (?)
PUBLIC  ?dy@@3HA
?dy@@3HA	DW 01H DUP (?)
PUBLIC  ?Old@@3UtagPOINT@@A
?Old@@3UtagPOINT@@A	DW 02H DUP (?)
_BSS      ENDS
_TEXT      SEGMENT
	ASSUME	CS: _TEXT

_aae	PROC FAR
; Line 56
	enter	0,0
	push	di
	push	si
	mov	WORD PTR ?BufferHeader@@3AAUheader@@A,OFFSET DGROUP:?BufferH@@3Uheader@@A	;BufferH
; Line 81
	mov	WORD PTR ?LogicalPalette@@3AAUpal@@A,OFFSET DGROUP:?LP@@3Upal@@A	;LP
	jmp	$EX7078
$EX7078:
	pop	si
	pop	di
	leave	
	ret	

_aae	ENDP
	PUBLIC	?AppAbout@@ZCHPBUHWND__@@IIJ@Z	; AppAbout
?AppAbout@@ZCHPBUHWND__@@IIJ@Z	PROC FAR	; AppAbout
; Line 145
	mov	ax,ss
	push	bp
	mov	bp,sp
	push	ds
	mov	ds,ax
	mov	ax,0
	call	__aNchkstk
	push	di
	push	si
;	hwnd = 14
;	msg = 12
;	wParam = 10
;	lParam = 6
; Line 146
	mov	ax,WORD PTR [bp+12]	;msg
	jmp	$S7130
; Line 147
; Line 148
$SC7134:
; Line 149
	cmp	WORD PTR [bp+10],1	;wParam
	je	$JCC51
	jmp	$I7137
$JCC51:
; Line 150
; Line 151
	push	WORD PTR [bp+14]	;hwnd
	push	1
	call	FAR PTR ENDDIALOG
; Line 152
; Line 153
$I7137:
	jmp	$SB7131
; Line 155
$SC7138:
; Line 156
	mov	ax,1
	jmp	$EX7129
; Line 157
	jmp	$SB7131
$S7130:
	sub	ax,272	;0110H
	jne	$JCC81
	jmp	$SC7138
$JCC81:
	dec	ax
	jne	$JCC87
	jmp	$SC7134
$JCC87:
	jmp	$SB7131
$SB7131:
; Line 158
	mov	ax,0
	jmp	$EX7129
; Line 159
$EX7129:
	pop	si
	pop	di
	lea	sp,WORD PTR [bp-2]
	pop	ds
	ASSUME DS: DGROUP
	pop	bp
	ret	10	;0000000aH

?AppAbout@@ZCHPBUHWND__@@IIJ@Z	ENDP
	PUBLIC	?AppInit@@YAHPBUHINSTANCE__@@0HPED@Z	; AppInit
?AppInit@@YAHPBUHINSTANCE__@@0HPED@Z	PROC NEAR	; AppInit
; Line 178
	push	bp
	mov	bp,sp
	mov	ax,28	;001cH
	call	__aNchkstk
	push	di
	push	si
;	cls = -26
;	szCmdLine = 10
;	sw = 8
;	hPrev = 6
;	hInst = 4
; Line 182
	mov	ax,WORD PTR [bp+4]	;hInst
	mov	WORD PTR $S7071_hInstApp,ax
; Line 185
	call	_ClearSystemPalette
; Line 187
	cmp	WORD PTR [bp+6],0	;hPrev
	je	$JCC135
	jmp	$I7146
$JCC135:
; Line 188
; Line 192
	push	0
	push	0
	push	32512	;7f00H
	call	FAR PTR LOADCURSOR
	mov	WORD PTR [bp-12],ax
; Line 193
	push	WORD PTR [bp+4]	;hInst
	push	ds
	push	OFFSET DGROUP:$SG7153
	call	FAR PTR LOADICON
	mov	WORD PTR [bp-14],ax
; Line 194
	sub	ax,ax
	mov	WORD PTR [bp-6],ax
	mov	WORD PTR [bp-8],ax
; Line 195
	mov	WORD PTR [bp-4],OFFSET DGROUP:$S7070_szAppName
	mov	WORD PTR [bp-2],ds
; Line 196
	mov	WORD PTR [bp-10],0
; Line 197
	mov	ax,WORD PTR [bp+4]	;hInst
	mov	WORD PTR [bp-16],ax
; Line 198
	mov	WORD PTR [bp-26],4107	;100bH	;cls
; Line 199
	mov	WORD PTR [bp-24],OFFSET ?AppWndProc@@ZCJPBUHWND__@@IIJ@Z	;AppWndProc
	mov	WORD PTR [bp-22],SEG ?AppWndProc@@ZCJPBUHWND__@@IIJ@Z	;AppWndProc
; Line 200
	mov	WORD PTR [bp-18],0
; Line 201
	mov	WORD PTR [bp-20],0
; Line 203
	lea	ax,WORD PTR [bp-26]	;cls
	push	ss
	push	ax
	call	FAR PTR REGISTERCLASS
	cmp	ax,0
	je	$JCC235
	jmp	$I7156
$JCC235:
; Line 204
	mov	ax,0
	jmp	$EX7144
; Line 205
$I7156:
; Line 207
$I7146:
	mov	WORD PTR ?dx@@3HA,640	;0280H	;dx
; Line 208
	mov	WORD PTR ?dy@@3HA,480	;01e0H	;dy
; Line 211
	push	1096	;0448H
	call	??2@YAPAXI@Z	; operator new
	add	sp,2
	mov	WORD PTR [bp-28],ax
	cmp	ax,0
	jne	$JCC273
	jmp	$L7319
$JCC273:
	push	OFFSET DGROUP:$SG7159
	push	0
	push	0
	push	640	;0280H
	push	480	;01e0H
	push	WORD PTR [bp-28]
	call	??0screen@@QAC@PADHHHH@Z	; screen::screen
	jmp	$L7320
$L7319:
	mov	ax,0
$L7320:
	mov	WORD PTR ?Tela1@@3PAVscreen@@A,ax	;Tela1
; Line 214
	push	96	;0060H
	call	??2@YAPAXI@Z	; operator new
	add	sp,2
	mov	WORD PTR [bp-28],ax
	cmp	ax,0
	jne	$JCC320
	jmp	$L7321
$JCC320:
	push	200	;00c8H
	push	200	;00c8H
	push	1
	push	OFFSET DGROUP:?MechNames@@3QAPADA	;MechNames
	push	OFFSET DGROUP:?MechFrames@@3QAHA	;MechFrames
	push	OFFSET DGROUP:?MechWidth@@3QAHA	;MechWidth
	push	OFFSET DGROUP:?MechHeight@@3QAHA	;MechHeight
	push	1
	push	60	;003cH
	push	1
	push	0
	push	1
	push	WORD PTR [bp-28]
	call	??0mech@@QAC@HHHQAPADQAH11HHW4boolean@@H@Z	; mech::mech
	jmp	$L7322
$L7321:
	mov	ax,0
$L7322:
	mov	WORD PTR ?Mech1@@3PAVmech@@A,ax	;Mech1
; Line 234
	push	ds
	push	OFFSET DGROUP:$S7070_szAppName
	push	ds
	push	OFFSET DGROUP:$S7070_szAppName
	push	-32512	;8100H
	push	0
	push	0
	push	0
	push	WORD PTR ?dx@@3HA	;dx
	push	WORD PTR ?dy@@3HA	;dy
	push	0
	push	0
	push	WORD PTR [bp+4]	;hInst
	push	0
	push	0
	call	FAR PTR CREATEWINDOW
	mov	WORD PTR $S7072_hwndApp,ax
; Line 236
	push	WORD PTR $S7072_hwndApp
	push	WORD PTR [bp+8]	;sw
	call	FAR PTR SHOWWINDOW
; Line 239
	mov	ax,1
	jmp	$EX7144
; Line 240
$EX7144:
	pop	si
	pop	di
	leave	
	ret	

?AppInit@@YAHPBUHINSTANCE__@@0HPED@Z	ENDP
	PUBLIC	?AppExit@@YAXXZ	; AppExit
?AppExit@@YAXXZ	PROC NEAR	; AppExit
; Line 251
	push	bp
	mov	bp,sp
	mov	ax,4
	call	__aNchkstk
	push	di
	push	si
; Line 253
	mov	ax,WORD PTR ?Tela1@@3PAVscreen@@A	;Tela1
	mov	WORD PTR [bp-4],ax
	mov	WORD PTR [bp-2],ax
	cmp	ax,0
	jne	$JCC459
	jmp	$L7325
$JCC459:
	push	1
	push	WORD PTR [bp-2]
	call	??_Gscreen@@QACPAXI@Z	; ??_Gscreen@@QACPAXI@Z
	jmp	$L7326
$L7325:
$L7326:
; Line 254
	mov	ax,WORD PTR ?Mech1@@3PAVmech@@A	;Mech1
	mov	WORD PTR [bp-2],ax
	mov	WORD PTR [bp-4],ax
	cmp	ax,0
	jne	$JCC487
	jmp	$L7327
$JCC487:
	push	1
	push	WORD PTR [bp-4]
	call	??_Gmech@@QACPAXI@Z	; ??_Gmech@@QACPAXI@Z
	jmp	$L7328
$L7327:
$L7328:
; Line 258
	jmp	$EX7166
$EX7166:
	pop	si
	pop	di
	leave	
	ret	

?AppExit@@YAXXZ	ENDP
	PUBLIC	?MessageLoop@@YAXPBUHINSTANCE__@@0PEDH@Z	; MessageLoop
?MessageLoop@@YAXPBUHINSTANCE__@@0PEDH@Z	PROC NEAR	; MessageLoop
; Line 282
	push	bp
	mov	bp,sp
	mov	ax,18	;0012H
	call	__aNchkstk
	push	di
	push	si
;	msg = -18
;	sw = 12
;	szCmdLine = 8
;	hPrev = 6
;	hInst = 4
; Line 288
$FC7179:
; Line 289
; Line 290
	lea	ax,WORD PTR [bp-18]	;msg
	push	ss
	push	ax
	push	0
	push	0
	push	0
	push	1
	call	FAR PTR PEEKMESSAGE
	cmp	ax,0
	jne	$JCC542
	jmp	$I7181
$JCC542:
; Line 291
; Line 292
	cmp	WORD PTR [bp-16],18	;0012H
	je	$JCC551
	jmp	$I7182
$JCC551:
; Line 293
	jmp	$FB7180
; Line 295
$I7182:
	lea	ax,WORD PTR [bp-18]	;msg
	push	ss
	push	ax
	call	FAR PTR TRANSLATEMESSAGE
; Line 296
	lea	ax,WORD PTR [bp-18]	;msg
	push	ss
	push	ax
	call	FAR PTR DISPATCHMESSAGE
; Line 297
; Line 298
	jmp	$I7183
$I7181:
; Line 299
; Line 300
	call	?AppIdle@@YAHXZ	; AppIdle
	cmp	ax,0
	jne	$JCC588
	jmp	$I7184
$JCC588:
; Line 301
	call	FAR PTR WAITMESSAGE
; Line 302
$I7184:
$I7183:
; Line 303
	jmp	$FC7179
$FB7180:
; Line 305
	jmp	$EX7176
$EX7176:
	pop	si
	pop	di
	leave	
	ret	

?MessageLoop@@YAXPBUHINSTANCE__@@0PEDH@Z	ENDP
	PUBLIC	WINMAIN
WINMAIN	PROC NEAR
; Line 309
	push	bp
	mov	bp,sp
	mov	ax,58	;003aH
	call	__aNchkstk
	push	di
	push	si
;	msg = -18
;	mensagem = -58
;	hInst = 12
;	hPrev = 10
;	szCmdLine = 6
;	sw = 4
; Line 311
	lea	di,WORD PTR [bp-58]	;mensagem
	mov	si,OFFSET DGROUP:$SG7192
	mov	ax,ss
	mov	es,ax
	mov	cx,16	;0010H
	rep	movsw
	mov	ax,0
	mov	cx,4
	lea	di,WORD PTR [bp-26]
	push	ss
	pop	es
	rep	stosw
; Line 314
	cmp	WORD PTR [bp+10],0	;hPrev
	jne	$JCC651
	jmp	$I7193
$JCC651:
; Line 315
; Line 316
	push	0
	lea	cx,WORD PTR [bp-58]	;mensagem
	push	ss
	push	cx
	push	ss
	push	cx
	push	0
	call	FAR PTR MESSAGEBOX
; Line 317
	mov	ax,0
	jmp	$EX7189
; Line 318
; Line 322
$I7193:
	push	WORD PTR [bp+8]
	push	WORD PTR [bp+6]	;szCmdLine
	push	WORD PTR [bp+4]	;sw
	push	WORD PTR [bp+10]	;hPrev
	push	WORD PTR [bp+12]	;hInst
	call	?AppInit@@YAHPBUHINSTANCE__@@0HPED@Z	; AppInit
	add	sp,10	;000aH
	cmp	ax,0
	je	$JCC702
	jmp	$I7194
$JCC702:
; Line 323
; Line 324
	mov	ax,0
	jmp	$EX7189
; Line 325
; Line 330
$I7194:
; Line 331
	push	ds
	push	OFFSET DGROUP:$SG7201
	call	FAR PTR GETMODULEHANDLE
	push	ax
	push	0
	push	11	;000bH
	call	FAR PTR GETPROCADDRESS
	mov	WORD PTR _SetSystemTimer,ax
	mov	WORD PTR _SetSystemTimer+2,dx
; Line 333
	push	ds
	push	OFFSET DGROUP:$SG7206
	call	FAR PTR GETMODULEHANDLE
	push	ax
	push	0
	push	182	;00b6H
	call	FAR PTR GETPROCADDRESS
	mov	WORD PTR _KillSystemTimer,ax
	mov	WORD PTR _KillSystemTimer+2,dx
; Line 339
	push	WORD PTR [bp+4]	;sw
	push	WORD PTR [bp+8]
	push	WORD PTR [bp+6]	;szCmdLine
	push	WORD PTR [bp+10]	;hPrev
	push	WORD PTR [bp+12]	;hInst
	call	?MessageLoop@@YAXPBUHINSTANCE__@@0PEDH@Z	; MessageLoop
	add	sp,10	;000aH
; Line 342
	call	?AppExit@@YAXXZ	; AppExit
; Line 343
	mov	ax,WORD PTR [bp-14]
	jmp	$EX7189
; Line 344
$EX7189:
	pop	si
	pop	di
	leave	
	ret	10	;000aH

WINMAIN	ENDP
	PUBLIC	?AppIdle@@YAHXZ	; AppIdle
?AppIdle@@YAHXZ	PROC NEAR	; AppIdle
; Line 356
	push	bp
	mov	bp,sp
	mov	ax,0
	call	__aNchkstk
	push	di
	push	si
; Line 357
	cmp	WORD PTR $S7074_fAppActive,0
	jne	$JCC818
	jmp	$I7209
$JCC818:
; Line 358
; Line 362
	mov	ax,1
	jmp	$EX7208
; Line 363
; Line 364
	jmp	$I7210
$I7209:
; Line 365
; Line 369
	mov	ax,1
	jmp	$EX7208
; Line 370
$I7210:
; Line 371
$EX7208:
	pop	si
	pop	di
	leave	
	ret	

?AppIdle@@YAHXZ	ENDP
	PUBLIC	?AppPaint@@YAHPBUHWND__@@PBUHDC__@@@Z	; AppPaint
?AppPaint@@YAHPBUHWND__@@PBUHDC__@@@Z	PROC NEAR	; AppPaint
; Line 385
	push	bp
	mov	bp,sp
	mov	ax,0
	call	__aNchkstk
	push	di
	push	si
;	hdc = 6
;	hwnd = 4
; Line 387
	push	WORD PTR [bp+6]	;hdc
	push	WORD PTR ?Tela1@@3PAVscreen@@A	;Tela1
	call	?Show@screen@@QACXPBUHDC__@@@Z	; screen::Show
; Line 390
	mov	ax,1
	jmp	$EX7214
; Line 391
$EX7214:
	pop	si
	pop	di
	leave	
	ret	

?AppPaint@@YAHPBUHWND__@@PBUHDC__@@@Z	ENDP
	PUBLIC	?AppWndProc@@ZCJPBUHWND__@@IIJ@Z	; AppWndProc
?AppWndProc@@ZCJPBUHWND__@@IIJ@Z	PROC FAR	; AppWndProc
; Line 402
	mov	ax,ss
	push	bp
	mov	bp,sp
	push	ds
	mov	ds,ax
	mov	ax,40	;0028H
	call	__aNchkstk
	push	di
	push	si
;	ps = -34
;	hdc = -36
;	f = -38
;	DeltaX = -40
;	DeltaY = -42
;	hwnd = 14
;	msg = 12
;	wParam = 10
;	lParam = 6
; Line 406
	mov	ax,20	;0014H
	mov	WORD PTR [bp-40],ax	;DeltaX
	mov	WORD PTR [bp-42],ax	;DeltaY
; Line 409
	mov	ax,WORD PTR [bp+12]	;msg
	jmp	$S7225
; Line 410
; Line 412
$SC7229:
; Line 414
	push	WORD PTR [bp+14]	;hwnd
	push	WORD PTR ?Tela1@@3PAVscreen@@A	;Tela1
	mov	bx,WORD PTR ?Tela1@@3PAVscreen@@A	;Tela1
	mov	bx,WORD PTR [bx]
	call	WORD PTR [bx]
; Line 415
	push	WORD PTR ?Tela1@@3PAVscreen@@A	;Tela1
	mov	bx,WORD PTR ?Mech1@@3PAVmech@@A	;Mech1
	mov	bx,WORD PTR [bx+2]
	mov	ax,WORD PTR [bx+2]
	add	ax,WORD PTR ?Mech1@@3PAVmech@@A	;Mech1
	add	ax,2
	push	ax
	call	?Init@object@@QACXPAVscreen@@@Z	; object::Init
; Line 421
	jmp	$SB7226
; Line 425
$SC7230:
; Line 431
	push	0
	call	FAR PTR POSTQUITMESSAGE
; Line 432
	jmp	$SB7226
; Line 434
$SC7231:
; Line 435
	mov	ax,WORD PTR [bp+10]	;wParam
	mov	WORD PTR $S7074_fAppActive,ax
; Line 436
	jmp	$SB7226
; Line 438
$SC7233:
; Line 440
	jmp	$SB7226
; Line 442
$SC7234:
; Line 444
	push	WORD PTR [bp+14]	;hwnd
	push	WORD PTR [bp+6]	;lParam
	push	WORD PTR [bp+8]
	push	WORD PTR ?Tela1@@3PAVscreen@@A	;Tela1
	push	WORD PTR ?Mech1@@3PAVmech@@A	;Mech1
	mov	bx,WORD PTR ?Mech1@@3PAVmech@@A	;Mech1
	mov	bx,WORD PTR [bx]
	call	WORD PTR [bx+2]
; Line 447
	jmp	$SB7226
; Line 449
$SC7239:
; Line 450
	jmp	$SB7226
; Line 452
$SC7240:
; Line 455
	mov	ax,WORD PTR [bp+10]	;wParam
	mov	bx,WORD PTR ?Mech1@@3PAVmech@@A	;Mech1
	cmp	WORD PTR [bx+48],ax
	je	$JCC1011
	jmp	$I7242
$JCC1011:
; Line 456
; Line 457
	push	WORD PTR [bp+14]	;hwnd
	push	WORD PTR ?Tela1@@3PAVscreen@@A	;Tela1
	push	WORD PTR ?Mech1@@3PAVmech@@A	;Mech1
	mov	bx,WORD PTR ?Mech1@@3PAVmech@@A	;Mech1
	mov	bx,WORD PTR [bx]
	call	WORD PTR [bx+12]
; Line 458
; Line 460
$I7242:
	jmp	$SB7226
; Line 462
$SC7243:
; Line 463
	push	WORD PTR [bp+8]
	push	WORD PTR [bp+6]	;lParam
	push	WORD PTR [bp+10]	;wParam
	push	WORD PTR [bp+12]	;msg
	push	WORD PTR [bp+14]	;hwnd
	call	?AppCommand@@YAJPBUHWND__@@IIJ@Z	; AppCommand
	add	sp,10	;000aH
	jmp	$EX7219
; Line 465
$SC7244:
; Line 466
	jmp	$SB7226
; Line 468
$SC7245:
; Line 469
	mov	ax,WORD PTR [bp+14]	;hwnd
	cmp	WORD PTR [bp+10],ax	;wParam
	je	$JCC1072
	jmp	$I7247
$JCC1072:
; Line 470
	jmp	$SB7226
; Line 474
$I7247:
$SC7248:
; Line 475
	push	WORD PTR [bp+14]	;hwnd
	call	FAR PTR GETDC
	mov	WORD PTR [bp-36],ax	;hdc
; Line 477
	mov	bx,WORD PTR ?Tela1@@3PAVscreen@@A	;Tela1
	cmp	WORD PTR [bx+28],0
	jne	$JCC1099
	jmp	$I7249
$JCC1099:
; Line 478
	push	WORD PTR [bp-36]	;hdc
	mov	bx,WORD PTR ?Tela1@@3PAVscreen@@A	;Tela1
	push	WORD PTR [bx+28]
	push	0
	call	FAR PTR SELECTPALETTE
; Line 480
$I7249:
	push	WORD PTR [bp-36]	;hdc
	call	FAR PTR REALIZEPALETTE
	mov	WORD PTR [bp-38],ax	;f
; Line 481
	push	WORD PTR [bp+14]	;hwnd
	push	WORD PTR [bp-36]	;hdc
	call	FAR PTR RELEASEDC
; Line 483
	cmp	WORD PTR [bp-38],0	;f
	jne	$JCC1147
	jmp	$I7250
$JCC1147:
; Line 484
	push	WORD PTR [bp+14]	;hwnd
	push	0
	push	0
	push	1
	call	FAR PTR INVALIDATERECT
; Line 486
$I7250:
	mov	ax,WORD PTR [bp-38]	;f
	cwd	
	jmp	$EX7219
; Line 488
$SC7251:
; Line 489
	push	WORD PTR [bp+14]	;hwnd
	lea	ax,WORD PTR [bp-34]	;ps
	push	ss
	push	ax
	call	FAR PTR BEGINPAINT
	mov	WORD PTR [bp-36],ax	;hdc
; Line 490
	push	WORD PTR [bp-36]	;hdc
	mov	bx,WORD PTR ?Tela1@@3PAVscreen@@A	;Tela1
	push	WORD PTR [bx+28]
	push	0
	call	FAR PTR SELECTPALETTE
; Line 491
	push	WORD PTR [bp-36]	;hdc
	call	FAR PTR REALIZEPALETTE
; Line 492
	push	WORD PTR [bp-36]	;hdc
	push	WORD PTR [bp+14]	;hwnd
	call	?AppPaint@@YAHPBUHWND__@@PBUHDC__@@@Z	; AppPaint
	add	sp,4
; Line 493
	push	WORD PTR [bp+14]	;hwnd
	lea	ax,WORD PTR [bp-34]	;ps
	push	ss
	push	ax
	call	FAR PTR ENDPAINT
; Line 494
	mov	ax,0
	mov	dx,0
	jmp	$EX7219
; Line 495
	jmp	$SB7226
$S7225:
	cmp	ax,256	;0100H
	jne	$JCC1254
	jmp	$SC7230
$JCC1254:
	jbe	$JCC1259
	jmp	$L7329
$JCC1259:
	cmp	ax,5
	jne	$JCC1267
	jmp	$SC7233
$JCC1267:
	jbe	$JCC1272
	jmp	$L7330
$JCC1272:
	dec	ax
	jne	$JCC1278
	jmp	$SC7229
$JCC1278:
	dec	ax
	jne	$JCC1284
	jmp	$SC7230
$JCC1284:
	jmp	$SB7226
$L7330:
	sub	ax,15	;000fH
	jne	$JCC1295
	jmp	$SC7251
$JCC1295:
	dec	ax
	jne	$JCC1301
	jmp	$SC7244
$JCC1301:
	sub	ax,12	;000cH
	jne	$JCC1309
	jmp	$SC7231
$JCC1309:
	jmp	$SB7226
$L7329:
	cmp	ax,513	;0201H
	jne	$JCC1320
	jmp	$SC7234
$JCC1320:
	jbe	$JCC1325
	jmp	$L7331
$JCC1325:
	sub	ax,273	;0111H
	jne	$JCC1333
	jmp	$SC7243
$JCC1333:
	dec	ax
	dec	ax
	jne	$JCC1340
	jmp	$SC7239
$JCC1340:
	sub	ax,5
	jne	$JCC1348
	jmp	$SC7240
$JCC1348:
	jmp	$SB7226
$L7331:
	sub	ax,516	;0204H
	jne	$JCC1359
	jmp	$SC7230
$JCC1359:
	sub	ax,267	;010bH
	jne	$JCC1367
	jmp	$SC7248
$JCC1367:
	dec	ax
	dec	ax
	jne	$JCC1374
	jmp	$SC7245
$JCC1374:
	jmp	$SB7226
$SB7226:
; Line 497
	push	WORD PTR [bp+14]	;hwnd
	push	WORD PTR [bp+12]	;msg
	push	WORD PTR [bp+10]	;wParam
	push	WORD PTR [bp+8]
	push	WORD PTR [bp+6]	;lParam
	call	FAR PTR DEFWINDOWPROC
	jmp	$EX7219
; Line 498
$EX7219:
	pop	si
	pop	di
	lea	sp,WORD PTR [bp-2]
	pop	ds
	ASSUME DS: DGROUP
	pop	bp
	ret	10	;0000000aH

?AppWndProc@@ZCJPBUHWND__@@IIJ@Z	ENDP
	PUBLIC	?AppCommand@@YAJPBUHWND__@@IIJ@Z	; AppCommand
?AppCommand@@YAJPBUHWND__@@IIJ@Z	PROC NEAR	; AppCommand
; Line 509
	push	bp
	mov	bp,sp
	mov	ax,0
	call	__aNchkstk
	push	di
	push	si
;	lParam = 10
;	wParam = 8
;	msg = 6
;	hwnd = 4
; Line 510
	mov	ax,WORD PTR [bp+8]	;wParam
	jmp	$S7257
; Line 511
; Line 512
$SC7261:
; Line 513
	push	WORD PTR $S7071_hInstApp
	push	ds
	push	OFFSET DGROUP:$SG7263
	push	WORD PTR [bp+4]	;hwnd
	push	SEG ?AppAbout@@ZCHPBUHWND__@@IIJ@Z	;AppAbout
	push	OFFSET ?AppAbout@@ZCHPBUHWND__@@IIJ@Z	;AppAbout
	call	FAR PTR DIALOGBOX
; Line 514
	jmp	$SB7258
; Line 516
$SC7264:
; Line 517
	push	WORD PTR [bp+4]	;hwnd
	push	16	;0010H
	push	0
	push	0
	push	0
	call	FAR PTR POSTMESSAGE
; Line 518
	jmp	$SB7258
; Line 519
	jmp	$SB7258
$S7257:
	dec	ax
	dec	ax
	jne	$JCC1481
	jmp	$SC7261
$JCC1481:
	dec	ax
	dec	ax
	jne	$JCC1488
	jmp	$SC7264
$JCC1488:
	jmp	$SB7258
$SB7258:
; Line 520
	mov	ax,0
	mov	dx,0
	jmp	$EX7256
; Line 521
$EX7256:
	pop	si
	pop	di
	leave	
	ret	

?AppCommand@@YAJPBUHWND__@@IIJ@Z	ENDP

_aaf	PROC FAR
; Line 522
	enter	0,0
	push	di
	push	si
	call	FAR PTR _aae
	jmp	$EX7266
$EX7266:
	pop	si
	pop	di
	leave	
	ret	

_aaf	ENDP
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
	jmp	$E7280
$JCC18:
	push	si
	push	14	;000eH
	push	WORD PTR [si-2]
	push	OFFSET ??1sprite@@QAC@XZ	;sprite::~sprite
	call	??_I@YCXPAXIHP6CX0@Z@Z	; ??_I@YCXPAXIHP6CX0@Z@Z
	lea	ax,WORD PTR [si-2]
	push	ax
	call	??3@YAXPAX@Z	; operator delete
	add	sp,2
	jmp	$I7281
$E7280:
	push	si
	call	??1sprite@@QAC@XZ	; sprite::~sprite
	test	BYTE PTR [bp+6],1	;__flags
	jne	$JCC56
	jmp	$I7283
$JCC56:
	push	si
	call	??3@YAXPAX@Z	; operator delete
	add	sp,2
$I7283:
$I7281:
	mov	ax,si
	jmp	$EX7279
$EX7279:
	pop	si
	pop	di
	leave	
	ret	4

??_Esprite@@QACPAXI@Z	ENDP
	PUBLIC	??_Gscreen@@QACPAXI@Z	; ??_Gscreen@@QACPAXI@Z
??_Gscreen@@QACPAXI@Z	PROC NEAR	; ??_Gscreen@@QACPAXI@Z COMDAT
	push	bp
	mov	bp,sp
	mov	ax,0
	call	__aNchkstk
	push	di
	push	si
	mov	si,WORD PTR [bp+4]	;this
;	register si = this
;	__flags = 6
	push	si
	call	??1screen@@QAC@XZ	; screen::~screen
	test	BYTE PTR [bp+6],1	;__flags
	jne	$JCC22
	jmp	$I7287
$JCC22:
	push	si
	call	??3@YAXPAX@Z	; operator delete
	add	sp,2
$I7287:
	mov	ax,si
	jmp	$EX7286
$EX7286:
	pop	si
	pop	di
	leave	
	ret	4

??_Gscreen@@QACPAXI@Z	ENDP
	PUBLIC	??_Gmech@@QACPAXI@Z	; ??_Gmech@@QACPAXI@Z
??_Gmech@@QACPAXI@Z	PROC NEAR	; ??_Gmech@@QACPAXI@Z COMDAT
	push	bp
	mov	bp,sp
	mov	ax,0
	call	__aNchkstk
	push	di
	push	si
	mov	si,WORD PTR [bp+4]	;this
;	register si = this
;	__flags = 6
	push	si
	call	??_Dmech@@QACXXZ	; ??_Dmech@@QACXXZ
	test	BYTE PTR [bp+6],1	;__flags
	jne	$JCC22
	jmp	$I7291
$JCC22:
	push	si
	call	??3@YAXPAX@Z	; operator delete
	add	sp,2
$I7291:
	mov	ax,si
	jmp	$EX7290
$EX7290:
	pop	si
	pop	di
	leave	
	ret	4

??_Gmech@@QACPAXI@Z	ENDP
	PUBLIC	??_Dmech@@QACXXZ	; ??_Dmech@@QACXXZ
??_Dmech@@QACXXZ	PROC NEAR	; ??_Dmech@@QACXXZ COMDAT
	push	bp
	mov	bp,sp
	mov	ax,0
	call	__aNchkstk
	push	di
	push	si
	mov	si,WORD PTR [bp+4]	;this
;	register si = this
	jmp	$EX7294
$EX7294:
	push	si
	call	??1mech@@QAC@XZ	; mech::~mech
	lea	ax,WORD PTR [si+62]
	push	ax
	call	??1object@@QAC@XZ	; object::~object
	pop	si
	pop	di
	leave	
	ret	2

??_Dmech@@QACXXZ	ENDP
	PUBLIC	??1mech@@QAC@XZ	; mech::~mech
??1mech@@QAC@XZ	PROC NEAR	; mech::~mech COMDAT
	push	bp
	mov	bp,sp
	mov	ax,0
	call	__aNchkstk
	push	di
	push	si
	mov	si,WORD PTR [bp+4]	;this
;	register si = this
	jmp	$EX7297
$EX7297:
	push	si
	call	??1player@@QAC@XZ	; player::~player
	pop	si
	pop	di
	leave	
	ret	2

??1mech@@QAC@XZ	ENDP
	PUBLIC	??1player@@QAC@XZ	; player::~player
??1player@@QAC@XZ	PROC NEAR	; player::~player COMDAT
	push	bp
	mov	bp,sp
	mov	ax,0
	call	__aNchkstk
	push	di
	push	si
	mov	si,WORD PTR [bp+4]	;this
;	register si = this
	jmp	$EX7300
$EX7300:
	push	si
	call	??1actor@@QAC@XZ	; actor::~actor
	pop	si
	pop	di
	leave	
	ret	2

??1player@@QAC@XZ	ENDP
	PUBLIC	??1actor@@QAC@XZ	; actor::~actor
??1actor@@QAC@XZ	PROC NEAR	; actor::~actor COMDAT
	push	bp
	mov	bp,sp
	mov	ax,2
	call	__aNchkstk
	push	di
	push	si
	mov	si,WORD PTR [bp+4]	;this
;	register si = this
	jmp	$EX7303
$EX7303:
	cmp	si,0
	jne	$JCC20
	jmp	$L7332
$JCC20:
	lea	ax,WORD PTR [si+52]
	jmp	$L7333
$L7332:
	mov	ax,0
$L7333:
	mov	WORD PTR [bp-2],ax
	push	ax
	call	??1animated@@QAC@XZ	; animated::~animated
	push	si
	call	??1moveable@@QAC@XZ	; moveable::~moveable
	pop	si
	pop	di
	leave	
	ret	2

??1actor@@QAC@XZ	ENDP
	PUBLIC	??1moveable@@QAC@XZ	; moveable::~moveable
??1moveable@@QAC@XZ	PROC NEAR	; moveable::~moveable COMDAT
	push	bp
	mov	bp,sp
	mov	ax,0
	call	__aNchkstk
	push	di
	push	si
	mov	si,WORD PTR [bp+4]	;this
;	register si = this
	jmp	$EX7306
$EX7306:
	pop	si
	pop	di
	leave	
	ret	2

??1moveable@@QAC@XZ	ENDP
	PUBLIC	??1animated@@QAC@XZ	; animated::~animated
??1animated@@QAC@XZ	PROC NEAR	; animated::~animated COMDAT
	push	bp
	mov	bp,sp
	mov	ax,0
	call	__aNchkstk
	push	di
	push	si
	mov	si,WORD PTR [bp+4]	;this
;	register si = this
	jmp	$EX7309
$EX7309:
	pop	si
	pop	di
	leave	
	ret	2

??1animated@@QAC@XZ	ENDP
	PUBLIC	?Show@moveable@@$4PPPPPPPO@1ACXPBUHDC__@@PAVscreen@@@Z	; moveable::Show
?Show@moveable@@$4PPPPPPPO@1ACXPBUHDC__@@PAVscreen@@@Z	PROC NEAR	; moveable::Show COMDAT
	mov	bx,sp
	mov	bx,WORD PTR ss:[bx+2]
	mov	ax,WORD PTR [bx+65534]
	add	ax,2
	mov	bx,sp
	sub	WORD PTR ss:[bx+2],ax
	jmp	?Show@moveable@@UACXPBUHDC__@@PAVscreen@@@Z	; moveable::Show

?Show@moveable@@$4PPPPPPPO@1ACXPBUHDC__@@PAVscreen@@@Z	ENDP
	PUBLIC	?Show@moveable@@$4PPPPPPPO@A@ACXPBUHDC__@@PAVscreen@@@Z	; moveable::Show
?Show@moveable@@$4PPPPPPPO@A@ACXPBUHDC__@@PAVscreen@@@Z	PROC NEAR	; moveable::Show COMDAT
	mov	bx,sp
	mov	bx,WORD PTR ss:[bx+2]
	mov	ax,WORD PTR [bx+65534]
	mov	bx,sp
	sub	WORD PTR ss:[bx+2],ax
	jmp	?Show@moveable@@UACXPBUHDC__@@PAVscreen@@@Z	; moveable::Show

?Show@moveable@@$4PPPPPPPO@A@ACXPBUHDC__@@PAVscreen@@@Z	ENDP
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
	PUBLIC	?NextFrame@animated@@W5ACPEUtagBITMAPINFOHEADER@@XZ	; animated::NextFrame
?NextFrame@animated@@W5ACPEUtagBITMAPINFOHEADER@@XZ	PROC NEAR	; animated::NextFrame COMDAT
	mov	bx,sp
	sub	WORD PTR ss:[bx+2],6
	jmp	FAR PTR ?NextFrame@animated@@UACPEUtagBITMAPINFOHEADER@@XZ	; animated::NextFrame

?NextFrame@animated@@W5ACPEUtagBITMAPINFOHEADER@@XZ	ENDP
	PUBLIC	?PreviousFrame@animated@@W5ACPEUtagBITMAPINFOHEADER@@XZ	; animated::PreviousFrame
?PreviousFrame@animated@@W5ACPEUtagBITMAPINFOHEADER@@XZ	PROC NEAR	; animated::PreviousFrame COMDAT
	mov	bx,sp
	sub	WORD PTR ss:[bx+2],6
	jmp	FAR PTR ?PreviousFrame@animated@@UACPEUtagBITMAPINFOHEADER@@XZ	; animated::PreviousFrame

?PreviousFrame@animated@@W5ACPEUtagBITMAPINFOHEADER@@XZ	ENDP
	PUBLIC	?NextFrame@animated@@$4PPPPPPPO@A@ACPEUtagBITMAPINFOHEADER@@XZ	; animated::NextFrame
?NextFrame@animated@@$4PPPPPPPO@A@ACPEUtagBITMAPINFOHEADER@@XZ	PROC NEAR	; animated::NextFrame COMDAT
	mov	bx,sp
	mov	bx,WORD PTR ss:[bx+2]
	mov	ax,WORD PTR [bx+65534]
	mov	bx,sp
	sub	WORD PTR ss:[bx+2],ax
	jmp	?NextFrame@animated@@UACPEUtagBITMAPINFOHEADER@@XZ	; animated::NextFrame

?NextFrame@animated@@$4PPPPPPPO@A@ACPEUtagBITMAPINFOHEADER@@XZ	ENDP
	PUBLIC	?PreviousFrame@animated@@$4PPPPPPPO@A@ACPEUtagBITMAPINFOHEADER@@XZ	; animated::PreviousFrame
?PreviousFrame@animated@@$4PPPPPPPO@A@ACPEUtagBITMAPINFOHEADER@@XZ	PROC NEAR	; animated::PreviousFrame COMDAT
	mov	bx,sp
	mov	bx,WORD PTR ss:[bx+2]
	mov	ax,WORD PTR [bx+65534]
	mov	bx,sp
	sub	WORD PTR ss:[bx+2],ax
	jmp	?PreviousFrame@animated@@UACPEUtagBITMAPINFOHEADER@@XZ	; animated::PreviousFrame

?PreviousFrame@animated@@$4PPPPPPPO@A@ACPEUtagBITMAPINFOHEADER@@XZ	ENDP
	PUBLIC	??0screen@@QAC@PADHHHH@Z	; screen::screen
??0screen@@QAC@PADHHHH@Z	PROC NEAR	; screen::screen COMDAT
; Line 297
	push	bp
	mov	bp,sp
	mov	ax,0
	call	__aNchkstk
	push	di
	push	si
	mov	si,WORD PTR [bp+4]	;this
;	register si = this
;	BackName = 14
;	_ScreenX = 12
;	_ScreenY = 10
;	_ScreenWidth = 8
;	_ScreenHeight = 6
	mov	WORD PTR [si],OFFSET DGROUP:??_7screen@@6B@
; Line 299
	push	ds
	push	WORD PTR [bp+14]	;BackName
	call	_DibOpenFile
	add	sp,4
	mov	WORD PTR [si+8],ax
	mov	WORD PTR [si+10],dx
; Line 301
	les	bx,DWORD PTR [si+8]
	mov	ax,WORD PTR es:[bx+4]
	mov	WORD PTR [si+12],ax
; Line 302
	les	bx,DWORD PTR [si+8]
	mov	ax,WORD PTR es:[bx+8]
	mov	WORD PTR [si+14],ax
; Line 305
	mov	WORD PTR [si+30],0
; Line 307
	mov	ax,WORD PTR [bp+12]	;_ScreenX
	mov	WORD PTR [si+16],ax
; Line 308
	mov	ax,WORD PTR [bp+10]	;_ScreenY
	mov	WORD PTR [si+18],ax
; Line 310
	mov	ax,WORD PTR [bp+8]	;_ScreenWidth
	mov	WORD PTR [si+20],ax
; Line 311
	mov	ax,WORD PTR [bp+6]	;_ScreenHeight
	mov	WORD PTR [si+22],ax
; Line 315
	mov	ax,si
	jmp	$EX6264
$EX6264:
	pop	si
	pop	di
	leave	
	ret	12	;000cH

??0screen@@QAC@PADHHHH@Z	ENDP
	PUBLIC	??1screen@@QAC@XZ	; screen::~screen
??1screen@@QAC@XZ	PROC NEAR	; screen::~screen COMDAT
; Line 319
	push	bp
	mov	bp,sp
	mov	ax,2
	call	__aNchkstk
	push	di
	push	si
	mov	si,WORD PTR [bp+4]	;this
;	hbm = -2
;	register si = this
	mov	WORD PTR [si],OFFSET DGROUP:??_7screen@@6B@
; Line 323
	push	WORD PTR [si+2]
	push	WORD PTR [si+30]
	call	FAR PTR SELECTOBJECT
	mov	WORD PTR [bp-2],ax	;hbm
; Line 326
	push	WORD PTR [bp-2]	;hbm
	call	FAR PTR DELETEOBJECT
; Line 327
	push	WORD PTR [si+2]
	call	FAR PTR DELETEDC
; Line 329
	push	WORD PTR [si+28]
	call	FAR PTR DELETEOBJECT
; Line 330
	jmp	$EX6271
$EX6271:
	pop	si
	pop	di
	leave	
	ret	2

??1screen@@QAC@XZ	ENDP
	PUBLIC	?Show@screen@@QACXPBUHDC__@@@Z	; screen::Show
?Show@screen@@QACXPBUHDC__@@@Z	PROC NEAR	; screen::Show COMDAT
; Line 333
	push	bp
	mov	bp,sp
	mov	ax,0
	call	__aNchkstk
	push	di
	push	si
	mov	si,WORD PTR [bp+4]	;this
;	register si = this
;	hdc = 6
; Line 335
	push	WORD PTR [bp+6]	;hdc
	push	0
	push	0
	push	WORD PTR [si+20]
	push	WORD PTR [si+22]
	push	WORD PTR [si+2]
	push	WORD PTR [si+16]
	push	WORD PTR [si+18]
	call	FAR PTR WINGBITBLT
; Line 336
	jmp	$EX6276
$EX6276:
	pop	si
	pop	di
	leave	
	ret	4

?Show@screen@@QACXPBUHDC__@@@Z	ENDP
	PUBLIC	?CantGo@screen@@UAC?AW4boolean@@II@Z	; screen::CantGo
?CantGo@screen@@UAC?AW4boolean@@II@Z	PROC NEAR	; screen::CantGo COMDAT
; Line 358
	push	bp
	mov	bp,sp
	mov	ax,0
	call	__aNchkstk
	push	di
	push	si
	mov	si,WORD PTR [bp+4]	;this
;	register si = this
;	X = 8
;	Y = 6
; Line 359
	mov	ax,0
	jmp	$EX6297
; Line 360
$EX6297:
	pop	si
	pop	di
	leave	
	ret	6

?CantGo@screen@@UAC?AW4boolean@@II@Z	ENDP
	PUBLIC	?CanGo@screen@@UAC?AW4boolean@@II@Z	; screen::CanGo
?CanGo@screen@@UAC?AW4boolean@@II@Z	PROC NEAR	; screen::CanGo COMDAT
; Line 363
	push	bp
	mov	bp,sp
	mov	ax,0
	call	__aNchkstk
	push	di
	push	si
	mov	si,WORD PTR [bp+4]	;this
;	register si = this
;	X = 8
;	Y = 6
; Line 364
	mov	ax,1
	jmp	$EX6301
; Line 365
$EX6301:
	pop	si
	pop	di
	leave	
	ret	6

?CanGo@screen@@UAC?AW4boolean@@II@Z	ENDP
	PUBLIC	?IncrOccupation@screen@@UACHIIII@Z	; screen::IncrOccupation
?IncrOccupation@screen@@UACHIIII@Z	PROC NEAR	; screen::IncrOccupation COMDAT
; Line 368
	push	bp
	mov	bp,sp
	mov	ax,0
	call	__aNchkstk
	push	di
	push	si
	mov	si,WORD PTR [bp+4]	;this
;	register si = this
;	X = 12
;	Y = 10
;	Width = 8
;	Height = 6
; Line 369
	mov	ax,1
	jmp	$EX6307
; Line 370
$EX6307:
	pop	si
	pop	di
	leave	
	ret	10	;000aH

?IncrOccupation@screen@@UACHIIII@Z	ENDP
	PUBLIC	?DecrOccupation@screen@@UACHIIII@Z	; screen::DecrOccupation
?DecrOccupation@screen@@UACHIIII@Z	PROC NEAR	; screen::DecrOccupation COMDAT
; Line 373
	push	bp
	mov	bp,sp
	mov	ax,0
	call	__aNchkstk
	push	di
	push	si
	mov	si,WORD PTR [bp+4]	;this
;	register si = this
;	X = 12
;	Y = 10
;	Width = 8
;	Height = 6
; Line 374
	mov	ax,1
	jmp	$EX6313
; Line 375
$EX6313:
	pop	si
	pop	di
	leave	
	ret	10	;000aH

?DecrOccupation@screen@@UACHIIII@Z	ENDP
	PUBLIC	??1sprite@@QAC@XZ	; sprite::~sprite
??1sprite@@QAC@XZ	PROC NEAR	; sprite::~sprite COMDAT
; Line 517
	push	bp
	mov	bp,sp
	mov	ax,4
	call	__aNchkstk
	push	di
	push	si
	mov	si,WORD PTR [bp+4]	;this
;	register si = this
	mov	WORD PTR [si],OFFSET DGROUP:??_7sprite@@6B@
; Line 518
	mov	ax,WORD PTR [si+2]
	mov	WORD PTR [bp-2],ax
	push	ax
	call	??3@YAXPAX@Z	; operator delete
	add	sp,2
; Line 519
	jmp	$EX6472
$EX6472:
	pop	si
	pop	di
	leave	
	ret	2

??1sprite@@QAC@XZ	ENDP
	PUBLIC	?Frame@sprite@@UACPEUtagBITMAPINFOHEADER@@H@Z	; sprite::Frame
?Frame@sprite@@UACPEUtagBITMAPINFOHEADER@@H@Z	PROC NEAR	; sprite::Frame COMDAT
; Line 522
	push	bp
	mov	bp,sp
	mov	ax,0
	call	__aNchkstk
	push	di
	push	si
	mov	si,WORD PTR [bp+4]	;this
;	register si = this
;	FrameNumber = 6
; Line 523
	mov	di,WORD PTR [bp+6]	;FrameNumber
	mov	ax,di
	shl	di,1
	add	di,ax
	shl	di,2
	mov	bx,WORD PTR [si+2]
	mov	ax,WORD PTR [bx+8][di]
	mov	dx,WORD PTR [bx+10][di]
	jmp	$EX6476
; Line 524
$EX6476:
	pop	si
	pop	di
	leave	
	ret	4

?Frame@sprite@@UACPEUtagBITMAPINFOHEADER@@H@Z	ENDP
	PUBLIC	?Init@object@@QACXPAVscreen@@@Z	; object::Init
?Init@object@@QACXPAVscreen@@@Z	PROC NEAR	; object::Init COMDAT
; Line 763
	push	bp
	mov	bp,sp
	mov	ax,4
	call	__aNchkstk
	push	di
	push	si
	mov	si,WORD PTR [bp+4]	;this
;	hback = -2
;	pBufferHeader = -4
;	register si = this
;	Screen = 6
; Line 765
	mov	ax,WORD PTR [bp+6]	;Screen
	add	ax,32	;0020H
	mov	WORD PTR [bp-4],ax	;pBufferHeader
; Line 767
	call	FAR PTR WINGCREATEDC
	mov	WORD PTR [si+24],ax
; Line 768
	sub	ax,ax
	mov	WORD PTR [si+28],ax
	mov	WORD PTR [si+26],ax
; Line 771
	push	si
	call	?FrameWidth@object@@QACHXZ	; object::FrameWidth
	cwd	
	mov	bx,WORD PTR [bp-4]	;pBufferHeader
	mov	WORD PTR [bx+4],ax
	mov	WORD PTR [bx+6],dx
; Line 772
	push	1
	push	si
	call	?FrameHeight@object@@QACHH@Z	; object::FrameHeight
	cwd	
	mov	bx,WORD PTR [bp-4]	;pBufferHeader
	mov	WORD PTR [bx+8],ax
	mov	WORD PTR [bx+10],dx
; Line 775
	push	WORD PTR [si+24]
	push	ds
	push	WORD PTR [bp-4]	;pBufferHeader
	lea	ax,WORD PTR [si+26]
	push	ds
	push	ax
	call	FAR PTR WINGCREATEBITMAP
	mov	WORD PTR [bp-2],ax	;hback
; Line 777
	push	WORD PTR [si+24]
	push	WORD PTR [bp-2]	;hback
	call	FAR PTR SELECTOBJECT
	mov	WORD PTR [si+30],ax
; Line 779
	push	WORD PTR [si+24]
	push	0
	push	0
	push	si
	call	?FrameWidth@object@@QACHXZ	; object::FrameWidth
	push	ax
	push	1
	push	si
	call	?FrameHeight@object@@QACHH@Z	; object::FrameHeight
	push	ax
	push	0
	push	66	;0042H
	call	FAR PTR PATBLT
; Line 781
	push	WORD PTR [bp+6]	;Screen
	call	?UpdateBufferSize@screen@@QACXXZ	; screen::UpdateBufferSize
; Line 784
; Line 786
	mov	bx,WORD PTR [bp+6]	;Screen
	push	WORD PTR [bx+2]
	push	si
	call	?SaveBackGround@object@@QACXPBUHDC__@@@Z	; object::SaveBackGround
; Line 790
	push	ds
	push	WORD PTR [bp-4]	;pBufferHeader
	mov	bx,WORD PTR [bp+6]	;Screen
	push	WORD PTR [bx+6]
	push	WORD PTR [bx+4]
	push	si
	call	?PutIntoBuffer@object@@QACXPEUtagBITMAPINFO@@PEX@Z	; object::PutIntoBuffer
; Line 791
; Line 793
	push	WORD PTR [si+8]
	push	WORD PTR [si+10]
	push	si
	call	?FrameWidth@object@@QACHXZ	; object::FrameWidth
	push	ax
	push	1
	push	si
	call	?FrameHeight@object@@QACHH@Z	; object::FrameHeight
	push	ax
	push	WORD PTR [bp+6]	;Screen
	mov	bx,WORD PTR [bp+6]	;Screen
	mov	bx,WORD PTR [bx]
	call	WORD PTR [bx+6]
; Line 795
	jmp	$EX6673
$EX6673:
	pop	si
	pop	di
	leave	
	ret	4

?Init@object@@QACXPAVscreen@@@Z	ENDP
	PUBLIC	??1object@@QAC@XZ	; object::~object
??1object@@QAC@XZ	PROC NEAR	; object::~object COMDAT
; Line 799
	push	bp
	mov	bp,sp
	mov	ax,2
	call	__aNchkstk
	push	di
	push	si
	mov	si,WORD PTR [bp+4]	;this
;	hback = -2
;	register si = this
	mov	WORD PTR [si],OFFSET DGROUP:??_7object@@6B@
; Line 803
	push	WORD PTR [si+24]
	push	WORD PTR [si+30]
	call	FAR PTR SELECTOBJECT
	mov	WORD PTR [bp-2],ax	;hback
; Line 806
	push	WORD PTR [bp-2]	;hback
	call	FAR PTR DELETEOBJECT
; Line 808
	push	WORD PTR [si+24]
	call	FAR PTR DELETEDC
; Line 809
	jmp	$EX6681
$EX6681:
	pop	si
	pop	di
	leave	
	ret	2

??1object@@QAC@XZ	ENDP
	PUBLIC	?NextFrame@animated@@UACPEUtagBITMAPINFOHEADER@@XZ	; animated::NextFrame
?NextFrame@animated@@UACPEUtagBITMAPINFOHEADER@@XZ	PROC NEAR	; animated::NextFrame COMDAT
; Line 883
	push	bp
	mov	bp,sp
	mov	ax,0
	call	__aNchkstk
	push	di
	push	si
	mov	si,WORD PTR [bp+4]	;this
;	register si = this
; Line 884
	mov	bx,WORD PTR [si-4]
	mov	ax,WORD PTR [bx+2]
	add	ax,si
	sub	ax,4
	push	ax
	call	?Sprite@object@@QACAAVsprite@@XZ	; object::Sprite
	mov	bx,ax
	mov	di,WORD PTR [si-4]
	mov	ax,WORD PTR [bx+8]
	mov	bx,WORD PTR [di+2]
	sub	ax,WORD PTR [bx+18][si]
	neg	ax
	cmp	ax,-1	;ffffH
	je	$JCC48
	jmp	$I6765
$JCC48:
; Line 885
; Line 886
	mov	bx,WORD PTR [si-4]
	mov	bx,WORD PTR [bx+2]
	mov	WORD PTR [bx+18][si],0
; Line 887
; Line 888
	jmp	$I6766
$I6765:
; Line 889
; Line 890
	mov	bx,WORD PTR [si-4]
	mov	bx,WORD PTR [bx+2]
	inc	WORD PTR [bx+18][si]
; Line 891
$I6766:
; Line 893
	mov	bx,WORD PTR [si-4]
	mov	ax,WORD PTR [bx+2]
	add	ax,si
	sub	ax,4
	push	ax
	call	?Frame@object@@QACPEUtagBITMAPINFOHEADER@@XZ	; object::Frame
	jmp	$EX6764
; Line 894
$EX6764:
	pop	si
	pop	di
	leave	
	ret	2

?NextFrame@animated@@UACPEUtagBITMAPINFOHEADER@@XZ	ENDP
	PUBLIC	?PreviousFrame@animated@@UACPEUtagBITMAPINFOHEADER@@XZ	; animated::PreviousFrame
?PreviousFrame@animated@@UACPEUtagBITMAPINFOHEADER@@XZ	PROC NEAR	; animated::PreviousFrame COMDAT
; Line 897
	push	bp
	mov	bp,sp
	mov	ax,0
	call	__aNchkstk
	push	di
	push	si
	mov	si,WORD PTR [bp+4]	;this
;	register si = this
; Line 898
	mov	bx,WORD PTR [si-4]
	mov	bx,WORD PTR [bx+2]
	cmp	WORD PTR [bx+18][si],0
	je	$JCC24
	jmp	$I6770
$JCC24:
; Line 899
; Line 900
	mov	bx,WORD PTR [si-4]
	mov	ax,WORD PTR [bx+2]
	add	ax,si
	sub	ax,4
	push	ax
	call	?Sprite@object@@QACAAVsprite@@XZ	; object::Sprite
	mov	bx,ax
	mov	ax,WORD PTR [bx+8]
	dec	ax
	mov	bx,WORD PTR [si-4]
	mov	bx,WORD PTR [bx+2]
	mov	WORD PTR [bx+18][si],ax
; Line 901
; Line 902
	jmp	$I6771
$I6770:
; Line 903
; Line 904
	mov	bx,WORD PTR [si-4]
	mov	bx,WORD PTR [bx+2]
	dec	WORD PTR [bx+18][si]
; Line 905
$I6771:
; Line 907
	mov	bx,WORD PTR [si-4]
	mov	ax,WORD PTR [bx+2]
	add	ax,si
	sub	ax,4
	push	ax
	call	?Frame@object@@QACPEUtagBITMAPINFOHEADER@@XZ	; object::Frame
	jmp	$EX6769
; Line 908
$EX6769:
	pop	si
	pop	di
	leave	
	ret	2

?PreviousFrame@animated@@UACPEUtagBITMAPINFOHEADER@@XZ	ENDP
	PUBLIC	?Show@moveable@@UACXPBUHDC__@@PAVscreen@@@Z	; moveable::Show
?Show@moveable@@UACXPBUHDC__@@PAVscreen@@@Z	PROC NEAR	; moveable::Show COMDAT
; Line 1005
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
; Line 1008
	push	WORD PTR [bp+8]	;hdc
	mov	ax,WORD PTR [si-36]
	mov	bx,WORD PTR [bp+6]	;Screen
	sub	ax,WORD PTR [bx+16]
	push	ax
	mov	ax,WORD PTR [si-34]
	mov	bx,WORD PTR [bp+6]	;Screen
	sub	ax,WORD PTR [bx+18]
	push	ax
	mov	bx,WORD PTR [si-52]
	mov	ax,WORD PTR [bx+2]
	add	ax,si
	sub	ax,52	;0034H
	push	ax
	call	?FrameWidth@object@@QACHXZ	; object::FrameWidth
	push	ax
	push	1
	mov	bx,WORD PTR [si-52]
	mov	ax,WORD PTR [bx+2]
	add	ax,si
	sub	ax,52	;0034H
	push	ax
	call	?FrameHeight@object@@QACHH@Z	; object::FrameHeight
	push	ax
	mov	bx,WORD PTR [bp+6]	;Screen
	push	WORD PTR [bx+2]
	push	WORD PTR [si-36]
	push	WORD PTR [si-34]
	call	FAR PTR WINGBITBLT
; Line 1012
	push	WORD PTR [bp+8]	;hdc
	mov	bx,WORD PTR [si-52]
	mov	bx,WORD PTR [bx+2]
	mov	ax,WORD PTR [bx-44][si]
	mov	bx,WORD PTR [bp+6]	;Screen
	sub	ax,WORD PTR [bx+16]
	push	ax
	mov	bx,WORD PTR [si-52]
	mov	bx,WORD PTR [bx+2]
	mov	ax,WORD PTR [bx-42][si]
	mov	bx,WORD PTR [bp+6]	;Screen
	sub	ax,WORD PTR [bx+18]
	push	ax
	mov	bx,WORD PTR [si-52]
	mov	ax,WORD PTR [bx+2]
	add	ax,si
	sub	ax,52	;0034H
	push	ax
	call	?FrameWidth@object@@QACHXZ	; object::FrameWidth
	push	ax
	push	1
	mov	bx,WORD PTR [si-52]
	mov	ax,WORD PTR [bx+2]
	add	ax,si
	sub	ax,52	;0034H
	push	ax
	call	?FrameHeight@object@@QACHH@Z	; object::FrameHeight
	push	ax
	mov	bx,WORD PTR [bp+6]	;Screen
	push	WORD PTR [bx+2]
	mov	bx,WORD PTR [si-52]
	mov	bx,WORD PTR [bx+2]
	push	WORD PTR [bx-44][si]
	mov	bx,WORD PTR [si-52]
	mov	bx,WORD PTR [bx+2]
	push	WORD PTR [bx-42][si]
	call	FAR PTR WINGBITBLT
; Line 1013
	jmp	$EX6878
$EX6878:
	pop	si
	pop	di
	leave	
	ret	6

?Show@moveable@@UACXPBUHDC__@@PAVscreen@@@Z	ENDP
	PUBLIC	??0mech@@QAC@HHHQAPADQAH11HHW4boolean@@H@Z	; mech::mech
??0mech@@QAC@HHHQAPADQAH11HHW4boolean@@H@Z	PROC NEAR	; mech::mech COMDAT
; Line 18
	push	bp
	mov	bp,sp
	mov	ax,0
	call	__aNchkstk
	push	di
	push	si
	mov	si,WORD PTR [bp+4]	;this
	mov	di,WORD PTR [bp+6]	;$initVBases
;	register si = this
;	_X = 28
;	_Y = 26
;	_NumberOfSprites = 24
;	BMPName = 22
;	BMPFrames = 20
;	BMPWidth = 18
;	BMPHeight = 16
;	_Timer = 14
;	_Period = 12
;	_IsVisible = 10
;	_Layer = 8
;	register di = $initVBases
	cmp	di,0
	jne	$JCC20
	jmp	$I7056
$JCC20:
	mov	WORD PTR [si+2],OFFSET DGROUP:??_8mech@@7Bmoveable@@@
	mov	WORD PTR [si+52],OFFSET DGROUP:??_8mech@@7Banimated@@@
	lea	ax,WORD PTR [si+62]
	push	ax
	call	??0object@@QAC@XZ	; object::object
$I7056:
	push	WORD PTR [bp+28]	;_X
	push	WORD PTR [bp+26]	;_Y
	push	WORD PTR [bp+24]	;_NumberOfSprites
	push	WORD PTR [bp+22]	;BMPName
	push	WORD PTR [bp+20]	;BMPFrames
	push	WORD PTR [bp+18]	;BMPWidth
	push	WORD PTR [bp+16]	;BMPHeight
	push	WORD PTR [bp+14]	;_Timer
	push	WORD PTR [bp+12]	;_Period
	push	WORD PTR [bp+10]	;_IsVisible
	push	WORD PTR [bp+8]	;_Layer
	push	0
	push	si
	call	??0player@@QAC@HHHQAPADQAH11HHW4boolean@@H@Z	; player::player
	mov	WORD PTR [si],OFFSET DGROUP:??_7mech@@6Bmoveable@@@
	mov	bx,WORD PTR [si+2]
	mov	bx,WORD PTR [bx+2]
	mov	WORD PTR [bx+2][si],OFFSET DGROUP:??_7mech@@6Bobject@@@
	mov	bx,WORD PTR [si+2]
	mov	ax,WORD PTR [bx+2]
	sub	ax,60	;003cH
	mov	bx,WORD PTR [si+2]
	mov	bx,WORD PTR [bx+2]
	mov	WORD PTR [bx][si],ax
; Line 19
	mov	ax,si
	jmp	$EX7055
$EX7055:
	pop	si
	pop	di
	leave	
	ret	26	;001aH

??0mech@@QAC@HHHQAPADQAH11HHW4boolean@@H@Z	ENDP
	PUBLIC	?InitMove@mech@@UACXPBUHWND__@@HHPAVscreen@@@Z	; mech::InitMove
?InitMove@mech@@UACXPBUHWND__@@HHPAVscreen@@@Z	PROC NEAR	; mech::InitMove COMDAT
; Line 23
	push	bp
	mov	bp,sp
	mov	ax,0
	call	__aNchkstk
	push	di
	push	si
	mov	si,WORD PTR [bp+4]	;this
;	register si = this
;	hwnd = 12
;	_NewX = 10
;	_NewY = 8
;	Screen = 6
; Line 24
	mov	ax,WORD PTR [bp+10]	;_NewX
	mov	bx,WORD PTR [si+2]
	mov	bx,WORD PTR [bx+2]
	cmp	WORD PTR [bx+10][si],ax
	jg	$JCC26
	jmp	$I7063
$JCC26:
; Line 25
; Line 26
	mov	bx,WORD PTR [si+2]
	mov	bx,WORD PTR [bx+2]
	mov	WORD PTR [bx+22][si],0
; Line 27
; Line 28
	jmp	$I7064
$I7063:
; Line 29
; Line 30
	mov	bx,WORD PTR [si+2]
	mov	bx,WORD PTR [bx+2]
	mov	WORD PTR [bx+22][si],0
; Line 31
$I7064:
; Line 33
	mov	bx,WORD PTR [si+2]
	mov	bx,WORD PTR [bx+2]
	mov	WORD PTR [bx+24][si],0
; Line 35
	push	WORD PTR [bp+12]	;hwnd
	push	WORD PTR [bp+10]	;_NewX
	push	WORD PTR [bp+8]	;_NewY
	push	WORD PTR [bp+6]	;Screen
	push	si
	call	?InitMove@moveable@@UACXPBUHWND__@@HHPAVscreen@@@Z	; moveable::InitMove
; Line 36
	jmp	$EX7062
$EX7062:
	pop	si
	pop	di
	leave	
	ret	10	;000aH

?InitMove@mech@@UACXPBUHWND__@@HHPAVscreen@@@Z	ENDP
	PUBLIC	?EndMove@mech@@UACXPBUHWND__@@PBUHDC__@@PAVscreen@@@Z	; mech::EndMove
?EndMove@mech@@UACXPBUHWND__@@PBUHDC__@@PAVscreen@@@Z	PROC NEAR	; mech::EndMove COMDAT
; Line 39
	push	bp
	mov	bp,sp
	mov	ax,0
	call	__aNchkstk
	push	di
	push	si
	mov	si,WORD PTR [bp+4]	;this
;	register si = this
;	hwnd = 10
;	hdc = 8
;	Screen = 6
; Line 40
	mov	bx,WORD PTR [si+2]
	mov	bx,WORD PTR [bx+2]
	mov	WORD PTR [bx+22][si],0
; Line 41
	mov	bx,WORD PTR [si+2]
	mov	bx,WORD PTR [bx+2]
	mov	WORD PTR [bx+24][si],0
; Line 43
	push	WORD PTR [bp+10]	;hwnd
	push	WORD PTR [bp+8]	;hdc
	push	WORD PTR [bp+6]	;Screen
	push	si
	call	?EndMove@moveable@@UACXPBUHWND__@@PBUHDC__@@PAVscreen@@@Z	; moveable::EndMove
; Line 44
	jmp	$EX7069
$EX7069:
	pop	si
	pop	di
	leave	
	ret	8

?EndMove@mech@@UACXPBUHWND__@@PBUHDC__@@PAVscreen@@@Z	ENDP
	PUBLIC	?UpdateBufferSize@screen@@QACXXZ	; screen::UpdateBufferSize
?UpdateBufferSize@screen@@QACXXZ	PROC NEAR	; screen::UpdateBufferSize COMDAT
; Line 345
	push	bp
	mov	bp,sp
	mov	ax,0
	call	__aNchkstk
	push	di
	push	si
	mov	si,WORD PTR [bp+4]	;this
;	register si = this
; Line 346
	mov	ax,WORD PTR [si+12]
	cwd	
	mov	WORD PTR [si+36],ax
	mov	WORD PTR [si+38],dx
; Line 347
	mov	ax,WORD PTR [si+14]
	cwd	
	mov	WORD PTR [si+40],ax
	mov	WORD PTR [si+42],dx
; Line 348
	jmp	$EX6289
$EX6289:
	pop	si
	pop	di
	leave	
	ret	2

?UpdateBufferSize@screen@@QACXXZ	ENDP
	PUBLIC	?Sprite@object@@QACAAVsprite@@XZ	; object::Sprite
?Sprite@object@@QACAAVsprite@@XZ	PROC NEAR	; object::Sprite COMDAT
; Line 575
	push	bp
	mov	bp,sp
	mov	ax,0
	call	__aNchkstk
	push	di
	push	si
	mov	si,WORD PTR [bp+4]	;this
;	register si = this
; Line 576
	mov	ax,WORD PTR [si+20]
	mov	cx,ax
	shl	ax,1
	add	ax,cx
	shl	ax,1
	add	ax,cx
	shl	ax,1
	add	ax,WORD PTR [si+16]
	jmp	$EX6579
; Line 577
$EX6579:
	pop	si
	pop	di
	leave	
	ret	2

?Sprite@object@@QACAAVsprite@@XZ	ENDP
	PUBLIC	?Frame@object@@QACPEUtagBITMAPINFOHEADER@@XZ	; object::Frame
?Frame@object@@QACPEUtagBITMAPINFOHEADER@@XZ	PROC NEAR	; object::Frame COMDAT
; Line 586
	push	bp
	mov	bp,sp
	mov	ax,4
	call	__aNchkstk
	push	di
	push	si
	mov	si,WORD PTR [bp+4]	;this
;	register si = this
; Line 587
	push	si
	call	?Sprite@object@@QACAAVsprite@@XZ	; object::Sprite
	mov	bx,ax
	mov	WORD PTR [bp-2],bx
	mov	ax,WORD PTR [bx]
	mov	WORD PTR [bp-4],ax
	push	WORD PTR [si+22]
	push	WORD PTR [bp-2]
	mov	bx,WORD PTR [bp-4]
	call	WORD PTR [bx]
	jmp	$EX6585
; Line 588
$EX6585:
	pop	si
	pop	di
	leave	
	ret	2

?Frame@object@@QACPEUtagBITMAPINFOHEADER@@XZ	ENDP
	PUBLIC	?FrameWidth@object@@QACHXZ	; object::FrameWidth
?FrameWidth@object@@QACHXZ	PROC NEAR	; object::FrameWidth COMDAT
; Line 591
	push	bp
	mov	bp,sp
	mov	ax,0
	call	__aNchkstk
	push	di
	push	si
	mov	si,WORD PTR [bp+4]	;this
;	register si = this
; Line 592
	push	si
	call	?Sprite@object@@QACAAVsprite@@XZ	; object::Sprite
	mov	bx,ax
	mov	ax,WORD PTR [bx+4]
	jmp	$EX6588
; Line 593
$EX6588:
	pop	si
	pop	di
	leave	
	ret	2

?FrameWidth@object@@QACHXZ	ENDP
	PUBLIC	?FrameHeight@object@@QACHH@Z	; object::FrameHeight
?FrameHeight@object@@QACHH@Z	PROC NEAR	; object::FrameHeight COMDAT
; Line 596
	push	bp
	mov	bp,sp
	mov	ax,0
	call	__aNchkstk
	push	di
	push	si
	mov	si,WORD PTR [bp+4]	;this
;	register si = this
;	Orientation = 6
; Line 597
	push	si
	call	?Sprite@object@@QACAAVsprite@@XZ	; object::Sprite
	mov	bx,ax
	mov	ax,WORD PTR [bx+6]
	imul	WORD PTR [bp+6]	;Orientation
	jmp	$EX6591
; Line 598
$EX6591:
	pop	si
	pop	di
	leave	
	ret	4

?FrameHeight@object@@QACHH@Z	ENDP
	PUBLIC	?SaveBackGround@object@@QACXPBUHDC__@@@Z	; object::SaveBackGround
?SaveBackGround@object@@QACXPBUHDC__@@@Z	PROC NEAR	; object::SaveBackGround COMDAT
; Line 606
	push	bp
	mov	bp,sp
	mov	ax,0
	call	__aNchkstk
	push	di
	push	si
	mov	si,WORD PTR [bp+4]	;this
;	register si = this
;	hBuffer = 6
; Line 608
	push	WORD PTR [si+24]
	push	0
	push	0
	push	si
	call	?FrameWidth@object@@QACHXZ	; object::FrameWidth
	push	ax
	push	1
	push	si
	call	?FrameHeight@object@@QACHH@Z	; object::FrameHeight
	push	ax
	push	WORD PTR [bp+6]	;hBuffer
	push	WORD PTR [si+8]
	push	WORD PTR [si+10]
	push	204	;00ccH
	push	32	;0020H
	call	FAR PTR BITBLT
; Line 612
	jmp	$EX6597
$EX6597:
	pop	si
	pop	di
	leave	
	ret	4

?SaveBackGround@object@@QACXPBUHDC__@@@Z	ENDP
	PUBLIC	?PutIntoBuffer@object@@QACXPEUtagBITMAPINFO@@PEX@Z	; object::PutIntoBuffer
?PutIntoBuffer@object@@QACXPEUtagBITMAPINFO@@PEX@Z	PROC NEAR	; object::PutIntoBuffer COMDAT
; Line 624
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
; Line 628
	mov	al,BYTE PTR ?TransparentColor@@3EA	;TransparentColor
	push	ax
	push	0
	push	0
	push	0
	push	si
	call	?pBitMap@object@@QACPEUtagBITMAPINFOHEADER@@XZ	; object::pBitMap
	push	dx
	push	ax
	push	si
	call	?Frame@object@@QACPEUtagBITMAPINFOHEADER@@XZ	; object::Frame
	push	dx
	push	ax
	push	WORD PTR [si+10]
	push	WORD PTR [si+8]
	push	WORD PTR [bp+8]
	push	WORD PTR [bp+6]	;pBuffer
	push	WORD PTR [bp+12]
	push	WORD PTR [bp+10]	;pBufferHeader
	call	?TransparentDIBits@@YAHPEUtagBITMAPINFO@@PIXHHPFXPFU1@HHHE@Z	; TransparentDIBits
	add	sp,28	;001cH
; Line 629
	jmp	$EX6604
$EX6604:
	pop	si
	pop	di
	leave	
	ret	10	;000aH

?PutIntoBuffer@object@@QACXPEUtagBITMAPINFO@@PEX@Z	ENDP
	PUBLIC	?Paint@object@@UACXPAVscreen@@@Z	; object::Paint
?Paint@object@@UACXPAVscreen@@@Z	PROC NEAR	; object::Paint COMDAT
; Line 633
	push	bp
	mov	bp,sp
	mov	ax,0
	call	__aNchkstk
	push	di
	push	si
	mov	si,WORD PTR [bp+4]	;this
;	register si = this
;	Screen = 6
; Line 638
	mov	bx,WORD PTR [bp+6]	;Screen
	push	WORD PTR [bx+2]
	push	si
	call	?SaveBackGround@object@@QACXPBUHDC__@@@Z	; object::SaveBackGround
; Line 640
	push	WORD PTR [bp+6]	;Screen
	call	?UpdateBufferSize@screen@@QACXXZ	; screen::UpdateBufferSize
; Line 643
	mov	ax,WORD PTR [bp+6]	;Screen
	add	ax,32	;0020H
	push	ds
	push	ax
	mov	bx,WORD PTR [bp+6]	;Screen
	push	WORD PTR [bx+6]
	push	WORD PTR [bx+4]
	push	si
	call	?PutIntoBuffer@object@@QACXPEUtagBITMAPINFO@@PEX@Z	; object::PutIntoBuffer
; Line 644
	jmp	$EX6608
$EX6608:
	pop	si
	pop	di
	leave	
	ret	4

?Paint@object@@UACXPAVscreen@@@Z	ENDP
	PUBLIC	?Hide@object@@UACXPBUHDC__@@PAVscreen@@@Z	; object::Hide
?Hide@object@@UACXPBUHDC__@@PAVscreen@@@Z	PROC NEAR	; object::Hide COMDAT
; Line 648
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
; Line 651
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
	push	1
	push	si
	call	?FrameHeight@object@@QACHH@Z	; object::FrameHeight
	push	ax
	mov	bx,WORD PTR [bp+6]	;Screen
	push	WORD PTR [bx+2]
	push	WORD PTR [si+8]
	push	WORD PTR [si+10]
	call	FAR PTR WINGBITBLT
; Line 652
	jmp	$EX6613
$EX6613:
	pop	si
	pop	di
	leave	
	ret	6

?Hide@object@@UACXPBUHDC__@@PAVscreen@@@Z	ENDP
	PUBLIC	?Show@object@@UACXPBUHDC__@@PAVscreen@@@Z	; object::Show
?Show@object@@UACXPBUHDC__@@PAVscreen@@@Z	PROC NEAR	; object::Show COMDAT
; Line 655
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
; Line 662
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
	push	1
	push	si
	call	?FrameHeight@object@@QACHH@Z	; object::FrameHeight
	push	ax
	mov	bx,WORD PTR [bp+6]	;Screen
	push	WORD PTR [bx+2]
	push	WORD PTR [si+8]
	push	WORD PTR [si+10]
	call	FAR PTR WINGBITBLT
; Line 663
	jmp	$EX6617
$EX6617:
	pop	si
	pop	di
	leave	
	ret	6

?Show@object@@UACXPBUHDC__@@PAVscreen@@@Z	ENDP
	PUBLIC	?NextFrame@object@@UACPEUtagBITMAPINFOHEADER@@XZ	; object::NextFrame
?NextFrame@object@@UACPEUtagBITMAPINFOHEADER@@XZ	PROC NEAR	; object::NextFrame COMDAT
; Line 673
	push	bp
	mov	bp,sp
	mov	ax,0
	call	__aNchkstk
	push	di
	push	si
	mov	si,WORD PTR [bp+4]	;this
;	register si = this
; Line 674
	push	si
	call	?Frame@object@@QACPEUtagBITMAPINFOHEADER@@XZ	; object::Frame
	jmp	$EX6625
; Line 675
$EX6625:
	pop	si
	pop	di
	leave	
	ret	2

?NextFrame@object@@UACPEUtagBITMAPINFOHEADER@@XZ	ENDP
	PUBLIC	?PreviousFrame@object@@UACPEUtagBITMAPINFOHEADER@@XZ	; object::PreviousFrame
?PreviousFrame@object@@UACPEUtagBITMAPINFOHEADER@@XZ	PROC NEAR	; object::PreviousFrame COMDAT
; Line 678
	push	bp
	mov	bp,sp
	mov	ax,0
	call	__aNchkstk
	push	di
	push	si
	mov	si,WORD PTR [bp+4]	;this
;	register si = this
; Line 679
	push	si
	call	?Frame@object@@QACPEUtagBITMAPINFOHEADER@@XZ	; object::Frame
	jmp	$EX6628
; Line 680
$EX6628:
	pop	si
	pop	di
	leave	
	ret	2

?PreviousFrame@object@@UACPEUtagBITMAPINFOHEADER@@XZ	ENDP
	PUBLIC	??0object@@QAC@XZ	; object::object
??0object@@QAC@XZ	PROC NEAR	; object::object COMDAT
; Line 683
	push	bp
	mov	bp,sp
	mov	ax,0
	call	__aNchkstk
	push	di
	push	si
	mov	si,WORD PTR [bp+4]	;this
;	register si = this
	mov	WORD PTR [si],OFFSET DGROUP:??_7object@@6B@
	mov	ax,si
	jmp	$EX6631
$EX6631:
	pop	si
	pop	di
	leave	
	ret	2

??0object@@QAC@XZ	ENDP
	PUBLIC	?Paint@moveable@@UACXHHPAVscreen@@@Z	; moveable::Paint
?Paint@moveable@@UACXHHPAVscreen@@@Z	PROC NEAR	; moveable::Paint COMDAT
; Line 986
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
; Line 987
	mov	bx,WORD PTR [bp+6]	;Screen
	push	WORD PTR [bx+2]
	mov	bx,WORD PTR [si+2]
	mov	ax,WORD PTR [bx+2]
	add	ax,si
	add	ax,2
	push	ax
	call	?RestoreBackGround@object@@QACXPBUHDC__@@@Z	; object::RestoreBackGround
; Line 989
	push	WORD PTR [bp+10]	;_X
	push	WORD PTR [bp+8]	;_Y
	push	si
	call	?SetPosition@moveable@@QACXHH@Z	; moveable::SetPosition
; Line 992
	push	WORD PTR [bp+6]	;Screen
	mov	bx,WORD PTR [si+2]
	mov	ax,WORD PTR [bx+2]
	add	ax,si
	add	ax,2
	push	ax
	call	?Paint@object@@UACXPAVscreen@@@Z	; object::Paint
; Line 1002
	jmp	$EX6874
$EX6874:
	pop	si
	pop	di
	leave	
	ret	8

?Paint@moveable@@UACXHHPAVscreen@@@Z	ENDP
	PUBLIC	?Move1Step@actor@@UACXPBUHWND__@@PAVscreen@@@Z	; actor::Move1Step
?Move1Step@actor@@UACXPBUHWND__@@PAVscreen@@@Z	PROC NEAR	; actor::Move1Step COMDAT
; Line 1080
	push	bp
	mov	bp,sp
	mov	ax,0
	call	__aNchkstk
	push	di
	push	si
	mov	si,WORD PTR [bp+4]	;this
;	register si = this
;	hwnd = 8
;	Screen = 6
; Line 1081
	lea	ax,WORD PTR [si+56]
	push	ax
	call	?NextFrame@animated@@UACPEUtagBITMAPINFOHEADER@@XZ	; animated::NextFrame
; Line 1082
	push	WORD PTR [bp+8]	;hwnd
	push	WORD PTR [bp+6]	;Screen
	push	si
	call	?Move1Step@moveable@@UACXPBUHWND__@@PAVscreen@@@Z	; moveable::Move1Step
; Line 1083
	jmp	$EX6946
$EX6946:
	pop	si
	pop	di
	leave	
	ret	6

?Move1Step@actor@@UACXPBUHWND__@@PAVscreen@@@Z	ENDP
	PUBLIC	??0player@@QAC@HHHQAPADQAH11HHW4boolean@@H@Z	; player::player
??0player@@QAC@HHHQAPADQAH11HHW4boolean@@H@Z	PROC NEAR	; player::player COMDAT
; Line 1106
	push	bp
	mov	bp,sp
	mov	ax,0
	call	__aNchkstk
	push	di
	push	si
	mov	si,WORD PTR [bp+4]	;this
	mov	di,WORD PTR [bp+6]	;$initVBases
;	register si = this
;	_X = 28
;	_Y = 26
;	_NumberOfSprites = 24
;	BMPName = 22
;	BMPFrames = 20
;	BMPWidth = 18
;	BMPHeight = 16
;	_Timer = 14
;	_Period = 12
;	_IsVisible = 10
;	_Layer = 8
;	register di = $initVBases
	cmp	di,0
	jne	$JCC20
	jmp	$I6996
$JCC20:
	mov	WORD PTR [si+2],OFFSET DGROUP:??_8player@@7Bmoveable@@@
	mov	WORD PTR [si+52],OFFSET DGROUP:??_8player@@7Banimated@@@
	lea	ax,WORD PTR [si+62]
	push	ax
	call	??0object@@QAC@XZ	; object::object
$I6996:
	push	WORD PTR [bp+28]	;_X
	push	WORD PTR [bp+26]	;_Y
	push	WORD PTR [bp+24]	;_NumberOfSprites
	push	WORD PTR [bp+22]	;BMPName
	push	WORD PTR [bp+20]	;BMPFrames
	push	WORD PTR [bp+18]	;BMPWidth
	push	WORD PTR [bp+16]	;BMPHeight
	push	WORD PTR [bp+14]	;_Timer
	push	WORD PTR [bp+12]	;_Period
	push	WORD PTR [bp+10]	;_IsVisible
	push	WORD PTR [bp+8]	;_Layer
	push	0
	push	si
	call	??0actor@@QAC@HHHQAPADQAH11HHW4boolean@@H@Z	; actor::actor
	mov	WORD PTR [si],OFFSET DGROUP:??_7player@@6Bmoveable@@@
	mov	bx,WORD PTR [si+2]
	mov	bx,WORD PTR [bx+2]
	mov	WORD PTR [bx+2][si],OFFSET DGROUP:??_7player@@6Bobject@@@
	mov	bx,WORD PTR [si+2]
	mov	ax,WORD PTR [bx+2]
	sub	ax,60	;003cH
	mov	bx,WORD PTR [si+2]
	mov	bx,WORD PTR [bx+2]
	mov	WORD PTR [bx][si],ax
; Line 1107
	mov	WORD PTR [si+54],0
; Line 1108
	sub	ax,ax
	mov	WORD PTR [si+58],ax
	mov	WORD PTR [si+56],ax
; Line 1109
	mov	ax,si
	jmp	$EX6995
$EX6995:
	pop	si
	pop	di
	leave	
	ret	26	;001aH

??0player@@QAC@HHHQAPADQAH11HHW4boolean@@H@Z	ENDP
	PUBLIC	?pBitMap@object@@QACPEUtagBITMAPINFOHEADER@@XZ	; object::pBitMap
?pBitMap@object@@QACPEUtagBITMAPINFOHEADER@@XZ	PROC NEAR	; object::pBitMap COMDAT
; Line 580
	push	bp
	mov	bp,sp
	mov	ax,0
	call	__aNchkstk
	push	di
	push	si
	mov	si,WORD PTR [bp+4]	;this
;	register si = this
; Line 581
	push	si
	call	?Sprite@object@@QACAAVsprite@@XZ	; object::Sprite
	mov	bx,ax
	mov	ax,WORD PTR [bx+10]
	mov	dx,WORD PTR [bx+12]
	jmp	$EX6582
; Line 582
$EX6582:
	pop	si
	pop	di
	leave	
	ret	2

?pBitMap@object@@QACPEUtagBITMAPINFOHEADER@@XZ	ENDP
	PUBLIC	?RestoreBackGround@object@@QACXPBUHDC__@@@Z	; object::RestoreBackGround
?RestoreBackGround@object@@QACXPBUHDC__@@@Z	PROC NEAR	; object::RestoreBackGround COMDAT
; Line 615
	push	bp
	mov	bp,sp
	mov	ax,0
	call	__aNchkstk
	push	di
	push	si
	mov	si,WORD PTR [bp+4]	;this
;	register si = this
;	hBuffer = 6
; Line 617
	push	WORD PTR [bp+6]	;hBuffer
	push	WORD PTR [si+8]
	push	WORD PTR [si+10]
	push	si
	call	?FrameWidth@object@@QACHXZ	; object::FrameWidth
	push	ax
	push	1
	push	si
	call	?FrameHeight@object@@QACHH@Z	; object::FrameHeight
	push	ax
	push	WORD PTR [si+24]
	push	0
	push	0
	push	204	;00ccH
	push	32	;0020H
	call	FAR PTR BITBLT
; Line 621
	jmp	$EX6600
$EX6600:
	pop	si
	pop	di
	leave	
	ret	4

?RestoreBackGround@object@@QACXPBUHDC__@@@Z	ENDP
	PUBLIC	?SetPosition@moveable@@QACXHH@Z	; moveable::SetPosition
?SetPosition@moveable@@QACXHH@Z	PROC NEAR	; moveable::SetPosition COMDAT
; Line 977
	push	bp
	mov	bp,sp
	mov	ax,0
	call	__aNchkstk
	push	di
	push	si
	mov	si,WORD PTR [bp+4]	;this
;	register si = this
;	_X = 8
;	_Y = 6
; Line 978
	mov	bx,WORD PTR [si+2]
	mov	bx,WORD PTR [bx+2]
	mov	ax,WORD PTR [bx+10][si]
	mov	WORD PTR [si+18],ax
; Line 979
	mov	bx,WORD PTR [si+2]
	mov	bx,WORD PTR [bx+2]
	mov	ax,WORD PTR [bx+12][si]
	mov	WORD PTR [si+20],ax
; Line 981
	mov	ax,WORD PTR [bp+8]	;_X
	mov	bx,WORD PTR [si+2]
	mov	bx,WORD PTR [bx+2]
	mov	WORD PTR [bx+10][si],ax
; Line 982
	mov	ax,WORD PTR [bp+6]	;_Y
	mov	bx,WORD PTR [si+2]
	mov	bx,WORD PTR [bx+2]
	mov	WORD PTR [bx+12][si],ax
; Line 983
	jmp	$EX6869
$EX6869:
	pop	si
	pop	di
	leave	
	ret	6

?SetPosition@moveable@@QACXHH@Z	ENDP
	PUBLIC	??0actor@@QAC@HHHQAPADQAH11HHW4boolean@@H@Z	; actor::actor
??0actor@@QAC@HHHQAPADQAH11HHW4boolean@@H@Z	PROC NEAR	; actor::actor COMDAT
; Line 1071
	push	bp
	mov	bp,sp
	mov	ax,0
	call	__aNchkstk
	push	di
	push	si
	mov	si,WORD PTR [bp+4]	;this
	mov	di,WORD PTR [bp+6]	;$initVBases
;	register si = this
;	_X = 28
;	_Y = 26
;	_NumberOfSprites = 24
;	BMPName = 22
;	BMPFrames = 20
;	BMPWidth = 18
;	BMPHeight = 16
;	_Timer = 14
;	_Period = 12
;	_IsVisible = 10
;	_Layer = 8
;	register di = $initVBases
	cmp	di,0
	jne	$JCC20
	jmp	$I6942
$JCC20:
	mov	WORD PTR [si+2],OFFSET DGROUP:??_8actor@@7Bmoveable@@@
	mov	WORD PTR [si+52],OFFSET DGROUP:??_8actor@@7Banimated@@@
	lea	ax,WORD PTR [si+56]
	push	ax
	call	??0object@@QAC@XZ	; object::object
$I6942:
	push	WORD PTR [bp+28]	;_X
	push	WORD PTR [bp+26]	;_Y
	push	WORD PTR [bp+14]	;_Timer
	push	WORD PTR [bp+12]	;_Period
	push	WORD PTR [bp+10]	;_IsVisible
	push	WORD PTR [bp+8]	;_Layer
	push	0
	push	si
	call	??0moveable@@IAC@HHHHW4boolean@@H@Z	; moveable::moveable
	push	0
	lea	ax,WORD PTR [si+52]
	push	ax
	call	??0animated@@QAC@XZ	; animated::animated
	mov	WORD PTR [si],OFFSET DGROUP:??_7actor@@6Bmoveable@@@
	mov	bx,WORD PTR [si+2]
	mov	bx,WORD PTR [bx+2]
	mov	WORD PTR [bx+2][si],OFFSET DGROUP:??_7actor@@6Bobject@@@
	mov	bx,WORD PTR [si+2]
	mov	ax,WORD PTR [bx+2]
	sub	ax,54	;0036H
	mov	bx,WORD PTR [si+2]
	mov	bx,WORD PTR [bx+2]
	mov	WORD PTR [bx][si],ax
; Line 1074
	push	WORD PTR [bp+24]	;_NumberOfSprites
	push	WORD PTR [bp+22]	;BMPName
	push	WORD PTR [bp+20]	;BMPFrames
	push	WORD PTR [bp+18]	;BMPWidth
	push	WORD PTR [bp+16]	;BMPHeight
	mov	bx,WORD PTR [si+2]
	mov	ax,WORD PTR [bx+2]
	add	ax,si
	add	ax,2
	push	ax
	call	?InitAnimated@object@@IACXHQAPADQAH11@Z	; object::InitAnimated
; Line 1076
	mov	ax,si
	jmp	$EX6941
$EX6941:
	pop	si
	pop	di
	leave	
	ret	26	;001aH

??0actor@@QAC@HHHQAPADQAH11HHW4boolean@@H@Z	ENDP
	PUBLIC	?InitAnimated@object@@IACXHQAPADQAH11@Z	; object::InitAnimated
?InitAnimated@object@@IACXHQAPADQAH11@Z	PROC NEAR	; object::InitAnimated COMDAT
; Line 818
	push	bp
	mov	bp,sp
	mov	ax,6
	call	__aNchkstk
	push	di
	push	si
	mov	si,WORD PTR [bp+4]	;this
;	_aad = -2
;	i = -4
;	register si = this
;	_NumberOfSprites = 14
;	BMPName = 12
;	BMPFrames = 10
;	BMPWidth = 8
;	BMPHeight = 6
; Line 819
	mov	ax,WORD PTR [bp+14]	;_NumberOfSprites
	mov	WORD PTR [si+18],ax
; Line 821
	mov	ax,WORD PTR [si+18]
	mov	WORD PTR [bp-2],ax	;_aad
	mov	cx,ax
	shl	ax,1
	add	ax,cx
	shl	ax,1
	add	ax,cx
	shl	ax,1
	add	ax,2
	push	ax
	call	??2@YAPAXI@Z	; operator new
	add	sp,2
	mov	WORD PTR [bp-6],ax
	cmp	ax,0
	jne	$JCC54
	jmp	$L7336
$JCC54:
	mov	ax,WORD PTR [bp-6]
	add	ax,2
	push	ax
	push	14	;000eH
	mov	ax,WORD PTR [bp-2]	;_aad
	mov	bx,WORD PTR [bp-6]
	mov	WORD PTR [bx],ax
	push	ax
	push	OFFSET ??0sprite@@QAC@XZ	;sprite::sprite
	call	??_H@YCXPAXIHP6CX0@Z@Z	; ??_H@YCXPAXIHP6CX0@Z@Z
	mov	ax,WORD PTR [bp-6]
	add	ax,2
	mov	WORD PTR [si+16],ax
	jmp	$L7337
$L7336:
	mov	WORD PTR [si+16],0
$L7337:
; Line 823
	mov	WORD PTR [bp-4],0	;i
	jmp	$F6696
$FC6697:
	inc	WORD PTR [bp-4]	;i
$F6696:
	mov	ax,WORD PTR [bp-4]	;i
	cmp	WORD PTR [si+18],ax
	ja	$JCC117
	jmp	$FB6698
$JCC117:
; Line 824
; Line 826
	mov	bx,WORD PTR [bp-4]	;i
	shl	bx,1
	mov	di,WORD PTR [bp+12]	;BMPName
	push	ds
	push	WORD PTR [bx][di]
	call	_DibOpenFile
	add	sp,4
	push	dx
	push	ax
	mov	bx,WORD PTR [bp-4]	;i
	shl	bx,1
	mov	di,WORD PTR [bp+10]	;BMPFrames
	push	WORD PTR [bx][di]
	mov	bx,WORD PTR [bp-4]	;i
	shl	bx,1
	mov	di,WORD PTR [bp+8]	;BMPWidth
	push	WORD PTR [bx][di]
	mov	bx,WORD PTR [bp-4]	;i
	shl	bx,1
	mov	di,WORD PTR [bp+6]	;BMPHeight
	push	WORD PTR [bx][di]
	mov	ax,WORD PTR [bp-4]	;i
	mov	cx,ax
	shl	ax,1
	add	ax,cx
	shl	ax,1
	add	ax,cx
	shl	ax,1
	add	ax,WORD PTR [si+16]
	push	ax
	call	?Init@sprite@@QACXPEUtagBITMAPINFOHEADER@@HHH@Z	; sprite::Init
; Line 827
	jmp	$FC6697
$FB6698:
; Line 829
	jmp	$EX6690
$EX6690:
	pop	si
	pop	di
	leave	
	ret	12	;000cH

?InitAnimated@object@@IACXHQAPADQAH11@Z	ENDP
	PUBLIC	??0animated@@QAC@XZ	; animated::animated
??0animated@@QAC@XZ	PROC NEAR	; animated::animated COMDAT
; Line 867
	push	bp
	mov	bp,sp
	mov	ax,0
	call	__aNchkstk
	push	di
	push	si
	mov	si,WORD PTR [bp+4]	;this
	mov	di,WORD PTR [bp+6]	;$initVBases
;	register si = this
;	register di = $initVBases
	cmp	di,0
	jne	$JCC20
	jmp	$I6746
$JCC20:
	mov	WORD PTR [si],OFFSET DGROUP:??_8animated@@7B@
	lea	ax,WORD PTR [si+4]
	push	ax
	call	??0object@@QAC@XZ	; object::object
$I6746:
	mov	bx,WORD PTR [si]
	mov	bx,WORD PTR [bx+2]
	mov	WORD PTR [bx][si],OFFSET DGROUP:??_7animated@@6B@
	mov	bx,WORD PTR [si]
	mov	ax,WORD PTR [bx+2]
	sub	ax,4
	mov	bx,WORD PTR [si]
	mov	bx,WORD PTR [bx+2]
	mov	WORD PTR [bx-2][si],ax
	mov	ax,si
	jmp	$EX6745
$EX6745:
	pop	si
	pop	di
	leave	
	ret	4

??0animated@@QAC@XZ	ENDP
	PUBLIC	??0moveable@@IAC@HHHHW4boolean@@H@Z	; moveable::moveable
??0moveable@@IAC@HHHHW4boolean@@H@Z	PROC NEAR	; moveable::moveable COMDAT
; Line 1036
	push	bp
	mov	bp,sp
	mov	ax,0
	call	__aNchkstk
	push	di
	push	si
	mov	si,WORD PTR [bp+4]	;this
	mov	di,WORD PTR [bp+6]	;$initVBases
;	register si = this
;	_X = 18
;	_Y = 16
;	_Timer = 14
;	_Period = 12
;	_IsVisible = 10
;	_Layer = 8
;	register di = $initVBases
	cmp	di,0
	jne	$JCC20
	jmp	$I6888
$JCC20:
	mov	WORD PTR [si+2],OFFSET DGROUP:??_8moveable@@7B@
	lea	ax,WORD PTR [si+54]
	push	ax
	call	??0object@@QAC@XZ	; object::object
$I6888:
	mov	WORD PTR [si],OFFSET DGROUP:??_7moveable@@6B0@@
	mov	bx,WORD PTR [si+2]
	mov	bx,WORD PTR [bx+2]
	mov	WORD PTR [bx+2][si],OFFSET DGROUP:??_7moveable@@6Bobject@@@
	mov	bx,WORD PTR [si+2]
	mov	ax,WORD PTR [bx+2]
	sub	ax,52	;0034H
	mov	bx,WORD PTR [si+2]
	mov	bx,WORD PTR [bx+2]
	mov	WORD PTR [bx][si],ax
; Line 1038
	push	WORD PTR [bp+18]	;_X
	push	WORD PTR [bp+16]	;_Y
	push	WORD PTR [bp+10]	;_IsVisible
	push	WORD PTR [bp+8]	;_Layer
	mov	bx,WORD PTR [si+2]
	mov	ax,WORD PTR [bx+2]
	add	ax,si
	add	ax,2
	push	ax
	call	?InitMoveable@object@@IACXHHW4boolean@@H@Z	; object::InitMoveable
; Line 1040
	mov	bx,WORD PTR [si+2]
	mov	bx,WORD PTR [bx+2]
	mov	ax,WORD PTR [bx+10][si]
	mov	WORD PTR [si+18],ax
	mov	WORD PTR [si+22],ax
; Line 1041
	mov	bx,WORD PTR [si+2]
	mov	bx,WORD PTR [bx+2]
	mov	ax,WORD PTR [bx+12][si]
	mov	WORD PTR [si+20],ax
	mov	WORD PTR [si+24],ax
; Line 1043
	mov	ax,WORD PTR [bp+14]	;_Timer
	mov	WORD PTR [si+48],ax
; Line 1044
	mov	ax,WORD PTR [bp+12]	;_Period
	mov	WORD PTR [si+50],ax
; Line 1046
	mov	WORD PTR [si+30],20	;0014H
; Line 1047
	mov	WORD PTR [si+32],20	;0014H
; Line 1049
	mov	ax,si
	jmp	$EX6887
$EX6887:
	pop	si
	pop	di
	leave	
	ret	16	;0010H

??0moveable@@IAC@HHHHW4boolean@@H@Z	ENDP
	PUBLIC	??0sprite@@QAC@XZ	; sprite::sprite
??0sprite@@QAC@XZ	PROC NEAR	; sprite::sprite COMDAT
; Line 480
	push	bp
	mov	bp,sp
	mov	ax,0
	call	__aNchkstk
	push	di
	push	si
	mov	si,WORD PTR [bp+4]	;this
;	register si = this
	mov	WORD PTR [si],OFFSET DGROUP:??_7sprite@@6B@
; Line 481
	mov	WORD PTR [si+8],0
; Line 482
	sub	ax,ax
	mov	WORD PTR [si+12],ax
	mov	WORD PTR [si+10],ax
; Line 483
	mov	ax,si
	jmp	$EX6446
$EX6446:
	pop	si
	pop	di
	leave	
	ret	2

??0sprite@@QAC@XZ	ENDP
	PUBLIC	?Init@sprite@@QACXPEUtagBITMAPINFOHEADER@@HHH@Z	; sprite::Init
?Init@sprite@@QACXPEUtagBITMAPINFOHEADER@@HHH@Z	PROC NEAR	; sprite::Init COMDAT
; Line 487
	push	bp
	mov	bp,sp
	mov	ax,4
	call	__aNchkstk
	push	di
	push	si
	mov	si,WORD PTR [bp+4]	;this
;	_aab = -2
;	register si = this
;	_pBitMap = 12
;	_NumberOfFrames = 10
;	_FrameWidth = 8
;	_FrameHeight = 6
; Line 488
	mov	ax,WORD PTR [bp+12]	;_pBitMap
	mov	dx,WORD PTR [bp+14]
	mov	WORD PTR [si+10],ax
	mov	WORD PTR [si+12],dx
; Line 489
	mov	ax,WORD PTR [bp+10]	;_NumberOfFrames
	mov	WORD PTR [si+8],ax
; Line 490
	mov	ax,WORD PTR [bp+8]	;_FrameWidth
	mov	WORD PTR [si+4],ax
; Line 491
	mov	ax,WORD PTR [bp+6]	;_FrameHeight
	mov	WORD PTR [si+6],ax
; Line 494
	mov	ax,WORD PTR [si+8]
	mov	WORD PTR [bp-2],ax	;_aab
	mov	ax,WORD PTR [bp-2]	;_aab
	mov	cx,ax
	shl	ax,1
	add	ax,cx
	shl	ax,2
	push	ax
	call	??2@YAPAXI@Z	; operator new
	add	sp,2
	mov	WORD PTR [bp-4],ax
	cmp	ax,0
	jne	$JCC75
	jmp	$L7339
$JCC75:
	push	WORD PTR [bp-4]
	push	12	;000cH
	push	WORD PTR [bp-2]	;_aab
	push	OFFSET ??0frame@@QAC@XZ	;frame::frame
	call	??_H@YCXPAXIHP6CX0@Z@Z	; ??_H@YCXPAXIHP6CX0@Z@Z
	mov	ax,WORD PTR [bp-4]
	mov	WORD PTR [si+2],ax
	jmp	$L7340
$L7339:
	mov	WORD PTR [si+2],0
$L7340:
; Line 496
	push	WORD PTR [bp+14]
	push	WORD PTR [bp+12]	;_pBitMap
	push	si
	call	?SetBitMaps@sprite@@QACXPEUtagBITMAPINFOHEADER@@@Z	; sprite::SetBitMaps
; Line 498
	mov	ax,WORD PTR [bp+8]	;_FrameWidth
	cwd	
	les	bx,DWORD PTR [si+10]
	mov	WORD PTR es:[bx+4],ax
	mov	WORD PTR es:[bx+6],dx
; Line 499
	mov	ax,WORD PTR [bp+6]	;_FrameHeight
	cwd	
	les	bx,DWORD PTR [si+10]
	mov	WORD PTR es:[bx+8],ax
	mov	WORD PTR es:[bx+10],dx
; Line 500
	jmp	$EX6452
$EX6452:
	pop	si
	pop	di
	leave	
	ret	12	;000cH

?Init@sprite@@QACXPEUtagBITMAPINFOHEADER@@HHH@Z	ENDP
	PUBLIC	?SetBitMaps@sprite@@QACXPEUtagBITMAPINFOHEADER@@@Z	; sprite::SetBitMaps
?SetBitMaps@sprite@@QACXPEUtagBITMAPINFOHEADER@@@Z	PROC NEAR	; sprite::SetBitMaps COMDAT
; Line 503
	push	bp
	mov	bp,sp
	mov	ax,2
	call	__aNchkstk
	push	di
	push	si
	mov	si,WORD PTR [bp+4]	;this
;	i = -2
;	register si = this
;	_pBitMap = 6
; Line 504
	mov	WORD PTR [bp-2],0	;i
	jmp	$F6461
$FC6462:
	inc	WORD PTR [bp-2]	;i
$F6461:
	mov	ax,WORD PTR [bp-2]	;i
	cmp	WORD PTR [si+8],ax
	ja	$JCC31
	jmp	$FB6463
$JCC31:
; Line 505
; Line 506
	mov	di,WORD PTR [si+2]
	mov	bx,WORD PTR [bp-2]	;i
	mov	ax,bx
	shl	bx,1
	add	bx,ax
	shl	bx,2
	mov	WORD PTR [bx][di],0
; Line 507
	mov	di,WORD PTR [bp-2]	;i
	mov	ax,di
	shl	di,1
	add	di,ax
	shl	di,2
	mov	bx,WORD PTR [si+2]
	mov	WORD PTR [bx+2][di],0
; Line 508
	mov	di,WORD PTR [bp-2]	;i
	mov	ax,di
	shl	di,1
	add	di,ax
	shl	di,2
	mov	bx,WORD PTR [si+2]
	mov	WORD PTR [bx+4][di],0
; Line 509
	mov	di,WORD PTR [bp-2]	;i
	mov	ax,di
	shl	di,1
	add	di,ax
	shl	di,2
	mov	bx,WORD PTR [si+2]
	mov	WORD PTR [bx+6][di],0
; Line 511
	mov	di,WORD PTR [bp-2]	;i
	mov	ax,di
	shl	di,1
	add	di,ax
	shl	di,2
	mov	bx,WORD PTR [si+2]
	mov	ax,WORD PTR [si+4]
	mul	WORD PTR [si+6]
	mul	WORD PTR [bp-2]	;i
	les	bx,DWORD PTR [bp+6]	;_pBitMap
	mov	cx,WORD PTR es:[bx+32]
	shl	cx,2
	add	ax,cx
	les	bx,DWORD PTR [bp+6]	;_pBitMap
	add	ax,WORD PTR es:[bx]
	add	ax,WORD PTR [bp+6]	;_pBitMap
	mov	dx,WORD PTR [bp+8]
	mov	bx,WORD PTR [si+2]
	mov	WORD PTR [bx+8][di],ax
	mov	WORD PTR [bx+10][di],dx
; Line 513
	jmp	$FC6462
$FB6463:
; Line 514
	jmp	$EX6459
$EX6459:
	pop	si
	pop	di
	leave	
	ret	6

?SetBitMaps@sprite@@QACXPEUtagBITMAPINFOHEADER@@@Z	ENDP
	PUBLIC	?InitMoveable@object@@IACXHHW4boolean@@H@Z	; object::InitMoveable
?InitMoveable@object@@IACXHHW4boolean@@H@Z	PROC NEAR	; object::InitMoveable COMDAT
; Line 834
	push	bp
	mov	bp,sp
	mov	ax,2
	call	__aNchkstk
	push	di
	push	si
	mov	si,WORD PTR [bp+4]	;this
;	register si = this
;	_X = 12
;	_Y = 10
;	_IsVisible = 8
;	_Layer = 6
; Line 835
	cmp	WORD PTR ?ObjectList@@3PAVobject_list@@A,0	;ObjectList
	je	$JCC19
	jmp	$I6705
$JCC19:
; Line 836
; Line 837
	push	2
	call	??2@YAPAXI@Z	; operator new
	add	sp,2
	mov	WORD PTR [bp-2],ax
	cmp	ax,0
	jne	$JCC38
	jmp	$L7342
$JCC38:
	push	si
	push	WORD PTR [bp-2]
	call	??0object_list@@QAC@PAVobject@@@Z	; object_list::object_list
	jmp	$L7343
$L7342:
	mov	ax,0
$L7343:
	mov	WORD PTR ?ObjectList@@3PAVobject_list@@A,ax	;ObjectList
; Line 838
	mov	ax,0
	mov	WORD PTR [si+4],ax
	mov	WORD PTR [si+2],ax
; Line 839
; Line 840
	jmp	$I6708
$I6705:
; Line 841
; Line 842
	mov	bx,WORD PTR ?ObjectList@@3PAVobject_list@@A	;ObjectList
	mov	ax,WORD PTR [bx]
	mov	WORD PTR [si+2],ax
; Line 843
	mov	WORD PTR [si+4],0
; Line 845
	mov	bx,WORD PTR ?ObjectList@@3PAVobject_list@@A	;ObjectList
	mov	bx,WORD PTR [bx]
	mov	WORD PTR [bx+4],si
; Line 847
	mov	bx,WORD PTR ?ObjectList@@3PAVobject_list@@A	;ObjectList
	mov	WORD PTR [bx],si
; Line 848
$I6708:
; Line 850
	mov	ax,WORD PTR [bp+12]	;_X
	mov	WORD PTR [si+8],ax
; Line 851
	mov	ax,WORD PTR [bp+10]	;_Y
	mov	WORD PTR [si+10],ax
; Line 852
	mov	ax,WORD PTR [bp+6]	;_Layer
	mov	WORD PTR [si+6],ax
; Line 853
	mov	ax,WORD PTR [bp+8]	;_IsVisible
	mov	WORD PTR [si+32],ax
; Line 855
	mov	WORD PTR [si+20],0
; Line 856
	mov	WORD PTR [si+22],0
; Line 857
	jmp	$EX6704
$EX6704:
	pop	si
	pop	di
	leave	
	ret	10	;000aH

?InitMoveable@object@@IACXHHW4boolean@@H@Z	ENDP
	PUBLIC	??0frame@@QAC@XZ	; frame::frame
??0frame@@QAC@XZ	PROC NEAR	; frame::frame COMDAT
; Line 450
	push	bp
	mov	bp,sp
	mov	ax,0
	call	__aNchkstk
	push	di
	push	si
	mov	si,WORD PTR [bp+4]	;this
;	register si = this
; Line 451
	sub	ax,ax
	mov	WORD PTR [si+10],ax
	mov	WORD PTR [si+8],ax
; Line 452
	mov	ax,si
	jmp	$EX6414
$EX6414:
	pop	si
	pop	di
	leave	
	ret	2

??0frame@@QAC@XZ	ENDP
	PUBLIC	??0object_list@@QAC@PAVobject@@@Z	; object_list::object_list
??0object_list@@QAC@PAVobject@@@Z	PROC NEAR	; object_list::object_list COMDAT
; Line 535
	push	bp
	mov	bp,sp
	mov	ax,0
	call	__aNchkstk
	push	di
	push	si
	mov	si,WORD PTR [bp+4]	;this
;	register si = this
;	_FirstObject = 6
; Line 536
	mov	ax,WORD PTR [bp+6]	;_FirstObject
	mov	WORD PTR [si],ax
; Line 537
	mov	ax,si
	jmp	$EX6498
$EX6498:
	pop	si
	pop	di
	leave	
	ret	4

??0object_list@@QAC@PAVobject@@@Z	ENDP
_TEXT	ENDS
END
