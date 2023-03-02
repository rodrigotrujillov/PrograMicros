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

UP EQU 6
DOWN EQU 7

PSECT udata_bank0
    cont: DS 2
    
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
	    movwf	W_TEMP			; guardamos W y STATUS
	    swapf	STATUS, W			; copiamos W a W_TEMP
					; intercambiamos STATUS para que se guarde en W
					; se usa SWAPF para no afectar las banderas 
	    movwf	STATUS_TEMP			; guardamos STATUS EN STATUS_TEMP
    
isr:
	    btfsc	RBIF			; 0 =  se salta subrutina int_iocb
					; 1 = llama a la subrutina int_iocb
	    call	int_iocb			; llamamos interrupcion_iocb
    
pop:
	    swapf	STATUS_TEMP, W		; restauramos W y STATUS
					; cambiamos el STATUS_TEMP a W
	    movwf	STATUS			; mueve W a STATUS
	    swapf	W_TEMP, F			; cambia W_TEMP
	    swapf	W_TEMP, W			; cambia W_TEMP en W
	    retfie				; return from interrupt
 
;------------------------ interrupciones- -------------------------------------
    
int_iocb:
	    banksel	PORTA		    
	    btfss	PORTB, UP			; 0 = incrementa PORTA
						; 1 = se salta INCF PORTA
	    incf	PORTA			; incrementamos PORTC
	    btfss	PORTB, DOWN			; 0 = decrementa PORTA
						; 1 =  se salta DECF PORTB
	    decf	PORTA			; decrementamos PORTC
	    bcf		RBIF			; se limpia la bandera
	    return
    
;-------------------------- codigo principal --------------
PSECT code, delta=2, abs
ORG 100h				; posicion de nuestro codigo
 
;-------------------------- main ---------------------------
 
main:
	    call    config_io
	    call    reloj_config
	    call    int_config	
	    call    config_ioc_rb		; llamamos subrutinas
		
loop:
	    goto    loop
    
config_io:
		banksel ANSEL
		clrf    ANSEL
		clrf    ANSELH			; digital I/O

		banksel TRISA
		clrf    TRISA			; seteamos C como salida

		bsf	    TRISB, UP			
		bsf	    TRISB, DOWN			; establece UP y DOWN como entradas

		bcf	    OPTION_REG, 7		; PORTB pull-up enable for individual PORT
		bsf	    WPUB, UP			; pull-up enable UP
		bsf	    WPUB, DOWN			; pull-up enable DOWN

		banksel PORTA
		clrf    PORTA
		clrf    cont			; limpiamos puertos y variables
		return

    reloj_config:
		banksel OSCCON
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