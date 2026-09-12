<?php
/**
 * GYM One – guardas de autorizacion del panel /admin/.
 *
 * Hasta ahora cada pagina repetia a mano el "if (!isset($_SESSION['adminuser']))"
 * y, para el rol de jefe, se limitaba a OCULTAR los enlaces en el menu con
 * "if ($is_boss === 1)" sin volver a comprobar nada en el servidor. Eso dejaba
 * dos agujeros:
 *
 *   1) Varios endpoints (search.php, logout.php, process.php del dashboard
 *      antiguo, get_BARCODE.php) no comprobaban NADA y eran accesibles sin
 *      iniciar sesion.
 *   2) Cualquier empleado sin permisos podia entrar a /admin/boss/* escribiendo
 *      la URL a mano, o enviar el POST directamente: la comprobacion de rol solo
 *      existia en el HTML.
 *
 * Estas funciones centralizan las dos comprobaciones para que no vuelvan a
 * quedar desparejadas. Uso tipico en una pagina solo-jefe, justo DESPUES de
 * abrir la conexion y ANTES de procesar cualquier POST:
 *
 *     require_once __DIR__ . '/../../_guard.php';
 *     $is_boss = gymone_require_boss($conn, $userid);
 */

// Este fichero solo define funciones; no tiene sentido pedirlo por HTTP.
if (PHP_SAPI !== 'cli' && realpath(__FILE__) === realpath($_SERVER['SCRIPT_FILENAME'] ?? '')) {
    http_response_code(404);
    exit;
}

/**
 * Ruta absoluta de la raiz del panel (".../admin/"), para poder redirigir al
 * login desde cualquier profundidad sin contar "../" a mano.
 */
function gymone_admin_base_url(): string
{
    $uri = $_SERVER['REQUEST_URI'] ?? '/admin/';
    $pos = strpos($uri, '/admin/');

    return $pos === false ? '/admin/' : substr($uri, 0, $pos + strlen('/admin/'));
}

/**
 * Exige una sesion de empleado abierta. Para paginas HTML: redirige al login.
 */
function gymone_require_admin(): int
{
    if (session_status() !== PHP_SESSION_ACTIVE) {
        session_start();
    }

    if (!isset($_SESSION['adminuser'])) {
        header('Location: ' . gymone_admin_base_url());
        exit;
    }

    return (int) $_SESSION['adminuser'];
}

/**
 * Igual que gymone_require_admin(), pero para endpoints que devuelven JSON:
 * responde 403 en lugar de redirigir, porque un 302 hacia HTML rompe al cliente.
 */
function gymone_require_admin_json(): int
{
    if (session_status() !== PHP_SESSION_ACTIVE) {
        session_start();
    }

    if (!isset($_SESSION['adminuser'])) {
        http_response_code(403);
        header('Content-Type: application/json; charset=utf-8');
        echo json_encode(['success' => false, 'error' => 'Unauthorized']);
        exit;
    }

    return (int) $_SESSION['adminuser'];
}

/**
 * Lee el flag is_boss del empleado. Devuelve 0 si el usuario ya no existe,
 * de modo que una sesion vieja de un empleado borrado no herede permisos.
 */
function gymone_worker_is_boss(mysqli $conn, int $userid): int
{
    $stmt = $conn->prepare('SELECT is_boss FROM workers WHERE userid = ?');
    $stmt->bind_param('i', $userid);
    $stmt->execute();
    $stmt->bind_result($is_boss);
    $found = $stmt->fetch();
    $stmt->close();

    return $found ? (int) $is_boss : 0;
}

/**
 * Exige rol de jefe. Devuelve is_boss (siempre 1) para que la pagina pueda
 * seguir usando la variable al pintar el menu.
 *
 * Llamar SIEMPRE antes de procesar $_POST: si no, un empleado sin permisos
 * podria ejecutar la accion y solo despues ver el menu recortado.
 */
function gymone_require_boss(mysqli $conn, int $userid): int
{
    if (gymone_worker_is_boss($conn, $userid) !== 1) {
        header('Location: ' . gymone_admin_base_url() . 'dashboard/');
        exit;
    }

    return 1;
}
