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

ClockWinMain PROTO :DWORD
ClockWndProc PROTO :DWORD, :DWORD, :DWORD, :DWORD

ShowError PROTO :DWORD,:BOOL
ZeroMemory PROTO :DWORD,:DWORD
CopyMemory PROTO :DWORD,:DWORD,:DWORD

.data

szClassName   BYTE "Exploding_Clock",0
szTimerErr    BYTE "Failed to create timer!",0

uTimerID      WORD 666

.data?
public ClockTID

tidClock    DWORD ?
hwndClock   DWORD ?
msg         DWORD ?

extern hInstance:DWORD
extern hWndMain:DWORD
extern szRegClsErr:DWORD
extern szThreadErr:DWORD

.const

.code

InitClock proc
  invoke CreateThread, 0, 0, addr ClockWinMain, 0, 0, addr tidClock
  .if (!eax)
    invoke ShowError, addr szThreadErr, FALSE
  .endif
  
  mov tidClock, eax
  ret
InitClock endp

ClockWinMain proc dummy:DWORD
  LOCAL wc:WNDCLASS
  LOCAL msg:MSG
  LOCAL dc:DWORD

  invoke ZeroMemory, addr wc, sizeof wc
  mov wc.style, CS_HREDRAW or CS_VREDRAW or CS_DBLCLKS
  mov wc.lpfnWndProc, offset ClockWndProc
  mov eax, hInstance
  mov wc.hInstance, eax
  mov wc.hBackground, COLOR_WINDOW
  mov wc.lpszClassName, offset szClassName
  
  invoke RegisterClass, addr wc
  .if (!eax)
    invoke ShowError, offset szRegClsErr, FALSE
  .endif
  
  invoke CreateWindowEx, WS_EX_TOPMOST, addr szClassName, 0, WS_VISIBLE, \
              0, 0, 82, 13, hwndMain, 0, hInstance, 0
  mov hwndClock, eax
  
  .while TRUE
    invoke GetMessage, addr msg, 0, 0, 0
    .break .if (!eax)
    invoke TranslateMessage, addr msg
    invoke DispatchMessage, addr msg
  .endw
  
  invoke ExitThread, msg.wParam
  ret
ClockWinMain endp

ClockWndProc proc hwnd:DWORD, uMsg:DWORD, wParam:DWORD, lParam:DWORD
  
  pusha
  mov eax, uMsg
  .if eax == WM_DESTROY
    invoke PostQuitMessage, 0
  .elseif eax == WM_CREATE
    invoke SetTimer, hwnd, uTimerID, 1000, NULL
    mov uTimerID, eax
    .if (!eax)
      ShowError, offset szTimerErr, FALSE
    .endif
  .elseif eax == WM_TIMER
    ;DrawTime
  .else
    popa
    invoke DefWindowProc, hwnd, uMsg, wParam, lParam
    ret
  .endif
  
  popa
  xor eax, eax ;0 out eax
  ret

ClockWndProc endp