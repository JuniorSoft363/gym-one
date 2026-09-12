<?php
// Endpoint AJAX del inventario: traduce un codigo de barras a id de producto.
// Pertenece a /boss/, asi que exige sesion Y rol de jefe, igual que la pagina
// que lo consume. Antes respondia a cualquiera sin autenticar.
require_once __DIR__ . '/../../../_guard.php';
$adminuser = gymone_require_admin_json();

function read_env_file($file_path)
{
    $env_file = file_get_contents($file_path);
    $env_lines = explode("\n", $env_file);
    $env_data = [];

    foreach ($env_lines as $line) {
        $line_parts = explode('=', $line);
        if (count($line_parts) == 2) {
            $key = trim($line_parts[0]);
            $value = trim($line_parts[1]);
            $env_data[$key] = $value;
        }
    }

    return $env_data;
}

$env_data = read_env_file('../../../../.env');

$db_host = $env_data['DB_SERVER'] ?? '';
$db_username = $env_data['DB_USERNAME'] ?? '';
$db_password = $env_data['DB_PASSWORD'] ?? '';
$db_name = $env_data['DB_NAME'] ?? '';

$business_name = $env_data['BUSINESS_NAME'] ?? '';
$lang_code = $env_data['LANG_CODE'] ?? '';
$version = $env_data["APP_VERSION"] ?? '';
$capacity = $env_data["CAPACITY"] ?? '';

$lang = $lang_code;

$langDir = __DIR__ . "/../../../../assets/lang/";

$langFile = $langDir . "$lang.json";

if (!file_exists($langFile)) {
    die("LANG ERROR: $langFile");
}

$translations = json_decode(file_get_contents($langFile), true);

$conn = new mysqli($db_host, $db_username, $db_password, $db_name);

if ($conn->connect_error) {
    die("CONN ERROR: " . $conn->connect_error);
}

// El inventario es area de jefe; la comprobacion va aqui porque necesita $conn.
if (gymone_worker_is_boss($conn, $adminuser) !== 1) {
    http_response_code(403);
    header('Content-Type: application/json; charset=utf-8');
    echo json_encode(['success' => false, 'error' => 'Forbidden']);
    exit;
}

if (isset($_GET['barcode'])) {
    // Sentencia preparada en lugar de interpolar con real_escape_string.
    $stmt = $conn->prepare("SELECT id FROM products WHERE barcode = ?");
    $stmt->bind_param("s", $_GET['barcode']);
    $stmt->execute();
    $stmt->bind_result($product_id);

    echo json_encode(['id' => $stmt->fetch() ? $product_id : null]);
    $stmt->close();
}

$conn->close();
?>
