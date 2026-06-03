-- ═══════════════════════════════════════════════════════════════
-- SPLITCASH — Sistema de Tarjetas con Cortes (solo Marvin por ahora)
-- Ejecutar en el SQL Editor de Supabase
-- ═══════════════════════════════════════════════════════════════


-- ───────────────────────────────────────────────────────────────
-- 1. TABLA: tarjetas
--    Cada tarjeta pertenece a un usuario (person) y tiene su
--    propio día de corte. El cálculo del mes de corte de cada
--    compra usa este día.
--    Columnas que lee/escribe el JS:
--      id         BIGSERIAL PK
--      person     INTEGER (1=Marvin, 2=Karol)
--      nombre     TEXT  ("BAC Black", "Scotiabank")
--      dia_corte  INTEGER (1-31) día de corte de la tarjeta
--      color      TEXT  (hex para el badge, ej "#5b8aff")
--      created_at TIMESTAMPTZ
-- ───────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS tarjetas (
  id         BIGSERIAL   PRIMARY KEY,
  person     INTEGER     NOT NULL CHECK (person IN (1, 2)),
  nombre     TEXT        NOT NULL,
  dia_corte  INTEGER     NOT NULL CHECK (dia_corte BETWEEN 1 AND 31),
  color      TEXT        NOT NULL DEFAULT '#5b8aff',
  created_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE tarjetas ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "tarjetas_publico" ON tarjetas;
CREATE POLICY "tarjetas_publico" ON tarjetas
  FOR ALL USING (true) WITH CHECK (true);

ALTER TABLE tarjetas REPLICA IDENTITY FULL;
DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime' AND tablename = 'tarjetas'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE tarjetas;
  END IF;
END $$;

CREATE INDEX IF NOT EXISTS idx_tarjetas_person ON tarjetas(person);


-- ───────────────────────────────────────────────────────────────
-- 2. COLUMNAS NUEVAS EN: gastos
--    tarjeta_id → referencia a la tarjeta usada (NULL = efectivo)
--    mes_corte  → mes 'YYYY-MM' al que pertenece la compra según
--                 el corte de su tarjeta (se calcula al guardar)
--    Los gastos viejos y los de Karol quedan con NULL: no les afecta.
-- ───────────────────────────────────────────────────────────────
ALTER TABLE gastos
  ADD COLUMN IF NOT EXISTS tarjeta_id BIGINT,
  ADD COLUMN IF NOT EXISTS mes_corte  TEXT;

-- (Opcional) índice para filtrar rápido por mes de corte
CREATE INDEX IF NOT EXISTS idx_gastos_mes_corte ON gastos(mes_corte);


-- ───────────────────────────────────────────────────────────────
-- 3. TARJETAS INICIALES DE MARVIN (person = 1)
--    BAC Black  → corte día 15
--    Scotiabank → corte día 3
--    Se insertan solo si no existen ya (evita duplicados al re-ejecutar)
-- ───────────────────────────────────────────────────────────────
INSERT INTO tarjetas (person, nombre, dia_corte, color)
SELECT 1, 'BAC Black', 15, '#5b8aff'
WHERE NOT EXISTS (
  SELECT 1 FROM tarjetas WHERE person = 1 AND nombre = 'BAC Black'
);

INSERT INTO tarjetas (person, nombre, dia_corte, color)
SELECT 1, 'Scotiabank', 3, '#e11d48'
WHERE NOT EXISTS (
  SELECT 1 FROM tarjetas WHERE person = 1 AND nombre = 'Scotiabank'
);


-- ───────────────────────────────────────────────────────────────
-- 4. VERIFICACIÓN
-- ───────────────────────────────────────────────────────────────
SELECT id, person, nombre, dia_corte, color FROM tarjetas ORDER BY person, id;

SELECT column_name, data_type
FROM information_schema.columns
WHERE table_schema = 'public' AND table_name = 'gastos'
  AND column_name IN ('tarjeta_id', 'mes_corte');
