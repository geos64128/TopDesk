;CopyDisk
; Date:	21.6.1991
; Par:	r6 - Zeiger auf den SourceDiskNamen (mu~ nicht unbedingt eingelegt sein)
; Ret:	x - Fehlernummer
; Des:	alles

:dir3Head	=	$9c80
:INV_TRACK	=	$02
:IDD_DDr	b	"B:"
:DestinationName	s	17
:MyInterleave	b	0
:VerifyFlag	b	$ff
:Make2SFlag	b	0
:CopyDrives	w	0
:SourceName	w	0
:SourceType	b	0

:StartCopyDisk	ldy	#0
	lda	#0
	jsr	ChangeDisk
	txa
	beq	:01
	rts
::01	MoveB	curType,SourceType
	ldy	#0
	sty	r1H
	sty	r11H
	iny
	sty	r1L
	sty	r11L
::00	LoadW	r0,ReadBlock
	jsr	:100
	cpx	#INV_TRACK
	beq	:05
	txa
	bne	:err
::05	MoveW	r1,r10
	ldy	#1
	tya
	jsr	ChangeDisk
	txa
	bne	:err
	MoveW	r11,r1
	LoadW	r0,DirTrack
	jsr	:100
	cpx	#INV_TRACK
	beq	:07
	txa
	bne	:err
::07	lda	VerifyFlag
	beq	:10
	MoveW	r11,r1
	LoadW	r0,VerWriteBlock
	jsr	:100
::10	cpx	#INV_TRACK
	beq	:30
	txa
	bne	:err
	ldy	#0
	lda	#1
	jsr	ChangeDisk
	txa
	bne	:err
	lda	r10L
	sta	r1L
	sta	r11L
	lda	r10H
	sta	r1H
	sta	r11H
	jmp	:00
::30	ldy	#1
	lda	#0
	jsr	ChangeDisk
	ldx	Make2SFlag
	beq	:err
	jsr	Make2Sides
	ldx	#0
::err	rts

::100	jsr	InitCount
	txa
	bne	:130
	LoadW	r4,MemBegin
	jsr	EnterTurbo
	txa
	bne	:130
	jsr	InitForIO
::110	MoveW	r1,r6
	jsr	FindBAMBit
	bne	:115
	lda	r0L
	ldx	r0H
	jsr	CallRoutine
	txa
	bne	:130
	ldy	r4H
	iny
	cpy	CopyMemHigh
	beq	:120
	sty	r4H
::115	jsr	CountBlock
	txa
	beq	:110
	bne	:130
::120	ldx	#0
::130	jmp	DoneWithIO
:DirTrack	lda	#00
	cmp	r1L
	bne	:40
	lda	r1H
	bne	:40
	ldy	#144
::30	lda	DestinationName-144,y
	beq	:20
	sta	(r4),y
	iny
	cpy	#160
	bcc	:30
	bcs	:10
::20	lda	#$a0
	sta	(r4),y
	iny
	cpy	#160
	bcc	:20
::10	ldx	Make2SFlag
	beq	:40
	ldy	#3
	lda	#$80
	sta	(r4),y
::40	jmp	WriteBlock

:ChangeDisk	;wechselt Source- nach Destinationdisk usw.
; Par:	y - 0 f}r Source einlegen und 1 entspr. f}r Destination
;	a - 0 f}r vollst{ndigen Diskettenwechsel
; Ret:	x - evtl. Fehlernummer (0-kein Fehler)
; Use:	CopyDrives,SourceName,DestinationName
; Des:	a,x,y,
	tax
	MoveW	SourceName,r6
	tya
	beq	:20
	LoadW	r6,DestinationName
::20	txa
	bne	:30
	jmp	SearchDisk
::30	lda	SourceType
	and	#DRIVE_MASK
	cmp	#3
	bne	:noretdir3
	jsr	i_MoveData
	w	dir3Head,fileHeader,256
::noretdir3	jsr	NewSearchDisk
	txa
	bne	:err
	lda	SourceType
	and	#DRIVE_MASK
	cmp	#3
	bne	:err
	jsr	i_MoveData
	w	fileHeader,dir3Head,256
::err	rts

;InitCount
; initialisiert CountBlock
; Par: r1 - Track/Sektor des erstenBlocks
; Ret: x - Fehlernummer (0=kein Fehler)
; Use: SeperTr,FirstSektor,Track,Sektor,GetSectors
; Des: a,x,y,r6-r9
:InitCount	MoveB	r1L,Track
	lda	r1H
	pha
	sta	Sektor
	jsr	GetSectors
	txa
	bne	:10
	MoveB	r1H,SeperTr
	lda	#0
	sta	r6H
	sta	r7H
	MoveB	Sektor,r6L
	MoveB	MyInterleave,r7L
	ldx	#r6L
	ldy	#r7L
	jsr	Ddiv
	MoveB	r8L,FirstSektor
	ldx	#0
::10	pla
	sta	r1H
	rts

:Track	b	0
:Sektor	b	0
:SeperTr	b	0
:FirstSektor	b	0

;CountBlock
; z{hlt in Abh{ngigkeit von MyInterleave 1 Block weiter
; Par: keine
; Ret: r1 - n{chster Track/Sektor
;      x  - Fehlernummer
; Use: SeperTr,FirstSektor,Track,Sektor,InitCount2
; Des: a,y
:CountBlock
	lda	Sektor
	clc
	adc	MyInterleave
	sta	Sektor
	sta	r1H
	cmp	SeperTr
	bcc	:10
	inc	FirstSektor
	lda	FirstSektor
	cmp	MyInterleave
	bcs	:20
	sta	r1H
	sta	Sektor
::10	MoveB	Track,r1L
	ldx	#0
	rts
::20	inc	Track
	MoveB	Track,r1L
	LoadB	r1H,0
	jmp	InitCount

;GetSectors gibt zu einem bestimmten Track die Anzahl der
;m|glichen Sektoren.
;Par: r1L - Track
;Ret: r1H - Sektoren
;     x   - Fehlernummer:
;           $00 - kein Fehler
;Des: a,y
:GetSectors
	lda	SourceType
	and	#DRIVE_MASK
	tay
	lda	r1L
	beq	:err
	dey
	bne	:10
	cmp	#36	;1541
	bcc	:20
::err	ldx	#INV_TRACK
	rts
::10	dey
	bne	:50
	cmp	#71	;1571
	bcs	:err
::20	ldy	#7	;1571/41
::30	cmp	Tracks,y
	bcs	:40
	dey
	bpl	:30
	bmi	:err
::40	tya
	and	#%0000 0011
	tay
	lda	Sectors,y
::45	sta	r1H
	ldx	#0
	rts
::50	cmp	#81
	bcs	:err
	lda	#40
	bne	:45

:Tracks	b	1,18,25,31,36,53,60,66
:Sectors	b	21,19,18,17

:Make2Sides	jsr	i_FillRam
	w	256,dir2Head
	b	0
	LoadW	r0,Content18
	jsr	InitRam
	jmp	PutDirHead
:Content18	w	curDirHead+221
	b	35
	b	$15,$15,$15,$15,$15,$15,$15,$15,$15,$15,$15,$15,$15,$15,$15,$15,$15
	b	0,$13,$13,$13,$13,$13,$13,$12,$12,$12,$12,$12,$12
	b	$11,$11,$11,$11,$11
:Content53	w	dir2Head
	b	105
	b	$ff,$ff,$1f,$ff,$ff,$1f,$ff,$ff,$1f,$ff,$ff,$1f
	b	$ff,$ff,$1f,$ff,$ff,$1f,$ff,$ff,$1f,$ff,$ff,$1f
	b	$ff,$ff,$1f,$ff,$ff,$1f,$ff,$ff,$1f,$ff,$ff,$1f
	b	$ff,$ff,$1f,$ff,$ff,$1f,$ff,$ff,$1f,$ff,$ff,$1f
	b	$ff,$ff,$1f,$00,$00,$00
	b	$ff,$ff,$07,$ff,$ff,$07,$ff,$ff,$07,$ff,$ff,$07,$ff,$ff,$07,$ff,$ff,$07
	b	$ff,$ff,$03,$ff,$ff,$03,$ff,$ff,$03,$ff,$ff,$03,$ff,$ff,$03,$ff,$ff,$03
	b	$ff,$ff,$01,$ff,$ff,$01,$ff,$ff,$01,$ff,$ff,$01,$ff,$ff,$01
	w	0

:CopyDisk
; Par:	r6 - Zeiger auf den SourceDiskNamen (mu~ nicht unbedingt eingelegt sein)
	MoveW	r6,SourceName
	jsr	SearchDisk
	txa
	beq	:00
	rts
::00	MoveB	curDirHead,DirTrack+1
	MoveB	interleave,MyInterleave
	lda	curType
	and	#DRIVE_MASK
	cmp	#2
	bne	:05
	ldx	curDirHead+3
	bmi	:05
	lda	#1
::05	sta	SourceType
	lda	curDrive
	sta	CopyDrives
	sta	CopyDrives+1
	jsr	NextDrive
	txa
	bne	:err
	LoadW	:IDD_DIT,DummyDIconTab
	lda	CopyDrives
	cmp	CopyDrives+1
	beq	:10
	LoadW	:IDD_DIT,DrivesIconTab
::10	lda	CopyDrives
	clc
	adc	#"A"-8
	sta	IDD_SDr
::15	ldx	#DISK
	lda	curType
	and	#%1000 0000
	beq	:20
	ldx	#0
::20	stx	:IDD_RAM
::25	lda	CopyDrives+1
	clc
	adc	#"A"-8
	sta	IDD_DDr
	LoadW	r0,:InsertDiskDial
	jsr	DoDlgBox
	lda	r0L
	cmp	#OK
	bne	:30
	lda	curDirHead+189
	cmp	#$50
	beq	:27
	cmp	#$42
	bne	:28
::27	LoadW	r0,:NoSystemBox
	jsr	DoDlgBox
	ldx	#12
	rts
::28	jmp	StartCopyDisk

::30	cmp	#DISK
	bne	:40
	jsr	InsertNewDisk
	txa
	beq	:25
::err	rts
::40	cmp	#128
	bne	:50
	jsr	NextDrive
	txa
	beq	:15
	bne	:err
::50	ldx	#CANCEL_ERR
	rts
::InsertDiskDial	b	$81,DB_USR_ROUT
	w	InitClickingOutSide
	b	DBOPVEC
	w	ClickOutSide
	b	OK,17,6
	b	CANCEL,17,72
	b	DBTXTSTR,4,14
	w	:IDD_t1
	b	DBTXTSTR,4,30
	w	:IDD_t2
	b	DBTXTSTR,4,58
	w	:IDD_t3
	b	DBTXTSTR,18,88
	w	:IDD_t4
	b	DBTXTSTR,10,69
	w	IDD_DDr
	b	DBUSRICON,17,50
::IDD_DIT	w	DrivesIconTab
::IDD_RAM	b	DISK,17,28,0
::IDD_t1	b	BOLDON,"Zieldiskette ausw{hlen:",0
::IDD_t2	b	"Startdiskette",0
::IDD_t3	b	"Zieldiskette",PLAINTEXT,0
::IDD_t4	b	"Verify",0
::NoSystemBox
	b	$81
	b	$0b,$10,$10
	w	:t1
	b	$0b,$10,$20
	w	:t2
	b	$0b,$10,$30
	w	:t3
	b	OK,17,72,NULL
::t1	b	"Die Zieldiskette darf keine ",0
::t2	b	"System- oder Hauptdiskette",0
::t3	b	"sein.",0

:IDD_SDr	b	"A:",0

:NextDrive	ldy	CopyDrives+1
::10	iny
	cpy	#12
	bcc	:20
	ldy	#8
::20	lda	driveType-8,y
	beq	:10
	and	#DRIVE_MASK
	cmp	SourceType	;mit Sourcetype vergleichen
	beq	:30
	tax
	lda	SourceType
	cmp	#1
	bne	:10
	cpx	#2
	bne	:10
::30	cpy	CopyDrives
	bne	:40
	lda	driveType-8,y
	and	#%1000 0000
	beq	:40
	lda	CopyDrives
	cmp	CopyDrives+1
	bne	:10
	ldx	#115
	rts
::40	tya
	sta	CopyDrives+1
	jsr	NewSetDevice

:InsertNewDisk	jsr	OpenDisk
	txa
	bne	:30	
	ldy	#15
::10	lda	curDirHead+144,y
	cmp	#$a0
	bne	:20
	lda	#0
::20	sta	DestinationName,y
	dey
	bpl	:10
	LoadW	r5,DestinationName
	MoveW	SourceName,r6
	ldx	#r5L
	ldy	#r6L
	jsr	CmpString
	bne	:40
::30	lda	curDrive
	clc
	adc	#"A"-8
	sta	:IZD_Dr
	LoadW	r0,:InsertZielDial
	jsr	DoDlgBox
	lda	r0L
	cmp	#OK
	beq	InsertNewDisk
	ldx	#CANCEL_ERR
	rts
::40	lda	interleave
	cmp	MyInterleave
	bcc	:50
	sta	MyInterleave
::50	ldx	#0
	lda	SourceType
	cmp	#1
	bne	:60
	lda	curType
	and	#DRIVE_MASK & %1111 1101
	bne	:60
	lda	curDirHead+3
	bpl	:60
	dex
::60	stx	Make2SFlag
	lda	SourceType
	cmp	#2
	bne	:70
	lda	curType
	and	#DRIVE_MASK & %1111 1101
	bne	:70
	lda	curDirHead+3
	bpl	:30
::70	ldx	#0
	rts
::InsertZielDial	b	$81,OK,1,72,CANCEL,17,72
	b	DBTXTSTR,16,16
	w	:IZD_t1
	b	DBTXTSTR,16,32
	w	:IZD_t2
	b	0
::IZD_t1	b	BOLDON,"Bitte Zieldisk in Laufwerk "
::IZD_Dr	b	"A",0
::IZD_t2	b	"einlegen.",PLAINTEXT,0

:InitClickingOutSide	LoadW	r0,IDD_SDr
	LoadW	r11,74
	LoadB	r1H,75
	jsr	PutString
	MoveW	SourceName,r0
	jsr	PutString
	jsr	i_FrameRectangle
	b	82+32,88+32
	w	8+64,14+64
	b	%1111 1111
	lda	VerifyFlag
	beq	:10
	jsr	InvertRectangle
::10	rts
:ClickOutSide	lda	mouseData
	beq	:10
	LoadB	r2L,82+32
	LoadB	r2H,88+32
	LoadW	r3,8+64
	LoadW	r4,14+64
	jsr	IsMseInRegion
	beq	:10
	lda	VerifyFlag
	eor	#$ff
	sta	VerifyFlag
	jmp	InvertRectangle
::10	rts

:MemBegin	=	(CopyDisk&$ff00)+$100
:DummyDIconTab	w	0
	b	0,0,1,1
	w	0
:DrivesIconTab	w	DrivesIcon
	b	0,0,6,16
	w	DrivesIconRout
:DrivesIconRout	LoadB	sysDBData,128
	jmp	RstrFrmDialogue
:DrivesIcon	b	$06,$10,$00,$05,$ff,$82,$fe,$80
	b	$04,$00,$82,$03,$80,$04,$00,$b2
	b	$03,$b0,$38,$00,$00,$00,$c3,$b0
	b	$60,$00,$00,$00,$c3,$b0,$f0,$18
	b	$67,$3e,$db,$b0,$60,$18,$6d,$b8
	b	$f3,$b0,$67,$cf,$cf,$b0,$e3,$b0
	b	$60,$0f,$cc,$30,$e3,$b0,$60,$07
	b	$8d,$b0,$f3,$be,$60,$07,$87,$30
	b	$db,$80,$04,$00,$82,$03,$80,$04
	b	$00,$82,$03,$80,$04,$00,$81,$03
	b	$06,$ff,$81,$7f,$05,$ff,$0c,$bf

