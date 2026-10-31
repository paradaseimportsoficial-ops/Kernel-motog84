### Moto G84: rename only the UTS release field, retaining module vermagic.
properties() { '
kernel.string=5.4.295-Tecnico-Root-V1
do.devicecheck=1
do.modules=0
do.systemless=0
do.cleanup=1
do.cleanuponabort=1
device.name1=bangkk
device.name2=bangkk_g
supported.versions=
supported.patchlevels=
supported.vendorpatchlevels=
'; }

BLOCK=boot
IS_SLOT_DEVICE=1
SLOT_SELECT=active
RAMDISK_COMPRESSION=auto
PATCH_VBMETA_FLAG=0
NO_VBMETA_PARTITION_PATCH=1
NO_MAGISK_CHECK=1
. tools/ak3-core.sh

case "$SLOT" in _a|_b) ;; *) abort 'Slot ativo desconhecido.' ;; esac
case "$BLOCK" in *boot_a|*boot_b) ;; *) abort 'Particao inesperada; nada foi gravado.' ;; esac
split_boot
[ "$(od -An -tu4 -j40 -N4 "$BOOTIMG" | tr -d ' ')" = 3 ] || abort 'Header de boot diferente de v3; nada foi gravado.'
# Restore raw components so even the compressed ramdisk bytes stay unchanged.
(cd "$SPLITIMG" && magiskboot unpack -n -h "$BOOTIMG") || abort 'Falha ao extrair componentes sem descompressao.'
[ -f "$SPLITIMG/kernel" ] || abort 'Kernel nao encontrado.'
KERNEL_SIZE=$(od -An -tu4 -j8 -N4 "$BOOTIMG" | tr -d ' ')
[ "$(wc -c < "$SPLITIMG/kernel")" -eq "$KERNEL_SIZE" ] || abort 'Kernel comprimido ou formato diferente; nada foi gravado.'

# Confirm the installed kernel has the expected UTS structure before any flash.
# This is deliberately distinct from the module ABI and the static Linux banner.
cp "$SPLITIMG/kernel" "$AKHOME/check-kernel" || abort 'Falha ao preparar verificacao.'
magiskboot hexpatch "$AKHOME/check-kernel" @OLD_PATTERN@ @OLD_PATTERN@ > "$AKHOME/check.log" 2>&1
[ "$(grep -c 'Patch @' "$AKHOME/check.log")" = 1 ] || abort 'Kernel instalado diferente ou nome ja alterado; nada foi gravado.'
rm -f "$AKHOME/check-kernel" "$AKHOME/check.log"

# A personalized ZIP carries the supplied, renamed kernel. The public Actions
# ZIP carries no image or root data and renames the installed kernel instead.
if [ -f "$AKHOME/Image" ]; then
  (cd "$AKHOME" && sha256sum -c Image.sha256) || abort 'Imagem do ZIP corrompida.'
  [ "$(wc -c < "$AKHOME/Image")" -eq "$KERNEL_SIZE" ] || abort 'Tamanho do kernel instalado diferente da base; nada foi gravado.'
  KERNEL_PAYLOAD="$AKHOME/Image"
else
  magiskboot hexpatch "$SPLITIMG/kernel" @OLD_PATTERN@ @NEW_PATTERN@ > "$AKHOME/rename.log" 2>&1 || abort 'Falha na alteracao do nome.'
  [ "$(grep -c 'Patch @' "$AKHOME/rename.log")" = 1 ] || abort 'Alteracao ambigua; nada foi gravado.'
  KERNEL_PAYLOAD="$SPLITIMG/kernel"
fi

# Equal-length replacement avoids rebuilding any boot metadata or ramdisk.
cp "$BOOTIMG" "$AKHOME/boot-new.img" || abort 'Falha ao copiar boot.'
dd if="$KERNEL_PAYLOAD" of="$AKHOME/boot-new.img" bs=4096 seek=1 conv=notrunc || abort 'Falha ao inserir kernel.'
[ "$(wc -c < "$AKHOME/boot-new.img")" -eq "$(wc -c < "$BOOTIMG")" ] || abort 'Tamanho do boot mudou; nada foi gravado.'

# Persist and verify a complete copy of the currently installed active boot.
# Refuse to flash if TWRP cannot access user storage.
BACKUP_DIR="/sdcard/TecnicoRoot-backup/$(date +%Y%m%d-%H%M%S)-$$"
mkdir -p "$BACKUP_DIR" || abort 'Nao foi possivel criar backup em /sdcard. Monte/desbloqueie o armazenamento.'
cp "$BOOTIMG" "$BACKUP_DIR/boot${SLOT}-antes.img" || abort 'Falha no backup; nada foi gravado.'
ORIGINAL_HASH=$(sha256sum "$BOOTIMG" | cut -d ' ' -f1)
SAVED_HASH=$(sha256sum "$BACKUP_DIR/boot${SLOT}-antes.img" | cut -d ' ' -f1)
[ "$ORIGINAL_HASH" = "$SAVED_HASH" ] || abort 'Backup inconsistente; nada foi gravado.'
printf '%s  %s\n' "$SAVED_HASH" "boot${SLOT}-antes.img" > "$BACKUP_DIR/SHA256SUMS"
sync
ui_print "Backup: $BACKUP_DIR/boot${SLOT}-antes.img"

# Only the active boot is written. All non-kernel bytes are copied unchanged.
blockdev --setrw "$BLOCK" 2>/dev/null
dd if="$AKHOME/boot-new.img" of="$BLOCK" bs=1048576 conv=fsync || abort "Falha de gravacao. Restaure o backup antes de reiniciar: $BACKUP_DIR"
sync
NEW_SIZE=$(wc -c < "$AKHOME/boot-new.img")
dd if="$BLOCK" of="$AKHOME/readback.img" bs=1048576 count="$NEW_SIZE" iflag=count_bytes 2>/dev/null || abort "Falha ao verificar gravacao. Restaure o backup antes de reiniciar: $BACKUP_DIR"
EXPECTED_HASH=$(sha256sum "$AKHOME/boot-new.img" | cut -d ' ' -f1)
ACTUAL_HASH=$(sha256sum "$AKHOME/readback.img" | cut -d ' ' -f1)
[ "$EXPECTED_HASH" = "$ACTUAL_HASH" ] || abort "Verificacao falhou. Restaure o backup antes de reiniciar: $BACKUP_DIR"
ui_print 'Concluido: 5.4.295-Tecnico-Root-V1' 'Backup salvo; nao e necessario formatar dados.'
