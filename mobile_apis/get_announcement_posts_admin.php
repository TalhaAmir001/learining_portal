<?php
/**
 * Announcement posts for admin/staff management.
 * GET (optional): api_secret when AC_API_SECRET is set.
 */
require_once __DIR__ . '/ac_admin_bootstrap.php';

$mysqli = null;
try {
    $mysqli = ac_mysqli_connect();
    ac_require_api_secret(array_merge($_GET, array()));

    $session_id = ac_current_session_id($mysqli);
    if ($session_id <= 0) {
        throw new Exception('Could not resolve current session.');
    }

    $sql = "SELECT ap.*,
                c.class AS class_name,
                sec.section AS section_name,
                st.name AS staff_firstname,
                st.surname AS staff_surname
            FROM announcement_posts ap
            LEFT JOIN classes c ON c.id = ap.class_id
            LEFT JOIN sections sec ON sec.id = ap.section_id
            LEFT JOIN staff st ON st.id = ap.created_by_staff_id
            WHERE ap.session_id = " . (int) $session_id . "
            ORDER BY ap.created_at DESC";

    $res = $mysqli->query($sql);
    if (!$res) {
        throw new Exception('Query failed: ' . $mysqli->error);
    }

    $items = array();
    while ($row = $res->fetch_assoc()) {
        $items[] = $row;
    }

    $mysqli->close();
    ac_admin_success(array(
        'session_id' => $session_id,
        'items' => $items,
    ));
} catch (Exception $e) {
    if ($mysqli) $mysqli->close();
    ac_admin_fail($e->getMessage(), array('items' => array()));
}

