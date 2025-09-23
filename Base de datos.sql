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
  tipo             VARCHAR(120) NOT NULL DEFAULT 'PLATO',
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
  total            DECIMAL(12,2) NOT NULL DEFAULT 0.00,
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
  total          DECIMAL(12,2) NOT NULL,                  -- cantidad * precio_unit
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
('ENT-001','ENSALADA DE PALTA', (SELECT id FROM categoria WHERE nombre='PLATOS'), 'ENTRADA', 'UN', FALSE, TRUE),
('ENT-002','CEVICHE DE PESCADO', (SELECT id FROM categoria WHERE nombre='PLATOS'), 'ENTRADA', 'UN', FALSE, TRUE),
('ENT-003','TEQUEÑOS CON SALSA GOLF', (SELECT id FROM categoria WHERE nombre='PLATOS'), 'ENTRADA', 'UN', FALSE, TRUE),
('SOP-001','SOPA DE CASA CON CARNE', (SELECT id FROM categoria WHERE nombre='PLATOS'), 'SOPA', 'UN', FALSE, TRUE),
('SEG-001','ESTOFADO DE POLLO CON PAPAS', (SELECT id FROM categoria WHERE nombre='PLATOS'), 'SEGUNDO', 'UN', FALSE, TRUE),
('SEG-002','SECO DE CABRITO CON FREJOLES', (SELECT id FROM categoria WHERE nombre='PLATOS'), 'SEGUNDO', 'UN', FALSE, TRUE),
('SEG-003','CAU CAU CRIOLLO', (SELECT id FROM categoria WHERE nombre='PLATOS'), 'SEGUNDO', 'UN', FALSE, TRUE),
('SEG-004','PESCADO FRITO CON FREJOLES', (SELECT id FROM categoria WHERE nombre='PLATOS'), 'SEGUNDO', 'UN', FALSE, TRUE),
('SEG-005','ARROZ A LA CUBANA', (SELECT id FROM categoria WHERE nombre='PLATOS'), 'SEGUNDO', 'UN', FALSE, TRUE),
('SEG-006','CHULETA CON PAPAS FRITAS', (SELECT id FROM categoria WHERE nombre='PLATOS'), 'SEGUNDO', 'UN', FALSE, TRUE),
('SEG-007','MILANESA CON PAPAS FRITAS', (SELECT id FROM categoria WHERE nombre='PLATOS'), 'SEGUNDO', 'UN', FALSE, TRUE),
('SEG-008','HIGADO FRITO', (SELECT id FROM categoria WHERE nombre='PLATOS'), 'SEGUNDO', 'UN', FALSE, TRUE),
('SEG-009','HIGADO SALTADO', (SELECT id FROM categoria WHERE nombre='PLATOS'), 'SEGUNDO', 'UN', FALSE, TRUE),
('SEG-010','HIGADO ENCEBOLLADO', (SELECT id FROM categoria WHERE nombre='PLATOS'), 'SEGUNDO', 'UN', FALSE, TRUE),
('SEG-011','TORTILLA DE VERDURAS', (SELECT id FROM categoria WHERE nombre='PLATOS'), 'SEGUNDO', 'UN', FALSE, TRUE),
('EJE-001','LOMO SALTADO', (SELECT id FROM categoria WHERE nombre='PLATOS'), 'EJECUTIVO', 'UN', FALSE, TRUE),
('EJE-002','SALTADO DE POLLO', (SELECT id FROM categoria WHERE nombre='PLATOS'), 'EJECUTIVO', 'UN', FALSE, TRUE),
('EJE-003','TALLARIN SALTADO', (SELECT id FROM categoria WHERE nombre='PLATOS'), 'EJECUTIVO', 'UN', FALSE, TRUE),
('EJE-004','ARROZ CHAUFA', (SELECT id FROM categoria WHERE nombre='PLATOS'), 'EJECUTIVO', 'UN', FALSE, TRUE),
('EJE-005','FILETE DE POLLO CON PAPA FRITA', (SELECT id FROM categoria WHERE nombre='PLATOS'), 'EJECUTIVO', 'UN', FALSE, TRUE),
('EJE-006','BISTECK CON PAPA FRITA', (SELECT id FROM categoria WHERE nombre='PLATOS'), 'EJECUTIVO', 'UN', FALSE, TRUE),
('EJE-007','POLLO BROASTER CON PAPA FRITA', (SELECT id FROM categoria WHERE nombre='PLATOS'), 'EJECUTIVO', 'UN', FALSE, TRUE),
('EJE-008','TALLARIN A LO ALFREDO', (SELECT id FROM categoria WHERE nombre='PLATOS'), 'EJECUTIVO', 'UN', FALSE, TRUE),
('MAR-001','ARROZ CON MARISCOS', (SELECT id FROM categoria WHERE nombre='PLATOS'), 'MARINO', 'UN', FALSE, TRUE),
('MAR-002','PESCADO AL AJO', (SELECT id FROM categoria WHERE nombre='PLATOS'), 'MARINO', 'UN', FALSE, TRUE),
('MAR-003','PESCADO A LO MACHO', (SELECT id FROM categoria WHERE nombre='PLATOS'), 'MARINO', 'UN', FALSE, TRUE),
('MAR-004','CHICHARRON DE PESCADO', (SELECT id FROM categoria WHERE nombre='PLATOS'), 'MARINO', 'UN', FALSE, TRUE),
('MAR-005','SUDADO DE PESCADO', (SELECT id FROM categoria WHERE nombre='PLATOS'), 'MARINO', 'UN', FALSE, TRUE),
('MAR-006','PESCADO A LA CHORRILLANA', (SELECT id FROM categoria WHERE nombre='PLATOS'), 'MARINO', 'UN', FALSE, TRUE),
('MAR-007','MILANESA DE PESCADO', (SELECT id FROM categoria WHERE nombre='PLATOS'), 'MARINO', 'UN', FALSE, TRUE),
('MAR-008','CHAUFA DE PESCADO', (SELECT id FROM categoria WHERE nombre='PLATOS'), 'MARINO', 'UN', FALSE, TRUE),
('MAR-009','CHAUFA DE MARISCOS', (SELECT id FROM categoria WHERE nombre='PLATOS'), 'MARINO', 'UN', FALSE, TRUE)
ON DUPLICATE KEY UPDATE
  nombre         = VALUES(nombre),
  categoria_id   = VALUES(categoria_id),
  tipo           = VALUES(tipo),
  unidad         = VALUES(unidad),
  controla_stock = VALUES(controla_stock),
  activo         = VALUES(activo),
  updated_at     = CURRENT_TIMESTAMP;

INSERT INTO lista_precio (nombre, moneda, canal, activo, horario_inicio, horario_fin, dias_semana, vigente_desde, vigente_hasta) values
('MENU DIARIO', 'PEN', 'SALON', TRUE, '11:00:00', '17:00:00','LMXJVS',CURRENT_TIMESTAMP,NULL),
('EJECUTIVO DIARIO', 'PEN', 'SALON', TRUE, '11:00:00', '17:00:00','LMXJVSD',CURRENT_TIMESTAMP,NULL),
('MARINO DIARIO', 'PEN', 'SALON', TRUE, '11:00:00', '17:00:00','LMXJVSD',CURRENT_TIMESTAMP,NULL),
('PARA LLEVAR', 'PEN','LLEVAR', TRUE, NULL, NULL,'LMXJVSD',CURRENT_TIMESTAMP,NULL),
('MENU DOMINGO','PEN','SALON',TRUE,'11:00:00','17:00:00','D',CURRENT_TIMESTAMP,NULL),
('CENA','PEN','SALON',TRUE,'17:00:00','22:00:00','LMXJVSD',CURRENT_TIMESTAMP,NULL),
('SOLO ENTRADA','PEN','SALON',TRUE,'11:00:00','17:00:00','LMXJVSD',CURRENT_TIMESTAMP,NULL)
ON DUPLICATE KEY UPDATE
  canal          = VALUES(canal),
  activo         = VALUES(activo),
  horario_inicio = VALUES(horario_inicio),
  horario_fin    = VALUES(horario_fin),
  dias_semana    = VALUES(dias_semana),
  vigente_desde  = VALUES(vigente_desde),
  vigente_hasta  = VALUES(vigente_hasta),
  updated_at     = CURRENT_TIMESTAMP;

INSERT INTO producto_precio
  (producto_id, lista_precio_id, precio, vigente_desde, vigente_hasta)
VALUES
-- SOLO ENTRADA (o usa CARTA si esa es tu lista base)
((SELECT id FROM producto      WHERE codigo='ENT-001' LIMIT 1),
 (SELECT id FROM lista_precio  WHERE nombre='SOLO ENTRADA' AND moneda='PEN' LIMIT 1),
 4.00, NOW(), NULL),
((SELECT id FROM producto      WHERE codigo='ENT-002' LIMIT 1),
 (SELECT id FROM lista_precio  WHERE nombre='SOLO ENTRADA' AND moneda='PEN' LIMIT 1),
 4.00, NOW(), NULL),
((SELECT id FROM producto      WHERE codigo='ENT-003' LIMIT 1),
 (SELECT id FROM lista_precio  WHERE nombre='SOLO ENTRADA' AND moneda='PEN' LIMIT 1),
 4.00, NOW(), NULL),
((SELECT id FROM producto      WHERE codigo='SOP-001' LIMIT 1),
 (SELECT id FROM lista_precio  WHERE nombre='SOLO ENTRADA' AND moneda='PEN' LIMIT 1),
 4.00, NOW(), NULL),

-- MENU DIARIO (segundos a 10)
((SELECT id FROM producto WHERE codigo='SEG-001' LIMIT 1),
 (SELECT id FROM lista_precio WHERE nombre='MENU DIARIO' AND moneda='PEN' LIMIT 1),
 10.00, NOW(), NULL),
((SELECT id FROM producto WHERE codigo='SEG-002' LIMIT 1),
 (SELECT id FROM lista_precio WHERE nombre='MENU DIARIO' AND moneda='PEN' LIMIT 1),
 10.00, NOW(), NULL),
((SELECT id FROM producto WHERE codigo='SEG-003' LIMIT 1),
 (SELECT id FROM lista_precio WHERE nombre='MENU DIARIO' AND moneda='PEN' LIMIT 1),
 10.00, NOW(), NULL),
((SELECT id FROM producto WHERE codigo='SEG-004' LIMIT 1),
 (SELECT id FROM lista_precio WHERE nombre='MENU DIARIO' AND moneda='PEN' LIMIT 1),
 10.00, NOW(), NULL),
((SELECT id FROM producto WHERE codigo='SEG-005' LIMIT 1),
 (SELECT id FROM lista_precio WHERE nombre='MENU DIARIO' AND moneda='PEN' LIMIT 1),
 10.00, NOW(), NULL),
((SELECT id FROM producto WHERE codigo='SEG-006' LIMIT 1),
 (SELECT id FROM lista_precio WHERE nombre='MENU DIARIO' AND moneda='PEN' LIMIT 1),
 10.00, NOW(), NULL),
((SELECT id FROM producto WHERE codigo='SEG-007' LIMIT 1),
 (SELECT id FROM lista_precio WHERE nombre='MENU DIARIO' AND moneda='PEN' LIMIT 1),
 10.00, NOW(), NULL),
((SELECT id FROM producto WHERE codigo='SEG-008' LIMIT 1),
 (SELECT id FROM lista_precio WHERE nombre='MENU DIARIO' AND moneda='PEN' LIMIT 1),
 10.00, NOW(), NULL),
((SELECT id FROM producto WHERE codigo='SEG-009' LIMIT 1),
 (SELECT id FROM lista_precio WHERE nombre='MENU DIARIO' AND moneda='PEN' LIMIT 1),
 10.00, NOW(), NULL),
((SELECT id FROM producto WHERE codigo='SEG-010' LIMIT 1),
 (SELECT id FROM lista_precio WHERE nombre='MENU DIARIO' AND moneda='PEN' LIMIT 1),
 10.00, NOW(), NULL),
((SELECT id FROM producto WHERE codigo='SEG-011' LIMIT 1),
 (SELECT id FROM lista_precio WHERE nombre='MENU DIARIO' AND moneda='PEN' LIMIT 1),
 10.00, NOW(), NULL),

-- EJECUTIVO DIARIO
((SELECT id FROM producto WHERE codigo='EJE-001' LIMIT 1),
 (SELECT id FROM lista_precio WHERE nombre='EJECUTIVO DIARIO' AND moneda='PEN' LIMIT 1),
 12.00, NOW(), NULL),
((SELECT id FROM producto WHERE codigo='EJE-002' LIMIT 1),
 (SELECT id FROM lista_precio WHERE nombre='EJECUTIVO DIARIO' AND moneda='PEN' LIMIT 1),
 12.00, NOW(), NULL),
((SELECT id FROM producto WHERE codigo='EJE-003' LIMIT 1),
 (SELECT id FROM lista_precio WHERE nombre='EJECUTIVO DIARIO' AND moneda='PEN' LIMIT 1),
 12.00, NOW(), NULL),
((SELECT id FROM producto WHERE codigo='EJE-004' LIMIT 1),
 (SELECT id FROM lista_precio WHERE nombre='EJECUTIVO DIARIO' AND moneda='PEN' LIMIT 1),
 12.00, NOW(), NULL),
((SELECT id FROM producto WHERE codigo='EJE-005' LIMIT 1),
 (SELECT id FROM lista_precio WHERE nombre='EJECUTIVO DIARIO' AND moneda='PEN' LIMIT 1),
 12.00, NOW(), NULL),
((SELECT id FROM producto WHERE codigo='EJE-006' LIMIT 1),
 (SELECT id FROM lista_precio WHERE nombre='EJECUTIVO DIARIO' AND moneda='PEN' LIMIT 1),
 12.00, NOW(), NULL),
((SELECT id FROM producto WHERE codigo='EJE-007' LIMIT 1),
 (SELECT id FROM lista_precio WHERE nombre='EJECUTIVO DIARIO' AND moneda='PEN' LIMIT 1),
 12.00, NOW(), NULL),
((SELECT id FROM producto WHERE codigo='EJE-008' LIMIT 1),
 (SELECT id FROM lista_precio WHERE nombre='EJECUTIVO DIARIO' AND moneda='PEN' LIMIT 1),
 12.00, NOW(), NULL),

-- MARINO DIARIO
((SELECT id FROM producto WHERE codigo='MAR-001' LIMIT 1),
 (SELECT id FROM lista_precio WHERE nombre='MARINO DIARIO' AND moneda='PEN' LIMIT 1),
 16.00, NOW(), NULL),
((SELECT id FROM producto WHERE codigo='MAR-002' LIMIT 1),
 (SELECT id FROM lista_precio WHERE nombre='MARINO DIARIO' AND moneda='PEN' LIMIT 1),
 16.00, NOW(), NULL),
((SELECT id FROM producto WHERE codigo='MAR-003' LIMIT 1),
 (SELECT id FROM lista_precio WHERE nombre='MARINO DIARIO' AND moneda='PEN' LIMIT 1),
 16.00, NOW(), NULL),
((SELECT id FROM producto WHERE codigo='MAR-004' LIMIT 1),
 (SELECT id FROM lista_precio WHERE nombre='MARINO DIARIO' AND moneda='PEN' LIMIT 1),
 16.00, NOW(), NULL),
((SELECT id FROM producto WHERE codigo='MAR-005' LIMIT 1),
 (SELECT id FROM lista_precio WHERE nombre='MARINO DIARIO' AND moneda='PEN' LIMIT 1),
 16.00, NOW(), NULL),
((SELECT id FROM producto WHERE codigo='MAR-006' LIMIT 1),
 (SELECT id FROM lista_precio WHERE nombre='MARINO DIARIO' AND moneda='PEN' LIMIT 1),
 16.00, NOW(), NULL),
((SELECT id FROM producto WHERE codigo='MAR-007' LIMIT 1),
 (SELECT id FROM lista_precio WHERE nombre='MARINO DIARIO' AND moneda='PEN' LIMIT 1),
 16.00, NOW(), NULL),
((SELECT id FROM producto WHERE codigo='MAR-008' LIMIT 1),
 (SELECT id FROM lista_precio WHERE nombre='MARINO DIARIO' AND moneda='PEN' LIMIT 1),
 16.00, NOW(), NULL),
((SELECT id FROM producto WHERE codigo='MAR-009' LIMIT 1),
 (SELECT id FROM lista_precio WHERE nombre='MARINO DIARIO' AND moneda='PEN' LIMIT 1),
 16.00, NOW(), NULL),

-- PARA LLEVAR
((SELECT id FROM producto WHERE codigo='ENT-001' LIMIT 1),
 (SELECT id FROM lista_precio WHERE nombre='PARA LLEVAR' AND moneda='PEN' LIMIT 1),
 5.00, NOW(), NULL),
((SELECT id FROM producto WHERE codigo='ENT-002' LIMIT 1),
 (SELECT id FROM lista_precio WHERE nombre='PARA LLEVAR' AND moneda='PEN' LIMIT 1),
 5.00, NOW(), NULL),
((SELECT id FROM producto WHERE codigo='ENT-003' LIMIT 1),
 (SELECT id FROM lista_precio WHERE nombre='PARA LLEVAR' AND moneda='PEN' LIMIT 1),
 5.00, NOW(), NULL),
((SELECT id FROM producto WHERE codigo='SOP-001' LIMIT 1),
 (SELECT id FROM lista_precio WHERE nombre='PARA LLEVAR' AND moneda='PEN' LIMIT 1),
 5.00, NOW(), NULL),
((SELECT id FROM producto WHERE codigo='SEG-001' LIMIT 1),
 (SELECT id FROM lista_precio WHERE nombre='PARA LLEVAR' AND moneda='PEN' LIMIT 1),
 11.00, NOW(), NULL),
((SELECT id FROM producto WHERE codigo='SEG-002' LIMIT 1),
 (SELECT id FROM lista_precio WHERE nombre='PARA LLEVAR' AND moneda='PEN' LIMIT 1),
 11.00, NOW(), NULL),
((SELECT id FROM producto WHERE codigo='SEG-003' LIMIT 1),
 (SELECT id FROM lista_precio WHERE nombre='PARA LLEVAR' AND moneda='PEN' LIMIT 1),
 11.00, NOW(), NULL),
((SELECT id FROM producto WHERE codigo='SEG-004' LIMIT 1),
 (SELECT id FROM lista_precio WHERE nombre='PARA LLEVAR' AND moneda='PEN' LIMIT 1),
 11.00, NOW(), NULL),
((SELECT id FROM producto WHERE codigo='SEG-005' LIMIT 1),
 (SELECT id FROM lista_precio WHERE nombre='PARA LLEVAR' AND moneda='PEN' LIMIT 1),
 11.00, NOW(), NULL),
((SELECT id FROM producto WHERE codigo='SEG-006' LIMIT 1),
 (SELECT id FROM lista_precio WHERE nombre='PARA LLEVAR' AND moneda='PEN' LIMIT 1),
 11.00, NOW(), NULL),
((SELECT id FROM producto WHERE codigo='SEG-007' LIMIT 1),
 (SELECT id FROM lista_precio WHERE nombre='PARA LLEVAR' AND moneda='PEN' LIMIT 1),
 11.00, NOW(), NULL),
((SELECT id FROM producto WHERE codigo='SEG-008' LIMIT 1),
 (SELECT id FROM lista_precio WHERE nombre='PARA LLEVAR' AND moneda='PEN' LIMIT 1),
 11.00, NOW(), NULL),
((SELECT id FROM producto WHERE codigo='SEG-009' LIMIT 1),
 (SELECT id FROM lista_precio WHERE nombre='PARA LLEVAR' AND moneda='PEN' LIMIT 1),
 11.00, NOW(), NULL),
((SELECT id FROM producto WHERE codigo='SEG-010' LIMIT 1),
 (SELECT id FROM lista_precio WHERE nombre='PARA LLEVAR' AND moneda='PEN' LIMIT 1),
 11.00, NOW(), NULL),
((SELECT id FROM producto WHERE codigo='SEG-011' LIMIT 1),
 (SELECT id FROM lista_precio WHERE nombre='PARA LLEVAR' AND moneda='PEN' LIMIT 1),
 11.00, NOW(), NULL),
((SELECT id FROM producto WHERE codigo='EJE-001' LIMIT 1),
 (SELECT id FROM lista_precio WHERE nombre='PARA LLEVAR' AND moneda='PEN' LIMIT 1),
 13.00, NOW(), NULL),
((SELECT id FROM producto WHERE codigo='EJE-002' LIMIT 1),
 (SELECT id FROM lista_precio WHERE nombre='PARA LLEVAR' AND moneda='PEN' LIMIT 1),
 13.00, NOW(), NULL),
((SELECT id FROM producto WHERE codigo='EJE-003' LIMIT 1),
 (SELECT id FROM lista_precio WHERE nombre='PARA LLEVAR' AND moneda='PEN' LIMIT 1),
 13.00, NOW(), NULL),
((SELECT id FROM producto WHERE codigo='EJE-004' LIMIT 1),
 (SELECT id FROM lista_precio WHERE nombre='PARA LLEVAR' AND moneda='PEN' LIMIT 1),
 13.00, NOW(), NULL),
((SELECT id FROM producto WHERE codigo='EJE-005' LIMIT 1),
 (SELECT id FROM lista_precio WHERE nombre='PARA LLEVAR' AND moneda='PEN' LIMIT 1),
 13.00, NOW(), NULL),
((SELECT id FROM producto WHERE codigo='EJE-006' LIMIT 1),
 (SELECT id FROM lista_precio WHERE nombre='PARA LLEVAR' AND moneda='PEN' LIMIT 1),
 13.00, NOW(), NULL),
((SELECT id FROM producto WHERE codigo='EJE-007' LIMIT 1),
 (SELECT id FROM lista_precio WHERE nombre='PARA LLEVAR' AND moneda='PEN' LIMIT 1),
 13.00, NOW(), NULL),
((SELECT id FROM producto WHERE codigo='EJE-008' LIMIT 1),
 (SELECT id FROM lista_precio WHERE nombre='PARA LLEVAR' AND moneda='PEN' LIMIT 1),
 13.00, NOW(), NULL),

-- MENU DOMINGO
((SELECT id FROM producto WHERE codigo='SEG-001' LIMIT 1),
 (SELECT id FROM lista_precio WHERE nombre='MENU DOMINGO' AND moneda='PEN' LIMIT 1),
 11.00, NOW(), NULL),
((SELECT id FROM producto WHERE codigo='SEG-002' LIMIT 1),
 (SELECT id FROM lista_precio WHERE nombre='MENU DOMINGO' AND moneda='PEN' LIMIT 1),
 11.00, NOW(), NULL),
((SELECT id FROM producto WHERE codigo='SEG-003' LIMIT 1),
 (SELECT id FROM lista_precio WHERE nombre='MENU DOMINGO' AND moneda='PEN' LIMIT 1),
 11.00, NOW(), NULL),
((SELECT id FROM producto WHERE codigo='SEG-004' LIMIT 1),
 (SELECT id FROM lista_precio WHERE nombre='MENU DOMINGO' AND moneda='PEN' LIMIT 1),
 11.00, NOW(), NULL),
((SELECT id FROM producto WHERE codigo='SEG-005' LIMIT 1),
 (SELECT id FROM lista_precio WHERE nombre='MENU DOMINGO' AND moneda='PEN' LIMIT 1),
 11.00, NOW(), NULL),
((SELECT id FROM producto WHERE codigo='SEG-006' LIMIT 1),
 (SELECT id FROM lista_precio WHERE nombre='MENU DOMINGO' AND moneda='PEN' LIMIT 1),
 11.00, NOW(), NULL),
((SELECT id FROM producto WHERE codigo='SEG-007' LIMIT 1),
 (SELECT id FROM lista_precio WHERE nombre='MENU DOMINGO' AND moneda='PEN' LIMIT 1),
 11.00, NOW(), NULL),
((SELECT id FROM producto WHERE codigo='SEG-008' LIMIT 1),
 (SELECT id FROM lista_precio WHERE nombre='MENU DOMINGO' AND moneda='PEN' LIMIT 1),
 11.00, NOW(), NULL),
((SELECT id FROM producto WHERE codigo='SEG-009' LIMIT 1),
 (SELECT id FROM lista_precio WHERE nombre='MENU DOMINGO' AND moneda='PEN' LIMIT 1),
 11.00, NOW(), NULL),
((SELECT id FROM producto WHERE codigo='SEG-010' LIMIT 1),
 (SELECT id FROM lista_precio WHERE nombre='MENU DOMINGO' AND moneda='PEN' LIMIT 1),
 11.00, NOW(), NULL),
((SELECT id FROM producto WHERE codigo='SEG-011' LIMIT 1),
 (SELECT id FROM lista_precio WHERE nombre='MENU DOMINGO' AND moneda='PEN' LIMIT 1),
 11.00, NOW(), NULL),

-- CENA
((SELECT id FROM producto WHERE codigo='EJE-001' LIMIT 1),
 (SELECT id FROM lista_precio WHERE nombre='CENA' AND moneda='PEN' LIMIT 1),
 13.00, NOW(), NULL),
((SELECT id FROM producto WHERE codigo='EJE-002' LIMIT 1),
 (SELECT id FROM lista_precio WHERE nombre='CENA' AND moneda='PEN' LIMIT 1),
 13.00, NOW(), NULL),
((SELECT id FROM producto WHERE codigo='EJE-003' LIMIT 1),
 (SELECT id FROM lista_precio WHERE nombre='CENA' AND moneda='PEN' LIMIT 1),
 13.00, NOW(), NULL),
((SELECT id FROM producto WHERE codigo='EJE-004' LIMIT 1),
 (SELECT id FROM lista_precio WHERE nombre='CENA' AND moneda='PEN' LIMIT 1),
 13.00, NOW(), NULL),
((SELECT id FROM producto WHERE codigo='EJE-005' LIMIT 1),
 (SELECT id FROM lista_precio WHERE nombre='CENA' AND moneda='PEN' LIMIT 1),
 13.00, NOW(), NULL),
((SELECT id FROM producto WHERE codigo='EJE-006' LIMIT 1),
 (SELECT id FROM lista_precio WHERE nombre='CENA' AND moneda='PEN' LIMIT 1),
 13.00, NOW(), NULL),
((SELECT id FROM producto WHERE codigo='EJE-007' LIMIT 1),
 (SELECT id FROM lista_precio WHERE nombre='CENA' AND moneda='PEN' LIMIT 1),
 13.00, NOW(), NULL),
((SELECT id FROM producto WHERE codigo='EJE-008' LIMIT 1),
 (SELECT id FROM lista_precio WHERE nombre='CENA' AND moneda='PEN' LIMIT 1),
 13.00, NOW(), NULL)
AS new
ON DUPLICATE KEY UPDATE
  precio        = new.precio,
  vigente_hasta = new.vigente_hasta,
  updated_at    = CURRENT_TIMESTAMP;

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
  NOW(),
  'SALON',
  'ABIERTA',
  0.00
);
SET @v := LAST_INSERT_ID();

INSERT INTO venta_detalle (venta_id, producto_id, descripcion, cantidad, precio_unit, total)
SELECT
  v.id,
  p.id,
  'TEQUEÑOS CON SALSA GOLF',
  1.000,
  pp.precio,
  ROUND(1.000 * pp.precio, 2)
FROM venta v
JOIN producto p   ON p.nombre = 'TEQUEÑOS CON SALSA GOLF'
JOIN producto_precio pp ON pp.producto_id = p.id
WHERE v.id = @v
  AND pp.lista_precio_id = v.lista_precio_id
ORDER BY pp.vigente_desde DESC
LIMIT 1;

UPDATE venta
SET total = (SELECT COALESCE(SUM(total),0) FROM venta_detalle WHERE venta_id=@v)
WHERE id=@v;

SET @monto := (SELECT total FROM venta WHERE id=@v);

INSERT INTO pago (venta_id, medio, monto, moneda, ts_pago, referencia)
VALUES (@v, 'EFECTIVO', @monto, 'PEN', NOW(), NULL);

UPDATE venta v
JOIN (
  SELECT venta_id, COALESCE(SUM(monto),0) AS pagado
  FROM pago
  WHERE venta_id = @v
  GROUP BY venta_id
) p ON p.venta_id = v.id
SET v.estado   = CASE WHEN p.pagado >= v.total - 0.01 THEN 'CERRADA' ELSE 'ABIERTA' END,
    v.ts_cierre= CASE WHEN p.pagado >= v.total - 0.01 THEN NOW()      ELSE NULL      END
WHERE v.id = @v;












CREATE DATABASE spotifysongs;
USE spotifysongs;
CREATE TABLE songs (
  id BIGINT PRIMARY KEY AUTO_INCREMENT,
  track_name            VARCHAR(200),
  artist_name           VARCHAR(200),
  artist_count          TINYINT UNSIGNED,
  released_year         SMALLINT,
  released_month        TINYINT UNSIGNED,
  released_day          TINYINT UNSIGNED,
  in_spotify_playlists  INT UNSIGNED,
  in_spotify_charts     INT UNSIGNED,
  streams               BIGINT UNSIGNED,
  in_apple_playlists    INT UNSIGNED,
  in_apple_charts       INT UNSIGNED,
  in_deezer_playlists   INT UNSIGNED,
  in_deezer_charts      INT UNSIGNED,
  in_shazam_charts      INT UNSIGNED,
  bpm                   SMALLINT UNSIGNED,
  musical_key           VARCHAR(3),
  mode                  VARCHAR(5),
  danceability_pct      TINYINT UNSIGNED,   -- 0–100
  valence_pct           TINYINT UNSIGNED,
  energy_pct            TINYINT UNSIGNED,
  acousticness_pct      TINYINT UNSIGNED,
  instrumentalness_pct  TINYINT UNSIGNED,
  liveness_pct          TINYINT UNSIGNED,
  speechiness_pct       TINYINT UNSIGNED
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

LOAD DATA LOCAL INFILE 'C:\\Users\\piter\\OneDrive\\Escritorio\\Aplicaciones\\Popular_Spotify_Songs.csv'
INTO TABLE songs
CHARACTER SET latin1                 -- <== clave: el archivo NO era utf8
FIELDS TERMINATED BY ','  ENCLOSED BY '"'  ESCAPED BY '\\'
LINES  TERMINATED BY '\r\n'
IGNORE 1 LINES
(@track_name, @artist_name, @artist_count, @year, @month, @day,
 @in_spotify_playlists, @in_spotify_charts, @streams,
 @in_apple_playlists, @in_apple_charts,
 @in_deezer_playlists, @in_deezer_charts,
 @in_shazam_charts, @bpm, @key, @mode,
 @dance, @valence, @energy, @acoustic, @instrum, @live, @speech)
SET
  track_name           = NULLIF(@track_name,''),
  artist_name          = NULLIF(@artist_name,''),
  artist_count         = NULLIF(@artist_count,''),
  released_year        = NULLIF(@year,''),
  released_month       = NULLIF(@month,''),
  released_day         = NULLIF(@day,''),
  in_spotify_playlists = NULLIF(@in_spotify_playlists,''),
  in_spotify_charts    = NULLIF(@in_spotify_charts,''),
  streams              = NULLIF(REPLACE(@streams, ',', ''), ''),
  in_apple_playlists   = NULLIF(@in_apple_playlists,''),
  in_apple_charts      = NULLIF(@in_apple_charts,''),
  in_deezer_playlists  = NULLIF(@in_deezer_playlists,''),
  in_deezer_charts     = NULLIF(@in_deezer_charts,''),
  in_shazam_charts     = NULLIF(@in_shazam_charts,''),
  bpm                  = NULLIF(@bpm,''),
  musical_key          = NULLIF(@key,''),
  mode                 = NULLIF(@mode,''),
  danceability_pct     = NULLIF(@dance,''),
  valence_pct          = NULLIF(@valence,''),
  energy_pct           = NULLIF(@energy,''),
  acousticness_pct     = NULLIF(@acoustic,''),
  instrumentalness_pct = NULLIF(@instrum,''),
  liveness_pct         = NULLIF(@live,''),
  speechiness_pct      = NULLIF(@speech,'');
  
SELECT id FROM songs
  ORDER BY track_name DESC;


SHOW VARIABLES LIKE 'local_infile';   -- debe decir ON
SET GLOBAL local_infile = 1;          -- habilita hasta el próximo reinicio


SHOW VARIABLES LIKE 'local_infile';  -- ON



