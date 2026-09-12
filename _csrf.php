<?php
/**
 * GYM One – proteccion CSRF.
 *
 * El proyecto no tenia ninguna: cualquier pagina externa que un empleado con
 * sesion abierta visitara podia enviar formularios al panel en su nombre
 * (vender abonos, recargar saldo, borrar socios, crear un jefe nuevo...).
 *
 * Como hay del orden de cuarenta formularios repartidos en treinta y tantos
 * ficheros, el campo oculto NO se pega a mano en cada uno: se inyecta en la
 * salida HTML desde un unico sitio. Asi no puede quedar un formulario olvidado,
 * que es el fallo tipico de este tipo de parche.
 *
 * Uso en una pagina HTML del panel, justo despues de comprobar la sesion y
 * ANTES de procesar cualquier POST o escribir nada:
 *
 *     require_once __DIR__ . '/../_csrf.php';
 *     gymone_csrf_protect();
 *
 * Uso en un endpoint que responde JSON (AJAX):
 *
 *     gymone_csrf_protect_json();
 *
 * Un formulario concreto puede quedar fuera añadiendo data-no-csrf a la etiqueta
 * <form> (por ejemplo si apunta a un dominio externo como PayPal, donde enviar
 * nuestro token no tendria sentido).
 */

// Solo define funciones: no tiene sentido pedirlo por HTTP.
if (PHP_SAPI !== 'cli' && realpath(__FILE__) === realpath($_SERVER['SCRIPT_FILENAME'] ?? '')) {
    http_response_code(404);
    exit;
}

const GYMONE_CSRF_FIELD   = '_csrf';
const GYMONE_CSRF_HEADER  = 'HTTP_X_CSRF_TOKEN';
const GYMONE_CSRF_SESSION = '_csrf_token';

/**
 * Token de la sesion actual (se crea la primera vez que se pide).
 * Uno por sesion y no por formulario: no rompe la navegacion con varias
 * pestañas ni el boton "atras", que es lo que suele hacer inusable este control.
 */
function gymone_csrf_token(): string
{
    if (session_status() !== PHP_SESSION_ACTIVE) {
        session_start();
    }

    if (empty($_SESSION[GYMONE_CSRF_SESSION])) {
        $_SESSION[GYMONE_CSRF_SESSION] = bin2hex(random_bytes(32));
    }

    return $_SESSION[GYMONE_CSRF_SESSION];
}

/**
 * Campo oculto listo para insertar en un formulario.
 */
function gymone_csrf_field(): string
{
    return '<input type="hidden" name="' . GYMONE_CSRF_FIELD
        . '" value="' . htmlspecialchars(gymone_csrf_token(), ENT_QUOTES) . '">';
}

/**
 * ¿Trae la peticion actual un token valido? Se acepta por campo de formulario o
 * por la cabecera X-CSRF-Token, que es lo que usan las llamadas AJAX.
 */
function gymone_csrf_valid(): bool
{
    $expected = $_SESSION[GYMONE_CSRF_SESSION] ?? '';
    if ($expected === '') {
        return false;
    }

    $given = $_POST[GYMONE_CSRF_FIELD] ?? $_SERVER[GYMONE_CSRF_HEADER] ?? '';

    return is_string($given) && $given !== '' && hash_equals($expected, $given);
}

/**
 * Reescribe el HTML de salida añadiendo el campo oculto a cada formulario POST.
 * Se registra como callback de ob_start(), por eso recibe y devuelve el buffer.
 */
function gymone_csrf_inject(string $html): string
{
    // No tocar respuestas que no sean HTML (JSON, PDF, imagenes...).
    foreach (headers_list() as $header) {
        if (stripos($header, 'content-type:') === 0 && stripos($header, 'text/html') === false) {
            return $html;
        }
    }

    $field = gymone_csrf_field();

    return (string) preg_replace_callback(
        '#<form\b[^>]*>#i',
        static function (array $m) use ($field): string {
            // Solo los formularios POST necesitan token; GET no cambia estado.
            if (!preg_match('#method\s*=\s*["\']?\s*post#i', $m[0])) {
                return $m[0];
            }
            // Salida explicita para formularios hacia terceros.
            if (stripos($m[0], 'data-no-csrf') !== false) {
                return $m[0];
            }

            return $m[0] . $field;
        },
        $html
    );
}

/**
 * Proteccion para paginas HTML: valida el POST y activa la inyeccion del campo.
 */
function gymone_csrf_protect(): void
{
    if (session_status() !== PHP_SESSION_ACTIVE) {
        session_start();
    }

    if (($_SERVER['REQUEST_METHOD'] ?? 'GET') === 'POST' && !gymone_csrf_valid()) {
        // 403 y no 419: el 419 de Laravel no es un codigo HTTP estandar y Apache
        // lo normaliza a 500, lo que parece un fallo del servidor y dispara
        // alertas de monitorizacion por un rechazo que es intencionado.
        http_response_code(403);
        header('Content-Type: text/html; charset=utf-8');
        echo '<!doctype html><meta charset="utf-8">'
            . '<title>403</title>'
            . '<div style="font:16px system-ui;max-width:34em;margin:15vh auto;padding:0 1em">'
            . '<h1 style="font-size:1.3em">Sesion caducada</h1>'
            . '<p>No se ha podido verificar el origen de la peticion, asi que no se ha '
            . 'ejecutado ningun cambio. Vuelve atras, recarga la pagina e intentalo de nuevo.</p>'
            . '</div>';
        exit;
    }

    gymone_csrf_token();
    ob_start('gymone_csrf_inject');
}

/**
 * Proteccion para endpoints AJAX/JSON: responde 403 en JSON y no toca la salida.
 */
function gymone_csrf_protect_json(): void
{
    if (session_status() !== PHP_SESSION_ACTIVE) {
        session_start();
    }

    if (($_SERVER['REQUEST_METHOD'] ?? 'GET') === 'POST' && !gymone_csrf_valid()) {
        http_response_code(403);
        header('Content-Type: application/json; charset=utf-8');
        echo json_encode(['success' => false, 'error' => 'CSRF token mismatch']);
        exit;
    }

    gymone_csrf_token();
}
