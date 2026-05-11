<?php
/**
 * Parent self-link children — mobile-only parent login.
 *
 * Authenticates a parent against the `app_parent_users` table (the mobile
 * parent-account registry, separate from the portal's `users` table).
 * Passwords are stored as bcrypt hashes (PHP `password_hash` /
 * `password_verify`). On success, the response carries the linked
 * `app_parents` profile that every other parent_link/* endpoint expects as
 * `caller_app_parent_id`.
 *
 * POST (JSON or form):
 *   identifier : string  — username OR email (case-insensitive)
 *   password   : string  — plaintext, verified against the stored hash
 *   api_secret?: string  — required when PL_API_SECRET is configured
 *
 * Response — success:
 *   {
 *     "success": true,
 *     "result": {
 *       "app_parent_id":      1,
 *       "app_parent_user_id": 1,
 *       "username":           "parent_demo",
 *       "email":              "parent@example.com",
 *       "name":               "Parent Demo",
 *       "phone":              "",
 *       "active_child_id":    null
 *     }
 *   }
 *
 * Response — failure:
 *   { "success": false, "error": "Invalid username or password." }
 *
 * Seeding for testing (run once, replace plaintext):
 *
 *   1. Pick a plaintext password and hash it:
 *        php -r "echo password_hash('changeme', PASSWORD_DEFAULT), PHP_EOL;"
 *
 *   2. Insert the rows (app_parents first, then app_parent_users):
 *        INSERT INTO app_parents (name, email, phone, created_at)
 *          VALUES ('Demo Parent', 'parent@example.com', '', NOW());
 *        SET @pid = LAST_INSERT_ID();
 *        INSERT INTO app_parent_users
 *          (app_parent_id, username, password, email, created_at)
 *        VALUES (@pid, 'parent_demo', '<paste hash>', 'parent@example.com', NOW());
 */

require_once __DIR__ . '/pl_bootstrap.php';

$mysqli = pl_mysqli_connect();

try {
    $body = pl_read_json_body();
    pl_require_api_secret($body);

    $identifier_raw = isset($body['identifier']) ? trim((string) $body['identifier']) : '';
    $password       = isset($body['password'])   ? (string) $body['password']         : '';

    if ($identifier_raw === '' || $password === '') {
        pl_json_out([
            'success' => false,
            'error'   => 'Please enter your username (or email) and password.',
        ]);
    }

    // Lookup is case-insensitive against username OR email. The columns are
    // independently indexed so this is cheap.
    $ident_lc = strtolower($identifier_raw);
    $ident_esc = $mysqli->real_escape_string($ident_lc);

    $sql = "SELECT id, app_parent_id, username, password, email, updated_at
            FROM app_parent_users
            WHERE LOWER(username) = '$ident_esc'
               OR LOWER(email)    = '$ident_esc'
            LIMIT 1";
    $res = $mysqli->query($sql);
    if (!$res) {
        throw new Exception('Login query failed: ' . $mysqli->error);
    }

    // Use a generic error for both "no row" and "bad password" so the
    // endpoint can't be used to enumerate valid usernames.
    $generic_fail = ['success' => false, 'error' => 'Invalid username or password.'];

    if ($res->num_rows === 0) {
        $res->free();
        $mysqli->close();
        // Constant-time-ish: run a dummy verify so the response timing for
        // "user missing" and "password wrong" stays similar.
        password_verify($password, '$2y$10$ABCDEFGHIJKLMNOPQRSTUuVWXYZabcdefghijklmnopqrstuvwx12');
        pl_json_out($generic_fail);
    }

    $user_row = $res->fetch_assoc();
    $res->free();

    $stored_hash = (string) ($user_row['password'] ?? '');
    if ($stored_hash === '' || !password_verify($password, $stored_hash)) {
        $mysqli->close();
        pl_json_out($generic_fail);
    }

    // Optional: re-hash if the cost has been bumped since the hash was
    // written. Cheap and silent — if anything fails we just skip it.
    if (password_needs_rehash($stored_hash, PASSWORD_DEFAULT)) {
        $new_hash = password_hash($password, PASSWORD_DEFAULT);
        if (is_string($new_hash) && $new_hash !== '') {
            $hash_esc = $mysqli->real_escape_string($new_hash);
            $uid      = (int) $user_row['id'];
            $mysqli->query("UPDATE app_parent_users SET password = '$hash_esc' WHERE id = $uid LIMIT 1");
        }
    }

    // Pull the linked app_parents row — the actual identity the other
    // endpoints care about.
    $app_parent_id = (int) ($user_row['app_parent_id'] ?? 0);
    if ($app_parent_id < 1) {
        $mysqli->close();
        pl_json_out([
            'success' => false,
            'error'   => 'Parent profile is missing. Please contact your school admin.',
        ]);
    }

    $pr = $mysqli->query("SELECT * FROM app_parents WHERE id = $app_parent_id LIMIT 1");
    if (!$pr || $pr->num_rows === 0) {
        $mysqli->close();
        pl_json_out([
            'success' => false,
            'error'   => 'Parent profile is missing. Please contact your school admin.',
        ]);
    }
    $parent_row = $pr->fetch_assoc();
    $pr->free();

    // Track "last activity" — useful for the admin even without a session.
    $uid = (int) $user_row['id'];
    $mysqli->query("UPDATE app_parent_users SET updated_at = NOW() WHERE id = $uid LIMIT 1");

    $mysqli->close();
    pl_json_out([
        'success' => true,
        'result'  => pl_app_parent_profile_payload($parent_row, $user_row),
    ]);
} catch (Exception $e) {
    if ($mysqli) {
        $mysqli->close();
    }
    pl_json_out([
        'success' => false,
        'error'   => $e->getMessage(),
    ]);
}
