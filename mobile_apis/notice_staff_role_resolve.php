<?php
/**
 * Resolve staff role_id list for notice filtering (matches web notification_roles targeting).
 * Web uses session role from getStaffRole(); mobile sends role_ids from login JSON or we fall back to DB.
 *
 * @param mysqli $mysqli
 * @param int    $staff_id      staff.id (same as app uid for teacher/admin)
 * @param string|null $role_ids_csv optional comma-separated role ids from app (login "roles" map)
 * @return int[] unique positive role ids (empty if unknown)
 */
function notice_resolve_staff_role_ids(mysqli $mysqli, int $staff_id, $role_ids_csv) {
    $ids = [];
    if ($role_ids_csv !== null && trim((string) $role_ids_csv) !== '') {
        foreach (explode(',', (string) $role_ids_csv) as $p) {
            $i = (int) trim($p);
            if ($i > 0) {
                $ids[] = $i;
            }
        }
        $ids = array_values(array_unique($ids));
        if (!empty($ids)) {
            return $ids;
        }
    }
    $sid = (int) $staff_id;
    $res = $mysqli->query("SELECT role_id FROM staff WHERE id = {$sid} LIMIT 1");
    if ($res && ($row = $res->fetch_assoc())) {
        $rid = isset($row['role_id']) ? (int) $row['role_id'] : 0;
        if ($rid > 0) {
            return [$rid];
        }
    }
    $check = $mysqli->query("SHOW TABLES LIKE 'staff_roles'");
    if ($check && $check->num_rows > 0) {
        $ids = [];
        $res2 = $mysqli->query("SELECT DISTINCT role_id FROM staff_roles WHERE staff_id = {$sid}");
        if ($res2) {
            while ($r = $res2->fetch_assoc()) {
                $rid = (int) $r['role_id'];
                if ($rid > 0) {
                    $ids[] = $rid;
                }
            }
        }
        return array_values(array_unique($ids));
    }
    return [];
}

/**
 * INNER JOIN clause for send_notification n × notification_roles for this staff's roles.
 * Role 7 = super-admin style: any notice that has at least one notification_roles row.
 *
 * @param int[] $role_ids
 * @return string SQL fragment starting with INNER JOIN
 */
function notice_staff_notification_roles_join(array $role_ids) {
    if (empty($role_ids)) {
        return 'INNER JOIN notification_roles nr ON 1 = 0';
    }
    if (in_array(7, $role_ids, true)) {
        return 'INNER JOIN (SELECT DISTINCT send_notification_id FROM notification_roles) nr ON nr.send_notification_id = n.id';
    }
    $in = implode(',', array_map('intval', $role_ids));
    return "INNER JOIN notification_roles nr ON nr.send_notification_id = n.id AND nr.role_id IN ({$in})";
}
