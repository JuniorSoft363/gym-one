# Entorno de desarrollo local (Docker)

Levanta GYM One en local sin instalar PHP, Apache ni MySQL en el sistema.

## Arrancar

```bash
cp docker/env.example .env    # solo la primera vez: el .env no esta en git
docker compose up -d          # añade --build la primera vez o si tocas el Dockerfile
```

> El `example.env` de la raíz es el del proyecto original y apunta a
> `localhost` / `root` / `smtp.gmail.com`: **no funciona con Docker**. Usa
> `docker/env.example`.

| Servicio | URL | Para qué |
|---|---|---|
| Sitio web | http://localhost:8080 | La aplicación |
| Panel de staff | http://localhost:8080/admin/ | Check-in, ventas, configuración |
| phpMyAdmin | http://localhost:8081 | Ver y editar la base de datos |
| Mailpit | http://localhost:8025 | Bandeja que captura todo el correo saliente |

## Credenciales de prueba

**Panel de staff** (`/admin/`)

| Usuario | Contraseña | Rol |
|---|---|---|
| `admin` | `admin123` | `is_boss = 1` — ve el menú completo `/boss/` |
| `staff` | `staff123` | `is_boss = 0` — menú reducido |

**Área de miembros** (`/login/`)

| Email | Contraseña | Estado |
|---|---|---|
| `ana@test.com` | `test1234` | Abono mensual ilimitado activo |
| `marco@test.com` | `test1234` | Bono de 10 sesiones, 7 restantes |
| `lucia@test.com` | `test1234` | Sin confirmar (sirve para probar el bloqueo del login) |

## Comandos útiles

```bash
docker compose logs -f web        # errores de PHP en tiempo real
docker compose restart web        # reiniciar Apache
docker compose down               # parar (conserva la base de datos)
docker compose down -v            # parar y BORRAR la base de datos
```

El código se monta en vivo desde el directorio del repo: editas un `.php` en
Windows y basta con recargar el navegador. Solo hay que reconstruir
(`--build`) si cambias algo dentro de `docker/`.

## Reiniciar la base de datos desde cero

Los ficheros de `docker/sql/` **solo se ejecutan cuando el volumen se crea por
primera vez**. Para volver al estado inicial:

```bash
docker compose down -v
docker compose up -d
```

## Qué hay en esta carpeta

| Fichero | Qué hace |
|---|---|
| `Dockerfile` | PHP 8.2 + Apache con las extensiones `mysqli`, `gd` y `zip` compiladas |
| `apache/gymone.conf` | Bloquea `.env`, `vendor/` y `docker/` desde el servidor web |
| `php/gymone.ini` | Límites de subida, zona horaria y errores visibles (modo desarrollo) |
| `sql/02-missing-schema.sql` | Tablas y columnas que el código usa pero faltan en `assets/SQL/Init.sql` |
| `sql/03-seed.sql` | Datos de prueba: personal, miembros, abonos, taquillas, horarios, productos |

## Cosas que hubo que arreglar para que arrancara

El repositorio por sí solo no es instalable. Estos son los parches que aplica
este entorno, por si migras a producción o al instalador oficial:

1. **`assets/SQL/Init.sql` está incompleto.** Le faltan la tabla
   `opening_hours_exceptions` (la consulta la portada), la columna `logs.details`
   (la escribe casi todo el panel) y la tabla `shop_gateway`. Sin ellas hay error
   fatal. Están en `sql/02-missing-schema.sql`.

2. **No hay ningún usuario administrador** y no existe forma de crearlo desde la
   interfaz: la tabla `workers` nace vacía. Se siembra en `sql/03-seed.sql`.

3. **`users.userid` era `int(10) unsigned`** (máximo 4.294.967.295) pero
   `register/index.php:200` genera el id con `rand(10^9, 10^10-1)`, que llega a
   9.999.999.999. Con el `sql_mode` estricto por defecto, más de la mitad de los
   registros fallaría. Ampliado a `bigint unsigned`, que es lo que ya usaba el
   resto del esquema.

4. **`login/index.php` llamaba a `session_start()` dos veces** (línea 2 y línea
   83). El aviso de PHP se imprimía antes del `header("Location:")`, lo que
   rompía la redirección y dejaba el login en blanco. Sustituido por
   `session_regenerate_id(true)`, que además evita fijación de sesión.

5. **Directorios que el código escribe pero que están en `.gitignore`** y por
   tanto no existen tras clonar: `assets/img/profiles/` (fotos de perfil),
   `assets/img/logincard/` (imágenes QR), `assets/img/trainers/`. Hay que
   crearlos a mano.

6. **`MAIL_ENCRYPTION` no puede quedar vacío.** Swiftmailer lo usa tal cual para
   construir la URL del socket, así que `""` intenta abrir `://host:puerto` y
   falla. Para SMTP sin cifrar el valor correcto es `tcp`.

## Correcciones de seguridad aplicadas

Además de lo necesario para arrancar, se cerraron estos agujeros. Todos están
comentados en el código, en el punto donde estaban.

**Endpoints accesibles sin iniciar sesión.** `admin/dashboard/search.php`
(listaba nombre y email de todos los socios) y `admin/dashboard/logout.php`
(sacaba del gimnasio a cualquier socio) no comprobaban nada, igual que
`get_BARCODE.php`. Se añadió `admin/_guard.php`, que centraliza las
comprobaciones de sesión y de rol.

**Escalada de privilegios.** El rol de jefe se comprobaba solo en el HTML
(`if ($is_boss === 1)` alrededor del menú), así que cualquier empleado podía
entrar a `/admin/boss/*` escribiendo la URL o enviando el POST a mano. Ahora se
verifica en el servidor con `gymone_require_boss()`. En `mainsettings`, `smtp` y
`chroom` la comprobación tuvo que subir por encima del handler POST, que se
ejecutaba antes de leer `$is_boss`.

**Inyección SQL** en la creación de empleados (`admin/boss/workers/index.php`):
los campos del formulario se interpolaban en la sentencia. Ahora va preparada.
En el mismo sitio, `$is_this_boss = isset($_POST["is_boss"])` comprobaba
*presencia* y no valor, así que `is_boss=0` creaba un jefe.

**CSRF.** No había ninguna protección: cualquier web externa podía enviar
formularios al panel usando la sesión de un empleado. Se añadió `_csrf.php` con
un token por sesión. El campo oculto **se inyecta automáticamente** en la salida
HTML en lugar de pegarlo en los cuarenta formularios del proyecto, para que no
pueda quedar ninguno olvidado; las llamadas AJAX lo envían en la cabecera
`X-CSRF-Token`. Un formulario puede quedar fuera con `data-no-csrf` (útil si
apunta a un dominio externo como PayPal).

**Confirmación de registro sin token.** `register/confirm.php` aceptaba
`?userid=<numero>`, así que se podían activar cuentas ajenas probando ids. Ahora
el enlace lleva un token aleatorio de un solo uso (columna `users.confirm_token`).
De paso: esa página exigía sesión de miembro, cosa imposible para quien acaba de
registrarse, así que el enlace del correo **nunca funcionaba**.

**`admin/dashboard_OLD/` eliminado** (1.528 líneas). Era una copia antigua del
check-in que duplicaba los agujeros anteriores y tenía además su propia
inyección SQL. Nada del proyecto lo enlazaba.

### Nota sobre el .env y los comentarios

El panel de ajustes regenera el `.env` a partir de pares `clave=valor`, así que
**los comentarios se pierden al guardar desde la interfaz**. Peor: el
`read_env_file()` antiguo no salta los comentarios, de modo que una línea de
comentario que contuviera un `=` se leía como clave y se reescribía, llenando el
fichero de basura en cada guardado. Los cuatro puntos que escriben el `.env`
ahora descartan esas claves. Conclusión práctica: no cuentes con que los
comentarios del `.env` sobrevivan.
