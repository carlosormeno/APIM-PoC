# Offline scripts (Podman)

## 1) Con internet (hotspot)
```bash
manual/scripts/offline-download.sh
```
- Descarga todas las imágenes necesarias para WSO2 + base.
- Guarda:
  - `/Datos/offline/apim-wso2-base-images.tar`
  - `/Datos/offline/images-wso2-base.txt`

## 2) Sin internet (PC offline)
```bash
manual/scripts/offline-load.sh
```
- Carga todas las imágenes desde el tar.

## Nota
Si agregas nuevos manifests, vuelve a ejecutar el script de descarga.
