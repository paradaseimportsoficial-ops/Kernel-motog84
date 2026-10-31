# Moto G84 — Tecnico Root V1

Renomeia `5.4.295-moto-17290-g91c2dab5855a` para
`5.4.295-Tecnico-Root-V1`, sem atualizar ou recompilar o Linux.
O objetivo atual é cosmético; não requer código-fonte ou toolchain do kernel.

## GitHub Actions

O workflow testa o patch e produz um **ZIP instalável pelo TWRP** usando
AnyKernel3 fixado no commit `41f04bdb4ee30a44e429c2c1131d5e8bb32b15f1`.
Baixe o artefato, extraia o ZIP externo do GitHub e instale o arquivo
`MotoG84-Tecnico-Root-V1-renomeador-TWRP.zip` que está dentro dele.

Essa versão pública não contém um kernel nem dados do APatch: no TWRP,
renomeia o kernel que já está instalado. Exige correspondência única da
estrutura UTS original. Um kernel incompatível ou já renomeado é recusado.

O nome é alterado somente no campo UTS release de 65 bytes. A identificação
`vermagic` usada pelos módulos, o banner estático e todos os demais bytes do
kernel ficam intactos. Algumas ferramentas que leem o banner estático ainda
mostrarão o nome antigo. O patch existente do APatch não é reaplicado nem trocado.

## ZIP personalizado a partir de boot.img

Para gerar **localmente** uma versão que contém o kernel de uma imagem boot v3
ARM64, já com o nome alterado:

```sh
python3 scripts/build_zip.py --anykernel AnyKernel3 \
  --boot /caminho/privado/boot.img \
  --output dist/MotoG84-Tecnico-Root-V1-personalizado-TWRP.zip
```

Não envie boot.img, kernel ou ZIP personalizado ao repositório público.
Uma imagem com APatch contém material de autenticação do root.
O arquivo de entrada é apenas lido, nunca sobrescrito.

## Instalação e recuperação

Somente Moto G84 (bangkk), TWRP funcional, bootloader desbloqueado e slot
ativo identificado. O instalador salva e verifica o boot atual em
`/sdcard/TecnicoRoot-backup/<data-hora>/boot_a-antes.img` (ou `_b`).
Sem armazenamento gravável ou com erro no backup, ele não grava o boot.

Ele substitui o kernel em uma cópia do boot do slot ativo, preservando todos
os bytes fora do kernel, e verifica a gravação. Não recalcula nem remove AVB;
assim como o APatch existente, exige bootloader desbloqueado. A versão com
imagem exige tamanho de kernel idêntico ao instalado; se diferir, recusa. Não modifica `vendor_boot`, `vbmeta` ou dados do usuário.
Para desfazer, restaure a imagem de backup na partição Boot do mesmo slot
pelo TWRP. Se houver erro de verificação após gravar, restaure antes de reiniciar.

Testes locais verificam sintaxe, alteração restrita ao campo UTS, rejeição de
entradas inválidas e integridade do ZIP. Isso não equivale a um teste de boot
no aparelho real. Consulte também `installer/LEIA-ME.txt`.
