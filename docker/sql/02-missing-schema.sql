-- ---------------------------------------------------------------------------
-- Piezas que el codigo PHP usa pero que NO existen en assets/SQL/Init.sql.
-- Sin esto la portada y varias pantallas del panel mueren con error fatal.
-- ---------------------------------------------------------------------------
USE `gymone`;

-- 1) Excepciones de horario (dias festivos / horarios especiales).
--    La consulta index.php:80 y admin/boss/hours/index.php:151 dependen de esta
--    tabla. El INSERT usa "ON DUPLICATE KEY UPDATE" sobre `date`, asi que la
--    fecha necesita indice unico.
CREATE TABLE IF NOT EXISTS `opening_hours_exceptions` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `date` date NOT NULL,
  `open_time` time DEFAULT NULL,
  `close_time` time DEFAULT NULL,
  `is_closed` tinyint(1) NOT NULL DEFAULT 0,
  PRIMARY KEY (`id`),
  UNIQUE KEY `date` (`date`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- 2) Columna `details` en logs: guarda el JSON con IP, dispositivo, ubicacion
--    y el antes/despues de cada cambio. La lee admin/log/index.php:82 y la
--    escriben casi todos los handlers del panel.
ALTER TABLE `logs`
  ADD COLUMN IF NOT EXISTS `details` text CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT NULL AFTER `actioncolor`;

-- 3) Pasarelas de pago (admin/shop/gateway/). `data` guarda el email de PayPal.
CREATE TABLE IF NOT EXISTS `shop_gateway` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `name` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci NOT NULL,
  `type` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci NOT NULL,
  `data` text CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT NULL,
  `is_enabled` tinyint(1) NOT NULL DEFAULT 0,
  `created_at` datetime DEFAULT NULL,
  `updated_at` datetime DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `type` (`type`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- 4) users.userid viene declarado como int(10) unsigned (maximo 4.294.967.295),
--    pero register/index.php:200 genera el id con rand(10^9, 10^10-1), que llega
--    hasta 9.999.999.999. Con el sql_mode estricto que trae MariaDB por defecto,
--    mas de la mitad de los registros fallarian. El resto del esquema
--    (current_tickets.userid, invoices.userid, workers.userid) ya usa bigint,
--    asi que lo alineamos.
ALTER TABLE `users`
  MODIFY COLUMN `userid` bigint(20) unsigned NOT NULL;

-- 5) Token de confirmacion de registro. Antes confirm.php aceptaba
--    "?userid=<numero>" sin ningun secreto, asi que cualquiera podia activar la
--    cuenta de otro (o activar cuentas en masa) probando ids. Ahora el enlace
--    lleva un token aleatorio de 32 bytes que se consume al usarlo.
ALTER TABLE `users`
  ADD COLUMN IF NOT EXISTS `confirm_token` varchar(64) CHARACTER SET ascii COLLATE ascii_bin DEFAULT NULL AFTER `confirmed`;
