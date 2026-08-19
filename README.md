# 🏰 Reino de Niebla

Juego fitness de exploración para Android. Tu ciudad real es un antiguo reino
cubierto por *la Niebla*: cada caminata con GPS es una expedición que despeja
el mapa, gana cofres con equipo para tu avatar, experiencia y medallas.

## Cómo funciona

- El mapa usa **OpenStreetMap** y tu posición GPS real.
- Las expediciones son **rutas circulares reales** por tus calles (1, 3 o 5 km),
  generadas con el servicio de ruteo peatonal de Valhalla (OSM).
- Al caminar, la **niebla de guerra se despeja permanentemente** — tu progreso
  fitness se ve literalmente en el mapa de tu ciudad.
- Al completar una expedición: **cofre con loot** (23 objetos cosméticos en 4
  rarezas), **XP y niveles** con títulos, y **12 medallas** por hitos.
- Todo se guarda localmente en el teléfono. Sin cuentas, sin pagos.

## Compilación

El APK se compila automáticamente con GitHub Actions en cada push a `main`
y se publica en el release **latest** de este repositorio.

Estructura:

- `app/` — código Flutter del juego (se monta sobre un `flutter create` fresco)
- `scripts/prepare.py` — inyecta permisos, nombre e íconos al proyecto Android
- `scripts/make_icon.py` — genera el ícono de la app
- `.github/workflows/build.yml` — pipeline de compilación

## Instalación en el teléfono

1. Abre la página de **Releases** del repositorio desde el teléfono.
2. Descarga `ReinoDeNiebla-arm64.apk`.
3. Ábrelo y acepta instalar desde orígenes desconocidos.
4. Concede el permiso de ubicación al abrir el juego. ⚔️
