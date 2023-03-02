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

;---- MACROS ------------------------------------------
  
reiniciar_tmr0 macro
		banksel	    PORTA
		movlw	    100
		movwf	    TMR0
		bcf	    T0IF
		endm
  
UP EQU 6
DOWN EQU 7

PSECT udata_bank0
    var: DS 1
    banderas: DS 1
    nibble: DS 2
    display_var: DS 2
    
    
PSECT udata_shr
    W_TEMP: DS 1
    STATUS_TEMP: DS 1
    
;------------------ reset vector -----------------
    
PSECT resVect, class=CODE, abs, delta=2
ORG 00h
resetVec:
	    PAGESEL		main
	    goto		main
    
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
		movwf	    W_TEMP		
		swapf	    STATUS, W			
		movwf	    STATUS_TEMP			
    
isr:
		btfsc	    RBIF	
		goto	    $-1
		call	    int_iocb			
		    
		btfsc	    T0IF
		call	    int_tmr0
		
pop:
		swapf	    STATUS_TEMP, W		
		movwf	    STATUS			
		swapf	    W_TEMP, F			
		swapf	    W_TEMP, W			
		retfie				
 
;------------------------ interrupciones- -------------------------------------
    
int_iocb:
		banksel	    PORTA		    
		btfss	    PORTB, UP			    
		incf	    PORTA			
		btfss	    PORTB, DOWN			
		decf	    PORTA			
		bcf	    RBIF			
		return
    
int_tmr0:
		reiniciar_tmr0
		clrf	    PORTD
		clrf	    PORTC
		btfsc	    banderas, 0
		goto	    display1
		goto	    display2
		
display1:
		movf	    display_var, W
		movwf	    PORTC
		bsf	    PORTD, 0
		goto	    siguiente_display
display2:
		movf	    display_var+1, W
		movwf	    PORTC
		bsf	    PORTD, 1
		goto	    siguiente_display
siguiente_display:
		movlw	    0x01
		xorwf	    banderas, F
		return
		
;-------------------------- codigo principal --------------
PSECT code, delta=2, abs
ORG 100h				; posicion de nuestro codigo

;---- TABLA ------------------------------------------------
tabla:
		clrf	    PCLATH			; se limpia el registro de PCLATH
		bsf	    PCLATH, 0		
		andlw	    0x0f			; valor maximo de la tabla
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
		retlw	    01110001B ;F			; tabla 
;-------------------------- main ---------------------------
 
main:
		call	    config_io
		call	    reloj_config
		call	    int_config	
		call	    config_ioc_rb		; llamamos subrutinas
		call	    config_tmr0
loop:
		movf	    PORTA,  W
		movwf	    var
		call	    separar_nibbles
		call	    preparar_display
		goto	    loop
		
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
    
config_io:
		banksel	    ANSEL
		clrf	    ANSEL
		clrf	    ANSELH			

		banksel	    TRISA
		clrf	    TRISA
		clrf	    TRISC
		bcf	    TRISD, 0
		bcf	    TRISD, 1

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
		bcf	    IRCF0			; seteamos el reloj interno en 4Mhz
		bsf	    SCS				; se setea que usaremos el reloj interno para
						    ; el reloj del sistema
		return
    
int_config:
		bsf	    GIE				; se habilitan las interrupciones globales

		bsf	    RBIE			; habilitamos la interrupcion en cambio del PORTB
		bcf	    RBIF			; se limpia la bandera

		bsf	    T0IE
		bcf	    T0IF
		return
   
config_ioc_rb:
		banksel	    TRISA
		bsf	    IOCB, UP			
		bsf	    IOCB, DOWN			; habilitamos la ioc en PORTB UP y DOWN (6 y 7)

		banksel	    PORTA
		movf	    PORTB, W			
		bcf	    RBIF			; limpiamos la bandera
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
    
END