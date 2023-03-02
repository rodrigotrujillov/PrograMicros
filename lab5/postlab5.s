; Archivo: prelab5.s
; Dispositivo: PIC16F887
; Autor: Rodrigo Esteban Trujillo Vásquez
; Compilador: pic-as 
;	   
; Creado: 21 febrero, 2023
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

;---- MACROS -------------------------------------------------------------------
  
reiniciar_tmr0 macro
		banksel	    PORTA
		movlw	    100
		movwf	    TMR0
		bcf	    T0IF
		endm
  
;---- VARIABLES ----------------------------------------------------------------
		
UP EQU 0
DOWN EQU 1

PSECT udata_bank0
    var: DS 1
    banderas: DS 1
    //nibble: DS 1
    display_var: DS 3
    
    decenas: DS 1
    centenas: DS 1
    unidades: DS 1
    
    
PSECT udata_shr
    W_TEMP: DS 1
    STATUS_TEMP: DS 1
    
;---- VECTOR RESET -------------------------------------------------------------
    
PSECT resVect, class=CODE, abs, delta=2
ORG 00h
resetVec:
	    PAGESEL		main
	    goto		main
    
;---- VECTOR DE INTERRUPCION ---------------------------------------------------
    
PSECT intVect, class=CODE, abs, delta=2
ORG 04h
    
push:
		movwf	    W_TEMP		
		swapf	    STATUS, W			
		movwf	    STATUS_TEMP			
    
isr:
		btfsc	    RBIF	
		//goto	    $-2
		call	    int_iocb	
		//bcf	    RBIF
		    
		btfsc	    T0IF
		call	    int_tmr0
		
pop:
		swapf	    STATUS_TEMP, W		
		movwf	    STATUS			
		swapf	    W_TEMP, F			
		swapf	    W_TEMP, W			
		retfie				
 
;---- INTERRUPCIONES -----------------------------------------------------------
    
;---- IOC INTERRUPCION ---------------------------------------------------------
		
int_iocb:
		banksel	    PORTA	
		btfss	    PORTB, UP			    
		incf	    PORTA
		//btfss	    PORTB, UP
		//goto	    $-1
		
		btfss	    PORTB, DOWN			
		decf	    PORTA	
		//btfss	    PORTB, DOWN
		//goto	    $-1
		
		bcf	    RBIF
			
		return
		
;---- TMR0 INTERRUPCION --------------------------------------------------------
		
int_tmr0:
		call	    sel_display
		reiniciar_tmr0
		return
	
;---- SELECCION DE DISPLAYS ----------------------------------------------------		

sel_display:
		bcf	    PORTD, 0
		bcf	    PORTD, 1
		bcf	    PORTD, 2
		btfsc	    banderas, 0
		goto	    display_3
		btfsc	    banderas, 1
		goto	    display_2
		btfsc	    banderas, 2
		goto	    display_1
		
display_1:
		movf	    display_var, W
		movwf	    PORTC
		bsf	    PORTD, 2
		bcf	    banderas, 2
		bsf	    banderas, 1
		return
		
display_2:
		movf	    display_var+1, W
		movwf	    PORTC
		bsf	    PORTD, 1
		bcf	    banderas, 1
		bsf	    banderas, 0
		return
		
display_3:
		movf	    display_var+2, W
		movwf	    PORTC
		bsf	    PORTD, 0
		bcf	    banderas, 0
		bsf	    banderas, 2
		return
		
;----- CODIGO PRINCIPAL --------------------------------------------------------
PSECT code, delta=2, abs
ORG 100h				; posicion de nuestro codigo

;---- TABLA --------------------------------------------------------------------
tabla:
		clrf	    PCLATH			
		bsf	    PCLATH, 0		
		andlw	    0x0f			
		addwf	    PCL		    
		retlw	    00111111B ;0
		retlw	    00000110B ;1
		retlw	    01011011B ;2
		retlw	    01001111B ;3
		retlw	    01100110B ;4
		retlw	    01101101B ;5
		retlw	    01111101B ;6
		retlw	    00000111B ;7
		retlw	    01111111B ;8
		retlw	    01101111B ;9
		retlw	    01110111B ;A
		retlw	    01111100B ;B
		retlw	    00111001B ;C
		retlw	    01011110B ;D
		retlw	    01111001B ;E
		retlw	    01110001B ;F			
		
;---- MAIN ---------------------------------------------------------------------
 
main:
		call	    config_io
		call	    reloj_config
		call	    int_config	
		call	    config_ioc_rb		
		call	    config_tmr0
		banksel	    PORTA
		
;---- LOOP ---------------------------------------------------------------------	
	
loop:	
		call	    mostrar_display
		call	    convert_centenas

		goto	    loop
		
;---- SUBRUTINAS ---------------------------------------------------------------
		
/*		
separar_nibbles:
		movf	    var, W
		andlw	    0x0f
		movwf	    nibble
		
		swapf	    var, W
		andlw	    0x0f
		movwf	    nibble+1
		return
		
preparar_display:
		movf	    nibble, W
		call	    tabla
		movwf	    display_var
		
		movf	    nibble+1, W
		call	    tabla
		movwf	    display_var+1
		return
*/
		
;---- SUBRUTINAS DE CONFIGURACION ----------------------------------------------
		
config_io:
		banksel	    ANSEL
		clrf	    ANSEL
		clrf	    ANSELH			

		banksel	    TRISA
		clrf	    TRISA
		clrf	    TRISC
		bcf	    TRISD, 0
		bcf	    TRISD, 1
		bcf	    TRISD, 2

		bsf	    TRISB, UP			
		bsf	    TRISB, DOWN			
		bcf	    OPTION_REG, 7		
		bsf	    WPUB, UP			
		bsf	    WPUB, DOWN			

		banksel	    PORTA
		clrf	    PORTA
		clrf	    PORTC
		clrf	    PORTD
		return

reloj_config:
		banksel	    OSCCON
		bsf	    IRCF2
		bsf	    IRCF1
		bcf	    IRCF0			
		bsf	    SCS				
		return
    
int_config:
		bsf	    GIE				

		bsf	    RBIE			
		bcf	    RBIF			

		bsf	    T0IE
		bcf	    T0IF
		return
   
config_ioc_rb:
		banksel	    TRISA
		bsf	    IOCB, UP			
		bsf	    IOCB, DOWN			

		banksel	    PORTA
		movf	    PORTB, W			
		bcf	    RBIF			
		return
		
config_tmr0:	
		banksel	    TRISA
		bcf	    T0CS
		bcf	    PSA
		bcf	    PS2
		bcf	    PS1
		bsf	    PS0
		reiniciar_tmr0
		return
		
;---- CONVERSION DE CENTENAS, DECENAS Y UNIDADES -------------------------------
		
convert_centenas:
    		clrf	    unidades
		clrf	    centenas
		clrf	    decenas
		
		movf	    PORTA, W
		movwf	    var
		
		movlw	    100
		subwf	    var, F
		incf	    centenas
		btfsc	    STATUS, 0
		goto	    $-4
		decf	    centenas
		movlw	    100
		addwf	    var, F
		call	    convert_decenas
		return
   
convert_decenas:
		movlw	    10
		subwf	    var, F
		incf	    decenas
		btfsc	    STATUS, 0
		goto	    $-4
		decf	    decenas
		movlw	    10
		addwf	    var, F
		call	    convert_unidades
		return
		
convert_unidades:
		movlw	    1
		subwf	    var, F
		incf	    unidades
		btfsc	    STATUS, 0
		goto	    $-4
		decf	    unidades
		movlw	    1
		addwf	    var, F
		return
		
;---- VALORES A LOS DISPLAYS ---------------------------------------------------
		
mostrar_display:
		movf	    unidades, W
		call	    tabla
		movwf	    display_var
		
		movf	    decenas, W
		call	    tabla
		movwf	    display_var+1
		
		movf	    centenas, W
		call	    tabla
		movwf	    display_var+2
		return
END