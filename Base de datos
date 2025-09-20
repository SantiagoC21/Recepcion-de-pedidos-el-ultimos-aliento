-- =========================================================
-- POS básico - Tablas mínimas
-- MySQL 8.x / InnoDB / utf8mb4
-- =========================================================
CREATE DATABASE IF NOT EXISTS el_ultimo_aliento
  DEFAULT CHARACTER SET utf8mb4
  DEFAULT COLLATE utf8mb4_0900_ai_ci;
USE el_ultimo_aliento;

-- Limpieza segura en orden de dependencias
DROP TABLE IF EXISTS pago;
DROP TABLE IF EXISTS venta_detalle;
DROP TABLE IF EXISTS venta;
DROP TABLE IF EXISTS sesion_caja;
DROP TABLE IF EXISTS producto_precio;
DROP TABLE IF EXISTS lista_precio;
DROP TABLE IF EXISTS producto;
DROP TABLE IF EXISTS categoria;

-- =========================
-- 1) Catálogo
-- =========================
CREATE TABLE categoria (
  id              BIGINT PRIMARY KEY AUTO_INCREMENT,
  nombre          VARCHAR(60) NOT NULL,
  color_hex       CHAR(7)      DEFAULT '#CCCCCC',         -- #RRGGBB
  orden           INT          DEFAULT 0,
  visible_tactil  BOOLEAN      DEFAULT TRUE,              -- aparece en la grilla táctil
  activo          BOOLEAN      DEFAULT TRUE,
  created_at      DATETIME     DEFAULT CURRENT_TIMESTAMP,
  updated_at      DATETIME     DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  CONSTRAINT uq_categoria_nombre UNIQUE (nombre)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE producto (
  id               BIGINT PRIMARY KEY AUTO_INCREMENT,
  codigo           VARCHAR(30) UNIQUE,
  nombre           VARCHAR(120) NOT NULL,
  categoria_id     BIGINT NOT NULL,
  tipo             ENUM('INSUMO','PLATO','BEBIDA','SERVICIO') NOT NULL DEFAULT 'PLATO',
  unidad           VARCHAR(15)  DEFAULT 'UN',
  controla_stock   BOOLEAN      DEFAULT FALSE,            -- mueve kardex
  activo           BOOLEAN      DEFAULT TRUE,
  created_at       DATETIME     DEFAULT CURRENT_TIMESTAMP,
  updated_at       DATETIME     DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  CONSTRAINT fk_prod_cat
    FOREIGN KEY (categoria_id) REFERENCES categoria(id)
    ON UPDATE CASCADE ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- =========================
-- 2) Listas de precio
-- =========================
CREATE TABLE lista_precio (
  id              BIGINT PRIMARY KEY AUTO_INCREMENT,
  nombre          VARCHAR(60) NOT NULL,
  moneda          CHAR(3)     NOT NULL DEFAULT 'PEN',     -- ISO-4217
  canal           ENUM('SALON','LLEVAR','DELIVERY','MAYORISTA','PROMO') NULL,
  activo          BOOLEAN     DEFAULT TRUE,
  horario_inicio  TIME NULL,
  horario_fin     TIME NULL,
  dias_semana     VARCHAR(7) NULL,                        -- ej: LMXJVSD
  vigente_desde   DATETIME    DEFAULT CURRENT_TIMESTAMP,  -- ventana de la lista (opcional)
  vigente_hasta   DATETIME    NULL,
  created_at      DATETIME    DEFAULT CURRENT_TIMESTAMP,
  updated_at      DATETIME    DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  CONSTRAINT uq_lp_nombre_moneda UNIQUE (nombre, moneda)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Relación N:N producto↔lista, con historial opcional por vigencia
CREATE TABLE producto_precio (
  producto_id      BIGINT NOT NULL,
  lista_precio_id  BIGINT NOT NULL,
  precio           DECIMAL(12,2) NOT NULL,                -- normalmente SIN IGV
  vigente_desde    DATETIME    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  vigente_hasta    DATETIME    NULL,
  created_at       DATETIME    DEFAULT CURRENT_TIMESTAMP,
  updated_at       DATETIME    DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (producto_id, lista_precio_id, vigente_desde),
  CONSTRAINT fk_pp_prod
    FOREIGN KEY (producto_id) REFERENCES producto(id)
    ON UPDATE CASCADE ON DELETE RESTRICT,
  CONSTRAINT fk_pp_lp
    FOREIGN KEY (lista_precio_id) REFERENCES lista_precio(id)
    ON UPDATE CASCADE ON DELETE RESTRICT,
  INDEX ix_pp_lp_prod (lista_precio_id, producto_id, vigente_desde)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- =========================
-- 3) Caja y ventas
-- =========================
CREATE TABLE sesion_caja (
  id             BIGINT PRIMARY KEY AUTO_INCREMENT,
  numero_caja    VARCHAR(30)  NOT NULL,                   -- "Caja 1"
  usuario_nombre VARCHAR(60)  NOT NULL,                   -- quien abrió
  ts_apertura    DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  ts_cierre      DATETIME     NULL,
  monto_inicial  DECIMAL(12,2) NOT NULL DEFAULT 0.00,
  monto_cierre   DECIMAL(12,2) NULL,
  estado         ENUM('ABIERTA','CERRADA') NOT NULL DEFAULT 'ABIERTA',
  created_at     DATETIME     DEFAULT CURRENT_TIMESTAMP,
  updated_at     DATETIME     DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE venta (
  id               BIGINT PRIMARY KEY AUTO_INCREMENT,
  sesion_caja_id   BIGINT NOT NULL,
  lista_precio_id  BIGINT NOT NULL,                       -- contexto tarifario
  ts_creacion      DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  ts_cierre        DATETIME NULL,
  origen           ENUM('SALON','LLEVAR','DELIVERY') NOT NULL DEFAULT 'SALON',
  estado           ENUM('ABIERTA','COBRADA','ANULADA') NOT NULL DEFAULT 'ABIERTA',
  subtotal         DECIMAL(12,2) NOT NULL DEFAULT 0.00,   -- suma líneas (base)
  igv              DECIMAL(12,2) NOT NULL DEFAULT 0.00,   -- impuesto
  total            DECIMAL(12,2) NOT NULL DEFAULT 0.00,   -- subtotal+igv
  created_at       DATETIME     DEFAULT CURRENT_TIMESTAMP,
  updated_at       DATETIME     DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  CONSTRAINT fk_venta_sesion
    FOREIGN KEY (sesion_caja_id)  REFERENCES sesion_caja(id)
    ON UPDATE CASCADE ON DELETE RESTRICT,
  CONSTRAINT fk_venta_lp
    FOREIGN KEY (lista_precio_id) REFERENCES lista_precio(id)
    ON UPDATE CASCADE ON DELETE RESTRICT,
  INDEX ix_venta_creacion (ts_creacion),
  INDEX ix_venta_estado (estado)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE venta_detalle (
  id             BIGINT PRIMARY KEY AUTO_INCREMENT,
  venta_id       BIGINT NOT NULL,
  producto_id    BIGINT NOT NULL,
  descripcion    VARCHAR(140) NOT NULL,                   -- texto impreso (snapshot)
  cantidad       DECIMAL(12,3) NOT NULL,
  precio_unit    DECIMAL(12,2) NOT NULL,                  -- base (sin IGV) snapshot
  subtotal       DECIMAL(12,2) NOT NULL,                  -- cantidad * precio_unit
  igv            DECIMAL(12,2) NOT NULL,
  total          DECIMAL(12,2) NOT NULL,                  -- subtotal + igv
  created_at     DATETIME DEFAULT CURRENT_TIMESTAMP,
  updated_at     DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  CONSTRAINT fk_vd_venta
    FOREIGN KEY (venta_id) REFERENCES venta(id)
    ON UPDATE CASCADE ON DELETE RESTRICT,
  CONSTRAINT fk_vd_prod
    FOREIGN KEY (producto_id) REFERENCES producto(id)
    ON UPDATE CASCADE ON DELETE RESTRICT,
  INDEX ix_vd_venta (venta_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE pago (
  id           BIGINT PRIMARY KEY AUTO_INCREMENT,
  venta_id     BIGINT NOT NULL,
  medio        ENUM('EFECTIVO','TARJETA','YAPE','PLIN','TRANSFER') NOT NULL,
  monto        DECIMAL(12,2) NOT NULL,
  moneda       CHAR(3) NOT NULL DEFAULT 'PEN',
  ts_pago      DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  referencia   VARCHAR(80) NULL,                          -- nro operación, voucher
  created_at   DATETIME DEFAULT CURRENT_TIMESTAMP,
  updated_at   DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  CONSTRAINT fk_pago_venta
    FOREIGN KEY (venta_id) REFERENCES venta(id)
    ON UPDATE CASCADE ON DELETE RESTRICT,
  INDEX ix_pago_venta (venta_id),
  INDEX ix_pago_fecha (ts_pago)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;


INSERT INTO categoria (nombre, color_hex, orden, visible_tactil, activo) values
('PLATOS','#2E8B57',1, TRUE, TRUE),
('BEBIDAS','#6A5ACD',2, TRUE, TRUE),
('POSTRES','#2E8B57',3, TRUE, TRUE);

INSERT INTO producto (codigo, nombre, categoria_id, tipo, unidad, controla_stock, activo) values
('ENT-001','ENSALADA DE PALTA', (SELECT id FROM categoria WHERE nombre='PLATOS'), 'ENTRADA', 'UN', TRUE, TRUE),
('ENT-002','CEVICHE DE PESCADO', (SELECT id FROM categoria WHERE nombre='PLATOS'), 'ENTRADA', 'UN', TRUE, TRUE),
('ENT-003','TEQUEÑOS CON SALSA GOLF', (SELEC'#2E8B57'id FROM categoria WHERE nombre='PLATOS'), 'ENTRADA', 'UN', TRUE, TRUE),
('SOP-001','SOPA DE CASA CON CARNE', (SELECT id FROM categoria WHERE nombre='PLATOS'), 'SOPA', 'UN', TRUE, TRUE),
('SEG-001','ESTOFADO DE POLLO CON PAPAS', (SELECT id FROM categoria WHERE nombre='PLATOS'), 'SEGUNDO', 'UN', TRUE, TRUE),
('SEG-002','SECO DE CABRITO CON FREJOLES', (SELECT id FROM categoria WHERE nombre='PLATOS'), 'SEGUNDO', 'UN', TRUE, TRUE),
('SEG-003','CAU CAU CRIOLLO', (SELECT id FROM categoria WHERE nombre='PLATOS'), 'SEGUNDO', 'UN', TRUE, TRUE),
('SEG-004','PESCADO FRITO CON FREJOLES', (SELECT id FROM categoria WHERE nombre='PLATOS'), 'SEGUNDO', 'UN', TRUE, TRUE),
('SEG-006','ARROZ A LA CUBANA', (SELECT id FROM categoria WHERE nombre='PLATOS'), 'SEGUNDO', 'UN', TRUE, TRUE),
('SEG-007','CHULETA CON PAPAS FRITAS', (SELECT id FROM categoria WHERE nombre='PLATOS'), 'SEGUNDO', 'UN', TRUE, TRUE),
('SEG-008','MILANESA CON PAPAS FRITAS', (SELECT id FROM categoria WHERE nombre='PLATOS'), 'SEGUNDO', 'UN', TRUE, TRUE),
('SEG-009','HIGADO FRITO', (SELECT id FROM categoria WHERE nombre='PLATOS'), 'SEGUNDO', 'UN', TRUE, TRUE),
('SEG-010','HIGADO SALTADO', (SELECT id FROM categoria WHERE nombre='PLATOS'), 'SEGUNDO', 'UN', TRUE, TRUE),
('SEG-011','HIGADO ENCEBOLLADO', (SELECT id FROM categoria WHERE nombre='PLATOS'), 'SEGUNDO', 'UN', TRUE, TRUE),
('SEG-012','TORTILLA DE VERDURAS', (SELECT id FROM categoria WHERE nombre='PLATOS'), 'SEGUNDO', 'UN', TRUE, TRUE),
('EJE-001','LOMO SALTADO', (SELECT id FROM categoria WHERE nombre='PLATOS'), 'EJECUTIVO', 'UN', TRUE, TRUE),
('EJE-002','SALTADO DE POLLO', (SELECT id FROM categoria WHERE nombre='PLATOS'), 'EJECUTIVO', 'UN', TRUE, TRUE),
('EJE-003','TALLARIN SALTADO', (SELECT id FROM categoria WHERE nombre='PLATOS'), 'EJECUTIVO', 'UN', TRUE, TRUE),
('EJE-004','ARROZ CHAUFA', (SELECT id FROM categoria WHERE nombre='PLATOS'), 'EJECUTIVO', 'UN', TRUE, TRUE),
('EJE-005','FILETE DE POLLO CON PAPA FRITA', (SELECT id FROM categoria WHERE nombre='PLATOS'), 'EJECUTIVO', 'UN', TRUE, TRUE),
('EJE-006','BISTECK CON PAPA FRITA', (SELECT id FROM categoria WHERE nombre='PLATOS'), 'EJECUTIVO', 'UN', TRUE, TRUE),
('EJE-007','POLLO BROASTER CON PAPA FRITA', (SELECT id FROM categoria WHERE nombre='PLATOS'), 'EJECUTIVO', 'UN', TRUE, TRUE),
('EJE-008','TALLARIN A LO ALFREDO', (SELECT id FROM categoria WHERE nombre='PLATOS'), 'EJECUTIVO', 'UN', TRUE, TRUE),
('MAR-001','ARROZ CON MARISCOS', (SELECT id FROM categoria WHERE nombre='PLATOS'), 'MARINO', 'UN', TRUE, TRUE),
('MAR-002','PESCADO AL AJO', (SELECT id FROM categoria WHERE nombre='PLATOS'), 'MARINO', 'UN', TRUE, TRUE),
('MAR-003','PESCADO A LO MACHO', (SELECT id FROM categoria WHERE nombre='PLATOS'), 'MARINO', 'UN', TRUE, TRUE),
('MAR-004','CHICHARRON DE PESCADO', (SELECT id FROM categoria WHERE nombre='PLATOS'), 'MARINO', 'UN', TRUE, TRUE),
('MAR-005','SUDADO DE PESCADO', (SELECT id FROM categoria WHERE nombre='PLATOS'), 'MARINO', 'UN', TRUE, TRUE),
('MAR-006','PESCADO A LA CHORRILLANA', (SELECT id FROM categoria WHERE nombre='PLATOS'), 'MARINO', 'UN', TRUE, TRUE),
('MAR-007','MILANESA DE PESCADO', (SELECT id FROM categoria WHERE nombre='PLATOS'), 'MARINO', 'UN', TRUE, TRUE),
('MAR-008','CHAUFA DE PESCADO', (SELECT id FROM categoria WHERE nombre='PLATOS'), 'MARINO', 'UN', TRUE, TRUE),
('MAR-008','CHAUFA DE MARISCOS', (SELECT id FROM categoria WHERE nombre='PLATOS'), 'MARINO', 'UN', TRUE, TRUE)
ON DUPLICATE KEY UPDATE
  nombre         = VALUES(nombre),
  categoria_id   = VALUES(categoria_id),
  tipo           = VALUES(tipo),
  unidad         = VALUES(unidad),
  controla_stock = VALUES(controla_stock),
  activo         = VALUES(activo),
  updated_at     = CURRENT_TIMESTAMP;

INSERT INTO lista_precio (nombre, moneda, canal, activo, horario_inicio, horario_fin, dias_semana, vigente_desde, vigente_hasta) values
('MENU DIARIO', 'PEN', 'SALON', 'TRUE', '11:00:00', '17:00:00','LMXJVS',CURRENT_TIMESTAMP,NULL),
('EJECUTIVO DIARIO', 'PEN', 'SALON', 'TRUE', '11:00:00', '17:00:00','LMXJVSD',CURRENT_TIMESTAMP,NULL),
('MARINO DIARIO', 'PEN', 'SALON', 'TRUE', '11:00:00', '17:00:00','LMXJVSD',CURRENT_TIMESTAMP,NULL),
('PARA LLEVAR', 'PEN','LLEVAR', 'TRUE', NULL, NULL,'LMXJVSD',CURRENT_TIMESTAMP,NULL),
('MENU DOMINGO','PEN','SALON','TRUE','11:00:00','17:00:00','D',CURRENT_TIMESTAMP,NULL),
('CENA','PEN','SALON','TRUE','17:00:00','22:00:00','LMXJVSD',CURRENT_TIMESTAMP,NULL)
('CENA','PEN','SALON','TRUE','11:00:00','17:00:00','LMXJVSD',CURRENT_TIMESTAMP,NULL)
ON DUPLICATE KEY UPDATE
  canal          = VALUES(canal),
  activo         = VALUES(activo),
  horario_inicio = VALUES(horario_inicio),
  horario_fin    = VALUES(horario_fin),
  dias_semana    = VALUES(dias_semana),
  vigente_desde  = VALUES(vigente_desde),
  vigente_hasta  = VALUES(vigente_hasta),
  updated_at     = CURRENT_TIMESTAMP;

INSERT INTO producto_precio (producto_id, lista_precio_id, precio, vigente_desde, vigente_hasta) values
( (SELECT id FROM producto WHERE codigo='ENT-001'),
  (SELECT id FROM lista_precio WHERE nombre='SOLO ENTRADA'),
  4,CURRENT_TIMESTAMP,NULL ),
( (SELECT id FROM producto WHERE codigo='ENT-002'),
  (SELECT id FROM lista_precio WHERE nombre='SOLO ENTRADA'),
  4,CURRENT_TIMESTAMP,NULL ),
( (SELECT id FROM producto WHERE codigo='ENT-003'),
  (SELECT id FROM lista_precio WHERE nombre='SOLO ENTRADA'),
  4,CURRENT_TIMESTAMP,NULL ),
( (SELECT id FROM producto WHERE codigo='SOP-001'),
  (SELECT id FROM lista_precio WHERE nombre='SOLO ENTRADA'),
  4,CURRENT_TIMESTAMP,NULL ),
( (SELECT id FROM producto WHERE codigo='SEG-001'),
  (SELECT id FROM lista_precio WHERE nombre='MENU DIARIO'),
  10,CURRENT_TIMESTAMP,NULL ),
( (SELECT id FROM producto WHERE codigo='SEG-002'),
  (SELECT id FROM lista_precio WHERE nombre='MENU DIARIO'),
  10,CURRENT_TIMESTAMP,NULL ),
( (SELECT id FROM producto WHERE codigo='SEG-003'),
  (SELECT id FROM lista_precio WHERE nombre='MENU DIARIO'),
  10,CURRENT_TIMESTAMP,NULL ),
( (SELECT id FROM producto WHERE codigo='SEG-004'),
  (SELECT id FROM lista_precio WHERE nombre='MENU DIARIO'),
  10,CURRENT_TIMESTAMP,NULL ),
( (SELECT id FROM producto WHERE codigo='SEG-005'),
  (SELECT id FROM lista_precio WHERE nombre='MENU DIARIO'),
  10,CURRENT_TIMESTAMP,NULL ),
( (SELECT id FROM producto WHERE codigo='SEG-006'),
  (SELECT id FROM lista_precio WHERE nombre='MENU DIARIO'),
  10,CURRENT_TIMESTAMP,NULL ),
( (SELECT id FROM producto WHERE codigo='SEG-007'),
  (SELECT id FROM lista_precio WHERE nombre='MENU DIARIO'),
  10,CURRENT_TIMESTAMP,NULL ),
( (SELECT id FROM producto WHERE codigo='SEG-008'),
  (SELECT id FROM lista_precio WHERE nombre='MENU DIARIO'),
  10,CURRENT_TIMESTAMP,NULL ),
( (SELECT id FROM producto WHERE codigo='SEG-009'),
  (SELECT id FROM lista_precio WHERE nombre='MENU DIARIO'),
  10,CURRENT_TIMESTAMP,NULL ),
( (SELECT id FROM producto WHERE codigo='SEG-010'),
  (SELECT id FROM lista_precio WHERE nombre='MENU DIARIO'),
  10,CURRENT_TIMESTAMP,NULL ),
( (SELECT id FROM producto WHERE codigo='SEG-011'),
  (SELECT id FROM lista_precio WHERE nombre='MENU DIARIO'),
  10,CURRENT_TIMESTAMP,NULL ),
( (SELECT id FROM producto WHERE codigo='SEG-012'),
  (SELECT id FROM lista_precio WHERE nombre='MENU DIARIO'),
  10,CURRENT_TIMESTAMP,NULL ),
( (SELECT id FROM producto WHERE codigo='EJE-001'),
  (SELECT id FROM lista_precio WHERE nombre='EJECUTIVO DIARIO'),
  12,CURRENT_TIMESTAMP,NULL ),
( (SELECT id FROM producto WHERE codigo='EJE-002'),
  (SELECT id FROM lista_precio WHERE nombre='EJECUTIVO DIARIO'),
  12,CURRENT_TIMESTAMP,NULL ),
( (SELECT id FROM producto WHERE codigo='EJE-003'),
  (SELECT id FROM lista_precio WHERE nombre='EJECUTIVO DIARIO'),
  12,CURRENT_TIMESTAMP,NULL ),
( (SELECT id FROM producto WHERE codigo='EJE-004'),
  (SELECT id FROM lista_precio WHERE nombre='EJECUTIVO DIARIO'),
  12,CURRENT_TIMESTAMP,NULL ),
( (SELECT id FROM producto WHERE codigo='EJE-005'),
  (SELECT id FROM lista_precio WHERE nombre='EJECUTIVO DIARIO'),
  12,CURRENT_TIMESTAMP,NULL ),
( (SELECT id FROM producto WHERE codigo='EJE-006'),
  (SELECT id FROM lista_precio WHERE nombre='EJECUTIVO DIARIO'),
  12,CURRENT_TIMESTAMP,NULL ),
( (SELECT id FROM producto WHERE codigo='EJE-007'),
  (SELECT id FROM lista_precio WHERE nombre='EJECUTIVO DIARIO'),
  12,CURRENT_TIMESTAMP,NULL ),
( (SELECT id FROM producto WHERE codigo='EJE-008'),
  (SELECT id FROM lista_precio WHERE nombre='EJECUTIVO DIARIO'),
  12,CURRENT_TIMESTAMP,NULL ),
( (SELECT id FROM producto WHERE codigo='MAR-001'),
  (SELECT id FROM lista_precio WHERE nombre='MARINO DIARIO'),
  16,CURRENT_TIMESTAMP,NULL ),
( (SELECT id FROM producto WHERE codigo='MAR-002'),
  (SELECT id FROM lista_precio WHERE nombre='MARINO DIARIO'),
  16,CURRENT_TIMESTAMP,NULL ),
( (SELECT id FROM producto WHERE codigo='MAR-003'),
  (SELECT id FROM lista_precio WHERE nombre='MARINO DIARIO'),
  16,CURRENT_TIMESTAMP,NULL ),
( (SELECT id FROM producto WHERE codigo='MAR-004'),
  (SELECT id FROM lista_precio WHERE nombre='MARINO DIARIO'),
  16,CURRENT_TIMESTAMP,NULL ),
( (SELECT id FROM producto WHERE codigo='MAR-005'),
  (SELECT id FROM lista_precio WHERE nombre='MARINO DIARIO'),
  16,CURRENT_TIMESTAMP,NULL ),
( (SELECT id FROM producto WHERE codigo='MAR-006'),
  (SELECT id FROM lista_precio WHERE nombre='MARINO DIARIO'),
  16,CURRENT_TIMESTAMP,NULL ),
( (SELECT id FROM producto WHERE codigo='MAR-007'),
  (SELECT id FROM lista_precio WHERE nombre='MARINO DIARIO'),
  16,CURRENT_TIMESTAMP,NULL ),
( (SELECT id FROM producto WHERE codigo='MAR-008'),
  (SELECT id FROM lista_precio WHERE nombre='MARINO DIARIO'),
  16,CURRENT_TIMESTAMP,NULL ),
( (SELECT id FROM producto WHERE codigo='MAR-008'),
  (SELECT id FROM lista_precio WHERE nombre='MARINO DIARIO'),
  16,CURRENT_TIMESTAMP,NULL ),
( (SELECT id FROM producto WHERE codigo='ENT-001'),
  (SELECT id FROM lista_precio WHERE nombre='PARA LLEVAR'),
  5,CURRENT_TIMESTAMP,NULL ),
( (SELECT id FROM producto WHERE codigo='ENT-002'),
  (SELECT id FROM lista_precio WHERE nombre='PARA LLEVAR'),
  5,CURRENT_TIMESTAMP,NULL ),
( (SELECT id FROM producto WHERE codigo='ENT-003'),
  (SELECT id FROM lista_precio WHERE nombre='PARA LLEVAR'),
  5,CURRENT_TIMESTAMP,NULL ),
( (SELECT id FROM producto WHERE codigo='SOP-001'),
  (SELECT id FROM lista_precio WHERE nombre='PARA LLEVAR'),
  5,CURRENT_TIMESTAMP,NULL ),
( (SELECT id FROM producto WHERE codigo='SEG-001'),
  (SELECT id FROM lista_precio WHERE nombre='PARA LLEVAR'),
  11,CURRENT_TIMESTAMP,NULL ),
( (SELECT id FROM producto WHERE codigo='SEG-002'),
  (SELECT id FROM lista_precio WHERE nombre='PARA LLEVAR'),
  11,CURRENT_TIMESTAMP,NULL ),
( (SELECT id FROM producto WHERE codigo='SEG-003'),
  (SELECT id FROM lista_precio WHERE nombre='PARA LLEVAR'),
  11,CURRENT_TIMESTAMP,NULL ),
( (SELECT id FROM producto WHERE codigo='SEG-004'),
  (SELECT id FROM lista_precio WHERE nombre='PARA LLEVAR'),
  11,CURRENT_TIMESTAMP,NULL ),
( (SELECT id FROM producto WHERE codigo='SEG-005'),
  (SELECT id FROM lista_precio WHERE nombre='PARA LLEVAR'),
  11,CURRENT_TIMESTAMP,NULL ),
( (SELECT id FROM producto WHERE codigo='SEG-006'),
  (SELECT id FROM lista_precio WHERE nombre='PARA LLEVAR'),
  11,CURRENT_TIMESTAMP,NULL ),
( (SELECT id FROM producto WHERE codigo='SEG-007'),
  (SELECT id FROM lista_precio WHERE nombre='PARA LLEVAR'),
  11,CURRENT_TIMESTAMP,NULL ),
( (SELECT id FROM producto WHERE codigo='SEG-008'),
  (SELECT id FROM lista_precio WHERE nombre='PARA LLEVAR'),
  11,CURRENT_TIMESTAMP,NULL ),
( (SELECT id FROM producto WHERE codigo='SEG-009'),
  (SELECT id FROM lista_precio WHERE nombre='PARA LLEVAR'),
  11,CURRENT_TIMESTAMP,NULL ),
( (SELECT id FROM producto WHERE codigo='SEG-010'),
  (SELECT id FROM lista_precio WHERE nombre='PARA LLEVAR'),
  11,CURRENT_TIMESTAMP,NULL ),
( (SELECT id FROM producto WHERE codigo='SEG-011'),
  (SELECT id FROM lista_precio WHERE nombre='PARA LLEVAR'),
  11,CURRENT_TIMESTAMP,NULL ),
( (SELECT id FROM producto WHERE codigo='SEG-012'),
  (SELECT id FROM lista_precio WHERE nombre='PARA LLEVAR'),
  11,CURRENT_TIMESTAMP,NULL ),
( (SELECT id FROM producto WHERE codigo='EJE-001'),
  (SELECT id FROM lista_precio WHERE nombre='PARA LLEVAR'),
  13,CURRENT_TIMESTAMP,NULL ),
( (SELECT id FROM producto WHERE codigo='EJE-002'),
  (SELECT id FROM lista_precio WHERE nombre='PARA LLEVAR'),
  13,CURRENT_TIMESTAMP,NULL ),
( (SELECT id FROM producto WHERE codigo='EJE-003'),
  (SELECT id FROM lista_precio WHERE nombre='PARA LLEVAR'),
  13,CURRENT_TIMESTAMP,NULL ),
( (SELECT id FROM producto WHERE codigo='EJE-004'),
  (SELECT id FROM lista_precio WHERE nombre='PARA LLEVAR'),
  13,CURRENT_TIMESTAMP,NULL ),
( (SELECT id FROM producto WHERE codigo='EJE-005'),
  (SELECT id FROM lista_precio WHERE nombre='PARA LLEVAR'),
  13,CURRENT_TIMESTAMP,NULL ),
( (SELECT id FROM producto WHERE codigo='EJE-006'),
  (SELECT id FROM lista_precio WHERE nombre='PARA LLEVAR'),
  13,CURRENT_TIMESTAMP,NULL ),
( (SELECT id FROM producto WHERE codigo='EJE-007'),
  (SELECT id FROM lista_precio WHERE nombre='PARA LLEVAR'),
  13,CURRENT_TIMESTAMP,NULL ),
( (SELECT id FROM producto WHERE codigo='EJE-008'),
  (SELECT id FROM lista_precio WHERE nombre='PARA LLEVAR'),
  13,CURRENT_TIMESTAMP,NULL ),
( (SELECT id FROM producto WHERE codigo='MAR-001'),
  (SELECT id FROM lista_precio WHERE nombre='PARA LLEVAR'),
  17,CURRENT_TIMESTAMP,NULL ),
( (SELECT id FROM producto WHERE codigo='MAR-002'),
  (SELECT id FROM lista_precio WHERE nombre='PARA LLEVAR'),
  17,CURRENT_TIMESTAMP,NULL ),
( (SELECT id FROM producto WHERE codigo='MAR-003'),
  (SELECT id FROM lista_precio WHERE nombre='PARA LLEVAR'),
  17,CURRENT_TIMESTAMP,NULL ),
( (SELECT id FROM producto WHERE codigo='MAR-004'),
  (SELECT id FROM lista_precio WHERE nombre='PARA LLEVAR'),
  17,CURRENT_TIMESTAMP,NULL ),
( (SELECT id FROM producto WHERE codigo='MAR-005'),
  (SELECT id FROM lista_precio WHERE nombre='PARA LLEVAR'),
  17,CURRENT_TIMESTAMP,NULL ),
( (SELECT id FROM producto WHERE codigo='MAR-006'),
  (SELECT id FROM lista_precio WHERE nombre='PARA LLEVAR'),
  17,CURRENT_TIMESTAMP,NULL ),
( (SELECT id FROM producto WHERE codigo='MAR-007'),
  (SELECT id FROM lista_precio WHERE nombre='PARA LLEVAR'),
  17,CURRENT_TIMESTAMP,NULL ),
( (SELECT id FROM producto WHERE codigo='MAR-008'),
  (SELECT id FROM lista_precio WHERE nombre='PARA LLEVAR'),
  17,CURRENT_TIMESTAMP,NULL ),
( (SELECT id FROM producto WHERE codigo='MAR-008'),
  (SELECT id FROM lista_precio WHERE nombre='PARA LLEVAR'),
  17,CURRENT_TIMESTAMP,NULL ),
( (SELECT id FROM producto WHERE codigo='SEG-001'),
  (SELECT id FROM lista_precio WHERE nombre='MENU DOMINGO'),
  11,CURRENT_TIMESTAMP,NULL ),
( (SELECT id FROM producto WHERE codigo='SEG-002'),
  (SELECT id FROM lista_precio WHERE nombre='MENU DOMINGO'),
  11,CURRENT_TIMESTAMP,NULL ),
( (SELECT id FROM producto WHERE codigo='SEG-003'),
  (SELECT id FROM lista_precio WHERE nombre='MENU DOMINGO'),
  11,CURRENT_TIMESTAMP,NULL ),
( (SELECT id FROM producto WHERE codigo='SEG-004'),
  (SELECT id FROM lista_precio WHERE nombre='MENU DOMINGO'),
  11,CURRENT_TIMESTAMP,NULL ),
( (SELECT id FROM producto WHERE codigo='SEG-005'),
  (SELECT id FROM lista_precio WHERE nombre='MENU DOMINGO'),
  11,CURRENT_TIMESTAMP,NULL ),
( (SELECT id FROM producto WHERE codigo='SEG-006'),
  (SELECT id FROM lista_precio WHERE nombre='MENU DOMINGO'),
  11,CURRENT_TIMESTAMP,NULL ),
( (SELECT id FROM producto WHERE codigo='SEG-007'),
  (SELECT id FROM lista_precio WHERE nombre='MENU DOMINGO'),
  11,CURRENT_TIMESTAMP,NULL ),
( (SELECT id FROM producto WHERE codigo='SEG-008'),
  (SELECT id FROM lista_precio WHERE nombre='MENU DOMINGO'),
  11,CURRENT_TIMESTAMP,NULL ),
( (SELECT id FROM producto WHERE codigo='SEG-009'),
  (SELECT id FROM lista_precio WHERE nombre='MENU DOMINGO'),
  11,CURRENT_TIMESTAMP,NULL ),
( (SELECT id FROM producto WHERE codigo='SEG-010'),
  (SELECT id FROM lista_precio WHERE nombre='MENU DOMINGO'),
  11,CURRENT_TIMESTAMP,NULL ),
( (SELECT id FROM producto WHERE codigo='SEG-011'),
  (SELECT id FROM lista_precio WHERE nombre='MENU DOMINGO'),
  11,CURRENT_TIMESTAMP,NULL ),
( (SELECT id FROM producto WHERE codigo='SEG-012'),
  (SELECT id FROM lista_precio WHERE nombre='MENU DOMINGO'),
  11,CURRENT_TIMESTAMP,NULL ),
( (SELECT id FROM producto WHERE codigo='EJE-001'),
  (SELECT id FROM lista_precio WHERE nombre='CENA'),
  13,CURRENT_TIMESTAMP,NULL ),
( (SELECT id FROM producto WHERE codigo='EJE-002'),
  (SELECT id FROM lista_precio WHERE nombre='CENA'),
  13,CURRENT_TIMESTAMP,NULL ),
( (SELECT id FROM producto WHERE codigo='EJE-003'),
  (SELECT id FROM lista_precio WHERE nombre='CENA'),
  13,CURRENT_TIMESTAMP,NULL ),
( (SELECT id FROM producto WHERE codigo='EJE-004'),
  (SELECT id FROM lista_precio WHERE nombre='CENA'),
  13,CURRENT_TIMESTAMP,NULL ),
( (SELECT id FROM producto WHERE codigo='EJE-005'),
  (SELECT id FROM lista_precio WHERE nombre='CENA'),
  13,CURRENT_TIMESTAMP,NULL ),
( (SELECT id FROM producto WHERE codigo='EJE-006'),
  (SELECT id FROM lista_precio WHERE nombre='CENA'),
  13,CURRENT_TIMESTAMP,NULL ),
( (SELECT id FROM producto WHERE codigo='EJE-007'),
  (SELECT id FROM lista_precio WHERE nombre='CENA'),
  13,CURRENT_TIMESTAMP,NULL ),
( (SELECT id FROM producto WHERE codigo='EJE-008'),
  (SELECT id FROM lista_precio WHERE nombre='CENA'),
  13,CURRENT_TIMESTAMP,NULL )
ON DUPLICATE KEY UPDATE
  precio       = VALUES(precio),
  vigente_hasta= VALUES(vigente_hasta),
  updated_at   = CURRENT_TIMESTAMP;

INSERT INTO sesion_caja (numero_caja, usuario_nombre, ts_apertura, monto_inicial, estado) values
('CAJA 1', 'USER', NOW(), 300.00, 'ABIERTA');

INSERT INTO sesion_caja (numero_caja, usuario_nombre, ts_apertura, ts_cierre, monto_inicial, monto_cierre, estado) values
('CAJA 1', 'USER', '2025-09-14 08:00:00', '2025-09-15 22:00:00', 300.00, 1850.50, 'CERRADA'),
('CAJA 1', 'USER', '2025-09-15 08:00:00', '2025-09-15 22:00:00', 200.00, 1325.20, 'CERRADA'),
('CAJA 1', 'USER', '2025-09-16 08:00:00', '2025-09-16 22:00:00', 250.00, 1690.00, 'CERRADA'),
('CAJA 1', 'USER', '2025-09-17 08:00:00', '2025-09-16 22:00:00', 200.00, 1402.30, 'CERRADA'),
('CAJA 1', 'USER', '2025-09-18 08:00:00', '2025-09-17 22:03:00', 300.00, 1912.70, 'CERRADA');

INSERT INTO venta (sesion_caja_id, lista_precio_id, ts_creacion, origen, estado, total) values
(
  (SELECT id FROM sesion_caja
    WHERE numero_caja='CAJA 1' AND estado='ABIERTA'
    ORDER BY ts_apertura DESC LIMIT 1),
  (SELECT id FROM lista_precio WHERE nombre='MENU DIARIO' AND moneda='PEN'),
  '2025-09-19 12:10:00',
  'SALON',
  'ABIERTA',
  




)

