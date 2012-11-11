.386
.model flat,stdcall

include \programs\coding\compil~1\masm32\include\windows.inc
include \programs\coding\compil~1\masm32\include\kernel32.inc
include \programs\coding\compil~1\masm32\include\user32.inc
include \programs\coding\compil~1\masm32\include\gdi32.inc
include tray.inc

includelib \programs\coding\compil~1\masm32\lib\kernel32.lib
includelib \programs\coding\compil~1\masm32\lib\user32.lib
includelib \programs\coding\compil~1\masm32\lib\gdi32.lib

TrayWinMain PROTO :DWORD
ShowError PROTO :DWORD, :BOOL
ZeroMemory PROTO :DWORD, :DWORD
AdjustLayout PROTO
CopyMemory PROTO :DWORD, :DWORD, :DWORD
MessageHandler PROTO :DWORD, :DWORD, :DWORD, :DWORD

min macro a, b
  .if (a > b)
    mov eax, b
  .else
    mov eax, a
  .endif
endm

max macro a, b
  .if (a < b)
    mov eax, b
  .else
    mov eax, a
  .endif
endm

.data
szShellClassName   BYTE  "Shell_TrayWnd", 0
szSystrayClassName BYTE "SystemTray", 0
szRegister         BYTE "TaskbarCreated", 0

hbmBuffer   DWORD 0
hdcBuffer   DWORD 0

LM_SYSTRAY  DWORD 9000
nWrapCount DWORD 8
nIconSize DWORD 16
nSpacingX DWORD 2
nSpacingY DWORD 2
nBorderX  DWORD 0
nBorderY  DWORD 0
nBorderTop DWORD 0
nBorderBottom DWORD 0
nBorderRight DWORD 0
nBorderLeft DWORD 0
nMinWidth DWORD 128
nMaxWidth DWORD 256
nDeltaX   DWORD 0
nDeltaY   DWORD 0
nMinHeight DWORD 16
nMaxHeight DWORD 32
uLastID DWORD 1

.data?
public hwndSystray
public uTrayThreadID

hwndSystray    DWORD   ?
hwndShellTray  DWORD   ?
hwndToolTip    DWORD   ?
uTrayThreadID  DWORD   ?

pHead       DWORD   ?
pCurrent    DWORD   ?
pPrev       DWORD   ?
cIcons      DWORD   ?

nTrayIcoSize  DWORD ?
nTrayYSize    DWORD ?
nScreenX    DWORD   ?
nScreenY    DWORD   ?
nSizeX      DWORD   ?
nSizeY      DWORD   ?
nX          DWORD   ?
nY          DWORD   ?

extern hInstance:DWORD
extern hWndMain:DWORD
extern szRegClsErr:DWORD
extern szThreadErr:DWORD

public szTooltipClass
szTooltipClass  BYTE  "tooltips_class32"

.const
X_EXIT      equ WM_USER+1000
DI_NORMAL   equ 3
CW_USEDEFAULT   equ 80000000h

.code

InitTray proc
    invoke CreateThread, 0, 0, addr TrayWinMain, 0, 0, addr uTrayThreadID
    .IF (!eax)
      invoke ShowError, addr szThreadErr, FALSE
    .ENDIF
    mov uTrayThreadID, eax
    ret
InitTray endp

TrayWinMain proc dummy:DWORD
  LOCAL wc:WNDCLASS
  LOCAL msg:MSG
  LOCAL dc:DWORD

  invoke GetSystemMetrics, SM_CXSCREEN
  mov nScreenX, eax
  invoke GetSystemMetrics, SM_CYSCREEN
  mov nScreenY, eax
  
  invoke  GetSystemMetrics, SM_CXSMICON
  mov     nTrayIcoSize, eax
  mov     nTrayYSize, eax

  
  
  invoke ZeroMemory, addr wc, sizeof wc
  
;  mov wc.cbSize, sizeof WNDCLASS
  mov wc.style, CS_HREDRAW or CS_VREDRAW or CS_DBLCLKS or CS_GLOBALCLASS
  mov wc.lpfnWndProc, offset SystrayWndProc
  mov eax, hInstance
  mov wc.hInstance, eax
  mov wc.hbrBackground, COLOR_BTNFACE+1
  mov wc.lpszClassName, offset szSystrayClassName

  invoke RegisterClass, addr wc
  .IF (!eax)
    invoke ShowError, offset szRegClsErr, FALSE
  .ENDIF

  invoke CreateWindowEx, WS_EX_TOOLWINDOW, szSystrayClassName, NULL, WS_POPUP, \
                        0, 0, 0, 0, hWndMain, NULL, hInstance, NULL
  mov hwndSystray, eax
  
  invoke AdjustLayout

  mov wc.lpfnWndProc, ShellTrayWndProc
  mov wc.lpszClassName, offset szShellClassName
  
  invoke RegisterClass, addr wc
  .IF (!eax)
    invoke ShowError, offset szRegClsErr, FALSE
  .ENDIF

  invoke CreateWindowEx, WS_EX_TOOLWINDOW, szShellClassName, NULL, WS_POPUP, \
                        0, 0, 0, 0, NULL, NULL, hInstance, NULL
  mov hwndShellTray, eax
TrayWinMain endp

AdjustLayout proc
  LOCAL nOriginX:DWORD
  LOCAL nOriginY:DWORD
  LOCAL nCurrentX:DWORD
  LOCAL nCurrentY:DWORD
  LOCAL nActualX:DWORD
  LOCAL nActualY:DWORD
  LOCAL nCount:DWORD
  LOCAL nTemp:DWORD
  LOCAL ti:TOOLINFO
  mov nCount, 0

  ;set nSizeX
  .if (nWrapCount > 0)
    min cIcons, nWrapCount
    mov nSizeX, eax
  .else
    mov eax, cIcons
    mov nSizeX, eax
  .endif

  mov eax, nIconSize
  add eax, nSpacingX
  mul nSizeX
  sub eax, nSpacingX
  mov nSizeX, eax
  
  ;set nSizeY
  .if (nWrapCount > 0)
    .if (cIcons > 1)
      mov eax, cIcons
      mov nSizeY, eax
    .else
      mov nSizeY, 1
    .endif
    sub nSizeY, 1
    mov eax, nSizeY ; nWrapCount
    div nWrapCount
    add eax, 1
    mov nSizeY, eax
  .else
    mov nSizeY, 1
  .endif
  mov eax, nIconSize
  add eax, nSpacingY
  mul nSizeY
  mov nSizeY, eax
  mov eax, nSpacingY
  sub nSizeY, eax

  .if (nSizeX)
    mov eax, nSizeX
    add eax, nBorderLeft
    add eax, nBorderRight
    add eax, nBorderX
    add eax, nBorderX
    mov nSizeX, eax
  .endif
  .if (nSizeY)
    mov eax, nSizeY
    add eax, nBorderTop
    add eax, nBorderBottom
    add eax, nBorderY
    add eax, nBorderY
    mov nSizeY, eax
  .endif
  
  .if (nMinWidth > 0)
    max nMinWidth, nSizeX
    mov nSizeX, eax
  .endif
  .if (nMaxWidth > 0)
    min nMaxWidth, nSizeX
    mov nSizeX, eax
  .endif
  .if (nMinHeight > 0)
    max nMinHeight, nSizeY
    mov nSizeY, eax
  .endif
  .if (nMaxHeight > 0)
    min nMaxHeight, nSizeY
    mov nSizeY, eax
  .endif
  
  .if (nDeltaX < 0)
    .if (nDeltaY < 0)
      mov eax, nSizeX
      sub eax, nIconSize
      sub eax, nBorderRight
      sub eax, nBorderX
      mov nOriginX, eax
      mov eax, nSizeY
      sub eax, nIconSize
      sub eax, nBorderBottom
      sub eax, nBorderY
      mov nOriginY, eax
    .else
      mov eax, nSizeX
      sub eax, nIconSize
      sub eax, nBorderRight
      sub eax, nBorderX
      mov nOriginX, eax
      mov eax, nBorderTop
      add eax, nBorderY
      mov nOriginY, eax
    .endif
  .else
    .if (nDeltaY < 0)
      mov eax, nBorderLeft
      add eax, nBorderX
      mov nOriginX, eax
      mov eax, nSizeY
      sub eax, nIconSize
      sub eax, nBorderBottom
      sub eax, nBorderY
      mov nOriginY, eax
    .else
      mov eax, nBorderLeft
      add eax, nBorderX
      mov nOriginX, eax
      mov eax, nBorderTop
      add eax, nBorderY
      mov nOriginY, eax
    .endif
  .endif
  
  mov eax, nOriginX
  mov nCurrentX, eax
  mov eax, nOriginY
  mov nCurrentY, eax
  
  assume eax:ptr TrayWnd
  assume ebx:ptr TrayWnd
  mov eax, pHead
  .while (eax)
    mov ebx, eax
    mov edx, nCurrentX
    mov [ebx].rc.left, edx
    mov edx, nCurrentY
    mov [ebx].rc.top, edx
    mov edx, nCurrentX
    add edx, nIconSize
    mov [ebx].rc.top, edx
    mov edx, nCurrentY
    add edx, nIconSize
    mov [ebx].rc.bottom, edx
    
    .if ([ebx].uToolTip)
      mov ti.cbSize, sizeof TOOLINFO
      mov edx, hwndSystray
      mov ti.hWnd, edx
      mov edx, [ebx].uToolTip
      mov ti.uId, edx
      invoke CopyMemory, addr [ti].rect, addr [ebx].rc, sizeof RECT
      invoke SendMessage, hwndToolTip, TTM_NEWTOOLRECT, 0, addr ti
    .endif
    
    inc nCount
    
    .if ((nWrapCount > 0) && (nCount >= nWrapCount))
      mov edx, nDeltaY
      add nOriginY, edx
      
      mov edx, nOriginX
      mov nCurrentX, edx
      mov edx, nOriginY
      mov nCurrentY, edx

      mov nCount, 0
    .else
      mov edx, nDeltaX
      add nCurrentX, edx
    .endif
    
    mov eax, [ebx].pNext
  .endw

  mov eax, nX
  .if (nResizeH == DIR_LEFT)
    sub eax, nSizeX
  .endif
  mov nActualX, eax
  
  mov eax, nY
  .if (nResizeV == DIR_UP)
    sub eax, nSizeY
  .endif
  mov nActualY, eax
  
  .if (nActualX < 0)
    mov nActualX, 0
  .elseif ((nActualX + nSizeX) > nScreenX)
    mov eax, nScreenX
    sub eax, nSizeX
    mov nActualX, eax
  .endif
  
  .if (nActualY < 0)
    mov nActualY, 0
  .elseif (nActualY < 0)
    mov eax, nScreenY
    sub eax, nSizeY
    mov nActualY, eax
  .endif
  
  invoke SetWindowPos, hwndSystray, NULL, nActualX, nActualY, nSizeX, nSizeY, SWP_NOZORDER or SWP_NOACTIVATE
  
  invoke InvalidateRect, hwndSystray, NULL, FALSE
AdjustLayout endp

AddIcon proc fRedraw:WORD
  LOCAL pIcon:DWORD
  LOCAL pLast:DWORD
  assume  eax:ptr TrayWnd
  assume  edx:ptr TrayWnd
  
  mov eax, pHead
  mov pLast, eax
  
  invoke GlobalAlloc, GPTR, sizeof TrayWnd
  mov pIcon, eax
  mov (TrayWnd ptr pIcon).pNext, NULL
  
  .if (pHead == NULL)
    mov eax, pIcon
    mov pHead, eax
  .else
    mov eax, (TrayWnd ptr [pLast]).pNext
    .while (eax)
      mov eax, (TrayWnd ptr [pLast]).pNext
      mov pLast, eax
    .endw
    mov eax, pIcon
    mov (TrayWnd ptr pLast).pNext, eax
  .endif
  
  inc cIcons
  
  .if (fRedraw)
    invoke AdjustLayout
  .endif
  
  mov eax, pIcon
  ret
AddIcon endp

SearchForIcon proc hwnd:DWORD, uID:DWORD, bAdd:DWORD
  LOCAL ptw:DWORD
  assume  eax:ptr TrayWnd

  mov eax, pHead
  mov ptw, eax
  
  .while (ptw)
    .if (((TrayWnd ptr [ptw]).hwnd == hwnd) && ((TrayWnd ptr [ptw]).uID == uID))
      mov eax, ptw
      ret
    .endif
    mov eax, (TrayWnd ptr [ptw]).pNext
    mov ptw, eax
  .endw
  .if (!bAdd)
    mov eax, NULL
    ret
  .endif
  
  invoke AddIcon, TRUE
  ret
SearchForIcon endp

RemoveIcon proc hwnd:DWORD, uID:DWORD
  LOCAL pIcon:DWORD
  LOCAL pPrevi:DWORD
  assume  eax:ptr TrayWnd

  mov eax, pHead
  mov pIcon, eax
  mov pPrev, NULL
  .while (pIcon)
    .if ((TrayWnd ptr [pIcon]).hwnd == hwnd && (TrayWnd ptr [pIcon]).uID == hwnd)
      .if (pPrevi)
        mov eax, (TrayWnd ptr [pIcon]).pNext
        mov ebx, (TrayWnd ptr [pPrevi]).pNext
        mov ebx, eax
      .else
        mov eax, (TrayWnd ptr [pIcon]).pNext
        mov pHead, eax
      .endif
      
      invoke GlobalFree, pIcon
      dec cIcons
      
      invoke AdjustLayout
      mov eax, TRUE
      ret
    .endif
    mov eax, pIcon
    mov pPrevi, eax
    mov eax, (TrayWnd ptr [pIcon]).pNext
    mov pIcon, eax
  .endw
  mov eax, FALSE
  ret
RemoveIcon endp

FreeIconList proc
  LOCAL pIcon:DWORD
  assume eax:ptr TrayWnd
  assume ebx:ptr TrayWnd

  mov eax, pHead
  mov pIcon, eax

  .while (pIcon)
    mov ebx, (TrayWnd ptr [pIcon]).pNext
    invoke GlobalFree, pIcon
    mov pIcon, ebx
  .endw
  
  mov pHead, NULL
  mov cIcons, 0
FreeIconList endp

SystrayWndProc proc hwnd:DWORD, uMsg:DWORD, wParam:DWORD, lParam:DWORD
  LOCAL pnid:DWORD
  LOCAL pWnd:DWORD
  LOCAL psti:DWORD
  LOCAL ti:TOOLINFO
  LOCAL ps:PAINTSTRUCT
  LOCAL hdc:DWORD
    
  .if (uMsg == LM_SYSTRAY)
    mov edi, lParam
    mov pnid, edi
    assume edi:ptr NOTIFYICONDATA
    
    .if (wParam == NIM_ADD)
      invoke IsWindow, [edi].hwnd
      .if (!eax)
        ret
      .endif
      invoke SearchForIcon, [edi].hwnd, [edi].uID, TRUE
      .if (!eax)
        ret
      .endif
      mov pWnd, eax
      assume eax:ptr NOTIFYICONDATA
      mov eax, [pnid]
      mov (TrayWnd ptr [pWnd]).hwnd, [eax].hwnd
      mov (TrayWnd ptr [pWnd]).uID, [eax].uID
      mov (TrayWnd ptr [pWnd]).uFlags, [eax].uFlags
      mov (TrayWnd ptr [pWnd]).uCallbackMessage, [eax].uCallbackMessage
      mov (TrayWnd ptr [pWnd]).hOriginalIcon, [eax].hIcon
      invoke CopyIcon, [eax].hIcon
      mov (TrayWnd ptr [pWnd]).hIcon, eax
      mov edi, pWnd
      invoke ZeroMemory, addr [edi].szTip, 1
      mov eax, uLastID
      mov (TrayWnd ptr [pWnd]).uToolTip, eax
      inc uLastID
      .if ([pWnd].uFlags & NIF_TIP)
        mov eax, pnid
        invoke lstrcpyn, addr [edi].szTip, addr [eax].szTip, 64
      .endif
      mov [ti].cbSize, sizeof TOOLINFO
      mov [ti].uFlags, 0
      mov eax, hwnd
      mov [ti].hwnd, eax
      mov eax, (TrayWnd ptr [psti]).uToolTip
      mov [ti].uId, eax
      mov eax, (TrayWnd ptr [psti]).rc
      mov [ti].rect, eax
      mov [ti].hInst, NULL
      .if ((TrayWnd ptr [pWnd]).uFlags & NIM_TIP)
        assume eax:ptr TrayWnd
        mov eax, (TrayWnd ptr [pWnd]).szTip
        mov [ti].lpszText, eax
      .else
        mov [ti].lpszText, NULL
      .endif
      invoke SendMessage, hwndToolTip, TTM_ADDTOOL, 0, addr ti
      invoke InvalidateRect, hwnd, NULL, FALSE
      mov eax, TRUE
      ret
    .elseif (wParam == NIM_MODIFY)

      invoke SearchForIcon, [edi].hwnd, [edi].uID, TRUE
      .if (!eax)
        invoke SendMessage, hwnd, LM_SYSTRAY, NIM_ADD, lParam
        ret
      .endif
      mov pWnd, eax
      .if ([edi].uFlags & NIF_MESSAGE)
        or (TrayWnd ptr [pWnd]).uFlags, NIF_MESSAGE
        mov eax, (NOTIFYICONDATA ptr [pnid]).uCallbackMessage
        mov (TrayWnd ptr [pWnd]).uCallbackMessage, eax
      .endif
      .if ((NOTIFYICONDATA ptr [pnid]).uFlags & NIF_TIP)
        or (TrayWnd ptr [pWnd]).uFlags, NIF_TIP
        mov eax, pWnd
        assume eax:ptr TrayWnd
        invoke lstrcpyn, [eax].szTip, [edi].szTip, 64
        mov [ti].cbSize, sizeof TOOLINFO
        mov eax, hwnd
        mov [ti].hWnd, eax
        mov eax, (TrayWnd ptr [pWnd]).uToolTip
        mov [ti].uId, eax
        mov [ti].hInst, NULL
        mov eax, (TrayWnd ptr [pWnd]).szTip
        mov [ti].lpszText, eax
        invoke SendMessage, hwndToolTip, TTM_UPDATETIPTEXT, 0, addr ti
      .endif
      .if ((NOTIFYICONDATA ptr [pnid]).uFlags & NIF_ICON)
        .if ((TrayWnd ptr [pWnd]).uFlags & NIF_ICON)
          mov eax, (TrayWnd ptr [pWnd]).hIcon
          invoke DestroyIcon, eax
        .endif
        assume eax:ptr NOTIFYICONDATA
        mov eax, [pnid]
        or (TrayWnd ptr [pWnd]).uFlags, NIF_ICON
        mov (TrayWnd ptr [pWnd]).hOriginalIcon, [eax].hIcon
        invoke CopyIcon, [eax].hIcon
        mov (TrayWnd ptr [pWnd]).hIcon, eax
        mov eax, (TrayWnd ptr [pWnd]).rc
        invoke InvalidateRect, hwnd, eax, FALSE
      .endif
      mov eax, TRUE
      ret
    .elseif (wParam == NIM_DELETE)
      mov eax, pnid
      assume eax:ptr NOTIFYICONDATA
      invoke SearchForIcon, [eax].hwnd, [eax].uID, FALSE
      .if (!eax)
        ret
      .endif
      mov pWnd, eax
      .if ((TrayWnd ptr [pWnd]).uFlags & NIF_ICON)
        mov eax, (TrayWnd ptr [pWnd]).hIcon
        invoke DestroyIcon, eax
      .endif
      mov [ti].cbSize, sizeof TOOLINFO
      mov eax, hwnd
      mov [ti].hWnd, eax
      mov eax, (TrayWnd ptr [pWnd]).uToolTip
      mov [ti].uId, eax
      invoke SendMessage, hwndToolTip, TTM_DELTOOL, 0, addr ti
      mov eax, pnid
      assume eax:ptr NOTIFYICONDATA
      invoke RemoveIcon, [eax].hwnd, [eax].uID
      ret
    .endif
    mov eax, FALSE
    ret
  .elseif (uMsg == WM_CREATE)
    mov cIcons, 0
    mov nSizeX, 0
    mov nSizeY, 0
    invoke CreateWindowEx, WS_EX_TOOLWINDOW or WS_EX_TOPMOST, addr szTooltipClass, 0, \
                        TTS_ALWAYSTIP, CW_USEDEFAULT, CW_USEDEFAULT, \
                        CW_USEDEFAULT, CW_USEDEFAULT, NULL, NULL, hInstance, NULL
    mov hwndToolTip, eax
    
    invoke RegisterWindowMessage, addr szRegister
    invoke PostMessage, HWND_BROADCAST, eax, 0, 0
    mov eax, 0
    ret
  .elseif (uMsg == WM_DESTROY)
    invoke DestroyWindow, hwndToolTip
    invoke FreeIconList
    
    invoke PostQuitMessage, 0
    mov eax, 0
    ret
  .elseif (uMsg == WM_ERASEBKGND)
    invoke PaintDesktop, wParam
    mov eax, TRUE
    ret
  .elseif eax == WM_LBUTTONDBLCLK
    invoke MessageHandler, hwnd, uMsg, wParam, lParam
  .elseif eax ==  WM_LBUTTONDOWN
    invoke MessageHandler, hwnd, uMsg, wParam, lParam
  .elseif eax == WM_LBUTTONUP
    invoke MessageHandler, hwnd, uMsg, wParam, lParam
  .elseif eax == WM_RBUTTONDBLCLK
    invoke MessageHandler, hwnd, uMsg, wParam, lParam
  .elseif eax == WM_RBUTTONDOWN
    invoke MessageHandler, hwnd, uMsg, wParam, lParam
  .elseif eax == WM_RBUTTONUP
    invoke MessageHandler, hwnd, uMsg, wParam, lParam
  .elseif eax == WM_MOUSEMOVE
    invoke MessageHandler, hwnd, uMsg, wParam, lParam
  .elseif eax == WM_MBUTTONDBLCLK
    invoke MessageHandler, hwnd, uMsg, wParam, lParam
  .elseif eax == WM_MBUTTONDOWN
    invoke MessageHandler, hwnd, uMsg, wParam, lParam
  .elseif eax == WM_MBUTTONUP
    invoke MessageHandler, hwnd, uMsg, wParam, lParam
  .elseif (eax == WM_MOUSEACTIVATE)
    mov eax, MA_NOACTIVATE
    ret
  .elseif eax == WM_PAINT
    mov eax, wParam
    .if (!eax)
      invoke BeginPaint, hwnd, addr ps
      mov hdc, eax
    .else
      mov hdc, eax
    .endif

    invoke SelectObject, hdcBuffer, hbmBuffer
    mov hbmBuffer, eax
    
    invoke PaintDesktop, hdc
    invoke BitBlt, hdcBuffer, 0, 0, nSizeX, nSizeY, hdc, 0, 0, SRCCOPY

    ; ebx, esi, edi
    ; loop through all the icons and redraw them
    assume  eax:ptr TrayWnd
    assume  ebx:ptr TrayWnd
    mov     eax, pHead
    .if (!eax)
      jmp Done
    .endif
@Loopz:
    mov ebx, eax
    invoke DrawIconEx, hdcBuffer, [ebx].rc.left, [ebx].rc.top, [ebx].hIcon, nTrayIcoSize, nTrayIcoSize, 0, NULL, DI_NORMAL
    mov     eax, [ebx].pNext
    test    eax, eax
    jnz     @Loopz
Done:

    invoke BitBlt, hdc, 0, 0, nSizeX, nSizeY, hdcBuffer, 0, 0, SRCCOPY
    invoke SelectObject, hdcBuffer, hbmBuffer
    mov hbmBuffer, eax

    mov eax, wParam
    .if (!eax)    
      invoke EndPaint, hwnd, addr ps
    .endif
    xor eax, eax
    ret
  .elseif eax == WM_SIZE
    mov eax, lParam
    mov nSizeX, ax
    mov nSizeY, 16 ; ah

    invoke GetDC, NULL
    mov hdc, eax
        mov eax, hdcBuffer
    .if (!eax)
      invoke CreateCompatibleDC, eax
      mov hdcBuffer, eax
    .endif
    mov eax, hbmBuffer
    .if (eax)
      invoke DeleteObject, hbmBuffer
    .endif

    invoke CreateCompatibleBitmap, hdc, nSizeX, nSizeY
    mov hbmBuffer, eax
    invoke ReleaseDC, NULL, hdc

    xor eax, eax
    ret
  .endif
  invoke DefWindowProc, hwnd, uMsg, wParam, lParam
  ret
SystrayWndProc endp

MessageHandler proc hwnd:DWORD, uMsg:DWORD, wParam:DWORD, lParam:DWORD
  LOCAL pWnd:DWORD
  LOCAL pt:POINT
  LOCAL msg:MSG
  LOCAL nid:NOTIFYICONDATA
  
  mov eax, pHead
  mov pWnd, eax
  mov eax, lParam
  mov [pt].x, al
  mov [pt].y, ah
  mov eax, hwnd
  mov [msg].hwnd, eax
  mov eax, uMsg
  mov [msg].message, eax
  mov eax, wParam
  mov [msg].wParam, eax
  mov eax, lParam
  mov [msg].lParam, eax
  invoke GetTickCount
  mov [msg].time, eax
  mov eax, pt
  mov [msg].pt, eax
  
  invoke SendMessage, hwndToolTip, TTM_RELAYEVENT, 0, addr msg
  
  .while (pWnd)
    invoke PtInRect, addr (TrayWnd ptr [pWnd]).rc, pt
    .if (eax)
      invoke IsWindow, (TrayWnd ptr [pWnd]).hwnd
      .if (!eax)
        mov [nid].cbSize, sizeof NOTIFYICONDATA
        mov eax, (TrayWnd ptr [pWnd]).hwnd
        mov [nid].hwnd, eax
        mov eax, (TrayWnd ptr [pWnd]).uID
        mov [nid].uID, eax
        mov [nid].uFlags, 0
        invoke SendMessage, hwnd, LM_SYSTRAY, NIM_DELETE, addr nid
      .elseif ((TrayWnd ptr [pWnd]).uFlags & NIF_MESSAGE)
        mov eax, pWnd
        assume eax:ptr TrayWnd
        invoke PostMessage, [eax].hwnd, [eax].uCallbackMessage, \
                          [eax].uID, uMsg
      .endif
      mov eax, 0
      ret
    .endif
    mov eax, (TrayWnd ptr [pWnd]).pNext
    mov pWnd, eax
  .endw
  mov eax, 0
  ret
MessageHandler endp


ShellTrayWndProc proc hwnd:DWORD, uMsg:DWORD, wParam:DWORD, lParam:DWORD
  LOCAL pcds:ptr COPYDATASTRUCT
  
  .if (uMsg == WM_COPYDATA)
    mov eax, dword ptr [lParam]
    mov edx, dword ptr [eax]
    mov pcds, eax
    .if (edx != 1) ;dwData
      mov eax, FALSE
      ret
    .endif
    mov eax, (COPYDATASTRUCT ptr [pcds]).lpData
    assume eax:ptr SHELTRAYDATA
    invoke SendMessage, hwndSystray, LM_SYSTRAY, (SHELLTRAYDATA ptr [eax]).dwMessage, addr (SHELLTRAYDATA ptr [eax]).nid
    ret
  .endif
  
  invoke DefWindowProc, hwnd, uMsg, wParam, lParam
  ret
ShellTrayWndProc endp

end