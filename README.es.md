<p align="center">
  <img src="docs/icon.svg" width="120" height="120" alt="Lovely Glow">
</p>

# Lovely Glow

[English](README.md) · [简体中文](README.zh-Hans.md) · [繁體中文](README.zh-Hant.md) · [日本語](README.ja.md) · [한국어](README.ko.md) · [Español](README.es.md)

La tipografía Pixel opcional usa DeparturePixelZh Compact 0.1.1 y no está incluida. Antes de empaquetar, ejecuta `python3 script/get_compact_font.py` para descargar y verificar la versión fijada. Consulta [dependencias](DEPENDENCIES.md).

Una aplicación nativa de barra de menús para macOS que dibuja un único borde luminoso alrededor de la ventana activa. No oscurece el contenido, organiza ventanas ni se adjunta a las de otras aplicaciones.

## Comportamiento

Al activar Glow sigue la ventana actual de la aplicación delantera. Excluye las ventanas auxiliares pequeñas sin título salvo que las incluyas en More. Conserva el objetivo anterior durante su menú, Cmd+Tab o Spotlight. Oculta el borde en pantalla completa, Mission Control y ventanas que llenan el área de trabajo. Deja pasar los clics y no toma el foco del teclado.

El panel de la barra ajusta paleta, tamaño, movimiento, aparición y tipografía. System es el valor inicial; Pixel Compact está incluido como opción guardada. Instant y Seamless usan la misma ventana superpuesta y siguen la cadencia de la pantalla actual. Las pruebas del núcleo no demuestran gestos reales, fluidez ni alineación de píxeles. Stage Manager, ventanas de formas propias y la detección de Spaces en futuras versiones de macOS tienen límites.

## Compilar el código

Requiere Apple Silicon, macOS 27 o posterior y un SDK compatible de Xcode／Swift 6.2 o posterior seleccionado. No descarga paquetes Swift ni necesita repositorios vecinos. Completa primero la instalación y aceptación de licencia de Xcode por el procedimiento de Apple.

```sh
swift build --jobs 2 --scratch-path Local/swift-build --product LovelyGlow
just test
python3 -m unittest discover -s script -p test_migrate_settings.py
```

`just` solo ofrece atajos existentes. El equivalente para el núcleo es `swift test --jobs 2 --scratch-path Local/swift-test`. Las pruebas usan datos sintéticos; no abren la aplicación, piden Accesibilidad, instalan ni cambian el inicio de sesión. `SWIFT_JOBS` vale 2 por defecto y `SWIFT_SCRATCH_PATH`, `Local/swift-test`. Las opciones inválidas fallan.

## Firma e instalación

`config/product.conf` tiene prioridad cuando existe. Si falta, se usa `config/product.public.conf`, con la misma identidad de producto y sin identidad de firma. El candidato de código excluye la configuración privada. Un ejecutable compilado no demuestra que haya una aplicación firmada aceptada.

```sh
just stage
just install
```

Estos comandos requieren tu certificado e identidad de firma configurados. Stage crea otro candidato sin parar la aplicación diaria. Install solo reemplaza y abre `~/Applications/LovelyGlow.app` cuando coincide el requisito de firma existente. No usa una firma temporal ni otro bundle ID para evitar la comprobación. El empaquetado usa iconutil／sips, rsvg-convert opcional y una ruta alternativa de iconos con Python.

Accesibilidad se solicita al activar Glow. Sin permiso, los cambios normales aún usan límites del sistema de ventanas, pero el seguimiento al arrastrar es más débil. El inicio de sesión usa SMAppService solo si lo activas. No necesita HTTP, LaunchAgent ni Process Compose.

## Datos y migración

Desde 0.7.9／33, la única configuración activa está en `~/Library/Application Support/com.alex.LovelyGlow/config.toml`. No escribe preferencias de ejecución en el código. El instalador lee la ruta antigua de los metadatos de la aplicación firmada anterior; tras detenerla, copia los bytes y los relee. Si ya existe otro contenido en el destino, se detiene sin sobrescribir ninguno. Conserva el archivo anterior para recuperación. Las instalaciones nuevas usan Application Support directamente. Los resultados de compilación permanecen en Local／dist, excluidos de Git.

## Licencias y revisión del código

La marca del README es un SVG independiente para documentación de codingEzio bajo [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/). No cambia los derechos del icono del producto, las fuentes ni terceros.

El software propio usa [MIT](LICENSE). La fuente conserva [OFL y los avisos de sus componentes](Resources/Licenses/NOTICE.md). [LICENSE-SCOPE.md](LICENSE-SCOPE.md) separa cada ámbito. Este repositorio excluye la marca original de derechos no resueltos y usa el marcador geométrico original CC BY 4.0 enumerado. El paquete privado conserva la marca antigua; eso no autoriza publicarla.

Consulta [PUBLICATION.md](PUBLICATION.md) para el historial y los límites de verificación.
