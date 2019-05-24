if .p
	t	"TopSym"
	t	"TopMac(a)"
:NewDataSign	=	$9
:OldDataSign	=	$7
:EndTrack	=	6
endif
	n	"SetProt.mod"
	o	$0300
:Start	jmp	SetCopyProtection
:Track	b	2
:Sektor	b	0
:TrackArea	b	3
:DataSignRW	b	OldDataSign,NewDataSign
:Job	b	0

:LedOn	lda	$1c00
	ora	#%0000 1000
	sta	$1c00
	rts
:LedOff	lda	$1c00
	and	#%1111 0111
	sta	$1c00
	rts
:SetCopyProtection
::nextblock	jsr	LedOn
	MoveB	DataSignRW,$47
	LoadB	Job,$80
	jsr	ReadWriteBlocks
	cmp	#2
	bcs	:joberr
	MoveB	DataSignRW+1,$47
	LoadB	Job,$90
	jsr	ReadWriteBlocks
	cmp	#2
	bcs	:joberr
	jsr	LedOff
	inc	Sektor
	lda	Sektor
	cmp	#8
	bcc	:nextblock
	LoadB	Sektor,0
	inc	Track
	lda	Track
	cmp	$fed7,y
	bcc	:testend
	dey
	sty	TrackArea
::testend	cmp	#EndTrack
	bcc	:nextblock
::end	LoadB	$47,OldDataSign
	rts
::joberr	pha
	jsr	:end
	pla
	inx
	jmp	$e60a

:ReadWriteBlocks	ldx	#0
::readnext	jsr	:setjob
	bcs	:next
	lda	$01,x
	cmp	#2
	bcs	:err
::next	inx
	cpx	#3
	bcc	:readnext
	lda	#1
::err	rts
::setjob	txa
	asl
	tay
	asl
	asl
	clc
	adc	Sektor
	sta	$09,y
	pha
	lda	Track
	sta	$08,y
	pla
	ldy	TrackArea
	cmp	$fed1,y
	bcs	:end
	lda	Job
	sta	$01,x
::waitjob	lda	$01,x
	bmi	:waitjob
	clc
::end	rts
.CopyProtectionEnd
