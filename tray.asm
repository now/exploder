.386
.model flat,stdcall

include tray.inc
include \programs\coding\compil~1\masm32\include\windows.inc
include \programs\coding\compil~1\masm32\include\kernel32.inc
include \programs\coding\compil~1\masm32\include\user32.inc
include \programs\coding\compil~1\masm32\include\gdi32.inc
include \programs\coding\compil~1\masm32\include\comctl32.inc

includelib \programs\coding\compil~1\masm32\lib\kernel32.lib
includelib \programs\coding\compil~1\masm32\lib\user32.lib
includelib \programs\coding\compil~1\masm32\lib\gdi32.lib
includelib \programs\coding\compil~1\masm32\lib\comctl32.lib

InitTray PROTO
TrayWinMain PROTO :DWORD
GetWindowFromTrayWnd    PROTO   :DWORD
GetWindowFromhWnd       PROTO   :DWORD
AddTrayItem PROTO   :DWORD,:DWORD,:DWORD,:DWORD,:DWORD,:DWORD
RemoveTrayItem PROTO :DWORD
FreeTrayWndList PROTO
RemoveOldItems PROTO
ZeroMemory PROTO :DWORD,:DWORD
CopyMemory PROTO :DWORD,:DWORD,:DWORD
ShowError PROTO :DWORD,:BOOL
lstrlenW  PROTO :DWORD
CreateTooltips PROTO :DWORD,:DWORD,:DWORD
UpdateTooltips PROTO :DWORD,:DWORD,:DWORD
RemoveTooltips PROTO :DWORD

m2m macro M1, M2
  push M2
  pop  M1
endm

.data
szClassName   BYTE  "Shell_TrayWnd", 0
szTrayIconClass BYTE  "TrayIconClass", 0
szFormat    BYTE  "%d",0
hbmBuffer   DWORD 0
hdcBuffer   DWORD 0

.data?
public hTrayWnd
public TrayTID

pHead       DWORD   ?
pCurrent    DWORD   ?
pPrev       DWORD   ?

BufferDC  DWORD ?
hTrayWnd  DWORD ?
hToolTips   DWORD   ?
TrayTID   DWORD ?

szData    BYTE 256 dup(?)
szTip       BYTE 256 dup(?)
szDispVal   BYTE 256 dup(?)

nTrayIcoSize    DWORD ?
nTrayYSize      DWORD ?
nSizeX          WORD ?
nSizeY          WORD ?

osinfo      OSVERSIONINFO <>

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

    invoke CreateThread, 0, 0, addr TrayWinMain, 0, 0, addr TrayTID
    .IF (!eax)
      invoke ShowError, addr szThreadErr, FALSE
    .ENDIF
    mov TrayTID, eax
    ret

InitTray endp

TrayWinMain proc dummy:DWORD
  LOCAL wc:WNDCLASS
  LOCAL msg:MSG
  LOCAL dc:DWORD

  mov wc.cbWndExtra, 0
  mov wc.cbClsExtra, 0
  mov wc.style, CS_HREDRAW or CS_VREDRAW or CS_DBLCLKS
  mov wc.lpfnWndProc, offset TrayWndProc
  mov eax, hInstance
  mov wc.hInstance, eax
  mov wc.hbrBackground, COLOR_BTNFACE+1
  mov wc.lpszMenuName, 0
  mov wc.lpszClassName, offset szClassName
  mov wc.hIcon, NULL
  mov wc.hCursor, NULL
  
  invoke RegisterClass, addr wc
  .IF (!eax)
    invoke ShowError, offset szRegClsErr, FALSE
  .ENDIF
  

  mov wc.style, CS_DBLCLKS
  mov wc.lpfnWndProc, offset WndProcIcon
  mov wc.lpszClassName, offset szTrayIconClass
  invoke RegisterClass, addr wc
  .IF (!eax)
    invoke ShowError, offset szRegClsErr, FALSE
  .ENDIF
  
    invoke  GetSystemMetrics, SM_CXSMICON
    mov     nTrayIcoSize, eax
    mov     nTrayYSize, eax
  
  invoke GetSystemMetrics, SM_CYSIZE
  mov esi, eax
  invoke GetSystemMetrics, SM_CYSIZEFRAME
  add eax, eax
  add esi, eax
  mov nTrayYSize, esi
  
    ;invoke GetSystemMetrics, SM_CYSIZEFRAME
    ;add     eax ,eax
    ;add     eax, 2
    ;add     nTrayYSize, eax
    invoke GetSystemMetrics, SM_CXSCREEN
  mov ebx, eax
  mov ecx, 6
  xor edx, edx
  div ecx
  mov esi, eax  ; esi is the tray width
  sub eax, 5    ; length of tray is 1/6 of the screen - 5 pixels
  sub ebx, eax  ; x of tray

  invoke GetSystemMetrics, SM_CYSCREEN
  sub eax, nTrayYSize

    invoke CreateWindowEx, WS_EX_TOOLWINDOW, \
      addr szClassName, 0, WS_POPUP or WS_VISIBLE, \
            ebx, eax, esi, nTrayYSize, hWndMain, 0, hInstance, 0
  mov hTrayWnd, eax
  
    invoke  CreateWindowEx, WS_EX_TOPMOST, addr szTooltipClass,0,TTS_ALWAYSTIP,CW_USEDEFAULT,CW_USEDEFAULT,CW_USEDEFAULT,CW_USEDEFAULT, 0,0,hInstance,0
    mov hToolTips, eax
    ;Code doesn't work :(
;    invoke GetDC, eax
; mov   dc, eax
; invoke  CreateCompatibleDC, eax
; mov   BufferDC, eax
; invoke  ReleaseDC, hTrayWnd, dc
    invoke SetWindowPos, hTrayWnd, 0, 0, 0, 0, 0, SWP_NOACTIVATE or SWP_NOMOVE or SWP_NOSIZE or SWP_NOZORDER

    invoke  GlobalAlloc, GPTR, sizeof TrayWnd
    mov pHead, eax
    xor eax,eax
    mov pPrev, eax
    mov pCurrent, eax
    .WHILE TRUE
      invoke GetMessage, addr msg, 0, 0, 0
      .BREAK .IF (!eax)
      invoke TranslateMessage, addr msg
      invoke DispatchMessage, addr msg
  .ENDW

  invoke FreeTrayWndList
  invoke ExitThread, msg.wParam
  ret
    
TrayWinMain endp

TrayWndProc proc hWnd:DWORD, uMsg:DWORD, wParam:DWORD, lParam:DWORD
  LOCAL icnData:DWORD
  LOCAL icnWnd:DWORD
  LOCAL tIcon:DWORD
  LOCAL mess:DWORD
  LOCAL uid:DWORD
  LOCAL needTrayPack:BYTE
  LOCAL r:RECT
  LOCAL ps:PAINTSTRUCT
  LOCAL hdc:DWORD
  LOCAL hIcon:DWORD
  LOCAL x:DWORD
  LOCAL y:DWORD
  
  assume ebx:ptr NOTIFYICONDATA
  assume edi:ptr TrayWnd

  pusha
  mov eax, uMsg
  .IF eax==WM_DESTROY

    invoke PostQuitMessage, 0

  .ELSEIF eax==X_EXIT

    ;int 3
    invoke DestroyWindow, hTrayWnd

  .elseif eax == WM_SIZE
 
    mov eax, lParam
    mov nSizeX, ax
    mov nSizeY, 16 ; ah
    ;m2m nSizeX, lParam[0]
    ;m2m nSizeY, lParam[2]

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
    
  .elseif eax == WM_PAINT

    mov eax, wParam
    .if (!eax)
      invoke BeginPaint, hWnd, addr ps
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
    invoke GetWindowLong, [ebx].trayWnd, GWL_USERDATA
    .if (eax)
      invoke DrawIconEx, hdcBuffer, [ebx].x, [ebx].y, eax, nTrayIcoSize, nTrayIcoSize, 0, NULL, DI_NORMAL
    .endif
    mov     eax, [ebx].next
    test    eax, eax
    jnz     @Loopz
Done:

    invoke BitBlt, hdc, 0, 0, nSizeX, nSizeY, hdcBuffer, 0, 0, SRCCOPY
    invoke SelectObject, hdcBuffer, hbmBuffer
    mov hbmBuffer, eax

    mov eax, wParam
    .if (!eax)    
      invoke EndPaint, hWnd, addr ps
    .endif
    xor eax, eax
    ret

  .elseif eax == WM_ERASEBKGND

    mov eax, wParam
    invoke PaintDesktop, eax
    mov eax, 1
    ret

  .ELSEIF eax==WM_COPYDATA

    mov esi, dword ptr [lParam]
    mov edx, dword ptr [esi]
    .IF edx == 1  ;d->dwData
      mov edx, dword ptr [esi+8] ;lpData
      lea ebx, [edx+8] ;lpData+8
      mov icnData, ebx
      mov edx, dword ptr [edx+4]  ;lpData+4
      .IF edx == NIM_ADD
        assume ebx:ptr NOTIFYICONDATA
        mov     edx, dword ptr [ebx+4]
        invoke  GetWindowFromhWnd, edx
        test    eax, eax
        jz      @HwndNotFound
        mov     edx, dword ptr [ebx+8]
        cmp     edx, dword ptr [eax+16] ;uID comparison [eax+16] == TrayWnd.uID
        jz      @IconExists
@HwndNotFound:
        mov   edx, dword ptr [ebx].uFlags ;NOTIFYICONDATA->uFlags
        test  edx, NIF_MESSAGE
        jz    @NOT_NIF_MESSAGE
        mov eax, dword ptr [ebx].uCallbackMessage
        mov mess, eax
@NOT_NIF_MESSAGE:
        test  edx, NIF_TIP
        jz    @NOT_NIF_TIP
                invoke  ZeroMemory, addr szTip, sizeof szTip
                mov     osinfo.dwOSVersionInfoSize, sizeof OSVERSIONINFO
                invoke  GetVersionEx, addr osinfo
                .IF osinfo.dwPlatformId == VER_PLATFORM_WIN32_NT
                    invoke  lstrlenW, addr [ebx].szTip
                    invoke  WideCharToMultiByte, CP_ACP, 0,addr [ebx].szTip, eax, addr szTip, sizeof szTip, 0,0
                .ELSE
                    invoke  lstrcpy, addr szTip, addr [ebx].szTip
                .ENDIF

@NOT_NIF_TIP:       
        invoke  CreateWindowEx, WS_EX_TRANSPARENT, addr szTrayIconClass, 0, WS_CHILD, 4,3,nTrayIcoSize,nTrayIcoSize,hWnd, 0,hInstance,0
        mov   icnWnd, eax
        test  eax, eax
        jnz   @CreateWindowOk
        invoke ShowError, offset szTrayIconClass, FALSE
@CreateWindowOk:
        test  edx, NIF_ICON
        ;jz   @NOT_NIF_ICON
        invoke  CopyIcon, [ebx].hIcon
        mov   tIcon, eax
@NOT_NIF_ICON:
        invoke  SetWindowLong, icnWnd, GWL_USERDATA, tIcon
                mov     edx, [ebx].uID  ;uID
                mov     ebx, [ebx].hwnd  ;hWnd
                invoke  AddTrayItem, icnWnd, ebx, edx, mess, tIcon, addr szTip
                mov     edx, dword ptr [eax+20]
                mov     ebx, dword ptr [eax+24]
                invoke  SetWindowPos, icnWnd, 0, edx, ebx, 0, 0, SWP_NOZORDER or SWP_NOSIZE
                invoke  ShowWindow, icnWnd, SW_SHOWNORMAL

            ;NIM_MODIFY
            .ELSEIF edx == NIM_MODIFY
                invoke  GetWindowFromhWnd, [ebx].hwnd
                test    eax, eax
                jz      @NoSuchWindow
@IconExists:
                mov     edi, eax
                mov needTrayPack, 0
                mov     eax, [edi].Message
                mov     mess, eax                
                mov     eax, [edi].hIcon
                mov     tIcon, eax
                mov     edx, dword ptr [ebx].uFlags
                test    edx, NIF_MESSAGE            ;Is it finding any of the flags?
                jz      @NOMESSAGE
                mov     ecx, [ebx].uCallbackMessage
                test    ecx, ecx
                jz      @NOMESSAGE
                mov     mess, ecx
@NOMESSAGE:
                test    edx, NIF_ICON
                jz      @NOICON
                mov     ecx, [ebx].hIcon
                test    ecx, ecx
                jz      @NOICON
                .IF tIcon != NULL
      push ecx
                    invoke  DestroyIcon, tIcon
      pop ecx
                .ENDIF
                invoke  CopyIcon, ecx
                mov     tIcon, eax
                ;mov     needTrayPack, 1 Rude: why do you need a tray pack here? without this line nim_modify works
                
@NOICON:
        test  edx, NIF_TIP
        jz    @NOTTIP
                invoke  ZeroMemory, addr szTip, sizeof szTip
                mov     osinfo.dwOSVersionInfoSize, sizeof OSVERSIONINFO
                invoke  GetVersionEx, addr osinfo
                .IF osinfo.dwPlatformId == VER_PLATFORM_WIN32_NT
                    invoke  lstrlenW, addr [ebx].szTip
                    invoke  WideCharToMultiByte, CP_ACP, 0,addr [ebx].szTip, eax, addr szTip, sizeof szTip, 0,0
                .ELSE
                    invoke  lstrcpy, addr szTip, addr [ebx].szTip
                .ENDIF
@NOTTIP:
                mov     eax, mess           ;Has edi changed from the start of the NIM_MODIFY handler? do i need to save it?
                mov     [edi].Message, eax
                mov     eax, tIcon
                mov     [edi].hIcon, eax
                mov     eax, [ebx].uID
                mov     [edi].uID, eax
                cmp     byte ptr szTip, 0
                jz      @NONEWTIP
                invoke  lstrcpy, addr [edi].szTip, addr szTip
@NONEWTIP:
    invoke  SetWindowLong, [edi].trayWnd, GWL_USERDATA, tIcon
                .IF needTrayPack == 1
                    invoke  RemoveOldItems
                .ENDIF
                ;invoke  GetWindowRect, [edi].trayWnd, addr r    ;Is it ok to call GetWindowRect here, or do i need to do it earlier?
                mov eax, nTrayIcoSize
                mov r.bottom, eax
                mov r.left, 0
                mov r.top, 0
                mov r.right, eax
                test    edx, NIF_TIP
                jz  @NOTIP2
                invoke UpdateTooltips, [edi].trayWnd, addr [edi].szTip, addr r
@NOTIP2:
                invoke  InvalidateRect, [edi].trayWnd, addr r, TRUE
@NoSuchWindow:

            ;NIM_DELETE
            .ELSEIF edx == NIM_DELETE
        invoke  RemoveTrayItem, [ebx].hwnd
                invoke  RemoveOldItems
      .ENDIF      

    .ENDIF
  .ELSEIF eax==WM_ACTIVATEAPP
      jmp @@wm_activate
      
  .ELSEIF eax==WM_MOUSEACTIVATE
      jmp @@wm_activate

  .ELSEIF eax==WM_ACTIVATE
    @@wm_activate:
    .IF ( wParam )
      mov eax, MA_NOACTIVATE
      ret
    .ENDIF
    
  .ELSE
    popa
    invoke DefWindowProc, hWnd, uMsg, wParam, lParam
    ret
  .ENDIF
  
  popa
  xor eax, eax
  ret
  
TrayWndProc endp

WndProcIcon proc uses edx hWnd:DWORD, uMsg:DWORD, wParam:DWORD, lParam:DWORD
;  LOCAL hIcon:DWORD
;  LOCAL hDC:DWORD
;  LOCAL ps:PAINTSTRUCT
  
  mov eax, uMsg
;  .IF eax == WM_PAINT
;    invoke BeginPaint, hWnd, addr ps
;    mov hDC, eax
;    invoke GetWindowLong, hWnd, GWL_USERDATA
;    mov hIcon, eax
;    invoke DrawIconEx, hDC, 0, 0, hIcon, nTrayIcoSize, nTrayIcoSize, 0, NULL, DI_NORMAL
;    invoke  EndPaint, hWnd, addr ps
;    xor eax, eax
;  .IF eax == WM_ERASEBKGND
;    push 1
;    pop eax
  .IF eax == WM_CREATE
    invoke ShowWindow, hWnd, SW_HIDE
    xor eax, eax
  .ELSEIF eax ==  WM_LBUTTONDBLCLK
    jmp @PassToApp
  .ELSEIF eax ==  WM_LBUTTONDOWN
    jmp @PassToApp
  .ELSEIF eax == WM_LBUTTONUP
    jmp @PassToApp
  .ELSEIF eax == WM_RBUTTONDBLCLK
    jmp @PassToApp
  .ELSEIF eax == WM_RBUTTONDOWN
    jmp @PassToApp
  .ELSEIF eax == WM_RBUTTONUP
    jmp @PassToApp
  .ELSEIF eax == WM_MOUSEMOVE
    jmp @PassToApp
  .ELSEIF eax == WM_MBUTTONDBLCLK
    jmp @PassToApp
  .ELSEIF eax == WM_MBUTTONDOWN
    jmp @PassToApp
  .ELSEIF eax == WM_MBUTTONUP
    jmp @PassToApp
  .ELSEIF eax == WM_KEYUP or WM_KEYDOWN
    invoke  PostMessage, hTrayWnd, eax, wParam, lParam
  .ELSEIF eax == WM_SYSCOMMAND
    mov edx, wParam
    .IF edx == SC_CLOSE
       invoke  PostMessage, hTrayWnd, WM_KEYDOWN, 8889,0
       xor eax, eax
    .ELSE
       jmp @DefProc
    .ENDIF
  .ELSE
@DefProc:
    invoke DefWindowProc, hWnd, eax, wParam, lParam
  .ENDIF
  ret
@PassToApp:
  invoke  GetWindowFromTrayWnd, hWnd
  test    eax, eax
  jz      @WindowNotFound
  assume  eax:ptr TrayWnd
  mov     ebx, eax
  invoke  IsWindow, [eax].hwnd
  test    eax, eax
  jz      @WindowDoesntExist    
  mov     eax, ebx
  mov     ebx, [eax].hwnd
  mov     edx, [eax].Message
  mov     eax, [eax].uID
  invoke  SendMessage, ebx, edx,eax,uMsg
  jmp     @WindowNotFound
@WindowDoesntExist:
  invoke  RemoveTrayItem, [eax].hwnd
@WindowNotFound:
  xor     eax, eax
  ret
WndProcIcon endp

AddTrayItem proc uses ebx edx trayWnd:DWORD, hWnd:DWORD, uID:DWORD, Message:DWORD, hIcon:DWORD, lpTip:DWORD
    LOCAL   r:RECT
    assume  eax:ptr TrayWnd
    assume  edx:ptr TrayWnd

    mov     eax, dword ptr [pHead]
    mov     edx, pCurrent
    test    edx, edx
    jnz     @ListInitialized
    mov     pCurrent, eax
    mov     [eax].x, 0   ;Set TrayWnds.x to 0
    jmp     @ListInitOk
@ListInitialized:
    invoke  RemoveOldItems
    invoke  GlobalAlloc, GPTR, sizeof TrayWnd   ;Allocate the new node of the linked list
    mov     pCurrent, eax
    mov     edx, pPrev
    mov     [edx].next, eax
    mov     ebx, [edx].x
    add     ebx, nTrayIcoSize
    add     ebx, 2
    mov     [eax].x, ebx
@ListInitOk:
    mov     edx, trayWnd
    mov     [eax].trayWnd, edx
    mov     edx, hWnd
    mov     [eax].hwnd, edx
    mov     edx, Message
    mov     [eax].Message, edx
    mov     edx, uID
    mov     [eax].uID, edx
    mov     edx, hIcon
    mov     [eax].hIcon, edx
    mov     pPrev, eax    
    mov     dl, byte ptr [lpTip]
    test    dl, dl
    jz      @NoTip
    invoke  lstrcpy, addr [eax].szTip, lpTip
    invoke  GetClientRect, trayWnd, addr r
    invoke  CreateTooltips, trayWnd, lpTip, addr r
    mov     eax, pPrev
@NoTip:
    ret
AddTrayItem endp

RemoveTrayItem proc uses ebx edx edi hWnd:DWORD
  assume  eax:ptr TrayWnd
  assume  ebx:ptr TrayWnd
    mov   ebx, pHead
    test    ebx, ebx
    mov     eax, ebx
    jz      @LocalRet
@Loopz:
    mov   edx, [ebx].hwnd
  .IF edx == hWnd
        mov edi, [ebx].next
        mov [eax].next, edi
        invoke  DestroyWindow, [ebx].trayWnd
        invoke  RemoveTooltips, [ebx].trayWnd
        invoke  DestroyIcon, [ebx].hIcon
        .IF ebx == pHead        ;If we're deleting the head
            .If edi == NULL     ;if the head is now the only element in the list, just zero the memory, don't free it
                mov     pCurrent, 0
                invoke  ZeroMemory, ebx, sizeof TrayWnd
                jmp     @LocalRet
            .ELSE
                mov pHead, edi      ;replace the head with the pointer to the next element
            .ENDIF
        .ENDIF
        invoke  GlobalFree, ebx ;Free the memory for the node
        jmp     @LocalRet
  .ENDIF
    mov     eax, ebx
  mov   ebx, [ebx].next
  test    ebx, ebx
    jnz   @Loopz
@LocalRet:
  ret
RemoveTrayItem endp

GetWindowFromhWnd proc uses edx ebx hWnd:DWORD
    ;returns: pointer to struct if successful, 0 if not
    assume  eax:ptr TrayWnd
    mov     edx, hWnd
    mov     eax, pHead
@Loopz:
    mov     ebx, [eax].hwnd
    .IF edx == ebx
        jmp ProcRet
    .ENDIF
    mov     eax, [eax].next
    test    eax, eax
    jnz     @Loopz
ProcRet:
    ret
GetWindowFromhWnd endp

GetWindowFromTrayWnd proc uses edx ebx tWnd:DWORD
    ;returns: pointer to struct if successful, 0 if not
    assume  eax:ptr TrayWnd
    
    mov     edx, tWnd
    mov     eax, pHead
@Loopz:
    mov     ebx, [eax].trayWnd
    .IF edx == ebx
        jmp ProcRet
    .ENDIF
    mov     eax, [eax].next
    test    eax, eax
    jnz     @Loopz
ProcRet:
    ret
GetWindowFromTrayWnd endp

RemoveOldItems proc uses edx edi
    LOCAL   r:RECT
    LOCAL   x:DWORD ;only X for now, Y never changes
    assume  edi:ptr TrayWnd

    mov     edi, pHead
@TestWindows:
    invoke  IsWindow, [edi].hwnd
    .IF eax != TRUE
        invoke  RemoveTrayItem, [edi].hwnd
    .ENDIF
    mov     edi, [edi].next
    test    edi, edi
    jnz     @TestWindows

    mov     x, 0
    mov     edi, pHead
@MoveWindows:
    invoke  GetWindowRect, [edi].trayWnd, addr r
    mov     eax, x
    cmp     eax, r.left
    jz      @NoChange
    mov     [edi].x, eax
    invoke  SetWindowPos, [edi].trayWnd, 0,[edi].x, [edi].y, 0,0,SWP_NOZORDER or SWP_NOSIZE
    ;invoke  SendMessage, [edi].trayWnd, WM_PAINT,0,0
@NoChange:
    mov     eax, x
    add     eax, nTrayIcoSize
    add     eax, 2
    mov     x, eax
    mov     edi, [edi].next
    test    edi, edi
    jnz     @MoveWindows

    ret
RemoveOldItems endp

FreeTrayWndList proc uses edx
; BUG BUG BUG BUG: memory leak (smartcheck claims pHead is not being freed)
  assume  eax:ptr TrayWnd
  mov   eax, pHead
  mov   eax, [eax].next
@Loop:
  test  eax, eax
  jz @Error
  mov   edx, [eax].next
  invoke  GlobalFree, eax
  mov   eax, edx
  jmp   @Loop
@Error:

  ret
FreeTrayWndList endp

CreateTooltips proc uses ebx hWnd:DWORD, lpTxt:DWORD, r:DWORD
    LOCAL   ti:TOOLINFO
    .IF(!hToolTips)
        ret
    .ENDIF

    mov ti.cbSize, sizeof TOOLINFO
    mov ti.uFlags, TTF_SUBCLASS
    mov eax, hWnd
    mov ti.hWnd, eax
    mov eax, hInstance
    mov ti.hInst, eax
    mov ti.uId, 0
    mov eax, lpTxt
    mov ti.lpszText, eax
    invoke  CopyMemory, addr ti.rect, r, sizeof RECT
    invoke  SendMessage, hToolTips, TTM_ADDTOOL, 0,addr ti
    ret
CreateTooltips endp

RemoveTooltips proc hWnd:DWORD
    LOCAL   ti:TOOLINFO
    LOCAL   r:RECT

    mov ti.cbSize, sizeof TOOLINFO
    mov ti.uFlags, 0
    mov eax, hWnd
    mov ti.hWnd, eax
    mov eax, hInstance
    mov ti.hInst, eax
    mov ti.uId, 0
    mov ti.lpszText, 0
    invoke  CopyMemory, addr ti.rect, addr r, sizeof RECT
    invoke  SendMessage, hToolTips, TTM_DELTOOL, 0,addr ti
    ret
RemoveTooltips endp

UpdateTooltips proc uses ebx hWnd:DWORD, lpTxt:DWORD, r:DWORD
    LOCAL   ti:TOOLINFO
    .IF(!hToolTips)
        ret
    .ENDIF
    invoke  ZeroMemory, addr szTip, sizeof szTip
    invoke  lstrcpy, addr szTip, lpTxt

    mov ti.cbSize, sizeof TOOLINFO
    mov ti.uFlags, TTF_SUBCLASS
    mov eax, hWnd
    mov ti.hWnd, eax
    mov eax, hInstance
    mov ti.hInst, eax
    mov ti.uId, 0
    mov eax, offset szTip
    mov ti.lpszText, eax
    invoke  CopyMemory, addr ti.rect, r, sizeof RECT
    invoke  SendMessage, hToolTips, TTM_UPDATETIPTEXT, 0,addr ti
    ret
UpdateTooltips endp
end