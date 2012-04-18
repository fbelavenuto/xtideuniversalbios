; Project name	:	XTIDE Universal BIOS
; Authors		:	Tomi Tilli
;				:	aitotat@gmail.com
;				:
;				:	Greg Lindhorst
;				:	gregli@hotmail.com
;				;
;				:	Krister Nordvall
;				:	krille_n_@hotmail.com
;				:
; Description	:	Main file for BIOS. This is the only file that needs
;					to be compiled since other files are included to this
;					file (so no linker needed, Nasm does it all).

;
; XTIDE Universal BIOS and Associated Tools
; Copyright (C) 2009-2010 by Tomi Tilli, 2011-2012 by XTIDE Universal BIOS Team.
;
; This program is free software; you can redistribute it and/or modify
; it under the terms of the GNU General Public License as published by
; the Free Software Foundation; either version 2 of the License, or
; (at your option) any later version.
;
; This program is distributed in the hope that it will be useful,
; but WITHOUT ANY WARRANTY; without even the implied warranty of
; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
; GNU General Public License for more details.
; Visit http://www.gnu.org/licenses/old-licenses/gpl-2.0.html
;

	ORG 0							; Code start offset 0000h

	; We must define included libraries before including "AssemblyLibrary.inc".
%define	EXCLUDE_FROM_XTIDE_UNIVERSAL_BIOS	; Exclude unused library functions
%ifdef MODULE_BOOT_MENU
	%define MENUEVENT_INLINE_OFFSETS    	; Only one menu required, save space and inline offsets
	%define INCLUDE_MENU_LIBRARY

%else	; If no boot menu included
	%define	INCLUDE_DISPLAY_LIBRARY
	%define INCLUDE_KEYBOARD_LIBRARY
	%define INCLUDE_TIME_LIBRARY
%endif


	; Included .inc files
	%include "AssemblyLibrary.inc"	; Assembly Library. Must be included first!
	%include "Version.inc"
	%include "ModuleDependency.inc"	; Dependency checks for optional modules
	%include "IntController.inc"	; For Interrupt Controller equates
	%include "ATA_ID.inc"			; For ATA Drive Information structs
	%include "IdeRegisters.inc"		; For ATA Registers, flags and commands
	%include "Int13h.inc"			; Equates for INT 13h functions
%ifdef MODULE_EBIOS
	%include "EBIOS.inc"			; Equates for EBIOS functions
%endif
	%include "CustomDPT.inc"		; For Disk Parameter Table
	%include "RomVars.inc"			; For ROMVARS and IDEVARS structs
	%include "RamVars.inc"			; For RAMVARS struct
	%include "BootVars.inc"			; For BOOTVARS struct
	%include "HotkeyBar.inc"		; For Hotkeys
	%include "BootMenu.inc"			; For Boot Menu
	%include "IDE_8bit.inc"			; For IDE 8-bit data port macros
	%include "DeviceIDE.inc"		; For IDE device equates
	%include "Vision.inc"			; For QDI Vision QD65xx VLB IDE Controllers


; Section containing code
SECTION .text

; ROM variables (must start at offset 0)
CNT_ROM_BLOCKS		EQU		ROMSIZE / 512		; number of 512B blocks, 16 = 8kB BIOS
istruc ROMVARS
	at	ROMVARS.wRomSign,	dw	0AA55h			; PC ROM signature
	at	ROMVARS.bRomSize,	db	CNT_ROM_BLOCKS	; ROM size in 512B blocks
	at	ROMVARS.rgbJump,	jmp	Initialize_FromMainBiosRomSearch
	at	ROMVARS.rgbSign,	db	FLASH_SIGNATURE
	at	ROMVARS.szTitle,	db	TITLE_STRING
	at	ROMVARS.szVersion,	db	ROM_VERSION_STRING

;;; For OR'ing into wFlags below
;;;
%ifdef MODULE_SERIAL
	MAIN_FLG_MODULE_SERIAL	equ	FLG_ROMVARS_MODULE_SERIAL
%else
	MAIN_FLG_MODULE_SERIAL	equ	0
%endif

%ifdef MODULE_EBIOS
	MAIN_FLG_MODULE_EBIOS	equ	FLG_ROMVARS_MODULE_EBIOS
%else
	MAIN_FLG_MODULE_EBIOS	equ	0
%endif

%ifdef MODULE_JRIDE
	MAIN_FLG_MODULE_JRIDE	equ	FLG_ROMVARS_MODULE_JRIDE
%else
	MAIN_FLG_MODULE_JRIDE	equ	0
%endif

%ifdef MODULE_ADVANCED_ATA
	MAIN_FLG_MODULE_ADVATA	equ	FLG_ROMVARS_MODULE_ADVATA
%else
	MAIN_FLG_MODULE_ADVATA	equ	0
%endif


;---------------------------;
; AT Build default settings ;
;---------------------------;
%ifdef USE_AT
	at	ROMVARS.wFlags,			dw	FLG_ROMVARS_FULLMODE | FLG_ROMVARS_DRVXLAT | MAIN_FLG_MODULE_SERIAL | MAIN_FLG_MODULE_EBIOS | MAIN_FLG_MODULE_JRIDE | MAIN_FLG_MODULE_ADVATA
	at	ROMVARS.wDisplayMode,	dw	DEFAULT_TEXT_MODE
	at	ROMVARS.wBootTimeout,	dw	BOOT_MENU_DEFAULT_TIMEOUT
	at	ROMVARS.bIdeCnt,		db	4						; Number of supported controllers
	at	ROMVARS.bBootDrv,		db	80h						; Boot Menu default drive
	at	ROMVARS.bMinFddCnt, 	db	0						; Do not force minimum number of floppy drives
	at	ROMVARS.bStealSize,		db	1						; Steal 1kB from base memory
	at	ROMVARS.bIdleTimeout,	db	0						; Standby timer disabled by default

	at	ROMVARS.ideVars0+IDEVARS.wPort,			dw	DEVICE_ATA_DEFAULT_PORT 		; Controller Command Block base port
	at	ROMVARS.ideVars0+IDEVARS.wPortCtrl,		dw	DEVICE_ATA_DEFAULT_PORTCTRL 	; Controller Control Block base port
	at	ROMVARS.ideVars0+IDEVARS.bDevice,		db	DEVICE_16BIT_ATA
	at	ROMVARS.ideVars0+IDEVARS.bIRQ,			db	0
	at	ROMVARS.ideVars0+IDEVARS.drvParamsMaster+DRVPARAMS.wFlags,	db	DISABLE_WRITE_CACHE | FLG_DRVPARAMS_BLOCKMODE
	at	ROMVARS.ideVars0+IDEVARS.drvParamsSlave+DRVPARAMS.wFlags,	db	DISABLE_WRITE_CACHE | FLG_DRVPARAMS_BLOCKMODE

	at	ROMVARS.ideVars1+IDEVARS.wPort,			dw	DEVICE_ATA_DEFAULT_SECONDARY_PORT
	at	ROMVARS.ideVars1+IDEVARS.wPortCtrl,		dw	DEVICE_ATA_DEFAULT_SECONDARY_PORTCTRL
	at	ROMVARS.ideVars1+IDEVARS.bDevice,		db	DEVICE_16BIT_ATA
	at	ROMVARS.ideVars1+IDEVARS.bIRQ,			db	0
	at	ROMVARS.ideVars1+IDEVARS.drvParamsMaster+DRVPARAMS.wFlags,	db	DISABLE_WRITE_CACHE | FLG_DRVPARAMS_BLOCKMODE
	at	ROMVARS.ideVars1+IDEVARS.drvParamsSlave+DRVPARAMS.wFlags,	db	DISABLE_WRITE_CACHE | FLG_DRVPARAMS_BLOCKMODE

	at	ROMVARS.ideVars2+IDEVARS.wPort,			dw	1E8h
	at	ROMVARS.ideVars2+IDEVARS.wPortCtrl,		dw	3E8h
	at	ROMVARS.ideVars2+IDEVARS.bDevice,		db	DEVICE_16BIT_ATA
	at	ROMVARS.ideVars2+IDEVARS.bIRQ,			db	0
	at	ROMVARS.ideVars2+IDEVARS.drvParamsMaster+DRVPARAMS.wFlags,	db	DISABLE_WRITE_CACHE | FLG_DRVPARAMS_BLOCKMODE
	at	ROMVARS.ideVars2+IDEVARS.drvParamsSlave+DRVPARAMS.wFlags,	db	DISABLE_WRITE_CACHE | FLG_DRVPARAMS_BLOCKMODE

	at	ROMVARS.ideVars3+IDEVARS.wPort,			dw	168h
	at	ROMVARS.ideVars3+IDEVARS.wPortCtrl,		dw	368h
	at	ROMVARS.ideVars3+IDEVARS.bDevice,		db	DEVICE_16BIT_ATA
	at	ROMVARS.ideVars3+IDEVARS.bIRQ,			db	0
	at	ROMVARS.ideVars3+IDEVARS.drvParamsMaster+DRVPARAMS.wFlags,	db	DISABLE_WRITE_CACHE | FLG_DRVPARAMS_BLOCKMODE
	at	ROMVARS.ideVars3+IDEVARS.drvParamsSlave+DRVPARAMS.wFlags,	db	DISABLE_WRITE_CACHE | FLG_DRVPARAMS_BLOCKMODE

%ifdef MODULE_SERIAL
	at	ROMVARS.ideVarsSerialAuto+IDEVARS.bDevice,		db	DEVICE_SERIAL_PORT
%endif
%else
;-----------------------------------;
; XT and XT+ Build default settings ;
;-----------------------------------;
	at	ROMVARS.wFlags,			dw	FLG_ROMVARS_DRVXLAT | MAIN_FLG_MODULE_SERIAL | MAIN_FLG_MODULE_EBIOS | MAIN_FLG_MODULE_JRIDE | MAIN_FLG_MODULE_ADVATA
	at	ROMVARS.wDisplayMode,	dw	DEFAULT_TEXT_MODE
	at	ROMVARS.wBootTimeout,	dw	BOOT_MENU_DEFAULT_TIMEOUT
	at	ROMVARS.bIdeCnt,		db	1						; Number of supported controllers
	at	ROMVARS.bBootDrv,		db	80h						; Boot Menu default drive
	at	ROMVARS.bMinFddCnt, 	db	1						; Assume at least 1 floppy drive present if autodetect fails
	at	ROMVARS.bStealSize,		db	1						; Steal 1kB from base memory in full mode
	at	ROMVARS.bIdleTimeout,	db	0						; Standby timer disabled by default

	at	ROMVARS.ideVars0+IDEVARS.wPort,			dw	DEVICE_XTIDE_DEFAULT_PORT			; Controller Command Block base port
	at	ROMVARS.ideVars0+IDEVARS.wPortCtrl,		dw	DEVICE_XTIDE_DEFAULT_PORTCTRL		; Controller Control Block base port
%ifdef MODULE_JRIDE
	at	ROMVARS.ideVars0+IDEVARS.bDevice,		db	DEVICE_JRIDE_ISA
%else
	at	ROMVARS.ideVars0+IDEVARS.bDevice,		db	DEVICE_XTIDE_REV1
%endif
	at	ROMVARS.ideVars0+IDEVARS.bIRQ,			db	0				; IRQ
	at	ROMVARS.ideVars0+IDEVARS.drvParamsMaster+DRVPARAMS.wFlags,	db	DISABLE_WRITE_CACHE | FLG_DRVPARAMS_BLOCKMODE
	at	ROMVARS.ideVars0+IDEVARS.drvParamsSlave+DRVPARAMS.wFlags,	db	DISABLE_WRITE_CACHE | FLG_DRVPARAMS_BLOCKMODE

	at	ROMVARS.ideVars1+IDEVARS.drvParamsMaster+DRVPARAMS.wFlags,	db	DISABLE_WRITE_CACHE | FLG_DRVPARAMS_BLOCKMODE
	at	ROMVARS.ideVars1+IDEVARS.drvParamsSlave+DRVPARAMS.wFlags,	db	DISABLE_WRITE_CACHE | FLG_DRVPARAMS_BLOCKMODE

	at	ROMVARS.ideVars2+IDEVARS.drvParamsMaster+DRVPARAMS.wFlags,	db	DISABLE_WRITE_CACHE | FLG_DRVPARAMS_BLOCKMODE
	at	ROMVARS.ideVars2+IDEVARS.drvParamsSlave+DRVPARAMS.wFlags,	db	DISABLE_WRITE_CACHE | FLG_DRVPARAMS_BLOCKMODE

	at	ROMVARS.ideVars3+IDEVARS.drvParamsMaster+DRVPARAMS.wFlags,	db	DISABLE_WRITE_CACHE | FLG_DRVPARAMS_BLOCKMODE
	at	ROMVARS.ideVars3+IDEVARS.drvParamsSlave+DRVPARAMS.wFlags,	db	DISABLE_WRITE_CACHE | FLG_DRVPARAMS_BLOCKMODE

%ifdef MODULE_SERIAL
	at	ROMVARS.ideVarsSerialAuto+IDEVARS.bDevice,		db	DEVICE_SERIAL_PORT
%endif
%endif
iend

	; Strings are first to avoid them moving unnecessarily when code is turned on and off with %ifdef's
	; since some groups of strings need to be on the same 256-byte page.
	;
%ifdef MODULE_STRINGS_COMPRESSED
	%define STRINGSCOMPRESSED_STRINGS
	%include "StringsCompressed.asm"
%else
	%include "Strings.asm"			; For BIOS message strings
%endif

	; Libraries, data, Initialization and drive detection

	%include "AssemblyLibrary.asm"

	; String compression tables need to come after the AssemblyLibrary (since they depend on addresses
	; established in the assembly library), and are unnecessary if strings are not compressed.
	;
%ifdef MODULE_STRINGS_COMPRESSED
	%undef  STRINGSCOMPRESSED_STRINGS
	%define STRINGSCOMPRESSED_TABLES
	%include "StringsCompressed.asm"
%endif

	%include "Initialize.asm"		; For BIOS initialization
	%include "Interrupts.asm"		; For Interrupt initialization
	%include "RamVars.asm"			; For RAMVARS initialization and access
	%include "BootVars.asm"			; For initializing variabled used during init and boot
	%include "FloppyDrive.asm"		; Floppy Drive related functions
	%include "CreateDPT.asm"		; For creating DPTs
	%include "FindDPT.asm"			; For finding DPTs
	%include "AccessDPT.asm"		; For accessing DPTs
	%include "LbaAssist.asm"		; For generating L-CHS parameters to LBA drives
	%include "BootMenuInfo.asm"		; For creating BOOTMENUINFO structs
	%include "AtaID.asm"			; For ATA Identify Device information
	%include "DetectDrives.asm"		; For detecting IDE drives
	%include "DetectPrint.asm"		; For printing drive detection strings

	; Hotkey Bar
%ifdef MODULE_HOTKEYS
	%include "HotkeyBar.asm"		; For hotkeys during drive detection and boot menu
	%include "DriveXlate.asm"		; For swapping drive numbers
%endif

	; Boot menu
%ifdef MODULE_BOOT_MENU
	%include "BootMenu.asm"			; For Boot Menu operations
	%include "BootMenuEvent.asm"	; For menu library event handling
									; NOTE: BootMenuPrint needs to come immediately after BootMenuEvent
									;       so that jump table entries in BootMenuEvent stay within 8-bits
	%include "BootMenuPrint.asm"	; For printing Boot Menu strings, also includes "BootMenuPrintCfg.asm"
%endif

	; Boot loader
	%include "Int19h.asm"			; For Int 19h, Boot Loader
	%include "Int19hReset.asm"		; INT 19h handler for proper system reset
	%include "BootSector.asm"		; For loading boot sector

	; For all device types
	%include "Idepack.asm"
	%include "Device.asm"
	%include "Timer.asm"			; For timeout and delay

	; IDE Device support
%ifdef MODULE_ADVANCED_ATA
	%include "AdvAtaInit.asm"		; For initializing VLB and PCI controllers
	%include "Vision.asm"			; QDI Vision QD6500 and QD6580 support
%endif
%define IDEDEVICE Ide
%define ASSEMBLE_SHARED_IDE_DEVICE_FUNCTIONS
	%include "IOMappedIDE.inc"		; Assembly IDE support for normal I/O mapped controllers
	%include "IdeCommand.asm"
	%include "IdeTransfer.asm"		; Must be included after IdeCommand.asm
	%include "IdeWait.asm"
	%include "IdeError.asm"			; Must be included after IdeWait.asm
	%include "IdeDPT.asm"
	%include "IdeIO.asm"
	%include "IdeIrq.asm"
%undef IDEDEVICE
%undef ASSEMBLE_SHARED_IDE_DEVICE_FUNCTIONS

	; JR-IDE support
%ifdef MODULE_JRIDE
%define IDEDEVICE MemIde
	%include "MemMappedIDE.inc"		; Assembly IDE support for memory mapped controllers
	%include "IdeCommand.asm"
	%include "MemIdeTransfer.asm"	; Must be included after IdeCommand.asm
	%include "IdeWait.asm"
	%include "IdeError.asm"			; Must be included after IdeWait.asm
%undef IDEDEVICE
%endif


%ifdef MODULE_SERIAL				; Serial Port Device support
	%include "SerialCommand.asm"
	%include "SerialDPT.asm"
%endif

	; INT 13h Hard Disk BIOS functions
	%include "Int13h.asm"			; For Int 13h, Disk functions
	%include "AH0h_HReset.asm"		; Required by Int13h_Jump.asm
	%include "AH1h_HStatus.asm"		; Required by Int13h_Jump.asm
	%include "AH2h_HRead.asm"		; Required by Int13h_Jump.asm
	%include "AH3h_HWrite.asm"		; Required by Int13h_Jump.asm
	%include "AH4h_HVerify.asm"		; Required by Int13h_Jump.asm
	%include "AH8h_HParams.asm"		; Required by Int13h_Jump.asm
	%include "AH9h_HInit.asm"		; Required by Int13h_Jump.asm
	%include "AHCh_HSeek.asm"		; Required by Int13h_Jump.asm
	%include "AHDh_HReset.asm"		; Required by Int13h_Jump.asm
	%include "AH10h_HReady.asm"		; Required by Int13h_Jump.asm
	%include "AH11h_HRecal.asm"		; Required by Int13h_Jump.asm
	%include "AH15h_HSize.asm"		; Required by Int13h_Jump.asm
	%include "AH23h_HFeatures.asm"	; Required by Int13h_Jump.asm
	%include "AH24h_HSetBlocks.asm"	; Required by Int13h_Jump.asm
	%include "AH25h_HDrvID.asm"		; Required by Int13h_Jump.asm
	%include "Address.asm"			; For sector address translations
	%include "Prepare.asm"			; For buffer pointer normalization
%ifdef MODULE_EBIOS
	%include "AH42h_ExtendedReadSectors.asm"
	%include "AH43h_ExtendedWriteSectors.asm"
	%include "AH44h_ExtendedVerifySectors.asm"
	%include "AH47h_ExtendedSeek.asm"
	%include "AH48h_GetExtendedDriveParameters.asm"
	%include "AH41h_CheckIfExtensionsPresent.asm"
%endif
