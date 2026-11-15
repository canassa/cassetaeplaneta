;	Static Name Aliases
;
;	$S8418_?InKeyLeft@?1??AppWndProc@@ZCJPBUHWND__@@IIJ@Z@4W4boolean@@A	EQU	?InKeyLeft@?1??AppWndProc@@ZCJPBUHWND__@@IIJ@Z@4W4boolean@@A
;	$S8420_?InKeyRight@?1??AppWndProc@@ZCJPBUHWND__@@IIJ@Z@4W4boolean@@A	EQU	?InKeyRight@?1??AppWndProc@@ZCJPBUHWND__@@IIJ@Z@4W4boolean@@A
;	$S8422_?InKeyUp@?1??AppWndProc@@ZCJPBUHWND__@@IIJ@Z@4W4boolean@@A	EQU	?InKeyUp@?1??AppWndProc@@ZCJPBUHWND__@@IIJ@Z@4W4boolean@@A
;	$S8424_?InKeyDown@?1??AppWndProc@@ZCJPBUHWND__@@IIJ@Z@4W4boolean@@A	EQU	?InKeyDown@?1??AppWndProc@@ZCJPBUHWND__@@IIJ@Z@4W4boolean@@A
;	$S8426_?InKeySub@?1??AppWndProc@@ZCJPBUHWND__@@IIJ@Z@4W4boolean@@A	EQU	?InKeySub@?1??AppWndProc@@ZCJPBUHWND__@@IIJ@Z@4W4boolean@@A
;	$S8428_?InKeyAdd@?1??AppWndProc@@ZCJPBUHWND__@@IIJ@Z@4W4boolean@@A	EQU	?InKeyAdd@?1??AppWndProc@@ZCJPBUHWND__@@IIJ@Z@4W4boolean@@A
;	$S8430_?InitAnim@?1??AppWndProc@@ZCJPBUHWND__@@IIJ@Z@4W4boolean@@A	EQU	?InitAnim@?1??AppWndProc@@ZCJPBUHWND__@@IIJ@Z@4W4boolean@@A
;	$S8250_szAppName	EQU	szAppName
;	$S8251_hInstApp	EQU	hInstApp
;	$S8508__aag	EQU	_aag
;	$S8252_hwndApp	EQU	hwndApp
;	$S8253_hpalApp	EQU	hpalApp
;	$S8254_fAppActive	EQU	fAppActive
	TITLE   d:\lc\demo\demo.cpp
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
PUBLIC  ??_7_3D_actor@@6Bmoveable@@@
PUBLIC  ??_7_3D_actor@@6Banimated@@@
PUBLIC  ??_7_3D_object@@6B0@@
PUBLIC  ?pBuffer@@3PEXE
PUBLIC  ??_7_3D_actor@@6Bobject@@@
PUBLIC  ??_7_3D_object@@6Bobject@@@
PUBLIC  ?Buffer@@3PBUHDC__@@B
PUBLIC  ??_7_3D_actor@@6B_3D_object@@@
PUBLIC  ??_8_3D_object@@7B@
PUBLIC  ?pBackBuffer@@3PEXE
PUBLIC  ??_8_3D_actor@@7Bmoveable@@@
PUBLIC  ?BackBuffer@@3PBUHDC__@@B
PUBLIC  ??_8_3D_actor@@7Banimated@@@
PUBLIC  ?LP@@3Upal@@A
PUBLIC  ??_8_3D_actor@@7B_3D_object@@@
PUBLIC  ??_7occup_screen@@6B@
PUBLIC  ?gbmOldMonoBitmap@@3PBUHBITMAP__@@B
PUBLIC  ?gBackOldMonoBitmap@@3PBUHBITMAP__@@B
PUBLIC  ??_7_3D_player@@6Bmoveable@@@
PUBLIC  ??_7_3D_player@@6Banimated@@@
PUBLIC  ??_7_3D_player@@6Bobject@@@
PUBLIC  ??_7_3D_player@@6B_3D_object@@@
PUBLIC  ??_8_3D_player@@7Bmoveable@@@
PUBLIC  ??_8_3D_player@@7Banimated@@@
PUBLIC  ??_8_3D_player@@7B_3D_object@@@
PUBLIC  ?InicioBufferX@@3HA
PUBLIC  ??_7_3D_screen@@6B@
PUBLIC  ?InicioBufferY@@3HA
PUBLIC  ?Scrollx@@3HA
PUBLIC  ??_7animated@@6B0@@
PUBLIC  ?Scrolly@@3HA
PUBLIC  ??_7animated@@6Bobject@@@
PUBLIC  ?SpriteOrder@@3HA
PUBLIC  ??_7screen@@6B@
PUBLIC  ??_8animated@@7B@
PUBLIC  ?TommyNames@@3QAPADA
PUBLIC  ??_7tommy_screen@@6B@
PUBLIC  ??_7_3D_animated@@6Banimated@@@
PUBLIC  ??_7_3D_animated@@6Bobject@@@
PUBLIC  ??_7_3D_animated@@6B_3D_object@@@
PUBLIC  ?TommyFrames@@3QAHA
PUBLIC  ??_8_3D_animated@@7Banimated@@@
PUBLIC  ?TommyWidth@@3QAHA
PUBLIC  ??_8_3D_animated@@7B_3D_object@@@
PUBLIC  ?TommyHeight@@3QAHA
PUBLIC  ??_C@_0BO@GBKI@?$CI?$CF03d?0?$CF03d?$CJ?$DN?$DO?$CI?$CF03d?0?$CF03d?0?$CF03d?$CJ?$AA@
PUBLIC  ??_7_3D_moveable@@6Bmoveable@@@
PUBLIC  ??_7_3D_moveable@@6Bobject@@@
PUBLIC  ??_7_3D_moveable@@6B_3D_object@@@
PUBLIC  ??_8_3D_moveable@@7Bmoveable@@@
PUBLIC  ??_7tommy@@6Bmoveable@@@
PUBLIC  ??_8_3D_moveable@@7B_3D_object@@@
PUBLIC  ??_7tommy@@6Banimated@@@
PUBLIC  ??_7tommy@@6Bobject@@@
PUBLIC  ??_7tommy@@6B_3D_object@@@
PUBLIC  ??_8tommy@@7Bmoveable@@@
PUBLIC  ??_8tommy@@7Banimated@@@
PUBLIC  ??_8tommy@@7B_3D_object@@@
PUBLIC  ??_7object@@6B@
PUBLIC  ??_7moveable@@6B0@@
PUBLIC  ??_7moveable@@6Bobject@@@
PUBLIC  ??_8moveable@@7B@
EXTRN	__acrtused:ABS
EXTRN	_ClearSystemPalette:NEAR
EXTRN	?y3D@_3D_object@@UACHXZ:NEAR
EXTRN	DEFWINDOWPROC:FAR
EXTRN	??_I@YCXPAXIHP6CX0@Z@Z:NEAR
EXTRN	?Set3DPosition@_3D_screen@@UACXPAV_3D_object@@H@Z:NEAR
EXTRN	?z3D@_3D_object@@UACHXZ:NEAR
EXTRN	?CanGo@moveable@@UAC?AW4boolean@@PAVoccup_screen@@@Z:NEAR
EXTRN	_DibOpenFile:NEAR
EXTRN	_sprintf:NEAR
EXTRN	?w3D@_3D_object@@UACHXZ:NEAR
EXTRN	?DetectedCollision@moveable@@UAC?AW4boolean@@PAVobject@@PAVscreen@@@Z:NEAR
EXTRN	?InitAnim@animated@@UACXPBUHWND__@@PAVoccup_screen@@@Z:NEAR
EXTRN	LOADICON:FAR
EXTRN	?h3D@_3D_object@@UACHXZ:NEAR
EXTRN	DIALOGBOX:FAR
EXTRN	?d3D@_3D_object@@UACHXZ:NEAR
EXTRN	SHOWWINDOW:FAR
EXTRN	?EndAnim@animated@@UACXPBUHWND__@@PAVoccup_screen@@@Z:NEAR
EXTRN	?IncrOccupation@occup_matrix@@QACDPAVobject@@@Z:NEAR
EXTRN	BEGINPAINT:FAR
EXTRN	POSTMESSAGE:FAR
EXTRN	GETMODULEHANDLE:FAR
EXTRN	?Init@_3D_object@@UACPAV1@PAV_3D_screen@@@Z:NEAR
EXTRN	?DecrOccupation@occup_matrix@@QACDPAVobject@@@Z:NEAR
EXTRN	ENDPAINT:FAR
EXTRN	?EndAnim@animated@@UACXPBUHWND__@@PBUHDC__@@PAVoccup_screen@@@Z:NEAR
EXTRN	?Set3DPosition@_3D_object@@UACPAV1@PAV_3D_screen@@H@Z:NEAR
EXTRN	__aNchkstk:NEAR
EXTRN	?Anim1Frame@animated@@UACXPBUHWND__@@PAVoccup_screen@@@Z:NEAR
EXTRN	?Set3DOrigin@_3D_object@@UACPAV1@HH@Z:NEAR
EXTRN	?InitMove@moveable@@UACXPBUHWND__@@HHPAVoccup_screen@@@Z:NEAR
EXTRN	GETPROCADDRESS:FAR
EXTRN	?Set3DDimensions@_3D_object@@UACPAV1@HHH@Z:NEAR
EXTRN	?InitHMove@moveable@@UACXPBUHWND__@@PAVoccup_screen@@W4MVDIR@@@Z:NEAR
EXTRN	?Anim1Frame@_3D_animated@@UACXPBUHWND__@@PAV_3D_screen@@@Z:NEAR
EXTRN	DELETEDC:FAR
EXTRN	?DetectedCollision@_3D_moveable@@UAC?AW4boolean@@PAVobject@@PAV_3D_screen@@@Z:NEAR
EXTRN	_TranspDIBits:NEAR
EXTRN	?CanGo@_3D_moveable@@UAC?AW4boolean@@PAV_3D_screen@@@Z:NEAR
EXTRN	?InitVMove@moveable@@UACXPBUHWND__@@PAVoccup_screen@@W4MVDIR@@@Z:NEAR
EXTRN	?Init@screen@@UACPAV1@PBUHWND__@@@Z:NEAR
EXTRN	?EndMove@moveable@@UACXPBUHWND__@@PAVoccup_screen@@@Z:NEAR
EXTRN	MESSAGEBOX:FAR
EXTRN	ENDDIALOG:FAR
EXTRN	POSTQUITMESSAGE:FAR
EXTRN	INVALIDATERECT:FAR
EXTRN	?EndMove@moveable@@UACXPBUHWND__@@PBUHDC__@@PAVoccup_screen@@@Z:NEAR
EXTRN	?Move1Step@moveable@@UACXPBUHWND__@@PAVoccup_screen@@@Z:NEAR
EXTRN	??2@YAPAXI@Z:NEAR
EXTRN	?Move1Step@_3D_moveable@@UACXPBUHWND__@@PAV_3D_screen@@@Z:NEAR
EXTRN	LOADCURSOR:FAR
EXTRN	??3@YAXPAX@Z:NEAR
EXTRN	SELECTPALETTE:FAR
EXTRN	CREATEWINDOW:FAR
EXTRN	REALIZEPALETTE:FAR
EXTRN	GETDC:FAR
EXTRN	?Occupation@occup_matrix@@QACDHHHHAAPAVobject@@@Z:NEAR
EXTRN	RELEASEDC:FAR
EXTRN	PEEKMESSAGE:FAR
EXTRN	BITBLT:FAR
EXTRN	__aNldiv:NEAR
EXTRN	REGISTERCLASS:FAR
EXTRN	WAITMESSAGE:FAR
EXTRN	DELETEOBJECT:FAR
EXTRN	TEXTOUT:FAR
EXTRN	WINGBITBLT:FAR
EXTRN	SELECTOBJECT:FAR
EXTRN	??_H@YCXPAXIHP6CX0@Z@Z:NEAR
EXTRN	TRANSLATEMESSAGE:FAR
EXTRN	_strlen:NEAR
EXTRN	?x3D@_3D_object@@UACHXZ:NEAR
EXTRN	DISPATCHMESSAGE:FAR
EXTRN	_SetSystemTimer:DWORD
EXTRN	_KillSystemTimer:DWORD
EXTRN	?TransparentColor@@3EA:BYTE
EXTRN	?ObjectList@@3PAVobject_list@@A:WORD
_DATA      SEGMENT
??_C@_0BO@GBKI@?$CI?$CF03d?0?$CF03d?$CJ?$DN?$DO?$CI?$CF03d?0?$CF03d?0?$CF03d?$CJ?$AA@	DB	'(%03d,%03d)=>(%03d,%03d,%03d)',  00H
	ORG	$-30
$S8250_szAppName	DB	'WinG Sprite Demo',  00H
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
$SG8282	DB	'boyfrent.bmp',  00H
$SG8283	DB	'zemane2.bmp',  00H
$SG8284	DB	'zemane1.bmp',  00H
$SG8285	DB	'boyfren1.bmp',  00H
?TommyNames@@3QAPADA	DW	DGROUP:$SG8282
	DW	DGROUP:$SG8283
	DW	DGROUP:$SG8284
	DW	DGROUP:$SG8285
?TommyFrames@@3QAHA	DW	01H
	DW	08H
	DW	08H
	DW	04H
?TommyWidth@@3QAHA	DW	0a5H
	DW	0a5H
	DW	0a5H
	DW	0a5H
?TommyHeight@@3QAHA	DW	0f7H
	DW	0f7H
	DW	0f7H
	DW	0f7H
$SG8337	DB	'AppIcon',  00H
$SG8343	DB	'quarvazi.bmp',  00H
$SG8346	DB	'moveltv2.bmp',  00H
$SG8349	DB	'cama.bmp',  00H
$SG8386	DB	'O aplicativo j',  0e1H, ' est',  0e1H, ' aberto !!!',  00H
$SG8393	DB	'USER',  00H
$SG8398	DB	'USER',  00H
	ORG	$+1
$S8418_?InKeyLeft@?1??AppWndProc@@ZCJPBUHWND__@@IIJ@Z@4W4boolean@@A	DW	00H
$S8420_?InKeyRight@?1??AppWndProc@@ZCJPBUHWND__@@IIJ@Z@4W4boolean@@A	DW	00H
$S8422_?InKeyUp@?1??AppWndProc@@ZCJPBUHWND__@@IIJ@Z@4W4boolean@@A	DW	00H
$S8424_?InKeyDown@?1??AppWndProc@@ZCJPBUHWND__@@IIJ@Z@4W4boolean@@A	DW	00H
$S8426_?InKeySub@?1??AppWndProc@@ZCJPBUHWND__@@IIJ@Z@4W4boolean@@A	DW	00H
$S8428_?InKeyAdd@?1??AppWndProc@@ZCJPBUHWND__@@IIJ@Z@4W4boolean@@A	DW	00H
$S8430_?InitAnim@?1??AppWndProc@@ZCJPBUHWND__@@IIJ@Z@4W4boolean@@A	DW	01H
$SG8499	DB	'AppAbout',  00H
_DATA      ENDS
XIFU      SEGMENT
$S8508__aag	DD	_aaf
XIFU      ENDS
_DATA      SEGMENT
	ORG	$-1263
??_7occup_screen@@6B@	DW	?Init@occup_screen@@UACPAVscreen@@PBUHWND__@@@Z
	DW	?CantGo@occup_screen@@UAC?AW4boolean@@HHHH@Z
	DW	?CanGo@occup_screen@@UAC?AW4boolean@@HHHH@Z
	DW	?IncrOccupation@occup_screen@@UACHPAVobject@@@Z
	DW	?DecrOccupation@occup_screen@@UACHPAVobject@@@Z
	DW	?Set3DPosition@screen@@UACXPAVobject@@H@Z
	DW	?SetVanishingPoint@screen@@UACPAV1@HH@Z
	DW	?SetViewPoint@screen@@UACPAV1@HHHHH@Z
	DW	?SetyAxisShift@screen@@UACPAV1@HH@Z
	ORG	$-18
??_7_3D_animated@@6Banimated@@@	DW	?InitAnim@animated@@UACXPBUHWND__@@PAVoccup_screen@@@Z
	DW	?EndAnim@animated@@UACXPBUHWND__@@PBUHDC__@@PAVoccup_screen@@@Z
	DW	?EndAnim@animated@@UACXPBUHWND__@@PAVoccup_screen@@@Z
	DW	?Anim1Frame@animated@@UACXPBUHWND__@@PAVoccup_screen@@@Z
	DW	?Anim1Frame@_3D_animated@@UACXPBUHWND__@@PAV_3D_screen@@@Z
	ORG	$-10
??_7_3D_animated@@6Bobject@@@	DW	?x3D@_3D_object@@WPPPPPLJI@ACHXZ
	DW	?y3D@_3D_object@@WPPPPPLJI@ACHXZ
	DW	?z3D@_3D_object@@WPPPPPLJI@ACHXZ
	DW	?w3D@_3D_object@@WPPPPPLJI@ACHXZ
	DW	?h3D@_3D_object@@WPPPPPLJI@ACHXZ
	DW	?d3D@_3D_object@@WPPPPPLJI@ACHXZ
	DW	?Put@object@@UACXPAVscreen@@@Z
	DW	?Paint@object@@UACXPAVscreen@@@Z
	DW	?Hide@object@@UACXPBUHDC__@@PAVscreen@@@Z
	DW	?Show@object@@UACXPBUHDC__@@PAVscreen@@@Z
	DW	?NextFrame@animated@@$4PPPPPPPO@A@ACHXZ
	DW	?PreviousFrame@animated@@$4PPPPPPPO@A@ACHXZ
	DW	?OccupScreen@object@@UACXPAVscreen@@@Z
	ORG	$-26
??_7_3D_animated@@6B_3D_object@@@	DW	?Init@_3D_object@@UACPAV1@PAV_3D_screen@@@Z
	DW	?Set3DPosition@_3D_object@@UACPAV1@PAV_3D_screen@@H@Z
	DW	?Set3DOrigin@_3D_object@@UACPAV1@HH@Z
	DW	?Set3DDimensions@_3D_object@@UACPAV1@HHH@Z
	ORG	$-8
??_8_3D_animated@@7Banimated@@@	DW	0fffeH
	DW	08H
	DW	045aH
	ORG	$-6
??_8_3D_animated@@7B_3D_object@@@	DW	0fffeH
	DW	0fbacH
	ORG	$-4
??_7object@@6B@	DW	?x3D@object@@UACHXZ
	DW	?y3D@object@@UACHXZ
	DW	?z3D@object@@UACHXZ
	DW	?w3D@object@@UACHXZ
	DW	?h3D@object@@UACHXZ
	DW	?d3D@object@@UACHXZ
	DW	?Put@object@@UACXPAVscreen@@@Z
	DW	?Paint@object@@UACXPAVscreen@@@Z
	DW	?Hide@object@@UACXPBUHDC__@@PAVscreen@@@Z
	DW	?Show@object@@UACXPBUHDC__@@PAVscreen@@@Z
	DW	?NextFrame@object@@UACHXZ
	DW	?PreviousFrame@object@@UACHXZ
	DW	?OccupScreen@object@@UACXPAVscreen@@@Z
	ORG	$-26
??_7_3D_object@@6B0@@	DW	?Init@_3D_object@@UACPAV1@PAV_3D_screen@@@Z
	DW	?Set3DPosition@_3D_object@@UACPAV1@PAV_3D_screen@@H@Z
	DW	?Set3DOrigin@_3D_object@@UACPAV1@HH@Z
	DW	?Set3DDimensions@_3D_object@@UACPAV1@HHH@Z
	ORG	$-8
??_7_3D_object@@6Bobject@@@	DW	?x3D@_3D_object@@$4PPPPPPPO@A@ACHXZ
	DW	?y3D@_3D_object@@$4PPPPPPPO@A@ACHXZ
	DW	?z3D@_3D_object@@$4PPPPPPPO@A@ACHXZ
	DW	?w3D@_3D_object@@$4PPPPPPPO@A@ACHXZ
	DW	?h3D@_3D_object@@$4PPPPPPPO@A@ACHXZ
	DW	?d3D@_3D_object@@$4PPPPPPPO@A@ACHXZ
	DW	?Put@object@@UACXPAVscreen@@@Z
	DW	?Paint@object@@UACXPAVscreen@@@Z
	DW	?Hide@object@@UACXPBUHDC__@@PAVscreen@@@Z
	DW	?Show@object@@UACXPBUHDC__@@PAVscreen@@@Z
	DW	?NextFrame@object@@UACHXZ
	DW	?PreviousFrame@object@@UACHXZ
	DW	?OccupScreen@object@@UACXPAVscreen@@@Z
	ORG	$-26
??_8_3D_object@@7B@	DW	0fffeH
	DW	014H
	ORG	$-4
??_7moveable@@6B0@@	DW	?SetPosition@moveable@@UACXHH@Z
	DW	?Paint@moveable@@UACXHHPAVscreen@@@Z
	DW	?CanGo@moveable@@UAC?AW4boolean@@PAVoccup_screen@@@Z
	DW	?DetectedCollision@moveable@@UAC?AW4boolean@@PAVobject@@PAVscreen@@@Z
	DW	?CantGo@moveable@@UAC?AW4boolean@@PAVoccup_screen@@@Z
	DW	?InitMove@moveable@@UACXPBUHWND__@@HHPAVoccup_screen@@@Z
	DW	?InitHMove@moveable@@UACXPBUHWND__@@PAVoccup_screen@@W4MVDIR@@@Z
	DW	?InitVMove@moveable@@UACXPBUHWND__@@PAVoccup_screen@@W4MVDIR@@@Z
	DW	?EndMove@moveable@@UACXPBUHWND__@@PBUHDC__@@PAVoccup_screen@@@Z
	DW	?EndMove@moveable@@UACXPBUHWND__@@PAVoccup_screen@@@Z
	DW	?Move1Step@moveable@@UACXPBUHWND__@@PAVoccup_screen@@@Z
	ORG	$-22
??_7moveable@@6Bobject@@@	DW	?x3D@object@@UACHXZ
	DW	?y3D@object@@UACHXZ
	DW	?z3D@object@@UACHXZ
	DW	?w3D@object@@UACHXZ
	DW	?h3D@object@@UACHXZ
	DW	?d3D@object@@UACHXZ
	DW	?Put@object@@UACXPAVscreen@@@Z
	DW	?Paint@object@@UACXPAVscreen@@@Z
	DW	?Hide@object@@UACXPBUHDC__@@PAVscreen@@@Z
	DW	?Show@moveable@@$4PPPPPPPO@A@ACXPBUHDC__@@PAVscreen@@@Z
	DW	?NextFrame@object@@UACHXZ
	DW	?PreviousFrame@object@@UACHXZ
	DW	?OccupScreen@object@@UACXPAVscreen@@@Z
	ORG	$-26
??_8moveable@@7B@	DW	0fffeH
	DW	036H
	ORG	$-4
??_7tommy@@6Bmoveable@@@	DW	?SetPosition@moveable@@UACXHH@Z
	DW	?Paint@moveable@@UACXHHPAVscreen@@@Z
	DW	?CanGo@moveable@@UAC?AW4boolean@@PAVoccup_screen@@@Z
	DW	?DetectedCollision@moveable@@UAC?AW4boolean@@PAVobject@@PAVscreen@@@Z
	DW	?CantGo@moveable@@UAC?AW4boolean@@PAVoccup_screen@@@Z
	DW	?InitMove@moveable@@UACXPBUHWND__@@HHPAVoccup_screen@@@Z
	DW	?InitHMove@moveable@@UACXPBUHWND__@@PAVoccup_screen@@W4MVDIR@@@Z
	DW	?InitVMove@moveable@@UACXPBUHWND__@@PAVoccup_screen@@W4MVDIR@@@Z
	DW	?EndMove@moveable@@UACXPBUHWND__@@PBUHDC__@@PAVoccup_screen@@@Z
	DW	?EndMove@moveable@@UACXPBUHWND__@@PAVoccup_screen@@@Z
	DW	?Move1Step@moveable@@UACXPBUHWND__@@PAVoccup_screen@@@Z
	DW	?DetectedCollision@_3D_moveable@@UAC?AW4boolean@@PAVobject@@PAV_3D_screen@@@Z
	DW	?CanGo@_3D_moveable@@UAC?AW4boolean@@PAV_3D_screen@@@Z
	DW	?SetPosition@_3D_moveable@@UACXHHPAV_3D_screen@@@Z
	DW	?Paint@_3D_moveable@@UACXHHPAV_3D_screen@@@Z
	DW	?Move1Step@_3D_actor@@UACXPBUHWND__@@PAV_3D_screen@@@Z
	ORG	$-32
??_7tommy@@6Banimated@@@	DW	?InitAnim@animated@@UACXPBUHWND__@@PAVoccup_screen@@@Z
	DW	?EndAnim@animated@@UACXPBUHWND__@@PBUHDC__@@PAVoccup_screen@@@Z
	DW	?EndAnim@animated@@UACXPBUHWND__@@PAVoccup_screen@@@Z
	DW	?Anim1Frame@animated@@UACXPBUHWND__@@PAVoccup_screen@@@Z
	DW	?Anim1Frame@_3D_animated@@UACXPBUHWND__@@PAV_3D_screen@@@Z
	ORG	$-10
??_7tommy@@6Bobject@@@	DW	?x3D@_3D_object@@WPPPPPLJI@ACHXZ
	DW	?y3D@_3D_object@@WPPPPPLJI@ACHXZ
	DW	?z3D@_3D_object@@WPPPPPLJI@ACHXZ
	DW	?w3D@_3D_object@@WPPPPPLJI@ACHXZ
	DW	?h3D@_3D_object@@WPPPPPLJI@ACHXZ
	DW	?d3D@_3D_object@@WPPPPPLJI@ACHXZ
	DW	?Put@object@@UACXPAVscreen@@@Z
	DW	?Paint@object@@UACXPAVscreen@@@Z
	DW	?Hide@object@@UACXPBUHDC__@@PAVscreen@@@Z
	DW	?Show@_3D_moveable@@$4PPPPPPPO@O@ACXPBUHDC__@@PAVscreen@@@Z
	DW	?NextFrame@animated@@W5ACHXZ
	DW	?PreviousFrame@animated@@W5ACHXZ
	DW	?OccupScreen@_3D_player@@$4PPPPPPPO@A@ACXPAVscreen@@@Z
	ORG	$-26
??_7tommy@@6B_3D_object@@@	DW	?Init@_3D_object@@UACPAV1@PAV_3D_screen@@@Z
	DW	?Set3DPosition@_3D_object@@UACPAV1@PAV_3D_screen@@H@Z
	DW	?Set3DOrigin@_3D_object@@UACPAV1@HH@Z
	DW	?Set3DDimensions@_3D_object@@UACPAV1@HHH@Z
	ORG	$-8
??_8tommy@@7Bmoveable@@@	DW	0fffeH
	DW	044H
	DW	0496H
	ORG	$-6
??_8tommy@@7Banimated@@@	DW	0fffeH
	DW	0eH
	DW	0460H
	ORG	$-6
??_8tommy@@7B_3D_object@@@	DW	0fffeH
	DW	0fbacH
	ORG	$-4
??_7screen@@6B@	DW	?Init@screen@@UACPAV1@PBUHWND__@@@Z
	DW	?CantGo@screen@@UAC?AW4boolean@@HHHH@Z
	DW	?CanGo@screen@@UAC?AW4boolean@@HHHH@Z
	DW	?IncrOccupation@screen@@UACHPAVobject@@@Z
	DW	?DecrOccupation@screen@@UACHPAVobject@@@Z
	DW	?Set3DPosition@screen@@UACXPAVobject@@H@Z
	DW	?SetVanishingPoint@screen@@UACPAV1@HH@Z
	DW	?SetViewPoint@screen@@UACPAV1@HHHHH@Z
	DW	?SetyAxisShift@screen@@UACPAV1@HH@Z
	ORG	$-18
??_7_3D_player@@6Bmoveable@@@	DW	?SetPosition@moveable@@UACXHH@Z
	DW	?Paint@moveable@@UACXHHPAVscreen@@@Z
	DW	?CanGo@moveable@@UAC?AW4boolean@@PAVoccup_screen@@@Z
	DW	?DetectedCollision@moveable@@UAC?AW4boolean@@PAVobject@@PAVscreen@@@Z
	DW	?CantGo@moveable@@UAC?AW4boolean@@PAVoccup_screen@@@Z
	DW	?InitMove@moveable@@UACXPBUHWND__@@HHPAVoccup_screen@@@Z
	DW	?InitHMove@moveable@@UACXPBUHWND__@@PAVoccup_screen@@W4MVDIR@@@Z
	DW	?InitVMove@moveable@@UACXPBUHWND__@@PAVoccup_screen@@W4MVDIR@@@Z
	DW	?EndMove@moveable@@UACXPBUHWND__@@PBUHDC__@@PAVoccup_screen@@@Z
	DW	?EndMove@moveable@@UACXPBUHWND__@@PAVoccup_screen@@@Z
	DW	?Move1Step@moveable@@UACXPBUHWND__@@PAVoccup_screen@@@Z
	DW	?DetectedCollision@_3D_moveable@@UAC?AW4boolean@@PAVobject@@PAV_3D_screen@@@Z
	DW	?CanGo@_3D_moveable@@UAC?AW4boolean@@PAV_3D_screen@@@Z
	DW	?SetPosition@_3D_moveable@@UACXHHPAV_3D_screen@@@Z
	DW	?Paint@_3D_moveable@@UACXHHPAV_3D_screen@@@Z
	DW	?Move1Step@_3D_actor@@UACXPBUHWND__@@PAV_3D_screen@@@Z
	ORG	$-32
??_7_3D_player@@6Banimated@@@	DW	?InitAnim@animated@@UACXPBUHWND__@@PAVoccup_screen@@@Z
	DW	?EndAnim@animated@@UACXPBUHWND__@@PBUHDC__@@PAVoccup_screen@@@Z
	DW	?EndAnim@animated@@UACXPBUHWND__@@PAVoccup_screen@@@Z
	DW	?Anim1Frame@animated@@UACXPBUHWND__@@PAVoccup_screen@@@Z
	DW	?Anim1Frame@_3D_animated@@UACXPBUHWND__@@PAV_3D_screen@@@Z
	ORG	$-10
??_7_3D_player@@6Bobject@@@	DW	?x3D@_3D_object@@WPPPPPLJI@ACHXZ
	DW	?y3D@_3D_object@@WPPPPPLJI@ACHXZ
	DW	?z3D@_3D_object@@WPPPPPLJI@ACHXZ
	DW	?w3D@_3D_object@@WPPPPPLJI@ACHXZ
	DW	?h3D@_3D_object@@WPPPPPLJI@ACHXZ
	DW	?d3D@_3D_object@@WPPPPPLJI@ACHXZ
	DW	?Put@object@@UACXPAVscreen@@@Z
	DW	?Paint@object@@UACXPAVscreen@@@Z
	DW	?Hide@object@@UACXPBUHDC__@@PAVscreen@@@Z
	DW	?Show@_3D_moveable@@$4PPPPPPPO@O@ACXPBUHDC__@@PAVscreen@@@Z
	DW	?NextFrame@animated@@W5ACHXZ
	DW	?PreviousFrame@animated@@W5ACHXZ
	DW	?OccupScreen@_3D_player@@$4PPPPPPPO@A@ACXPAVscreen@@@Z
	ORG	$-26
??_7_3D_player@@6B_3D_object@@@	DW	?Init@_3D_object@@UACPAV1@PAV_3D_screen@@@Z
	DW	?Set3DPosition@_3D_object@@UACPAV1@PAV_3D_screen@@H@Z
	DW	?Set3DOrigin@_3D_object@@UACPAV1@HH@Z
	DW	?Set3DDimensions@_3D_object@@UACPAV1@HHH@Z
	ORG	$-8
??_8_3D_player@@7Bmoveable@@@	DW	0fffeH
	DW	044H
	DW	0496H
	ORG	$-6
??_8_3D_player@@7Banimated@@@	DW	0fffeH
	DW	0eH
	DW	0460H
	ORG	$-6
??_8_3D_player@@7B_3D_object@@@	DW	0fffeH
	DW	0fbacH
	ORG	$-4
??_7tommy_screen@@6B@	DW	?Init@tommy_screen@@UACPAVscreen@@PBUHWND__@@@Z
	DW	?CantGo@occup_screen@@UAC?AW4boolean@@HHHH@Z
	DW	?CanGo@occup_screen@@UAC?AW4boolean@@HHHH@Z
	DW	?IncrOccupation@occup_screen@@UACHPAVobject@@@Z
	DW	?DecrOccupation@occup_screen@@UACHPAVobject@@@Z
	DW	?Set3DPosition@screen@@UACXPAVobject@@H@Z
	DW	?SetVanishingPoint@_3D_screen@@UACPAVscreen@@HH@Z
	DW	?SetViewPoint@_3D_screen@@UACPAVscreen@@HHHHH@Z
	DW	?SetyAxisShift@_3D_screen@@UACPAVscreen@@HH@Z
	DW	?Set3DPosition@_3D_screen@@UACXPAV_3D_object@@H@Z
	ORG	$-20
??_7animated@@6B0@@	DW	?InitAnim@animated@@UACXPBUHWND__@@PAVoccup_screen@@@Z
	DW	?EndAnim@animated@@UACXPBUHWND__@@PBUHDC__@@PAVoccup_screen@@@Z
	DW	?EndAnim@animated@@UACXPBUHWND__@@PAVoccup_screen@@@Z
	DW	?Anim1Frame@animated@@UACXPBUHWND__@@PAVoccup_screen@@@Z
	ORG	$-8
??_7animated@@6Bobject@@@	DW	?x3D@object@@UACHXZ
	DW	?y3D@object@@UACHXZ
	DW	?z3D@object@@UACHXZ
	DW	?w3D@object@@UACHXZ
	DW	?h3D@object@@UACHXZ
	DW	?d3D@object@@UACHXZ
	DW	?Put@object@@UACXPAVscreen@@@Z
	DW	?Paint@object@@UACXPAVscreen@@@Z
	DW	?Hide@object@@UACXPBUHDC__@@PAVscreen@@@Z
	DW	?Show@object@@UACXPBUHDC__@@PAVscreen@@@Z
	DW	?NextFrame@animated@@$4PPPPPPPO@A@ACHXZ
	DW	?PreviousFrame@animated@@$4PPPPPPPO@A@ACHXZ
	DW	?OccupScreen@object@@UACXPAVscreen@@@Z
	ORG	$-26
??_8animated@@7B@	DW	0fffeH
	DW	08H
	ORG	$-4
??_7_3D_actor@@6Bmoveable@@@	DW	?SetPosition@moveable@@UACXHH@Z
	DW	?Paint@moveable@@UACXHHPAVscreen@@@Z
	DW	?CanGo@moveable@@UAC?AW4boolean@@PAVoccup_screen@@@Z
	DW	?DetectedCollision@moveable@@UAC?AW4boolean@@PAVobject@@PAVscreen@@@Z
	DW	?CantGo@moveable@@UAC?AW4boolean@@PAVoccup_screen@@@Z
	DW	?InitMove@moveable@@UACXPBUHWND__@@HHPAVoccup_screen@@@Z
	DW	?InitHMove@moveable@@UACXPBUHWND__@@PAVoccup_screen@@W4MVDIR@@@Z
	DW	?InitVMove@moveable@@UACXPBUHWND__@@PAVoccup_screen@@W4MVDIR@@@Z
	DW	?EndMove@moveable@@UACXPBUHWND__@@PBUHDC__@@PAVoccup_screen@@@Z
	DW	?EndMove@moveable@@UACXPBUHWND__@@PAVoccup_screen@@@Z
	DW	?Move1Step@moveable@@UACXPBUHWND__@@PAVoccup_screen@@@Z
	DW	?DetectedCollision@_3D_moveable@@UAC?AW4boolean@@PAVobject@@PAV_3D_screen@@@Z
	DW	?CanGo@_3D_moveable@@UAC?AW4boolean@@PAV_3D_screen@@@Z
	DW	?SetPosition@_3D_moveable@@UACXHHPAV_3D_screen@@@Z
	DW	?Paint@_3D_moveable@@UACXHHPAV_3D_screen@@@Z
	DW	?Move1Step@_3D_actor@@UACXPBUHWND__@@PAV_3D_screen@@@Z
	ORG	$-32
??_7_3D_actor@@6Banimated@@@	DW	?InitAnim@animated@@UACXPBUHWND__@@PAVoccup_screen@@@Z
	DW	?EndAnim@animated@@UACXPBUHWND__@@PBUHDC__@@PAVoccup_screen@@@Z
	DW	?EndAnim@animated@@UACXPBUHWND__@@PAVoccup_screen@@@Z
	DW	?Anim1Frame@animated@@UACXPBUHWND__@@PAVoccup_screen@@@Z
	DW	?Anim1Frame@_3D_animated@@UACXPBUHWND__@@PAV_3D_screen@@@Z
	ORG	$-10
??_7_3D_actor@@6Bobject@@@	DW	?x3D@_3D_object@@WPPPPPLJI@ACHXZ
	DW	?y3D@_3D_object@@WPPPPPLJI@ACHXZ
	DW	?z3D@_3D_object@@WPPPPPLJI@ACHXZ
	DW	?w3D@_3D_object@@WPPPPPLJI@ACHXZ
	DW	?h3D@_3D_object@@WPPPPPLJI@ACHXZ
	DW	?d3D@_3D_object@@WPPPPPLJI@ACHXZ
	DW	?Put@object@@UACXPAVscreen@@@Z
	DW	?Paint@object@@UACXPAVscreen@@@Z
	DW	?Hide@object@@UACXPBUHDC__@@PAVscreen@@@Z
	DW	?Show@_3D_moveable@@$4PPPPPPPO@7ACXPBUHDC__@@PAVscreen@@@Z
	DW	?NextFrame@animated@@UACHXZ
	DW	?PreviousFrame@animated@@UACHXZ
	DW	?OccupScreen@object@@UACXPAVscreen@@@Z
	ORG	$-26
??_7_3D_actor@@6B_3D_object@@@	DW	?Init@_3D_object@@UACPAV1@PAV_3D_screen@@@Z
	DW	?Set3DPosition@_3D_object@@UACPAV1@PAV_3D_screen@@H@Z
	DW	?Set3DOrigin@_3D_object@@UACPAV1@HH@Z
	DW	?Set3DDimensions@_3D_object@@UACPAV1@HHH@Z
	ORG	$-8
??_8_3D_actor@@7Bmoveable@@@	DW	0fffeH
	DW	03eH
	DW	0490H
	ORG	$-6
??_8_3D_actor@@7Banimated@@@	DW	0fffeH
	DW	08H
	DW	045aH
	ORG	$-6
??_8_3D_actor@@7B_3D_object@@@	DW	0fffeH
	DW	0fbacH
	ORG	$-4
??_7_3D_screen@@6B@	DW	?Init@occup_screen@@UACPAVscreen@@PBUHWND__@@@Z
	DW	?CantGo@occup_screen@@UAC?AW4boolean@@HHHH@Z
	DW	?CanGo@occup_screen@@UAC?AW4boolean@@HHHH@Z
	DW	?IncrOccupation@occup_screen@@UACHPAVobject@@@Z
	DW	?DecrOccupation@occup_screen@@UACHPAVobject@@@Z
	DW	?Set3DPosition@screen@@UACXPAVobject@@H@Z
	DW	?SetVanishingPoint@_3D_screen@@UACPAVscreen@@HH@Z
	DW	?SetViewPoint@_3D_screen@@UACPAVscreen@@HHHHH@Z
	DW	?SetyAxisShift@_3D_screen@@UACPAVscreen@@HH@Z
	DW	?Set3DPosition@_3D_screen@@UACXPAV_3D_object@@H@Z
	ORG	$-20
??_7_3D_moveable@@6Bmoveable@@@	DW	?SetPosition@moveable@@UACXHH@Z
	DW	?Paint@moveable@@UACXHHPAVscreen@@@Z
	DW	?CanGo@moveable@@UAC?AW4boolean@@PAVoccup_screen@@@Z
	DW	?DetectedCollision@moveable@@UAC?AW4boolean@@PAVobject@@PAVscreen@@@Z
	DW	?CantGo@moveable@@UAC?AW4boolean@@PAVoccup_screen@@@Z
	DW	?InitMove@moveable@@UACXPBUHWND__@@HHPAVoccup_screen@@@Z
	DW	?InitHMove@moveable@@UACXPBUHWND__@@PAVoccup_screen@@W4MVDIR@@@Z
	DW	?InitVMove@moveable@@UACXPBUHWND__@@PAVoccup_screen@@W4MVDIR@@@Z
	DW	?EndMove@moveable@@UACXPBUHWND__@@PBUHDC__@@PAVoccup_screen@@@Z
	DW	?EndMove@moveable@@UACXPBUHWND__@@PAVoccup_screen@@@Z
	DW	?Move1Step@moveable@@UACXPBUHWND__@@PAVoccup_screen@@@Z
	DW	?DetectedCollision@_3D_moveable@@UAC?AW4boolean@@PAVobject@@PAV_3D_screen@@@Z
	DW	?CanGo@_3D_moveable@@UAC?AW4boolean@@PAV_3D_screen@@@Z
	DW	?SetPosition@_3D_moveable@@UACXHHPAV_3D_screen@@@Z
	DW	?Paint@_3D_moveable@@UACXHHPAV_3D_screen@@@Z
	DW	?Move1Step@_3D_moveable@@UACXPBUHWND__@@PAV_3D_screen@@@Z
	ORG	$-32
??_7_3D_moveable@@6Bobject@@@	DW	?x3D@_3D_object@@WPPPPPLJI@ACHXZ
	DW	?y3D@_3D_object@@WPPPPPLJI@ACHXZ
	DW	?z3D@_3D_object@@WPPPPPLJI@ACHXZ
	DW	?w3D@_3D_object@@WPPPPPLJI@ACHXZ
	DW	?h3D@_3D_object@@WPPPPPLJI@ACHXZ
	DW	?d3D@_3D_object@@WPPPPPLJI@ACHXZ
	DW	?Put@object@@UACXPAVscreen@@@Z
	DW	?Paint@object@@UACXPAVscreen@@@Z
	DW	?Hide@object@@UACXPBUHDC__@@PAVscreen@@@Z
	DW	?Show@_3D_moveable@@$4PPPPPPPO@A@ACXPBUHDC__@@PAVscreen@@@Z
	DW	?NextFrame@object@@UACHXZ
	DW	?PreviousFrame@object@@UACHXZ
	DW	?OccupScreen@object@@UACXPAVscreen@@@Z
	ORG	$-26
??_7_3D_moveable@@6B_3D_object@@@	DW	?Init@_3D_object@@UACPAV1@PAV_3D_screen@@@Z
	DW	?Set3DPosition@_3D_object@@UACPAV1@PAV_3D_screen@@H@Z
	DW	?Set3DOrigin@_3D_object@@UACPAV1@HH@Z
	DW	?Set3DDimensions@_3D_object@@UACPAV1@HHH@Z
	ORG	$-8
??_8_3D_moveable@@7Bmoveable@@@	DW	0fffeH
	DW	036H
	DW	0488H
	ORG	$-6
??_8_3D_moveable@@7B_3D_object@@@	DW	0fffeH
	DW	0fbacH
_DATA      ENDS
_BSS      SEGMENT
	ORG	$+1072
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
PUBLIC  ?Tela1@@3PAV_3D_screen@@A
?Tela1@@3PAV_3D_screen@@A	DW 01H DUP (?)
PUBLIC  ?Tommy1@@3PAVtommy@@A
?Tommy1@@3PAVtommy@@A	DW 01H DUP (?)
PUBLIC  ?Tommy2@@3PAVtommy@@A
?Tommy2@@3PAVtommy@@A	DW 01H DUP (?)
PUBLIC  ?Comoda@@3PAV_3D_object@@A
?Comoda@@3PAV_3D_object@@A	DW 01H DUP (?)
PUBLIC  ?Cama@@3PAV_3D_object@@A
?Cama@@3PAV_3D_object@@A	DW 01H DUP (?)
	ORG	$-1110
$S8251_hInstApp	DW 01H DUP (?)
$S8252_hwndApp	DW 01H DUP (?)
$S8253_hpalApp	DW 01H DUP (?)
$S8254_fAppActive	DW 01H DUP (?)
PUBLIC  ?BufferH@@3Uheader@@A
?BufferH@@3Uheader@@A	DW 0214H DUP (?)
_BSS      ENDS
_TEXT      SEGMENT
	ASSUME	CS: _TEXT

_aae	PROC FAR
; Line 58
	enter	0,0
	push	di
	push	si
	mov	WORD PTR ?BufferHeader@@3AAUheader@@A,OFFSET DGROUP:?BufferH@@3Uheader@@A	;BufferH
; Line 83
	mov	WORD PTR ?LogicalPalette@@3AAUpal@@A,OFFSET DGROUP:?LP@@3Upal@@A	;LP
	jmp	$EX8258
$EX8258:
	pop	si
	pop	di
	leave	
	ret	

_aae	ENDP
	PUBLIC	?AppAbout@@ZCHPBUHWND__@@IIJ@Z	; AppAbout
?AppAbout@@ZCHPBUHWND__@@IIJ@Z	PROC FAR	; AppAbout
; Line 164
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
; Line 165
	mov	ax,WORD PTR [bp+12]	;msg
	jmp	$S8314
; Line 166
; Line 167
$SC8318:
; Line 168
	cmp	WORD PTR [bp+10],1	;wParam
	je	$JCC51
	jmp	$I8321
$JCC51:
; Line 169
; Line 170
	push	WORD PTR [bp+14]	;hwnd
	push	1
	call	FAR PTR ENDDIALOG
; Line 171
; Line 172
$I8321:
	jmp	$SB8315
; Line 174
$SC8322:
; Line 175
	mov	ax,1
	jmp	$EX8313
; Line 176
	jmp	$SB8315
$S8314:
	sub	ax,272	;0110H
	jne	$JCC81
	jmp	$SC8322
$JCC81:
	dec	ax
	jne	$JCC87
	jmp	$SC8318
$JCC87:
	jmp	$SB8315
$SB8315:
; Line 177
	mov	ax,0
	jmp	$EX8313
; Line 178
$EX8313:
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
; Line 197
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
; Line 201
	mov	ax,WORD PTR [bp+4]	;hInst
	mov	WORD PTR $S8251_hInstApp,ax
; Line 204
	call	_ClearSystemPalette
; Line 206
	cmp	WORD PTR [bp+6],0	;hPrev
	je	$JCC135
	jmp	$I8330
$JCC135:
; Line 207
; Line 211
	push	0
	push	0
	push	32512	;7f00H
	call	FAR PTR LOADCURSOR
	mov	WORD PTR [bp-12],ax
; Line 212
	push	WORD PTR [bp+4]	;hInst
	push	ds
	push	OFFSET DGROUP:$SG8337
	call	FAR PTR LOADICON
	mov	WORD PTR [bp-14],ax
; Line 213
	sub	ax,ax
	mov	WORD PTR [bp-6],ax
	mov	WORD PTR [bp-8],ax
; Line 214
	mov	WORD PTR [bp-4],OFFSET DGROUP:$S8250_szAppName
	mov	WORD PTR [bp-2],ds
; Line 215
	mov	WORD PTR [bp-10],0
; Line 216
	mov	ax,WORD PTR [bp+4]	;hInst
	mov	WORD PTR [bp-16],ax
; Line 217
	mov	WORD PTR [bp-26],4107	;100bH	;cls
; Line 218
	mov	WORD PTR [bp-24],OFFSET ?AppWndProc@@ZCJPBUHWND__@@IIJ@Z	;AppWndProc
	mov	WORD PTR [bp-22],SEG ?AppWndProc@@ZCJPBUHWND__@@IIJ@Z	;AppWndProc
; Line 219
	mov	WORD PTR [bp-18],0
; Line 220
	mov	WORD PTR [bp-20],0
; Line 222
	lea	ax,WORD PTR [bp-26]	;cls
	push	ss
	push	ax
	call	FAR PTR REGISTERCLASS
	cmp	ax,0
	je	$JCC235
	jmp	$I8340
$JCC235:
; Line 223
	mov	ax,0
	jmp	$EX8328
; Line 224
$I8340:
; Line 226
$I8330:
	mov	WORD PTR ?dx@@3HA,640	;0280H	;dx
; Line 227
	mov	WORD PTR ?dy@@3HA,480	;01e0H	;dy
; Line 230
	push	1106	;0452H
	call	??2@YAPAXI@Z	; operator new
	add	sp,2
	mov	WORD PTR [bp-28],ax
	cmp	ax,0
	jne	$JCC273
	jmp	$L8591
$JCC273:
	push	OFFSET DGROUP:$SG8343
	push	0
	push	0
	push	640	;0280H
	push	480	;01e0H
	push	WORD PTR [bp-28]
	call	??0tommy_screen@@QAC@PADHHHH@Z	; tommy_screen::tommy_screen
	jmp	$L8592
$L8591:
	mov	ax,0
$L8592:
	mov	WORD PTR ?Tela1@@3PAV_3D_screen@@A,ax	;Tela1
; Line 232
	push	1128	;0468H
	call	??2@YAPAXI@Z	; operator new
	add	sp,2
	mov	WORD PTR [bp-28],ax
	cmp	ax,0
	jne	$JCC321
	jmp	$L8593
$JCC321:
	push	0
	push	236	;00ecH
	push	OFFSET DGROUP:$SG8346
	push	1
	push	117	;0075H
	push	158	;009eH
	push	1
	push	0
	push	1
	push	WORD PTR [bp-28]
	call	??0_3D_object@@QAC@HHPADHHHW4boolean@@H@Z	; _3D_object::_3D_object
	jmp	$L8594
$L8593:
	mov	ax,0
$L8594:
	mov	WORD PTR ?Comoda@@3PAV_3D_object@@A,ax	;Comoda
; Line 233
	push	1128	;0468H
	call	??2@YAPAXI@Z	; operator new
	add	sp,2
	mov	WORD PTR [bp-28],ax
	cmp	ax,0
	jne	$JCC377
	jmp	$L8595
$JCC377:
	push	410	;019aH
	push	260	;0104H
	push	OFFSET DGROUP:$SG8349
	push	1
	push	231	;00e7H
	push	200	;00c8H
	push	1
	push	0
	push	1
	push	WORD PTR [bp-28]
	call	??0_3D_object@@QAC@HHPADHHHW4boolean@@H@Z	; _3D_object::_3D_object
	jmp	$L8596
$L8595:
	mov	ax,0
$L8596:
	mov	WORD PTR ?Cama@@3PAV_3D_object@@A,ax	;Cama
; Line 239
	push	1196	;04acH
	call	??2@YAPAXI@Z	; operator new
	add	sp,2
	mov	WORD PTR [bp-28],ax
	cmp	ax,0
	jne	$JCC435
	jmp	$L8597
$JCC435:
	push	250	;00faH
	push	100	;0064H
	push	4
	push	OFFSET DGROUP:?TommyNames@@3QAPADA	;TommyNames
	push	OFFSET DGROUP:?TommyFrames@@3QAHA	;TommyFrames
	push	OFFSET DGROUP:?TommyWidth@@3QAHA	;TommyWidth
	push	OFFSET DGROUP:?TommyHeight@@3QAHA	;TommyHeight
	push	50	;0032H
	push	0
	push	70	;0046H
	push	247	;00f7H
	push	1
	push	170	;00aaH
	push	25	;0019H
	push	20	;0014H
	push	1
	push	0
	push	1
	push	WORD PTR [bp-28]
	call	??0tommy@@QAC@HHHQAPADQAH11HHHHHHHHW4boolean@@H@Z	; tommy::tommy
	jmp	$L8598
$L8597:
	mov	ax,0
$L8598:
	mov	WORD PTR ?Tommy1@@3PAVtommy@@A,ax	;Tommy1
; Line 262
	push	ds
	push	OFFSET DGROUP:$S8250_szAppName
	push	ds
	push	OFFSET DGROUP:$S8250_szAppName
	push	-32576	;80c0H
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
	mov	WORD PTR $S8252_hwndApp,ax
; Line 264
	push	WORD PTR $S8252_hwndApp
	push	WORD PTR [bp+8]	;sw
	call	FAR PTR SHOWWINDOW
; Line 267
	mov	ax,1
	jmp	$EX8328
; Line 268
$EX8328:
	pop	si
	pop	di
	leave	
	ret	

?AppInit@@YAHPBUHINSTANCE__@@0HPED@Z	ENDP
	PUBLIC	?AppExit@@YAXXZ	; AppExit
?AppExit@@YAXXZ	PROC NEAR	; AppExit
; Line 279
	push	bp
	mov	bp,sp
	mov	ax,4
	call	__aNchkstk
	push	di
	push	si
; Line 281
	mov	ax,WORD PTR ?Tela1@@3PAV_3D_screen@@A	;Tela1
	mov	WORD PTR [bp-4],ax
	mov	WORD PTR [bp-2],ax
	cmp	ax,0
	jne	$JCC587
	jmp	$L8601
$JCC587:
	push	1
	push	WORD PTR [bp-2]
	call	??_G_3D_screen@@QACPAXI@Z	; ??_G_3D_screen@@QACPAXI@Z
	jmp	$L8602
$L8601:
$L8602:
; Line 282
	mov	ax,WORD PTR ?Tommy1@@3PAVtommy@@A	;Tommy1
	mov	WORD PTR [bp-2],ax
	mov	WORD PTR [bp-4],ax
	cmp	ax,0
	jne	$JCC615
	jmp	$L8603
$JCC615:
	push	1
	push	WORD PTR [bp-4]
	call	??_Gtommy@@QACPAXI@Z	; ??_Gtommy@@QACPAXI@Z
	jmp	$L8604
$L8603:
$L8604:
; Line 285
	mov	ax,WORD PTR ?Comoda@@3PAV_3D_object@@A	;Comoda
	mov	WORD PTR [bp-4],ax
	mov	WORD PTR [bp-2],ax
	cmp	ax,0
	jne	$JCC643
	jmp	$L8605
$JCC643:
	push	1
	push	WORD PTR [bp-2]
	call	??_G_3D_object@@QACPAXI@Z	; ??_G_3D_object@@QACPAXI@Z
	jmp	$L8606
$L8605:
$L8606:
; Line 286
	mov	ax,WORD PTR ?Cama@@3PAV_3D_object@@A	;Cama
	mov	WORD PTR [bp-2],ax
	mov	WORD PTR [bp-4],ax
	cmp	ax,0
	jne	$JCC671
	jmp	$L8607
$JCC671:
	push	1
	push	WORD PTR [bp-4]
	call	??_G_3D_object@@QACPAXI@Z	; ??_G_3D_object@@QACPAXI@Z
	jmp	$L8608
$L8607:
$L8608:
; Line 287
	jmp	$EX8356
$EX8356:
	pop	si
	pop	di
	leave	
	ret	

?AppExit@@YAXXZ	ENDP
	PUBLIC	?MessageLoop@@YAXPBUHINSTANCE__@@0PEDH@Z	; MessageLoop
?MessageLoop@@YAXPBUHINSTANCE__@@0PEDH@Z	PROC NEAR	; MessageLoop
; Line 311
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
; Line 317
$FC8373:
; Line 318
; Line 319
	lea	ax,WORD PTR [bp-18]	;msg
	push	ss
	push	ax
	push	0
	push	0
	push	0
	push	1
	call	FAR PTR PEEKMESSAGE
	cmp	ax,0
	jne	$JCC726
	jmp	$I8375
$JCC726:
; Line 320
; Line 321
	cmp	WORD PTR [bp-16],18	;0012H
	je	$JCC735
	jmp	$I8376
$JCC735:
; Line 322
	jmp	$FB8374
; Line 324
$I8376:
	lea	ax,WORD PTR [bp-18]	;msg
	push	ss
	push	ax
	call	FAR PTR TRANSLATEMESSAGE
; Line 325
	lea	ax,WORD PTR [bp-18]	;msg
	push	ss
	push	ax
	call	FAR PTR DISPATCHMESSAGE
; Line 326
; Line 327
	jmp	$I8377
$I8375:
; Line 328
; Line 329
	call	?AppIdle@@YAHXZ	; AppIdle
	cmp	ax,0
	jne	$JCC772
	jmp	$I8378
$JCC772:
; Line 330
	call	FAR PTR WAITMESSAGE
; Line 331
$I8378:
$I8377:
; Line 332
	jmp	$FC8373
$FB8374:
; Line 334
	jmp	$EX8370
$EX8370:
	pop	si
	pop	di
	leave	
	ret	

?MessageLoop@@YAXPBUHINSTANCE__@@0PEDH@Z	ENDP
	PUBLIC	WINMAIN
WINMAIN	PROC NEAR
; Line 338
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
; Line 340
	lea	di,WORD PTR [bp-58]	;mensagem
	mov	si,OFFSET DGROUP:$SG8386
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
; Line 344
	push	ds
	push	OFFSET DGROUP:$SG8393
	call	FAR PTR GETMODULEHANDLE
	push	ax
	push	0
	push	11	;000bH
	call	FAR PTR GETPROCADDRESS
	mov	WORD PTR _SetSystemTimer,ax
	mov	WORD PTR _SetSystemTimer+2,dx
; Line 346
	push	ds
	push	OFFSET DGROUP:$SG8398
	call	FAR PTR GETMODULEHANDLE
	push	ax
	push	0
	push	182	;00b6H
	call	FAR PTR GETPROCADDRESS
	mov	WORD PTR _KillSystemTimer,ax
	mov	WORD PTR _KillSystemTimer+2,dx
; Line 348
	cmp	WORD PTR [bp+10],0	;hPrev
	jne	$JCC888
	jmp	$I8399
$JCC888:
; Line 349
; Line 350
	push	0
	lea	ax,WORD PTR [bp-58]	;mensagem
	push	ss
	push	ax
	push	ss
	push	ax
	push	0
	call	FAR PTR MESSAGEBOX
; Line 351
	mov	ax,0
	jmp	$EX8383
; Line 352
; Line 356
$I8399:
	push	WORD PTR [bp+8]
	push	WORD PTR [bp+6]	;szCmdLine
	push	WORD PTR [bp+4]	;sw
	push	WORD PTR [bp+10]	;hPrev
	push	WORD PTR [bp+12]	;hInst
	call	?AppInit@@YAHPBUHINSTANCE__@@0HPED@Z	; AppInit
	add	sp,10	;000aH
	cmp	ax,0
	je	$JCC939
	jmp	$I8400
$JCC939:
; Line 357
; Line 358
	mov	ax,0
	jmp	$EX8383
; Line 359
; Line 365
$I8400:
	push	WORD PTR [bp+4]	;sw
	push	WORD PTR [bp+8]
	push	WORD PTR [bp+6]	;szCmdLine
	push	WORD PTR [bp+10]	;hPrev
	push	WORD PTR [bp+12]	;hInst
	call	?MessageLoop@@YAXPBUHINSTANCE__@@0PEDH@Z	; MessageLoop
	add	sp,10	;000aH
; Line 368
	call	?AppExit@@YAXXZ	; AppExit
; Line 369
	mov	ax,WORD PTR [bp-14]
	jmp	$EX8383
; Line 370
$EX8383:
	pop	si
	pop	di
	leave	
	ret	10	;000aH

WINMAIN	ENDP
	PUBLIC	?AppIdle@@YAHXZ	; AppIdle
?AppIdle@@YAHXZ	PROC NEAR	; AppIdle
; Line 382
	push	bp
	mov	bp,sp
	mov	ax,0
	call	__aNchkstk
	push	di
	push	si
; Line 383
	cmp	WORD PTR $S8254_fAppActive,0
	jne	$JCC1002
	jmp	$I8403
$JCC1002:
; Line 384
; Line 388
	mov	ax,1
	jmp	$EX8402
; Line 389
; Line 390
	jmp	$I8404
$I8403:
; Line 391
; Line 395
	mov	ax,1
	jmp	$EX8402
; Line 396
$I8404:
; Line 397
$EX8402:
	pop	si
	pop	di
	leave	
	ret	

?AppIdle@@YAHXZ	ENDP
	PUBLIC	?AppPaint@@YAHPBUHWND__@@PBUHDC__@@@Z	; AppPaint
?AppPaint@@YAHPBUHWND__@@PBUHDC__@@@Z	PROC NEAR	; AppPaint
; Line 411
	push	bp
	mov	bp,sp
	mov	ax,0
	call	__aNchkstk
	push	di
	push	si
;	hdc = 6
;	hwnd = 4
; Line 413
	push	WORD PTR [bp+6]	;hdc
	push	WORD PTR ?Tela1@@3PAV_3D_screen@@A	;Tela1
	call	?Show@screen@@QACXPBUHDC__@@@Z	; screen::Show
; Line 416
	mov	ax,1
	jmp	$EX8408
; Line 417
$EX8408:
	pop	si
	pop	di
	leave	
	ret	

?AppPaint@@YAHPBUHWND__@@PBUHDC__@@@Z	ENDP
	PUBLIC	?AppWndProc@@ZCJPBUHWND__@@IIJ@Z	; AppWndProc
?AppWndProc@@ZCJPBUHWND__@@IIJ@Z	PROC FAR	; AppWndProc
; Line 428
	mov	ax,ss
	push	bp
	mov	bp,sp
	push	ds
	mov	ds,ax
	mov	ax,84	;0054H
	call	__aNchkstk
	push	di
	push	si
;	ps = -34
;	hdc = -36
;	f = -38
;	hwnd = 14
;	msg = 12
;	wParam = 10
;	lParam = 6
; Line 442
	mov	ax,WORD PTR [bp+12]	;msg
	jmp	$S8431
; Line 443
; Line 445
$SC8435:
; Line 447
	push	WORD PTR [bp+14]	;hwnd
	push	WORD PTR ?Tela1@@3PAV_3D_screen@@A	;Tela1
	mov	bx,WORD PTR ?Tela1@@3PAV_3D_screen@@A	;Tela1
	mov	bx,WORD PTR [bx]
	call	WORD PTR [bx]
	mov	bx,ax
	mov	WORD PTR [bp-40],bx
	mov	ax,WORD PTR [bx]
	mov	WORD PTR [bp-50],ax
	push	514	;0202H
	push	202	;00caH
	push	WORD PTR [bp-40]
	mov	bx,WORD PTR [bp-50]
	call	WORD PTR [bx+12]
	mov	bx,ax
	mov	WORD PTR [bp-42],bx
	mov	ax,WORD PTR [bx]
	mov	WORD PTR [bp-48],ax
	push	160	;00a0H
	push	300	;012cH
	push	0
	push	455	;01c7H
	push	0
	push	WORD PTR [bp-42]
	mov	bx,WORD PTR [bp-48]
	call	WORD PTR [bx+14]
	mov	bx,ax
	mov	WORD PTR [bp-44],bx
	mov	ax,WORD PTR [bx]
	mov	WORD PTR [bp-46],ax
	push	0
	push	345	;0159H
	push	WORD PTR [bp-44]
	mov	bx,WORD PTR [bp-46]
	call	WORD PTR [bx+16]
; Line 449
	push	WORD PTR ?Tela1@@3PAV_3D_screen@@A	;Tela1
	push	WORD PTR ?Cama@@3PAV_3D_object@@A	;Cama
	mov	bx,WORD PTR ?Cama@@3PAV_3D_object@@A	;Cama
	mov	bx,WORD PTR [bx]
	call	WORD PTR [bx]
	mov	bx,ax
	mov	WORD PTR [bp-52],bx
	mov	ax,WORD PTR [bx]
	mov	WORD PTR [bp-62],ax
	push	2
	push	196	;00c4H
	push	WORD PTR [bp-52]
	mov	bx,WORD PTR [bp-62]
	call	WORD PTR [bx+4]
	mov	bx,ax
	mov	WORD PTR [bp-54],bx
	mov	ax,WORD PTR [bx]
	mov	WORD PTR [bp-60],ax
	push	140	;008cH
	push	70	;0046H
	push	280	;0118H
	push	WORD PTR [bp-54]
	mov	bx,WORD PTR [bp-60]
	call	WORD PTR [bx+6]
	mov	bx,ax
	mov	WORD PTR [bp-56],bx
	mov	ax,WORD PTR [bx]
	mov	WORD PTR [bp-58],ax
	push	WORD PTR ?Tela1@@3PAV_3D_screen@@A	;Tela1
	push	0
	push	WORD PTR [bp-56]
	mov	bx,WORD PTR [bp-58]
	call	WORD PTR [bx+2]
; Line 450
	push	WORD PTR ?Tela1@@3PAV_3D_screen@@A	;Tela1
	push	WORD PTR ?Comoda@@3PAV_3D_object@@A	;Comoda
	mov	bx,WORD PTR ?Comoda@@3PAV_3D_object@@A	;Comoda
	mov	bx,WORD PTR [bx]
	call	WORD PTR [bx]
	mov	bx,ax
	mov	WORD PTR [bp-64],bx
	mov	ax,WORD PTR [bx]
	mov	WORD PTR [bp-74],ax
	push	4
	push	155	;009bH
	push	WORD PTR [bp-64]
	mov	bx,WORD PTR [bp-74]
	call	WORD PTR [bx+4]
	mov	bx,ax
	mov	WORD PTR [bp-66],bx
	mov	ax,WORD PTR [bx]
	mov	WORD PTR [bp-72],ax
	push	50	;0032H
	push	120	;0078H
	push	80	;0050H
	push	WORD PTR [bp-66]
	mov	bx,WORD PTR [bp-72]
	call	WORD PTR [bx+6]
	mov	bx,ax
	mov	WORD PTR [bp-68],bx
	mov	ax,WORD PTR [bx]
	mov	WORD PTR [bp-70],ax
	push	WORD PTR ?Tela1@@3PAV_3D_screen@@A	;Tela1
	push	0
	push	WORD PTR [bp-68]
	mov	bx,WORD PTR [bp-70]
	call	WORD PTR [bx+2]
; Line 452
	push	WORD PTR ?Tela1@@3PAV_3D_screen@@A	;Tela1
	mov	bx,WORD PTR ?Tommy1@@3PAVtommy@@A	;Tommy1
	mov	bx,WORD PTR [bx+2]
	mov	ax,WORD PTR [bx+4]
	add	ax,WORD PTR ?Tommy1@@3PAVtommy@@A	;Tommy1
	add	ax,2
	push	ax
	mov	bx,WORD PTR ?Tommy1@@3PAVtommy@@A	;Tommy1
	mov	bx,WORD PTR [bx+2]
	mov	si,WORD PTR [bx+4]
	mov	bx,WORD PTR ?Tommy1@@3PAVtommy@@A	;Tommy1
	mov	bx,WORD PTR [bx+2][si]
	call	WORD PTR [bx]
	mov	bx,ax
	mov	WORD PTR [bp-76],bx
	mov	ax,WORD PTR [bx]
	mov	WORD PTR [bp-86],ax
	push	50	;0032H
	push	238	;00eeH
	push	WORD PTR [bp-76]
	mov	bx,WORD PTR [bp-86]
	call	WORD PTR [bx+4]
	mov	bx,ax
	mov	WORD PTR [bp-78],bx
	mov	ax,WORD PTR [bx]
	mov	WORD PTR [bp-84],ax
	push	70	;0046H
	push	238	;00eeH
	push	50	;0032H
	push	WORD PTR [bp-78]
	mov	bx,WORD PTR [bp-84]
	call	WORD PTR [bx+6]
	mov	bx,ax
	mov	WORD PTR [bp-80],bx
	mov	ax,WORD PTR [bx]
	mov	WORD PTR [bp-82],ax
	push	WORD PTR ?Tela1@@3PAV_3D_screen@@A	;Tela1
	push	0
	push	WORD PTR [bp-80]
	mov	bx,WORD PTR [bp-82]
	call	WORD PTR [bx+2]
; Line 454
	push	WORD PTR [bp+14]	;hwnd
	push	WORD PTR ?Tela1@@3PAV_3D_screen@@A	;Tela1
	push	WORD PTR ?Tommy1@@3PAVtommy@@A	;Tommy1
	call	?InitAnimP@tommy@@QACXPBUHWND__@@PAV_3D_screen@@@Z	; tommy::InitAnimP
; Line 457
	jmp	$SB8432
; Line 461
$SC8436:
; Line 466
	push	0
	call	FAR PTR POSTQUITMESSAGE
; Line 467
	jmp	$SB8432
; Line 469
$SC8437:
; Line 470
	mov	ax,WORD PTR [bp+10]	;wParam
	mov	WORD PTR $S8254_fAppActive,ax
; Line 471
	jmp	$SB8432
; Line 473
$SC8439:
; Line 475
	jmp	$SB8432
; Line 477
$SC8440:
; Line 479
	mov	ax,WORD PTR [bp+10]	;wParam
	jmp	$S8441
; Line 480
; Line 481
$SC8445:
; Line 482
	cmp	WORD PTR $S8418_?InKeyLeft@?1??AppWndProc@@ZCJPBUHWND__@@IIJ@Z@4W4boolean@@A,0
	je	$JCC1523
	jmp	$I8446
$JCC1523:
; Line 483
; Line 484
	mov	WORD PTR $S8418_?InKeyLeft@?1??AppWndProc@@ZCJPBUHWND__@@IIJ@Z@4W4boolean@@A,1
; Line 485
	push	WORD PTR [bp+14]	;hwnd
	push	WORD PTR ?Tela1@@3PAV_3D_screen@@A	;Tela1
	push	0
	push	WORD PTR ?Tommy1@@3PAVtommy@@A	;Tommy1
	call	?InitHMove@tommy@@QACXPBUHWND__@@PAV_3D_screen@@W4MVDIR@@@Z	; tommy::InitHMove
; Line 486
; Line 487
$I8446:
	jmp	$SB8442
; Line 488
$SC8447:
; Line 489
	cmp	WORD PTR $S8420_?InKeyRight@?1??AppWndProc@@ZCJPBUHWND__@@IIJ@Z@4W4boolean@@A,0
	je	$JCC1558
	jmp	$I8448
$JCC1558:
; Line 490
; Line 491
	mov	WORD PTR $S8420_?InKeyRight@?1??AppWndProc@@ZCJPBUHWND__@@IIJ@Z@4W4boolean@@A,1
; Line 492
	push	WORD PTR [bp+14]	;hwnd
	push	WORD PTR ?Tela1@@3PAV_3D_screen@@A	;Tela1
	push	1
	push	WORD PTR ?Tommy1@@3PAVtommy@@A	;Tommy1
	call	?InitHMove@tommy@@QACXPBUHWND__@@PAV_3D_screen@@W4MVDIR@@@Z	; tommy::InitHMove
; Line 493
; Line 494
$I8448:
	jmp	$SB8442
; Line 495
$SC8449:
; Line 496
	cmp	WORD PTR $S8422_?InKeyUp@?1??AppWndProc@@ZCJPBUHWND__@@IIJ@Z@4W4boolean@@A,0
	je	$JCC1593
	jmp	$I8450
$JCC1593:
; Line 497
; Line 498
	mov	WORD PTR $S8422_?InKeyUp@?1??AppWndProc@@ZCJPBUHWND__@@IIJ@Z@4W4boolean@@A,1
; Line 499
	push	WORD PTR [bp+14]	;hwnd
	push	WORD PTR ?Tela1@@3PAV_3D_screen@@A	;Tela1
	push	2
	push	WORD PTR ?Tommy1@@3PAVtommy@@A	;Tommy1
	call	?InitVMove@tommy@@QACXPBUHWND__@@PAV_3D_screen@@W4MVDIR@@@Z	; tommy::InitVMove
; Line 500
; Line 501
$I8450:
	jmp	$SB8442
; Line 502
$SC8451:
; Line 503
	cmp	WORD PTR $S8424_?InKeyDown@?1??AppWndProc@@ZCJPBUHWND__@@IIJ@Z@4W4boolean@@A,0
	je	$JCC1628
	jmp	$I8452
$JCC1628:
; Line 504
; Line 505
	mov	WORD PTR $S8424_?InKeyDown@?1??AppWndProc@@ZCJPBUHWND__@@IIJ@Z@4W4boolean@@A,1
; Line 506
	push	WORD PTR [bp+14]	;hwnd
	push	WORD PTR ?Tela1@@3PAV_3D_screen@@A	;Tela1
	push	3
	push	WORD PTR ?Tommy1@@3PAVtommy@@A	;Tommy1
	call	?InitVMove@tommy@@QACXPBUHWND__@@PAV_3D_screen@@W4MVDIR@@@Z	; tommy::InitVMove
; Line 507
; Line 508
$I8452:
	jmp	$SB8442
; Line 509
$SC8453:
; Line 510
	cmp	WORD PTR $S8428_?InKeyAdd@?1??AppWndProc@@ZCJPBUHWND__@@IIJ@Z@4W4boolean@@A,0
	je	$JCC1663
	jmp	$I8454
$JCC1663:
; Line 511
; Line 512
	mov	WORD PTR $S8428_?InKeyAdd@?1??AppWndProc@@ZCJPBUHWND__@@IIJ@Z@4W4boolean@@A,1
; Line 513
	push	WORD PTR [bp+14]	;hwnd
	push	WORD PTR ?Tela1@@3PAV_3D_screen@@A	;Tela1
	push	1
	push	WORD PTR ?Tommy1@@3PAVtommy@@A	;Tommy1
	call	?InitAnim@tommy@@QACXPBUHWND__@@PAV_3D_screen@@W4MVDIR@@@Z	; tommy::InitAnim
; Line 514
; Line 515
$I8454:
	jmp	$SB8442
; Line 516
$SC8455:
; Line 517
	cmp	WORD PTR $S8426_?InKeySub@?1??AppWndProc@@ZCJPBUHWND__@@IIJ@Z@4W4boolean@@A,0
	je	$JCC1698
	jmp	$I8456
$JCC1698:
; Line 518
; Line 519
	mov	WORD PTR $S8426_?InKeySub@?1??AppWndProc@@ZCJPBUHWND__@@IIJ@Z@4W4boolean@@A,1
; Line 520
	push	WORD PTR [bp+14]	;hwnd
	push	WORD PTR ?Tela1@@3PAV_3D_screen@@A	;Tela1
	push	0
	push	WORD PTR ?Tommy1@@3PAVtommy@@A	;Tommy1
	call	?InitAnim@tommy@@QACXPBUHWND__@@PAV_3D_screen@@W4MVDIR@@@Z	; tommy::InitAnim
; Line 521
; Line 522
$I8456:
	jmp	$SB8442
; Line 523
	jmp	$SB8442
$S8441:
	cmp	ax,39	;0027H
	jne	$JCC1734
	jmp	$SC8447
$JCC1734:
	jbe	$JCC1739
	jmp	$L8609
$JCC1739:
	sub	ax,37	;0025H
	jne	$JCC1747
	jmp	$SC8445
$JCC1747:
	dec	ax
	jne	$JCC1753
	jmp	$SC8449
$JCC1753:
	jmp	$SB8442
$L8609:
	sub	ax,40	;0028H
	jne	$JCC1764
	jmp	$SC8451
$JCC1764:
	sub	ax,67	;0043H
	jne	$JCC1772
	jmp	$SC8453
$JCC1772:
	dec	ax
	dec	ax
	jne	$JCC1779
	jmp	$SC8455
$JCC1779:
	jmp	$SB8442
$SB8442:
; Line 525
	jmp	$SB8432
; Line 526
$SC8457:
; Line 528
	mov	ax,WORD PTR [bp+10]	;wParam
	jmp	$S8458
; Line 529
; Line 530
$SC8462:
; Line 531
	mov	WORD PTR $S8418_?InKeyLeft@?1??AppWndProc@@ZCJPBUHWND__@@IIJ@Z@4W4boolean@@A,0
; Line 532
	push	WORD PTR [bp+14]	;hwnd
	push	WORD PTR ?Tela1@@3PAV_3D_screen@@A	;Tela1
	push	WORD PTR ?Tommy1@@3PAVtommy@@A	;Tommy1
	call	?EndMove@tommy@@QACXPBUHWND__@@PAV_3D_screen@@@Z	; tommy::EndMove
; Line 533
	jmp	$SB8459
; Line 534
$SC8463:
; Line 535
	mov	WORD PTR $S8420_?InKeyRight@?1??AppWndProc@@ZCJPBUHWND__@@IIJ@Z@4W4boolean@@A,0
; Line 536
	push	WORD PTR [bp+14]	;hwnd
	push	WORD PTR ?Tela1@@3PAV_3D_screen@@A	;Tela1
	push	WORD PTR ?Tommy1@@3PAVtommy@@A	;Tommy1
	call	?EndMove@tommy@@QACXPBUHWND__@@PAV_3D_screen@@@Z	; tommy::EndMove
; Line 537
	jmp	$SB8459
; Line 538
$SC8464:
; Line 539
	mov	WORD PTR $S8422_?InKeyUp@?1??AppWndProc@@ZCJPBUHWND__@@IIJ@Z@4W4boolean@@A,0
; Line 540
	push	WORD PTR [bp+14]	;hwnd
	push	WORD PTR ?Tela1@@3PAV_3D_screen@@A	;Tela1
	push	WORD PTR ?Tommy1@@3PAVtommy@@A	;Tommy1
	call	?EndMove@tommy@@QACXPBUHWND__@@PAV_3D_screen@@@Z	; tommy::EndMove
; Line 541
	jmp	$SB8459
; Line 542
$SC8465:
; Line 543
	mov	WORD PTR $S8424_?InKeyDown@?1??AppWndProc@@ZCJPBUHWND__@@IIJ@Z@4W4boolean@@A,0
; Line 544
	push	WORD PTR [bp+14]	;hwnd
	push	WORD PTR ?Tela1@@3PAV_3D_screen@@A	;Tela1
	push	WORD PTR ?Tommy1@@3PAVtommy@@A	;Tommy1
	call	?EndMove@tommy@@QACXPBUHWND__@@PAV_3D_screen@@@Z	; tommy::EndMove
; Line 545
	jmp	$SB8459
; Line 546
$SC8466:
; Line 547
	mov	WORD PTR $S8428_?InKeyAdd@?1??AppWndProc@@ZCJPBUHWND__@@IIJ@Z@4W4boolean@@A,0
; Line 548
	push	WORD PTR [bp+14]	;hwnd
	push	WORD PTR ?Tela1@@3PAV_3D_screen@@A	;Tela1
	push	WORD PTR ?Tommy1@@3PAVtommy@@A	;Tommy1
	call	?EndAnim@tommy@@QACXPBUHWND__@@PAV_3D_screen@@@Z	; tommy::EndAnim
; Line 549
	jmp	$SB8459
; Line 550
$SC8467:
; Line 551
	mov	WORD PTR $S8426_?InKeySub@?1??AppWndProc@@ZCJPBUHWND__@@IIJ@Z@4W4boolean@@A,0
; Line 552
	push	WORD PTR [bp+14]	;hwnd
	push	WORD PTR ?Tela1@@3PAV_3D_screen@@A	;Tela1
	push	WORD PTR ?Tommy1@@3PAVtommy@@A	;Tommy1
	call	?EndAnim@tommy@@QACXPBUHWND__@@PAV_3D_screen@@@Z	; tommy::EndAnim
; Line 553
	jmp	$SB8459
; Line 554
	jmp	$SB8459
$S8458:
	cmp	ax,39	;0027H
	jne	$JCC1940
	jmp	$SC8463
$JCC1940:
	jbe	$JCC1945
	jmp	$L8610
$JCC1945:
	sub	ax,37	;0025H
	jne	$JCC1953
	jmp	$SC8462
$JCC1953:
	dec	ax
	jne	$JCC1959
	jmp	$SC8464
$JCC1959:
	jmp	$SB8459
$L8610:
	sub	ax,40	;0028H
	jne	$JCC1970
	jmp	$SC8465
$JCC1970:
	sub	ax,67	;0043H
	jne	$JCC1978
	jmp	$SC8466
$JCC1978:
	dec	ax
	dec	ax
	jne	$JCC1985
	jmp	$SC8467
$JCC1985:
	jmp	$SB8459
$SB8459:
; Line 556
	jmp	$SB8432
; Line 557
$SC8468:
; Line 559
	push	WORD PTR [bp+14]	;hwnd
	push	WORD PTR [bp+6]	;lParam
	push	WORD PTR [bp+8]
	push	WORD PTR ?Tela1@@3PAV_3D_screen@@A	;Tela1
	push	WORD PTR ?Tommy1@@3PAVtommy@@A	;Tommy1
	call	?InitMove@tommy@@QACXPBUHWND__@@HHPAV_3D_screen@@@Z	; tommy::InitMove
; Line 562
	jmp	$SB8432
; Line 564
$SC8473:
; Line 565
	jmp	$SB8432
; Line 567
$SC8474:
; Line 570
	mov	ax,WORD PTR [bp+10]	;wParam
	mov	bx,WORD PTR ?Tommy1@@3PAVtommy@@A	;Tommy1
	cmp	WORD PTR [bx+48],ax
	je	$JCC2032
	jmp	$I8476
$JCC2032:
; Line 571
; Line 572
	mov	bx,WORD PTR ?Tommy1@@3PAVtommy@@A	;Tommy1
	cmp	WORD PTR [bx+52],0
	je	$JCC2045
	jmp	$I8477
$JCC2045:
; Line 573
; Line 574
	push	WORD PTR [bp+14]	;hwnd
	push	WORD PTR ?Tela1@@3PAV_3D_screen@@A	;Tela1
	mov	ax,WORD PTR ?Tommy1@@3PAVtommy@@A	;Tommy1
	add	ax,54	;0036H
	push	ax
	mov	bx,WORD PTR ?Tommy1@@3PAVtommy@@A	;Tommy1
	mov	bx,WORD PTR [bx+54]
	call	WORD PTR [bx+8]
; Line 575
; Line 576
	jmp	$I8478
$I8477:
; Line 577
	push	WORD PTR [bp+14]	;hwnd
	push	WORD PTR ?Tela1@@3PAV_3D_screen@@A	;Tela1
	push	WORD PTR ?Tommy1@@3PAVtommy@@A	;Tommy1
	mov	bx,WORD PTR ?Tommy1@@3PAVtommy@@A	;Tommy1
	mov	bx,WORD PTR [bx]
	call	WORD PTR [bx+30]
$I8478:
; Line 583
; Line 585
$I8476:
	jmp	$SB8432
; Line 587
$SC8479:
; Line 588
	push	WORD PTR [bp+8]
	push	WORD PTR [bp+6]	;lParam
	push	WORD PTR [bp+10]	;wParam
	push	WORD PTR [bp+12]	;msg
	push	WORD PTR [bp+14]	;hwnd
	call	?AppCommand@@YAJPBUHWND__@@IIJ@Z	; AppCommand
	add	sp,10	;000aH
	jmp	$EX8413
; Line 590
$SC8480:
; Line 591
	jmp	$SB8432
; Line 593
$SC8481:
; Line 594
	mov	ax,WORD PTR [bp+14]	;hwnd
	cmp	WORD PTR [bp+10],ax	;wParam
	je	$JCC2133
	jmp	$I8483
$JCC2133:
; Line 595
	jmp	$SB8432
; Line 599
$I8483:
$SC8484:
; Line 600
	push	WORD PTR [bp+14]	;hwnd
	call	FAR PTR GETDC
	mov	WORD PTR [bp-36],ax	;hdc
; Line 602
	mov	bx,WORD PTR ?Tela1@@3PAV_3D_screen@@A	;Tela1
	cmp	WORD PTR [bx+28],0
	jne	$JCC2160
	jmp	$I8485
$JCC2160:
; Line 603
	push	WORD PTR [bp-36]	;hdc
	mov	bx,WORD PTR ?Tela1@@3PAV_3D_screen@@A	;Tela1
	push	WORD PTR [bx+28]
	push	0
	call	FAR PTR SELECTPALETTE
; Line 605
$I8485:
	push	WORD PTR [bp-36]	;hdc
	call	FAR PTR REALIZEPALETTE
	mov	WORD PTR [bp-38],ax	;f
; Line 606
	push	WORD PTR [bp+14]	;hwnd
	push	WORD PTR [bp-36]	;hdc
	call	FAR PTR RELEASEDC
; Line 608
	cmp	WORD PTR [bp-38],0	;f
	jne	$JCC2208
	jmp	$I8486
$JCC2208:
; Line 609
	push	WORD PTR [bp+14]	;hwnd
	push	0
	push	0
	push	1
	call	FAR PTR INVALIDATERECT
; Line 611
$I8486:
	mov	ax,WORD PTR [bp-38]	;f
	cwd	
	jmp	$EX8413
; Line 613
$SC8487:
; Line 614
	push	WORD PTR [bp+14]	;hwnd
	lea	ax,WORD PTR [bp-34]	;ps
	push	ss
	push	ax
	call	FAR PTR BEGINPAINT
	mov	WORD PTR [bp-36],ax	;hdc
; Line 615
	push	WORD PTR [bp-36]	;hdc
	mov	bx,WORD PTR ?Tela1@@3PAV_3D_screen@@A	;Tela1
	push	WORD PTR [bx+28]
	push	0
	call	FAR PTR SELECTPALETTE
; Line 616
	push	WORD PTR [bp-36]	;hdc
	call	FAR PTR REALIZEPALETTE
; Line 617
	push	WORD PTR [bp-36]	;hdc
	push	WORD PTR [bp+14]	;hwnd
	call	?AppPaint@@YAHPBUHWND__@@PBUHDC__@@@Z	; AppPaint
	add	sp,4
; Line 618
	push	WORD PTR [bp+14]	;hwnd
	lea	ax,WORD PTR [bp-34]	;ps
	push	ss
	push	ax
	call	FAR PTR ENDPAINT
; Line 619
	mov	ax,0
	mov	dx,0
	jmp	$EX8413
; Line 620
	jmp	$SB8432
$S8431:
	cmp	ax,257	;0101H
	jne	$JCC2315
	jmp	$SC8457
$JCC2315:
	jbe	$JCC2320
	jmp	$L8611
$JCC2320:
	cmp	ax,15	;000fH
	jne	$JCC2328
	jmp	$SC8487
$JCC2328:
	jbe	$JCC2333
	jmp	$L8612
$JCC2333:
	dec	ax
	jne	$JCC2339
	jmp	$SC8435
$JCC2339:
	dec	ax
	jne	$JCC2345
	jmp	$SC8436
$JCC2345:
	sub	ax,3
	jne	$JCC2353
	jmp	$SC8439
$JCC2353:
	jmp	$SB8432
$L8612:
	sub	ax,16	;0010H
	jne	$JCC2364
	jmp	$SC8480
$JCC2364:
	sub	ax,12	;000cH
	jne	$JCC2372
	jmp	$SC8437
$JCC2372:
	sub	ax,228	;00e4H
	jne	$JCC2380
	jmp	$SC8440
$JCC2380:
	jmp	$SB8432
$L8611:
	cmp	ax,513	;0201H
	jne	$JCC2391
	jmp	$SC8468
$JCC2391:
	jbe	$JCC2396
	jmp	$L8613
$JCC2396:
	sub	ax,273	;0111H
	jne	$JCC2404
	jmp	$SC8479
$JCC2404:
	dec	ax
	dec	ax
	jne	$JCC2411
	jmp	$SC8473
$JCC2411:
	sub	ax,5
	jne	$JCC2419
	jmp	$SC8474
$JCC2419:
	jmp	$SB8432
$L8613:
	sub	ax,516	;0204H
	jne	$JCC2430
	jmp	$SC8436
$JCC2430:
	sub	ax,267	;010bH
	jne	$JCC2438
	jmp	$SC8484
$JCC2438:
	dec	ax
	dec	ax
	jne	$JCC2445
	jmp	$SC8481
$JCC2445:
	jmp	$SB8432
$SB8432:
; Line 622
	push	WORD PTR [bp+14]	;hwnd
	push	WORD PTR [bp+12]	;msg
	push	WORD PTR [bp+10]	;wParam
	push	WORD PTR [bp+8]
	push	WORD PTR [bp+6]	;lParam
	call	FAR PTR DEFWINDOWPROC
	jmp	$EX8413
; Line 623
$EX8413:
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
; Line 634
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
; Line 635
	mov	ax,WORD PTR [bp+8]	;wParam
	jmp	$S8493
; Line 636
; Line 637
$SC8497:
; Line 638
	push	WORD PTR $S8251_hInstApp
	push	ds
	push	OFFSET DGROUP:$SG8499
	push	WORD PTR [bp+4]	;hwnd
	push	SEG ?AppAbout@@ZCHPBUHWND__@@IIJ@Z	;AppAbout
	push	OFFSET ?AppAbout@@ZCHPBUHWND__@@IIJ@Z	;AppAbout
	call	FAR PTR DIALOGBOX
; Line 639
	jmp	$SB8494
; Line 641
$SC8500:
; Line 642
	push	WORD PTR [bp+4]	;hwnd
	push	16	;0010H
	push	0
	push	0
	push	0
	call	FAR PTR POSTMESSAGE
; Line 643
	jmp	$SB8494
; Line 644
	jmp	$SB8494
$S8493:
	dec	ax
	dec	ax
	jne	$JCC2552
	jmp	$SC8497
$JCC2552:
	dec	ax
	dec	ax
	jne	$JCC2559
	jmp	$SC8500
$JCC2559:
	jmp	$SB8494
$SB8494:
; Line 645
	mov	ax,0
	mov	dx,0
	jmp	$EX8492
; Line 646
$EX8492:
	pop	si
	pop	di
	leave	
	ret	

?AppCommand@@YAJPBUHWND__@@IIJ@Z	ENDP

_aaf	PROC FAR
; Line 647
	enter	0,0
	push	di
	push	si
	call	FAR PTR _aae
	jmp	$EX8502
$EX8502:
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
	jmp	$E8516
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
	jmp	$I8517
$E8516:
	push	si
	call	??1sprite@@QAC@XZ	; sprite::~sprite
	test	BYTE PTR [bp+6],1	;__flags
	jne	$JCC56
	jmp	$I8519
$JCC56:
	push	si
	call	??3@YAXPAX@Z	; operator delete
	add	sp,2
$I8519:
$I8517:
	mov	ax,si
	jmp	$EX8515
$EX8515:
	pop	si
	pop	di
	leave	
	ret	4

??_Esprite@@QACPAXI@Z	ENDP
	PUBLIC	??_G_3D_screen@@QACPAXI@Z	; ??_G_3D_screen@@QACPAXI@Z
??_G_3D_screen@@QACPAXI@Z	PROC NEAR	; ??_G_3D_screen@@QACPAXI@Z COMDAT
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
	call	??1_3D_screen@@QAC@XZ	; _3D_screen::~_3D_screen
	test	BYTE PTR [bp+6],1	;__flags
	jne	$JCC22
	jmp	$I8523
$JCC22:
	push	si
	call	??3@YAXPAX@Z	; operator delete
	add	sp,2
$I8523:
	mov	ax,si
	jmp	$EX8522
$EX8522:
	pop	si
	pop	di
	leave	
	ret	4

??_G_3D_screen@@QACPAXI@Z	ENDP
	PUBLIC	??_Gtommy@@QACPAXI@Z	; ??_Gtommy@@QACPAXI@Z
??_Gtommy@@QACPAXI@Z	PROC NEAR	; ??_Gtommy@@QACPAXI@Z COMDAT
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
	call	??_Dtommy@@QACXXZ	; ??_Dtommy@@QACXXZ
	test	BYTE PTR [bp+6],1	;__flags
	jne	$JCC22
	jmp	$I8527
$JCC22:
	push	si
	call	??3@YAXPAX@Z	; operator delete
	add	sp,2
$I8527:
	mov	ax,si
	jmp	$EX8526
$EX8526:
	pop	si
	pop	di
	leave	
	ret	4

??_Gtommy@@QACPAXI@Z	ENDP
	PUBLIC	??_G_3D_object@@QACPAXI@Z	; ??_G_3D_object@@QACPAXI@Z
??_G_3D_object@@QACPAXI@Z	PROC NEAR	; ??_G_3D_object@@QACPAXI@Z COMDAT
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
	call	??_D_3D_object@@QACXXZ	; ??_D_3D_object@@QACXXZ
	test	BYTE PTR [bp+6],1	;__flags
	jne	$JCC22
	jmp	$I8531
$JCC22:
	push	si
	call	??3@YAXPAX@Z	; operator delete
	add	sp,2
$I8531:
	mov	ax,si
	jmp	$EX8530
$EX8530:
	pop	si
	pop	di
	leave	
	ret	4

??_G_3D_object@@QACPAXI@Z	ENDP
	PUBLIC	??1_3D_screen@@QAC@XZ	; _3D_screen::~_3D_screen
??1_3D_screen@@QAC@XZ	PROC NEAR	; _3D_screen::~_3D_screen COMDAT
	push	bp
	mov	bp,sp
	mov	ax,0
	call	__aNchkstk
	push	di
	push	si
	mov	si,WORD PTR [bp+4]	;this
;	register si = this
	jmp	$EX8534
$EX8534:
	push	si
	call	??1occup_screen@@QAC@XZ	; occup_screen::~occup_screen
	pop	si
	pop	di
	leave	
	ret	2

??1_3D_screen@@QAC@XZ	ENDP
	PUBLIC	??_Dtommy@@QACXXZ	; ??_Dtommy@@QACXXZ
??_Dtommy@@QACXXZ	PROC NEAR	; ??_Dtommy@@QACXXZ COMDAT
	push	bp
	mov	bp,sp
	mov	ax,0
	call	__aNchkstk
	push	di
	push	si
	mov	si,WORD PTR [bp+4]	;this
;	register si = this
	jmp	$EX8537
$EX8537:
	push	si
	call	??1tommy@@QAC@XZ	; tommy::~tommy
	lea	ax,WORD PTR [si+1176]
	push	ax
	call	??1_3D_object@@QAC@XZ	; _3D_object::~_3D_object
	lea	ax,WORD PTR [si+70]
	push	ax
	call	??1object@@QAC@XZ	; object::~object
	pop	si
	pop	di
	leave	
	ret	2

??_Dtommy@@QACXXZ	ENDP
	PUBLIC	??_D_3D_object@@QACXXZ	; ??_D_3D_object@@QACXXZ
??_D_3D_object@@QACXXZ	PROC NEAR	; ??_D_3D_object@@QACXXZ COMDAT
	push	bp
	mov	bp,sp
	mov	ax,0
	call	__aNchkstk
	push	di
	push	si
	mov	si,WORD PTR [bp+4]	;this
;	register si = this
	jmp	$EX8540
$EX8540:
	push	si
	call	??1_3D_object@@QAC@XZ	; _3D_object::~_3D_object
	lea	ax,WORD PTR [si+22]
	push	ax
	call	??1object@@QAC@XZ	; object::~object
	pop	si
	pop	di
	leave	
	ret	2

??_D_3D_object@@QACXXZ	ENDP
	PUBLIC	??1tommy@@QAC@XZ	; tommy::~tommy
??1tommy@@QAC@XZ	PROC NEAR	; tommy::~tommy COMDAT
	push	bp
	mov	bp,sp
	mov	ax,0
	call	__aNchkstk
	push	di
	push	si
	mov	si,WORD PTR [bp+4]	;this
;	register si = this
	jmp	$EX8543
$EX8543:
	push	si
	call	??1_3D_player@@QAC@XZ	; _3D_player::~_3D_player
	pop	si
	pop	di
	leave	
	ret	2

??1tommy@@QAC@XZ	ENDP
	PUBLIC	??1_3D_object@@QAC@XZ	; _3D_object::~_3D_object
??1_3D_object@@QAC@XZ	PROC NEAR	; _3D_object::~_3D_object COMDAT
	push	bp
	mov	bp,sp
	mov	ax,0
	call	__aNchkstk
	push	di
	push	si
	mov	si,WORD PTR [bp+4]	;this
;	register si = this
	jmp	$EX8546
$EX8546:
	pop	si
	pop	di
	leave	
	ret	2

??1_3D_object@@QAC@XZ	ENDP
	PUBLIC	??1_3D_player@@QAC@XZ	; _3D_player::~_3D_player
??1_3D_player@@QAC@XZ	PROC NEAR	; _3D_player::~_3D_player COMDAT
	push	bp
	mov	bp,sp
	mov	ax,0
	call	__aNchkstk
	push	di
	push	si
	mov	si,WORD PTR [bp+4]	;this
;	register si = this
	jmp	$EX8549
$EX8549:
	push	si
	call	??1_3D_actor@@QAC@XZ	; _3D_actor::~_3D_actor
	pop	si
	pop	di
	leave	
	ret	2

??1_3D_player@@QAC@XZ	ENDP
	PUBLIC	??1_3D_actor@@QAC@XZ	; _3D_actor::~_3D_actor
??1_3D_actor@@QAC@XZ	PROC NEAR	; _3D_actor::~_3D_actor COMDAT
	push	bp
	mov	bp,sp
	mov	ax,2
	call	__aNchkstk
	push	di
	push	si
	mov	si,WORD PTR [bp+4]	;this
;	register si = this
	jmp	$EX8552
$EX8552:
	cmp	si,0
	jne	$JCC20
	jmp	$L8614
$JCC20:
	lea	ax,WORD PTR [si+54]
	jmp	$L8615
$L8614:
	mov	ax,0
$L8615:
	mov	WORD PTR [bp-2],ax
	push	ax
	call	??1_3D_animated@@QAC@XZ	; _3D_animated::~_3D_animated
	push	si
	call	??1_3D_moveable@@QAC@XZ	; _3D_moveable::~_3D_moveable
	pop	si
	pop	di
	leave	
	ret	2

??1_3D_actor@@QAC@XZ	ENDP
	PUBLIC	??1_3D_moveable@@QAC@XZ	; _3D_moveable::~_3D_moveable
??1_3D_moveable@@QAC@XZ	PROC NEAR	; _3D_moveable::~_3D_moveable COMDAT
	push	bp
	mov	bp,sp
	mov	ax,0
	call	__aNchkstk
	push	di
	push	si
	mov	si,WORD PTR [bp+4]	;this
;	register si = this
	jmp	$EX8555
$EX8555:
	push	si
	call	??1moveable@@QAC@XZ	; moveable::~moveable
	pop	si
	pop	di
	leave	
	ret	2

??1_3D_moveable@@QAC@XZ	ENDP
	PUBLIC	??1_3D_animated@@QAC@XZ	; _3D_animated::~_3D_animated
??1_3D_animated@@QAC@XZ	PROC NEAR	; _3D_animated::~_3D_animated COMDAT
	push	bp
	mov	bp,sp
	mov	ax,0
	call	__aNchkstk
	push	di
	push	si
	mov	si,WORD PTR [bp+4]	;this
;	register si = this
	jmp	$EX8558
$EX8558:
	push	si
	call	??1animated@@QAC@XZ	; animated::~animated
	pop	si
	pop	di
	leave	
	ret	2

??1_3D_animated@@QAC@XZ	ENDP
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
	jmp	$EX8561
$EX8561:
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
	jmp	$EX8564
$EX8564:
	pop	si
	pop	di
	leave	
	ret	2

??1animated@@QAC@XZ	ENDP
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
	PUBLIC	??1occup_screen@@QAC@XZ	; occup_screen::~occup_screen
??1occup_screen@@QAC@XZ	PROC NEAR	; occup_screen::~occup_screen COMDAT
; Line 425
	push	bp
	mov	bp,sp
	mov	ax,4
	call	__aNchkstk
	push	di
	push	si
	mov	si,WORD PTR [bp+4]	;this
;	register si = this
	mov	WORD PTR [si],OFFSET DGROUP:??_7occup_screen@@6B@
; Line 426
	mov	ax,WORD PTR [si+1096]
	mov	WORD PTR [bp-4],ax
	mov	WORD PTR [bp-2],ax
	cmp	ax,0
	jne	$JCC31
	jmp	$L8618
$JCC31:
	push	1
	push	WORD PTR [bp-2]
	call	??_Goccup_matrix@@QACPAXI@Z	; ??_Goccup_matrix@@QACPAXI@Z
	jmp	$L8619
$L8618:
$L8619:
; Line 427
	jmp	$EX6645
$EX6645:
	push	si
	call	??1screen@@QAC@XZ	; screen::~screen
	pop	si
	pop	di
	leave	
	ret	2

??1occup_screen@@QAC@XZ	ENDP
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
	PUBLIC	??1object@@QAC@XZ	; object::~object
??1object@@QAC@XZ	PROC NEAR	; object::~object COMDAT
; Line 1007
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
; Line 1011
	push	WORD PTR [si+24]
	push	WORD PTR [si+1094]
	call	FAR PTR SELECTOBJECT
	mov	WORD PTR [bp-2],ax	;hback
; Line 1014
	push	WORD PTR [bp-2]	;hback
	call	FAR PTR DELETEOBJECT
; Line 1016
	push	WORD PTR [si+24]
	call	FAR PTR DELETEDC
; Line 1017
	jmp	$EX7092
$EX7092:
	pop	si
	pop	di
	leave	
	ret	2

??1object@@QAC@XZ	ENDP
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
	PUBLIC	??0_3D_object@@QAC@HHPADHHHW4boolean@@H@Z	; _3D_object::_3D_object
??0_3D_object@@QAC@HHPADHHHW4boolean@@H@Z	PROC NEAR	; _3D_object::_3D_object COMDAT
; Line 1666
	push	bp
	mov	bp,sp
	mov	ax,0
	call	__aNchkstk
	push	di
	push	si
	mov	si,WORD PTR [bp+4]	;this
	mov	di,WORD PTR [bp+6]	;$initVBases
;	register si = this
;	_X = 22
;	_Y = 20
;	BMPName = 18
;	_NumberOfFrames = 16
;	BMPWidth = 14
;	BMPHeight = 12
;	_IsVisible = 10
;	_Layer = 8
;	register di = $initVBases
	cmp	di,0
	jne	$JCC20
	jmp	$I7743
$JCC20:
	mov	WORD PTR [si+2],OFFSET DGROUP:??_8_3D_object@@7B@
	lea	ax,WORD PTR [si+22]
	push	ax
	call	??0object@@QAC@XZ	; object::object
$I7743:
	mov	WORD PTR [si],OFFSET DGROUP:??_7_3D_object@@6B0@@
	mov	bx,WORD PTR [si+2]
	mov	bx,WORD PTR [bx+2]
	mov	WORD PTR [bx+2][si],OFFSET DGROUP:??_7_3D_object@@6Bobject@@@
	mov	bx,WORD PTR [si+2]
	mov	ax,WORD PTR [bx+2]
	sub	ax,20	;0014H
	mov	bx,WORD PTR [si+2]
	mov	bx,WORD PTR [bx+2]
	mov	WORD PTR [bx][si],ax
; Line 1670
	push	WORD PTR [bp+22]	;_X
	push	WORD PTR [bp+20]	;_Y
	push	0
	push	0
	push	WORD PTR [bp+14]	;BMPWidth
	push	WORD PTR [bp+12]	;BMPHeight
	push	WORD PTR [bp+10]	;_IsVisible
	push	WORD PTR [bp+8]	;_Layer
	mov	bx,WORD PTR [si+2]
	mov	ax,WORD PTR [bx+2]
	add	ax,si
	add	ax,2
	push	ax
	call	?InitMoveable@object@@IACXHHHHHHW4boolean@@H@Z	; object::InitMoveable
; Line 1674
	push	WORD PTR [bp+18]	;BMPName
	push	WORD PTR [bp+16]	;_NumberOfFrames
	push	WORD PTR [bp+14]	;BMPWidth
	push	WORD PTR [bp+12]	;BMPHeight
	mov	bx,WORD PTR [si+2]
	mov	ax,WORD PTR [bx+2]
	add	ax,si
	add	ax,2
	push	ax
	call	?InitAnimated@object@@IACXPADHHH@Z	; object::InitAnimated
; Line 1676
	mov	ax,si
	jmp	$EX7742
$EX7742:
	pop	si
	pop	di
	leave	
	ret	20	;0014H

??0_3D_object@@QAC@HHPADHHHW4boolean@@H@Z	ENDP
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
	PUBLIC	??0tommy@@QAC@HHHQAPADQAH11HHHHHHHHW4boolean@@H@Z	; tommy::tommy
??0tommy@@QAC@HHHQAPADQAH11HHHHHHHHW4boolean@@H@Z	PROC NEAR	; tommy::tommy COMDAT
; Line 24
	push	bp
	mov	bp,sp
	mov	ax,0
	call	__aNchkstk
	push	di
	push	si
	mov	si,WORD PTR [bp+4]	;this
	mov	di,WORD PTR [bp+6]	;$initVBases
;	register si = this
;	_X = 40
;	_Y = 38
;	_NumberOfSprites = 36
;	BMPName = 34
;	BMPFrames = 32
;	BMPWidth = 30
;	BMPHeight = 28
;	_BoundX = 26
;	_BoundY = 24
;	_BoundWidth = 22
;	_BoundHeight = 20
;	_Timer = 18
;	_Period = 16
;	_DeltaX = 14
;	_DeltaY = 12
;	_IsVisible = 10
;	_Layer = 8
;	register di = $initVBases
	cmp	di,0
	jne	$JCC20
	jmp	$I8151
$JCC20:
	mov	WORD PTR [si+2],OFFSET DGROUP:??_8tommy@@7Bmoveable@@@
	mov	WORD PTR [si+56],OFFSET DGROUP:??_8tommy@@7Banimated@@@
	mov	WORD PTR [si+1178],OFFSET DGROUP:??_8tommy@@7B_3D_object@@@
	lea	ax,WORD PTR [si+70]
	push	ax
	call	??0object@@QAC@XZ	; object::object
	push	0
	lea	ax,WORD PTR [si+1176]
	push	ax
	call	??0_3D_object@@QAC@XZ	; _3D_object::_3D_object
$I8151:
	push	WORD PTR [bp+40]	;_X
	push	WORD PTR [bp+38]	;_Y
	push	WORD PTR [bp+36]	;_NumberOfSprites
	push	WORD PTR [bp+34]	;BMPName
	push	WORD PTR [bp+32]	;BMPFrames
	push	WORD PTR [bp+30]	;BMPWidth
	push	WORD PTR [bp+28]	;BMPHeight
	push	WORD PTR [bp+26]	;_BoundX
	push	WORD PTR [bp+24]	;_BoundY
	push	WORD PTR [bp+22]	;_BoundWidth
	push	WORD PTR [bp+20]	;_BoundHeight
	push	WORD PTR [bp+18]	;_Timer
	push	WORD PTR [bp+16]	;_Period
	push	WORD PTR [bp+14]	;_DeltaX
	push	WORD PTR [bp+12]	;_DeltaY
	push	WORD PTR [bp+10]	;_IsVisible
	push	WORD PTR [bp+8]	;_Layer
	push	0
	push	si
	call	??0_3D_player@@QAC@HHHQAPADQAH11HHHHHHHHW4boolean@@H@Z	; _3D_player::_3D_player
	mov	WORD PTR [si],OFFSET DGROUP:??_7tommy@@6Bmoveable@@@
	mov	WORD PTR [si+54],OFFSET DGROUP:??_7tommy@@6Banimated@@@
	mov	bx,WORD PTR [si+2]
	mov	bx,WORD PTR [bx+2]
	mov	WORD PTR [bx+2][si],OFFSET DGROUP:??_7tommy@@6Bobject@@@
	mov	bx,WORD PTR [si+2]
	mov	bx,WORD PTR [bx+4]
	mov	WORD PTR [bx+2][si],OFFSET DGROUP:??_7tommy@@6B_3D_object@@@
	mov	bx,WORD PTR [si+2]
	mov	ax,WORD PTR [bx+2]
	sub	ax,68	;0044H
	mov	bx,WORD PTR [si+2]
	mov	bx,WORD PTR [bx+2]
	mov	WORD PTR [bx][si],ax
; Line 25
	mov	ax,si
	jmp	$EX8150
$EX8150:
	pop	si
	pop	di
	leave	
	ret	38	;0026H

??0tommy@@QAC@HHHQAPADQAH11HHHHHHHHW4boolean@@H@Z	ENDP
	PUBLIC	?InitAnim@tommy@@QACXPBUHWND__@@PAV_3D_screen@@W4MVDIR@@@Z	; tommy::InitAnim
?InitAnim@tommy@@QACXPBUHWND__@@PAV_3D_screen@@W4MVDIR@@@Z	PROC NEAR	; tommy::InitAnim COMDAT
; Line 30
	push	bp
	mov	bp,sp
	mov	ax,0
	call	__aNchkstk
	push	di
	push	si
	mov	si,WORD PTR [bp+4]	;this
;	register si = this
;	hwnd = 10
;	Screen = 8
;	Direction = 6
; Line 31
	cmp	WORD PTR [bp+6],1	;Direction
	je	$JCC18
	jmp	$I8157
$JCC18:
; Line 32
; Line 34
	push	WORD PTR [bp+10]	;hwnd
	push	WORD PTR [bp+8]	;Screen
	push	1
	lea	ax,WORD PTR [si+54]
	push	ax
	call	?SetCurrentSprite@animated@@QACAAVsprite@@PBUHWND__@@PAVscreen@@H@Z	; animated::SetCurrentSprite
; Line 35
; Line 36
	jmp	$I8158
$I8157:
; Line 37
; Line 39
	push	WORD PTR [bp+10]	;hwnd
	push	WORD PTR [bp+8]	;Screen
	push	2
	lea	ax,WORD PTR [si+54]
	push	ax
	call	?SetCurrentSprite@animated@@QACAAVsprite@@PBUHWND__@@PAVscreen@@H@Z	; animated::SetCurrentSprite
; Line 40
$I8158:
; Line 44
	push	WORD PTR [bp+10]	;hwnd
	push	WORD PTR [bp+8]	;Screen
	lea	ax,WORD PTR [si+54]
	push	ax
	call	?InitAnim@animated@@UACXPBUHWND__@@PAVoccup_screen@@@Z	; animated::InitAnim
; Line 45
	jmp	$EX8156
$EX8156:
	pop	si
	pop	di
	leave	
	ret	8

?InitAnim@tommy@@QACXPBUHWND__@@PAV_3D_screen@@W4MVDIR@@@Z	ENDP
	PUBLIC	?InitAnimP@tommy@@QACXPBUHWND__@@PAV_3D_screen@@@Z	; tommy::InitAnimP
?InitAnimP@tommy@@QACXPBUHWND__@@PAV_3D_screen@@@Z	PROC NEAR	; tommy::InitAnimP COMDAT
; Line 49
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
; Line 52
	push	WORD PTR [bp+8]	;hwnd
	push	WORD PTR [bp+6]	;Screen
	push	3
	lea	ax,WORD PTR [si+54]
	push	ax
	call	?SetCurrentSprite@animated@@QACAAVsprite@@PBUHWND__@@PAVscreen@@H@Z	; animated::SetCurrentSprite
; Line 54
	push	WORD PTR [bp+8]	;hwnd
	push	WORD PTR [bp+6]	;Screen
	lea	ax,WORD PTR [si+54]
	push	ax
	call	?InitAnim@animated@@UACXPBUHWND__@@PAVoccup_screen@@@Z	; animated::InitAnim
; Line 55
	jmp	$EX8162
$EX8162:
	pop	si
	pop	di
	leave	
	ret	6

?InitAnimP@tommy@@QACXPBUHWND__@@PAV_3D_screen@@@Z	ENDP
	PUBLIC	?EndAnim@tommy@@QACXPBUHWND__@@PAV_3D_screen@@@Z	; tommy::EndAnim
?EndAnim@tommy@@QACXPBUHWND__@@PAV_3D_screen@@@Z	PROC NEAR	; tommy::EndAnim COMDAT
; Line 59
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
; Line 62
	push	WORD PTR [bp+8]	;hwnd
	push	WORD PTR [bp+6]	;Screen
	push	0
	lea	ax,WORD PTR [si+54]
	push	ax
	call	?SetCurrentSprite@animated@@QACAAVsprite@@PBUHWND__@@PAVscreen@@H@Z	; animated::SetCurrentSprite
; Line 64
	push	WORD PTR [bp+8]	;hwnd
	push	WORD PTR [bp+6]	;Screen
	lea	ax,WORD PTR [si+54]
	push	ax
	call	?EndAnim@animated@@UACXPBUHWND__@@PAVoccup_screen@@@Z	; animated::EndAnim
; Line 65
	jmp	$EX8166
$EX8166:
	pop	si
	pop	di
	leave	
	ret	6

?EndAnim@tommy@@QACXPBUHWND__@@PAV_3D_screen@@@Z	ENDP
	PUBLIC	?InitMove@tommy@@QACXPBUHWND__@@HHPAV_3D_screen@@@Z	; tommy::InitMove
?InitMove@tommy@@QACXPBUHWND__@@HHPAV_3D_screen@@@Z	PROC NEAR	; tommy::InitMove COMDAT
; Line 77
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
; Line 78
	push	WORD PTR [bp+12]	;hwnd
	push	WORD PTR [bp+6]	;Screen
	push	si
	call	?EndAnim@tommy@@QACXPBUHWND__@@PAV_3D_screen@@@Z	; tommy::EndAnim
; Line 80
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
	mov	bx,WORD PTR [si+2]
	mov	bx,WORD PTR [bx+2]
	cmp	ax,WORD PTR [bx+10][si]
	jl	$JCC64
	jmp	$I8178
$JCC64:
; Line 81
; Line 83
	push	WORD PTR [bp+12]	;hwnd
	push	WORD PTR [bp+6]	;Screen
	push	2
	lea	ax,WORD PTR [si+54]
	push	ax
	call	?SetCurrentSprite@animated@@QACAAVsprite@@PBUHWND__@@PAVscreen@@H@Z	; animated::SetCurrentSprite
; Line 84
; Line 85
	jmp	$I8179
$I8178:
; Line 86
; Line 88
	push	WORD PTR [bp+12]	;hwnd
	push	WORD PTR [bp+6]	;Screen
	push	1
	lea	ax,WORD PTR [si+54]
	push	ax
	call	?SetCurrentSprite@animated@@QACAAVsprite@@PBUHWND__@@PAVscreen@@H@Z	; animated::SetCurrentSprite
; Line 89
$I8179:
; Line 93
	push	WORD PTR [bp+12]	;hwnd
	push	WORD PTR [bp+10]	;_NewX
	push	WORD PTR [bp+8]	;_NewY
	push	WORD PTR [bp+6]	;Screen
	push	si
	call	?InitMove@moveable@@UACXPBUHWND__@@HHPAVoccup_screen@@@Z	; moveable::InitMove
; Line 94
	jmp	$EX8177
$EX8177:
	pop	si
	pop	di
	leave	
	ret	10	;000aH

?InitMove@tommy@@QACXPBUHWND__@@HHPAV_3D_screen@@@Z	ENDP
	PUBLIC	?InitHMove@tommy@@QACXPBUHWND__@@PAV_3D_screen@@W4MVDIR@@@Z	; tommy::InitHMove
?InitHMove@tommy@@QACXPBUHWND__@@PAV_3D_screen@@W4MVDIR@@@Z	PROC NEAR	; tommy::InitHMove COMDAT
; Line 97
	push	bp
	mov	bp,sp
	mov	ax,0
	call	__aNchkstk
	push	di
	push	si
	mov	si,WORD PTR [bp+4]	;this
;	register si = this
;	hwnd = 10
;	Screen = 8
;	Direction = 6
; Line 98
	push	WORD PTR [bp+10]	;hwnd
	push	WORD PTR [bp+8]	;Screen
	push	si
	call	?EndAnim@tommy@@QACXPBUHWND__@@PAV_3D_screen@@@Z	; tommy::EndAnim
; Line 100
	cmp	WORD PTR [bp+6],1	;Direction
	je	$JCC28
	jmp	$I8185
$JCC28:
; Line 101
; Line 103
	push	WORD PTR [bp+10]	;hwnd
	push	WORD PTR [bp+8]	;Screen
	push	1
	lea	ax,WORD PTR [si+54]
	push	ax
	call	?SetCurrentSprite@animated@@QACAAVsprite@@PBUHWND__@@PAVscreen@@H@Z	; animated::SetCurrentSprite
; Line 104
; Line 105
	jmp	$I8186
$I8185:
; Line 106
; Line 108
	push	WORD PTR [bp+10]	;hwnd
	push	WORD PTR [bp+8]	;Screen
	push	2
	lea	ax,WORD PTR [si+54]
	push	ax
	call	?SetCurrentSprite@animated@@QACAAVsprite@@PBUHWND__@@PAVscreen@@H@Z	; animated::SetCurrentSprite
; Line 109
$I8186:
; Line 113
	push	WORD PTR [bp+10]	;hwnd
	push	WORD PTR [bp+8]	;Screen
	push	WORD PTR [bp+6]	;Direction
	push	si
	call	?InitHMove@moveable@@UACXPBUHWND__@@PAVoccup_screen@@W4MVDIR@@@Z	; moveable::InitHMove
; Line 114
	jmp	$EX8184
$EX8184:
	pop	si
	pop	di
	leave	
	ret	8

?InitHMove@tommy@@QACXPBUHWND__@@PAV_3D_screen@@W4MVDIR@@@Z	ENDP
	PUBLIC	?InitVMove@tommy@@QACXPBUHWND__@@PAV_3D_screen@@W4MVDIR@@@Z	; tommy::InitVMove
?InitVMove@tommy@@QACXPBUHWND__@@PAV_3D_screen@@W4MVDIR@@@Z	PROC NEAR	; tommy::InitVMove COMDAT
; Line 117
	push	bp
	mov	bp,sp
	mov	ax,0
	call	__aNchkstk
	push	di
	push	si
	mov	si,WORD PTR [bp+4]	;this
;	register si = this
;	hwnd = 10
;	Screen = 8
;	Direction = 6
; Line 118
	push	WORD PTR [bp+10]	;hwnd
	push	WORD PTR [bp+8]	;Screen
	push	si
	call	?EndAnim@tommy@@QACXPBUHWND__@@PAV_3D_screen@@@Z	; tommy::EndAnim
; Line 120
	cmp	WORD PTR [bp+6],3	;Direction
	je	$JCC28
	jmp	$I8192
$JCC28:
; Line 121
; Line 123
	push	WORD PTR [bp+10]	;hwnd
	push	WORD PTR [bp+8]	;Screen
	push	1
	lea	ax,WORD PTR [si+54]
	push	ax
	call	?SetCurrentSprite@animated@@QACAAVsprite@@PBUHWND__@@PAVscreen@@H@Z	; animated::SetCurrentSprite
; Line 124
; Line 125
	jmp	$I8193
$I8192:
; Line 126
; Line 128
	push	WORD PTR [bp+10]	;hwnd
	push	WORD PTR [bp+8]	;Screen
	push	2
	lea	ax,WORD PTR [si+54]
	push	ax
	call	?SetCurrentSprite@animated@@QACAAVsprite@@PBUHWND__@@PAVscreen@@H@Z	; animated::SetCurrentSprite
; Line 129
$I8193:
; Line 133
	push	WORD PTR [bp+10]	;hwnd
	push	WORD PTR [bp+8]	;Screen
	push	WORD PTR [bp+6]	;Direction
	push	si
	call	?InitVMove@moveable@@UACXPBUHWND__@@PAVoccup_screen@@W4MVDIR@@@Z	; moveable::InitVMove
; Line 134
	jmp	$EX8191
$EX8191:
	pop	si
	pop	di
	leave	
	ret	8

?InitVMove@tommy@@QACXPBUHWND__@@PAV_3D_screen@@W4MVDIR@@@Z	ENDP
	PUBLIC	?EndMove@tommy@@QACXPBUHWND__@@PAV_3D_screen@@@Z	; tommy::EndMove
?EndMove@tommy@@QACXPBUHWND__@@PAV_3D_screen@@@Z	PROC NEAR	; tommy::EndMove COMDAT
; Line 137
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
; Line 140
	push	WORD PTR [bp+8]	;hwnd
	push	WORD PTR [bp+6]	;Screen
	push	0
	lea	ax,WORD PTR [si+54]
	push	ax
	call	?SetCurrentSprite@animated@@QACAAVsprite@@PBUHWND__@@PAVscreen@@H@Z	; animated::SetCurrentSprite
; Line 142
	push	WORD PTR [bp+8]	;hwnd
	push	WORD PTR [bp+6]	;Screen
	push	si
	call	?EndMove@moveable@@UACXPBUHWND__@@PAVoccup_screen@@@Z	; moveable::EndMove
; Line 144
	push	WORD PTR [bp+8]	;hwnd
	push	WORD PTR [bp+6]	;Screen
	push	si
	call	?InitAnimP@tommy@@QACXPBUHWND__@@PAV_3D_screen@@@Z	; tommy::InitAnimP
; Line 145
	jmp	$EX8197
$EX8197:
	pop	si
	pop	di
	leave	
	ret	6

?EndMove@tommy@@QACXPBUHWND__@@PAV_3D_screen@@@Z	ENDP
	PUBLIC	??0tommy_screen@@QAC@PADHHHH@Z	; tommy_screen::tommy_screen
??0tommy_screen@@QAC@PADHHHH@Z	PROC NEAR	; tommy_screen::tommy_screen COMDAT
; Line 204
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
	push	WORD PTR [bp+14]	;BackName
	push	WORD PTR [bp+12]	;_ScreenX
	push	WORD PTR [bp+10]	;_ScreenY
	push	WORD PTR [bp+8]	;_ScreenWidth
	push	WORD PTR [bp+6]	;_ScreenHeight
	push	si
	call	??0_3D_screen@@QAC@PADHHHH@Z	; _3D_screen::_3D_screen
	mov	WORD PTR [si],OFFSET DGROUP:??_7tommy_screen@@6B@
; Line 206
	mov	ax,si
	jmp	$EX8249
$EX8249:
	pop	si
	pop	di
	leave	
	ret	12	;000cH

??0tommy_screen@@QAC@PADHHHH@Z	ENDP
	PUBLIC	??_Goccup_matrix@@QACPAXI@Z	; ??_Goccup_matrix@@QACPAXI@Z
??_Goccup_matrix@@QACPAXI@Z	PROC NEAR	; ??_Goccup_matrix@@QACPAXI@Z COMDAT
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
	call	??1occup_matrix@@QAC@XZ	; occup_matrix::~occup_matrix
	test	BYTE PTR [bp+6],1	;__flags
	jne	$JCC22
	jmp	$I8512
$JCC22:
	push	si
	call	??3@YAXPAX@Z	; operator delete
	add	sp,2
$I8512:
	mov	ax,si
	jmp	$EX8511
$EX8511:
	pop	si
	pop	di
	leave	
	ret	4

??_Goccup_matrix@@QACPAXI@Z	ENDP
	PUBLIC	??1occup_matrix@@QAC@XZ	; occup_matrix::~occup_matrix
??1occup_matrix@@QAC@XZ	PROC NEAR	; occup_matrix::~occup_matrix COMDAT
; Line 222
	push	bp
	mov	bp,sp
	mov	ax,0
	call	__aNchkstk
	push	di
	push	si
	mov	si,WORD PTR [bp+4]	;this
;	register si = this
; Line 225
	jmp	$EX6421
$EX6421:
	pop	si
	pop	di
	leave	
	ret	2

??1occup_matrix@@QAC@XZ	ENDP
	PUBLIC	??1screen@@QAC@XZ	; screen::~screen
??1screen@@QAC@XZ	PROC NEAR	; screen::~screen COMDAT
; Line 286
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
; Line 290
	push	WORD PTR [si+2]
	push	WORD PTR [si+30]
	call	FAR PTR SELECTOBJECT
	mov	WORD PTR [bp-2],ax	;hbm
; Line 293
	push	WORD PTR [bp-2]	;hbm
	call	FAR PTR DELETEOBJECT
; Line 294
	push	WORD PTR [si+2]
	call	FAR PTR DELETEDC
; Line 296
	push	WORD PTR [si+28]
	call	FAR PTR DELETEOBJECT
; Line 297
	jmp	$EX6509
$EX6509:
	pop	si
	pop	di
	leave	
	ret	2

??1screen@@QAC@XZ	ENDP
	PUBLIC	?CantGo@screen@@UAC?AW4boolean@@HHHH@Z	; screen::CantGo
?CantGo@screen@@UAC?AW4boolean@@HHHH@Z	PROC NEAR	; screen::CantGo COMDAT
; Line 325
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
; Line 326
	mov	ax,0
	jmp	$EX6537
; Line 327
$EX6537:
	pop	si
	pop	di
	leave	
	ret	10	;000aH

?CantGo@screen@@UAC?AW4boolean@@HHHH@Z	ENDP
	PUBLIC	?CanGo@screen@@UAC?AW4boolean@@HHHH@Z	; screen::CanGo
?CanGo@screen@@UAC?AW4boolean@@HHHH@Z	PROC NEAR	; screen::CanGo COMDAT
; Line 330
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
; Line 331
	mov	ax,1
	jmp	$EX6543
; Line 332
$EX6543:
	pop	si
	pop	di
	leave	
	ret	10	;000aH

?CanGo@screen@@UAC?AW4boolean@@HHHH@Z	ENDP
	PUBLIC	?IncrOccupation@screen@@UACHPAVobject@@@Z	; screen::IncrOccupation
?IncrOccupation@screen@@UACHPAVobject@@@Z	PROC NEAR	; screen::IncrOccupation COMDAT
; Line 336
	push	bp
	mov	bp,sp
	mov	ax,0
	call	__aNchkstk
	push	di
	push	si
	mov	si,WORD PTR [bp+4]	;this
;	register si = this
;	o = 6
; Line 337
	mov	ax,1
	jmp	$EX6546
; Line 338
$EX6546:
	pop	si
	pop	di
	leave	
	ret	4

?IncrOccupation@screen@@UACHPAVobject@@@Z	ENDP
	PUBLIC	?DecrOccupation@screen@@UACHPAVobject@@@Z	; screen::DecrOccupation
?DecrOccupation@screen@@UACHPAVobject@@@Z	PROC NEAR	; screen::DecrOccupation COMDAT
; Line 342
	push	bp
	mov	bp,sp
	mov	ax,0
	call	__aNchkstk
	push	di
	push	si
	mov	si,WORD PTR [bp+4]	;this
;	register si = this
;	o = 6
; Line 343
	mov	ax,1
	jmp	$EX6549
; Line 344
$EX6549:
	pop	si
	pop	di
	leave	
	ret	4

?DecrOccupation@screen@@UACHPAVobject@@@Z	ENDP
	PUBLIC	?Set3DPosition@screen@@UACXPAVobject@@H@Z	; screen::Set3DPosition
?Set3DPosition@screen@@UACXPAVobject@@H@Z	PROC NEAR	; screen::Set3DPosition COMDAT
; Line 347
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
; Line 348
	jmp	$EX6553
$EX6553:
	pop	si
	pop	di
	leave	
	ret	6

?Set3DPosition@screen@@UACXPAVobject@@H@Z	ENDP
	PUBLIC	?SetVanishingPoint@screen@@UACPAV1@HH@Z	; screen::SetVanishingPoint
?SetVanishingPoint@screen@@UACPAV1@HH@Z	PROC NEAR	; screen::SetVanishingPoint COMDAT
; Line 351
	push	bp
	mov	bp,sp
	mov	ax,0
	call	__aNchkstk
	push	di
	push	si
	mov	si,WORD PTR [bp+4]	;this
;	register si = this
;	_XV = 8
;	_YV = 6
; Line 352
	mov	ax,si
	jmp	$EX6557
; Line 353
$EX6557:
	pop	si
	pop	di
	leave	
	ret	6

?SetVanishingPoint@screen@@UACPAV1@HH@Z	ENDP
	PUBLIC	?SetViewPoint@screen@@UACPAV1@HHHHH@Z	; screen::SetViewPoint
?SetViewPoint@screen@@UACPAV1@HHHHH@Z	PROC NEAR	; screen::SetViewPoint COMDAT
; Line 361
	push	bp
	mov	bp,sp
	mov	ax,0
	call	__aNchkstk
	push	di
	push	si
	mov	si,WORD PTR [bp+4]	;this
;	register si = this
;	_X = 14
;	_Y = 12
;	_x = 10
;	_y = 8
;	_z = 6
; Line 362
	mov	ax,si
	jmp	$EX6564
; Line 363
$EX6564:
	pop	si
	pop	di
	leave	
	ret	12	;000cH

?SetViewPoint@screen@@UACPAV1@HHHHH@Z	ENDP
	PUBLIC	?SetyAxisShift@screen@@UACPAV1@HH@Z	; screen::SetyAxisShift
?SetyAxisShift@screen@@UACPAV1@HH@Z	PROC NEAR	; screen::SetyAxisShift COMDAT
; Line 366
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
; Line 367
	mov	ax,si
	jmp	$EX6568
; Line 368
$EX6568:
	pop	si
	pop	di
	leave	
	ret	6

?SetyAxisShift@screen@@UACPAV1@HH@Z	ENDP
	PUBLIC	?Init@occup_screen@@UACPAVscreen@@PBUHWND__@@@Z	; occup_screen::Init
?Init@occup_screen@@UACPAVscreen@@PBUHWND__@@@Z	PROC NEAR	; occup_screen::Init COMDAT
; Line 388
	push	bp
	mov	bp,sp
	mov	ax,2
	call	__aNchkstk
	push	di
	push	si
	mov	si,WORD PTR [bp+4]	;this
;	register si = this
;	hwnd = 6
; Line 389
	push	WORD PTR [bp+6]	;hwnd
	push	si
	call	?Init@screen@@UACPAV1@PBUHWND__@@@Z	; screen::Init
; Line 391
	push	15802	;3dbaH
	call	??2@YAPAXI@Z	; operator new
	add	sp,2
	mov	WORD PTR [bp-2],ax
	cmp	ax,0
	jne	$JCC36
	jmp	$L8621
$JCC36:
	push	WORD PTR [si+12]
	push	WORD PTR [si+14]
	push	WORD PTR [bp-2]
	call	??0occup_matrix@@QAC@II@Z	; occup_matrix::occup_matrix
	jmp	$L8622
$L8621:
	mov	ax,0
$L8622:
	mov	WORD PTR [si+1096],ax
; Line 393
	mov	ax,si
	jmp	$EX6617
; Line 394
$EX6617:
	pop	si
	pop	di
	leave	
	ret	4

?Init@occup_screen@@UACPAVscreen@@PBUHWND__@@@Z	ENDP
	PUBLIC	?CanGo@occup_screen@@UAC?AW4boolean@@HHHH@Z	; occup_screen::CanGo
?CanGo@occup_screen@@UAC?AW4boolean@@HHHH@Z	PROC NEAR	; occup_screen::CanGo COMDAT
; Line 397
	push	bp
	mov	bp,sp
	mov	ax,4
	call	__aNchkstk
	push	di
	push	si
	mov	si,WORD PTR [bp+4]	;this
;	o = -2
;	occ = -4
;	register si = this
;	X = 12
;	Y = 10
;	Width = 8
;	Height = 6
; Line 401
	push	WORD PTR [bp+12]	;X
	push	WORD PTR [bp+10]	;Y
	push	WORD PTR [bp+8]	;Width
	push	WORD PTR [bp+6]	;Height
	lea	ax,WORD PTR [bp-2]	;o
	push	ax
	push	WORD PTR [si+1096]
	call	?Occupation@occup_matrix@@QACDHHHHAAPAVobject@@@Z	; occup_matrix::Occupation
	mov	BYTE PTR [bp-4],al	;occ
; Line 403
	cmp	BYTE PTR [bp-4],1	;occ
	sbb	ax,ax
	neg	ax
	jmp	$EX6625
; Line 404
$EX6625:
	pop	si
	pop	di
	leave	
	ret	10	;000aH

?CanGo@occup_screen@@UAC?AW4boolean@@HHHH@Z	ENDP
	PUBLIC	?CantGo@occup_screen@@UAC?AW4boolean@@HHHH@Z	; occup_screen::CantGo
?CantGo@occup_screen@@UAC?AW4boolean@@HHHH@Z	PROC NEAR	; occup_screen::CantGo COMDAT
; Line 408
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
; Line 409
	push	WORD PTR [bp+12]	;X
	push	WORD PTR [bp+10]	;Y
	push	WORD PTR [bp+8]	;Width
	push	WORD PTR [bp+6]	;Height
	push	si
	call	?CanGo@occup_screen@@UAC?AW4boolean@@HHHH@Z	; occup_screen::CanGo
	cmp	ax,1
	sbb	ax,ax
	neg	ax
	jmp	$EX6635
; Line 410
$EX6635:
	pop	si
	pop	di
	leave	
	ret	10	;000aH

?CantGo@occup_screen@@UAC?AW4boolean@@HHHH@Z	ENDP
	PUBLIC	?IncrOccupation@occup_screen@@UACHPAVobject@@@Z	; occup_screen::IncrOccupation
?IncrOccupation@occup_screen@@UACHPAVobject@@@Z	PROC NEAR	; occup_screen::IncrOccupation COMDAT
; Line 414
	push	bp
	mov	bp,sp
	mov	ax,0
	call	__aNchkstk
	push	di
	push	si
	mov	si,WORD PTR [bp+4]	;this
;	register si = this
;	o = 6
; Line 415
	push	WORD PTR [bp+6]	;o
	push	WORD PTR [si+1096]
	call	?IncrOccupation@occup_matrix@@QACDPAVobject@@@Z	; occup_matrix::IncrOccupation
	cbw	
	jmp	$EX6639
; Line 416
$EX6639:
	pop	si
	pop	di
	leave	
	ret	4

?IncrOccupation@occup_screen@@UACHPAVobject@@@Z	ENDP
	PUBLIC	?DecrOccupation@occup_screen@@UACHPAVobject@@@Z	; occup_screen::DecrOccupation
?DecrOccupation@occup_screen@@UACHPAVobject@@@Z	PROC NEAR	; occup_screen::DecrOccupation COMDAT
; Line 420
	push	bp
	mov	bp,sp
	mov	ax,0
	call	__aNchkstk
	push	di
	push	si
	mov	si,WORD PTR [bp+4]	;this
;	register si = this
;	o = 6
; Line 421
	push	WORD PTR [bp+6]	;o
	push	WORD PTR [si+1096]
	call	?DecrOccupation@occup_matrix@@QACDPAVobject@@@Z	; occup_matrix::DecrOccupation
	cbw	
	jmp	$EX6642
; Line 422
$EX6642:
	pop	si
	pop	di
	leave	
	ret	4

?DecrOccupation@occup_screen@@UACHPAVobject@@@Z	ENDP
	PUBLIC	??0_3D_screen@@QAC@PADHHHH@Z	; _3D_screen::_3D_screen
??0_3D_screen@@QAC@PADHHHH@Z	PROC NEAR	; _3D_screen::_3D_screen COMDAT
; Line 449
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
	push	WORD PTR [bp+14]	;BackName
	push	WORD PTR [bp+12]	;_ScreenX
	push	WORD PTR [bp+10]	;_ScreenY
	push	WORD PTR [bp+8]	;_ScreenWidth
	push	WORD PTR [bp+6]	;_ScreenHeight
	push	si
	call	??0occup_screen@@QAC@PADHHHH@Z	; occup_screen::occup_screen
	mov	WORD PTR [si],OFFSET DGROUP:??_7_3D_screen@@6B@
; Line 451
	mov	ax,si
	jmp	$EX6687
$EX6687:
	pop	si
	pop	di
	leave	
	ret	12	;000cH

??0_3D_screen@@QAC@PADHHHH@Z	ENDP
	PUBLIC	?SetVanishingPoint@_3D_screen@@UACPAVscreen@@HH@Z	; _3D_screen::SetVanishingPoint
?SetVanishingPoint@_3D_screen@@UACPAVscreen@@HH@Z	PROC NEAR	; _3D_screen::SetVanishingPoint COMDAT
; Line 467
	push	bp
	mov	bp,sp
	mov	ax,0
	call	__aNchkstk
	push	di
	push	si
	mov	si,WORD PTR [bp+4]	;this
;	register si = this
;	_XV = 8
;	_YV = 6
; Line 468
	mov	ax,WORD PTR [bp+8]	;_XV
	mov	WORD PTR [si+1098],ax
; Line 469
	mov	ax,WORD PTR [si+14]
	sub	ax,WORD PTR [bp+6]	;_YV
	mov	WORD PTR [si+1100],ax
; Line 471
	mov	ax,si
	jmp	$EX6691
; Line 472
$EX6691:
	pop	si
	pop	di
	leave	
	ret	6

?SetVanishingPoint@_3D_screen@@UACPAVscreen@@HH@Z	ENDP
	PUBLIC	?SetViewPoint@_3D_screen@@UACPAVscreen@@HHHHH@Z	; _3D_screen::SetViewPoint
?SetViewPoint@_3D_screen@@UACPAVscreen@@HHHHH@Z	PROC NEAR	; _3D_screen::SetViewPoint COMDAT
; Line 475
	push	bp
	mov	bp,sp
	mov	ax,0
	call	__aNchkstk
	push	di
	push	si
	mov	si,WORD PTR [bp+4]	;this
;	register si = this
;	_X = 14
;	_Y = 12
;	_x = 10
;	_y = 8
;	_z = 6
; Line 476
	mov	ax,WORD PTR [si+14]
	sub	ax,WORD PTR [bp+12]	;_Y
	mov	WORD PTR [bp+12],ax	;_Y
; Line 478
	mov	ax,WORD PTR [bp+6]	;_z
	sub	ax,WORD PTR [bp+12]	;_Y
	cwd	
	push	dx
	push	ax
	mov	ax,WORD PTR [bp+12]	;_Y
	sub	ax,WORD PTR [si+1100]
	imul	WORD PTR [bp+8]	;_y
	push	dx
	push	ax
	call	__aNldiv
	mov	WORD PTR [si+1102],ax
; Line 480
	mov	ax,si
	jmp	$EX6698
; Line 481
$EX6698:
	pop	si
	pop	di
	leave	
	ret	12	;000cH

?SetViewPoint@_3D_screen@@UACPAVscreen@@HHHHH@Z	ENDP
	PUBLIC	?SetyAxisShift@_3D_screen@@UACPAVscreen@@HH@Z	; _3D_screen::SetyAxisShift
?SetyAxisShift@_3D_screen@@UACPAVscreen@@HH@Z	PROC NEAR	; _3D_screen::SetyAxisShift COMDAT
; Line 484
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
; Line 485
	mov	ax,WORD PTR [si+14]
	sub	ax,WORD PTR [bp+6]	;_Y
	mov	WORD PTR [bp+6],ax	;_Y
; Line 487
	cmp	WORD PTR [bp+8],0	;_X
	je	$JCC27
	jmp	$I6706
$JCC27:
; Line 488
; Line 489
	mov	ax,WORD PTR [si+1100]
	sub	ax,WORD PTR [bp+6]	;_Y
	cwd	
	push	dx
	push	ax
	mov	ax,WORD PTR [si+1098]
	imul	WORD PTR [bp+6]	;_Y
	push	dx
	push	ax
	call	__aNldiv
	mov	WORD PTR [si+1104],ax
; Line 490
; Line 491
	jmp	$I6710
$I6706:
; Line 492
; Line 493
	mov	ax,WORD PTR [bp+8]	;_X
	neg	ax
	mov	WORD PTR [si+1104],ax
; Line 494
$I6710:
; Line 496
	mov	ax,si
	jmp	$EX6705
; Line 497
$EX6705:
	pop	si
	pop	di
	leave	
	ret	6

?SetyAxisShift@_3D_screen@@UACPAVscreen@@HH@Z	ENDP
	PUBLIC	?x3D@object@@UACHXZ	; object::x3D
?x3D@object@@UACHXZ	PROC NEAR	; object::x3D COMDAT
; Line 678
	push	bp
	mov	bp,sp
	mov	ax,0
	call	__aNchkstk
	push	di
	push	si
	mov	si,WORD PTR [bp+4]	;this
;	register si = this
	mov	ax,0
	jmp	$EX6913
$EX6913:
	pop	si
	pop	di
	leave	
	ret	2

?x3D@object@@UACHXZ	ENDP
	PUBLIC	?y3D@object@@UACHXZ	; object::y3D
?y3D@object@@UACHXZ	PROC NEAR	; object::y3D COMDAT
; Line 679
	push	bp
	mov	bp,sp
	mov	ax,0
	call	__aNchkstk
	push	di
	push	si
	mov	si,WORD PTR [bp+4]	;this
;	register si = this
	mov	ax,0
	jmp	$EX6916
$EX6916:
	pop	si
	pop	di
	leave	
	ret	2

?y3D@object@@UACHXZ	ENDP
	PUBLIC	?z3D@object@@UACHXZ	; object::z3D
?z3D@object@@UACHXZ	PROC NEAR	; object::z3D COMDAT
; Line 680
	push	bp
	mov	bp,sp
	mov	ax,0
	call	__aNchkstk
	push	di
	push	si
	mov	si,WORD PTR [bp+4]	;this
;	register si = this
	mov	ax,0
	jmp	$EX6919
$EX6919:
	pop	si
	pop	di
	leave	
	ret	2

?z3D@object@@UACHXZ	ENDP
	PUBLIC	?w3D@object@@UACHXZ	; object::w3D
?w3D@object@@UACHXZ	PROC NEAR	; object::w3D COMDAT
; Line 681
	push	bp
	mov	bp,sp
	mov	ax,0
	call	__aNchkstk
	push	di
	push	si
	mov	si,WORD PTR [bp+4]	;this
;	register si = this
	mov	ax,0
	jmp	$EX6922
$EX6922:
	pop	si
	pop	di
	leave	
	ret	2

?w3D@object@@UACHXZ	ENDP
	PUBLIC	?h3D@object@@UACHXZ	; object::h3D
?h3D@object@@UACHXZ	PROC NEAR	; object::h3D COMDAT
; Line 682
	push	bp
	mov	bp,sp
	mov	ax,0
	call	__aNchkstk
	push	di
	push	si
	mov	si,WORD PTR [bp+4]	;this
;	register si = this
	mov	ax,0
	jmp	$EX6925
$EX6925:
	pop	si
	pop	di
	leave	
	ret	2

?h3D@object@@UACHXZ	ENDP
	PUBLIC	?d3D@object@@UACHXZ	; object::d3D
?d3D@object@@UACHXZ	PROC NEAR	; object::d3D COMDAT
; Line 683
	push	bp
	mov	bp,sp
	mov	ax,0
	call	__aNchkstk
	push	di
	push	si
	mov	si,WORD PTR [bp+4]	;this
;	register si = this
	mov	ax,0
	jmp	$EX6928
$EX6928:
	pop	si
	pop	di
	leave	
	ret	2

?d3D@object@@UACHXZ	ENDP
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
	PUBLIC	?Put@object@@UACXPAVscreen@@@Z	; object::Put
?Put@object@@UACXPAVscreen@@@Z	PROC NEAR	; object::Put COMDAT
; Line 762
	push	bp
	mov	bp,sp
	mov	ax,0
	call	__aNchkstk
	push	di
	push	si
	mov	si,WORD PTR [bp+4]	;this
;	register si = this
;	Screen = 6
; Line 764
	mov	ax,WORD PTR [bp+6]	;Screen
	add	ax,32	;0020H
	push	ds
	push	ax
	mov	bx,WORD PTR [bp+6]	;Screen
	push	WORD PTR [bx+6]
	push	WORD PTR [bx+4]
	push	si
	call	?PutIntoBuffer@object@@QACXPEUtagBITMAPINFO@@PEX@Z	; object::PutIntoBuffer
; Line 765
	jmp	$EX6973
$EX6973:
	pop	si
	pop	di
	leave	
	ret	4

?Put@object@@UACXPAVscreen@@@Z	ENDP
	PUBLIC	?Paint@object@@UACXPAVscreen@@@Z	; object::Paint
?Paint@object@@UACXPAVscreen@@@Z	PROC NEAR	; object::Paint COMDAT
; Line 769
	push	bp
	mov	bp,sp
	mov	ax,0
	call	__aNchkstk
	push	di
	push	si
	mov	si,WORD PTR [bp+4]	;this
;	register si = this
;	Screen = 6
; Line 770
	mov	bx,WORD PTR [bp+6]	;Screen
	push	WORD PTR [bx+2]
	push	si
	call	?RestoreBackGround@object@@QACXPBUHDC__@@@Z	; object::RestoreBackGround
; Line 773
	mov	ax,WORD PTR [bp+6]	;Screen
	add	ax,32	;0020H
	push	ds
	push	ax
	mov	bx,WORD PTR [bp+6]	;Screen
	push	WORD PTR [bx+6]
	push	WORD PTR [bx+4]
	push	si
	call	?PutIntoBuffer@object@@QACXPEUtagBITMAPINFO@@PEX@Z	; object::PutIntoBuffer
; Line 774
	jmp	$EX6977
$EX6977:
	pop	si
	pop	di
	leave	
	ret	4

?Paint@object@@UACXPAVscreen@@@Z	ENDP
	PUBLIC	?Hide@object@@UACXPBUHDC__@@PAVscreen@@@Z	; object::Hide
?Hide@object@@UACXPBUHDC__@@PAVscreen@@@Z	PROC NEAR	; object::Hide COMDAT
; Line 778
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
; Line 781
	mov	bx,WORD PTR [bp+6]	;Screen
	push	WORD PTR [bx+2]
	push	si
	call	?RestoreBackGround@object@@QACXPBUHDC__@@@Z	; object::RestoreBackGround
; Line 785
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
; Line 786
	jmp	$EX6982
$EX6982:
	pop	si
	pop	di
	leave	
	ret	6

?Hide@object@@UACXPBUHDC__@@PAVscreen@@@Z	ENDP
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
	PUBLIC	?NextFrame@object@@UACHXZ	; object::NextFrame
?NextFrame@object@@UACHXZ	PROC NEAR	; object::NextFrame COMDAT
; Line 803
	push	bp
	mov	bp,sp
	mov	ax,0
	call	__aNchkstk
	push	di
	push	si
	mov	si,WORD PTR [bp+4]	;this
;	register si = this
; Line 804
	mov	ax,0
	jmp	$EX6994
; Line 805
$EX6994:
	pop	si
	pop	di
	leave	
	ret	2

?NextFrame@object@@UACHXZ	ENDP
	PUBLIC	?PreviousFrame@object@@UACHXZ	; object::PreviousFrame
?PreviousFrame@object@@UACHXZ	PROC NEAR	; object::PreviousFrame COMDAT
; Line 808
	push	bp
	mov	bp,sp
	mov	ax,0
	call	__aNchkstk
	push	di
	push	si
	mov	si,WORD PTR [bp+4]	;this
;	register si = this
; Line 809
	mov	ax,0
	jmp	$EX6997
; Line 810
$EX6997:
	pop	si
	pop	di
	leave	
	ret	2

?PreviousFrame@object@@UACHXZ	ENDP
	PUBLIC	??0object@@QAC@XZ	; object::object
??0object@@QAC@XZ	PROC NEAR	; object::object COMDAT
; Line 813
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
	jmp	$EX7000
$EX7000:
	pop	si
	pop	di
	leave	
	ret	2

??0object@@QAC@XZ	ENDP
	PUBLIC	?OccupScreen@object@@UACXPAVscreen@@@Z	; object::OccupScreen
?OccupScreen@object@@UACXPAVscreen@@@Z	PROC NEAR	; object::OccupScreen COMDAT
; Line 999
	push	bp
	mov	bp,sp
	mov	ax,0
	call	__aNchkstk
	push	di
	push	si
	mov	si,WORD PTR [bp+4]	;this
;	register si = this
;	Screen = 6
; Line 1000
	push	si
	push	WORD PTR [bp+6]	;Screen
	mov	bx,WORD PTR [bp+6]	;Screen
	mov	bx,WORD PTR [bx]
	call	WORD PTR [bx+6]
; Line 1001
	jmp	$EX7089
$EX7089:
	pop	si
	pop	di
	leave	
	ret	4

?OccupScreen@object@@UACXPAVscreen@@@Z	ENDP
	PUBLIC	?InitAnimated@object@@IACXPADHHH@Z	; object::InitAnimated
?InitAnimated@object@@IACXPADHHH@Z	PROC NEAR	; object::InitAnimated COMDAT
; Line 1043
	push	bp
	mov	bp,sp
	mov	ax,2
	call	__aNchkstk
	push	di
	push	si
	mov	si,WORD PTR [bp+4]	;this
;	register si = this
;	BMPName = 12
;	BMPFrames = 10
;	BMPWidth = 8
;	BMPHeight = 6
; Line 1044
	mov	WORD PTR [si+18],1
; Line 1046
	push	10	;000aH
	call	??2@YAPAXI@Z	; operator new
	add	sp,2
	mov	WORD PTR [bp-2],ax
	cmp	ax,0
	jne	$JCC33
	jmp	$L8629
$JCC33:
	push	WORD PTR [bp-2]
	call	??0sprite@@QAC@XZ	; sprite::sprite
	jmp	$L8630
$L8629:
	mov	ax,0
$L8630:
	mov	WORD PTR [si+16],ax
; Line 1049
	push	ds
	push	WORD PTR [bp+12]	;BMPName
	call	_DibOpenFile
	add	sp,4
	push	dx
	push	ax
	push	WORD PTR [bp+10]	;BMPFrames
	push	WORD PTR [bp+8]	;BMPWidth
	push	WORD PTR [bp+6]	;BMPHeight
	push	WORD PTR [si+16]
	call	?Init@sprite@@QACXPEUtagBITMAPINFOHEADER@@HHH@Z	; sprite::Init
; Line 1051
	jmp	$EX7115
$EX7115:
	pop	si
	pop	di
	leave	
	ret	10	;000aH

?InitAnimated@object@@IACXPADHHH@Z	ENDP
	PUBLIC	?InitMoveable@object@@IACXHHHHHHW4boolean@@H@Z	; object::InitMoveable
?InitMoveable@object@@IACXHHHHHHW4boolean@@H@Z	PROC NEAR	; object::InitMoveable COMDAT
; Line 1058
	push	bp
	mov	bp,sp
	mov	ax,2
	call	__aNchkstk
	push	di
	push	si
	mov	si,WORD PTR [bp+4]	;this
;	register si = this
;	_X = 20
;	_Y = 18
;	_BoundX = 16
;	_BoundY = 14
;	_BoundWidth = 12
;	_BoundHeight = 10
;	_IsVisible = 8
;	_Layer = 6
; Line 1059
	cmp	WORD PTR ?ObjectList@@3PAVobject_list@@A,0	;ObjectList
	je	$JCC19
	jmp	$I7128
$JCC19:
; Line 1060
; Line 1061
	push	2
	call	??2@YAPAXI@Z	; operator new
	add	sp,2
	mov	WORD PTR [bp-2],ax
	cmp	ax,0
	jne	$JCC38
	jmp	$L8632
$JCC38:
	push	si
	push	WORD PTR [bp-2]
	call	??0object_list@@QAC@PAVobject@@@Z	; object_list::object_list
	jmp	$L8633
$L8632:
	mov	ax,0
$L8633:
	mov	WORD PTR ?ObjectList@@3PAVobject_list@@A,ax	;ObjectList
; Line 1062
	mov	ax,0
	mov	WORD PTR [si+4],ax
	mov	WORD PTR [si+2],ax
; Line 1063
; Line 1064
	jmp	$I7131
$I7128:
; Line 1065
; Line 1066
	mov	bx,WORD PTR ?ObjectList@@3PAVobject_list@@A	;ObjectList
	mov	ax,WORD PTR [bx]
	mov	WORD PTR [si+2],ax
; Line 1067
	mov	WORD PTR [si+4],0
; Line 1069
	mov	bx,WORD PTR ?ObjectList@@3PAVobject_list@@A	;ObjectList
	mov	bx,WORD PTR [bx]
	mov	WORD PTR [bx+4],si
; Line 1071
	mov	bx,WORD PTR ?ObjectList@@3PAVobject_list@@A	;ObjectList
	mov	WORD PTR [bx],si
; Line 1072
$I7131:
; Line 1074
	mov	ax,WORD PTR [bp+20]	;_X
	mov	WORD PTR [si+8],ax
; Line 1075
	mov	ax,WORD PTR [bp+18]	;_Y
	mov	WORD PTR [si+10],ax
; Line 1076
	mov	ax,WORD PTR [bp+6]	;_Layer
	mov	WORD PTR [si+6],ax
; Line 1077
	mov	ax,WORD PTR [bp+8]	;_IsVisible
	mov	WORD PTR [si+1096],ax
; Line 1079
	mov	WORD PTR [si+20],0
; Line 1080
	mov	WORD PTR [si+22],0
; Line 1082
	mov	ax,WORD PTR [bp+16]	;_BoundX
	mov	WORD PTR [si+1098],ax
; Line 1083
	mov	ax,WORD PTR [bp+14]	;_BoundY
	mov	WORD PTR [si+1100],ax
; Line 1085
	mov	ax,WORD PTR [bp+12]	;_BoundWidth
	mov	WORD PTR [si+1102],ax
; Line 1086
	mov	ax,WORD PTR [bp+10]	;_BoundHeight
	mov	WORD PTR [si+1104],ax
; Line 1088
	jmp	$EX7127
$EX7127:
	pop	si
	pop	di
	leave	
	ret	18	;0012H

?InitMoveable@object@@IACXHHHHHHW4boolean@@H@Z	ENDP
	PUBLIC	?SetCurrentSprite@animated@@QACAAVsprite@@PBUHWND__@@PAVscreen@@H@Z	; animated::SetCurrentSprite
?SetCurrentSprite@animated@@QACAAVsprite@@PBUHWND__@@PAVscreen@@H@Z	PROC NEAR	; animated::SetCurrentSprite COMDAT
; Line 1158
	push	bp
	mov	bp,sp
	mov	ax,0
	call	__aNchkstk
	push	di
	push	si
	mov	si,WORD PTR [bp+4]	;this
;	register si = this
;	hwnd = 10
;	Screen = 8
;	SpriteNumber = 6
; Line 1166
; Line 1167
	mov	ax,WORD PTR [bp+6]	;SpriteNumber
	mov	bx,WORD PTR [si+2]
	mov	bx,WORD PTR [bx+2]
	mov	WORD PTR [bx+22][si],ax
; Line 1168
	mov	bx,WORD PTR [si+2]
	mov	bx,WORD PTR [bx+2]
	mov	WORD PTR [bx+24][si],0
; Line 1169
; Line 1206
	mov	bx,WORD PTR [si+2]
	mov	ax,WORD PTR [bx+2]
	add	ax,si
	add	ax,2
	push	ax
	call	?Sprite@object@@QACAAVsprite@@XZ	; object::Sprite
	jmp	$EX7242
; Line 1207
$EX7242:
	pop	si
	pop	di
	leave	
	ret	8

?SetCurrentSprite@animated@@QACAAVsprite@@PBUHWND__@@PAVscreen@@H@Z	ENDP
	PUBLIC	?SetPosition@moveable@@UACXHH@Z	; moveable::SetPosition
?SetPosition@moveable@@UACXHH@Z	PROC NEAR	; moveable::SetPosition COMDAT
; Line 1368
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
; Line 1369
	mov	bx,WORD PTR [si+2]
	mov	bx,WORD PTR [bx+2]
	mov	ax,WORD PTR [bx+10][si]
	mov	WORD PTR [si+18],ax
; Line 1370
	mov	bx,WORD PTR [si+2]
	mov	bx,WORD PTR [bx+2]
	mov	ax,WORD PTR [bx+12][si]
	mov	WORD PTR [si+20],ax
; Line 1372
	mov	ax,WORD PTR [bp+8]	;_X
	mov	bx,WORD PTR [si+2]
	mov	bx,WORD PTR [bx+2]
	mov	WORD PTR [bx+10][si],ax
; Line 1373
	mov	ax,WORD PTR [bp+6]	;_Y
	mov	bx,WORD PTR [si+2]
	mov	bx,WORD PTR [bx+2]
	mov	WORD PTR [bx+12][si],ax
; Line 1375
	jmp	$EX7410
$EX7410:
	pop	si
	pop	di
	leave	
	ret	6

?SetPosition@moveable@@UACXHH@Z	ENDP
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
	PUBLIC	?CantGo@moveable@@UAC?AW4boolean@@PAVoccup_screen@@@Z	; moveable::CantGo
?CantGo@moveable@@UAC?AW4boolean@@PAVoccup_screen@@@Z	PROC NEAR	; moveable::CantGo COMDAT
; Line 1409
	push	bp
	mov	bp,sp
	mov	ax,0
	call	__aNchkstk
	push	di
	push	si
	mov	si,WORD PTR [bp+4]	;this
;	register si = this
;	Screen = 6
; Line 1410
	push	WORD PTR [bp+6]	;Screen
	push	si
	mov	bx,WORD PTR [si]
	call	WORD PTR [bx+4]
	cmp	ax,1
	sbb	ax,ax
	neg	ax
	jmp	$EX7423
; Line 1411
$EX7423:
	pop	si
	pop	di
	leave	
	ret	4

?CantGo@moveable@@UAC?AW4boolean@@PAVoccup_screen@@@Z	ENDP
	PUBLIC	??0_3D_object@@QAC@XZ	; _3D_object::_3D_object
??0_3D_object@@QAC@XZ	PROC NEAR	; _3D_object::_3D_object COMDAT
; Line 1605
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
	jmp	$I7697
$JCC20:
	mov	WORD PTR [si+2],OFFSET DGROUP:??_8_3D_object@@7B@
	lea	ax,WORD PTR [si+22]
	push	ax
	call	??0object@@QAC@XZ	; object::object
$I7697:
	mov	WORD PTR [si],OFFSET DGROUP:??_7_3D_object@@6B0@@
	mov	bx,WORD PTR [si+2]
	mov	bx,WORD PTR [bx+2]
	mov	WORD PTR [bx+2][si],OFFSET DGROUP:??_7_3D_object@@6Bobject@@@
	mov	bx,WORD PTR [si+2]
	mov	ax,WORD PTR [bx+2]
	sub	ax,20	;0014H
	mov	bx,WORD PTR [si+2]
	mov	bx,WORD PTR [bx+2]
	mov	WORD PTR [bx][si],ax
	mov	ax,si
	jmp	$EX7696
$EX7696:
	pop	si
	pop	di
	leave	
	ret	4

??0_3D_object@@QAC@XZ	ENDP
	PUBLIC	?SetPosition@_3D_moveable@@UACXHHPAV_3D_screen@@@Z	; _3D_moveable::SetPosition
?SetPosition@_3D_moveable@@UACXHHPAV_3D_screen@@@Z	PROC NEAR	; _3D_moveable::SetPosition COMDAT
; Line 1751
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
; Line 1752
	push	WORD PTR [bp+10]	;_X
	push	WORD PTR [bp+8]	;_Y
	push	si
	call	?SetPosition@moveable@@UACXHH@Z	; moveable::SetPosition
; Line 1754
	push	WORD PTR [bp+6]	;Screen
	push	0
	mov	bx,WORD PTR [si+2]
	mov	ax,WORD PTR [bx+4]
	add	ax,si
	add	ax,2
	push	ax
	mov	bx,WORD PTR [si+2]
	mov	bx,WORD PTR [bx+4]
	mov	bx,WORD PTR [bx+2][si]
	call	WORD PTR [bx+2]
; Line 1756
	jmp	$EX7894
$EX7894:
	pop	si
	pop	di
	leave	
	ret	8

?SetPosition@_3D_moveable@@UACXHHPAV_3D_screen@@@Z	ENDP
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
	PUBLIC	?Move1Step@_3D_actor@@UACXPBUHWND__@@PAV_3D_screen@@@Z	; _3D_actor::Move1Step
?Move1Step@_3D_actor@@UACXPBUHWND__@@PAV_3D_screen@@@Z	PROC NEAR	; _3D_actor::Move1Step COMDAT
; Line 1821
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
; Line 1822
	cmp	WORD PTR [si+52],0
	jne	$JCC18
	jmp	$I7980
$JCC18:
; Line 1823
; Line 1824
	lea	ax,WORD PTR [si+64]
	push	ax
	call	?NextFrame@animated@@UACHXZ	; animated::NextFrame
; Line 1825
	push	WORD PTR [bp+8]	;hwnd
	push	WORD PTR [bp+6]	;Screen
	push	si
	call	?Move1Step@_3D_moveable@@UACXPBUHWND__@@PAV_3D_screen@@@Z	; _3D_moveable::Move1Step
; Line 1826
; Line 1827
$I7980:
	jmp	$EX7979
$EX7979:
	pop	si
	pop	di
	leave	
	ret	6

?Move1Step@_3D_actor@@UACXPBUHWND__@@PAV_3D_screen@@@Z	ENDP
	PUBLIC	??0_3D_player@@QAC@HHHQAPADQAH11HHHHHHHHW4boolean@@H@Z	; _3D_player::_3D_player
??0_3D_player@@QAC@HHHQAPADQAH11HHHHHHHHW4boolean@@H@Z	PROC NEAR	; _3D_player::_3D_player COMDAT
; Line 1859
	push	bp
	mov	bp,sp
	mov	ax,0
	call	__aNchkstk
	push	di
	push	si
	mov	si,WORD PTR [bp+4]	;this
	mov	di,WORD PTR [bp+6]	;$initVBases
;	register si = this
;	_X = 40
;	_Y = 38
;	_NumberOfSprites = 36
;	BMPName = 34
;	BMPFrames = 32
;	BMPWidth = 30
;	BMPHeight = 28
;	_BoundX = 26
;	_BoundY = 24
;	_BoundWidth = 22
;	_BoundHeight = 20
;	_Timer = 18
;	_Period = 16
;	_DeltaX = 14
;	_DeltaY = 12
;	_IsVisible = 10
;	_Layer = 8
;	register di = $initVBases
	cmp	di,0
	jne	$JCC20
	jmp	$I8048
$JCC20:
	mov	WORD PTR [si+2],OFFSET DGROUP:??_8_3D_player@@7Bmoveable@@@
	mov	WORD PTR [si+56],OFFSET DGROUP:??_8_3D_player@@7Banimated@@@
	mov	WORD PTR [si+1178],OFFSET DGROUP:??_8_3D_player@@7B_3D_object@@@
	lea	ax,WORD PTR [si+70]
	push	ax
	call	??0object@@QAC@XZ	; object::object
	push	0
	lea	ax,WORD PTR [si+1176]
	push	ax
	call	??0_3D_object@@QAC@XZ	; _3D_object::_3D_object
$I8048:
	push	WORD PTR [bp+40]	;_X
	push	WORD PTR [bp+38]	;_Y
	push	WORD PTR [bp+36]	;_NumberOfSprites
	push	WORD PTR [bp+34]	;BMPName
	push	WORD PTR [bp+32]	;BMPFrames
	push	WORD PTR [bp+30]	;BMPWidth
	push	WORD PTR [bp+28]	;BMPHeight
	push	WORD PTR [bp+26]	;_BoundX
	push	WORD PTR [bp+24]	;_BoundY
	push	WORD PTR [bp+22]	;_BoundWidth
	push	WORD PTR [bp+20]	;_BoundHeight
	push	WORD PTR [bp+18]	;_Timer
	push	WORD PTR [bp+16]	;_Period
	push	WORD PTR [bp+14]	;_DeltaX
	push	WORD PTR [bp+12]	;_DeltaY
	push	WORD PTR [bp+10]	;_IsVisible
	push	WORD PTR [bp+8]	;_Layer
	push	0
	push	si
	call	??0_3D_actor@@QAC@HHHQAPADQAH11HHHHHHHHW4boolean@@H@Z	; _3D_actor::_3D_actor
	mov	WORD PTR [si],OFFSET DGROUP:??_7_3D_player@@6Bmoveable@@@
	mov	WORD PTR [si+54],OFFSET DGROUP:??_7_3D_player@@6Banimated@@@
	mov	bx,WORD PTR [si+2]
	mov	bx,WORD PTR [bx+2]
	mov	WORD PTR [bx+2][si],OFFSET DGROUP:??_7_3D_player@@6Bobject@@@
	mov	bx,WORD PTR [si+2]
	mov	bx,WORD PTR [bx+4]
	mov	WORD PTR [bx+2][si],OFFSET DGROUP:??_7_3D_player@@6B_3D_object@@@
	mov	bx,WORD PTR [si+2]
	mov	ax,WORD PTR [bx+2]
	sub	ax,68	;0044H
	mov	bx,WORD PTR [si+2]
	mov	bx,WORD PTR [bx+2]
	mov	WORD PTR [bx][si],ax
; Line 1860
	mov	ax,si
	jmp	$EX8047
$EX8047:
	pop	si
	pop	di
	leave	
	ret	38	;0026H

??0_3D_player@@QAC@HHHQAPADQAH11HHHHHHHHW4boolean@@H@Z	ENDP
	PUBLIC	?Init@tommy_screen@@UACPAVscreen@@PBUHWND__@@@Z	; tommy_screen::Init
?Init@tommy_screen@@UACPAVscreen@@PBUHWND__@@@Z	PROC NEAR	; tommy_screen::Init COMDAT
; Line 168
	push	bp
	mov	bp,sp
	mov	ax,4
	call	__aNchkstk
	push	di
	push	si
	mov	si,WORD PTR [bp+4]	;this
;	register di = i
;	j = -2
;	k = -4
;	register si = this
;	hwnd = 6
; Line 171
	push	WORD PTR [bp+6]	;hwnd
	push	si
	call	?Init@occup_screen@@UACPAVscreen@@PBUHWND__@@@Z	; occup_screen::Init
; Line 174
	mov	di,0
	jmp	$F8229
$FC8230:
	inc	di
$F8229:
	cmp	di,5
	jl	$JCC31
	jmp	$FB8231
$JCC31:
; Line 175
; Line 177
	mov	WORD PTR [bp-2],0	;j
	jmp	$F8232
$FC8233:
	inc	WORD PTR [bp-2]	;j
$F8232:
	cmp	WORD PTR [bp-2],40	;0028H	;j
	jl	$JCC51
	jmp	$FB8234
$JCC51:
; Line 178
; Line 179
	push	di
	push	WORD PTR [bp-2]	;j
	push	-1	;ffffH
	push	0
	push	WORD PTR [si+1096]
	call	?SetOccup@occup_matrix@@QACDHHDPAVobject@@@Z	; occup_matrix::SetOccup
; Line 180
	jmp	$FC8233
$FB8234:
; Line 181
	jmp	$FC8230
$FB8231:
; Line 185
	mov	di,5
	mov	WORD PTR [bp-4],8	;k
	jmp	$F8236
$FC8237:
	inc	di
	sub	WORD PTR [bp-4],3	;k
$F8236:
	cmp	di,8
	jl	$JCC96
	jmp	$FB8238
$JCC96:
; Line 186
; Line 187
	mov	WORD PTR [bp-2],0	;j
	jmp	$F8239
$FC8240:
	inc	WORD PTR [bp-2]	;j
$F8239:
	mov	ax,WORD PTR [bp-2]	;j
	cmp	WORD PTR [bp-4],ax	;k
	jg	$JCC118
	jmp	$FB8241
$JCC118:
; Line 188
; Line 189
	push	di
	push	WORD PTR [bp-2]	;j
	push	-1	;ffffH
	push	0
	push	WORD PTR [si+1096]
	call	?SetOccup@occup_matrix@@QACDHHDPAVobject@@@Z	; occup_matrix::SetOccup
; Line 190
	jmp	$FC8240
$FB8241:
; Line 191
	jmp	$FC8237
$FB8238:
; Line 194
	mov	ax,si
	jmp	$EX8225
; Line 196
$EX8225:
	pop	si
	pop	di
	leave	
	ret	4

?Init@tommy_screen@@UACPAVscreen@@PBUHWND__@@@Z	ENDP
	PUBLIC	?SetOccup@occup_matrix@@QACDHHDPAVobject@@@Z	; occup_matrix::SetOccup
?SetOccup@occup_matrix@@QACDHHDPAVobject@@@Z	PROC NEAR	; occup_matrix::SetOccup COMDAT
; Line 154
	push	bp
	mov	bp,sp
	mov	ax,0
	call	__aNchkstk
	push	di
	push	si
	mov	si,WORD PTR [bp+4]	;this
;	register si = this
;	Line = 12
;	Col = 10
;	Occup = 8
;	o = 6
; Line 155
	mov	ax,WORD PTR [bp+6]	;o
	imul	bx,WORD PTR [bp+12],81	;0051H	;Line
	add	bx,WORD PTR [bp+10]	;Col
	shl	bx,1
	mov	WORD PTR [bx+5266][si],ax
; Line 157
	mov	al,BYTE PTR [bp+8]	;Occup
	imul	bx,WORD PTR [bp+12],81	;0051H	;Line
	add	bx,WORD PTR [bp+10]	;Col
	mov	BYTE PTR [bx][si],al
	jmp	$EX6383
; Line 158
$EX6383:
	pop	si
	pop	di
	leave	
	ret	10	;000aH

?SetOccup@occup_matrix@@QACDHHDPAVobject@@@Z	ENDP
	PUBLIC	??0occup_matrix@@QAC@II@Z	; occup_matrix::occup_matrix
??0occup_matrix@@QAC@II@Z	PROC NEAR	; occup_matrix::occup_matrix COMDAT
; Line 200
	push	bp
	mov	bp,sp
	mov	ax,2
	call	__aNchkstk
	push	di
	push	si
	mov	si,WORD PTR [bp+4]	;this
;	register di = i
;	j = -2
;	register si = this
;	BufferWidth = 8
;	BufferHeight = 6
; Line 201
	mov	di,0
	mov	WORD PTR [bp-2],di	;j
; Line 203
	mov	ax,WORD PTR [bp+6]	;BufferHeight
	shr	ax,4
	inc	ax
	mov	WORD PTR [si+15798],ax
; Line 204
	mov	ax,WORD PTR [bp+8]	;BufferWidth
	shr	ax,4
	inc	ax
	mov	WORD PTR [si+15800],ax
; Line 206
	mov	di,0
	jmp	$F6412
$FC6413:
	inc	di
$F6412:
	cmp	WORD PTR [si+15798],di
	jg	$JCC53
	jmp	$FB6414
$JCC53:
; Line 207
; Line 208
	mov	WORD PTR [bp-2],0	;j
	jmp	$F6415
$FC6416:
	inc	WORD PTR [bp-2]	;j
$F6415:
	mov	ax,WORD PTR [bp-2]	;j
	cmp	WORD PTR [si+15800],ax
	jg	$JCC76
	jmp	$FB6417
$JCC76:
; Line 209
; Line 210
	push	di
	push	WORD PTR [bp-2]	;j
	push	0
	push	0
	push	si
	call	?SetOccup@occup_matrix@@QACDHHDPAVobject@@@Z	; occup_matrix::SetOccup
; Line 212
	jmp	$FC6416
$FB6417:
; Line 213
	jmp	$FC6413
$FB6414:
; Line 215
	mov	WORD PTR [si+15796],0
; Line 219
	mov	ax,si
	jmp	$EX6409
$EX6409:
	pop	si
	pop	di
	leave	
	ret	6

??0occup_matrix@@QAC@II@Z	ENDP
	PUBLIC	??0occup_screen@@QAC@PADHHHH@Z	; occup_screen::occup_screen
??0occup_screen@@QAC@PADHHHH@Z	PROC NEAR	; occup_screen::occup_screen COMDAT
; Line 385
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
	push	WORD PTR [bp+14]	;BackName
	push	WORD PTR [bp+12]	;_ScreenX
	push	WORD PTR [bp+10]	;_ScreenY
	push	WORD PTR [bp+8]	;_ScreenWidth
	push	WORD PTR [bp+6]	;_ScreenHeight
	push	si
	call	??0screen@@QAC@PADHHHH@Z	; screen::screen
	mov	WORD PTR [si],OFFSET DGROUP:??_7occup_screen@@6B@
	mov	ax,si
	jmp	$EX6614
$EX6614:
	pop	si
	pop	di
	leave	
	ret	12	;000cH

??0occup_screen@@QAC@PADHHHH@Z	ENDP
	PUBLIC	??0sprite@@QAC@XZ	; sprite::sprite
??0sprite@@QAC@XZ	PROC NEAR	; sprite::sprite COMDAT
; Line 555
	push	bp
	mov	bp,sp
	mov	ax,0
	call	__aNchkstk
	push	di
	push	si
	mov	si,WORD PTR [bp+4]	;this
;	register si = this
; Line 556
	mov	WORD PTR [si+4],0
; Line 557
	sub	ax,ax
	mov	WORD PTR [si+8],ax
	mov	WORD PTR [si+6],ax
; Line 558
	mov	ax,si
	jmp	$EX6737
$EX6737:
	pop	si
	pop	di
	leave	
	ret	2

??0sprite@@QAC@XZ	ENDP
	PUBLIC	?Init@sprite@@QACXPEUtagBITMAPINFOHEADER@@HHH@Z	; sprite::Init
?Init@sprite@@QACXPEUtagBITMAPINFOHEADER@@HHH@Z	PROC NEAR	; sprite::Init COMDAT
; Line 562
	push	bp
	mov	bp,sp
	mov	ax,0
	call	__aNchkstk
	push	di
	push	si
	mov	si,WORD PTR [bp+4]	;this
;	register si = this
;	_pBitMap = 12
;	_NumberOfFrames = 10
;	_FrameWidth = 8
;	_FrameHeight = 6
; Line 563
	mov	ax,WORD PTR [bp+12]	;_pBitMap
	mov	dx,WORD PTR [bp+14]
	mov	WORD PTR [si+6],ax
	mov	WORD PTR [si+8],dx
; Line 564
	mov	ax,WORD PTR [bp+10]	;_NumberOfFrames
	mov	WORD PTR [si+4],ax
; Line 566
	mov	ax,WORD PTR [bp+8]	;_FrameWidth
	mov	WORD PTR [si],ax
; Line 567
	mov	ax,WORD PTR [bp+6]	;_FrameHeight
	mov	WORD PTR [si+2],ax
; Line 574
	jmp	$EX6743
$EX6743:
	pop	si
	pop	di
	leave	
	ret	12	;000cH

?Init@sprite@@QACXPEUtagBITMAPINFOHEADER@@HHH@Z	ENDP
	PUBLIC	??0object_list@@QAC@PAVobject@@@Z	; object_list::object_list
??0object_list@@QAC@PAVobject@@@Z	PROC NEAR	; object_list::object_list COMDAT
; Line 628
	push	bp
	mov	bp,sp
	mov	ax,0
	call	__aNchkstk
	push	di
	push	si
	mov	si,WORD PTR [bp+4]	;this
;	register si = this
;	_FirstObject = 6
; Line 629
	mov	ax,WORD PTR [bp+6]	;_FirstObject
	mov	WORD PTR [si],ax
; Line 630
	mov	ax,si
	jmp	$EX6774
$EX6774:
	pop	si
	pop	di
	leave	
	ret	4

??0object_list@@QAC@PAVobject@@@Z	ENDP
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
	PUBLIC	??0_3D_actor@@QAC@HHHQAPADQAH11HHHHHHHHW4boolean@@H@Z	; _3D_actor::_3D_actor
??0_3D_actor@@QAC@HHHQAPADQAH11HHHHHHHHW4boolean@@H@Z	PROC NEAR	; _3D_actor::_3D_actor COMDAT
; Line 1813
	push	bp
	mov	bp,sp
	mov	ax,0
	call	__aNchkstk
	push	di
	push	si
	mov	si,WORD PTR [bp+4]	;this
	mov	di,WORD PTR [bp+6]	;$initVBases
;	register si = this
;	_X = 40
;	_Y = 38
;	_NumberOfSprites = 36
;	BMPName = 34
;	BMPFrames = 32
;	BMPWidth = 30
;	BMPHeight = 28
;	_BoundX = 26
;	_BoundY = 24
;	_BoundWidth = 22
;	_BoundHeight = 20
;	_Timer = 18
;	_Period = 16
;	_DeltaX = 14
;	_DeltaY = 12
;	_IsVisible = 10
;	_Layer = 8
;	register di = $initVBases
	cmp	di,0
	jne	$JCC20
	jmp	$I7975
$JCC20:
	mov	WORD PTR [si+2],OFFSET DGROUP:??_8_3D_actor@@7Bmoveable@@@
	mov	WORD PTR [si+56],OFFSET DGROUP:??_8_3D_actor@@7Banimated@@@
	mov	WORD PTR [si+1172],OFFSET DGROUP:??_8_3D_actor@@7B_3D_object@@@
	lea	ax,WORD PTR [si+64]
	push	ax
	call	??0object@@QAC@XZ	; object::object
	push	0
	lea	ax,WORD PTR [si+1170]
	push	ax
	call	??0_3D_object@@QAC@XZ	; _3D_object::_3D_object
$I7975:
	push	WORD PTR [bp+40]	;_X
	push	WORD PTR [bp+38]	;_Y
	push	WORD PTR [bp+36]	;_NumberOfSprites
	push	WORD PTR [bp+34]	;BMPName
	push	WORD PTR [bp+32]	;BMPFrames
	push	WORD PTR [bp+30]	;BMPWidth
	push	WORD PTR [bp+28]	;BMPHeight
	push	WORD PTR [bp+26]	;_BoundX
	push	WORD PTR [bp+24]	;_BoundY
	push	WORD PTR [bp+22]	;_BoundWidth
	push	WORD PTR [bp+20]	;_BoundHeight
	push	WORD PTR [bp+18]	;_Timer
	push	WORD PTR [bp+16]	;_Period
	push	WORD PTR [bp+14]	;_DeltaX
	push	WORD PTR [bp+12]	;_DeltaY
	push	WORD PTR [bp+10]	;_IsVisible
	push	WORD PTR [bp+8]	;_Layer
	push	0
	push	si
	call	??0_3D_moveable@@QAC@HHHQAPADQAH11HHHHHHHHW4boolean@@H@Z	; _3D_moveable::_3D_moveable
	push	0
	lea	ax,WORD PTR [si+54]
	push	ax
	call	??0_3D_animated@@QAC@XZ	; _3D_animated::_3D_animated
	mov	WORD PTR [si],OFFSET DGROUP:??_7_3D_actor@@6Bmoveable@@@
	mov	WORD PTR [si+54],OFFSET DGROUP:??_7_3D_actor@@6Banimated@@@
	mov	bx,WORD PTR [si+2]
	mov	bx,WORD PTR [bx+2]
	mov	WORD PTR [bx+2][si],OFFSET DGROUP:??_7_3D_actor@@6Bobject@@@
	mov	bx,WORD PTR [si+2]
	mov	bx,WORD PTR [bx+4]
	mov	WORD PTR [bx+2][si],OFFSET DGROUP:??_7_3D_actor@@6B_3D_object@@@
	mov	bx,WORD PTR [si+2]
	mov	ax,WORD PTR [bx+2]
	sub	ax,62	;003eH
	mov	bx,WORD PTR [si+2]
	mov	bx,WORD PTR [bx+2]
	mov	WORD PTR [bx][si],ax
; Line 1814
	mov	ax,WORD PTR [bp+18]	;_Timer
	mov	WORD PTR [si+58],ax
; Line 1815
	mov	ax,WORD PTR [bp+16]	;_Period
	mov	WORD PTR [si+60],ax
; Line 1817
	mov	ax,si
	jmp	$EX7974
$EX7974:
	pop	si
	pop	di
	leave	
	ret	38	;0026H

??0_3D_actor@@QAC@HHHQAPADQAH11HHHHHHHHW4boolean@@H@Z	ENDP
	PUBLIC	??0screen@@QAC@PADHHHH@Z	; screen::screen
??0screen@@QAC@PADHHHH@Z	PROC NEAR	; screen::screen COMDAT
; Line 264
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
; Line 266
	push	ds
	push	WORD PTR [bp+14]	;BackName
	call	_DibOpenFile
	add	sp,4
	mov	WORD PTR [si+8],ax
	mov	WORD PTR [si+10],dx
; Line 268
	les	bx,DWORD PTR [si+8]
	mov	ax,WORD PTR es:[bx+4]
	mov	WORD PTR [si+12],ax
; Line 269
	les	bx,DWORD PTR [si+8]
	mov	ax,WORD PTR es:[bx+8]
	mov	WORD PTR [si+14],ax
; Line 272
	mov	WORD PTR [si+30],0
; Line 274
	mov	ax,WORD PTR [bp+12]	;_ScreenX
	mov	WORD PTR [si+16],ax
; Line 275
	mov	ax,WORD PTR [bp+10]	;_ScreenY
	mov	WORD PTR [si+18],ax
; Line 277
	mov	ax,WORD PTR [bp+8]	;_ScreenWidth
	mov	WORD PTR [si+20],ax
; Line 278
	mov	ax,WORD PTR [bp+6]	;_ScreenHeight
	mov	WORD PTR [si+22],ax
; Line 282
	mov	ax,si
	jmp	$EX6502
$EX6502:
	pop	si
	pop	di
	leave	
	ret	12	;000cH

??0screen@@QAC@PADHHHH@Z	ENDP
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
	PUBLIC	??0_3D_animated@@QAC@XZ	; _3D_animated::_3D_animated
??0_3D_animated@@QAC@XZ	PROC NEAR	; _3D_animated::_3D_animated COMDAT
; Line 1689
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
	jmp	$I7787
$JCC20:
	mov	WORD PTR [si+2],OFFSET DGROUP:??_8_3D_animated@@7Banimated@@@
	mov	WORD PTR [si+1118],OFFSET DGROUP:??_8_3D_animated@@7B_3D_object@@@
	lea	ax,WORD PTR [si+10]
	push	ax
	call	??0object@@QAC@XZ	; object::object
	push	0
	lea	ax,WORD PTR [si+1116]
	push	ax
	call	??0_3D_object@@QAC@XZ	; _3D_object::_3D_object
$I7787:
	push	0
	push	si
	call	??0animated@@QAC@XZ	; animated::animated
	mov	WORD PTR [si],OFFSET DGROUP:??_7_3D_animated@@6Banimated@@@
	mov	bx,WORD PTR [si+2]
	mov	bx,WORD PTR [bx+2]
	mov	WORD PTR [bx+2][si],OFFSET DGROUP:??_7_3D_animated@@6Bobject@@@
	mov	bx,WORD PTR [si+2]
	mov	bx,WORD PTR [bx+4]
	mov	WORD PTR [bx+2][si],OFFSET DGROUP:??_7_3D_animated@@6B_3D_object@@@
	mov	bx,WORD PTR [si+2]
	mov	ax,WORD PTR [bx+2]
	sub	ax,8
	mov	bx,WORD PTR [si+2]
	mov	bx,WORD PTR [bx+2]
	mov	WORD PTR [bx][si],ax
	mov	ax,si
	jmp	$EX7786
$EX7786:
	pop	si
	pop	di
	leave	
	ret	4

??0_3D_animated@@QAC@XZ	ENDP
	PUBLIC	??0_3D_moveable@@QAC@HHHQAPADQAH11HHHHHHHHW4boolean@@H@Z	; _3D_moveable::_3D_moveable
??0_3D_moveable@@QAC@HHHQAPADQAH11HHHHHHHHW4boolean@@H@Z	PROC NEAR	; _3D_moveable::_3D_moveable COMDAT
; Line 1735
	push	bp
	mov	bp,sp
	mov	ax,0
	call	__aNchkstk
	push	di
	push	si
	mov	si,WORD PTR [bp+4]	;this
	mov	di,WORD PTR [bp+6]	;$initVBases
;	register si = this
;	_X = 40
;	_Y = 38
;	_NumberOfSprites = 36
;	BMPName = 34
;	BMPFrames = 32
;	BMPWidth = 30
;	BMPHeight = 28
;	_BoundX = 26
;	_BoundY = 24
;	_BoundWidth = 22
;	_BoundHeight = 20
;	_Timer = 18
;	_Period = 16
;	_DeltaX = 14
;	_DeltaY = 12
;	_IsVisible = 10
;	_Layer = 8
;	register di = $initVBases
	cmp	di,0
	jne	$JCC20
	jmp	$I7889
$JCC20:
	mov	WORD PTR [si+2],OFFSET DGROUP:??_8_3D_moveable@@7Bmoveable@@@
	mov	WORD PTR [si+1164],OFFSET DGROUP:??_8_3D_moveable@@7B_3D_object@@@
	lea	ax,WORD PTR [si+56]
	push	ax
	call	??0object@@QAC@XZ	; object::object
	push	0
	lea	ax,WORD PTR [si+1162]
	push	ax
	call	??0_3D_object@@QAC@XZ	; _3D_object::_3D_object
$I7889:
	push	WORD PTR [bp+40]	;_X
	push	WORD PTR [bp+38]	;_Y
	push	WORD PTR [bp+36]	;_NumberOfSprites
	push	WORD PTR [bp+34]	;BMPName
	push	WORD PTR [bp+32]	;BMPFrames
	push	WORD PTR [bp+30]	;BMPWidth
	push	WORD PTR [bp+28]	;BMPHeight
	push	WORD PTR [bp+26]	;_BoundX
	push	WORD PTR [bp+24]	;_BoundY
	push	WORD PTR [bp+22]	;_BoundWidth
	push	WORD PTR [bp+20]	;_BoundHeight
	push	WORD PTR [bp+18]	;_Timer
	push	WORD PTR [bp+16]	;_Period
	push	WORD PTR [bp+14]	;_DeltaX
	push	WORD PTR [bp+12]	;_DeltaY
	push	WORD PTR [bp+10]	;_IsVisible
	push	WORD PTR [bp+8]	;_Layer
	push	0
	push	si
	call	??0moveable@@QAC@HHHQAPADQAH11HHHHHHHHW4boolean@@H@Z	; moveable::moveable
	mov	WORD PTR [si],OFFSET DGROUP:??_7_3D_moveable@@6Bmoveable@@@
	mov	bx,WORD PTR [si+2]
	mov	bx,WORD PTR [bx+2]
	mov	WORD PTR [bx+2][si],OFFSET DGROUP:??_7_3D_moveable@@6Bobject@@@
	mov	bx,WORD PTR [si+2]
	mov	bx,WORD PTR [bx+4]
	mov	WORD PTR [bx+2][si],OFFSET DGROUP:??_7_3D_moveable@@6B_3D_object@@@
	mov	bx,WORD PTR [si+2]
	mov	ax,WORD PTR [bx+2]
	sub	ax,54	;0036H
	mov	bx,WORD PTR [si+2]
	mov	bx,WORD PTR [bx+2]
	mov	WORD PTR [bx][si],ax
; Line 1736
	mov	ax,si
	jmp	$EX7888
$EX7888:
	pop	si
	pop	di
	leave	
	ret	38	;0026H

??0_3D_moveable@@QAC@HHHQAPADQAH11HHHHHHHHW4boolean@@H@Z	ENDP
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
	PUBLIC	??0animated@@QAC@XZ	; animated::animated
??0animated@@QAC@XZ	PROC NEAR	; animated::animated COMDAT
; Line 1101
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
	jmp	$I7203
$JCC20:
	mov	WORD PTR [si+2],OFFSET DGROUP:??_8animated@@7B@
	lea	ax,WORD PTR [si+10]
	push	ax
	call	??0object@@QAC@XZ	; object::object
$I7203:
	mov	WORD PTR [si],OFFSET DGROUP:??_7animated@@6B0@@
	mov	bx,WORD PTR [si+2]
	mov	bx,WORD PTR [bx+2]
	mov	WORD PTR [bx+2][si],OFFSET DGROUP:??_7animated@@6Bobject@@@
	mov	bx,WORD PTR [si+2]
	mov	ax,WORD PTR [bx+2]
	sub	ax,8
	mov	bx,WORD PTR [si+2]
	mov	bx,WORD PTR [bx+2]
	mov	WORD PTR [bx][si],ax
	mov	ax,si
	jmp	$EX7202
$EX7202:
	pop	si
	pop	di
	leave	
	ret	4

??0animated@@QAC@XZ	ENDP
	PUBLIC	??0moveable@@QAC@HHHQAPADQAH11HHHHHHHHW4boolean@@H@Z	; moveable::moveable
??0moveable@@QAC@HHHQAPADQAH11HHHHHHHHW4boolean@@H@Z	PROC NEAR	; moveable::moveable COMDAT
; Line 1304
	push	bp
	mov	bp,sp
	mov	ax,0
	call	__aNchkstk
	push	di
	push	si
	mov	si,WORD PTR [bp+4]	;this
	mov	di,WORD PTR [bp+6]	;$initVBases
;	register si = this
;	_X = 40
;	_Y = 38
;	_NumberOfSprites = 36
;	BMPName = 34
;	BMPFrames = 32
;	BMPWidth = 30
;	BMPHeight = 28
;	_BoundX = 26
;	_BoundY = 24
;	_BoundWidth = 22
;	_BoundHeight = 20
;	_Timer = 18
;	_Period = 16
;	_DeltaX = 14
;	_DeltaY = 12
;	_IsVisible = 10
;	_Layer = 8
;	register di = $initVBases
	cmp	di,0
	jne	$JCC20
	jmp	$I7389
$JCC20:
	mov	WORD PTR [si+2],OFFSET DGROUP:??_8moveable@@7B@
	lea	ax,WORD PTR [si+56]
	push	ax
	call	??0object@@QAC@XZ	; object::object
$I7389:
	mov	WORD PTR [si],OFFSET DGROUP:??_7moveable@@6B0@@
	mov	bx,WORD PTR [si+2]
	mov	bx,WORD PTR [bx+2]
	mov	WORD PTR [bx+2][si],OFFSET DGROUP:??_7moveable@@6Bobject@@@
	mov	bx,WORD PTR [si+2]
	mov	ax,WORD PTR [bx+2]
	sub	ax,54	;0036H
	mov	bx,WORD PTR [si+2]
	mov	bx,WORD PTR [bx+2]
	mov	WORD PTR [bx][si],ax
; Line 1308
	push	WORD PTR [bp+40]	;_X
	push	WORD PTR [bp+38]	;_Y
	push	WORD PTR [bp+26]	;_BoundX
	push	WORD PTR [bp+24]	;_BoundY
	push	WORD PTR [bp+22]	;_BoundWidth
	push	WORD PTR [bp+20]	;_BoundHeight
	push	WORD PTR [bp+10]	;_IsVisible
	push	WORD PTR [bp+8]	;_Layer
	mov	bx,WORD PTR [si+2]
	mov	ax,WORD PTR [bx+2]
	add	ax,si
	add	ax,2
	push	ax
	call	?InitMoveable@object@@IACXHHHHHHW4boolean@@H@Z	; object::InitMoveable
; Line 1313
	push	WORD PTR [bp+36]	;_NumberOfSprites
	push	WORD PTR [bp+34]	;BMPName
	push	WORD PTR [bp+32]	;BMPFrames
	push	WORD PTR [bp+30]	;BMPWidth
	push	WORD PTR [bp+28]	;BMPHeight
	mov	bx,WORD PTR [si+2]
	mov	ax,WORD PTR [bx+2]
	add	ax,si
	add	ax,2
	push	ax
	call	?InitAnimated@object@@IACXHQAPADQAH11@Z	; object::InitAnimated
; Line 1316
	mov	bx,WORD PTR [si+2]
	mov	bx,WORD PTR [bx+2]
	mov	ax,WORD PTR [bx+10][si]
	mov	WORD PTR [si+18],ax
	mov	WORD PTR [si+22],ax
; Line 1317
	mov	bx,WORD PTR [si+2]
	mov	bx,WORD PTR [bx+2]
	mov	ax,WORD PTR [bx+12][si]
	mov	WORD PTR [si+20],ax
	mov	WORD PTR [si+24],ax
; Line 1319
	mov	ax,WORD PTR [bp+18]	;_Timer
	mov	WORD PTR [si+48],ax
; Line 1320
	mov	ax,WORD PTR [bp+16]	;_Period
	mov	WORD PTR [si+50],ax
; Line 1322
	mov	ax,WORD PTR [bp+14]	;_DeltaX
	mov	WORD PTR [si+30],ax
; Line 1323
	mov	ax,WORD PTR [bp+12]	;_DeltaY
	mov	WORD PTR [si+32],ax
; Line 1325
	mov	WORD PTR [si+52],0
; Line 1327
	mov	ax,si
	jmp	$EX7388
$EX7388:
	pop	si
	pop	di
	leave	
	ret	38	;0026H

??0moveable@@QAC@HHHQAPADQAH11HHHHHHHHW4boolean@@H@Z	ENDP
	PUBLIC	?InitAnimated@object@@IACXHQAPADQAH11@Z	; object::InitAnimated
?InitAnimated@object@@IACXHQAPADQAH11@Z	PROC NEAR	; object::InitAnimated COMDAT
; Line 1026
	push	bp
	mov	bp,sp
	mov	ax,6
	call	__aNchkstk
	push	di
	push	si
	mov	si,WORD PTR [bp+4]	;this
;	i = -4
;	_aad = -2
;	register si = this
;	_NumberOfSprites = 14
;	BMPName = 12
;	BMPFrames = 10
;	BMPWidth = 8
;	BMPHeight = 6
; Line 1027
	mov	ax,WORD PTR [bp+14]	;_NumberOfSprites
	mov	WORD PTR [si+18],ax
; Line 1029
	mov	ax,WORD PTR [si+18]
	mov	WORD PTR [bp-2],ax	;_aad
	mov	cx,ax
	shl	ax,2
	add	ax,cx
	shl	ax,1
	add	ax,2
	push	ax
	call	??2@YAPAXI@Z	; operator new
	add	sp,2
	mov	WORD PTR [bp-6],ax
	cmp	ax,0
	jne	$JCC51
	jmp	$L8637
$JCC51:
	mov	ax,WORD PTR [bp-6]
	add	ax,2
	push	ax
	push	10	;000aH
	mov	ax,WORD PTR [bp-2]	;_aad
	mov	bx,WORD PTR [bp-6]
	mov	WORD PTR [bx],ax
	push	ax
	push	OFFSET ??0sprite@@QAC@XZ	;sprite::sprite
	call	??_H@YCXPAXIHP6CX0@Z@Z	; ??_H@YCXPAXIHP6CX0@Z@Z
	mov	ax,WORD PTR [bp-6]
	add	ax,2
	mov	WORD PTR [si+16],ax
	jmp	$L8638
$L8637:
	mov	WORD PTR [si+16],0
$L8638:
; Line 1031
	mov	WORD PTR [bp-4],0	;i
	jmp	$F7107
$FC7108:
	inc	WORD PTR [bp-4]	;i
$F7107:
	mov	ax,WORD PTR [bp-4]	;i
	cmp	WORD PTR [si+18],ax
	ja	$JCC114
	jmp	$FB7109
$JCC114:
; Line 1032
; Line 1034
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
	shl	ax,2
	add	ax,cx
	shl	ax,1
	add	ax,WORD PTR [si+16]
	push	ax
	call	?Init@sprite@@QACXPEUtagBITMAPINFOHEADER@@HHH@Z	; sprite::Init
; Line 1035
	jmp	$FC7108
$FB7109:
; Line 1037
	jmp	$EX7101
$EX7101:
	pop	si
	pop	di
	leave	
	ret	12	;000cH

?InitAnimated@object@@IACXHQAPADQAH11@Z	ENDP
_TEXT	ENDS
END
