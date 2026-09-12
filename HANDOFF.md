# GYM One — documento de traspaso

**Para qué es este fichero:** poner al día a una persona o a un asistente que
**no tiene acceso al código** (ChatGPT, DeepSeek, Gemini…). Está escrito para
pegarse entero en un chat. Si el asistente *sí* puede leer el repositorio
(Claude Code), usa `CLAUDE.md`, que es más corto y remite a los ficheros.

Repositorio: https://github.com/JuniorSoft363/gym-one
Fork de: https://github.com/mayerbalintdev/GYM-One (upstream en `V1.4.1`)

> **Aviso para el asistente:** no puedes ejecutar este proyecto ni leer sus
> ficheros. Todo lo que propongas son hipótesis sin verificar. Este documento
> incluye mediciones reales: fíate de ellas antes que de tu intuición, y pide el
> contenido del fichero concreto antes de proponer un cambio sobre él.

---

## 1. Qué es

Gestor de gimnasios: altas de socios, abonos, control de acceso por QR,
taquillas, punto de venta con facturas en PDF y panel de administración.

**Stack:** PHP 8.2 procedural, MariaDB 10.11, Apache. Bootstrap por CDN.
Dependencias vía Composer, con `vendor/` **commiteado** en el repo: Swiftmailer
(correo), mPDF (facturas), endroid/qr-code (QR), PKPass (Apple Wallet).

**Arquitectura:** no hay framework, ni router, ni ORM, ni autoload propio. La
estructura de carpetas *es* el enrutado: cada carpeta tiene un `index.php`
autosuficiente que se ejecuta de arriba a abajo, con la lógica y el HTML en el
mismo fichero. Unas 28.000 líneas de PHP propio en unos 60 ficheros.

**Idioma:** código y comentarios originales en húngaro. Los comentarios añadidos
durante este trabajo están en español. La interfaz se traduce con
`assets/lang/{HU,GB,ES,DE,FR,PL,TR}.json`, 756 claves cada uno, elegido por
`LANG_CODE` del `.env`.

## 2. Estructura

```
index.php            portada pública (aforo en vivo, horarios)
login/  register/    acceso y alta de socios (register/confirm.php valida el email)
prices/ trainers/ contact/ rule/    páginas públicas
dashboard/           área del socio: su abono, QR, facturas, estadísticas
  profile/ stats/ invoices/
admin/               panel del personal
  index.php          login de personal
  dashboard/         CHECK-IN: index.php + checkin.js + process.php + search.php
  users/             listado y ficha de socios (users/edit/)
  statistics/  log/  invoices/
  trainers/          entrenadores y horario de clases
  shop/              tipos de abono y pasarelas de pago
  updater/           auto-actualización desde GitHub
  boss/              SOLO JEFE: mainsettings, workers, packages, hours, smtp,
                     chroom (taquillas), rule
    sell/            punto de venta (accesible a TODO el personal, no solo jefe)
crontab/send_reminders.php   avisos de caducidad (cron diario)
_csrf.php            protección CSRF (añadido)
admin/_guard.php     guardas de sesión y rol (añadido)
docker/              entorno de desarrollo (añadido)
```

## 3. Configuración

Todo en un `.env` en la raíz, **no versionado**. Plantilla: `docker/env.example`.
Claves: `DB_*`, `BUSINESS_NAME`, `LANG_CODE`, `CURRENCY`, dirección, `MAIL_*`,
`CAPACITY`, `ABOUT`, `AUTOACCEPT`, `APP_VERSION`, `GOOGLE_KEY`.

No se usa ninguna librería de dotenv: cada fichero define **su propia copia** de
`read_env_file()`. Hay **4 variantes divergentes**; las antiguas parten la línea
por el primer `=` sin límite y no saltan comentarios, así que un valor que
contenga `=` rompe el parseo. El panel de ajustes **reescribe el `.env` y pierde
los comentarios**.

## 4. Base de datos (18 tablas)

`users` socios · `workers` personal · `tickets` catálogo de abonos ·
`current_tickets` abonos vendidos y vigentes · `invoices` facturas ·
`lockers` taquillas · `temp_loggeduser` quién está dentro ahora ·
`workout_stats` sesiones cerradas · `revenu_stats` caja diaria ·
`products` tienda · `temp_cart` carrito · `opening_hours` +
`opening_hours_exceptions` · `timetable` clases · `trainers` · `logs` auditoría ·
`shop_gateway` pasarelas · `temp_dailyworkout`

Esquema base en `assets/SQL/Init.sql`, **incompleto** (ver §7). Complementos en
`docker/sql/02-missing-schema.sql`, datos de prueba en `03-seed.sql`.

## 5. Roles: exactamente 3

| Rol | Tabla | Sesión PHP |
|---|---|---|
| Socio | `users` | `$_SESSION['userid']` |
| Empleado | `workers` con `is_boss = 0` | `$_SESSION['adminuser']` |
| Jefe | `workers` con `is_boss = 1` | `$_SESSION['adminuser']` |

No existe tabla de permisos ni más niveles: todo depende de un `tinyint(1)`.
Los **entrenadores no son usuarios**: `trainers` no tiene credenciales, son
fichas de catálogo público.

**Mono-sede.** Ninguna tabla tiene `gym_id`/`branch`/`tenant`: una instalación =
un gimnasio. `CAPACITY` es el aforo simultáneo que pinta la barra de la portada,
no un límite de socios.

## 6. Los dos flujos que hay que entender

**Check-in** (`admin/dashboard/`). `checkin.js` lee el QR con la cámara (ZXing) y
llama a `process.php`, que tiene dos modos deliberados:

- `lookup` — solo lectura: ¿existe el socio? ¿ya está dentro? ¿abono válido?
- `commit` — se llama **solo tras confirmar la identidad** el empleado. En una
  transacción: asigna una taquilla libre del género correcto (`FOR UPDATE`),
  descuenta una sesión y escribe en `temp_loggeduser`.

El check-out es `logout.php?user=<id>`: calcula los minutos desde `login_date`,
los guarda en `workout_stats`, borra de `temp_loggeduser` y libera la taquilla.

**Venta** (`admin/boss/sell/`). Tres vías: abono, productos (carrito + código de
barras) y recarga de saldo. Pago en efectivo, tarjeta o saldo interno
(`users.profile_balance`). Genera factura PDF con mPDF en
`assets/docs/invoices/`, la registra en `invoices` y suma a `revenu_stats`.

## 7. Qué se cambió respecto al upstream

**El repositorio original no era instalable.** Correcciones para que arranque:

1. `Init.sql` no crea **ningún usuario administrador** y no hay forma de crearlo
   desde la interfaz: era imposible entrar al panel.
2. Faltaban la tabla `opening_hours_exceptions`, la columna `logs.details` y la
   tabla `shop_gateway`, todas usadas por el código → error fatal.
3. `users.userid` era `int(10) unsigned` (máx. 4.294.967.295) pero el registro
   genera ids de hasta 10 dígitos → ampliado a `bigint unsigned`.
4. `login/index.php` llamaba `session_start()` dos veces; el aviso de PHP se
   imprimía antes del `header("Location:")` y rompía la redirección.
5. `register/confirm.php` exigía sesión de socio, imposible para quien acaba de
   registrarse → **el enlace del correo nunca funcionaba**.

**Correcciones de seguridad** (commit `c727dd2`):

- Endpoints sin autenticar: `search.php` listaba nombre y email de todos los
  socios a cualquiera; `logout.php` permitía expulsar a un socio arbitrario.
- Escalada de privilegios: el rol de jefe solo se comprobaba en el HTML, así que
  cualquier empleado podía entrar a `/admin/boss/*` o enviar el POST a mano.
- Inyección SQL en el alta de empleados. En el mismo sitio, `$is_this_boss`
  usaba `isset()`, que mira presencia y no valor: `is_boss=0` creaba un jefe.
- **CSRF**: no había ninguna protección en todo el proyecto.
- Token de un solo uso para confirmar el registro.
- Eliminado `admin/dashboard_OLD/` (1.528 líneas): copia muerta del check-in que
  duplicaba los agujeros y tenía su propia inyección SQL.

**Módulos nuevos** (no existen en el upstream):

- `_csrf.php` — token por sesión. El campo oculto **se inyecta automáticamente**
  en la salida HTML mediante `ob_start`, en lugar de pegarlo en los ~40
  formularios del proyecto, para que no pueda quedar ninguno olvidado. Las
  llamadas AJAX lo mandan en la cabecera `X-CSRF-Token`. Un formulario puede
  quedar fuera con `data-no-csrf`.
- `admin/_guard.php` — `gymone_require_admin()`, `gymone_require_admin_json()`,
  `gymone_require_boss()`.

> **Regla al añadir una página al panel:** necesita **las dos cosas**, guarda de
> sesión/rol y protección CSRF. Y la comprobación de rol debe ir **antes** del
> handler POST: en `mainsettings`, `smtp` y `chroom` el POST se ejecutaba antes
> de leer `$is_boss`, así que la guarda tuvo que subir por encima.

## 8. Mediciones reales, no estimaciones

- **Cada página del panel hace una llamada HTTP bloqueante y sin timeout a
  `api.gymoneglobal.com` para comprobar la versión: 748 ms medidos.** Bloquear
  ese dominio bajó `/admin/users/` de 782 ms a 98 ms: es el **87 %** del tiempo
  de respuesta, con independencia del volumen de datos. Está duplicado en unos
  20 ficheros.
- **`/admin/log/` no pagina** (trae todo el historial y filtra en JavaScript):
  16 logs → 47 ms y 28 KB · 5.000 → 154 ms y 1 MB ·
  **55.000 → 2.030 ms y 11,3 MB de HTML**. Es el techo real de escala.
- Con 10.005 socios, `/admin/users/` tarda 98 ms y la portada 33 ms: los
  listados de socios y facturas **sí paginan** (10 y 15 por página).
- **Ninguna columna `userid` de las tablas hijas tiene índice**
  (`current_tickets`, `workout_stats`, `invoices`, `logs`). `temp_loggeduser` no
  tiene **ningún** índice ni clave primaria.
- **`temp_cart` guarda `user_id = 0` fijo** → carrito global: dos empleados
  vendiendo a la vez mezclan los carritos. Un solo puesto de venta simultáneo.

## 9. Pendientes, por impacto

1. **Paginar `/admin/log/`** — el techo de escala.
2. **Timeout o caché** en la comprobación de versión — el 87 % del tiempo.
3. **Índices** en las columnas `userid` de las tablas hijas.
4. Borrar restos muertos: `admin/trainers/timetable/index copy.php` y
   `admin/shop/gateway/PAYPALCHECK.php` (demo con email hardcodeado).
5. Swiftmailer está **abandonado desde 2021** → migrar a `symfony/mailer`.
6. `temp_cart` por empleado, para permitir varios puestos de venta.

## 10. Cómo levantarlo y cómo verificar

```bash
git clone https://github.com/JuniorSoft363/gym-one.git
cd gym-one
cp docker/env.example .env
docker compose up -d
```

Web `http://localhost:8080` · Panel `/admin/` · phpMyAdmin `:8081` ·
Mailpit, que captura el correo saliente, `:8025`

Credenciales de la demo local: `admin`/`admin123` (jefe), `staff`/`staff123`
(empleado), y socios `ana@test.com`, `marco@test.com`, `lucia@test.com` (esta
última sin confirmar), todos con `test1234`.

**Este flujo está verificado**: se clonó el repositorio desde GitHub en una
carpeta limpia, se levantó con estos comandos y funcionó — base de datos
sembrada sola, ambos logins, check-in asignando taquilla, las protecciones
activas y las 33 páginas del panel sin un solo error fatal.

**Cómo verificar un cambio.** Esto importa: varios de los fallos de §7 eran
invisibles leyendo el código y solo aparecieron al probar.

```bash
# sintaxis de un fichero
docker compose exec -T web php -l /var/www/html/<fichero>

# consultar la base de datos
docker compose exec -T db mariadb -ugymone -pgymone gymone -e "SELECT ..."

# probar una página con sesión de personal
curl -s -c /tmp/c.txt -d 'username=admin&password=admin123' http://localhost:8080/admin/
curl -s -b /tmp/c.txt http://localhost:8080/admin/users/
```

Para reiniciar la base de datos desde cero:
`docker compose down -v && docker compose up -d`
(los ficheros de `docker/sql/` solo se ejecutan al crear el volumen).
