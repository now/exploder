.386
.model flat,stdcall

include \programs\coding\compil~1\masm32\include\windows.inc
include \programs\coding\compil~1\masm32\include\kernel32.inc
include \programs\coding\compil~1\masm32\include\user32.inc
include \programs\coding\compil~1\masm32\include\gdi32.inc
include \programs\coding\compil~1\masm32\include\comctl32.inc

includelib \programs\coding\compil~1\masm32\lib\kernel32.lib
includelib \programs\coding\compil~1\masm32\lib\user32.lib
includelib \programs\coding\compil~1\masm32\lib\gdi32.lib
includelib \programs\coding\compil~1\masm32\lib\comctl32.lib


WinMain PROTO :DWORD,:DWORD,:DWORD,:DWORD
InitDesktop PROTO
InitShell PROTO
ShowError PROTO :DWORD,:BOOL
InitTray PROTO
DesktopCleanup PROTO

.data
public szThreadErr

szClassName			BYTE	"ExploderWnd",0
public szRegClsErr
szRegClsErr			BYTE	"Cannot register class!",0
szError				BYTE	"Error",0
szShell32			BYTE	"SHELL32.DLL",0
szThreadErr			BYTE	"Cannot create a thread!",0

.data?
public hInstance
hInstance		DWORD	?               ; Instance handle
public hWndMain
hWndMain		DWORD	?
szBuf			BYTE 50 dup(?)
lpfnRun			DWORD	?
lpfnShutdown	DWORD	?
hShell32		DWORD	?
extern hwndSystray:DWORD
extern uTrayThreadID:DWORD

.const
X_EXIT	equ	WM_USER+1000


.code

start:
	invoke GetModuleHandle, NULL
	mov    hInstance, eax
	invoke WinMain, hInstance,NULL,NULL, SW_SHOWDEFAULT
	invoke ExitProcess, eax

WinMain proc hInst:DWORD,hPrevInst:DWORD,CmdLine:DWORD,CmdShow:DWORD
	LOCAL wc:WNDCLASSEX
	LOCAL msg:MSG
	
	mov wc.cbSize, sizeof WNDCLASSEX
	mov wc.cbWndExtra, 0
	mov wc.cbClsExtra, 0
	mov wc.style, CS_HREDRAW or CS_VREDRAW or CS_DBLCLKS
	mov wc.lpfnWndProc, offset WndProc
	push hInstance
	pop wc.hInstance
	invoke GetStockObject, BLACK_BRUSH
	mov wc.hbrBackground, eax
	mov wc.lpszMenuName, 0
	mov wc.lpszClassName, offset szClassName
	invoke LoadIcon, 0, IDI_APPLICATION
	mov wc.hIcon, eax
	mov wc.hIconSm, 0
	invoke LoadCursor, 0, IDC_ARROW
	mov wc.hCursor, eax
	invoke RegisterClassEx, addr wc
	.IF (!eax)
		invoke ShowError, addr szRegClsErr, TRUE
	.ENDIF
	
	invoke InitCommonControls
	
	invoke GetSystemMetrics, SM_CXSCREEN
	mov ebx, eax
	invoke GetSystemMetrics, SM_CYSCREEN
	; Create the main window
	invoke CreateWindowEx, WS_EX_TOOLWINDOW, addr szClassName, \
		addr szClassName, WS_POPUP or WS_CLIPSIBLINGS \
		or WS_CLIPCHILDREN, 0, 0, ebx, eax, HWND_DESKTOP, \
		0, hInstance, 0
	
	mov hWndMain, eax
	
	invoke InitShell
	invoke InitDesktop
	
	invoke ShowWindow, hWndMain, SW_SHOW
	invoke UpdateWindow, hWndMain
	invoke GetDesktopWindow
	; removed temporarily.. sometimes causes hanging
	;invoke SendMessage, eax, 400h, 0, 0	; undocumented: tells windows the shell is loaded
	
	.WHILE TRUE
		invoke GetMessage, addr msg, 0, 0, 0
		.BREAK .IF (!eax)
		invoke TranslateMessage, addr msg
		invoke DispatchMessage, addr msg
	.ENDW
	
	mov eax, msg.wParam
	ret

WinMain endp

	
WndProc proc hWnd:DWORD, uMsg:DWORD, wParam:DWORD, lParam:DWORD

	mov eax, uMsg
	
	.IF eax == WM_DESTROY
		invoke FreeLibrary, hShell32
		; destroy desktop
		invoke CloseHandle, uTrayThreadID
		invoke PostQuitMessage, 0
		
		;;;;;; TEMPORARY: Until we get the desktop working
	.ELSEIF eax == WM_RBUTTONUP
    ; do nothing right now		
  .elseif eax == WM_ERASEBKGND
    invoke PaintDesktop, wParam
    mov eax, 1
    ret		
	; stop the main window from activating	
	.ELSEIF eax == WM_ACTIVATEAPP
		jmp @@wm_activate
		
	.ELSEIF eax == WM_MOUSEACTIVATE
		jmp @@wm_activate

	.ELSEIF eax == WM_ACTIVATE
	@@wm_activate:
		cmp wParam, 0
		je @@nothing
		mov eax, MA_NOACTIVATE
		ret
		@@nothing:
		
	.ELSE
		invoke DefWindowProc, hWnd, uMsg, wParam, lParam
		ret
	.ENDIF
	
	; 0 out eax (wow, i'm good at this)
	xor eax, eax
	ret
	
WndProc endp


InitShell proc

	; load shell32.dll (for the undocumented run and shutdown functions)
	invoke LoadLibrary, addr szShell32
	mov hShell32, eax
	invoke GetProcAddress, eax, 0000003Ch
	mov lpfnShutdown, eax
	invoke GetProcAddress, hShell32, 0000003Dh
	mov lpfnRun, eax
	ret

InitShell endp

InitDesktop proc

	invoke InitTray
	ret

InitDesktop endp

ShowError proc msg:DWORD, bDestroy:BOOL

	; stupid, useless function that should be removed
	invoke MessageBox, 0, msg, addr szError, MB_OK or MB_ICONEXCLAMATION
	mov eax, bDestroy
	.IF (eax)
		invoke ExitProcess, 0
	.ENDIF
	ret
	
ShowError endp

end start