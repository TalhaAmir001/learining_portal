<?php
/**
 * Shared helpers for HTTP SQL installers in mobile_apis/.
 */

require_once __DIR__ . '/pl_bootstrap.php';

/**
 * FTP fallback when PL_API_SECRET is not set on the server.
 * Change this to a long random string before uploading, then call:
 *   ?install_key=that-same-string
 */
if (!defined('PL_INSTALL_KEY')) {
    define('PL_INSTALL_KEY', 'CHANGE_ME_BEFORE_UPLOAD');
}

/**
 * Require api_secret (env) or install_key (constant above).
 */
function pl_install_require_secret() {
    if (PL_API_SECRET !== '') {
        pl_require_api_secret(pl_read_json_body());
        return;
    }

    $expected = (string) PL_INSTALL_KEY;
    if ($expected === '' || $expected === 'CHANGE_ME_BEFORE_UPLOAD') {
        pl_install_json_response(array(
            'success' => false,
            'error'   => 'Set PL_API_SECRET on the server, or edit PL_INSTALL_KEY in pl_install_helper.php before uploading.',
        ));
    }

    $sent = '';
    if (isset($_GET['install_key'])) {
        $sent = (string) $_GET['install_key'];
    } elseif (isset($_POST['install_key'])) {
        $sent = (string) $_POST['install_key'];
    }

    if ($sent === '' || !hash_equals($expected, $sent)) {
        pl_install_json_response(array(
            'success' => false,
            'error'   => 'Invalid or missing install_key.',
        ));
    }
}

/**
 * Strip SQL line comments and execute a single-statement migration file.
 *
 * @return array{success:bool,message?:string,error?:string,table_exists?:bool}
 */
function pl_install_run_sql_file($path) {
    if (!is_readable($path)) {
        return array(
            'success' => false,
            'error'   => 'SQL file not found: ' . basename((string) $path),
        );
    }

    $raw = file_get_contents($path);
    if ($raw === false || trim($raw) === '') {
        return array(
            'success' => false,
            'error'   => 'SQL file is empty: ' . basename((string) $path),
        );
    }

    $sql = pl_install_strip_sql_comments($raw);
    if ($sql === '') {
        return array(
            'success' => false,
            'error'   => 'No executable SQL in file: ' . basename((string) $path),
        );
    }

    $mysqli = pl_mysqli_connect();

    $table_name = pl_install_guess_table_name($sql);
    $existed_before = ($table_name !== '') ? pl_install_table_exists($mysqli, $table_name) : false;

    if (!$mysqli->query($sql)) {
        $err = $mysqli->error;
        $mysqli->close();
        return array(
            'success' => false,
            'error'   => $err,
            'file'    => basename((string) $path),
        );
    }

    $exists_after = ($table_name !== '') ? pl_install_table_exists($mysqli, $table_name) : true;
    $mysqli->close();

    $message = 'Migration executed.';
    if ($table_name !== '') {
        if ($existed_before) {
            $message = "Table `$table_name` already existed; no changes required.";
        } else {
            $message = "Table `$table_name` created successfully.";
        }
    }

    return array(
        'success'      => true,
        'message'      => $message,
        'file'         => basename((string) $path),
        'table'        => $table_name,
        'table_exists' => $exists_after,
    );
}

function pl_install_strip_sql_comments($raw) {
    $out = array();
    foreach (preg_split('/\R/', (string) $raw) as $line) {
        $trimmed = trim($line);
        if ($trimmed === '' || strpos($trimmed, '--') === 0) {
            continue;
        }
        $out[] = $line;
    }
    return trim(implode("\n", $out));
}

function pl_install_guess_table_name($sql) {
    if (preg_match('/CREATE\s+TABLE\s+(?:IF\s+NOT\s+EXISTS\s+)?`([^`]+)`/i', $sql, $m)) {
        return $m[1];
    }
    return '';
}

function pl_install_table_exists($mysqli, $table) {
    $table_esc = $mysqli->real_escape_string($table);
    $res = $mysqli->query("SHOW TABLES LIKE '$table_esc'");
    $exists = ($res && $res->num_rows > 0);
    if ($res) {
        $res->free();
    }
    return $exists;
}

function pl_install_json_response($data) {
    pl_json_out($data);
}

function pl_install_html_response($data, $title) {
    if (!headers_sent()) {
        header('Content-Type: text/html; charset=utf-8');
    }
    $title_esc = htmlspecialchars((string) $title, ENT_QUOTES, 'UTF-8');
    $ok        = !empty($data['success']);
    $badge     = $ok ? 'OK' : 'FAILED';
    $color     = $ok ? '#1b7f3a' : '#b00020';
    $json      = json_encode($data, JSON_PRETTY_PRINT | JSON_UNESCAPED_UNICODE);
    if ($json === false) {
        $json = '{"success":false,"error":"Failed to encode response"}';
    }
    echo '<!DOCTYPE html><html><head><meta charset="utf-8"><title>' . $title_esc . '</title></head><body style="font-family:system-ui,sans-serif;padding:24px;max-width:900px;">';
    echo '<h1>' . $title_esc . '</h1>';
    echo '<p style="font-size:18px;color:' . $color . ';font-weight:bold;">' . $badge . '</p>';
    echo '<pre style="background:#f5f5f5;padding:16px;border-radius:8px;overflow:auto;">';
    echo htmlspecialchars($json, ENT_QUOTES, 'UTF-8');
    echo '</pre>';
    echo '<p><strong>Security:</strong> delete this installer from the server after success.</p>';
    echo '</body></html>';
    exit;
}
