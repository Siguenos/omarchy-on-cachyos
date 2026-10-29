# Omarchy sobre CachyOS

Adaptador comunitario **experimental** para instalar el escritorio de Omarchy
**4.0.6 (Quattro)** en CachyOS x86_64. Conserva la distribución, el kernel, los
controladores, el cargador de arranque y la política de Snapper de CachyOS.
Instala los programas del escritorio y sus configuraciones de usuario.

## Por qué fallaba `./install.sh`

Omarchy 4 dejó de distribuir el instalador `install.sh`: ahora utiliza paquetes
del sistema y la instalación desde su ISO. Por eso `cd "$HOME/omarchy"` no arregla
`./install.sh: No such file or directory` al descargar Quattro.
El instalador anterior también mezclaba rutas relativas y podía continuar
después de errores de descarga o de modificación de archivos.

Este fork verifica el tag `v4.0.6` contra el commit
`237f1b4071a0bff2296c6d740ba2b9fd695ebfa0`, construye el paquete local
`omarchy-cachyos` y ejecuta la preparación de usuario de Quattro. No ejecuta
`install.sh`, ni instala los paquetes oficiales `omarchy` / `omarchy-settings`:
en x86_64 esos paquetes añaden dependencias de Limine y ajustes de arranque.
La versión se fija deliberadamente; una versión futura debe revisarse antes de
cambiar `bin/release.sh` y el `PKGBUILD`. No se ofrece una opción `main/dev`.

## Antes de instalar

- CachyOS ya instalado, x86_64, raíz Btrfs y configuración Snapper `root` válida.
  Se identifica mediante `ID=cachyos` en `/etc/os-release`; no es necesario que
  exista `/etc/cachyos-release`.
  Si usas Arch con un kernel CachyOS, puedes optar por la adaptación experimental
  con `bash bin/install-omarchy-on-cachyos.sh --allow-arch-with-cachyos-kernel`.
  Esta opción comprueba `ID=arch`, `/etc/arch-release` y que el kernel en ejecución
  contenga `cachyos`; no elimina los demás requisitos. No equivale a probar la
  adaptación en esa combinación de sistema y kernel.
- Se recomienda una instalación nueva con el escritorio Hyprland de CachyOS y
  SDDM. El adaptador también instala SDDM si falta. Rechaza GNOME, Plasma y una
  instalación de los paquetes oficiales de Omarchy.
- Ejecuta desde tu usuario normal, **sin `sudo` delante del script**. Bash es el
  intérprete del instalador; tu shell interactiva puede seguir siendo Fish.
- Los controladores gráficos deben funcionar antes de empezar. Este adaptador
  no fuerza NVIDIA 580xx, no instala controladores con `chwd`, ni cambia módulos
  del kernel. Las actualizaciones normales de pacman siguen aplicándose.
- Omarchy usa configuración Lua de Hyprland; el paquete exige Hyprland >= 0.55.
- Conexión a Internet y espacio para paquetes, caché, copia de `.config` y
  snapshot. Guarda aparte tus datos: un snapshot de raíz puede excluir `/home`.

**Límite de validación:** hay pruebas de Bash, descarga, rutas y contenido del
paquete con las fuentes reales de 4.0.6. No constituyen una instalación completa
en CachyOS ni una prueba de inicio gráfico, GPU, audio o Wi-Fi. Prueba primero en
una instalación prescindible o una VM con snapshot.

## Instalación paso a paso

1. Actualiza CachyOS e instala las herramientas iniciales:

   ```bash
   sudo pacman -Syu --needed git base-devel snapper
   ```

   Si la actualización cambia el kernel, reinicia antes de continuar y verifica
   tu escritorio/conexión. Comprueba el sistema:

   ```bash
   uname -r
   findmnt -n -o FSTYPE /
   sudo snapper -c root get-config
   ```

   La raíz debe ser `btrfs`. Si Snapper no tiene configuración `root`, termina la
   configuración de snapshots de CachyOS antes de usar el adaptador.

2. Clona **este fork**:

   ```bash
   git clone https://github.com/MiguelU-coder/omarchy-on-cachyos.git
   cd omarchy-on-cachyos
   ```

3. Descarga y verifica las fuentes sin modificar el sistema:

   ```bash
   bash bin/install-omarchy-on-cachyos.sh --prepare-only
   ```

   Las fuentes se guardan en `~/.cache/omarchy-on-cachyos/source-4.0.6`.
   El comando se puede ejecutar desde cualquier directorio utilizando la ruta
   absoluta del script. No necesitas hacer `cd` a Omarchy ni usar `chmod`.

4. Instala:

   ```bash
   bash bin/install-omarchy-on-cachyos.sh
   ```

   Escribe `INSTALL` para comenzar e introduce nombre y correo Git si quieres.
   Revisa las transacciones que presenta pacman. El instalador crea un snapshot
   y una copia de configuración antes de modificar paquetes. Añade el repositorio
   estable firmado de Omarchy conservando los repositorios de CachyOS. Lo coloca
   primero para dar prioridad a paquetes de escritorio con el mismo nombre;
   esto puede cambiar la procedencia de algunos paquetes del sistema.
   Construye el adaptador con `makepkg` como usuario, instala la lista de programas
   de Omarchy, guarda el viejo directorio Hyprland y copia los nuevos ajustes.

5. **Solo si aparece `Installation completed`**, reinicia:

   ```bash
   systemctl reboot
   ```

   En SDDM selecciona **Omarchy (Hyprland uwsm)** e inicia sesión. La primera sesión
   prepara servicios de usuario y preferencias de escritorio. El arranque no se
   convierte al de la ISO de Omarchy ni se configura inicio automático.

## Si falla o ya ejecutaste el instalador viejo

No vuelvas a ejecutar el instalador antiguo ni borres `~/omarchy` para resolver
el error de `install.sh`: ese archivo no existe en Quattro. El script viejo
pudo cambiar `/etc/pacman.conf` y borrar `/etc/sddm.conf` antes de fallar; esta
adaptación no puede recuperar automáticamente archivos que ya se borraron.

El adaptador reemplaza la sección antigua `[omarchy]` por el servidor estable.
Si falló con conflictos de `foot.desktop`, `imv.desktop` o `mpv.desktop`, actualiza
el fork con `git pull --ff-only origin main` y ejecuta de nuevo el instalador.
La revisión `4.0.4-2` del adaptador libera esas rutas al actualizar el paquete;
los lanzadores e iconos de Omarchy se aplican en `~/.local/share`. No necesitas
usar `--overwrite` ni borrar archivos propiedad de paquetes manualmente.
No elimina una copia de fuentes existente: si está modificada o es de otra
versión, detiene la ejecución y pide moverla aparte.

Los registros y copias nuevas están en:

```text
~/.local/state/omarchy-on-cachyos/install-AAAAMMDD-HHMMSS.log
~/.local/state/omarchy-on-cachyos/backup-AAAAMMDD-HHMMSS-PID/
```

Si el instalador se detiene, conserva el registro completo. Corrige la causa
antes de reiniciar. Una repetición crea otra copia, pero no es un mecanismo
automático de recuperación. Para recuperar una instalación fallida usa tu
snapshot de CachyOS y la copia de configuración de usuario. Restaurar solo
`pacman.conf` o `.config` no revierte los paquetes ya instalados.

## Actualizaciones y diferencias

Si tras una instalación completada el arranque queda en una terminal, inicia
sesión con tu usuario y ejecuta `sudo systemctl set-default graphical.target`
y después `sudo systemctl start sddm.service`. En la pantalla gráfica selecciona
Omarchy (Hyprland uwsm). Si SDDM falla, revisa
`systemctl status sddm.service --no-pager -l` y
`journalctl -b -u sddm.service --no-pager -n 50` antes de reinstalar.

- `sudo pacman -Syu` y `omarchy update` actualizan paquetes de CachyOS/Arch y los
  programas del repositorio Omarchy. La segunda orden está adaptada para evitar
  el flujo de migraciones del sistema Omarchy.
- `omarchy-cachyos` es un paquete local: no recibe automáticamente versiones
  nuevas del escritorio Omarchy. Para una versión futura, primero actualiza el
  fork cuando tenga una adaptación revisada y sigue sus instrucciones.
- No uses el conversor `omarchy-upgrade-to-quattro` ni instales los paquetes
  oficiales `omarchy` / `omarchy-settings` encima de esta adaptación.
- Se conservan Fish, tealdeer, red, controladores, login con contraseña y
  configuración de arranque. No se ejecutan los orquestadores de hardware,
  configuración del sistema, login o post-instalación de la ISO. Algunas
  funciones propias de esa ISO (por ejemplo gestión de Limine) no aplican.
- `bin/nvidia.sh` del instalador anterior fue retirado: ya no participa ningún
  script personalizado de controladores en la instalación.

## Pruebas

En Linux con Bash, Git, AWK y Python 3:

```bash
bash bin/install-omarchy-on-cachyos.sh --prepare-only
OMARCHY_TEST_SOURCE="$HOME/.cache/omarchy-on-cachyos/source-4.0.6" python3 tests/test_adapter.py
```

La prueba de empaquetado ejecuta `package()` sobre las fuentes reales en una
carpeta temporal y simula solo la conversión de iconos con ImageMagick. No
ejecuta pacman ni servicios. Comprueba que no se instalen archivos en rutas de
arranque, PAM, sudo, SDDM, Snapper, identidad de distribución o repositorios.

## Licencia

MIT; consulta [LICENSE](LICENSE). Omarchy y sus recetas originales también usan
MIT. Este adaptador comunitario se distribuye sin garantía.
