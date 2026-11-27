<# : parte batch (PowerShell la ve como comentario)
@echo off
setlocal
copy /y "%~f0" "%TEMP%\soporte-marco-instalar.ps1" >nul
powershell -NoProfile -ExecutionPolicy Bypass -File "%TEMP%\soporte-marco-instalar.ps1" -Modo instalar
exit /b
#>
param(
    [ValidateSet('sesion', 'instalar', 'vigilar', 'limpiar', 'desinstalar', 'comprobar', 'activarEspera', 'quitarEspera')]
    [string]$Modo = 'sesion',
    [int]$IdProceso = 0
)

# Soporte Marco: sesion de soporte remoto temporal.
# Solo ASCII en este archivo (PowerShell 5.1 lee los .ps1 sin BOM como ANSI).
#
#   instalar    : primera vez. Pide el codigo, crea el icono y las tareas.
#   sesion      : lo dispara el icono. Si Marco abrio una sesion, conecta todo.
#   vigilar     : proceso oculto que limpia si se cierra la ventana.
#   limpiar     : revierte todo lo que hizo la sesion.
#   desinstalar : quita el icono, las tareas y los archivos.
#   comprobar   : modo desatendido. Mira si Marco abrio una sesion y, si es asi, la inicia sola.
#   activarEspera / quitarEspera : enciende o apaga el modo desatendido en esta PC.

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$Buzon        = 'https://api.github.com/repos/Cocho92/soporte/contents/s'
$ClavePublica = 'ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAICFjzEzTLqUAgHl8P5IpFY7DivxIDlOba4EK5wZU2QBY soporte-claude'
$MarcaClave   = 'soporte-claude'
$Palabras     = 'abeja abril abuelo aceite acelga agua aguila aire albanil alfombra almeja almohada amarillo amigo anana anteojo apio arana arbol arco arcoiris arena armario arpa arroyo arroz arveja asado auto avena avion avispa ayer azucar azul babosa balcon balde ballena banana banco bandeja barco barro batata bateria batidor baul beige bermuda bici birome bizcocho blanco boca bolsillo bombero bosque bota bote botella boton brazo budin bufanda buho burro buzo caballo cabeza cabra cadera cafetera cajon calamar calcetin caldo calefon calle cama camaron camello camion camisa campera canario canasto candado cangrejo cara caracol carpeta carro cartera cartero casa casco catre cebolla cebra ceja celeste cerdo cereal cereza cerro cesta chaleco chaucha choclo chofer chorizo cielo cierre ciervo ciguena cintura cinturon ciruela clavo cochera cocina cocinero coco codo cofre cohete colador colcha colina comoda compas condor conejo copa corbata cordero cortina cuaderno cuadro cuchara cucharon cuchillo cuello cuervo cuna damasco dedo delfin diente dorado dulce durazno embudo empanada ensalada escalera escoba escuadra escuela espalda espejo espiga espinaca estante estrella estufa falda faro fideo flan flauta flor florero foca fosforo frasco frazada freezer frente frutilla fuego fuente galleta gallina gallo ganso garage garbanzo gasista gato globo goma gorila gorra gorrion granizo granja grillo gris guante guiso guitarra gusano halcon harina heladera helado hermano herrero higo hija hijo hoja hombro hora hormiga horno hospital huevo iglesia iguana invierno isla jabali jamon jardin jarra jarron jilguero jirafa juez kiwi labio lagarto lago laguna lampara lancha langosta lapiz lata leche lechon lechuga lechuza lengua lenteja leon libro liebre limon linterna llama llanura llave llavero lluvia lobo loro luna lunes maceta madre maestro manana manga manguera mano manta manteca mantel manzana mapa mariposa marron martes martillo mayo mecanico media medico medusa mejilla mejillon melon menton mercado mesa miel milanesa minuto mochila molino mono montana morron mosca moto mozo mula muneca museo naranja nariz negro niebla nieto nieve noche nube ojota olla oreja oruga otono oveja padre pajaro pala paloma palta panadero pantalon pantera papa paraguas pared parque pasillo pasto patin patio pato pava pavo pecho pelota pepino pera perchero perro pesa pestana piano piedra pierna pila pimienta pintor pinza piso pizarra pizza plancha plateado plato playa plaza plomero polenta policia pollera pollo pomelo poroto potro pozo primo profesor puente puerro puerta pulpo puma queso rabano raiz rallador rama rana raqueta raton ravioles rayo regadera regla reloj remera remo repisa roca rocio rodilla rojo ropero rosa sabana saco salame sandalia sandia sapo sarten sastre sello selva semana semilla serrucho silla sillon sobre sobrino sofa soga sombrero sopa subte suegro tacho taladro tallarin talon tambor tarde tarro tarta taxi taza teatro techo tenedor termo ternero tetera tiburon tienda tierra tigre tijera tiza toalla tobillo tomate tornillo torre torta tortuga tractor tren triciclo trompeta tronco trueno tucan vaca valija valle vaso vecino vela velador venado ventana verano verde vereda vestido viento vinagre violeta violin yegua yerno yogur zapallo zapatero zapato zorro' -split ' '    # lista para validar el codigo y evitar errores de tipeo

$DirProg       = Join-Path $env:ProgramFiles 'SoporteMarco'
$DirDatos      = Join-Path $env:ProgramData 'SoporteMarco'
$RutaScript    = Join-Path $DirProg 'soporte.ps1'
$ArchPc        = Join-Path $DirDatos 'pc.json'
$ArchEstado    = Join-Path $DirDatos 'estado.json'
$ArchInfo      = Join-Path $DirDatos 'info.json'
$ArchCerrar    = Join-Path $DirDatos 'cerrar'
$ArchLog       = Join-Path $DirDatos 'ultimo.log'
$ArchUltima    = Join-Path $DirDatos 'ultima-sesion'
$DirTmp        = Join-Path $DirDatos 'tmp'
$Tarea         = 'SoporteMarco'
$TareaLimpieza = 'SoporteMarco-Limpieza'
$TareaEspera   = 'SoporteMarco-Espera'
$ReglaFw       = 'SoporteMarco-SSH'
$ReglaFwPantalla = 'SoporteMarco-RustDesk'
$PowerShellExe = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
$TsExe         = Join-Path $env:ProgramFiles 'Tailscale\tailscale.exe'
$DirSsh        = Join-Path $env:ProgramData 'ssh'
$ArchClaves    = Join-Path $DirSsh 'administrators_authorized_keys'
$ArchSshd      = Join-Path $DirSsh 'sshd_config'
$ArchSshdBak   = Join-Path $DirSsh 'sshd_config.soporte-original'

# ---------------------------------------------------------------- utilidades

function Es-Admin {
    $p = [Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()
    return $p.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Decir([string]$texto, [string]$color = 'Gray') { Write-Host $texto -ForegroundColor $color }

function Ahora-Unix { return [int64](([DateTime]::UtcNow - [DateTime]'1970-01-01').TotalSeconds) }

function Hora-Local([int64]$unix) { return ([DateTime]'1970-01-01').AddSeconds($unix).ToLocalTime() }

function Hmac([byte[]]$clave, [byte[]]$datos) {
    $h = New-Object System.Security.Cryptography.HMACSHA256 -ArgumentList (, $clave)
    try { return , $h.ComputeHash($datos) } finally { $h.Dispose() }
}

function Derivar([byte[]]$secreto, [string]$uso) {
    return , (Hmac $secreto ([Text.Encoding]::ASCII.GetBytes($uso)))
}

function A-Hex([byte[]]$b) { return (($b | ForEach-Object { $_.ToString('x2') }) -join '') }

function A-Base32([byte[]]$b) {
    $abc = 'abcdefghijklmnopqrstuvwxyz234567'
    $sb = New-Object System.Text.StringBuilder
    $val = 0; $bits = 0
    foreach ($x in $b) {
        $val = ($val -shl 8) -bor $x
        $bits += 8
        while ($bits -ge 5) {
            [void]$sb.Append($abc[($val -shr ($bits - 5)) -band 31])
            $bits -= 5
        }
        $val = $val -band ((1 -shl $bits) - 1)
    }
    if ($bits -gt 0) { [void]$sb.Append($abc[($val -shl (5 - $bits)) -band 31]) }
    return $sb.ToString()
}

function Secreto-Pc {
    $pc = Get-Content -LiteralPath $ArchPc -Raw | ConvertFrom-Json
    return , ([Text.Encoding]::ASCII.GetBytes([string]$pc.secreto))
}

# Normaliza el codigo tipeado igual que la notebook: minusculas, sin acentos ni la letra ene,
# palabras separadas por un solo espacio. Asi da igual escribir con espacios, guiones o mayusculas.
function Canonico([string]$texto) {
    $d = ($texto.ToLowerInvariant()).Normalize([Text.NormalizationForm]::FormD)
    $sb = New-Object System.Text.StringBuilder
    foreach ($ch in $d.ToCharArray()) {
        if ([Globalization.CharUnicodeInfo]::GetUnicodeCategory($ch) -ne [Globalization.UnicodeCategory]::NonSpacingMark) {
            [void]$sb.Append($ch)
        }
    }
    $palabras = [regex]::Matches($sb.ToString(), '[a-z]+') | ForEach-Object { $_.Value }
    return ($palabras -join ' ')
}

# Clave maestra (hex) derivada del codigo con PBKDF2-HMAC-SHA1. Debe coincidir con la notebook.
function Maestro-De-Codigo([string]$codigo) {
    $pass = [Text.Encoding]::ASCII.GetBytes((Canonico $codigo))
    $salt = [Text.Encoding]::ASCII.GetBytes('SoporteMarco/claves/v2')
    $kdf = New-Object System.Security.Cryptography.Rfc2898DeriveBytes($pass, $salt, 300000)
    try { $bytes = $kdf.GetBytes(32) } finally { $kdf.Dispose() }
    return (A-Hex $bytes)
}

# Sobre = base64( iv[16] + AES-256-CBC(json) + HMAC-SHA256(iv+cifrado)[32] )
function Abrir-Sobre([string]$b64, [byte[]]$secreto) {
    $raw = [Convert]::FromBase64String($b64.Trim())
    $n = $raw.Length
    if ($n -lt 64) { throw 'sobre demasiado corto' }
    $cuerpo = New-Object byte[] ($n - 32)
    [Array]::Copy($raw, 0, $cuerpo, 0, $n - 32)
    $esperada = A-Hex (Hmac (Derivar $secreto 'firma') $cuerpo)
    $recibida = A-Hex ([byte[]]$raw[($n - 32)..($n - 1)])
    if ($esperada -ne $recibida) { throw 'la firma del sobre no coincide' }
    $aes = [System.Security.Cryptography.Aes]::Create()
    try {
        $aes.Mode = [System.Security.Cryptography.CipherMode]::CBC
        $aes.Padding = [System.Security.Cryptography.PaddingMode]::PKCS7
        $aes.Key = Derivar $secreto 'cifrado'
        $aes.IV = [byte[]]$raw[0..15]
        $dec = $aes.CreateDecryptor()
        $claro = $dec.TransformFinalBlock($raw, 16, $n - 48)
    } finally { $aes.Dispose() }
    return ([Text.Encoding]::UTF8.GetString($claro) | ConvertFrom-Json)
}

function Buscar-Sobre([byte[]]$secreto) {
    $id = (A-Hex (Derivar $secreto 'buzon')).Substring(0, 32)
    try {
        $r = Invoke-WebRequest -UseBasicParsing -Uri "$Buzon/$id" -TimeoutSec 20 `
            -UserAgent 'soporte-marco' -Headers @{ Accept = 'application/vnd.github.raw' }
    } catch { return $null }
    $texto = $r.Content
    if ($texto -is [byte[]]) { $texto = [Text.Encoding]::ASCII.GetString($texto) }
    try { $sobre = Abrir-Sobre $texto $secreto } catch { return $null }
    if ([int64]$sobre.vence -le (Ahora-Unix)) { return $null }
    return $sobre
}

function Guardar-Estado($estado) {
    $estado | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $ArchEstado -Encoding ASCII
}

function Leer-Estado {
    if (-not (Test-Path -LiteralPath $ArchEstado)) { return $null }
    try { return (Get-Content -LiteralPath $ArchEstado -Raw | ConvertFrom-Json) } catch { return $null }
}

# Ejecuta un programa externo sin que su salida de error corte el script.
function Ejecutar([string]$exe, [string[]]$argumentos) {
    $previo = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        $salida = & $exe @argumentos 2>&1 | Out-String
        return @{ Codigo = $LASTEXITCODE; Salida = $salida.Trim() }
    } finally { $ErrorActionPreference = $previo }
}

function Bajar([string]$url, [string]$destino) {
    Invoke-WebRequest -UseBasicParsing -Uri $url -OutFile $destino -UserAgent 'soporte-marco' -TimeoutSec 600
}

function Usuario-Interactivo {
    $u = $null
    try { $u = (Get-CimInstance Win32_ComputerSystem).UserName } catch { }
    if (-not $u) { $u = [Security.Principal.WindowsIdentity]::GetCurrent().Name }
    return $u
}

function Arquitectura {
    $a = $env:PROCESSOR_ARCHITEW6432
    if (-not $a) { $a = $env:PROCESSOR_ARCHITECTURE }
    return $a
}

# Un clic dentro de la consola activa el modo "Seleccionar", que congela el script.
function Desactivar-Seleccion {
    try {
        $api = Add-Type -PassThru -Name Consola -Namespace SoporteMarco -MemberDefinition @'
[DllImport("kernel32.dll")] public static extern IntPtr GetStdHandle(int n);
[DllImport("kernel32.dll")] public static extern bool GetConsoleMode(IntPtr h, out uint m);
[DllImport("kernel32.dll")] public static extern bool SetConsoleMode(IntPtr h, uint m);
'@
        $entrada = $api::GetStdHandle(-10)
        [uint32]$modo = 0
        if ($api::GetConsoleMode($entrada, [ref]$modo)) {
            [void]$api::SetConsoleMode($entrada, [uint32](($modo -band 0xFFFFFFBF) -bor 0x80))
        }
    } catch { }
}

# Evita que la PC se suspenda por inactividad mientras dura la sesion (no cubre cerrar la tapa).
function Evitar-Suspension {
    try {
        $api = Add-Type -PassThru -Name Energia -Namespace SoporteMarco -MemberDefinition `
            '[DllImport("kernel32.dll")] public static extern uint SetThreadExecutionState(uint estado);'
        [void]$api::SetThreadExecutionState([uint32]2147483649)    # ES_CONTINUOUS + ES_SYSTEM_REQUIRED
    } catch { }
}

# ---------------------------------------------------------------- pantalla (RustDesk)

function Preparar-RustDesk($sobre, $estado, $info) {
    if (Get-Process -Name rustdesk -ErrorAction SilentlyContinue) {
        Decir '  RustDesk ya estaba abierto: lo dejo como esta.'
        $info.rustdesk = 'ya estaba abierto'
        return
    }
    $instalado = Join-Path $env:ProgramFiles 'RustDesk\rustdesk.exe'
    if (Test-Path -LiteralPath $instalado) {
        Decir '  RustDesk ya esta instalado en esta PC: lo abro.'
        $exe = $instalado
        Start-Process -FilePath $exe
        $estado.rustdeskIniciado = $true
        Guardar-Estado $estado
    } else {
        $sufijo = 'x86_64'
        if ((Arquitectura) -eq 'ARM64') { $sufijo = 'aarch64' }
        $version = Invoke-RestMethod -Uri 'https://api.github.com/repos/rustdesk/rustdesk/releases/latest' `
            -UserAgent 'soporte-marco' -TimeoutSec 30
        $archivo = $version.assets | Where-Object { $_.name -match "^rustdesk-[\d.]+-$sufijo\.exe$" } | Select-Object -First 1
        if (-not $archivo) { throw 'no encontre el ejecutable de RustDesk' }
        $exe = Join-Path $DirTmp 'rustdesk.exe'
        Bajar $archivo.browser_download_url $exe
        $firma = Get-AuthenticodeSignature -LiteralPath $exe
        if ($firma.Status -ne 'Valid' -and $firma.Status -ne 'NotSigned') {
            throw "la firma de RustDesk no es valida ($($firma.Status))"
        }

        # Clave fija para esta sesion, solo si RustDesk nunca se uso en esta cuenta.
        $dirConfig = Join-Path $env:APPDATA 'RustDesk'
        $dirLocal = Join-Path $env:LOCALAPPDATA 'rustdesk'
        $estado.rustdeskDirConfig = $dirConfig
        $estado.rustdeskDirLocal = $dirLocal
        $estado.rustdeskConfigCreada = -not (Test-Path -LiteralPath $dirConfig)
        $estado.rustdeskLocalCreada = -not (Test-Path -LiteralPath $dirLocal)
        $estado.rustdeskIniciado = $true
        Guardar-Estado $estado
        if ($estado.rustdeskConfigCreada) {
            $clave = [string]$sobre.pantalla
            if ($clave -notmatch '^[A-Za-z0-9._-]{6,40}$') {
                $clave = -join ((1..10) | ForEach-Object { 'abcdefghijkmnpqrstuvwxyz23456789'[(Get-Random -Maximum 32)] })
            }
            New-Item -ItemType Directory -Force -Path (Join-Path $dirConfig 'config') | Out-Null
            Set-Content -LiteralPath (Join-Path $dirConfig 'config\RustDesk.toml') -Encoding ASCII -Value "password = '$clave'"
            $info.rustdeskClave = $clave
            # Acceso directo por IP, para que el video viaje por el tunel y no por los servidores publicos.
            Set-Content -LiteralPath (Join-Path $dirConfig 'config\RustDesk2.toml') -Encoding ASCII `
                -Value @('[options]', "direct-server = 'Y'")
            Remove-NetFirewallRule -Name $ReglaFwPantalla -ErrorAction SilentlyContinue
            New-NetFirewallRule -Name $ReglaFwPantalla -DisplayName 'Soporte Marco (RustDesk, solo tunel)' `
                -Direction Inbound -Protocol TCP -LocalPort 21118 -RemoteAddress '100.64.0.0/10' `
                -Action Allow -Profile Any | Out-Null
            $info.rustdeskDirecto = $true
        }
        Start-Process -FilePath $exe
    }
    $estado.rustdeskExe = $exe
    Guardar-Estado $estado
    Start-Sleep -Seconds 10
    Minimizar-Proceso 'rustdesk'          # que no quede su ventana abierta molestando
    $r = Ejecutar $exe @('--get-id')
    if ($r.Salida -match '\d{6,}') { $info.rustdeskId = $Matches[0] }
    $info.rustdesk = 'abierto'
}

function Quitar-RustDesk($estado) {
    Remove-NetFirewallRule -Name $ReglaFwPantalla -ErrorAction SilentlyContinue
    if (-not $estado.rustdeskIniciado) { return }
    Get-Process -Name rustdesk -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 2
    if ($estado.rustdeskConfigCreada -and $estado.rustdeskDirConfig) {
        Remove-Item -LiteralPath $estado.rustdeskDirConfig -Recurse -Force -ErrorAction SilentlyContinue
    }
    if ($estado.rustdeskLocalCreada -and $estado.rustdeskDirLocal) {
        Remove-Item -LiteralPath $estado.rustdeskDirLocal -Recurse -Force -ErrorAction SilentlyContinue
    }
}

# ---------------------------------------------------------------- tunel (Tailscale)

function Preparar-Tunel($sobre, $estado, $info) {
    if (Test-Path -LiteralPath $TsExe) {
        Decir '  Esta PC ya tiene Tailscale instalado: no lo toco.'
        $info.tunel = 'tailscale ya estaba instalado; usar su nombre de siempre'
        return
    }
    $arq = switch (Arquitectura) { 'ARM64' { 'arm64' } 'x86' { 'x86' } default { 'amd64' } }
    $msi = Join-Path $DirTmp 'tailscale.msi'
    Bajar "https://pkgs.tailscale.com/stable/tailscale-setup-latest-$arq.msi" $msi
    $firma = Get-AuthenticodeSignature -LiteralPath $msi
    if ($firma.Status -ne 'Valid' -or $firma.SignerCertificate.Subject -notmatch 'Tailscale') {
        throw "la firma del instalador de Tailscale no es valida ($($firma.Status))"
    }

    $estado.tailscaleInstalado = $true
    $estado.tailscaleDirUsuario = Join-Path $env:LOCALAPPDATA 'Tailscale'
    Guardar-Estado $estado

    $argumentos = "/i `"$msi`" /quiet /norestart TS_NOLAUNCH=1 TS_UNATTENDEDMODE=always " +
        'TS_INSTALLUPDATES=never TS_ENABLEDNS=never TS_ENABLESUBNETS=never'
    $p = Start-Process -FilePath 'msiexec.exe' -ArgumentList $argumentos -Wait -PassThru
    if ($p.ExitCode -ne 0 -and $p.ExitCode -ne 3010) { throw "el instalador de Tailscale devolvio $($p.ExitCode)" }

    $limite = (Get-Date).AddSeconds(60)
    while ((Get-Date) -lt $limite) {
        $svc = Get-Service -Name Tailscale -ErrorAction SilentlyContinue
        if ((Test-Path -LiteralPath $TsExe) -and $svc -and $svc.Status -eq 'Running') { break }
        Start-Sleep -Seconds 2
    }

    $usuario = A-Base32 ([Text.Encoding]::UTF8.GetBytes($env:USERNAME))
    $nodo = "soporte-$($sobre.nombre)-$usuario"
    if ($nodo.Length -gt 63) { $nodo = $nodo.Substring(0, 63) }

    $r = $null
    foreach ($intento in 1..3) {
        $r = Ejecutar $TsExe @('up', "--auth-key=$($sobre.clave)", "--hostname=$nodo", '--unattended',
            '--accept-dns=false', '--accept-routes=false', '--timeout=60s')
        if ($r.Codigo -eq 0) { break }
        Start-Sleep -Seconds 5
    }
    if ($r.Codigo -ne 0) { throw "tailscale up fallo: $($r.Salida)" }
    $ip = Ejecutar $TsExe @('ip', '-4')
    $info.tunel = 'conectado'
    $info.nodo = $nodo
    $info.ip = $ip.Salida
}

function Quitar-Tunel($estado) {
    if (-not $estado.tailscaleInstalado) { return }
    if (Test-Path -LiteralPath $TsExe) { [void](Ejecutar $TsExe @('logout')) }
    $claves = @(
        'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*',
        'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*'
    )
    $productos = Get-ItemProperty -Path $claves -ErrorAction SilentlyContinue |
        Where-Object { $_.DisplayName -like 'Tailscale*' -and $_.PSChildName -match '^\{.+\}$' }
    foreach ($prod in $productos) {
        Start-Process -FilePath 'msiexec.exe' -ArgumentList "/x $($prod.PSChildName) /quiet /norestart" -Wait
    }
    Remove-Item -LiteralPath (Join-Path $env:ProgramData 'Tailscale') -Recurse -Force -ErrorAction SilentlyContinue
    if ($estado.tailscaleDirUsuario) {
        Remove-Item -LiteralPath $estado.tailscaleDirUsuario -Recurse -Force -ErrorAction SilentlyContinue
    }
    Remove-Item -LiteralPath 'HKLM:\SOFTWARE\Policies\Tailscale' -Recurse -Force -ErrorAction SilentlyContinue
}

# ---------------------------------------------------------------- consola (SSH)

function Preparar-Ssh($estado, $info) {
    $svc = Get-Service -Name sshd -ErrorAction SilentlyContinue
    $estado.sshExistia = [bool]$svc
    if ($svc) {
        $estado.sshCorriendo = ($svc.Status -eq 'Running')
        $estado.sshArranque = "$($svc.StartType)"
    }
    $regla = Get-NetFirewallRule -Name 'OpenSSH-Server-In-TCP' -ErrorAction SilentlyContinue
    if ($regla) { $estado.fwOriginalActiva = ("$($regla.Enabled)" -eq 'True') }
    $shell = Get-ItemProperty -Path 'HKLM:\SOFTWARE\OpenSSH' -Name DefaultShell -ErrorAction SilentlyContinue
    if ($shell) { $estado.shellPrevio = [string]$shell.DefaultShell }
    $estado.clavesExistian = (Test-Path -LiteralPath $ArchClaves)
    $estado.sshTocado = $true
    Guardar-Estado $estado

    if (-not $svc) {
        Decir '  Activando el servidor SSH de Windows (puede tardar unos minutos)...'
        $cap = Get-WindowsCapability -Online -Name 'OpenSSH.Server*' | Select-Object -First 1
        Add-WindowsCapability -Online -Name $cap.Name | Out-Null
    }
    if ("$((Get-Service sshd).StartType)" -eq 'Disabled') { Set-Service -Name sshd -StartupType Manual }
    Start-Service -Name sshd    # el primer arranque crea sshd_config y las claves del equipo

    if (-not (Test-Path -LiteralPath $ArchSshdBak)) { Copy-Item -LiteralPath $ArchSshd -Destination $ArchSshdBak }
    $texto = Get-Content -LiteralPath $ArchSshd -Raw
    $texto = $texto -replace '(?m)^[ \t]*#?[ \t]*PasswordAuthentication[ \t]+\S+[ \t]*\r?$', 'PasswordAuthentication no'
    Set-Content -LiteralPath $ArchSshd -Value $texto -Encoding ASCII

    $tiene = (Test-Path -LiteralPath $ArchClaves) -and
        (Select-String -LiteralPath $ArchClaves -SimpleMatch $ClavePublica -Quiet)
    if (-not $tiene) { Add-Content -LiteralPath $ArchClaves -Value $ClavePublica -Encoding ASCII }
    # Solo Administradores (S-1-5-32-544) y SYSTEM (S-1-5-18); por SID para cualquier idioma.
    [void](Ejecutar 'icacls.exe' @($ArchClaves, '/inheritance:r', '/grant', '*S-1-5-32-544:F', '/grant', '*S-1-5-18:F'))

    New-Item -Path 'HKLM:\SOFTWARE\OpenSSH' -Force | Out-Null
    New-ItemProperty -Path 'HKLM:\SOFTWARE\OpenSSH' -Name DefaultShell -PropertyType String -Force -Value $PowerShellExe | Out-Null

    # Puerto 22 solo desde la red del tunel (100.64.0.0/10).
    if ($regla) { Disable-NetFirewallRule -Name 'OpenSSH-Server-In-TCP' }
    Remove-NetFirewallRule -Name $ReglaFw -ErrorAction SilentlyContinue
    New-NetFirewallRule -Name $ReglaFw -DisplayName 'Soporte Marco (SSH, solo tunel)' -Direction Inbound `
        -Protocol TCP -LocalPort 22 -RemoteAddress '100.64.0.0/10' -Action Allow -Profile Any | Out-Null

    Restart-Service -Name sshd
    $info.ssh = 'listo'
}

function Quitar-Ssh($estado) {
    if (-not $estado.sshTocado) { return }
    Remove-NetFirewallRule -Name $ReglaFw -ErrorAction SilentlyContinue
    if ($estado.fwOriginalActiva) { Enable-NetFirewallRule -Name 'OpenSSH-Server-In-TCP' -ErrorAction SilentlyContinue }

    if (Test-Path -LiteralPath $ArchClaves) {
        if ($estado.clavesExistian) {
            $resto = @(Get-Content -LiteralPath $ArchClaves | Where-Object { $_ -notmatch [regex]::Escape($MarcaClave) })
            Set-Content -LiteralPath $ArchClaves -Value $resto -Encoding ASCII
        } else {
            Remove-Item -LiteralPath $ArchClaves -Force -ErrorAction SilentlyContinue
        }
    }
    if (Test-Path -LiteralPath $ArchSshdBak) {
        Copy-Item -LiteralPath $ArchSshdBak -Destination $ArchSshd -Force
        Remove-Item -LiteralPath $ArchSshdBak -Force
    }
    if ($estado.shellPrevio) {
        Set-ItemProperty -Path 'HKLM:\SOFTWARE\OpenSSH' -Name DefaultShell -Value $estado.shellPrevio
    } else {
        Remove-ItemProperty -Path 'HKLM:\SOFTWARE\OpenSSH' -Name DefaultShell -ErrorAction SilentlyContinue
    }

    if ($estado.sshExistia -and $estado.sshCorriendo) {
        Restart-Service -Name sshd -ErrorAction SilentlyContinue
    } else {
        Stop-Service -Name sshd -Force -ErrorAction SilentlyContinue
        Get-Process -Name sshd -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
        $arranque = 'Manual'
        if ($estado.sshExistia -and $estado.sshArranque -eq 'Disabled') { $arranque = 'Disabled' }
        Set-Service -Name sshd -StartupType $arranque -ErrorAction SilentlyContinue
    }
}

# ---------------------------------------------------------------- limpieza

function Limpiar {
    $creado = $false
    $mutex = New-Object System.Threading.Mutex($false, 'Global\SoporteMarcoLimpieza', [ref]$creado)
    try { [void]$mutex.WaitOne(600000) } catch [System.Threading.AbandonedMutexException] { }
    try {
        $estado = Leer-Estado
        if ($estado) {
            foreach ($paso in 'Quitar-Ssh', 'Quitar-Tunel', 'Quitar-RustDesk') {
                try { & $paso $estado } catch { Decir "  Aviso al limpiar ($paso): $_" 'Yellow' }
            }
        }
        foreach ($ruta in $ArchEstado, $ArchInfo, $ArchCerrar) {
            Remove-Item -LiteralPath $ruta -Force -ErrorAction SilentlyContinue
        }
        Remove-Item -LiteralPath $DirTmp -Recurse -Force -ErrorAction SilentlyContinue
    } finally {
        try { $mutex.ReleaseMutex() } catch { }
        $mutex.Dispose()
    }
}

function Programar-Limpieza($cuando) {
    $accion = New-ScheduledTaskAction -Execute $PowerShellExe `
        -Argument "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$RutaScript`" -Modo limpiar"
    $disparos = @(New-ScheduledTaskTrigger -AtStartup)
    if ($cuando) { $disparos += New-ScheduledTaskTrigger -Once -At $cuando }
    $principal = New-ScheduledTaskPrincipal -UserId 'SYSTEM' -LogonType ServiceAccount -RunLevel Highest
    $ajustes = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable
    Register-ScheduledTask -TaskName $TareaLimpieza -Action $accion -Trigger $disparos -Principal $principal `
        -Settings $ajustes -Force | Out-Null
}

# ---------------------------------------------------------------- modos

function Modo-Sesion {
    $Host.UI.RawUI.WindowTitle = 'Soporte Marco'
    Desactivar-Seleccion
    Evitar-Suspension
    if (-not (Es-Admin)) {
        Decir 'Esto tiene que abrirse desde el icono "Soporte Marco" del escritorio.' 'Red'
        Start-Sleep -Seconds 15
        return
    }
    if (-not (Test-Path -LiteralPath $ArchPc)) {
        Decir 'Falta la instalacion inicial. Llama a Marco.' 'Red'
        Start-Sleep -Seconds 15
        return
    }
    try { Start-Transcript -LiteralPath $ArchLog -Force | Out-Null } catch { }

    if (Leer-Estado) { Decir 'Cerrando una sesion anterior que quedo abierta...'; Limpiar }

    Ocultar-Consola
    $ui = Nueva-Progreso

    Avanzar $ui 'Buscando la sesion de soporte...' 8
    $secreto = Secreto-Pc
    $sobre = $null
    $limite = (Get-Date).AddMinutes(5)
    while (-not $sobre -and (Get-Date) -lt $limite -and -not $ui.Cerrado) {
        $sobre = Buscar-Sobre $secreto
        if (-not $sobre) {
            for ($i = 0; $i -lt 20 -and -not $ui.Cerrado; $i++) {
                [Windows.Forms.Application]::DoEvents(); Start-Sleep -Milliseconds 500
            }
        }
    }
    if ($ui.Cerrado) { return }
    if (-not $sobre) {
        try { $ui.Form.Close() } catch { }
        [void][Windows.Forms.MessageBox]::Show(
            'No hay una sesion de soporte abierta todavia. Llama a Marco y volve a abrir el icono.',
            'Soporte Marco', 'OK', 'Information')
        return
    }

    $vence = [int64]$sobre.vence
    New-Item -ItemType Directory -Force -Path $DirTmp | Out-Null
    Remove-Item -LiteralPath $ArchCerrar -Force -ErrorAction SilentlyContinue
    Set-Content -LiteralPath $ArchUltima -Value "$($sobre.vence)" -Encoding ASCII
    $estado = @{ vence = $vence; proceso = $PID }
    Guardar-Estado $estado
    Programar-Limpieza (Hora-Local ($vence + 120))
    Start-Process -FilePath $PowerShellExe -WindowStyle Hidden -ArgumentList @(
        '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', "`"$RutaScript`"", '-Modo', 'vigilar', '-IdProceso', "$PID")

    $info = @{ usuario = $env:USERNAME; equipo = $env:COMPUTERNAME; vence = $vence; errores = @() }
    try {
        $pasos = @(
            @{ Nombre = 'Preparando la pantalla compartida...'; Pct = 25; Hacer = { Preparar-RustDesk $sobre $estado $info } },
            @{ Nombre = 'Armando la conexion segura (puede tardar un momento)...'; Pct = 55; Hacer = { Preparar-Tunel $sobre $estado $info } },
            @{ Nombre = 'Activando la consola remota...'; Pct = 85; Hacer = { Preparar-Ssh $estado $info } }
        )
        foreach ($paso in $pasos) {
            Avanzar $ui $paso.Nombre $paso.Pct
            try { & $paso.Hacer } catch { $info.errores += "$($paso.Nombre): $_" }
            $info | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $ArchInfo -Encoding UTF8
        }

        try {
            $ui.Barra.Visible = $false          # la conexion termino: la barra desaparece (no queda "clavada")
            $ui.Form.TopMost = $false            # ya no molesta: la persona puede seguir trabajando
            $ui.Estado.Text = 'Conectado con el soporte.' + [Environment]::NewLine +
                              'Podes seguir usando la computadora normalmente.'
            if ($info.rustdeskId) {
                $ui.LblId.Visible = $true
                $ui.IdBox.Text = [string]$info.rustdeskId
                $ui.IdBox.Visible = $true
            }
            [Windows.Forms.Application]::DoEvents()
        } catch { }

        # El soporte sigue hasta que venza el tiempo o Marco lo cierre; cerrar la ventana no lo corta.
        while ($true) {
            if (-not $ui.Cerrado) { try { [Windows.Forms.Application]::DoEvents() } catch { } }
            $actual = Leer-Estado
            if ($actual -and [int64]$actual.vence -ne $vence) {
                $vence = [int64]$actual.vence
                Programar-Limpieza (Hora-Local ($vence + 120))
            }
            if ((Ahora-Unix) -ge $vence -or (Test-Path -LiteralPath $ArchCerrar)) { break }
            Start-Sleep -Milliseconds 500
        }
    } finally {
        Limpiar
        try { Stop-Transcript | Out-Null } catch { }
        if (-not $ui.Cerrado) {
            try {
                $ui.IdBox.Visible = $false
                $ui.LblId.Visible = $false
                $ui.Form.WindowState = 'Normal'
                $ui.Estado.Text = 'La sesion de soporte termino.' + [Environment]::NewLine +
                                  'Ya no hay acceso remoto a esta PC.'
                [Windows.Forms.Application]::DoEvents()
                Start-Sleep -Seconds 4
                $ui.Form.Close()
            } catch { }
        }
    }
}

function Proceso-Vivo([int]$id) {
    return ($id -gt 0) -and [bool](Get-Process -Id $id -ErrorAction SilentlyContinue)
}

function Modo-Vigilar {
    # Espera a que la ventana de la sesion se cierre o a que venza el tiempo (que puede extenderse).
    $fallos = 0
    while ($true) {
        $estado = Leer-Estado
        if (-not $estado) {
            $fallos++
            if ($fallos -ge 3) { return }       # ya se limpio
            Start-Sleep -Seconds 2
            continue
        }
        $fallos = 0
        if (-not (Proceso-Vivo $IdProceso)) { break }
        if ((Ahora-Unix) -ge ([int64]$estado.vence + 60)) { break }
        Start-Sleep -Seconds 10
    }
    if ($IdProceso -gt 0) { Stop-Process -Id $IdProceso -Force -ErrorAction SilentlyContinue }
    Limpiar
}

# Lo llama la tarea programada (al vencer y al encender la PC): no limpia una sesion que sigue vigente.
function Modo-Limpiar {
    $estado = Leer-Estado
    if ($estado -and (Proceso-Vivo ([int]$estado.proceso)) -and (Ahora-Unix) -lt [int64]$estado.vence) { return }
    Limpiar
}

# API de ventanas de Windows (se declara una sola vez aunque se llame varias veces).
function Api-Ventanas {
    if (-not ('SoporteMarco.ApiVentanas' -as [type])) {
        $firma = '[DllImport("kernel32.dll")] public static extern IntPtr GetConsoleWindow();' +
                 '[DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr h, int n);'
        Add-Type -Name ApiVentanas -Namespace SoporteMarco -MemberDefinition $firma | Out-Null
    }
    return [SoporteMarco.ApiVentanas]
}

# Oculta la ventana negra de consola (en su lugar se ve la ventana linda).
function Ocultar-Consola {
    $h = (Api-Ventanas)::GetConsoleWindow()
    if ($h -ne [IntPtr]::Zero) { [void](Api-Ventanas)::ShowWindow($h, 0) }   # 0 = SW_HIDE
}

# Minimiza la ventana de un programa (ej. RustDesk) para que no moleste a la persona.
function Minimizar-Proceso([string]$nombre) {
    for ($i = 0; $i -lt 16; $i++) {
        $p = Get-Process -Name $nombre -ErrorAction SilentlyContinue |
             Where-Object { $_.MainWindowHandle -ne 0 } | Select-Object -First 1
        if ($p) { [void](Api-Ventanas)::ShowWindow($p.MainWindowHandle, 6); return }   # 6 = SW_MINIMIZE
        Start-Sleep -Milliseconds 500
    }
}

# Ventana con barra de progreso para la sesion. Devuelve un hash con el form y sus controles.
function Nueva-Progreso {
    Add-Type -AssemblyName System.Windows.Forms
    Add-Type -AssemblyName System.Drawing
    $azul = [Drawing.Color]::FromArgb(11, 107, 203)
    $ui = @{ Cerrado = $false }

    $f = New-Object Windows.Forms.Form
    $f.Text = 'Soporte Marco'
    $f.ClientSize = New-Object Drawing.Size(460, 256)
    $f.StartPosition = 'CenterScreen'
    $f.FormBorderStyle = 'FixedDialog'
    $f.MaximizeBox = $false; $f.MinimizeBox = $true; $f.TopMost = $true   # con boton de minimizar
    $f.BackColor = [Drawing.Color]::White
    $f.Font = New-Object Drawing.Font('Segoe UI', 11)

    $titulo = New-Object Windows.Forms.Label
    $titulo.Text = 'Soporte Marco'
    $titulo.Font = New-Object Drawing.Font('Segoe UI', 18, [Drawing.FontStyle]::Bold)
    $titulo.ForeColor = $azul
    $titulo.AutoSize = $true
    $titulo.Location = New-Object Drawing.Point(24, 16)
    $f.Controls.Add($titulo)

    $estado = New-Object Windows.Forms.Label
    $estado.AutoSize = $false
    $estado.Size = New-Object Drawing.Size(410, 48)
    $estado.Location = New-Object Drawing.Point(26, 56)
    $f.Controls.Add($estado)

    $barra = New-Object Windows.Forms.ProgressBar
    $barra.Location = New-Object Drawing.Point(26, 110)
    $barra.Size = New-Object Drawing.Size(408, 22)
    $barra.Minimum = 0; $barra.Maximum = 100; $barra.Value = 0
    $f.Controls.Add($barra)

    # Etiqueta y campo (ocultos hasta conectar) con el numero de RustDesk, por si Marco lo pide.
    $lblId = New-Object Windows.Forms.Label
    $lblId.Text = 'Si Marco te lo pide, pasale este numero:'
    $lblId.AutoSize = $true
    $lblId.Location = New-Object Drawing.Point(26, 148)
    $lblId.Visible = $false
    $f.Controls.Add($lblId)

    $idbox = New-Object Windows.Forms.TextBox
    $idbox.ReadOnly = $true
    $idbox.Location = New-Object Drawing.Point(26, 176)
    $idbox.Size = New-Object Drawing.Size(408, 34)
    $idbox.Font = New-Object Drawing.Font('Segoe UI', 15, [Drawing.FontStyle]::Bold)
    $idbox.TextAlign = 'Center'
    $idbox.Visible = $false
    $f.Controls.Add($idbox)

    $ui.Form = $f; $ui.Estado = $estado; $ui.Barra = $barra; $ui.LblId = $lblId; $ui.IdBox = $idbox
    # Cerrar la ventana NO corta la sesion: solo registra que se cerro (el soporte sigue hasta que Marco cierre).
    $f.Add_FormClosed({ $ui.Cerrado = $true }.GetNewClosure())
    $f.Show(); [void]$f.Activate()
    [Windows.Forms.Application]::DoEvents()
    return $ui
}

# Actualiza el texto y la barra, y deja que la ventana se refresque.
function Avanzar($ui, [string]$texto, [int]$pct) {
    if (-not $ui -or $ui.Cerrado) { return }
    try {
        if ($texto) { $ui.Estado.Text = $texto }
        if ($pct -ge 0) { $ui.Barra.Value = [Math]::Min(100, [Math]::Max(0, $pct)) }
        [Windows.Forms.Application]::DoEvents()
    } catch { }
}

# Ventana grafica para que la persona escriba las 5 palabras. Devuelve el codigo ya normalizado, o $null.
function Pedir-Codigo-GUI {
    Add-Type -AssemblyName System.Windows.Forms
    Add-Type -AssemblyName System.Drawing
    $azul = [Drawing.Color]::FromArgb(11, 107, 203)

    $f = New-Object Windows.Forms.Form
    $f.Text = 'Soporte Marco'
    $f.ClientSize = New-Object Drawing.Size(460, 300)
    $f.StartPosition = 'CenterScreen'
    $f.FormBorderStyle = 'FixedDialog'
    $f.MaximizeBox = $false; $f.MinimizeBox = $false; $f.TopMost = $true
    $f.BackColor = [Drawing.Color]::White
    $f.Font = New-Object Drawing.Font('Segoe UI', 11)

    $titulo = New-Object Windows.Forms.Label
    $titulo.Text = 'Soporte Marco'
    $titulo.Font = New-Object Drawing.Font('Segoe UI', 20, [Drawing.FontStyle]::Bold)
    $titulo.ForeColor = $azul
    $titulo.AutoSize = $true
    $titulo.Location = New-Object Drawing.Point(24, 22)
    $f.Controls.Add($titulo)

    $instr = New-Object Windows.Forms.Label
    $instr.Text = 'Escribi las 5 palabras que te paso Marco.'
    $instr.AutoSize = $true
    $instr.Location = New-Object Drawing.Point(26, 78)
    $f.Controls.Add($instr)

    $caja = New-Object Windows.Forms.TextBox
    $caja.Location = New-Object Drawing.Point(28, 112)
    $caja.Size = New-Object Drawing.Size(404, 32)
    $caja.Font = New-Object Drawing.Font('Segoe UI', 13)
    $f.Controls.Add($caja)

    $aviso = New-Object Windows.Forms.Label
    $aviso.ForeColor = [Drawing.Color]::FromArgb(185, 40, 40)
    $aviso.AutoSize = $false
    $aviso.Size = New-Object Drawing.Size(404, 44)
    $aviso.Location = New-Object Drawing.Point(28, 150)
    $f.Controls.Add($aviso)

    $boton = New-Object Windows.Forms.Button
    $boton.Text = 'Conectar'
    $boton.Size = New-Object Drawing.Size(130, 44)
    $boton.Location = New-Object Drawing.Point(302, 236)
    $boton.FlatStyle = 'Flat'
    $boton.FlatAppearance.BorderSize = 0
    $boton.BackColor = $azul
    $boton.ForeColor = [Drawing.Color]::White
    $boton.Font = New-Object Drawing.Font('Segoe UI', 12, [Drawing.FontStyle]::Bold)
    $f.Controls.Add($boton)
    $f.AcceptButton = $boton

    # El resultado se guarda en $f.Tag (el mismo objeto dentro y fuera del evento), no en una
    # variable de script: un controlador de evento no puede escribir confiablemente en el scope de afuera.
    $f.Tag = $null
    $boton.Add_Click({
        $cn = Canonico $caja.Text
        $ps = @($cn -split ' ' | Where-Object { $_ })
        if ($ps.Count -ne 5) { $aviso.Text = 'Tienen que ser 5 palabras. Fijate que no falte ninguna.'; return }
        $malas = @($ps | Where-Object { $Palabras -notcontains $_ })
        if ($malas.Count -gt 0) {
            $aviso.Text = "Revisa como se escribe: $($malas -join ', '). Quiza falta o sobra una letra."
            return
        }
        $f.Tag = $cn
        $f.Close()
    }.GetNewClosure())

    [void]$caja.Focus()
    [void]$f.ShowDialog()
    $cod = $f.Tag
    $f.Dispose()
    return $cod
}

function Avisar-Listo {
    Add-Type -AssemblyName System.Windows.Forms
    [void][Windows.Forms.MessageBox]::Show(
        "Listo. Quedo el icono Soporte Marco en el escritorio de esta PC." + [Environment]::NewLine +
        "Cuando Marco te lo pida, abrilo con doble clic.",
        'Soporte Marco', 'OK', 'Information')
}

function Modo-Instalar {
    if (-not (Es-Admin)) {
        Start-Process -FilePath $PowerShellExe -Verb RunAs -ArgumentList @(
            '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', "`"$PSCommandPath`"", '-Modo', 'instalar')
        return
    }
    Ocultar-Consola
  try {
    $codigo = Pedir-Codigo-GUI
    if (-not $codigo) { return }           # cerro la ventana sin completar
    $maestro = Maestro-De-Codigo $codigo

    New-Item -ItemType Directory -Force -Path $DirProg, $DirDatos | Out-Null
    [void](Ejecutar 'icacls.exe' @($DirDatos, '/inheritance:r', '/grant', '*S-1-5-32-544:(OI)(CI)F', '/grant', '*S-1-5-18:(OI)(CI)F'))
    Copy-Item -LiteralPath $PSCommandPath -Destination $RutaScript -Force
    @{ secreto = $maestro } | ConvertTo-Json | Set-Content -LiteralPath $ArchPc -Encoding ASCII

    $usuario = Usuario-Interactivo
    $actual = [Security.Principal.WindowsIdentity]::GetCurrent().Name
    if ($usuario -ne $actual) {
        Decir "  OJO: la sesion de Windows es de '$usuario' pero el permiso lo dio '$actual'." 'Yellow'
        Decir '  Si esa cuenta no es administradora, el icono no va a funcionar. Avisale a Marco.' 'Yellow'
    }
    $accion = New-ScheduledTaskAction -Execute $PowerShellExe `
        -Argument "-NoProfile -ExecutionPolicy Bypass -File `"$RutaScript`" -Modo sesion"
    $principal = New-ScheduledTaskPrincipal -UserId $usuario -LogonType Interactive -RunLevel Highest
    $ajustes = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries `
        -ExecutionTimeLimit (New-TimeSpan -Seconds 0) -MultipleInstances IgnoreNew
    Register-ScheduledTask -TaskName $Tarea -Action $accion -Principal $principal -Settings $ajustes -Force | Out-Null
    Programar-Limpieza $null

    $ws = New-Object -ComObject WScript.Shell
    $acceso = $ws.CreateShortcut((Join-Path $env:PUBLIC 'Desktop\Soporte Marco.lnk'))
    $acceso.TargetPath = Join-Path $env:SystemRoot 'System32\schtasks.exe'
    $acceso.Arguments = "/run /tn `"$Tarea`""
    $acceso.WindowStyle = 7
    $acceso.IconLocation = (Join-Path $env:SystemRoot 'System32\msra.exe') + ',0'
    $acceso.Description = 'Abrir una sesion de soporte con Marco'
    $acceso.Save()

    Avisar-Listo
  } catch {
    Add-Type -AssemblyName System.Windows.Forms
    [void][Windows.Forms.MessageBox]::Show(
        "No se pudo completar la instalacion:" + [Environment]::NewLine + [Environment]::NewLine +
        $_.Exception.Message, 'Soporte Marco', 'OK', 'Error')
  }
}

# Modo desatendido: lo corre una tarea como SYSTEM cada pocos minutos. Una sola consulta, sin ventanas.
function Modo-Comprobar {
    if (Leer-Estado) { return }                                  # ya hay una sesion en curso
    if (-not (Test-Path -LiteralPath $ArchPc)) { return }
    $sobre = Buscar-Sobre (Secreto-Pc)
    if (-not $sobre) { return }
    $ultima = ''
    if (Test-Path -LiteralPath $ArchUltima) { $ultima = (Get-Content -LiteralPath $ArchUltima -Raw).Trim() }
    if ($ultima -eq "$($sobre.vence)") { return }                # esa sesion ya se abrio y se cerro
    Start-ScheduledTask -TaskName $Tarea                         # abre la ventana en el escritorio del usuario
}

function Activar-Espera {
    $accion = New-ScheduledTaskAction -Execute $PowerShellExe `
        -Argument "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$RutaScript`" -Modo comprobar"
    $disparo = New-ScheduledTaskTrigger -Once -At (Get-Date).AddMinutes(1) -RepetitionInterval (New-TimeSpan -Minutes 5)
    $principal = New-ScheduledTaskPrincipal -UserId 'SYSTEM' -LogonType ServiceAccount -RunLevel Highest
    $ajustes = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable `
        -ExecutionTimeLimit (New-TimeSpan -Minutes 2) -MultipleInstances IgnoreNew
    Register-ScheduledTask -TaskName $TareaEspera -Action $accion -Trigger $disparo -Principal $principal `
        -Settings $ajustes -Force | Out-Null
    Decir 'Modo desatendido ACTIVADO: esta PC consulta cada 5 minutos si Marco abrio una sesion.'
}

function Quitar-Espera {
    Unregister-ScheduledTask -TaskName $TareaEspera -Confirm:$false -ErrorAction SilentlyContinue
    Decir 'Modo desatendido DESACTIVADO: solo se abre una sesion con doble clic en el icono.'
}

function Modo-Desinstalar {
    if (-not (Es-Admin)) { Decir 'Hay que ejecutarlo como administrador.' 'Red'; return }
    Limpiar
    Unregister-ScheduledTask -TaskName $Tarea -Confirm:$false -ErrorAction SilentlyContinue
    Unregister-ScheduledTask -TaskName $TareaLimpieza -Confirm:$false -ErrorAction SilentlyContinue
    Unregister-ScheduledTask -TaskName $TareaEspera -Confirm:$false -ErrorAction SilentlyContinue
    Remove-Item -LiteralPath (Join-Path $env:PUBLIC 'Desktop\Soporte Marco.lnk') -Force -ErrorAction SilentlyContinue
    Remove-Item -LiteralPath $DirDatos -Recurse -Force -ErrorAction SilentlyContinue
    Remove-Item -LiteralPath $DirProg -Recurse -Force -ErrorAction SilentlyContinue
    Decir 'Soporte Marco desinstalado.' 'Green'
}

switch ($Modo) {
    'sesion'      { Modo-Sesion }
    'instalar'    { Modo-Instalar }
    'vigilar'     { Modo-Vigilar }
    'limpiar'     { Modo-Limpiar }
    'desinstalar' { Modo-Desinstalar }
    'comprobar'   { Modo-Comprobar }
    'activarEspera' { Activar-Espera }
    'quitarEspera'  { Quitar-Espera }
}
