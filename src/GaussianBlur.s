    AREA    MotionBlur, CODE, READONLY
    IMPORT  main
    IMPORT  getPicAddr
    IMPORT  putPic
    IMPORT  getPicWidth
    IMPORT  getPicHeight
    EXPORT  start
    PRESERVE8

start

        BL      getPicAddr      ; load the start address of the image in R4
        MOV     r4, r0  
        BL      getPicHeight    ; load the height of the image (rows) in R5
        MOV     r5, r0
        BL      getPicWidth     ; load the width of the image (columns) in R6
        MOV     r6, r0

        MOV     r0, r4
        MOV     r1, r6
        MOV     r2, r5
        BL      loadToWorkspace         ; convert image to workspace

        LDR     r0, =0x40600000         ; gaussSD = 3.5f
        MOV     r1, #4                  ; iter = 4
        MOV     r2, r6                  ; width
        MOV     r3, r5                  ; height
        BL      gaussianBlur

        MOV     r0, r4
        MOV     r1, r6
        MOV     r2, r5
        BL      loadFromWorkspace       ; convert image from workspace to memory
        
        BL      putPic                  ; re-display the updated image

stop    B   stop

; gaussianBlur subroutine
;  preforms a number of iterations of linear blurs to image in
;  workspace building up greater approximations of a linear guassian blur
; parapeters:   r0 = radius (gaussSD)
;               r1 = iterations
;               r2 = width
;               r3 = height
; return:       void
gaussianBlur
        STMFD   sp!, {r4-r9, lr}
        
        MOV     r7, r0                  ; gaussSD
        MOV     r6, r2                  ; width
        MOV     r5, r3                  ; height
        MOV     r4, r1                  ; iter (int)
        MOV     r0, r4
        BL      intToFloat
        MOV     r8, r0                  ; iter (float)

        MOV     r0, r7                  ; gaussSD = 5f
        MOV     r1, r8                  ; iter = 3f
        BL      boxFracRadius           ; corresponding radFrac
        STR     r0, [sp, #-4]!
        MOV     r0, r7                  ; gaussSD = 5f
        MOV     r1, r8                  ; iter = 3f
        BL      boxIntRadius            ; corresponding radInt
        STR     r0, [sp, #-4]!

        ; x-axis blur:
        MOV     r9, #0
gBL_wh1
        CMP     r9, r4                  ; for(i = 0; i < iterations; i++)
        BEQ     gBL_wh1_end             ; {
        MOV     r0, #1                  ;   innerStep = 1
        MOV     r1, r6                  ;   outerStep = width
        MOV     r2, r6                  ;   innerInterval = width
        MOV     r3, r5                  ;   outerInterval = height
        BL      linearBlur              ;   x-axis linear blur
        ADD     r9, r9, #1              ; }
        B       gBL_wh1
gBL_wh1_end
        
        ; y-axis blur:
        MOV     r9, #0
gBL_wh2
        CMP     r9, r4                  ; for(i = 0; i < iterations; i++)
        BEQ     gBL_wh2_end             ; {
        MOV     r0, r6                  ;   innerStep = width
        MOV     r1, #1                  ;   outerStep = 1
        MOV     r2, r5                  ;   innerInterval = height
        MOV     r3, r6                  ;   outerInterval = width
        BL      linearBlur              ;   y-axis linear blur
        ADD     r9, r9, #1              ; }
        B       gBL_wh2
gBL_wh2_end
        ADD     sp, sp, #8

        LDMFD   sp!, {r4-r9, pc}

; linearBlur subroutine
;  linear blur of the red green and blue channels of image in workspace
;   x-axis: innerStep = 1, outerStep = width, innerInterval = width, outerInterval = height
;   y-axis: innerStep = width, outerStep = 1, innerInterval = height, outerInterval = width
; parameters:   r0 = innerStep
;               r1 = outerStep
;               r2 = innerInterval
;               r3 = outerInterval
;               [sp] = radiusInt    (float)
;               [sp + 4] = radiusFrac   (float)
; return:       void
linearBlur
        STMFD   sp!, {r12, lr}
        ADD     r12, sp, #8             ; frame pointer
        STMFD   sp!, {r4-r11}
        
        MUL     r11, r2, r3             ;
        MOV     r11, r11, LSL #2        ; = size 
        
        MOV     r4, r0                  ; = innerStep
        MOV     r5, r1                  ; = outerStep
        MOV     r6, r2                  ; = innerInterval
        MOV     r7, r3                  ; = outerInterval
        LDR     r8, =workspace
        LDR     r9, [r12]               ; = rInt
        LDR     r10, [r12, #4]          ; = rFrac

        ; Blur red:
        MOV     r0, r4
        MOV     r1, r5
        MOV     r2, r6
        MOV     r3, r7
        STR     r10, [sp, #-4]!
        STR     r9, [sp, #-4]!
        STR     r8, [sp, #-4]!  
        BL      linearColorBlur
        ADD     sp, sp, #12
        ADD     r8, r8, r11             ; initial += size
        ; Blur green:
        MOV     r0, r4
        MOV     r1, r5
        MOV     r2, r6
        MOV     r3, r7      
        STR     r10, [sp, #-4]!
        STR     r9, [sp, #-4]!
        STR     r8, [sp, #-4]!  
        BL      linearColorBlur     
        ADD     sp, sp, #12
        ADD     r8, r8, r11             ; initial += size
        ; Blur blue:
        MOV     r0, r4
        MOV     r1, r5
        MOV     r2, r6
        MOV     r3, r7
        STR     r10, [sp, #-4]!
        STR     r9, [sp, #-4]!
        STR     r8, [sp, #-4]!  
        BL      linearColorBlur 
        ADD     sp, sp, #12
        
        LDMFD   sp!, {r4-r12,pc}

; linearColorBlur subroutine
;  Applies a linear blur to specified memory region.
;  Used to linear bulr single color channel in workspace
;   x-axis: innerStep = 1, outerStep = width, innerInterval = width, outerInterval = height
;   y-axis: innerStep = width, outerStep = 1, innerInterval = height, outerInterval = width
; parameters:   r0 = innerStep
;               r1 = outerStep
;               r2 = innerInterval
;               r3 = outerInterval
;               [sp + 0] = initial
;               [sp + 4] = radiusInt    (float)
;               [sp + 8] = radiusFrac   (float)
; return:       void
linearColorBlur
        STMFD   sp!, {r12, lr}
        ADD     r12, sp, #8             ; frame pointer
        STMFD   sp!, {r4-r11}
        
        MOV     r4, r0                  ; = innerStep
        MOV     r5, r2                  ; = innerInterval
        MOV     r6, r3                  ; = outerInterval
        LDR     r7, [r12]               ; = initial
        LDR     r8, [r12, #4]           ; = rInt
        LDR     r9, [r12, #8]           ; = rFrac
        MOV     r12, r1                 ; = outerStep
        
        MOV     r11, r7                 ; address = initial
        MOV     r10, #0
lnCoBl_for
        CMP     r10, r6                 ; for (count = 0; count < outer; count++)
        BGE     lnCoBl_for_end          ; {
        MOV     r0, r4
        MOV     r1, r5
        MOV     r2, r11
        MOV     r3, r8
        STR     r9, [sp, #-4]!
        BL      linearSum               ;   sum from [address] to [address + innerInterval]
        ADD     sp, sp, #4
        ADD     r11, r11, r12, LSL #2   ;   address += 4 * outerStep
        ADD     r10, r10, #1            ; }
        B       lnCoBl_for
lnCoBl_for_end

        ; rescaling after sum to find average:
        MOV     r0, r8
        MOV     r1, r9
        BL      fAdd                    ; rFrac + rInt
        MOV     r1, r0
        ADD     r1, r0, #(1 << 23)      ; 2 * (rFrac + rInt)
        LDR     r0, =0x3F800000         ; 1f
        BL      fAdd                    ; 2 * (rFrac + rInt) + 1
        MOV     r1, r0
        LDR     r0, =0x3F800000         ; 1f
        BL      fDiv                    ; 1 / (2 * (rFrac + rInt) + 1)
        MOV     r1, r7                  ; initial
        MUL     r2, r5, r6              ; inner * outer
        BL      scaleMem
        
        LDMFD   sp!, {r4-r12, pc}

; linearSum subroutine;
;  Applies a linear blur to specified memory line
;  Used to blur a givel line in a color channel
; parameters:   r0 = step
;               r1 = interval
;               r2 = initial
;               r3 = radiusInt      (float)
;               [sp] = radiusFrac   (float)
; return:       void
linearSum
        STMFD   sp!, {r12,lr}
        ADD     r12, sp, #8             ; frame pointer
        STMFD   sp!, {r4-r11}
        
        MOV     r4, r0                  ; = step
        MOV     r5, r2                  ; = initial
        SUB     r0, r1, #1              ; interval - 1
        MUL     r6, r4, r0              ; (interval - 1) * step
        ADD     r6, r2, r6, LSL #2      ; = upperBound = initial + 4*(interval - 1)*step
        MOV     r7, r3                  ; = rInt (radiusInt)
        LDR     r8, [r12]               ; = rFrac (radiusFrac)
        
        MOV     r0, #0x3F800000         ; 1f
        MOV     r1, r7                  ;
        BL      fAdd                    ;
        MOV     r7, r0                  ; rInt += 1

        MOV     r0, r7
        BL      floatToInt              ; rInt = toInt(rInt)
        MOV     r7, r0
        
        BL      queueReset              ; initialise queue

    ; find B(0) (seed):
        LDR     r0, [r5]                ; px[0] = initial.load()
        MOV     r9, r0
        MOV     r1, r8
        BL      fMul                    ; ePx[0] = px[0] * rFrac
        MOV     r10, r0
        BL      queueAdd                ; queue.add(ePx[0])
        MOV     r12, r10                ; B[0] = ePx[0]
        
        ; boundary terms:
        MOV     r11, #0
lnSm_for3
        CMP     r11, r7                 ; for(i = 0; i < rInt; i++)
        BEQ     lnSm_for3_end           ; {
        
        MOV     r0, r9
        BL      queueAdd                ;   queue.add(px[0])
        MOV     r1, r12
        BL      fAdd                    ;   B[0] += px[0]
        MOV     r12, r0
        
        MOV     r0, r10                 ;   ePx[0]
        BL      queueAdd                ;   queue.add(ePx[0])
        
        ADD     r11, r11, #1            ; }
        B       lnSm_for3
lnSm_for3_end       

        ; inner terms:
        MOV     r9, #1
lnSm_for1
        CMP     r9, r7                  ; for(i = 1; i <= rInt; i++)
        BGT     lnSm_for1_end           ; {
        MUL     r0, r4, r9              ;   step * i
        ADD     r0, r5, r0, LSL #2      ;   = initial[i] = initial + 4 * step * i
        LDR     r0, [r0]                ;   = px[i]
        BL      queueAdd                ;   queue.add(px[i])
        MOV     r10, r0
        CMP     r9, r7                  ;   if (i < rInt)
        BGE     lnSm_if1                ;   {
        MOV     r1, r12
        BL      fAdd                    ;     B[0] += px[i]
        MOV     r12, r0
lnSm_if1                                ;   }
        MOV     r0, r10
        MOV     r1, r8
        BL      fMul                    ;   ePx[i] = px[i] * rFrac
        BL      queueAdd                ;   queue.add(ePx[i])
        MOV     r11, r0 
        CMP     r9, r7                  ;   if (i == rInt)
        BNE     lnSm_if2                ;   {
        MOV     r1, r12
        BL      fAdd                    ;     B[0] += ePx[i]
        MOV     r12, r0
lnSm_if2                                ;   }
        ADD     r9, r9, #1              ; }
        B       lnSm_for1
lnSm_for1_end
        STR     r12, [r5]               ; store B[0]    (3. check)

    ; find rest of terms:
        MOV     r9, r5                  ; adr = initial
        MUL     r7, r4, r7              ; rInt = rInt * step        
        ; loop precondition:
        ;  1. r10 = px[adr + rInt]
        ;  2. r11 = ePx[adr + rInt]
        ;  3. r12 = B[adr - 1]
        ; frame:
        ;   B[adr] = B[adr - 1] + ePx[adr + rInt] + px[adr - 1 + rInt] - ePx[adr - 1 + rInt]
        ;            - ePx[adr - rInt] - px[adr + 1 - rInt] + ePx[adr + 1 - rInt]
lnSm_for2
        ADD     r9, r9, r4, LSL #2      ; adr += 4 * step
        CMP     r9, r6                  ; for (adr = 1; adr <= upperBound; i++)
        BGT     lnSm_for2_end           ; {
        
        ; previous loop terms:
        MOV     r0, r12
        MOV     r1, r10
        BL      fAdd                    ;   B[adr] = B[adr - 1] + px[adr - 1 + rInt]
        MOV     r1, r11
        BL      fSub                    ;   B[adr] -= ePx[adr - 1 + rInt]
        MOV     r12, r0
        
        ; get address of greates pixel in frame:
        ADD     r0, r9, r7, LSL #2      ;   pxAdr = adr + rInt
            ; check for boundary case:
        CMP     r0, r6                  ;   if (pxAdr > upperBound)
        MOVGT   r0, r6                  ;     pxAdr = upperBound
        
        ; this loop terms:
        LDR     r10, [r0]               ;   px[pxAdr]   (1. check)
        MOV     r0, r10
        BL      queueAdd                ;   queue.add(px[adr + rInt])
        MOV     r1, r8
        BL      fMul                    ;   ePx[pxAdr] = rFrac * px[pxAdr]
        MOV     r11, r0                 ;   (2. check)
        BL      queueAdd                ;   queueAdd(ePx[pxAdr])
        MOV     r1, r12
        BL      fAdd                    ;   B[adr] += ePx[pxAdr]
        MOV     r12, r0
        
        ; queue terms:
        BL      queueRemove             ;   ePx[adr - rInt] = queue.remove()
        MOV     r1, r0
        MOV     r0, r12
        BL      fSub                    ;   B[adr] -= ePx[adr - rInt]
        MOV     r12, r0
        BL      queueRemove             ;   px[adr + 1 - rInt] = queue.remove()
        MOV     r1, r0
        MOV     r0, r12
        BL      fSub                    ;   B[adr] -= px[adr + 1 - rInt]
        MOV     r12, r0
        BL      queuePeak               ;   ePx[adr + 1 - rInt] = queue.peak()
        MOV     r1, r12
        BL      fAdd                    ;   B[adr] += ePx[adr + 1 - rInt]
        MOV     r12, r0                 ;   (3. check)
        
        STR     r12, [r9]               ;   store B[adr]

        B       lnSm_for2               ; }
lnSm_for2_end
        
        LDMFD   sp!, {r4-r12,pc}

; scaleMem subroutine:
; parameter:    r0 = scalar
;               r1 = startAddress
;               r2 = length
; return:       void
scaleMem
        STMFD   sp!, {r4-r6,lr}
        
        MOV     r4, r0                  ; = scalar
        MOV     r5, r1                  ; = address
        ADD     r6, r1, r2, LSL #2      ; = upperBound = address + 4 * length
        
sclWkspc_wh     
        CMP     r5, r6                  ; while (address < upperBound)
        BEQ     sclWkspc_wh_end         ; {
        LDR     r0, [r5]                ;   value = address.load()
        MOV     r1, r4                  ;   = scalar
        BL      fMul                    ;   scaled = scalar * value
        STR     r0, [r5], #4            ;   address.store(scaled)
        B       sclWkspc_wh             ; }
sclWkspc_wh_end
        
        LDMFD   sp!, {r4-r6,pc}

; boxFracRadius
;  Calculates fractional part of boxRadius nessisary to produce
;  an approximate gaussian blur of specified standard deviation in
;  specified number of iterations
; parameter:    r0 = gausSD (radius of target blur)
;               r1 = iter (number of box convolutions)
; return        r0 = boxRadius.fractionalPart
boxFracRadius
        STMFD   sp!, {r4-r12,lr}
        MOV     r4, r0                  ; = gausSD
        MOV     r5, r1                  ; = iter
        
        ; terms:
        BL      boxIntRadius
        MOV     r6, r0                  ; radInt = boxRadius.integerPart

        ADD     r0, r6, #(1 << 23)      ; 2 * radInt
        MOV     r1, #0x3F800000         ; = 1f
        BL      fAdd
        MOV     r7, r0                  ; 2*radInt + 1

        MOV     r0, r6
        MOV     r1, #0x3F800000         ; = 1f
        BL      fAdd
        MOV     r8, r0                  ; = radInt + 1
        
        MOV     r0, r4
        MOV     r1, r4
        BL      fMul
        MOV     r9, r0                  ; = gausSD^2

        MOV     r0, r5
        MOV     r1, r8
        BL      fMul
        MOV     r10, r0                 ;  = iter * (radInt + 1)

        ; numerator =
        MOV     r1, r6
        BL      fMul                    ;
        MOV     r11, r0                 ; = iter * (radInt + 1) * radInt
        
        LDR     r0, =0x40400000         ; = 3f
        MOV     r1, r9
        BL      fMul                    ; = 3 * gausSD^2
        MOV     r1, r11
        BL      fSub                    ; 3 * gausSD^2 - (iter * (radInt + 1) * radInt)
        MOV     r1, r7
        BL      fMul
        MOV     r11, r0                 ; = (2*radInt + 1)*(3*gausSD^2 - 3(iter*radInt*(radInt + 1)))
        
        ; denominator = 
        MOV     r0, r10
        MOV     r1, r8
        BL      fMul                    ; iter * (radInt + 1)^2
        MOV     r1, r9
        BL      fSub                    ; iter * (radInt + 1)^2 - gausSD^2
        LDR     r1, =0x40C00000         ; = 6f
        BL      fMul                    ; 6 * (iter * (radInt + 1)^2 - gausSD^2)
        MOV     r12, r0
        
        ; quotient = 
        MOV     r0, r11
        MOV     r1, r12
        BL      fDiv                    ; return (numerator / denominator)
        
        LDMFD   sp!, {r4-r12,pc}    ;HERE

; boxIntRadius subroutine
;  Calculates integer part of boxRadius nessisary to produce
;  an approximate gaussian blur of specified standard deviation in
;  specified number of iterations
; parameter:    r0 = gausSD (radius of target blur)
;               r1 = iter (number of box convolutions)
; return        r0 = boxRadius.integerPart
boxIntRadius
        STMFD   sp!, {r4-r5,lr}
        MOV     r4, r0
        MOV     r5, r1
        
        MOV     r1, r4
        BL      fMul                    ; gausSD^2
        LDR     r1, =0x41400000         ; = 12f
        BL      fMul                    ; 12 * gausSD^2
        MOV     r1, r5
        BL      fDiv                    ; 12 * gausSD^2 / iter
        MOV     r1, #0x3F800000         ; = 1f
        BL      fAdd                    ; 12 * gausSD^2 / iter + 1
        BL      fSqrtPrecise            ; diameter = sqrt(12 * gausSD^2 / iter + 1)
        MOV     r1, #0x3F800000         ; = 1f
        BL      fSub                    ; diameter - 1
        SUB     r0, r0, #(1 << 23)      ; (diameter - 1) / 2
        BL      floor                   ; return floor((diameter - 1) / 2)
        
        LDMFD   sp!, {r4-r5,pc}

;-------------- WORKSPACE --------------;

; loadToWorkspace subroutine
;  Convert image from givel region of memory into
;  separate red, green and blue channels in workspace
;  with values in floating point representation
; parameters:   r0 = source address
;               r1 = image width
;               r2 = image height
; return:       void
loadToWorkspace
        STMFD   sp!, {r4-r9,lr}
        
        MUL     r1, r2, r1              ; pixelCount = width * height
        MOV     r1, r1, LSL #2          ; pixelsWidth = 4 * pixelCount
        LDR     r4, =workspace          ; = wkspcRed (= workspace)
        ADD     r5, r4, r1              ; = wkspcGreen (= workspace + pixelsWidth)
        ADD     r6, r5, r1              ; = wkspcBlue (= workspace + 2*pixelsWidth)
        MOV     r7, r0                  ; = src
        ADD     r8, r7, r1              ; = src.upperBound (= src + pixelsWidth)

ldToWkspc_wh
        CMP     r7, r8                  ; while (src < src.upperBound)
        BEQ     ldToWkspc_wh_end        ; {
        LDR     r9, [r7], #4            ;   load pixel from src image
        
        MOV     r0, r9, LSR #16
        AND     r0, r0, #0x000000FF     ;   red (byte)
        BL      intToFloat              ;   red (float)
        STR     r0, [r4], #4            ;   wkspcRed.add(red)

        MOV     r0, r9, LSR #8
        AND     r0, r0, #0x000000FF     ;   green (byte)
        BL      intToFloat              ;   green (float)
        STR     r0, [r5], #4            ;   wkspcGreen.add(green)

        AND     r0, r9, #0x000000FF     ;   blue (byte)
        BL      intToFloat              ;   blue (float)
        STR     r0, [r6], #4            ;   wkspcBlue.add(blue)
        B       ldToWkspc_wh            ; }
ldToWkspc_wh_end

        LDM     sp!, {r4-r9,pc}

; loadFromWorkspace subroutine
;  Combines seperate color channels in workspace into
;  rgb pixels and stores in destination address
; parameters:   r0 = destination address
;               r1 = image width
;               r2 = image height
; return:       void
loadFromWorkspace
        STMFD   sp!, {r4-r9,lr}
        
        MUL     r1, r2, r1              ; pixelCount = width * height
        MOV     r1, r1, LSL #2          ; pixelsWidth = 4 * pixelCount
        LDR     r4, =workspace          ; = wkspcRed (= workspace)
        ADD     r5, r4, r1              ; = wkspcGreen (= workspace + pixelsWidth)
        ADD     r6, r5, r1              ; = wkspcBlue (= workspace + 2*pixelsWidth)
        MOV     r7, r0                  ; = dest
        ADD     r8, r7, r1              ; = dest.upperBound (= src + pixelsWidth)

ldFrmWkspc_wh
        CMP     r7, r8                  ; while (dest < dest.upperBound)
        BEQ     ldFrmWkspc_wh_end       ; {
        MOV     r9, #0                  ;   pixel = 0

        LDR     r0, [r4], #4            ;   red (float) = wkspcRed.get()
        BL      floatToInt
        CMP     r0, #0xFF               ;   if (red > 255)
        MOVGT   r0, #0xFF               ;     red = 255
        CMP     r0, #0                  ;   if (red < 0)
        MOVLT   r0, #0                  ;     red = 0
        ADD     r9, r9, r0, LSL #16     ;   pixel.red = red

        LDR     r0, [r5], #4            ;   green (float) = wkspcGreen.get()
        BL      floatToInt
        CMP     r0, #0xFF               ;   if (green > 255)
        MOVGT   r0, #0xFF               ;     green = 255
        CMP     r0, #0                  ;   if (green < 0)
        MOVLT   r0, #0                  ;     green = 0
        ADD     r9, r9, r0, LSL #8      ;   pixel.green = green


        LDR     r0, [r6], #4            ;   blue (float) = wkspcBlue.add(blue)
        BL      floatToInt
;       BIC     r0, r9, #0x000000FF     ;   blue (byte)
        CMP     r0, #0xFF               ;   if (blue > 255)
        MOVGT   r0, #0xFF               ;     blue = 255
        CMP     r0, #0                  ;   if (blue < 0)
        MOVLT   r0, #0                  ;     blue = 0
        ADD     r9, r9, r0              ;   pixel.blue = blue

        STR     r9, [r7], #4            ;   load pixel from src image

        B       ldFrmWkspc_wh           ; }
ldFrmWkspc_wh_end

        LDM     sp!, {r4-r9,pc}


;----------------- QUEUE -----------------;


; queueAdd subroutine
;  Add word value to back of queue
;  Also returns the added value
; parameters:   r0 = word
; return:       r0 = word
queueAdd
        LDR     r1, =qBack
        LDR     r2, [r1]
        STR     r0, [r2]                ; queue.add(word)
        ADD     r2, r2, #4
        BIC     r2, r2, #0xFF00         ; qBack += 4 (mod byte)
        STR     r2, [r1]                ; update qBack
        BX      lr

; queueRemove subroutine
;  Remove and return word value at front of queue 
; parameters:   void
; return:       r0 = front
queueRemove
        LDR     r2, =qFront
        LDR     r1, [r2]                ; = qFront address
        LDR     r0, [r1]                ; = front
        ADD     r1, r1, #4
        BIC     r1, r1, #0xFF00         ; qFront += 4 (mod byte)
        STR     r1, [r2]                ; update qFront
        BX      lr

; queuePeak subroutine
;  Return word value at front of queue
; parameters:   void
; return:       r0 = front
queuePeak
        LDR     r0, =qFront
        LDR     r0, [r0]
        LDR     r0, [r0]                ; return queue.front(value)         
        BX      lr

; queueReset subroutine
;  Reset queue to defaul empty state
; parameters:   void
; return:       void
queueReset
        LDR     r0, =queue              ; = queue memory block start
        LDR     r1, =qFront
        LDR     r2, =qBack
        STR     r0, [r1]                ; qBack points to queue memory block start
        STR     r0, [r2]                ; qFront points to queue memory block start
        BX      lr
        
;-------------- FLOATING POINT ARITHMETIC --------------;


; fSqrtPrecise subroutine
;  Calculates square root of float value within
;  the accuracy prescribed by floating point
; parameters:   r0 = float
; return:       r0 = sqrt(float)
fSqrtPrecise
        STMFD   sp!, {r4,lr}
        MOV     r4, r0      

        BL      fSqrt
        MOV     r1, r4
        BL      fSqrtRefine
        MOV     r1, r4
        BL      fSqrtRefine
        
        LDMFD   sp!, {r4,pc}

; fSqrt subroutine
;  Calculates square too of float value within
;  approximatly 4 precent
; parameters:   r0 = float
; return:       r0 = sqrt(float)
fSqrt
        LDR     r1, =0x1FBD1DF5
        ADD     r0, r1, r0, LSR #1
        BX      lr
        
; fSqrtRefine:
;  Carries out newton rapson method on approximation
;  of square root returning an improved approximation
; parameters:   r0 = aprx_0
;               r1 = num
; return:       r0 = aprx_1
fSqrtRefine
        STMFD   sp!, {r4-r6,lr}
    
        MOV     r4, r0                  ; aprx_0
        MOV     r5, r1                  ; num

        MOV     r0, r5
        MOV     r1, r4
        BL      fDiv
        MOV     r6, r0                  ; num / aprx_0
        
        MOV     r0, r4
        MOV     r1, r6
        BL      fAdd                    ; aprx_0 + num / aprx_0
        SUB     r0, r0, #(1 << 23)      ; aprx_1 = (aprx_0 + num / aprx_0) / 2
        
        LDMFD   sp!, {r4-r6,pc}
        
; fMulFast subroutine
;  Approximates op_1 multiplied by op_2
;  within a few precent
; parameters:   r0 = op_1   (float)
;               r1 = op_2   (float)
; return:       r0 = op_1 * op_2    (float)
fMulFast
        LDR     r2, =0x3F7A3BEA
        ADD     r0, r0, r1
        SUB     r0, r0, r2
        BX      lr
        
; fDivFast subroutine
;  Approximates op_1 divided by op_2
;  within a few precent
; parameters:   r0 = op_1   (float)
;               r1 = op_2   (float)
; return:       r0 = op_1 / op_2    (float)
fDivFast
        LDR     r2, =0x3F7A3BEA
        SUB     r0, r0, r1
        ADD     r0, r0, r2
        BX      lr

; floor subrouting
;  Rounds floating point value towards 0
; parameters:   r0 = float
; return:       r0 = floor(float)
floor
        STMFD   sp!, {r4,lr}
        MOV     r4, r0
        
        BL      getExp
        SUB     r0, #127                ; exponent - bias
        CMP     r0, #0                  ; if (exponent < 0)
        MOVLT   r0, #0                  ; return 0
        BLT     floor_end
        CMP     r0, #23                 ; if (exponent >= 23)
        MOVGE   r0, r4                  ; return float
        BGE     floor_end
        RSB     r1, r0, #23             ; trunc = 23 - exponent
        MOV     r4, r4, LSR r1
        MOV     r0, r4, LSL r1          ; return float with lower trunc bits cleared
        
floor_end       
        LDMFD   sp!, {r4,pc}

; floatToInt subroutine
;  Converts floating point representation to integer 
;  representation rounding towards 0 in loss of precision
; parameters:   r0 = float
; return:       r0 = int
floatToInt
        STMFD   sp!, {r4-r5,lr}
        
        MOV     r4, r0
        
        BL      getSignificand
        MOV     r5, r0                  ; value = mantissa (+ leading 1)
        
        MOV     r0, r4
        BL      getExp
        SUB     r0, r0, #127            ; exponent -= bias
        
        SUBS    r0, r0, #23             ; if (value.posDif < 0) {
        RSBLT   r0, r0, #0              ;   value.posDif * -1
        MOVLT   r5, r5, LSR r0          ;   int = value >> value.posDif
        MOVGT   r5, r5, LSL r0          ; } else int = value << value.posDif        
        
        TST     r4, #0x80000000         ; if (float < 0)
        RSBNE   r5, r5, #0              ;   int = -int
        
        MOV     r0, r5                  ; return int
        
        LDMFD   sp!, {r4-r5,pc}

; intToFloat subroutine
;  Converts integer value to floating point representation
; parameters:   r0 = int
; return:       r0 = float
intToFloat
        STMFD   sp!, {r4-r5, lr}
        
        MOV     r4, r0
        
        CMP     r0, #0                  ; if (int == 0)
        BEQ     intToFloat_end          ;   return 0
                
        ANDS    r5, r4, #0x80000000     ; float.sign = int.sign
        RSBNE   r4, r4, #0              ; if (int negative) value = -int
        MOV     r0, r4
        BL      msOne
        SUB     r0, r0, #1              ; index of leading 1
        ADD     r1, r0, #127            ; exponent += bias
        ADD     r5, r5, r1, LSL #23     ; float = float + exponent << 23
        
        
        SUBS    r0, r0, #23             ; if (value.posDif < 0) {
        RSBLT   r0, r0, #0              ;   value.posDif * -1
        MOVLT   r4, r4, LSL r0          ;   value = value << value.posDif
        MOVGT   r4, r4, LSR r0          ; } else value = value >> value.posDif
        
        SUB     r4, r4, #(1 << 23)      ; mantissa = value - leading 1
        
        ADD     r0, r4, r5              ; return float + mantissa
        
intToFloat_end      
        LDMFD   sp!, {r4-r5, pc}

; fMul subroutine
;   Preforms floating point multiplication on op_1 and op_2
; parameters:   r0 = op1 (float)
;               r1 = op2 (float)
; return:       r0 = op1 * op2 (float)
fMul
        STMFD   sp!, {r4-r8,lr}
        
        MOV     r4, r0
        MOV     r5, r1
        
        ; Check if eithe op is 0:
        EOR     r6, r4, r5              ; 
        AND     r6, #0x80000000         ; signed = op_1.sign * op_2.sign
        
        BICS    r0, r4, #0x80000000     ; if op1 == -0 OR 0
        MOVEQ   r0, r6                  ;
        BEQ     fMul_end                ;   return (signed) 0

        BICS    r0, r5, #0x80000000     ; if op2 == -0 OR 0
        MOVEQ   r0, r6                  ;
        BEQ     fMul_end                ;   return (signed) 0
        
        
        MOV     r0, r4
        BL      getSignificand
        MOV     r6, r0

        MOV     r0, r5
        BL      getSignificand
        MOV     r7, r0
        
        UMULL   r0, r1, r6, r7
        MOV     r0, r0, LSR #23
        ADD     r8, r0, r1, ROR #23     ; mantissa = (m_op1 + 1) * (m_op2 + 1)
        
        EOR     r0, r4, r5
        TST     r0, #0x80000000
        RSBNE   r8, r8, #0              ; value = -mantissa
        
        MOV     r0, r4
        BL      getExp
        MOV     r6, r0                  ; op1.exp
        MOV     r0, r5
        BL      getExp
        MOV     r7, r0                  ; op2.exp
        
        ADD     r6, r6, r7              ; exponent = op1.exp + op2.exp  (bias double counted)
        SUB     r6, r6, #127            ; exponent -= bias
        
        MOV     r0, r8
        MOV     r1, r6
        BL      makeFloat
fMul_end        
        LDMFD   sp!, {r4-r8,pc}

; fDiv subroutine
;  Preforms floating point division on op_1 and op_2
; parameters:   r0 = op1 (float)
;               r1 = op2 (float)
; return:       r0 = quotient (float)
fDiv
        STMFD   sp!, {r4-r8,lr}
        MOV     r4, r0
        MOV     r5, r1

;------ Check if op_1 OR op_2 is 0: ----;
        EOR     r0, r4, r5              ; 
        AND     r6, r0, #0x80000000     ; quotient.sign = op_1.sign * op_2.sign
        BICS    r0, r4, #0x80000000     ; if op1 == -0 OR 0
        MOVEQ   r0, r6                  ;
        BEQ     fDiv_end                ;   return (quotient.sign) 0
        BICS    r0, r5, #0x80000000     ; if op2 == -0 OR 0
        BNE     fDiv_if                 ; {
        LDR     r0, =0x7f800000         ;   = Infinity 
        ADD     r0, r6, r0              ;
        B       fDiv_end                ;   return (quotient.sign) Infinity
fDiv_if ;-------------------------------; }
        
        MOV     r0, r4
        BL      getExp
        MOV     r7, r0                  ; op1.exp
        MOV     r0, r5
        BL      getExp
        MOV     r8, r0                  ; op2.exp
        SUB     r7, r7, r8              ; quotient.exp = op1.exp - op2.exp  (bias cancelled)
        ADD     r7, r7, #127            ; quotient.exp += bias
        ADD     r8, r7, r6              ; quotient = quotient.sign + quotient.exp
        
        MOV     r0, r4
        BL      getSignificand
        MOV     r6, r0                  ; op_1.sig
        MOV     r0, r5
        BL      getSignificand
        MOV     r7, r0                  ; op_2.sig
        CMP     r6, r7                  ; if (op_1.sig < op_2.sig)
        SUBLT   r8, r8, #1              ;   quotient.exp -= 1   (adjust for fDivAlg oneOver)
        
        MOV     r0, r6
        MOV     r1, r7
        BL      fDivAlg                 ; quotient.sig = divAlg(op_1.sig, op_2.sig)
        SUB     r0, r0, #(1 << 23)      ; quotient.mantissa = quotient.sig - leading 1
        
        ADD     r0, r0, r8, LSL #23     ; quotient = quot.sign + quot.exp << 23 + quot.mantissa
fDiv_end
        LDMFD   sp!, {r4-r8,pc}

; fDivAlg subroutine
;  Division algorithm for floating point division
; parameters:   r0 = numerator
;               r1 = denominator
; return:       r0 = quotient (mantissa)
fDivAlg
        MOV     r2, #0                  ; quotient = 0
fDivAlg_for
        TST     r2, #(1 << 23)          ; while (leading 1 not on bit 23)
        BNE     fDivAlg_eFor            ; {
        MOV     r2, r2, LSL #1          ;   quotient << 1
        CMP     r0, r1                  ;   if (numerator >= denominator)
        BLT     fDivAlg_if              ;   {
        ADD     r2, r2, #1              ;     quotient += 1
        SUB     r0, r0, r1              ;     numerator -= denominator
fDivAlg_if                              ;   }
        MOV     r0, r0, LSL #1          ;   numerator << 1
        B       fDivAlg_for             ; }
fDivAlg_eFor
        MOV     r0, r2                  ; return quotient
        BX      lr

; fAdd subroutine
;  Preforms floating point addition on op_1 and op_2
; parameters:   r0 = op_1 (float) (augend)
;               r1 = op_2 (float) (addend)
; return:       r0 = op_1 + op_2 (float)
fAdd
        STMFD   sp!, {r4-r8,lr}
        MOV     r4, r0
        MOV     r5, r1
        
        ; Check if either op is 0 or negation of eachother:
        BICS    r0, r4, #0x80000000     ; if (op_1 == -0 OR 0)
        MOVEQ   r0, r5                  ;   return op2
        BEQ     fAdd_end                ;
        BICS    r1, r5, #0x80000000     ; if (op_2 == -0 OR 0)
        MOVEQ   r0, r4                  ;   return op_1
        BEQ     fAdd_end                ;
        EOR     r0, r4, #0x80000000     ; = -op1
        CMP     r0, r5                  ; if (-op_1 = op_2)
        MOVEQ   r0, #0                  ;   return 0
        BEQ     fAdd_end                ; 
        
        MOV     r0, r4
        BL      getExp
        MOV     r6, r0
    
        MOV     r0, r5
        BL      getExp
        MOV     r7, r0
    
    ; correct order and find exponent difference:
        CMP     r6, r7                  ; if (op1.exp < op2.exp)
        BGE     correctOrder            ; {
        MOV     r0, r4                  ;   
        MOV     r4, r5                  ;   swap(op_1, op_2)
        MOV     r5, r0                  ;   
        SUB     r8, r7, r6              ;   expDif = op2.exp - op1.exp
correctOrder                            ; } else
        SUBGE   r8, r6, r7              ;   expDif = op1.exp - op2.exp

        MOV     r0, r4
        BL      getSignificand
        TST     r4, #0x80000000         ; if (float is negative)
        RSBNE   r0, r0, #0              ;   2sComp = -2sComp
        MOV     r6, r0

        MOV     r0, r5
        BL      getSignificand
        TST     r5, #0x80000000         ; if (float is negative)
        RSBNE   r0, r0, #0              ;   2sComp = -2sComp
        MOV     r7, r0, ASR r8          ; match exponents

        ADD     r5, r6, r7              ; value
    
        MOV     r0, r4
        BL      getExp                  ; exponenet of resulting term (not corrected)
        MOV     r1, r0
        MOV     r0, r5
        BL      makeFloat
fAdd_end    
        LDMFD   sp!, {r4-r8,pc}

; fSub subroutine
;  Preforms floating point subtraction on op_1 and op_2
; parameters:   r0 = op1 (float)
;               r1 = op2 (float)
; return:       r0 = op1 + op2 (float)
fSub
        STMFD   sp!, {lr}
        EOR     r1, r1, #0x80000000     ; negate r1
        BL      fAdd                    ; return r0 + (-r1)
        LDMFD   sp!, {pc}
        
; getExp subroutine
;  returns exponent of floating point representation
; paramters:    r0 = float
; return:       r0 = exponent
getExp
        BIC     r0, r0, #0x80000000
        MOV     r0, r0, LSR #23
        BX      lr

; getSignificand subroutine
;  returns (mantissa + 1) of floating point representation
; paramters:    r0 = float
; return:       r0 = mantissa + (1 << 23)
getSignificand
    MOV     r1, r0, LSL #9              ; mantissa
    MOV     r1, r1, LSR #9              ; /
    ADD     r0, r1, #(1 << 23)          ; significand = 1 + mantissa
    BX      lr

; makeFloat
;  Returns floating point value from given exponent
;  and 2s complement value
; parameters:   r0 = value
;               r1 = exponent
; return:       r0 = float
makeFloat
        STMFD   sp!, {r4-r7,lr}
        
        MOV     r4, r0                  ; = value
        MOV     r5, r1                  ; = exponent
    
        CMP     r4, #0                  ; if (value == 0)
        BEQ     makeFloat_end           ;   return 0
        BGE     makeFloat_if            ; else if (value < 0) {
        RSB     r4, r4, #0              ;   value = -value
        MOV     r6, #0x80000000         ;   float = -0
makeFloat_if                            ; } else
        MOVGE   r6, #0                  ;   float = 0
    
        MOV     r0, r4
        BL      msOne
        SUB     r7, r0, #24             ; difference from correct position
        ADD     r5, r5, r7              ; exponent corrected
        
        CMP     r7, #0                  ; if (expDif > 0)
        MOVGT   r4, r4, LSR r7          ;   value = value >> expDiff
        RSBLT   r7, r7, #0              ; if (expDif < 0) {
        MOVLT   r4, r4, LSL r7          ;   value = value << (-expDif)
        SUB     r4, r4, #(1 << 23)      ; mantissa = value - leadingBit
        
        ADD     r6, r6, r4              ; float = float + mantissa
        ADD     r0, r6, r5, LSL #23     ; float = float + exponenet << 23
makeFloat_end   
        LDMFD   sp!, {r4-r7,pc}

;
; msOne subroutine
; Returns one greater than index of most significant 1.
; parameters:  r0 = binary value
; return:      r0 = position of most significant 1  
;
msOne
        CMP     r0, #0                  ; if (reg = 0)
        BXEQ    lr                      ;   return 0
        MOV     r1, #1                  ; msOne = 1
        LDR     r2, =0xFFFF0000
        TST     r0, r2                  ; if (top 16 bits contain a 1)
        MOVNE   r0, r0, LSR #16         ;   reg >> 16
        ADDNE   r1, r1, #16             ;   msOne += 16
        TST     r0, #0x0000FF00         ; if (next top 8 bits contain 1)
        MOVNE   r0, r0, LSR #8          ;   reg >> 8
        ADDNE   r1, r1, #8              ;   msOne += 8
        TST     r0, #0x000000F0         ; if (next top 4 bits contain 1)
        MOVNE   r0, r0, LSR #4          ;   reg >> 4
        ADDNE   r1, r1, #4              ;   msOne += 4
        TST     r0, #0x0000000C         ; if (next top 2 bits contain 1)
        MOVNE   r0, r0, LSR #2          ;   reg >> 2
        ADDNE   r1, r1, #2              ;   msOne += 2
        TST     r0, #0x00000002         ; if (next top bit is 1)
        MOVNE   r0, r0, LSR #1          ;   reg >> 1
        ADDNE   r1, r1, #1              ;   msOne += 1
        MOV     r0, r1                  ; return msOne
        BX      lr



;-------------- MEMORY --------------;

queue       EQU     0xA1800000,     CODE32
qFront      EQU     0xA1800100,     CODE32  ; full
qBack       EQU     0xA1800104,     CODE32  ; empty
newImage    EQU     0xA1800800,     CODE32  ; to store intermediate image step
workspace   EQU     0xA1880000,     CODE32  ; to store floating point image

    END
