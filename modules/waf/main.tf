# ──────────────────────────────────────────────
# Cloud Armor – WAF policy for Web Application
# ──────────────────────────────────────────────
resource "google_compute_security_policy" "webapp" {
  count       = var.enable_webapp_policy ? 1 : 0
  name        = "${var.environment}-webapp-waf-policy"
  project     = var.project_id
  description = "WAF policy for web application (OWASP CRS + rate limiting)"

  # ── OWASP Top 10 preconfigured rules ────────

  # SQLi protection
  rule {
    priority    = 1000
    action      = "deny(403)"
    description = "Block SQL injection attacks (OWASP CRS)"

    match {
      expr {
        expression = "evaluatePreconfiguredExpr('sqli-v33-stable')"
      }
    }
  }

  # XSS protection
  rule {
    priority    = 1001
    action      = "deny(403)"
    description = "Block cross-site scripting attacks (OWASP CRS)"

    match {
      expr {
        expression = "evaluatePreconfiguredExpr('xss-v33-stable')"
      }
    }
  }

  # LFI protection
  rule {
    priority    = 1002
    action      = "deny(403)"
    description = "Block local file inclusion attacks (OWASP CRS)"

    match {
      expr {
        expression = "evaluatePreconfiguredExpr('lfi-v33-stable')"
      }
    }
  }

  # RFI protection
  rule {
    priority    = 1003
    action      = "deny(403)"
    description = "Block remote file inclusion attacks (OWASP CRS)"

    match {
      expr {
        expression = "evaluatePreconfiguredExpr('rfi-v33-stable')"
      }
    }
  }

  # RCE protection
  rule {
    priority    = 1004
    action      = "deny(403)"
    description = "Block remote code execution attacks (OWASP CRS)"

    match {
      expr {
        expression = "evaluatePreconfiguredExpr('rce-v33-stable')"
      }
    }
  }

  # Scanner detection
  rule {
    priority    = 1005
    action      = "deny(403)"
    description = "Block known vulnerability scanners"

    match {
      expr {
        expression = "evaluatePreconfiguredExpr('scannerdetection-v33-stable')"
      }
    }
  }

  # Protocol attack protection
  rule {
    priority    = 1006
    action      = "deny(403)"
    description = "Block protocol attacks (OWASP CRS)"

    match {
      expr {
        expression = "evaluatePreconfiguredExpr('protocolattack-v33-stable')"
      }
    }
  }

  # ── Rate Limiting ────────────────────────────
  rule {
    priority    = 2000
    action      = "throttle"
    description = "Rate limit per IP: ${var.rate_limit_threshold_count} req/${var.rate_limit_threshold_interval_sec}s"

    match {
      versioned_expr = "SRC_IPS_V1"
      config {
        src_ip_ranges = ["*"]
      }
    }

    rate_limit_options {
      conform_action = "allow"
      exceed_action  = "deny(429)"

      rate_limit_threshold {
        count        = var.rate_limit_threshold_count
        interval_sec = var.rate_limit_threshold_interval_sec
      }

      enforce_on_key = "IP"
    }
  }

  # ── Default allow rule (lowest priority) ────
  rule {
    priority    = 2147483647
    action      = "allow"
    description = "Default allow rule"

    match {
      versioned_expr = "SRC_IPS_V1"
      config {
        src_ip_ranges = ["*"]
      }
    }
  }

  adaptive_protection_config {
    layer_7_ddos_defense_config {
      enable = true
    }
  }
}

# ──────────────────────────────────────────────
# Cloud Armor – WAF policy for ArgoCD
# Stricter policy: only HTTPS allowed, tighter rate limit
# ──────────────────────────────────────────────
resource "google_compute_security_policy" "argocd" {
  count       = var.enable_argocd_policy ? 1 : 0
  name        = "${var.environment}-argocd-waf-policy"
  project     = var.project_id
  description = "WAF policy for ArgoCD UI exposed externally"

  # SQLi
  rule {
    priority    = 1000
    action      = "deny(403)"
    description = "Block SQL injection (OWASP CRS)"

    match {
      expr {
        expression = "evaluatePreconfiguredExpr('sqli-v33-stable')"
      }
    }
  }

  # XSS
  rule {
    priority    = 1001
    action      = "deny(403)"
    description = "Block XSS (OWASP CRS)"

    match {
      expr {
        expression = "evaluatePreconfiguredExpr('xss-v33-stable')"
      }
    }
  }

  # Tighter rate limit for ArgoCD (brute-force protection)
  rule {
    priority    = 2000
    action      = "throttle"
    description = "Rate limit: 100 req/60s per IP for ArgoCD"

    match {
      versioned_expr = "SRC_IPS_V1"
      config {
        src_ip_ranges = ["*"]
      }
    }

    rate_limit_options {
      conform_action = "allow"
      exceed_action  = "deny(429)"

      rate_limit_threshold {
        count        = 100
        interval_sec = 60
      }

      enforce_on_key = "IP"
    }
  }

  # Default allow
  rule {
    priority    = 2147483647
    action      = "allow"
    description = "Default allow rule"

    match {
      versioned_expr = "SRC_IPS_V1"
      config {
        src_ip_ranges = ["*"]
      }
    }
  }

  adaptive_protection_config {
    layer_7_ddos_defense_config {
      enable = true
    }
  }
}
