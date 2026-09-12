-- ---------------------------------------------------------------------------
-- Datos de prueba para GYM One.
-- El Init.sql del repo solo crea tablas vacias, asi que sin esto no hay forma
-- de entrar al panel (la tabla `workers` estaria vacia y no existe registro
-- de administradores desde la interfaz).
--
-- CREDENCIALES
--   Panel de staff  ->  http://localhost:8080/admin/
--     admin / admin123    (is_boss = 1, ve todo el menu /boss/)
--     staff / staff123    (is_boss = 0, menu reducido)
--   Area de miembros ->  http://localhost:8080/login/
--     ana@test.com   / test1234   (abono mensual ilimitado activo)
--     marco@test.com / test1234   (bono de 10 sesiones, 7 restantes)
--     lucia@test.com / test1234   (sin confirmar: sirve para probar el bloqueo)
-- ---------------------------------------------------------------------------
USE `gymone`;

-- --- Personal ---------------------------------------------------------------
-- OJO: el userid 1 esta protegido contra borrado en
-- admin/boss/workers/index.php:121, asi que es el jefe "indestructible".
INSERT INTO `workers` (`userid`, `firstname`, `lastname`, `username`, `password_hash`, `is_boss`) VALUES
  (1, 'Admin',  'Principal', 'admin', '$2y$12$fibYPBqV2.PxsZo2LBMLy.0HSsUXBE0W4UEw7XP6OzKLLmPOv.GHO', 1),
  (2, 'Carlos', 'Recepcion', 'staff', '$2y$12$.eOf7lXpqLtXlPnQh6kNzO1F6jZ8.0wmusGU5nOZDjTqH/tM.OWTy', 0);

-- --- Miembros ---------------------------------------------------------------
-- El hash es el mismo para los tres: test1234
INSERT INTO `users`
  (`userid`, `firstname`, `lastname`, `email`, `password`, `gender`, `birthdate`,
   `city`, `street`, `house_number`, `registration_date`, `confirmed`, `profile_balance`) VALUES
  (1000000001, 'Ana',   'Garcia',  'ana@test.com',   '$2y$12$IaTTU7lyqAp9KS6Gvirwbe8mZzwdNcxuKZTFACK6Sh1faXBYuBKK2', 'Female', '1995-04-12', 'Madrid',    'Calle Mayor',    '14', DATE_SUB(NOW(), INTERVAL 8 MONTH), 'Yes', 50.00),
  (1000000002, 'Marco', 'Ruiz',    'marco@test.com', '$2y$12$IaTTU7lyqAp9KS6Gvirwbe8mZzwdNcxuKZTFACK6Sh1faXBYuBKK2', 'Male',   '1988-11-03', 'Madrid',    'Gran Via',       '7',  DATE_SUB(NOW(), INTERVAL 5 MONTH), 'Yes', 12.50),
  (1000000003, 'Lucia', 'Fernandez','lucia@test.com','$2y$12$IaTTU7lyqAp9KS6Gvirwbe8mZzwdNcxuKZTFACK6Sh1faXBYuBKK2', 'Female', '2000-07-22', 'Alcorcon', 'Avenida del Sol','3',  DATE_SUB(NOW(), INTERVAL 2 DAY),   'No',   0.00);

-- --- Tipos de abono (catalogo que se vende en admin/boss/sell/) --------------
-- occasions = NULL significa ilimitado; el check-in no descuenta nada.
INSERT INTO `tickets` (`id`, `name`, `expire_days`, `price`, `occasions`) VALUES
  (1, 'Entrada puntual',         1,    8.00,  1),
  (2, 'Mensual ilimitado',       30,  45.00,  NULL),
  (3, 'Bono 10 sesiones',        90,  70.00,  10),
  (4, 'Trimestral ilimitado',    90, 120.00,  NULL),
  (5, 'Anual ilimitado',        365, 420.00,  NULL);

-- --- Abonos activos ---------------------------------------------------------
-- Ana tiene uno ilimitado vigente; Marco un bono por sesiones a medio gastar.
-- Con esto el check-in (admin/dashboard/) ya devuelve "valido" al escanear.
INSERT INTO `current_tickets` (`userid`, `ticketname`, `buydate`, `expiredate`, `opportunities`) VALUES
  (1000000001, 'Mensual ilimitado', DATE_SUB(CURDATE(), INTERVAL 10 DAY), DATE_ADD(CURDATE(), INTERVAL 20 DAY), NULL),
  (1000000002, 'Bono 10 sesiones',  DATE_SUB(CURDATE(), INTERVAL 30 DAY), DATE_ADD(CURDATE(), INTERVAL 60 DAY), 7);

-- --- Taquillas --------------------------------------------------------------
-- El check-in elige una libre del genero correspondiente (process.php:186).
INSERT INTO `lockers` (`lockernum`, `gender`, `user_id`) VALUES
  (1,'Male',NULL),(2,'Male',NULL),(3,'Male',NULL),(4,'Male',NULL),(5,'Male',NULL),
  (6,'Male',NULL),(7,'Male',NULL),(8,'Male',NULL),(9,'Male',NULL),(10,'Male',NULL),
  (11,'Male',NULL),(12,'Male',NULL),(13,'Male',NULL),(14,'Male',NULL),(15,'Male',NULL),
  (21,'Female',NULL),(22,'Female',NULL),(23,'Female',NULL),(24,'Female',NULL),(25,'Female',NULL),
  (26,'Female',NULL),(27,'Female',NULL),(28,'Female',NULL),(29,'Female',NULL),(30,'Female',NULL),
  (31,'Female',NULL),(32,'Female',NULL),(33,'Female',NULL),(34,'Female',NULL),(35,'Female',NULL);

-- --- Horario de apertura ----------------------------------------------------
-- day: 1 = lunes ... 7 = domingo. open_time/close_time en NULL = cerrado.
INSERT INTO `opening_hours` (`day`, `open_time`, `close_time`) VALUES
  (1, '07:00:00', '22:00:00'),
  (2, '07:00:00', '22:00:00'),
  (3, '07:00:00', '22:00:00'),
  (4, '07:00:00', '22:00:00'),
  (5, '07:00:00', '21:00:00'),
  (6, '09:00:00', '14:00:00'),
  (7, NULL, NULL);

-- Excepciones: la portada solo muestra las de los proximos 14 dias (index.php:80).
INSERT INTO `opening_hours_exceptions` (`date`, `open_time`, `close_time`, `is_closed`) VALUES
  (DATE_ADD(CURDATE(), INTERVAL 3 DAY),  '10:00:00', '16:00:00', 0),
  (DATE_ADD(CURDATE(), INTERVAL 9 DAY),  NULL,       NULL,       1);

-- --- Productos de tienda ----------------------------------------------------
-- El `barcode` es lo que lee admin/boss/packages/inventory/get_BARCODE.php.
INSERT INTO `products` (`name`, `description`, `price`, `stock`, `barcode`) VALUES
  ('Agua mineral 500ml', 'Botella de agua', 1.20, 120, '8400000000017'),
  ('Bebida isotonica',   'Bebida deportiva 500ml', 2.50, 60, '8400000000024'),
  ('Barrita proteica',   'Barrita 30g de proteina', 2.90, 40, '8400000000031'),
  ('Toalla GYM One',     'Toalla de microfibra', 9.90, 25, '8400000000048'),
  ('Shaker 600ml',       'Vaso mezclador', 6.50, 18, '8400000000055');

-- --- Entrenadores personales ------------------------------------------------
-- `image` apunta a un fichero dentro de assets/img/; si no existe solo se ve
-- el hueco de la imagen, no rompe la pagina.
INSERT INTO `trainers` (`name`, `image`, `description`, `price_1hour`, `price_10sessions`) VALUES
  ('Sergio Lopez', 'trainer1.png', 'Especialista en fuerza y powerlifting.', '35', '300'),
  ('Nuria Vidal',  'trainer2.png', 'Entrenamiento funcional y movilidad.',   '32', '280');

-- --- Clases dirigidas -------------------------------------------------------
-- ATENCION: day_of_week guarda el nombre TRADUCIDO del dia, tal como sale del
-- fichero de idioma (admin/trainers/timetable/index.php:169). Estos valores
-- coinciden con assets/lang/ES.json, que es el LANG_CODE configurado en .env.
-- Si cambias LANG_CODE, estas filas dejaran de mostrarse en la cuadricula.
INSERT INTO `timetable` (`event_name`, `start_time`, `end_time`, `day_of_week`, `color`) VALUES
  ('Spinning',   '09:00:00', '10:00:00', 'Lunes',     '#0950dc'),
  ('Yoga',       '18:00:00', '19:00:00', 'Lunes',     '#16a34a'),
  ('CrossFit',   '19:00:00', '20:00:00', 'Martes',    '#dc2626'),
  ('Pilates',    '10:00:00', '11:00:00', 'Miercoles', '#9333ea'),
  ('Body Pump',  '18:30:00', '19:30:00', 'Jueves',    '#ea580c'),
  ('Zumba',      '19:00:00', '20:00:00', 'Viernes',   '#db2777'),
  ('Funcional',  '10:00:00', '11:00:00', 'Sabado',    '#0891b2');

-- --- Historico para que las estadisticas no salgan vacias -------------------
INSERT INTO `workout_stats` (`userid`, `duration`, `workout_date`) VALUES
  (1000000001, 65, DATE_SUB(CURDATE(), INTERVAL 1 DAY)),
  (1000000001, 72, DATE_SUB(CURDATE(), INTERVAL 3 DAY)),
  (1000000001, 58, DATE_SUB(CURDATE(), INTERVAL 6 DAY)),
  (1000000001, 80, DATE_SUB(CURDATE(), INTERVAL 12 DAY)),
  (1000000002, 45, DATE_SUB(CURDATE(), INTERVAL 2 DAY)),
  (1000000002, 90, DATE_SUB(CURDATE(), INTERVAL 8 DAY)),
  (1000000002, 55, DATE_SUB(CURDATE(), INTERVAL 20 DAY));

INSERT INTO `revenu_stats` (`date`, `bank_card`, `cash`) VALUES
  (DATE_SUB(CURDATE(), INTERVAL 1 DAY),  45.00, 16.00),
  (DATE_SUB(CURDATE(), INTERVAL 2 DAY),  70.00,  8.00),
  (DATE_SUB(CURDATE(), INTERVAL 3 DAY),   0.00, 24.00),
  (DATE_SUB(CURDATE(), INTERVAL 10 DAY), 120.00, 8.00);

-- --- Registro de actividad --------------------------------------------------
INSERT INTO `logs` (`userid`, `action`, `actioncolor`, `details`, `time`) VALUES
  (1, 'Instalacion inicial con datos de prueba', 'info', '{"origen":"docker/sql/03-seed.sql"}', NOW());
