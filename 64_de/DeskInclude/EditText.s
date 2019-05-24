:EditText	; Text-Editierung
; Par:	keine
; Ret:	keine
; Des:	alles
	lda	dirEntryBuf+22
	bne	:05
	rts
::05	MoveW	otherPressVec,oldotherPress
	LoadW	otherPressVec,MouseRoutine
	LoadW	keyVector,TextKeyRoutine
	lda	curHeight
	jsr	InitTextPrompt
	ldy	#MaxTextLength-1
::testcodeloop	lda	Text,y
	beq	:codeok
	cmp	#$0d
	beq	:codeok
	cmp	#32
	bcc	:undefinedcode
	cmp	#127
	bcc	:codeok
::undefinedcode	lda	#"*"
	sta	Text,y
::codeok	dey
	bpl	:testcodeloop
	ldy	#5
::10	lda	PositionYO,y
	sta	r2L,y
	sta	windowTop,y
	dey
	bpl	:10
	dec	r2L
	inc	r2H
	ldx	#r3L
	jsr	Ddec
	inc	r4L
	bne	:20
	inc	r4H
::20	lda	#$ff
	jsr	FrameRectangle
	LoadB	ActualCharacter,0
	jmp	NewText
:oldotherPress	w	0

:TextKeyRoutine	lda	keyData
	cmp	#32
	bcs	:100
::noputkey	cmp	#128+20
	bne	:noclose
	jmp	RstrFrmDialog
::noclose	cmp	#08
	bne	:10
	lda	ActualCharacter
	beq	:99
	dec	ActualCharacter
	jmp	NewDisplay
::10	cmp	#30
	bne	:20
	ldy	ActualCharacter
	iny
	cpy	TextLength
	bcs	:99
	inc	ActualCharacter
	jmp	NewDisplay
::20	cmp	#17
	bne	:30
	lda	stringY
	clc
	adc	#10
::25	sta	r1H
	MoveW	stringX,r11
	jmp	SetTextPtr
::30	cmp	#16
	bne	:40
	ldy	ActualCharPointer
	beq	:99
	lda	stringY
	sec
	sbc	#10
	jmp	:25
::40	ldx	#$ff
	stx	AlternateFlag
	cmp	#29
	bne	:50
	ldy	ActualCharacter
	beq	:99
	jsr	DeleteChar
	dec	ActualCharacter
	jmp	NewText
::50	cmp	#$0d
	beq	:102
::70
::99	rts	;Sonderzeichen

::100	cmp	#127
	bcs	:noputkey
::102	ldx	#$ff
	stx	AlternateFlag
	ldy	TextLength
	cpy	#MaxTextLength
	bcs	:99
	jsr	InsertChar
	inc	ActualCharacter
	ldy	ActualCharacter
	cpy	TextLength
	bcs	:110
	jmp	NewText
::110	jsr	RethinkText
	MoveW	stringX,r11
	MoveW	stringX,r0
	lda	stringY
	clc
	adc	#7
	sta	r1H
	lda	keyData
	jsr	GetCharWidth
	beq	:117
	clc
	adc	r0L
	sta	r0L
	bcc	:115
	inc	r0H
::115	CmpW	r0,PositionXR
	bcc	:118
::117	inc	ActualCharPointer
	jmp	NewText
::118	lda	keyData
	jsr	PutChar
	jmp	NewDisplay

:MouseRoutine	lda	mouseData
	bpl	:10
::05	lda	oldotherPress
	ldx	oldotherPress+1
	jmp	CallRoutine
::10	ldy	#5
::15	lda	PositionYO,y
	sta	r2L,y
	dey
	bpl	:15
	jsr	IsMseInRegion
	beq	:05
	MoveW	mouseXPos,r11
	MoveB	mouseYPos,r1H
:SetTextPtr	jsr	TextPosition
	bcc	:20
	ldx	ActualCharacter
	beq	:20
	dex
	dex
	stx	ActualCharacter
	jsr	InitForIO
	inc	$d020
	jsr	DoneWithIO
	jsr	NewDisplay
	LoadB	keyData,30
	jmp	TextKeyRoutine
::20	jmp	NewDisplay

:NewText
; rechnet alle Zeiger neu aus und gibt alle Zeilen ab der aktuellen aus
	jsr	RethinkText
	jsr	RethinkActChrPtr
	PushB	ActualCharPointer
	lda	ActualCharPointer
	beq	:10
	dec	ActualCharPointer
::10	jsr	RefreshLine
	inc	ActualCharPointer
	lda	ActualCharPointer
	cmp	#MaxZeilen
	bcc	:10
	PopB	ActualCharPointer
	jmp	NewDisplay

:NewDisplay
; aktualisiert den Cursor
	jsr	RethinkActChrPtr
	lda	ActualCharPointer
	asl
	sta	r1H
	asl
	asl
	clc
	adc	r1H
	adc	PositionYO
	bcs	:drau~en
	cmp	PositionYU
	bcc	:drin
::drau~en	lda	PositionYU
	clc
	adc	#3
::drin	sta	r1H
	MoveW	PositionXL,r11
	ldy	ActualCharPointer
	ldx	Pointer,y
::30	cpx	ActualCharacter
	beq	:40
	lda	Text,x
	jsr	GetCharWidth
	clc
	adc	r11L
	sta	r11L
	bcc	:35
	inc	r11H
::35	inx
	bne	:30
::40	CmpW	r11,PositionXR
	bcc	:50
	MoveW	PositionXR,r11
::50	MoveW	r11,stringX
	MoveB	r1H,stringY
	jmp	PromptOn

:RethinkText
; aktualisiert Pointer und TextLength
; Des:	a,x,y,r0-r2
	ldy	#0	;Variablen initialisieren
	sty	r2L
	sty	Pointer
::loop2	LoadB	r2H,0
	MoveW	PositionXL,r0
	ldy	r2L
	ldx	Pointer,y
	dex
::loop	inx
	lda	Text,x
	beq	:ende
	cmp	#$0d
	beq	:15
	cmp	#32
	bne	:05
	stx	r1L
	dec	r2H
::05	jsr	GetCharWidth	;CRSR-Pos aktualisieren
	clc
	adc	r0L
	sta	r0L
	bcc	:10
	inc	r0H
::10	CmpW	r0,PositionXR	;Rechter Rand erreicht
	bcc	:loop
	lda	r2H	;Space vorhanden
	beq	:20
	ldx	r1L	;Space = gew. Position
::15	inx		;n{chstes Zeichen
::20	ldy	r2L	;MaxZeilen erreicht
	cpy	#MaxZeilen-1
	bcs	:search0
	inc	r2L
	txa
	sta	Pointer+1,y
	jmp	:loop2
::search0	lda	Text,x
	beq	:ende
	inx
	bne	:search0
::ende	inc	r2L
	ldy	r2L
	inx
	txa
	sta	TextLength
::30	sta	Pointer,y
	iny
	cpy	#MaxZeilen
	bcc	:30
	rts

:TextPosition
; Par:	r11,r1H: gew}nschte Textposition
; Ret:	ActualCharacter: Zeichenposition
; Des:	a,x,y,r0-r3
	MoveW	PositionXL,r0
	MoveW	r11,r2
	SubW	r0,r2
	lda	r1H
	sec
	sbc	PositionYO
	ldy	#0
::10	sec
	sbc	#10
	bcc	:20
	iny
	bne	:10
::20	sty	r3H
	ldx	Pointer,y
	cpx	TextLength
	bcs	:ende
	stx	r3L
;	inx
;	cpx	Pointer+1,y
;	bne	:initloop
;	lda	Text-1,x
;	cmp	#$0d
;	bne	:initloop
;
;::initloop	ldx	r3L
::loop	lda	Text,x
	beq	:40
	cmp	#$0d
	bne	:nocr
	lda	#"M"
::nocr	jsr	GetCharWidth
	clc
	adc	r0L
	sta	r0L
	bcc	:30
	inc	r0H
::30	MoveW	r0,r1	;Abstand errechnen
	SubW	r11,r1
	txa
	pha
	ldx	#r1L
	jsr	Dabs
	pla
	tax
	inx
	CmpW	r2,r1	;kleinerer Abstand ?
	bcc	:gr|~er
	MoveW	r1,r2	;neuen Abstand merken
	stx	r3L	;Offset merken
::gr|~er	ldy	r3H
	inx
	txa
	dex
	cmp	Pointer+1,y
	bcc	:loop
::40	clc
::50	MoveB	r3L,ActualCharacter
	rts
::ende	ldx	TextLength
	dex
	stx	ActualCharacter
	clc
	rts

:RethinkActChrPtr
; rechnet ActualCharPointer neu aus
	ldy	#0
::05	lda	Pointer,y
	cmp	ActualCharacter
	beq	:20
	bcs	:10
	iny
	cpy	#MaxZeilen
	bcc	:05
::10	dey
::20	sty	ActualCharPointer
	rts

:RefreshLine
; gibt die aktuelle Zeile neu aus
; Des:	a,y
	lda	ActualCharPointer
	asl
	sta	r2L
	asl
	asl
	clc
	adc	r2L
	clc
	adc	PositionYO
	sta	r2L
	bcs	:20
	cmp	PositionYU
	bcs	:20
	clc
	adc	#9
	cmp	PositionYU
	bcc	:01
	lda	PositionYU
::01	sta	r2H
	MoveW	PositionXL,r3
	MoveW	PositionXR,r4
	lda	#0
	jsr	SetPattern
	jsr	Rectangle
	lda	r2L
	clc
	adc	#7
	sta	r1H
	MoveW	PositionXL,r11
	ldy	ActualCharPointer
	lda	Pointer,y
	cmp	TextLength
	bcs	:20
	sta	r15L
	lda	Pointer+1,y
	sta	r15H
::10	ldy	r15L
	lda	Text,y
	beq	:15
	jsr	PutChar
::15	inc	r15L
	lda	r15L
	cmp	r15H
	bcc	:10
::20	rts

:InsertChar
; InsertChar f}gt an der aktuellen Position den Inhalt von keyData ein
; Par:	keyData: einzuf}gendes Zeichen
; Des:	a,y
	ldy	TextLength
	iny
::10	dey
	lda	Text,y
	sta	Text+1,y
	cpy	ActualCharacter
	beq	:20
	bcs	:10
::20	lda	keyData
	sta	Text,y
	rts
:DeleteChar
; DeleteChar nimmt aus dem Text das aktuelle Zeichen heraus
; Des:	a,y
	ldy	ActualCharacter
::10	lda	Text,y
	sta	Text-1,y
	iny
	cpy	TextLength
	bcc	:10
	rts

; Position der EingabeBox :
:PositionYO	b	136
:PositionYU	b	136+39
:PositionXL	w	80
:PositionXR	w	80+160
:MaxTextLength	=	96
:TextLength	b	0
; Offset des Abschlu~byte Null des Textes
:ActualCharacter	b	0
; ActualCharacter enth{lt den Offset des aktuell zu bearbeitenden Zeichens
:ActualCharPointer	b	0
; ActualCharPointer enth{lt die Nummer der aktuellen Zeile
:MaxZeilen	=	5
:Pointer	s	MaxZeilen+1
; Pointer enth{lt f}r jede Zeile einen Offset auf das erste Zeichen der Zeile
; max. 22 Zeilen
