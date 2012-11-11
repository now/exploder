.386
.model flat,stdcall

ZeroMemory PROTO :DWORD,:DWORD
CopyMemory PROTO :DWORD,:DWORD,:DWORD



.code
ZeroMemory proc uses edi ecx edx ebx loc:DWORD, len:DWORD
    mov edi, loc
    mov edx, len
    xor eax, eax
    mov ecx, edx    
    shr ecx, 2      ;ecx == len/4
    mov ebx, ecx
    shl ebx, 2
    sub edx, ebx    ;edx == remainder after len/4 (6 clocks for div & get remainder)
    rep stosd
    mov ecx, edx
    rep stosb
    ret
ZeroMemory endp

CopyMemory proc uses edi esi edx ecx ebx dest:DWORD, src:DWORD, len:DWORD
    mov edi, dest
    mov esi, src
    mov edx, len
    mov ecx, edx
    shr ecx, 2
    mov ebx, ecx
    shl ebx, 2
    sub edx, ebx    ;edx == remainder after len/4 (6 clocks for div & get remainder)
    rep movsd
    mov ecx, edx
    rep movsb       ;This will never be more than 3, sor a movsb is PLENTY fast enough
    ret
CopyMemory endp

end