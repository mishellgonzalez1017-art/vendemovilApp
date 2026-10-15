# Licencias: cómo funciona y cómo emitir claves

## Cómo funciona

- Al abrir la app por primera vez empiezan **7 días de prueba gratis**.
- Después hace falta una **clave**. Es una sola clave para todos los clientes
  y vale hasta el final de la fecha que lleva dentro (por ejemplo, 30 días).
- Con la licencia **vencida** la app deja ver el historial y exportar a Excel,
  pero no deja agregar productos ni cobrar ventas nuevas.
- Todo se valida en el teléfono, sin internet.

Una clave se ve así: `VM-261105-549KV7CG`
(`261105` = vence el 05/11/2026; lo demás es la firma).

## 1. Crear tu secreto (una sola vez)

Inventa una frase larga y difícil de adivinar, por ejemplo con 30 caracteres al
azar. **Guárdala en un gestor de contraseñas.** Si la pierdes no podrás emitir
claves nuevas para las apps ya instaladas, y si alguien la consigue puede
fabricar claves.

> **No la escribas dentro del código ni la subas a GitHub.** Si el repositorio
> es público, cualquiera podría leerla. Conviene poner el repositorio en
> privado (GitHub → Settings → General → Danger Zone → Change visibility).

## 2. Compilar la app con el secreto

El secreto se pasa al compilar; no queda en el repositorio.

```bash
# Probar en el teléfono conectado
flutter run --dart-define=LICENSE_SECRET="tu-secreto"

# APK para instalar/entregar
flutter build apk --release --dart-define=LICENSE_SECRET="tu-secreto"
```

En VS Code puedes dejarlo fijo en `.vscode/launch.json`
(ese archivo no se sube si lo agregas a `.gitignore`):

```json
{
  "version": "0.2.0",
  "configurations": [
    {
      "name": "Vende GT",
      "request": "launch",
      "type": "dart",
      "args": ["--dart-define=LICENSE_SECRET=tu-secreto"]
    }
  ]
}
```

En Codemagic, guarda `LICENSE_SECRET` como variable de entorno segura y agrega
`--dart-define=LICENSE_SECRET=$LICENSE_SECRET` al comando de build.

Si compilas **sin** el secreto, la prueba de 7 días funciona, pero la app
rechaza todas las claves.

## 3. Emitir la clave del mes

Con el mismo secreto en una variable de entorno:

```bash
# Mac / Linux
export LICENSE_SECRET="tu-secreto"
# Windows PowerShell
$env:LICENSE_SECRET = "tu-secreto"

dart run tools/generar_clave.dart --dias 30
# o con fecha exacta:
dart run tools/generar_clave.dart --hasta 2026-11-05
```

(Si prefieres Python: `python3 tools/generar_clave.py --dias 30`.
Genera exactamente las mismas claves.)

Mándales la clave por WhatsApp. Ellos la ingresan en **Ajustes → Licencia**
(o en el aviso rojo de la pantalla de ventas).

Consejos:
- Emite la clave nueva unos días **antes** de que venza la anterior. Quien la
  ingrese tarde simplemente pierde esos días.
- Una clave nueva solo se acepta si vence **después** de la que ya tienen.

## Probar que todo está bien

```bash
flutter test test/licencia_clave_test.dart
```

## Límites que conviene conocer

- **La clave es la misma para todos:** si un cliente se la pasa a alguien que
  no paga, esa persona también puede usarla hasta que venza. Cambia con cada
  periodo, así que el daño dura como máximo un mes.
- **Reinstalar la app reinicia los 7 días de prueba** (los datos de ventas
  también se pierden, así que casi nadie lo hace).
- **Atrasar la fecha del teléfono no sirve:** la app recuerda la fecha más alta
  que vio. Pero si alguien adelanta mucho la fecha por error y la regresa, la
  app seguirá contando desde la fecha adelantada.
- El secreto va dentro de la app compilada. Una persona con conocimientos
  técnicos podría extraerlo. Esto frena al cliente común, no a un experto.
