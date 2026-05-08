-- pergamino-heartbeat — D1 schema
-- Run once per deployment: wrangler d1 execute pergamino-<slug> --file ./schema.sql

CREATE TABLE IF NOT EXISTS pr_reviews (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  pr_number INTEGER NOT NULL,
  verdict TEXT NOT NULL,           -- 'approve' | 'needs-eyes' | 'reject'
  confidence TEXT NOT NULL,        -- 'high' | 'medium' | 'low'
  reasoning TEXT,
  flags TEXT,                      -- JSON array of flag strings
  ts INTEGER NOT NULL
);

CREATE TABLE IF NOT EXISTS escalations (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  phone TEXT NOT NULL,
  last_message TEXT NOT NULL,
  ts INTEGER NOT NULL,
  resolved INTEGER DEFAULT 0,      -- 0 = open, 1 = resolved by ops/sales
  resolved_by TEXT,
  resolved_at INTEGER
);

CREATE TABLE IF NOT EXISTS knowledge_gaps (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  question TEXT NOT NULL,
  ts INTEGER NOT NULL,
  proposed_pr INTEGER              -- nullable; set if FAQ proposal PR opened
);

CREATE TABLE IF NOT EXISTS audit_log (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  user_email TEXT,
  action TEXT NOT NULL,            -- 'merge' | 'close' | 'review' | 'escalate' | 'concierge-reply' | ...
  detail TEXT,                     -- JSON; action-specific
  ts INTEGER NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_pr_ts ON pr_reviews(ts);
CREATE INDEX IF NOT EXISTS idx_kg_ts ON knowledge_gaps(ts);
CREATE INDEX IF NOT EXISTS idx_esc_ts ON escalations(ts);
CREATE INDEX IF NOT EXISTS idx_audit_ts ON audit_log(ts);
CREATE INDEX IF NOT EXISTS idx_audit_user ON audit_log(user_email);
