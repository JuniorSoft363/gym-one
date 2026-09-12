# GYM One — contexto del proyecto

Software de gestión de gimnasios en **PHP procedural plano**: sin framework, sin
router. La estructura de carpetas *es* el enrutado (`/login/`, `/dashboard/`,
`/admin/boss/sell/`), y cada carpeta tiene un `index.php` autosuficiente.
Código y comentarios originales en húngaro; los comentarios añadidos por mí, en
español. UI traducida vía `assets/lang/*.json` (7 idiomas, 756 claves cada uno).

Repo original: https://github.com/mayerbalintdev/GYM-One

## Cómo levantarlo

```bash
cp docker/env.example .env   # el .env NO esta en git (lleva credenciales)
docker compose up -d         # --build la primera vez
```

- Web http://localhost:8080 · Panel http://localhost:8080/admin/
- phpMyAdmin http://localhost:8081 · Mailpit (correo) http://localhost:8025
- Staff: `admin`/`admin123` (jefe) · `staff`/`staff123` (sin permisos)
- Socios: `ana@test.com` · `marco@test.com` · `lucia@test.com` (sin confirmar), todos `test1234`

**Detalle completo del entorno en `docker/README.md`.** Lee ese fichero antes
de tocar `docker/`, el esquema o el `.env`.

Flujo verificado en frio: se clono el repo en una carpeta limpia, se levanto
con esos dos comandos y funciono (BD sembrada sola, ambos logins, check-in
asignando taquilla, 33 paginas del panel sin errores).

`HANDOFF.md` es la version autocontenida de este documento, para pegar en un
asistente que NO puede leer el repositorio (ChatGPT, DeepSeek...). Si cambias
algo estructural, actualiza los dos.

## Patrón que se repite en todo el código

No hay bootstrap compartido. Cada fichero repite por su cuenta:
`session_start()` → guarda de sesión → su propia copia de `read_env_file()` →
`new mysqli(...)` → carga del JSON de idioma → `curl` a `api.gymoneglobal.com`.
Existen 4 variantes divergentes de `read_env_file()`; las antiguas usan
`explode('=')` sin límite y no saltan comentarios.

## Roles: solo 3, y un único `tinyint`

| Rol | Tabla | Sesión |
|---|---|---|
| Socio | `users` | `$_SESSION['userid']` |
| Empleado | `workers` con `is_boss=0` | `$_SESSION['adminuser']` |
| Jefe | `workers` con `is_boss=1` | `$_SESSION['adminuser']` |

No hay tabla de permisos ni más niveles. Los **entrenadores (`trainers`) no son
usuarios**: no tienen credenciales, son fichas de catálogo público.
`/admin/boss/sell/` está bajo `boss/` pero **es accesible a todo el personal**
(vender es tarea de recepción); el resto de `/admin/boss/*` y `/admin/updater/`
son solo-jefe.

Es **mono-sede**: ninguna tabla tiene `gym_id`/`branch`/`tenant`. Una
instalación = un gimnasio. `CAPACITY` del `.env` es el aforo simultáneo que
pinta la barra de la portada, no un límite de socios.

## Módulos añadidos (no son del upstream)

- **`_csrf.php`** (raíz) — token por sesión. El campo oculto **se inyecta
  automáticamente** en el HTML vía `ob_start`, en lugar de pegarlo en los ~40
  formularios. AJAX lo manda en la cabecera `X-CSRF-Token`. Opt-out con
  `data-no-csrf` en el `<form>`. Llamar `gymone_csrf_protect()` (HTML) o
  `gymone_csrf_protect_json()` (AJAX) tras la guarda de sesión y **antes** de
  cualquier POST u output.
- **`admin/_guard.php`** — `gymone_require_admin()`, `gymone_require_admin_json()`,
  `gymone_require_boss()`. La comprobación de rol **debe ir antes del handler
  POST**: en `mainsettings`, `smtp` y `chroom` el POST se ejecutaba antes de leer
  `$is_boss`.

Si añades una página nueva al panel, necesita **las dos**: guarda de sesión/rol
y protección CSRF.

## Trampas descubiertas (verificadas, no teoría)

- **Cada página del panel hace un `curl` bloqueante sin timeout a
  `api.gymoneglobal.com`: ~750 ms medidos.** Es el 87 % del tiempo de respuesta,
  independiente del volumen de datos. Está duplicado en ~20 ficheros.
- **`/admin/log/` no pagina**: carga todo el historial y filtra en JavaScript.
  Medido: 55.000 logs → **11,3 MB de HTML** y 2 s. Es el techo real de escala.
  (`/admin/users/` y `/admin/invoices/` sí paginan: 10 y 15 por página.)
- **Ninguna columna `userid` de las tablas hijas tiene índice**
  (`current_tickets`, `workout_stats`, `invoices`, `logs`). `temp_loggeduser` no
  tiene **ningún** índice ni clave primaria.
- **`temp_cart` usa `user_id = 0` fijo** → carrito global. Dos empleados
  vendiendo a la vez mezclan los carritos. Un solo puesto de venta simultáneo.
- **Guardar ajustes desde el panel regenera el `.env` y pierde los comentarios.**
  No pongas nada importante en comentarios ahí.
- **`assets/SQL/Init.sql` está incompleto** (faltan `opening_hours_exceptions`,
  `logs.details`, `shop_gateway`) y **no crea ningún usuario admin**. Los parches
  están en `docker/sql/02-missing-schema.sql` y `03-seed.sql`, que **solo se
  ejecutan al crear el volumen**: para reiniciar, `docker compose down -v`.
- `.gitignore` excluye carpetas en las que el código escribe
  (`assets/img/profiles/`, `logincard/`, `trainers/`): hay que crearlas a mano.
- MariaDB limita los CTE recursivos a 1000 iteraciones por defecto
  (`max_recursive_iterations`), útil si generas datos de prueba.

## Estado y pendientes

Ya corregido (todo verificado con ataques reales, no solo revisando código):
endpoints sin autenticar, escalada de privilegios, inyección SQL en alta de
empleados, CSRF, token de confirmación de registro, y `admin/dashboard_OLD/`
eliminado. El detalle está en `docker/README.md`.

Pendiente, por orden de impacto:
1. Paginar `/admin/log/`.
2. Timeout o caché en la comprobación de versión (`api.gymoneglobal.com`).
3. Índices en las columnas `userid` de las tablas hijas.
4. Restos muertos por borrar: `admin/trainers/timetable/index copy.php` y
   `admin/shop/gateway/PAYPALCHECK.php`.
5. Swiftmailer está abandonado desde 2021 (migrar a symfony/mailer).

## Cómo trabajar aquí

Verifica los cambios **contra la instancia en marcha**, no solo leyendo el
código: `curl` contra `localhost:8080` con una cookie de sesión, y consulta la
base de datos con `docker compose exec -T db mariadb -ugymone -pgymone gymone -e "..."`.
Varios fallos de esta lista aparecieron al probar y eran invisibles leyendo.
Comprueba la sintaxis con `docker compose exec -T web php -l <fichero>`
(en Git Bash hace falta `MSYS_NO_PATHCONV=1` para que no traduzca la ruta).
