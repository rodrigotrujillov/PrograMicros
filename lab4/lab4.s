; Archivo: lab4.s
; Dispositivo: PIC16F887
; Autor: Rodrigo Esteban Trujillo Vásquez
; Compilador: pic-as 
;	   
; Creado: 16 febrero, 2023
; Última modificación: 21 febrero, 2023
PROCESSOR 16F887
#include <xc.inc>

; CONFIGURACIÓN 1
  CONFIG  FOSC = INTRC_NOCLKOUT // Oscilador interno sin salidas
  CONFIG  WDTE = OFF            // WDT disabled (reinicio repetitivo del pic)
  CONFIG  PWRTE = OFF            // PWRT enabled (reinicio repetitivo del pic)
  CONFIG  MCLRE = OFF           // El pin de MCLR se utiliza como I/O
  CONFIG  CP = OFF              // Sin protección de código
  CONFIG  CPD = OFF             // Sin protección de datos
  CONFIG  BOREN = OFF           // Sin reinicio cuando el voltaje de alimentación baja de 4V
  CONFIG  IESO = OFF            // Reinicio sin cambio de reloj de interno a externo 
  CONFIG  FCMEN = OFF           // Cambio de reloj externo a interno en caso de fallo
  CONFIG  LVP = OFF              // Programación en bajo voltaje permitida

; CONFIGURACIÓN 2
  CONFIG  BOR4V = BOR40V        // Reinicio abajo de 4V, (BOR21V=2.1V)
  CONFIG  WRT = OFF             // Protección de autoescritura por el programa desactivado
  
;----------------- MACRO --------------------------------
rein_tmr0 MACRO
   
    banksel PORTA
    movlw 178			; tiempo = 4 * (1/fosc)(256-tmr0)(prescaler)
    movwf TMR0			
    bcf T0IF    
    ENDM
    
; ---------------------------------------------------------
    
UP EQU 6
DOWN EQU 7

PSECT udata_bank0
    cont: DS 2
    cont_unidades: DS 2
    cont_decenas: DS 2
    
PSECT udata_shr
    W_TEMP: DS 1
    STATUS_TEMP: DS 1
    
;------------------ reset vector -----------------
    
PSECT resVect, class=CODE, abs, delta=2
ORG 00h
resetVec:
    PAGESEL main
    goto main
    
;------------------ interrupt vector -------------
    
PSECT intVect, class=CODE, abs, delta=2
ORG 04h
    
; durante una interrupcion solamente los valores del PC se guardan, los valores de
; W y del STATUS REGISTER deben de guardarse manualmente.
; en resumen se realiza lo siguiente:
;   - Guardan el registro W
;   - Guardan el registro STATUS
;   - Ejecutar el codigo ISR (interrupcion)
;   - Restaurar el registro STATUS
;   - Restaurar el registro W
    
push:
    movwf   W_TEMP			; guardamos W y STATUS
    swapf   STATUS, W			; copiamos W a W_TEMP
					; intercambiamos STATUS para que se guarde en W
					; se usa SWAPF para no afectar las banderas 
    movwf   STATUS_TEMP			; guardamos STATUS EN STATUS_TEMP
    
isr:
    btfsc   RBIF			; 0 =  se salta subrutina int_iocb
					; 1 = llama a la subrutina int_iocb
    call    int_iocb
	
    btfsc   T0IF			; 0 = se salta subrutina int_tmr0
					; 1 = llama a la subrutina int_tmr0
    call    int_tmr0
    
pop:
    swapf   STATUS_TEMP, W		; restauramos W y STATUS
					; cambiamos el STATUS_TEMP a W
    movwf   STATUS			; mueve W a STATUS
    swapf   W_TEMP, F			; cambia W_TEMP
    swapf   W_TEMP, W			; cambia W_TEMP en W
    retfie				; return from interrupt
 
;------------------------ interrupciones- -------------------------------------
    
int_iocb:
    banksel PORTA		    
    btfss   PORTB, UP			; 0 = incrementa PORTA
					; 1 = se salta INCF PORTA
    incf    PORTA
    btfss   PORTB, DOWN			; 0 = decrementa PORTA
    decf    PORTA			; 1 =  se salta DECF PORTB
    bcf	    RBIF			; se limpia la bandera
    return
    
int_tmr0:
    rein_tmr0				; 20 ms
    incf    cont			; incrementamos cont
    movf    cont, W			; lo movemos cont a W
    sublw   50				; 20 ms lo hace 50 veces
    btfss   ZERO			; si W - 50 = 0 --> seguimos con la subrutina
					; si W - 50 =/= 0 -> sigue verificando
    goto    return_to			; 1000 ms / 1 s
    clrf    cont			; se limpia el contador
    incf    cont_unidades		; incrementamos el contador de unidades de segundo
    movf    cont_unidades, W		; cont_unidades lo movemos a W
    call    tabla			; llamamos a la tabla
    movwf   PORTD			; el valor de la tabla se refleja en PORTD

    movf    cont_unidades, W		; se mueve el contador de unidades de segundo a W
    sublw   10				; W - 10
    btfsc   STATUS, 2			; STATUS bit 2, revisa el resultado de una operacion
					; si el resultado es 0 --> 1
					; si el resultado no es 0 --> 0 
					; da 0 la operacion?
    call    inc_decenas			; si, entonces incremente las decenas de segundo
    
    movf    cont_decenas, W		; mueve las decenas de segundo a W
    call    tabla			; llama a la tabla
    movwf   PORTC			; el valor de la tabla se tira a PORTC
    
    return
    
inc_decenas:
    incf    cont_decenas		; incrementa el contador de decenas
    clrf    cont_unidades		; limpia el contador de unidades
    movf    cont_unidades, W		; mueve el contador de unidades a W
    call    tabla			; llama a la tabla
    movwf   PORTD			; mueve el valor al puerto D
    
    movf    cont_decenas, W		; mueve el valor de decenas a W
    sublw   6				; W - 6
    btfsc   STATUS, 2			; el resultado es 0?	
    clrf    cont_decenas		; Si, limpia el conteo de decenas
    return
    
return_to:
    return

    
;-------------------------- codigo principal --------------
PSECT code, delta=2, abs
ORG 100h				; posicion de nuestro codigo
 
tabla:
    clrf    PCLATH			; se limpia el registro de PCLATH
    bsf	    PCLATH, 0		
    andlw   0x0f			; valor maximo de la tabla
    addwf   PCL		    
    retlw 00111111B ;0
    retlw 00000110B ;1
    retlw 01011011B ;2
    retlw 01001111B ;3
    retlw 01100110B ;4
    retlw 01101101B ;5
    retlw 01111101B ;6
    retlw 00000111B ;7
    retlw 01111111B ;8
    retlw 01101111B ;9
    retlw 01110111B ;A
    retlw 01111100B ;B
    retlw 00111001B ;C
    retlw 01011110B ;D
    retlw 01111001B ;E
    retlw 01110001B ;F			; tabla 
 
;-------------------------- main ---------------------------
 
main:
    call    config_io
    call    reloj_config
    call    tmr0_config
    call    int_config	
    call    config_ioc_rb		; llamamos subrutinas
		
loop:
    goto    loop
    
config_io:
    banksel ANSEL
    clrf    ANSEL
    clrf    ANSELH			; digital I/O
    
    banksel TRISA
    clrf    TRISA
    clrf    TRISC
    clrf    TRISD			; Establece TRISA, TRISC y TRISD en salidas.
    
    bsf	    TRISB, UP			
    bsf	    TRISB, DOWN			; establece UP y DOWN como entradas
    
    bcf	    OPTION_REG, 7		; PORTB pull-up enable for individual PORT
    bsf	    WPUB, UP			; pull-up enable UP
    bsf	    WPUB, DOWN			; pull-up enable DOWN
    
    banksel PORTA
    clrf    PORTA
    clrf    PORTC
    clrf    PORTD			; limpia los puertos A, C y D
    clrf    cont
    clrf    cont_decenas
    clrf    cont_unidades		; limpiamos los contadores
    return
    
reloj_config:
    banksel OSCCON
    bsf	    IRCF2
    bsf	    IRCF1
    bcf	    IRCF0			; seteamos el reloj interno en 4Mhz
    bsf	    SCS				; se setea que usaremos el reloj interno para
					; el reloj del sistema
    return

tmr0_config:
    banksel TRISA   
    bcf	    T0CS			; Internal instruction cycle clock (Fosc/4)
    bcf	    PSA				; el prescaler se asigna al modulo Timer0
    bsf	    PS2
    bsf	    PS1
    bsf	    PS0				; TMR0 rate = 1:256
    rein_tmr0
    return
    
int_config:
    bsf	    GIE				; se habilitan las interrupciones globales
    
    bsf	    RBIE			; habilitamos la interrupcion en cambio del PORTB
    bcf	    RBIF			; se limpia la bandera
    
    bsf	    T0IE			; habilitamos la interrupcion del TMR0
    bcf	    T0IF			; se limpia la flag
    return
   
config_ioc_rb:
    banksel TRISA
    bsf	    IOCB, UP			
    bsf	    IOCB, DOWN			; habilitamos la ioc en PORTB UP y DOWN (6 y 7)
    
    banksel PORTA
    movf    PORTB, W			
    bcf	    RBIF			; limpiamos la bandera
    return
    
END